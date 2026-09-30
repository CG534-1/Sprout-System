import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/core/widgets/sprout_check.dart';
import 'package:sprout/data/services/auth_service.dart';
import 'package:sprout/features/auth/auth_widgets.dart';
import 'package:sprout/features/splash/splash_cup.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.markKey, this.showMark = true});

  final Key? markKey;
  final bool showMark;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _Slide {
  const _Slide({
    required this.image,
    required this.title,
    required this.emphasis,
    required this.body,
    this.shade,
    this.foreground,
  });

  final String image;
  final String title;
  final String emphasis;
  final String body;
  final Color? shade;
  final Widget? foreground;
}

const _slides = [
  _Slide(
    image: 'assets/images/onboarding_home.png',
    shade: Color(0x2E081A0F),
    title: 'Care for your',
    emphasis: 'whole home.',
    body: 'Plants and pets, together in one calm place. A tiny ritual with a big difference.',
  ),
  _Slide(
    image: 'assets/images/onboarding_dog.png',
    title: 'Never wonder',
    emphasis: 'what’s due.',
    body: 'From Monstera’s weekly drink to Milo’s evening walk, Sprout keeps the rhythm for you.',
    foreground: _WalkChip(),
  ),
  _Slide(
    image: 'assets/images/onboarding_plant.png',
    title: 'All set for',
    emphasis: 'today.',
    body: 'See what needs your attention, then get back to enjoying the ones you care for.',
    foreground: _TodayCard(),
  ),
];

class _OnboardingPageState extends State<OnboardingPage> {
  static const _beat = Duration(milliseconds: 3200);
  static const _fade = Duration(milliseconds: 1400);

  Timer? _timer;
  var _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_beat, (_) {
      if (!mounted) return;
      setState(() => _page = (_page + 1) % _slides.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    context.read<AuthService>().completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.onboardingPaper,
      body: SizedBox.expand(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  AnimatedSwitcher(
                    duration: _fade,
                    switchInCurve: Curves.easeInOutCubic,
                    switchOutCurve: Curves.easeInOutCubic,
                    layoutBuilder: (current, previous) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [...previous, if (current != null) current],
                      );
                    },
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: _PhotoFrame(
                      key: ValueKey(slide.image),
                      slide: slide,
                    ),
                  ),
                  Positioned(
                    left: 22,
                    top: topInset + 14,
                    child: Row(
                      children: [
                        SizedBox(
                          key: widget.markKey,
                          width: 36,
                          height: 36,
                          child: widget.showMark
                              ? const SplashCup(filled: true, diameter: 36)
                              : null,
                        ),
                        const SizedBox(width: 2),
                        Transform.translate(
                          offset: const Offset(-6, 0),
                          child: Text(
                            'sprout',
                            style: GoogleFonts.fraunces(
                              fontSize: 25,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: -1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ColoredBox(
              color: AppColors.onboardingPaper,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(25, 23, 25, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PageDots(page: _page),
                    const SizedBox(height: 8),
                    _DissolvingCopy(slide: slide),
                    const SizedBox(height: 28),
                    _StartSproutButton(
                      key: const Key('onboarding-continue'),
                      onPressed: _start,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({super.key, required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _KenBurnsPhoto(image: slide.image),
        if (slide.shade != null) ColoredBox(color: slide.shade!),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0x5C183D2D)],
              stops: [0.45, 1],
            ),
          ),
        ),
        ?slide.foreground,
      ],
    );
  }
}

class _KenBurnsPhoto extends StatefulWidget {
  const _KenBurnsPhoto({required this.image});

  final String image;

  @override
  State<_KenBurnsPhoto> createState() => _KenBurnsPhotoState();
}

class _KenBurnsPhotoState extends State<_KenBurnsPhoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _zoom = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..forward();

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _zoom,
        builder: (context, child) {
          return Transform.scale(
            scale: 1 + (0.045 * _zoom.value),
            child: child,
          );
        },
        child: SizedBox.expand(
          child: Image.asset(widget.image, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _DissolvingCopy extends StatefulWidget {
  const _DissolvingCopy({required this.slide});

  final _Slide slide;

  @override
  State<_DissolvingCopy> createState() => _DissolvingCopyState();
}

class _DissolvingCopyState extends State<_DissolvingCopy>
    with SingleTickerProviderStateMixin {
  late _Slide _slide;
  var _ticket = 0;
  late final AnimationController _visibility = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 480),
  );

  @override
  void initState() {
    super.initState();
    _slide = widget.slide;
  }

  @override
  void didUpdateWidget(covariant _DissolvingCopy oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.slide.title != oldWidget.slide.title) {
      _swap(widget.slide);
    }
  }

  Future<void> _swap(_Slide next) async {
    final ticket = ++_ticket;
    await _visibility.animateTo(0, curve: Curves.easeInCubic);
    if (!mounted || ticket != _ticket) return;
    setState(() => _slide = next);
    await _visibility.animateTo(1, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _visibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _visibility,
      builder: (context, child) {
        final shown = _visibility.value;
        return Opacity(
          opacity: shown,
          child: Transform.translate(
            offset: Offset(0, (1 - shown) * 8),
            child: child,
          ),
        );
      },
      child: _CopyBlock(slide: _slide),
    );
  }
}

class _CopyBlock extends StatelessWidget {
  const _CopyBlock({super.key, required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${slide.title}\n'),
              TextSpan(
                text: slide.emphasis,
                style: GoogleFonts.fraunces(
                  fontSize: 33,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  height: 35 / 33,
                  letterSpacing: -1.8,
                  color: AppColors.sproutGreen,
                ),
              ),
            ],
          ),
          style: GoogleFonts.fraunces(
            fontSize: 33,
            fontWeight: FontWeight.w600,
            height: 35 / 33,
            letterSpacing: -1.8,
            color: AppColors.onboardingInk,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 279,
          height: 56,
          child: Text(
            slide.body,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              height: 18.5 / 13,
              color: AppColors.onboardingBody,
            ),
          ),
        ),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < 3; index++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
            width: index == page ? 44 : 24,
            height: 4,
            decoration: BoxDecoration(
              color: index == page ? AppColors.primary : AppColors.dotIdle,
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          if (index < 2) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _StartSproutButton extends StatelessWidget {
  const _StartSproutButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 61,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned(
            left: 7,
            right: 0,
            top: 3,
            height: 53,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x9C006134),
                borderRadius: BorderRadius.circular(9),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 7,
            top: 0,
            height: 58,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(9),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(9),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24, right: 10),
                    child: Row(
                      children: [
                        Text(
                          'Start Sprout',
                          style: GoogleFonts.fraunces(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const Spacer(),
                        const ButtonArrow(),
                      ],
                    ),
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

class _WalkChip extends StatelessWidget {
  const _WalkChip();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xE8FFFDF9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24163322),
              blurRadius: 25,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Milo’s walk',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  height: 1.2,
                  color: const Color(0xFF173F2E),
                ),
              ),
              Text(
                '7:00 PM',
                style: GoogleFonts.dmMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  color: const Color(0xFF377856),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 22,
      right: 22,
      bottom: 22,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xEBF8FEF9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E006134),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY',
                      style: GoogleFonts.dmMono(
                        fontSize: 10,
                        color: AppColors.sproutGreen,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Water Monstera',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 21 / 14,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '9:00 AM · Due now',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        height: 16.5 / 11,
                        color: AppColors.onboardingBody,
                      ),
                    ),
                  ],
                ),
              ),
              const SproutCheck(),
            ],
          ),
        ),
      ),
    );
  }
}
