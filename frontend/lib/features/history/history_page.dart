import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_history_entry.dart';
import 'package:sprout/data/services/care_service.dart';
import 'package:sprout/data/services/pet_service.dart';
import 'package:sprout/data/services/plant_service.dart';
import 'package:sprout/features/shell/care_nav.dart';

const _mint = Color(0xFF87DB6C);

enum _Filter { all, plants, pets }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  var _filter = _Filter.all;
  var _loading = true;
  List<CareHistoryEntry> _entries = [];
  Map<String, String> _photos = {};
  CareService? _care;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _care = context.read<CareService>()..addListener(_load);
      _load();
    });
  }

  @override
  void dispose() {
    _care?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final care = _care;
    if (care == null || !mounted) return;
    final plants = context.read<PlantService>();
    final pets = context.read<PetService>();
    final bundled = await (care.history(), plants.listPlants(), pets.listPets()).wait;
    if (!mounted) return;
    final photos = <String, String>{};
    for (final plant in bundled.$2) {
      final url = plant.photoUrl;
      if (url != null) photos[plant.name] = url;
    }
    for (final pet in bundled.$3) {
      final url = pet.photoUrl;
      if (url != null) photos[pet.name] = url;
    }
    final entries = List<CareHistoryEntry>.of(bundled.$1)
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    setState(() {
      _entries = entries;
      _photos = photos;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final visible = _entries.where((entry) {
      return switch (_filter) {
        _Filter.all => true,
        _Filter.plants => entry.subjectType == CareSubjectType.plant,
        _Filter.pets => entry.subjectType == CareSubjectType.pet,
      };
    }).toList();
    final monthCount = _entries
        .where((entry) => entry.completedAt.year == now.year && entry.completedAt.month == now.month)
        .length;

    return Scaffold(
      backgroundColor: AppColors.onboardingPaper,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
              children: [
                Text(
                  'A LITTLE PROGRESS, EVERY DAY',
                  style: GoogleFonts.dmMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.9,
                    color: AppColors.sproutGreen,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Care history',
                  style: GoogleFonts.fraunces(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.6,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monthCount == 1 ? '1 care moment' : '$monthCount care moments',
                        style: GoogleFonts.fraunces(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'completed this month',
                        style: GoogleFonts.dmSans(fontSize: 11, height: 1.5, color: _mint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    _HistoryChip(
                      label: 'All',
                      selected: _filter == _Filter.all,
                      onTap: () => setState(() => _filter = _Filter.all),
                    ),
                    const SizedBox(width: 7),
                    _HistoryChip(
                      label: 'Plants',
                      selected: _filter == _Filter.plants,
                      onTap: () => setState(() => _filter = _Filter.plants),
                    ),
                    const SizedBox(width: 7),
                    _HistoryChip(
                      label: 'Pets',
                      selected: _filter == _Filter.pets,
                      onTap: () => setState(() => _filter = _Filter.pets),
                    ),
                  ],
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 28),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: Text(
                      'Nothing completed yet.',
                      style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.onboardingBody),
                    ),
                  )
                else
                  for (var index = 0; index < visible.length; index++) ...[
                    if (index == 0 || !_sameDay(visible[index].completedAt, visible[index - 1].completedAt))
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Text(
                          DateFormat('EEEE, MMM d').format(visible[index].completedAt).toUpperCase(),
                          style: GoogleFonts.dmMono(
                            fontSize: 10,
                            color: AppColors.onboardingBody,
                          ),
                        ),
                      ),
                    _HistoryRow(
                      entry: visible[index],
                      photo: _photos[visible[index].subjectName],
                    ),
                  ],
              ],
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: CareNav(tab: CareTab.history),
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
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
            fontSize: 12,
            height: 1.5,
            color: selected ? Colors.white : AppColors.onboardingBody,
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.photo});

  final CareHistoryEntry entry;
  final String? photo;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = entry.completedAt.year == now.year &&
        entry.completedAt.month == now.month &&
        entry.completedAt.day == now.day;
    final when = today
        ? 'Today, ${DateFormat('h:mm a').format(entry.completedAt)}'
        : DateFormat('MMM d, h:mm a').format(entry.completedAt);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.dotIdle, width: 0.8)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 43,
              height: 43,
              child: photo == null
                  ? ColoredBox(color: AppColors.field)
                  : Image.asset(photo!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.action.past} ${entry.subjectName}',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  when,
                  style: GoogleFonts.dmMono(fontSize: 10, color: AppColors.onboardingBody),
                ),
              ],
            ),
          ),
          Container(
            width: 21,
            height: 21,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.field,
              shape: BoxShape.circle,
            ),
            child: Text(
              '✓',
              style: GoogleFonts.dmSans(fontSize: 12, height: 1, color: AppColors.sproutGreen),
            ),
          ),
        ],
      ),
    );
  }
}
