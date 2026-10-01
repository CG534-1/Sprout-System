import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/core/router/routes.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/data/services/auth_service.dart';
import 'package:sprout/features/auth/auth_validators.dart';
import 'package:sprout/features/auth/auth_widgets.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  var _step = 0;
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _avatar = -1;
  Uint8List? _photo;
  var _plants = false;
  var _pets = false;
  var _plantCount = 1;
  var _petCount = 1;
  final _times = <String>{};
  String? _level;
  String? _firstError;
  String? _lastError;
  String? _emailError;
  String? _passwordError;
  var _obscure = true;
  var _agreed = false;
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    if (auth.pendingSignup) {
      _step = 1;
      _first.text = auth.pendingFirst ?? '';
      _last.text = auth.pendingLast ?? '';
      _email.text = auth.pendingEmail ?? '';
    }
    _first.addListener(_refresh);
    _last.addListener(_refresh);
    _email.addListener(_refresh);
    _password.addListener(_refresh);
    _leaveFieldsAlone();
  }

  void _leaveFieldsAlone() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  void _refresh() {
    if (_firstError != null && _first.text.trim().isNotEmpty) _firstError = null;
    if (_lastError != null && _last.text.trim().isNotEmpty) _lastError = null;
    if (_emailError != null && validateEmail(_email.text) == null) {
      _emailError = null;
    }
    if (_passwordError != null && _password.text.isNotEmpty) {
      _passwordError = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _first.removeListener(_refresh);
    _last.removeListener(_refresh);
    _email.removeListener(_refresh);
    _password.removeListener(_refresh);
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _back() {
    if (_step == 0) {
      context.pop();
      return;
    }
    setState(() => _step -= 1);
    _leaveFieldsAlone();
  }

  Future<void> _openAvatars() async {
    final picked = await showModalBottomSheet<_AvatarPick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.onboardingPaper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AvatarSheet(
        selected: _photo == null ? _avatar : -1,
        photo: _photo,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (picked.bytes != null) {
        _photo = picked.bytes;
      } else {
        _photo = null;
        _avatar = picked.index;
      }
    });
  }

  Future<void> _next() async {
    if (_submitting) return;
    if (_step == 0) {
      final first = _first.text.trim().isEmpty ? 'Enter your first name' : null;
      final last = _last.text.trim().isEmpty ? 'Enter your last name' : null;
      final email = validateEmail(_email.text);
      if (first != null || last != null || email != null) {
        setState(() {
          _firstError = first;
          _lastError = last;
          _emailError = email;
        });
        return;
      }
      setState(() => _submitting = true);
      try {
        await context.read<AuthService>().requestEmailConfirmation(
          firstName: _first.text,
          lastName: _last.text,
          email: _email.text,
        );
        if (!mounted) return;
        final email = Uri.encodeQueryComponent(_email.text.trim());
        final verified = await context.push<bool>(
          '${AppRoutes.verifyEmail}?email=$email&purpose=signup',
        );
        if (!mounted || verified != true) return;
        setState(() => _step = 1);
        _leaveFieldsAlone();
      } on AppException catch (error) {
        if (!mounted) return;
        setState(() => _emailError = error.message);
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }
    setState(() => _step += 1);
    _leaveFieldsAlone();
  }

  bool get _canContinue {
    if (_step == 0) {
      return !_submitting &&
          _first.text.trim().isNotEmpty &&
          _last.text.trim().isNotEmpty &&
          _email.text.trim().isNotEmpty;
    }
    if (_step == 1) return _plants || _pets;
    if (_step == 3) return _times.isNotEmpty;
    if (_step == 4) return _level != null;
    if (_step == 5) return _passwordReady && _agreed && !_submitting;
    return true;
  }

  String get _initials {
    final first = _first.text.trim();
    final last = _last.text.trim();
    final start = first.isEmpty ? '' : first[0];
    final end = last.isEmpty ? '' : last[0];
    return '$start$end'.toUpperCase();
  }

  bool get _passwordReady {
    final value = _password.text;
    return value.length >= 8 &&
        RegExp(r'\d').hasMatch(value) &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  Future<void> _create() async {
    if (!_canContinue) return;
    setState(() {
      _submitting = true;
      _passwordError = null;
    });
    try {
      final needsConfirmation = await context.read<AuthService>().signUp(
        name: '${_first.text.trim()} ${_last.text.trim()}',
        email: _email.text,
        password: _password.text,
        avatarUrl: _photo == null && _avatar >= 0 ? _avatars[_avatar] : null,
        avatarBytes: _photo,
      );
      if (!mounted) return;
      if (needsConfirmation) {
        setState(() {
          _passwordError = 'Enter the code from your email, then create your password.';
          _submitting = false;
        });
        return;
      }
      context.go(AppRoutes.today);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _passwordError = error.message;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: Scaffold(
      backgroundColor: AppColors.onboardingPaper,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 26, 16),
          child: Column(
            children: [
              _header(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                    child: ListView(
                    key: ValueKey(_step),
                    padding: EdgeInsets.only(
                      left: 6,
                      bottom: MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    children: [
                      _body(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: SlabButton(
                  label: _actionLabel,
                  enabled: _canContinue,
                  onPressed: _step == 5 ? _create : _next,
                ),
              ),
              if (_step == 0) ...[
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.onboardingBody,
                    ),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: () => context.go(AppRoutes.signIn),
                          child: Text(
                            'Sign in',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.sproutGreen,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.sproutGreen,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  String get _actionLabel {
    if (_step == 0) return _submitting ? 'Sending' : 'Get Started';
    if (_step == 5) return _submitting ? 'Creating' : 'Create Account';
    return 'Continue';
  }

  Widget _header() {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          AuthBackButton(onPressed: _back),
          Expanded(
            child: _step >= 1 && _step <= 4
                ? Center(child: SignupProgress(step: _step - 1))
                : const SizedBox.shrink(),
          ),
          if (_step == 5)
            Text(
              'Almost done',
              style: GoogleFonts.dmMono(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.6,
                color: AppColors.onboardingBody,
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_step) {
      case 0:
        return _setup();
      case 1:
        return _care();
      case 2:
        return _counts();
      case 3:
        return _timeStep();
      case 4:
        return _levelStep();
      default:
        return _passwordStep();
    }
  }

  Widget _setup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const AuthHeadline(lead: "Let's set up", accent: 'your home.'),
        const SizedBox(height: 28),
        Center(
          child: Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              key: const Key('select-avatar'),
              onTap: _openAvatars,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select Your Avatar',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 96,
            height: 96,
            child: _MemojiFace(
              asset: _photo == null && _avatar >= 0 ? _avatars[_avatar] : null,
              bytes: _photo,
              initials: _initials,
            ),
          ),
        ),
        const SizedBox(height: 22),
        AuthField(
          label: 'FIRST NAME',
          controller: _first,
          hint: 'Your first name',
          error: _firstError,
          mark: FieldClover(controller: _first),
        ),
        const SizedBox(height: 14),
        AuthField(
          label: 'LAST NAME',
          controller: _last,
          hint: 'Your last name',
          error: _lastError,
          mark: FieldClover(controller: _last),
        ),
        const SizedBox(height: 14),
        AuthField(
          label: 'EMAIL',
          controller: _email,
          hint: 'you@example.com',
          error: _emailError,
          keyboardType: TextInputType.emailAddress,
          mark: FieldClover(controller: _email),
        ),
      ],
    );
  }

  Widget _care() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Badge(icon: 'assets/icons/badge_herb.png'),
        const SizedBox(height: 18),
        _splitTitle('What do you ', 'care for?'),
        const SizedBox(height: 8),
        _note('Pick everything that applies.'),
        const SizedBox(height: 22),
        ChoiceCard(
          icon: 'assets/icons/icon_herb.png',
          title: 'Plants',
          subtitle: 'Succulents, tropicals & more',
          selected: _plants,
          onTap: () => setState(() => _plants = !_plants),
        ),
        const SizedBox(height: 16),
        ChoiceCard(
          icon: 'assets/icons/icon_paw.png',
          title: 'Pets',
          subtitle: 'Dogs, cats, and little ones',
          selected: _pets,
          onTap: () => setState(() => _pets = !_pets),
        ),
      ],
    );
  }

  Widget _counts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Badge(icon: 'assets/icons/badge_seedling.png'),
        const SizedBox(height: 18),
        const AuthHeadline(lead: 'How many', accent: 'do you have?'),
        const SizedBox(height: 8),
        _note("We'll set up the right number of care spots."),
        const SizedBox(height: 22),
        if (_plants)
          _Counter(
            icon: 'assets/icons/icon_herb.png',
            label: 'Plants',
            value: _plantCount,
            onChanged: (value) => setState(() => _plantCount = value),
          ),
        if (_plants && _pets) const SizedBox(height: 16),
        if (_pets)
          _Counter(
            icon: 'assets/icons/icon_paw.png',
            label: 'Pets',
            value: _petCount,
            onChanged: (value) => setState(() => _petCount = value),
          ),
      ],
    );
  }

  Widget _timeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Badge(icon: 'assets/icons/badge_sunrise.png'),
        const SizedBox(height: 18),
        const AuthHeadline(lead: "When's your", accent: 'care time?'),
        const SizedBox(height: 8),
        _note("We'll remind you at just the right moment."),
        const SizedBox(height: 22),
        ChoiceCard(
          icon: 'assets/icons/icon_sunrise.png',
          title: 'Morning',
          subtitle: 'Start the day right',
          selected: _times.contains('morning'),
          tall: false,
          onTap: () => _toggleTime('morning'),
        ),
        const SizedBox(height: 14),
        ChoiceCard(
          icon: 'assets/icons/icon_sun.png',
          title: 'Afternoon',
          subtitle: 'A midday check-in',
          selected: _times.contains('afternoon'),
          tall: false,
          onTap: () => _toggleTime('afternoon'),
        ),
        const SizedBox(height: 14),
        ChoiceCard(
          icon: 'assets/icons/icon_moon.png',
          title: 'Evening',
          subtitle: 'Wind down together',
          selected: _times.contains('evening'),
          tall: false,
          onTap: () => _toggleTime('evening'),
        ),
      ],
    );
  }

  Widget _levelStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Badge(icon: 'assets/icons/badge_tree.png'),
        const SizedBox(height: 18),
        const AuthHeadline(lead: "How green's", accent: 'your thumb?'),
        const SizedBox(height: 8),
        _note('No judgment, totally fine wherever you are.'),
        const SizedBox(height: 22),
        for (final option in _levels) ...[
          ChoiceCard(
            icon: option.$1,
            title: option.$2,
            subtitle: option.$3,
            selected: _level == option.$2,
            onTap: () => setState(() => _level = option.$2),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _passwordStep() {
    final value = _password.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuthHeadline(lead: 'Create your', accent: 'password.'),
        const SizedBox(height: 8),
        _note('Keep your care space all yours.'),
        const SizedBox(height: 22),
        AuthField(
          label: 'PASSWORD',
          controller: _password,
          hint: '••••••••',
          error: _passwordError,
          obscure: _obscure,
          suffix: IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.sproutGreen,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: authField,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _RuleChip('8+ characters', value.length >= 8),
                  _RuleChip('1 number', RegExp(r'\d').hasMatch(value)),
                  _RuleChip('1 uppercase', RegExp(r'[A-Z]').hasMatch(value)),
                  _RuleChip('1 special', RegExp(r'[^A-Za-z0-9]').hasMatch(value)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => setState(() => _agreed = !_agreed),
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _agreed ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.primary),
                ),
                child: _agreed
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    height: 21 / 14,
                    color: AppColors.onboardingBody,
                  ),
                  children: [
                    const TextSpan(text: "I agree to Sprout's "),
                    TextSpan(
                      text: 'Terms of use',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColors.sproutGreen,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.sproutGreen,
                      ),
                    ),
                    const TextSpan(text: ' & '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColors.sproutGreen,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.sproutGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _toggleTime(String id) {
    setState(() {
      if (!_times.add(id)) _times.remove(id);
    });
  }

  Widget _splitTitle(String lead, String accent) {
    final base = GoogleFonts.fraunces(
      fontSize: 33,
      fontWeight: FontWeight.w600,
      height: 36 / 33,
      letterSpacing: -1.3,
      color: authInk,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: lead),
          TextSpan(
            text: accent,
            style: base.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.sproutGreen,
            ),
          ),
        ],
      ),
      style: base,
    );
  }

  Widget _note(String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 14,
        height: 20 / 14,
        color: AppColors.onboardingBody,
      ),
    );
  }
}

