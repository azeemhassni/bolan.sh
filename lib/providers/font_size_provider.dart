import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages the terminal font size with increase/decrease/reset.
///
/// Clamped between 8 and 32. Default is 13.
class FontSizeNotifier extends Notifier<double> {
  static const _default = 13.0;
  static const _min = 8.0;
  static const _max = 32.0;

  @override
  double build() => _default;

  void increase() => state = (state + 1).clamp(_min, _max);

  void decrease() => state = (state - 1).clamp(_min, _max);

  void reset() => state = _default;

  void setSize(double size) => state = size.clamp(_min, _max);
}

final fontSizeProvider =
    NotifierProvider<FontSizeNotifier, double>(FontSizeNotifier.new);
