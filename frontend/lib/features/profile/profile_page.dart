import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/notifications/push_service.dart';
import 'package:sprout/core/widgets/person_avatar.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_settings.dart';
import 'package:sprout/data/models/slot_hours.dart';
import 'package:sprout/data/models/user_profile.dart';
import 'package:sprout/data/services/auth_service.dart';
import 'package:sprout/data/services/care_service.dart';
import 'package:sprout/data/services/pet_service.dart';
import 'package:sprout/data/services/plant_service.dart';
import 'package:sprout/data/services/profile_service.dart';
import 'package:sprout/features/profile/profile_sheets.dart';
import 'package:sprout/features/shell/care_nav.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  var _plants = 0;
  var _pets = 0;
  var _streak = 0;
  var _weekDays = 0;
  Set<int> _filled = {};
  var _reminders = true;
  var _overdue = true;
  var _summary = true;
  var _tips = false;
  final _preferredSlots = <CareSlot>{CareSlot.morning};
  var _lead = '30 min before';
  var _slotHours = SlotHours.defaults;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final plantService = context.read<PlantService>();
    final petService = context.read<PetService>();
    final care = context.read<CareService>();
    final profile = context.read<ProfileService>();
    final plants = await plantService.listPlants();
    final pets = await petService.listPets();
    final history = await care.history();
    final settings = await profile.settings();
    if (!mounted) return;
    final days = history.map((entry) => DateTime(entry.completedAt.year, entry.completedAt.month, entry.completedAt.day)).toSet();
    setState(() {
      _plants = plants.length;
      _pets = pets.length;
      _streak = _careStreak(days);
      _filled = _thisWeek(days);
      _weekDays = _filled.length;
      _reminders = settings.reminders;
      _overdue = settings.overdue;
      _summary = settings.summary;
      _tips = settings.tips;
      _preferredSlots
        ..clear()
        ..addAll(settings.preferredSlots);
      _lead = settings.lead;
      _slotHours = settings.slotHours;
    });
    if (settings.wantsPush) {
      await PushService.enable(profile);
    }
  }

  int _careStreak(Set<DateTime> days) {
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!days.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
    var count = 0;
    while (days.contains(cursor)) {
      count += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  Future<void> _saveSettings() {
    return context.read<ProfileService>().updateSettings(
      CareSettings(
        reminders: _reminders,
        overdue: _overdue,
        summary: _summary,
        tips: _tips,
        preferredSlots: _preferredSlots.toList(),
        lead: _lead,
        slotHours: _slotHours,
      ),
    );
  }

  Set<int> _thisWeek(Set<DateTime> days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return {
      for (var index = 0; index < 7; index++)
        if (days.contains(monday.add(Duration(days: index)))) index,
    };
  }

  void _open(Widget sheet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      _Stat(value: '$_plants', label: _plants == 1 ? 'plant' : 'plants'),
                      const SizedBox(width: 10),
                      _Stat(value: '$_pets', label: _pets == 1 ? 'pet' : 'pets'),
                      const SizedBox(width: 10),
                      _Stat(value: '$_streak', label: 'care streak', accent: true),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _Week(filled: _filled, count: _weekDays),
                ),
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
                      if (_reminders || _overdue || _summary) {
                        PushService.enable(context.read<ProfileService>());
                      }
                      _open(
                        NotificationsSheet(
                          reminders: _reminders,
                          overdue: _overdue,
                          summary: _summary,
                          tips: _tips,
                          onChanged: (reminders, overdue, summary, tips) {
                            setState(() {
                              _reminders = reminders;
                              _overdue = overdue;
                              _summary = summary;
                              _tips = tips;
                            });
                            _saveSettings();
                            if (reminders || overdue || summary) {
                              PushService.enable(context.read<ProfileService>());
                            }
                          },
                        ),
                      );
                    },
                    onPreferences: () => _open(
                      PreferencesSheet(
                        preferredSlots: _preferredSlots,
                        lead: _lead,
                        slotHours: _slotHours,
                        onChanged: (slots, lead, hours) {
                          setState(() {
                            _preferredSlots
                              ..clear()
                              ..addAll(slots);
                            _lead = lead;
                            _slotHours = hours;
                          });
                          _saveSettings();
                        },
                      ),
                    ),
                    onAccount: () => _open(AccountSheet(user: user)),
                    onAppearance: () => _open(const AppearanceSheet()),
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