const _levels = [
  ('assets/icons/icon_seedling.png', 'Just starting out', 'Learning as I go'),
  ('assets/icons/icon_herb.png', 'Getting the hang of it', 'Building good habits'),
  ('assets/icons/icon_tree.png', 'Seasoned caregiver', 'Been doing this a while'),
];

class _Badge extends StatelessWidget {
  const _Badge({required this.icon});

  final String icon;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      icon,
      width: 80,
      height: 80,
      filterQuality: FilterQuality.high,
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String icon;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: authField,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Image.asset(
            icon,
            width: 16,
            height: 16,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: authInk,
            ),
          ),
          const Spacer(),
          _stepButton('−', () => onChanged(value > 1 ? value - 1 : 1)),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: GoogleFonts.fraunces(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: authInk,
              ),
            ),
          ),
          _stepButton('+', () => onChanged(value + 1)),
        ],
      ),
    );
  }

  Widget _stepButton(String glyph, VoidCallback onTap) {
    return Material(
      color: AppColors.onboardingPaper,
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: const Color(0x1F006134),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Center(
            child: Text(
              glyph,
              style: GoogleFonts.dmSans(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip(this.label, this.met);

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: met ? AppColors.primary : const Color(0xFFD7EBD9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: met ? FontWeight.w700 : FontWeight.w500,
            color: met ? Colors.white : AppColors.onboardingBody,
          ),
        ),
      ),
    );
  }
}

