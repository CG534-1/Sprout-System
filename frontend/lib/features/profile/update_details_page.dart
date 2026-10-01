import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/core/photo_picker.dart';
import 'package:sprout/core/widgets/person_avatar.dart';
import 'package:sprout/core/widgets/sprout_toast.dart';
import 'package:sprout/core/router/routes.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/data/services/auth_service.dart';
import 'package:sprout/features/auth/auth_validators.dart';
import 'package:sprout/features/auth/auth_widgets.dart';
import 'package:sprout/features/care/care_sheet.dart';

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

class UpdateDetailsPage extends StatefulWidget {
  const UpdateDetailsPage({super.key});

  @override
  State<UpdateDetailsPage> createState() => _UpdateDetailsPageState();
}

class _UpdateDetailsPageState extends State<UpdateDetailsPage> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  var _avatar = -1;
  Uint8List? _photo;
  var _keepRemoteAvatar = false;
  var _saving = false;
  String? _nameError;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _name = TextEditingController(text: user?.name ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _photo = user?.avatarBytes;
    final url = user?.avatarUrl;
    final index = _avatars.indexOf(url ?? '');
    if (_photo == null && index >= 0) {
      _avatar = index;
    } else if (_photo == null &&
        url != null &&
        url.isNotEmpty &&
        !url.startsWith('assets/')) {
      _keepRemoteAvatar = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await showModalBottomSheet<_AvatarChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _AvatarSheet(selected: _photo == null ? _avatar : -1, photo: _photo),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (picked.bytes != null) {
        _photo = picked.bytes;
        _keepRemoteAvatar = false;
      } else {
        _photo = null;
        _avatar = picked.index;
        _keepRemoteAvatar = false;
      }
    });
  }

  Future<void> _save() async {
    final nameError = _name.text.trim().isEmpty ? 'Enter your name.' : null;
    final emailError = validateEmail(_email.text);
    setState(() {
      _nameError = nameError;
      _emailError = emailError;
    });
    if (nameError != null || emailError != null || _saving) return;
    setState(() => _saving = true);
    final auth = context.read<AuthService>();
    final previous = auth.currentUser?.email ?? '';
    final next = _email.text.trim();
    final changing = next.toLowerCase() != previous.toLowerCase();
    final avatarUrl = _photo == null && !_keepRemoteAvatar
        ? (_avatar >= 0 ? _avatars[_avatar] : '')
        : null;
    final toast = sproutToaster(context);
    try {
      await auth.updateDetails(
        name: _name.text,
        email: changing ? previous : next,
        avatarUrl: avatarUrl,
        avatarBytes: _photo,
      );
      if (!mounted) return;
      if (!changing) {
        toast.show('Your details are saved.');
        context.pop();
        return;
      }
      await auth.requestEmailChange(email: next);
      if (!mounted) return;
      setState(() => _saving = false);
      toast.show('We sent a code to $next.');
      final ok = await context.push<bool>(
        '${AppRoutes.verifyEmail}?email=${Uri.encodeQueryComponent(next)}&current=${Uri.encodeQueryComponent(previous)}&purpose=email_change',
      );
      if (!mounted || ok != true) return;
      setState(() => _saving = true);
      await auth.updateDetails(
        name: _name.text,
        email: next,
        avatarUrl: avatarUrl,
        avatarBytes: _photo,
      );
      if (!mounted) return;
      toast.show('Your email is now $next.');
      context.pop();
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _emailError = error.message;
        _saving = false;
      });
      toast.show(error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onboardingPaper,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: AuthBackButton(onPressed: () => context.pop()),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  children: [
                    Text(
                      'Update details',
                      style: GoogleFonts.fraunces(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1.2,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Change your name, email, or avatar.',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.onboardingBody,
                      ),
                    ),
                    const SizedBox(height: 22),
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Row(
                        children: [
                          ClipOval(
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: ColoredBox(
                                color: AppColors.field,
                                child: PersonAvatar(
                                  name: _name.text,
                                  avatarBytes: _photo,
                                  avatarUrl: _photo != null
                                      ? null
                                      : _keepRemoteAvatar
                                      ? context
                                            .read<AuthService>()
                                            .currentUser
                                            ?.avatarUrl
                                      : _avatar >= 0
                                      ? _avatars[_avatar]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Change avatar',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    AuthField(
                      label: 'NAME',
                      controller: _name,
                      hint: 'Your name',
                      error: _nameError,
                    ),
                    const SizedBox(height: 14),
                    AuthField(
                      label: 'EMAIL',
                      controller: _email,
                      hint: 'you@example.com',
                      error: _emailError,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
              SlabButton(
                label: _saving ? 'Saving' : 'Save details',
                enabled: !_saving,
                busy: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarChoice {
  const _AvatarChoice.memoji(this.index) : bytes = null;
  const _AvatarChoice.photo(Uint8List this.bytes) : index = -1;
  const _AvatarChoice.none() : index = -1, bytes = null;

  final int index;
  final Uint8List? bytes;
}

class _AvatarSheet extends StatefulWidget {
  const _AvatarSheet({required this.selected, this.photo});

  final int selected;
  final Uint8List? photo;

  @override
  State<_AvatarSheet> createState() => _AvatarSheetState();
}

class _AvatarSheetState extends State<_AvatarSheet> {
  var _busy = false;

  int get selected => widget.selected;

  Uint8List? get photo => widget.photo;

  Future<void> _upload(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await pickCarePhoto(from: context);
      if (!mounted) return;
      if (bytes == null) {
        setState(() => _busy = false);
        return;
      }
      if (!context.mounted) return;
      Navigator.pop(context, _AvatarChoice.photo(bytes));
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSproutToast(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CareSheet(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        children: [
          const CareSheetHandle(),
          const SizedBox(height: 12),
          Text(
            'Select an avatar',
            style: GoogleFonts.fraunces(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You can always change this later.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
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
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              if (index == _avatars.length) {
                return GestureDetector(
                  onTap: () => _upload(context),
                  child: _Face(
                    selected: selected < 0 && photo != null,
                    child: _busy
                        ? const Center(
                            child: SproutSpinner(color: AppColors.sproutGreen),
                          )
                        : photo == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.file_upload_outlined,
                                color: AppColors.sproutGreen,
                              ),
                              Text(
                                'Upload image',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.sproutGreen,
                                ),
                              ),
                            ],
                          )
                        : SproutCirclePhoto(bytes: photo),
                  ),
                );
              }
              return GestureDetector(
                onTap: () =>
                    Navigator.pop(context, _AvatarChoice.memoji(index)),
                child: _Face(
                  selected: index == selected,
                  child: Image.asset(_avatars[index], fit: BoxFit.contain),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context, const _AvatarChoice.none()),
            child: Text(
              'Skip, do this later',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.sproutGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.sproutGreen : AppColors.dotIdle,
          width: selected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ClipOval(
          clipBehavior: Clip.hardEdge,
          child: ColoredBox(
            color: AppColors.field,
            child: SizedBox.expand(child: child),
          ),
        ),
      ),
    );
  }
}
