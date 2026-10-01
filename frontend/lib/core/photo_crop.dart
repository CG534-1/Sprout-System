import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sprout/core/app_exception.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/core/widgets/sprout_toast.dart';
import 'package:sprout/features/auth/auth_widgets.dart';
import 'package:sprout/features/care/care_sheet.dart';

Future<Uint8List?> showPhotoCrop(BuildContext context, Uint8List bytes) {
  return Navigator.of(context, rootNavigator: true).push<Uint8List>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PhotoCropPage(bytes: bytes),
    ),
  );
}

/// Maps a pan/zoom over a cover-fitted image onto a square of the original.
class PhotoCropTransform {
  const PhotoCropTransform({
    required this.image,
    required this.view,
    required this.zoom,
    required this.pan,
  });

  final Size image;
  final double view;
  final double zoom;
  final Offset pan;

  double get cover {
    if (image.width <= 0 || image.height <= 0 || view <= 0) return 1;
    return math.max(view / image.width, view / image.height);
  }

  double get scale => cover * zoom.clamp(1, 4);

  Offset get clampedPan {
    final shown = Size(image.width * scale, image.height * scale);
    final maxX = math.max(0.0, (shown.width - view) / 2);
    final maxY = math.max(0.0, (shown.height - view) / 2);
    return Offset(pan.dx.clamp(-maxX, maxX), pan.dy.clamp(-maxY, maxY));
  }

  Rect get source {
    final p = clampedPan;
    final s = scale;
    final left = (view - image.width * s) / 2 + p.dx;
    final top = (view - image.height * s) / 2 + p.dy;
    return Rect.fromLTWH(
      (0 - left) / s,
      (0 - top) / s,
      view / s,
      view / s,
    ).intersect(Offset.zero & image);
  }
}

class PhotoCropPage extends StatefulWidget {
  const PhotoCropPage({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<PhotoCropPage> createState() => _PhotoCropPageState();
}

class _PhotoCropPageState extends State<PhotoCropPage> {
  ui.Image? _image;
  var _zoom = 1.0;
  var _pan = Offset.zero;
  var _startZoom = 1.0;
  var _startPan = Offset.zero;
  var _busy = false;
  var _view = 240.0;
  Object? _failed;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => _image = frame.image);
    } catch (error) {
      if (!mounted) return;
      setState(() => _failed = error);
    }
  }

  PhotoCropTransform _transform(double view) {
    final image = _image;
    return PhotoCropTransform(
      image: image == null
          ? Size.zero
          : Size(image.width.toDouble(), image.height.toDouble()),
      view: view,
      zoom: _zoom,
      pan: _pan,
    );
  }

  Future<void> _use(double view) async {
    final image = _image;
    if (image == null || _busy) return;
    setState(() => _busy = true);
    try {
      final source = _transform(view).source;
      final cropped = await _encodeCrop(image, source);
      if (!mounted) return;
      Navigator.pop(context, cropped);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSproutToast(context, error.message, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSproutToast(
        context,
        'That photo could not be cropped. Try another.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onboardingPaper,
      body: SafeArea(
        child: Column(
          children: [
            CarePageHeader(
              title: 'Crop photo',
              subtitle: 'Drag and pinch to frame it',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                child: _stage(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: SlabButton(
                label: 'Use photo',
                busy: _busy,
                enabled: _image != null && !_busy,
                onPressed: _image == null ? null : () => _use(_view),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stage() {
    if (_failed != null) {
      return Center(
        child: Text(
          'That photo could not be opened. Try a different one.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: AppColors.onboardingBody,
          ),
        ),
      );
    }
    if (_image == null) {
      return const Center(
        child: SproutSpinner(color: AppColors.sproutGreen),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final view = math.min(box.maxWidth, box.maxHeight);
        _view = view;
        final transform = _transform(view);
        final pan = transform.clampedPan;
        return Center(
          child: SizedBox(
            width: view,
            height: view,
            child: GestureDetector(
              onScaleStart: (_) {
                _startZoom = _zoom;
                _startPan = _pan;
              },
              onScaleUpdate: (details) {
                setState(() {
                  _zoom = (_startZoom * details.scale).clamp(1.0, 4.0);
                  _pan = _startPan + details.focalPointDelta;
                  _pan = _transform(view).clampedPan;
                });
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipOval(
                    clipBehavior: Clip.hardEdge,
                    child: OverflowBox(
                      maxWidth: view * 4,
                      maxHeight: view * 4,
                      child: Transform.translate(
                        offset: pan,
                        child: Transform.scale(
                          scale: _zoom,
                          child: Image.memory(
                            widget.bytes,
                            fit: BoxFit.cover,
                            width: view,
                            height: view,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const IgnorePointer(
                    child: CustomPaint(painter: _CropRingPainter()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<Uint8List> _encodeCrop(ui.Image image, Rect source) async {
  const out = 512;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    image,
    source,
    Rect.fromLTWH(0, 0, out.toDouble(), out.toDouble()),
    Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high,
  );
  final picture = recorder.endRecording();
  final cropped = await picture.toImage(out, out);
  final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) {
    throw const AppException('That photo could not be cropped. Try another.');
  }
  return data.buffer.asUint8List();
}

class _CropRingPainter extends CustomPainter {
  const _CropRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.shortestSide / 2) - 1.4;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.sproutGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
