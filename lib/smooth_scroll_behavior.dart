import 'package:flutter/material.dart';

/// Applies iOS-style bouncing scroll physics on all platforms and removes the
/// overscroll glow, giving a smoother, more native feel without touching the
/// colour scheme or layout.
class SmoothScrollBehavior extends ScrollBehavior {
  const SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Bounces on both iOS & Android for a smoother perception of scrolling.
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    // Disable the default blue glow effect.
    return child;
  }
}