const _avatars = [
  'assets/images/memoji_freckles.png',
  'assets/images/memoji_twists.png',
  'assets/images/memoji_cap.png',
  'assets/images/memoji_braids.png',
  'assets/images/memoji_bald.png',
  'assets/images/memoji_hijab.png',
  'assets/images/memoji_blue.png',
  'assets/images/memoji_curls.png',
];

class _AvatarPick {
  const _AvatarPick.memoji(this.index) : bytes = null;

  const _AvatarPick.photo(Uint8List this.bytes) : index = -1;

  const _AvatarPick.none() : index = -1, bytes = null;

  final int index;
  final Uint8List? bytes;
}

class _AvatarSheet extends StatelessWidget {
  const _AvatarSheet({required this.selected, this.photo});

  final int selected;
  final Uint8List? photo;

  Future<void> _upload(BuildContext context) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file == null || !context.mounted) return;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    Navigator.pop(context, _AvatarPick.photo(bytes));
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dotIdle,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const AuthHeadline(lead: 'Select an', accent: 'avatar.'),
            const SizedBox(height: 8),
            Text(
              'You can always change this later.',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                height: 20 / 14,
                color: AppColors.onboardingBody,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _avatars.length + 1,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                if (index == _avatars.length) {
                  return GestureDetector(
                    key: const Key('upload-avatar'),
                    onTap: () => _upload(context),
                    child: _UploadChoice(
                      photo: photo,
                      selected: selected < 0 && photo != null,
                    ),
                  );
                }
                return GestureDetector(
                  onTap: () => Navigator.pop(context, _AvatarPick.memoji(index)),
                  child: _AvatarChoice(
                    asset: _avatars[index],
                    selected: index == selected,
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, const _AvatarPick.none()),
                child: Text(
                  'Skip, do this later',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.sproutGreen,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({required this.asset, required this.selected});

  final String asset;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          painter: _DashedRingPainter(
            selected ? AppColors.sproutGreen : AppColors.dotIdle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: _MemojiFace(asset: asset),
          ),
        ),
        if (selected)
          const Positioned(
            top: -2,
            right: 2,
            child: _AvatarCheck(),
          ),
      ],
    );
  }
}

