import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/core/widgets/sprout_toast.dart';
import 'package:sprout/data/models/care_enums.dart';

const careRemove = Color(0xFFC0392B);

Color get careInk => AppColors.ink;
Color get careField => AppColors.field;

class CareSheet extends StatelessWidget {
  const CareSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Material(
              color: AppColors.onboardingPaper,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class CareSheetHandle extends StatelessWidget {
  const CareSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12),
      child: Center(
        child: SizedBox(
          width: 36,
          height: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.dotIdle,
              borderRadius: BorderRadius.all(Radius.circular(9)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The title bar for a care flow that takes the whole screen.
class CarePageHeader extends StatelessWidget {
  const CarePageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 22, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.dotIdle, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.fraunces(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: careInk,
                  ),
                ),
                if (subtitle.trim().isNotEmpty)
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
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

class CareSheetHeader extends StatelessWidget {
  const CareSheetHeader({
    super.key,
    required this.title,
    this.onBack,
  });

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.dotIdle, width: 0.8)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: Text(
                  '←',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    height: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              textAlign: onBack == null ? TextAlign.start : TextAlign.center,
              style: GoogleFonts.fraunces(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: careInk,
              ),
            ),
          ),
          if (onBack != null) const SizedBox(width: 8),
          const CareCloseButton(),
        ],
      ),
    );
  }
}

class CareCloseButton extends StatelessWidget {
  const CareCloseButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: careField,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '✕',
          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.onboardingBody),
        ),
      ),
    );
  }
}

class CareChoice extends StatelessWidget {
  const CareChoice({
    super.key,
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
          decoration: BoxDecoration(
            color: selected ? careField : AppColors.onboardingPaper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.sproutGreen : AppColors.dotIdle,
              width: 0.8,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28, height: 1.4)),
              const SizedBox(height: 6),
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : careInk,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  height: 1.4,
                  color: AppColors.onboardingBody,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CareLabel extends StatelessWidget {
  const CareLabel(this.text, {super.key, this.top = 22});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 9),
      child: Text(
        text,
        style: GoogleFonts.dmMono(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: AppColors.onboardingBody,
        ),
      ),
    );
  }
}

class CareNameField extends StatelessWidget {
  const CareNameField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.dmSans(fontSize: 14, color: careInk),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(fontSize: 14, color: AppColors.onboardingBody),
        filled: true,
        fillColor: careField,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.dotIdle, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
    );
  }
}

class CareChip extends StatelessWidget {
  const CareChip({
    super.key,
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
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
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
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : careInk,
          ),
        ),
      ),
    );
  }
}

class CareSlots extends StatelessWidget {
  const CareSlots({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  final Set<CareSlot> selected;
  final ValueChanged<CareSlot> onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final slot in CareSlot.values) ...[
          if (slot != CareSlot.morning) const SizedBox(width: 8),
          Expanded(
            child: _SlotCard(
              slot: slot,
              selected: selected.contains(slot),
              onTap: () => onToggle(slot),
            ),
          ),
        ],
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final CareSlot slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
        decoration: BoxDecoration(
          color: selected ? careField : AppColors.onboardingPaper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.sproutGreen : AppColors.dotIdle,
            width: 0.8,
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Text(slot.mark, style: const TextStyle(fontSize: 22, height: 1.4)),
                const SizedBox(height: 4),
                Text(
                  slot.label,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.primary : careInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  slot.clock,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.onboardingBody,
                  ),
                ),
              ],
            ),
            if (selected)
              const Positioned(top: 0, right: 0, child: _SlotCheck()),
          ],
        ),
      ),
    );
  }
}

class _SlotCheck extends StatelessWidget {
  const _SlotCheck();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.sproutGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '✓',
        style: GoogleFonts.dmMono(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}

class CarePhoto extends StatelessWidget {
  const CarePhoto({super.key, this.url, this.bytes, this.fit = BoxFit.cover});

  final String? url;
  final Uint8List? bytes;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return careImage(url: url, bytes: bytes, fit: fit);
  }
}

Widget careImage({String? url, Uint8List? bytes, BoxFit fit = BoxFit.cover}) {
  if (bytes != null) return Image.memory(bytes, fit: fit);
  final path = url?.trim() ?? '';
  if (path.isEmpty) return ColoredBox(color: careField);
  if (path.startsWith('assets/')) return Image.asset(path, fit: fit);
  return Image.network(
    path,
    fit: fit,
    errorBuilder: (context, error, stack) => ColoredBox(color: careField),
  );
}

class CareActionButton extends StatelessWidget {
  const CareActionButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.busy = false,
    this.top = 26,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final bool busy;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? const [
                    BoxShadow(color: AppColors.splashTop, offset: Offset(3, 3)),
                  ]
                : null,
          ),
          child: Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 50,
                width: double.infinity,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (busy) ...[
                        const SproutSpinner(size: 15),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        label,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
