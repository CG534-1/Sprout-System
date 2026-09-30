import 'dart:math' as math;

import 'package:flutter/material.dart';

class SplashCup extends StatefulWidget {
  const SplashCup({
    super.key,
    this.playing = false,
    this.filled = false,
    this.diameter = 142,
  });

  final bool playing;
  final bool filled;
  final double diameter;

  static const fill = Duration(seconds: 6);

  @override
  State<SplashCup> createState() => _SplashCupState();
}

class _SplashCupState extends State<SplashCup> with TickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: SplashCup.fill,
    value: widget.filled ? 1 : 0,
  );

  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _begin();
  }

  @override
  void didUpdateWidget(covariant SplashCup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !oldWidget.playing) _begin();
  }

  void _begin() {
    if (_fill.value < 1) _fill.forward();
    if (!_wave.isAnimating) _wave.repeat();
  }

  @override
  void dispose() {
    _fill.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.diameter,
      height: widget.diameter,
      child: AnimatedBuilder(
        animation: Listenable.merge([_fill, _wave]),
        builder: (context, child) {
          return CustomPaint(
            painter: _LiquidPainter(
              levelT: Curves.easeInOut.transform(_fill.value),
              phase: _wave.value,
            ),
            child: child,
          );
        },
        child: Image.asset(
          'assets/images/cup_outline.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  const _LiquidPainter({required this.levelT, required this.phase});

  final double levelT;
  final double phase;

  static final Path _backWave = _svgPath(
    'M5.62791 44.7345C1.43739 45.0173 -4.09302 49.2063 -4.09302 49.2063V220H59.3488V49.2063C59.3488 49.2063 53.8256 44.8873 49.6279 44.7345C45.0661 44.5683 43.4455 49.3724 38.8837 49.2063C34.6861 49.0534 33.3533 45.0173 29.1628 44.7345C24.2399 44.4022 22.3301 49.2063 17.3953 49.2063C12.4606 49.2063 10.5508 44.4022 5.62791 44.7345Z',
  );
  static final Path _frontWave = _svgPath(
    'M-8.46662 44.7534C-13.1978 45.0788 -19.4419 49.8976 -19.4419 49.8976V220H52.186V49.8976C52.186 49.8976 45.9501 44.9293 41.2108 44.7534C36.0604 44.5623 34.2306 50.0887 29.0803 49.8976C24.341 49.7217 22.8363 45.0788 18.105 44.7534C12.5469 44.3712 10.3907 49.8976 4.8192 49.8976C-0.752314 49.8976 -2.9085 44.3712 -8.46662 44.7534Z',
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(_cupInterior(size));
    final scaleX = size.width / 44;
    final scaleY = size.height / 55;
    final level = size.height * (0.8 + (0.36 - 0.8) * levelT);
    final drift = math.sin(phase * math.pi * 2) * size.width * 0.035;
    canvas.translate(drift, level - 45 * scaleY);
    canvas.scale(scaleX, scaleY);
    canvas.drawPath(
      _backWave,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF87DB6C), Color(0xFF179C46)],
        ).createShader(const Rect.fromLTWH(0, 40, 44, 180)),
    );
    canvas.drawPath(
      _frontWave,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA1FF83), Color(0xFF179C46)],
        ).createShader(const Rect.fromLTWH(-8, 40, 60, 180)),
    );
    canvas.restore();
  }

  Path _cupInterior(Size size) {
    double x(double fraction) => size.width * fraction;
    double y(double fraction) => size.height * fraction;
    return Path()
      ..moveTo(x(0.312), y(0.342))
      ..lineTo(x(0.374), y(0.792))
      ..quadraticBezierTo(x(0.50), y(0.832), x(0.626), y(0.792))
      ..lineTo(x(0.688), y(0.342))
      ..close();
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter oldDelegate) {
    return oldDelegate.levelT != levelT || oldDelegate.phase != phase;
  }
}

Path _svgPath(String data) {
  final path = Path();
  final tokens = RegExp(r'[MmCcLlHhVvZz]|-?\d*\.?\d+(?:e-?\d+)?')
      .allMatches(data)
      .map((match) => match.group(0)!)
      .toList();
  var index = 0;
  var command = '';
  var x = 0.0;
  var y = 0.0;
  double next() => double.parse(tokens[index++]);
  while (index < tokens.length) {
    if (RegExp('[A-Za-z]').hasMatch(tokens[index])) {
      command = tokens[index];
      index++;
      if (command == 'Z' || command == 'z') {
        path.close();
        continue;
      }
    }
    switch (command) {
      case 'M':
        x = next();
        y = next();
        path.moveTo(x, y);
      case 'C':
        final x1 = next();
        final y1 = next();
        final x2 = next();
        final y2 = next();
        x = next();
        y = next();
        path.cubicTo(x1, y1, x2, y2, x, y);
      case 'H':
        x = next();
        path.lineTo(x, y);
      case 'V':
        y = next();
        path.lineTo(x, y);
      default:
        break;
    }
  }
  return path;
}