class _UploadChoice extends StatelessWidget {
  const _UploadChoice({required this.photo, required this.selected});

  final Uint8List? photo;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          painter: _DashedRingPainter(AppColors.sproutGreen),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: photo == null
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.field,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.file_upload_outlined,
                            color: AppColors.sproutGreen,
                            size: 22,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Upload image',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              height: 1.15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.sproutGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _MemojiFace(bytes: photo),
          ),
        ),
        if (selected)
          const Positioned(
            top: -2,
            right: 2,
            child: _AvatarCheck(),
          ),
      ],
    );
  }
}

class _AvatarCheck extends StatelessWidget {
  const _AvatarCheck();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.sproutGreen,
        shape: BoxShape.circle,
      ),
      child: Text(
        '✓',
        style: GoogleFonts.dmSans(
          fontSize: 13,
          height: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _MemojiFace extends StatelessWidget {
  const _MemojiFace({this.asset, this.bytes, this.initials = ''});

  final String? asset;
  final Uint8List? bytes;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: ColoredBox(
        color: AppColors.field,
        child: bytes != null
            ? Image.memory(bytes!, fit: BoxFit.cover)
            : asset != null
            ? Image.asset(asset!, fit: BoxFit.contain)
            : Center(
                child: initials.isEmpty
                    ? const Icon(Icons.person_outline, color: AppColors.sproutGreen, size: 36)
                    : Text(
                        initials,
                        style: GoogleFonts.fraunces(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sproutGreen,
                        ),
                      ),
              ),
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final radius = (size.shortestSide / 2) - 1;
    final center = Offset(size.width / 2, size.height / 2);
    const dashes = 18;
    const sweep = 3.1415926535 * 2 / dashes;
    const gap = sweep * 0.42;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep,
        sweep - gap,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
