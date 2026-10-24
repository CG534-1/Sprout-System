import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/providers.dart';
import 'package:sprout/features/care/add_care_sheet.dart';
import 'package:sprout/features/care/care_detail_sheet.dart';
import 'package:sprout/features/care/care_sheet.dart';
import 'package:sprout/features/care/my_care_providers.dart';
import 'package:sprout/features/shell/care_nav.dart';
import 'package:sprout/features/shell/quiet_card.dart';

enum _Filter { all, plants, pets }

class MyCarePage extends HookConsumerWidget {
  const MyCarePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = useState(_Filter.all);
    final selectedFilter = filter.value;
    final load = ref.watch(careMembersProvider);
    final loaded = load.value;
    final failed = load.failedEmpty;
    final loading = loaded == null && !failed;
    final members = loaded ?? const <CareMember>[];
    final visible = switch (selectedFilter) {
      _Filter.all => members,
      _Filter.plants =>
        members.where((item) => item.type == CareSubjectType.plant).toList(),
      _Filter.pets =>
        members.where((item) => item.type == CareSubjectType.pet).toList(),
    };
    return Scaffold(
      backgroundColor: AppColors.onboardingPaper,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, CareNav.scrollClearance(context)),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR LITTLE FAMILY',
                            style: GoogleFonts.dmMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.9,
                              color: AppColors.sproutGreen,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'My care',
                            style: GoogleFonts.fraunces(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1.6,
                              color: careInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      key: const Key('add-care'),
                      onTap: () => showAddCareSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.sproutGreen,
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.splashTop,
                              offset: Offset(3, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '＋ Add',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (members.isNotEmpty) ...[
                  Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: selectedFilter == _Filter.all,
                        onTap: () => filter.value = _Filter.all,
                      ),
                      const SizedBox(width: 7),
                      _FilterChip(
                        label: 'Plants',
                        selected: selectedFilter == _Filter.plants,
                        onTap: () => filter.value = _Filter.plants,
                      ),
                      const SizedBox(width: 7),
                      _FilterChip(
                        label: 'Pets',
                        selected: selectedFilter == _Filter.pets,
                        onTap: () => filter.value = _Filter.pets,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                if (failed)
                  LoadFailedCard(
                    title: 'Your care could not load',
                    onRetry: () => ref
                      ..invalidate(homeProvider)
                      ..invalidate(careMembersProvider),
                  )
                else if (loading)
                  const SizedBox(height: 120)
                else if (members.isEmpty)
                  QuietCard(
                    icon: Icons.yard_outlined,
                    title: 'No one to care for yet',
                    body: 'Add a plant or a pet. You can set their routine when you are ready.',
                    action: 'Add someone',
                    onAction: () => showAddCareSheet(context),
                  )
                else if (visible.isEmpty)
                  QuietCard(
                    icon: selectedFilter == _Filter.pets
                        ? Icons.pets_outlined
                        : Icons.spa_outlined,
                    title: selectedFilter == _Filter.pets
                        ? 'No pets yet'
                        : 'No plants yet',
                    body: 'This filter is empty. The rest of your home is still on All.',
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = (constraints.maxWidth - 12) / 2;
                      final extent = (cardWidth * 0.7 + 84).clamp(200.0, 228.0);
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: visible.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: extent,
                        ),
                        itemBuilder: (context, index) =>
                            _Card(member: visible[index]),
                      );
                    },
                  ),
              ],
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CareNav(tab: CareTab.care),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
            color: selected ? Colors.white : AppColors.onboardingBody,
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.member});

  final CareMember member;

  @override
  Widget build(BuildContext context) {
    final plant = member.type == CareSubjectType.plant;
    return GestureDetector(
      onTap: () => showCareDetailSheet(
        context,
        CareDraft(
          id: member.id,
          name: member.name,
          type: member.type,
          createdAt: member.createdAt,
          species: member.species,
          breed: member.breed,
          photoUrl: member.photoUrl,
          photoBytes: member.photoBytes,
          location: member.location,
          notes: member.notes,
          schedules: member.schedules,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.onboardingPaper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.dotIdle, width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (member.photoBytes != null || member.photoUrl != null)
                    CarePhoto(url: member.photoUrl, bytes: member.photoBytes)
                  else
                    ColoredBox(color: careField),
                  const Positioned(
                    top: 4,
                    right: 10,
                    child: Text(
                      '›',
                      style: TextStyle(fontSize: 18, color: Color(0xFF4C7259)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 0),
              child: Text(
                plant ? 'Plant' : 'Pet',
                style: GoogleFonts.dmMono(
                  fontSize: 10,
                  color: AppColors.sproutGreen,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 5, 11, 0),
              child: Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: careInk,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 5, 11, 10),
              child: Text(
                member.line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  height: 1.3,
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
