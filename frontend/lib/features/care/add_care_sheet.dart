import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/core/photo_picker.dart';
import 'package:sprout/core/widgets/person_avatar.dart';
import 'package:sprout/core/router/routes.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/core/widgets/sprout_toast.dart';
import 'package:sprout/data/models/care_enums.dart';
import 'package:sprout/data/models/care_schedule.dart';
import 'package:sprout/features/care/care_schedule_page.dart';
import 'package:sprout/features/care/care_sheet.dart';

class CareDraft {
  const CareDraft({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    this.species = '',
    this.breed = '',
    this.photoUrl,
    this.photoBytes,
    this.location,
    this.notes,
    this.schedules = const [],
  });

  final String id;
  final String name;
  final CareSubjectType type;
  final DateTime createdAt;
  final String species;
  final String breed;
  final String? photoUrl;
  final Uint8List? photoBytes;
  final String? location;
  final String? notes;
  final List<CareSchedule> schedules;
}

/// Who the details page is for: a new plant or pet, or someone already in
/// your care.
class CareDetailsArgs {
  const CareDetailsArgs({required this.plant, this.existing});

  final bool plant;
  final CareDraft? existing;
}

/// Asks only whether this is a plant or a pet. The fields and the plan are
/// long, so they each get a page of their own after this.
Future<void> showAddCareSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _KindSheet(),
  );
}

class _KindSheet extends HookWidget {
  const _KindSheet();

  @override
  Widget build(BuildContext context) {
    final plant = useState(true);

    void next() {
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push(
        AppRoutes.careDetails,
        extra: CareDetailsArgs(plant: plant.value),
      );
    }

    return CareSheet(
      child: ListView(
        shrinkWrap: true,
        children: [
          const CareSheetHandle(),
          const CareSheetHeader(title: 'Add to your care'),
          Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              20,
              22,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CareChoice(
                        emoji: '🌿',
                        title: 'Plant',
                        subtitle: 'Watering reminders & schedule',
                        selected: plant.value,
                        onTap: () => plant.value = true,
                      ),
                      const SizedBox(width: 10),
                      CareChoice(
                        emoji: '🐾',
                        title: 'Pet',
                        subtitle: 'Feeding, water bowl & walks',
                        selected: !plant.value,
                        onTap: () => plant.value = false,
                      ),
                    ],
                  ),
                ),
                CareActionButton(
                  label: 'Next',
                  enabled: true,
                  onPressed: next,
                ),
                CareCancelButton(
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The name, photo and notes, for a new plant or pet or for one already in
/// your care. A page rather than a sheet, because there is a lot to fill in
/// and the plan still has to follow.
class CareDetailsPage extends HookWidget {
  const CareDetailsPage({super.key, required this.args});

  final CareDetailsArgs args;

  @override
  Widget build(BuildContext context) {
    final existing = args.existing;
    final plant = args.plant;
    final name = useTextEditingController(text: existing?.name ?? '');
    final species = useTextEditingController(text: existing?.species ?? '');
    final breed = useTextEditingController(text: existing?.breed ?? '');
    final location = useTextEditingController(text: existing?.location ?? '');
    final notes = useTextEditingController(text: existing?.notes ?? '');
    // Only the name decides whether the plan can open.
    useListenable(name);
    final nameFocus = useFocusNode();
    final speciesFocus = useFocusNode();
    final breedFocus = useFocusNode();
    final locationFocus = useFocusNode();
    final notesFocus = useFocusNode();
    final photo = useState(existing?.photoBytes);
    // Guards against a second tap while the picker is open. It does not
    // repaint the page, so it lives in a ref rather than in state.
    final picking = useRef(false);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusManager.instance.primaryFocus?.unfocus();
      });
      return null;
    }, const []);

    final named = name.text.trim().isNotEmpty;

    void leave() {
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go(AppRoutes.myCare);
    }

