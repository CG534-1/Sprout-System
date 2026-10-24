import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sprout/core/notifications/push_service.dart';
import 'package:sprout/core/widgets/person_avatar.dart';
import 'package:sprout/core/widgets/sprout_toast.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/data/models/care_settings.dart';
import 'package:sprout/data/models/user_profile.dart';
import 'package:sprout/data/providers.dart';
import 'package:sprout/features/profile/profile_providers.dart';
import 'package:sprout/features/profile/profile_sheets.dart';
import 'package:sprout/features/shell/care_nav.dart';
import 'package:sprout/features/shell/quiet_card.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _open(BuildContext context, Widget sheet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => sheet,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(careSettingsProvider, (previous, next) {
      // Asks for push once the saved settings first arrive, as opening
      // Profile always has.
      final settings = next.value;
      if (settings == null || (previous?.hasValue ?? false)) return;
      if (settings.wantsPush) ref.read(pushServiceProvider).enable();
    });
    final user = ref.watch(currentUserProvider);
    final statsLoad = ref.watch(profileStatsProvider);
    final stats = statsLoad.value ?? ProfileStats.empty;
    final settingsLoad = ref.watch(careSettingsProvider);
    final settings = settingsLoad.value ?? CareSettings.defaults;
    final settingsNotifier = ref.read(careSettingsProvider.notifier);

    // The sheets save the whole settings object, so opening one on the
    // defaults would overwrite the saved settings with them.
    bool settingsReady() {
      if (settingsLoad.hasValue) return true;
      if (settingsLoad.failedEmpty) {
        ref.invalidate(careSettingsProvider);
        showSproutToast(
          context,
          'Your settings could not load. Check your connection and try again.',
          error: true,
        );
      } else {
        showSproutToast(context, 'Your settings are still loading.');
      }
      return false;
    }

    return Scaffold(
      backgroundColor: AppColors.onboardingPaper,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, CareNav.scrollClearance(context)),
              children: [
                const SizedBox(height: 28),
                Center(child: _ProfileAvatar(user: user)),
                const SizedBox(height: 16),
                Text(
                  user?.name ?? 'Alex Morgan',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fraunces(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Growing a happier home 🌿',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.onboardingBody,
                  ),
                ),
                const SizedBox(height: 20),
                if (statsLoad.failedEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: LoadFailedCard(
                      title: 'Your progress could not load',
                      onRetry: () => ref
                        ..invalidate(homeProvider)
                        ..invalidate(profileStatsProvider),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        _Stat(
                          value: '${stats.plants}',
                          label: stats.plants == 1 ? 'plant' : 'plants',
                        ),
                        const SizedBox(width: 10),
                        _Stat(
                          value: '${stats.pets}',
                          label: stats.pets == 1 ? 'pet' : 'pets',
                        ),
                        const SizedBox(width: 10),
                        _Stat(
                          value: '${stats.streak}',
                          label: 'care streak',
                          accent: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _Week(
                      filled: stats.filled,
                      count: stats.filled.length,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'SETTINGS',
                    style: GoogleFonts.dmMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                      color: AppColors.onboardingBody,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _Settings(
                    onNotifications: () {
                      if (!settingsReady()) return;
                      final push = ref.read(pushServiceProvider);
                      if (settings.wantsPush) push.enable();
                      _open(
                        context,
                        NotificationsSheet(
                          reminders: settings.reminders,
                          overdue: settings.overdue,
                          summary: settings.summary,
                          tips: settings.tips,
                          onChanged: (reminders, overdue, summary, tips) {
                            settingsNotifier.save(
                              settingsNotifier.current.copyWith(
                                reminders: reminders,
                                overdue: overdue,
                                summary: summary,
                                tips: tips,
                              ),
                            );
                            if (reminders || overdue || summary) {
                              push.enable();
                            }
                          },
                        ),
                      );
                    },
                    onPreferences: () {
                      if (!settingsReady()) return;
                      _open(
                        context,
                        PreferencesSheet(
                          preferredSlots: {...settings.preferredSlots},
                          lead: settings.lead,
                          slotHours: settings.slotHours,
                          onChanged: (slots, lead, hours) {
                            settingsNotifier.save(
                              settingsNotifier.current.copyWith(
                                preferredSlots: slots.toList(),
                                lead: lead,
                                slotHours: hours,
                              ),
                            );
                          },
                        ),
                      );
                    },
                    onAccount: () => _open(context, AccountSheet(user: user)),
                    onAppearance: () => _open(context, const AppearanceSheet()),
                  ),
                ),
              ],
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: CareNav(tab: CareTab.profile),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user});

  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFEEF8F0),
        border: Border.all(color: const Color(0xFFDCFFE3), width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
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

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.accent = false});

  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 78),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: accent ? AppColors.field : AppColors.onboardingPaper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent ? AppColors.sproutGreen : AppColors.dotIdle,
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.fraunces(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: accent ? AppColors.primary : AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onboardingBody,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Week extends StatelessWidget {
  const _Week({required this.filled, required this.count});

  final Set<int> filled;
  final int count;

  @override
  Widget build(BuildContext context) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.onboardingPaper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dotIdle, width: 0.8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'THIS WEEK',
                style: GoogleFonts.dmMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                  color: AppColors.onboardingBody,
                ),
              ),
              const Spacer(),
              Text(
                '$count of 7 days',
                style: GoogleFonts.dmMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onboardingBody,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var index = 0; index < 7; index++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
                    child: Column(
                      children: [
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: filled.contains(index)
                                ? AppColors.sproutGreen
                                : AppColors.dotIdle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          letters[index],
                          style: GoogleFonts.dmMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onboardingBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Settings extends StatelessWidget {
  const _Settings({
    required this.onNotifications,
    required this.onPreferences,
    required this.onAccount,
    required this.onAppearance,
  });

  final VoidCallback onNotifications;
  final VoidCallback onPreferences;
  final VoidCallback onAccount;
  final VoidCallback onAppearance;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('🔔', 'Notifications', onNotifications),
      ('⏰', 'Care preferences', onPreferences),
      ('🔑', 'Account & security', onAccount),
      ('🎨', 'Appearance', onAppearance),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.onboardingPaper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.dotIdle, width: 0.8),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++)
            GestureDetector(
              onTap: rows[index].$3,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: index == rows.length - 1
                      ? null
                      : Border(bottom: BorderSide(color: AppColors.dotIdle, width: 0.8)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(rows[index].$1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        rows[index].$2,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      '›',
                      style: GoogleFonts.dmSans(fontSize: 18, color: AppColors.onboardingBody),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
