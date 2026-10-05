import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/core/router/routes.dart';
import 'package:sprout/core/widgets/person_avatar.dart';
import 'package:sprout/core/widgets/sprout_toast.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/core/theme/theme_controller.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/slot_hours.dart';
import 'package:sprout/data/models/user_profile.dart';
import 'package:sprout/data/services/auth_service.dart';
import 'package:sprout/features/care/care_sheet.dart';

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({
    super.key,
    required this.reminders,
    required this.overdue,
    required this.summary,
    required this.tips,
    required this.onChanged,
  });

  final bool reminders;
  final bool overdue;
  final bool summary;
  final bool tips;
  final void Function(bool reminders, bool overdue, bool summary, bool tips)
  onChanged;

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  late bool _reminders = widget.reminders;
  late bool _overdue = widget.overdue;
  late bool _summary = widget.summary;
  late bool _tips = widget.tips;

  void _set({bool? reminders, bool? overdue, bool? summary, bool? tips}) {
    setState(() {
      _reminders = reminders ?? _reminders;
      _overdue = overdue ?? _overdue;
      _summary = summary ?? _summary;
      _tips = tips ?? _tips;
    });
    widget.onChanged(_reminders, _overdue, _summary, _tips);
  }

  @override
  Widget build(BuildContext context) {
    return CareSheet(
      child: ListView(
        shrinkWrap: true,
        children: [
          const CareSheetHandle(),
          const _SheetTitle('Notifications'),
          Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              20,
              22,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose what Sprout keeps you in the loop about.',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.onboardingBody,
                  ),
                ),
                const SizedBox(height: 8),
                _ToggleRow(
                  emoji: '🔔',
                  title: 'Care reminders',
                  subtitle: 'Get notified when tasks are due',
                  on: _reminders,
                  onChanged: (value) => _set(reminders: value),
                ),
                _ToggleRow(
                  emoji: '⏰',
                  title: 'Overdue alerts',
                  subtitle: 'When a task has passed its time',
                  on: _overdue,
                  onChanged: (value) => _set(overdue: value),
                ),
                _ToggleRow(
                  emoji: '🌿',
                  title: 'Daily summary',
                  subtitle: 'A morning overview of your day',
                  on: _summary,
                  bordered: false,
                  onChanged: (value) => _set(summary: value),
                ),
                // Tips & insights is parked. Keep _tips on settings for a later push.
                // _ToggleRow(
                //   emoji: '💡',
                //   title: 'Tips & insights',
                //   subtitle: 'Seasonal care advice for your plants & pets',
                //   on: _tips,
                //   bordered: false,
                //   onChanged: (value) => _set(tips: value),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PreferencesSheet extends StatefulWidget {
  const PreferencesSheet({
    super.key,
    required this.preferredSlots,
    required this.lead,
    required this.slotHours,
    required this.onChanged,
  });

  final Set<CareSlot> preferredSlots;
  final String lead;
  final SlotHours slotHours;
  final void Function(Set<CareSlot> slots, String lead, SlotHours hours) onChanged;

  @override
  State<PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<PreferencesSheet> {
  late final Set<CareSlot> _slots = {...widget.preferredSlots};
  late String _lead = widget.lead;
  late SlotHours _hours = widget.slotHours;

  void _emit() => widget.onChanged({..._slots}, _lead, _hours);

  void _toggle(CareSlot slot) {
    setState(() {
      if (!_slots.add(slot) && _slots.length > 1) _slots.remove(slot);
    });
    _emit();
  }

  Future<void> _pickClock(CareSlot slot) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hours.of(slot),
    );
    if (picked == null || !mounted) return;
    setState(() => _hours = _hours.copyWithSlot(slot, picked));
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return CareSheet(
      child: ListView(
        shrinkWrap: true,
        children: [
          const CareSheetHandle(),
          const _SheetTitle('Care preferences'),
          Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              20,
              22,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set your default rhythm. You can override these on any plant or pet.',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.onboardingBody,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'PREFERRED TIME TO CARE',
                  style: GoogleFonts.dmMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                    color: AppColors.onboardingBody,
                  ),
                ),
                const SizedBox(height: 12),
                CareSlots(
                  selected: _slots,
                  clocks: _hours,
                  onToggle: _toggle,
                  onCustom: _pickClock,
                ),
                const SizedBox(height: 16),
                Text(
                  'REMIND ME HOW FAR IN ADVANCE?',
                  style: GoogleFonts.dmMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                    color: AppColors.onboardingBody,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final lead in [
                      '15 min before',
                      '30 min before',
                      '1 hour before',
                    ])
                      _LeadChip(
                        label: lead,
                        selected: _lead == lead,
                        onTap: () {
                          setState(() => _lead = lead);
                          _emit();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: CareCancelButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key, required this.user});

  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'Alex Morgan';
    final email = user?.email ?? '';
    return CareSheet(
      child: ListView(
        shrinkWrap: true,
        children: [
          const CareSheetHandle(),
          const _SheetTitle('Account & security'),
          Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              20,
              22,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.dotIdle, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      _AccountAvatar(user: user),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              email,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: AppColors.onboardingBody,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const _SectionLabel('SECURITY'),
                _AccountGroup(
                  rows: [
                    _AccountRow(
                      emoji: '🔑',
                      label: 'Change password',
                      onTap: () {
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.push(AppRoutes.forgotPassword);
                      },
                    ),
                    _AccountRow(
                      emoji: '✏️',
                      label: 'Update details',
                      onTap: () {
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.push(AppRoutes.updateDetails);
                      },
                    ),
                  ],
                ),
                const _SectionLabel('DANGER ZONE'),
                _AccountGroup(
                  rows: [
                    _AccountRow(
                      emoji: '👋',
                      label: 'Sign out',
                      onTap: () => showSignOutSheet(context),
                    ),
                    _AccountRow(
                      emoji: '🗑️',
                      label: 'Delete account',
                      danger: true,
                      onTap: () => showDeleteAccountSheet(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showSignOutSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return CareSheet(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            0,
            22,
            28 + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CareSheetHandle(),
              const SizedBox(height: 16),
              Text(
                'Sign out?',
                style: GoogleFonts.fraunces(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You will need to sign in again to see today\'s care.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.onboardingBody,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: BorderSide(color: AppColors.dotIdle),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DangerAction(
                      label: 'Sign out',
                      busyLabel: 'Signing out',
                      done: 'Signed out. See you soon.',
                      run: (auth) => auth.signOut(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showDeleteAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return CareSheet(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            0,
            22,
            28 + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CareSheetHandle(),
              const SizedBox(height: 16),
              Text(
                'Delete account?',
                style: GoogleFonts.fraunces(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This removes your plants, pets, and care history.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.onboardingBody,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: BorderSide(color: AppColors.dotIdle),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DangerAction(
                      label: 'Delete account',
                      busyLabel: 'Deleting',
                      done: 'Your account and its care are deleted.',
                      run: (auth) => auth.deleteAccount(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A confirm button that shows its own progress and reports what happened.
class _DangerAction extends StatefulWidget {
  const _DangerAction({
    required this.label,
    required this.busyLabel,
    required this.done,
    required this.run,
  });

  final String label;
  final String busyLabel;
  final String done;
  final Future<void> Function(AuthService auth) run;

  @override
  State<_DangerAction> createState() => _DangerActionState();
}

class _DangerActionState extends State<_DangerAction> {
  var _busy = false;

  Future<void> _press() async {
    if (_busy) return;
    setState(() => _busy = true);
    final auth = context.read<AuthService>();
    final router = GoRouter.of(context);
    final toast = sproutToaster(context);
    final navigator = Navigator.of(context);
    try {
      await widget.run(auth);
      navigator.pop();
      toast.show(widget.done);
      router.go(AppRoutes.signIn);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      toast.show(error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: _busy ? null : _press,
      style: FilledButton.styleFrom(
        backgroundColor: careRemove,
        foregroundColor: Colors.white,
        disabledBackgroundColor: careRemove.withValues(alpha: 0.6),
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_busy) ...[
            const SproutSpinner(size: 14),
            const SizedBox(width: 8),
          ],
          Text(
            _busy ? widget.busyLabel : widget.label,
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class AppearanceSheet extends StatelessWidget {
  const AppearanceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().label;
    const options = [
      ('☀️', 'Light', 'Bright & fresh'),
      ('🌙', 'Dark', 'Easy on the eyes'),
      ('📱', 'System', 'Match device'),
    ];
    return CareSheet(
      child: ListView(
        shrinkWrap: true,
        children: [
          const CareSheetHandle(),
          const _SheetTitle('Appearance'),
          Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              20,
              22,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose how Sprout looks on your device.',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.onboardingBody,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'COLOUR THEME',
                  style: GoogleFonts.dmMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                    color: AppColors.onboardingBody,
                  ),
                ),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < options.length; index++) ...[
                        if (index > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _ThemeCard(
                            emoji: options[index].$1,
                            title: options[index].$2,
                            subtitle: options[index].$3,
                            selected: theme == options[index].$2,
                            onTap: () => context.read<ThemeController>().select(
                              options[index].$2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: careField,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 166,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.dotIdle,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 110,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD7EBD9),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.dotIdle, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.fraunces(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          const CareCloseButton(),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.on,
    required this.onChanged,
    this.bordered = true,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool on;
  final ValueChanged<bool> onChanged;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: bordered
            ? Border(bottom: BorderSide(color: AppColors.dotIdle, width: 0.8))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: careField,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.onboardingBody,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!on),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 44,
              height: 26,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: on ? AppColors.sproutGreen : AppColors.dotIdle,
                borderRadius: BorderRadius.circular(999),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadChip extends StatelessWidget {
  const _LeadChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.dotIdle,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: selected ? Colors.white : AppColors.onboardingBody,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(
        label,
        style: GoogleFonts.dmMono(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
          color: AppColors.onboardingBody,
        ),
      ),
    );
  }
}

class _AccountGroup extends StatelessWidget {
  const _AccountGroup({required this.rows});

  final List<_AccountRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dotIdle, width: 0.8),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++)
            Container(
              decoration: BoxDecoration(
                border: index == rows.length - 1
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: AppColors.dotIdle,
                          width: 0.8,
                        ),
                      ),
              ),
              child: rows[index],
            ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.emoji,
    required this.label,
    this.danger = false,
    this.onTap,
  });

  final String emoji;
  final String label;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = danger ? careRemove : AppColors.ink;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            Text(
              '›',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                color: AppColors.onboardingBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.user});

  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFEEF8F0),
        border: Border.all(color: const Color(0xFFDCFFE3), width: 3),
      ),
      child: ClipOval(
        child: PersonAvatar(
          name: user?.name ?? '',
          avatarUrl: user?.avatarUrl,
          avatarBytes: user?.avatarBytes,
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
        decoration: BoxDecoration(
          color: selected ? careField : AppColors.onboardingPaper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.sproutGreen : AppColors.dotIdle,
            width: selected ? 1.4 : 0.8,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                height: 1.25,
                color: AppColors.onboardingBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