    /// Hands over to the plan, which is a page of its own because pet plans
    /// are long. This step is left behind, so a back from the plan lands on
    /// My care rather than halfway through the form.
    void openSchedule() {
      if (!named) return;
      final scheduleArgs = CareScheduleArgs(
        plant: plant,
        name: name.text.trim(),
        species: species.text.trim(),
        breed: breed.text.trim(),
        location: location.text.trim(),
        notes: notes.text.trim(),
        photo: photo.value,
        existing: existing,
      );
      final router = GoRouter.of(context);
      if (router.canPop()) router.pop();
      router.push(AppRoutes.schedule, extra: scheduleArgs);
    }

    Future<void> pickPhoto(BuildContext from) async {
      if (picking.value) return;
      picking.value = true;
      try {
        final bytes = await pickCarePhoto(from: from);
        if (!context.mounted) return;
        if (bytes != null) photo.value = bytes;
      } on AppException catch (error) {
        if (!context.mounted) return;
        showSproutToast(context, error.message, error: true);
      } finally {
        picking.value = false;
      }
    }

    void ignore(String _) {}

    List<Widget> nameFields() {
      return [
        const CareLabel('PHOTO', top: 18),
        Builder(
          builder: (context) => GestureDetector(
            onTap: () => pickPhoto(context),
            child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: picking.value
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: careField,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SproutSpinner(color: AppColors.sproutGreen),
                        ),
                      )
                    : photo.value != null || existing?.photoUrl != null
                    ? SproutCirclePhoto(
                        url: photo.value == null ? existing?.photoUrl : null,
                        bytes: photo.value,
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: careField,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            plant ? '🌿' : '🐾',
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Text(
                picking.value
                    ? 'Opening your photos'
                    : photo.value == null && existing?.photoUrl == null
                    ? 'Add a photo'
                    : 'Change photo',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF006134),
                ),
              ),
            ],
          ),
          ),
        ),
        CareLabel(plant ? 'PLANT NAME' : 'PET NAME'),
        CareNameField(
          controller: name,
          focusNode: nameFocus,
          hint: plant ? 'e.g. Monstera, Snake Plant…' : 'e.g. Milo',
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => speciesFocus.requestFocus(),
          onChanged: ignore,
        ),
        CareLabel(plant ? 'SPECIES (OPTIONAL)' : 'PET TYPE (OPTIONAL)'),
        CareNameField(
          controller: species,
          focusNode: speciesFocus,
          hint: plant ? 'e.g. Monstera deliciosa' : 'e.g. Dog',
          textInputAction: TextInputAction.next,
          onSubmitted: (_) =>
              plant ? locationFocus.requestFocus() : breedFocus.requestFocus(),
          onChanged: ignore,
        ),
        if (!plant) ...[
          const CareLabel('BREED (OPTIONAL)'),
          CareNameField(
            controller: breed,
            focusNode: breedFocus,
            hint: 'e.g. Golden Retriever',
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => notesFocus.requestFocus(),
            onChanged: ignore,
          ),
        ],
        if (plant) ...[
          const CareLabel('WHERE IT LIVES'),
          CareNameField(
            controller: location,
            focusNode: locationFocus,
            hint: 'e.g. Living room',
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => notesFocus.requestFocus(),
            onChanged: ignore,
          ),
        ],
        const CareLabel('NOTES'),
        CareNameField(
          controller: notes,
          focusNode: notesFocus,
          hint: 'Anything worth remembering',
          maxLines: 3,
          onChanged: ignore,
        ),
      ];
    }

    return Focus(
      autofocus: true,
      child: Scaffold(
        backgroundColor: AppColors.onboardingPaper,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              CarePageHeader(
                title: existing != null
                    ? 'Edit details'
                    : plant
                    ? 'Add a plant'
                    : 'Add a pet',
                subtitle: existing?.name ?? '',
                onBack: leave,
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    22,
                    6,
                    22,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  children: nameFields(),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  22,
                  0,
                  22,
                  12 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  children: [
                    CareActionButton(
                      label: 'Set up care schedule →',
                      enabled: named,
                      top: 10,
                      onPressed: openSchedule,
                    ),
                    CareCancelButton(onPressed: leave),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
