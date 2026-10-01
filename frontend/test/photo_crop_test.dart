import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprout/core/photo_crop.dart';

void main() {
  test('a cover crop keeps the short side filled', () {
    const transform = PhotoCropTransform(
      image: Size(200, 100),
      view: 100,
      zoom: 1,
      pan: Offset.zero,
    );
    expect(transform.source.width, 100);
    expect(transform.source.height, 100);
    expect(transform.source.left, 50);
    expect(transform.source.top, 0);
  });

  test('pan stays inside the image so the frame never goes empty', () {
    const transform = PhotoCropTransform(
      image: Size(200, 100),
      view: 100,
      zoom: 1,
      pan: Offset(400, 80),
    );
    expect(transform.clampedPan, const Offset(50, 0));
    expect(transform.source.left, 0);
    expect(transform.source.top, 0);
  });

  test('zoom in crops a smaller square of the original', () {
    const transform = PhotoCropTransform(
      image: Size(200, 200),
      view: 100,
      zoom: 2,
      pan: Offset.zero,
    );
    expect(transform.source.width, 100);
    expect(transform.source.height, 100);
    expect(transform.source.left, 50);
  });
}
