import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sprout/data/models/user_profile.dart';
import 'package:sprout/data/providers.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/core/photo_picker.dart';
import 'package:sprout/core/widgets/person_avatar.dart';
import 'package:sprout/core/widgets/sprout_toast.dart';
import 'package:sprout/core/router/routes.dart';
import 'package:sprout/core/theme/app_colors.dart';
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

/// How the page opens: the avatar the account already has.
class _StartingAvatar {
  _StartingAvatar(UserProfile? user) : photo = user?.avatarBytes {
    final url = user?.avatarUrl;
    final index = _avatars.indexOf(url ?? '');
    if (photo == null && index >= 0) {
      avatar = index;
    } else if (photo == null &&
        url != null &&
        url.isNotEmpty &&
        !url.startsWith('assets/')) {
      keepRemote = true;
    }
  }

  final Uint8List? photo;
  var avatar = -1;
  var keepRemote = false;
}

class UpdateDetailsPage extends HookConsumerWidget {
  const UpdateDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read once: the form starts from the account and then belongs to the person.
    final user = useMemoized(() => ref.read(authServiceProvider).currentUser);
    final starting = useMemoized(() => _StartingAvatar(user));
    final name = useTextEditingController(text: user?.name ?? '');
    final email = useTextEditingController(text: user?.email ?? '');
    final avatar = useState(starting.avatar);
    final photo = useState(starting.photo);
    final keepRemoteAvatar = useState(starting.keepRemote);
    final saving = useState(false);
    final nameError = useState<String?>(null);
    final emailError = useState<String?>(null);

    Future<void> pickAvatar() async {
      final picked = await showModalBottomSheet<_AvatarChoice>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _AvatarSheet(
          selected: photo.value == null ? avatar.value : -1,
          photo: photo.value,
        ),
      );
      if (picked == null || !context.mounted) return;
      if (picked.bytes != null) {
        photo.value = picked.bytes;
      } else {
        photo.value = null;
        avatar.value = picked.index;
      }
      keepRemoteAvatar.value = false;
    }

    Future<void> save() async {
      final nameFailure = name.text.trim().isEmpty ? 'Enter your name.' : null;
      final emailFailure = validateEmail(email.text);
      nameError.value = nameFailure;
      emailError.value = emailFailure;
      if (nameFailure != null || emailFailure != null || saving.value) return;
      saving.value = true;
      final auth = ref.read(authServiceProvider);
      final previous = auth.currentUser?.email ?? '';
      final next = email.text.trim();
      final changing = next.toLowerCase() != previous.toLowerCase();
      final avatarUrl = photo.value == null && !keepRemoteAvatar.value
          ? (avatar.value >= 0 ? _avatars[avatar.value] : '')
          : null;
      final toast = sproutToaster(context);
      try {
        await auth.updateDetails(
          name: name.text,
          email: changing ? previous : next,
          avatarUrl: avatarUrl,
          avatarBytes: photo.value,
        );
        if (!context.mounted) return;
        if (!changing) {
          toast.show('Your details are saved.');
          context.pop();
          return;
        }
        await auth.requestEmailChange(email: next);
        if (!context.mounted) return;
        saving.value = false;
        toast.show('We sent a code to $next.');
        final ok = await context.push<bool>(
          '${AppRoutes.verifyEmail}?email=${Uri.encodeQueryComponent(next)}&current=${Uri.encodeQueryComponent(previous)}&purpose=email_change',
        );
        if (!context.mounted || ok != true) return;
        saving.value = true;
        await auth.updateDetails(
          name: name.text,
          email: next,
          avatarUrl: avatarUrl,
          avatarBytes: photo.value,
        );
        if (!context.mounted) return;
        toast.show('Your email is now $next.');
        context.pop();
      } on AppException catch (error) {
        if (!context.mounted) return;
        emailError.value = error.message;
        saving.value = false;
        toast.show(error.message, error: true);
      }
    }

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
                      onTap: pickAvatar,
                      child: Row(
                        children: [
                          ClipOval(
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: ColoredBox(
                                color: AppColors.field,
                                child: PersonAvatar(
                                  name: name.text,
                                  avatarBytes: photo.value,
                                  avatarUrl: photo.value != null
                                      ? null
                                      : keepRemoteAvatar.value
                                      ? ref.read(authServiceProvider).currentUser?.avatarUrl
                                      : avatar.value >= 0
                                      ? _avatars[avatar.value]
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
                      controller: name,
                      hint: 'Your name',
                      error: nameError.value,
                    ),
                    const SizedBox(height: 14),
                    AuthField(
                      label: 'EMAIL',
                      controller: email,
                      hint: 'you@example.com',
                      error: emailError.value,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
              SlabButton(
                label: saving.value ? 'Saving' : 'Save details',
                enabled: !saving.value,
                busy: saving.value,
                onPressed: save,
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

class _AvatarSheet extends HookWidget {
  const _AvatarSheet({required this.selected, this.photo});

  final int selected;
  final Uint8List? photo;

  @override
  Widget build(BuildContext context) {
    // Guards against a second tap while the picker is open. It does not
    // repaint the sheet, so it lives in a ref rather than in state.
    final busy = useRef(false);

    Future<void> upload(BuildContext context) async {
      if (busy.value) return;
      busy.value = true;
      try {
        final bytes = await pickCarePhoto(from: context);
        if (bytes == null || !context.mounted) return;
        Navigator.pop(context, _AvatarChoice.photo(bytes));
      } on AppException catch (error) {
        if (!context.mounted) return;
        showSproutToast(context, error.message, error: true);
      } finally {
        busy.value = false;
      }
    }

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
                  onTap: () => upload(context),
                  child: _Face(
                    selected: selected < 0 && photo != null,
                    child: busy.value
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
