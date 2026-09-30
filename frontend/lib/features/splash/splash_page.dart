import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/data/services/auth_service.dart';
import 'package:sprout/features/onboarding/onboarding_page.dart';
import 'package:sprout/features/splash/splash_cup.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  static const hold = Duration(milliseconds: 6600);
  static const reveal = Duration(milliseconds: 1400);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  final _potKey = GlobalKey();
  final _slotKey = GlobalKey();
  var _playing = false;
  var _revealing = false;
  Rect? _from;
  Rect? _to;
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: SplashPage.reveal,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startWhenReady());
  }

  Future<void> _startWhenReady() async {
    if (!mounted) return;
    final bundle = DefaultAssetBundle.of(context);
    await Future.wait([
      bundle.load('assets/images/cup_outline.png'),
      bundle.load('assets/images/onboarding_home.png'),
      bundle.loadString('assets/icons/splash_wave_front.svg'),
      bundle.loadString('assets/icons/splash_wave_back.svg'),
    ]);
    if (!mounted) return;
    setState(() => _playing = true);
    Future<void>.delayed(SplashPage.hold, () {
      if (!mounted) return;
      final from = _rectOf(_potKey);
      setState(() {
        _from = from;
        _revealing = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fly());
    });
  }

  void _fly() {
    if (!mounted) return;
    setState(() => _to = _rectOf(_slotKey) ?? _from);
    _flight.forward();
    Future<void>.delayed(SplashPage.reveal, () {
      if (!mounted) return;
      context.read<AuthService>().markSplashSeen();
    });
  }

  Rect? _rectOf(GlobalKey key) {
    final target = key.currentContext?.findRenderObject() as RenderBox?;
    final stack = context.findRenderObject() as RenderBox?;
    if (target == null ||
        stack == null ||
        !target.hasSize ||
        !stack.hasSize) {
      return null;
    }
    final topLeft = stack.globalToLocal(target.localToGlobal(Offset.zero));
    return topLeft & target.size;
  }

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final from = _from;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_revealing)
          OnboardingPage(markKey: _slotKey, showMark: false)
        else
          const SizedBox.shrink(),
        AnimatedBuilder(
          animation: _flight,
          builder: (context, child) {
            final faded = const Interval(
              0,
              0.62,
              curve: Curves.easeOut,
            ).transform(_flight.value);
            return Opacity(opacity: 1 - faded, child: child);
          },
          child: IgnorePointer(child: _splashScene()),
        ),
        if (_revealing && from != null)
          AnimatedBuilder(
            animation: _flight,
            builder: (context, child) {
              final move = Curves.easeInOutCubic.transform(_flight.value);
              final rect = Rect.lerp(from, _to ?? from, move)!;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: rect.left,
                    top: rect.top,
                    width: rect.width,
                    height: rect.height,
                    child: FittedBox(child: child),
                  ),
                ],
              );
            },
            child: SplashCup(key: _potKey, playing: _playing, diameter: 98),
          ),
      ],
    );
  }

  Widget _splashScene() {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.splashTop,
        body: SizedBox.expand(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.splashTop, AppColors.sproutGreen],
              ),
            ),
            child: Column(
              children: [
                const Spacer(),
                _SplashCircle(
                  child: _revealing
                      ? const SizedBox(width: 98, height: 98)
                      : SplashCup(
                          key: _potKey,
                          playing: _playing,
                          diameter: 98,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  'sprout',
                  style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 114),
                const _SplashWaves(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashCircle extends StatelessWidget {
  const _SplashCircle({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      height: 142,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFFF4F4F4),
          shape: BoxShape.circle,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _SplashWaves extends StatelessWidget {
  const _SplashWaves();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 225,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: SvgPicture.asset(
              'assets/icons/splash_wave_back.svg',
              fit: BoxFit.fill,
            ),
          ),
          SizedBox(
            height: 171,
            width: double.infinity,
            child: SvgPicture.asset(
              'assets/icons/splash_wave_front.svg',
              fit: BoxFit.fill,
            ),
          ),
        ],
      ),
    );
  }
}
