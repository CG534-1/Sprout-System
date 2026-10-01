import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/core/widgets/person_avatar.dart';
import 'package:sprout/core/widgets/sprout_check.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_task.dart';
import 'package:sprout/data/models/user_profile.dart';
import 'package:sprout/data/services/auth_service.dart';
import 'package:sprout/data/services/care_service.dart';
import 'package:sprout/data/services/pet_service.dart';
import 'package:sprout/data/services/plant_service.dart';
import 'package:sprout/data/services/profile_service.dart';
import 'package:sprout/features/care/add_care_sheet.dart';
import 'package:sprout/features/shell/care_nav.dart';
import 'package:sprout/features/shell/quiet_card.dart';
import 'package:sprout/features/today/bell_sheet.dart';
import 'package:sprout/features/today/calendar_sheet.dart';


class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  List<CareTask> _today = [];
  CareTask? _upcoming;
  Map<String, String> _photos = {};
  var _loading = true;
  var _unread = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final care = context.read<CareService>();
    final plants = context.read<PlantService>();
    final pets = context.read<PetService>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bundled = await (
      care.tasksFor(today),
      plants.listPlants(),
      pets.listPets(),
      _nextTask(care, today),
    ).wait;
    if (!mounted) return;
    final photos = <String, String>{};
    for (final plant in bundled.$2) {
      final url = plant.photoUrl;
      if (url != null) photos[plant.id] = url;
    }
    for (final pet in bundled.$3) {
      final url = pet.photoUrl;
      if (url != null) photos[pet.id] = url;
    }
    setState(() {
      _today = List<CareTask>.of(bundled.$1)
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      _photos = photos;
      _upcoming = bundled.$4;
      _loading = false;
    });
    await _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await context.read<ProfileService>().notifications();
    if (!mounted) return;
    setState(() => _unread = notes.where((note) => !note.read).length);
  }

  Future<void> _openBell() async {
    await showBellSheet(context);
    if (mounted) await _loadNotes();
  }

  Future<CareTask?> _nextTask(CareService care, DateTime today) async {
    for (var offset = 1; offset <= 7; offset++) {
      final tasks = await care.tasksFor(today.add(Duration(days: offset)));
      final open = tasks.where((task) => task.status != TaskStatus.done);
      if (open.isNotEmpty) {
        return (open.toList()..sort((a, b) => a.dueAt.compareTo(b.dueAt))).first;
      }
    }
    return null;
  }

  Future<void> _toggle(CareTask task) async {
    final care = context.read<CareService>();
    if (task.status == TaskStatus.done) {
      await care.reopenTask(task.id);
    } else {
      await care.completeTask(task.id);
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final name = user?.name ?? 'there';
    final first = name.trim().split(RegExp(r'\s+')).first;
    final done = _today.where((task) => task.status == TaskStatus.done).length;
    final caughtUp = _today.isNotEmpty && done == _today.length;
    final quiet = !_loading && _today.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.onboardingPaper,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
              children: [
                _Header(
                  firstName: first,
                  user: user,
                  unread: _unread,
                  onBell: _openBell,
                ),
                const SizedBox(height: 24),
                _Hero(count: _today.length, caughtUp: caughtUp, quiet: quiet),
                const SizedBox(height: 26),
                _SectionTitle(
                  title: "Today's care",
                  trailing: _loading || quiet
                      ? ''
                      : '$done/${_today.length} complete',
                ),
                const SizedBox(height: 12),
                if (quiet)
                  QuietCard(
                    icon: Icons.spa_outlined,
                    title: 'Your home is empty',
                    body: 'Add a plant or a pet. Their care will show up here.',
                    action: 'Add someone',
                    onAction: () async {
                      await showAddCareSheet(context);
                      if (mounted) await _load();
                    },
                  ),
                for (final task in _today) ...[
                  _TaskCard(
                    task: task,
                    photo: _photos[task.subjectId],
                    onComplete: () => _toggle(task),
                  ),
                  const SizedBox(height: 9),
                ],
                if (caughtUp) ...[
                  const SizedBox(height: 1),
                  const _CaughtUpNote(),
                ],
                if (!quiet && !_loading) ...[
                  const SizedBox(height: 18),
                  const _SectionTitle(
                    title: 'Coming up',
                    trailing: _CalendarLink(),
                  ),
                  const SizedBox(height: 12),
                  if (_upcoming != null)
                    _UpcomingCard(
                      task: _upcoming!,
                      photo: _photos[_upcoming!.subjectId],
                    )
                  else
                    const _QuietLine('Nothing else this week.'),
                ],
              ],
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CareNav(tab: CareTab.today),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.firstName,
    required this.user,
    required this.unread,
    required this.onBell,
  });

  final String firstName;
  final UserProfile? user;
  final int unread;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final hello = hour < 12
        ? 'Good morning,'
        : hour < 17
        ? 'Good afternoon,'
        : 'Good evening,';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMMM d').format(now).toUpperCase(),
                style: GoogleFonts.dmMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.9,
                  color: AppColors.sproutGreen,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                hello,
                style: GoogleFonts.fraunces(
                  fontSize: 33,
                  fontWeight: FontWeight.w600,
                  height: 1.06,
                  letterSpacing: -1.1,
                  color: AppColors.ink,
                ),
              ),
              Text(
                '$firstName.',
                style: GoogleFonts.fraunces(
                  fontSize: 33,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  height: 1.06,
                  letterSpacing: -1.1,
                  color: AppColors.sproutGreen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _Bell(unread: unread, onTap: onBell),
        const SizedBox(width: 10),
        _MemojiAvatar(user: user),
      ],
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.dotIdle, width: 0.8),
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/icons/icon_bell.svg',
                  width: 18,
                  height: 18,
                ),
              ),
              if (unread > 0)
                Positioned(
                  right: -2,
                  top: -3,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.sproutGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFEEF8F0), width: 0.8),
                    ),
                    child: Text(
                      unread > 9 ? '9' : '$unread',
                      style: GoogleFonts.dmMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemojiAvatar extends StatelessWidget {
  const _MemojiAvatar({required this.user});

  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.splashTop, width: 2.5),
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

class _Hero extends StatelessWidget {
  const _Hero({required this.count, required this.caughtUp, required this.quiet});

  final int count;
  final bool caughtUp;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final title = caughtUp
        ? 'All caught up! 🌿'
        : quiet
        ? 'A quiet day'
        : '$count care ${count == 1 ? 'task' : 'tasks'} today';
    final body = caughtUp
        ? 'The ones you love are cared for.'
        : quiet
        ? 'Nothing is due until someone joins your home.'
        : 'A little attention goes a long way.';
    return Container(
      height: caughtUp ? 123 : 120,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: caughtUp ? null : AppColors.primary,
        gradient: caughtUp
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.sproutGreen],
              )
            : null,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -46,
            top: caughtUp ? 12 : 10,
            child: Container(
              width: 158,
              height: 158,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 0.8,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(21, 21, 21, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR DAY, GENTLY',
                  style: GoogleFonts.dmMono(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: caughtUp
                        ? Colors.white.withValues(alpha: 0.65)
                        : AppColors.splashTop,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  style: GoogleFonts.fraunces(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: caughtUp ? 0.95 : 1),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: caughtUp ? 0.95 : 0.7),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.trailing});

  final String title;
  final Object trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.fraunces(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const Spacer(),
        if (trailing is Widget) trailing as Widget,
        if (trailing is String && (trailing as String).isNotEmpty)
          Text(
            trailing as String,
            style: GoogleFonts.dmMono(fontSize: 10, color: AppColors.onboardingBody),
          ),
      ],
    );
  }
}

class _CalendarLink extends StatelessWidget {
  const _CalendarLink();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const Key('view-calendar'),
      onPressed: () => showCalendarSheet(context),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppColors.sproutGreen,
      ),
      child: Text(
        'View calendar →',
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.sproutGreen,
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.photo,
    required this.onComplete,
  });

  final CareTask task;
  final String? photo;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.done;
    return Opacity(
      opacity: done ? 0.54 : 1,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppColors.onboardingPaper,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: AppColors.dotIdle, width: 0.8),
        ),
        child: Row(
          children: [
            _Photo(path: photo, size: 50, radius: 12),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${task.subjectType.label} · ${DateFormat('h:mm a').format(task.dueAt)}',
                    style: GoogleFonts.dmMono(
                      fontSize: 10,
                      color: AppColors.onboardingBody,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.ink, height: 1.5),
                      children: [
                        TextSpan(text: '${task.action.label} '),
                        TextSpan(
                          text: task.subjectName,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _Check(done: done, onPressed: onComplete, id: task.id),
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.done, required this.onPressed, required this.id});

  final bool done;
  final VoidCallback onPressed;
  final String id;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('complete-$id'),
      onTap: onPressed,
      child: done
          ? const SproutCheck(size: 28)
          : Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.dotIdle, width: 0.8),
              ),
            ),
    );
  }
}

class _QuietLine extends StatelessWidget {
  const _QuietLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(fontSize: 14, height: 1.4, color: AppColors.onboardingBody),
    );
  }
}

class _CaughtUpNote extends StatelessWidget {
  const _CaughtUpNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('🌿', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All caught up for today',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Come back tomorrow for your next round of care.',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: AppColors.onboardingBody,
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

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.task, required this.photo});

  final CareTask task;
  final String? photo;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(task.dueAt.year, task.dueAt.month, task.dueAt.day);
    final days = due.difference(today).inDays;
    final when = days == 1 ? 'In 1 day' : 'In $days days';
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          _Photo(path: photo, size: 47, radius: 11),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('EEE').format(task.dueAt).toUpperCase()} · ${DateFormat('h:mm a').format(task.dueAt)}',
                  style: GoogleFonts.dmMono(
                    fontSize: 10,
                    color: AppColors.onboardingBody,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${task.action.label} ${task.subjectName}',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  when,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.onboardingBody,
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

class _Photo extends StatelessWidget {
  const _Photo({required this.path, required this.size, required this.radius});

  final String? path;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: path == null
            ? ColoredBox(color: AppColors.field)
            : Image.asset(path!, fit: BoxFit.cover),
      ),
    );
  }
}
