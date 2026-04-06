import 'package:flutter/material.dart';

import '../../core/theme/bolan_theme.dart';

/// Minimal color picker popup with hex input and HSV gradient.
class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final BolonTheme theme;

  const ColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.theme,
  });

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late HSVColor _hsv;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
    _hexController = TextEditingController(text: _colorToHex(widget.initialColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color c) {
    return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final currentColor = _hsv.toColor();

    return Dialog(
      backgroundColor: theme.blockBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Saturation/Value gradient
            SizedBox(
              width: 248,
              height: 180,
              child: GestureDetector(
                onPanDown: (d) => _updateSV(d.localPosition, const Size(248, 180)),
                onPanUpdate: (d) => _updateSV(d.localPosition, const Size(248, 180)),
                child: CustomPaint(
                  painter: _SVPainter(_hsv),
                  size: const Size(248, 180),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Hue slider
            SizedBox(
              width: 248,
              height: 20,
              child: GestureDetector(
                onPanDown: (d) => _updateHue(d.localPosition.dx, 248),
                onPanUpdate: (d) => _updateHue(d.localPosition.dx, 248),
                child: CustomPaint(
                  painter: _HuePainter(_hsv.hue),
                  size: const Size(248, 20),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Preview + hex input
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: currentColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.blockBorder, width: 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: theme.statusChipBg,
                    borderRadius: BorderRadius.circular(6),
                    child: TextField(
                      controller: _hexController,
                      style: TextStyle(
                        color: theme.foreground,
                        fontFamily: theme.fontFamily,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: theme.blockBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: theme.blockBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: theme.cursor),
                        ),
                        isDense: true,
                      ),
                      onSubmitted: _onHexSubmit,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: theme.dimForeground)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(currentColor),
                  child: Text('Apply', style: TextStyle(color: theme.cursor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateSV(Offset pos, Size size) {
    final s = (pos.dx / size.width).clamp(0.0, 1.0);
    final v = (1 - pos.dy / size.height).clamp(0.0, 1.0);
    setState(() {
      _hsv = _hsv.withSaturation(s).withValue(v);
      _hexController.text = _colorToHex(_hsv.toColor());
    });
  }

  void _updateHue(double x, double width) {
    final hue = (x / width * 360).clamp(0.0, 360.0);
    setState(() {
      _hsv = _hsv.withHue(hue);
      _hexController.text = _colorToHex(_hsv.toColor());
    });
  }

  void _onHexSubmit(String value) {
    var hex = value.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) hex = 'FF$hex';
    final v = int.tryParse(hex, radix: 16);
    if (v != null) {
      setState(() {
        _hsv = HSVColor.fromColor(Color(v));
        _hexController.text = _colorToHex(_hsv.toColor());
      });
    }
  }
}

class _SVPainter extends CustomPainter {
  final HSVColor hsv;
  _SVPainter(this.hsv);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Hue background
    canvas.drawRect(rect, Paint()..color = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor());

    // White gradient (left to right)
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(
      colors: [Colors.white, Colors.transparent],
    ).createShader(rect));

    // Black gradient (top to bottom)
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black],
    ).createShader(rect));

    // Selector circle
    final dx = hsv.saturation * size.width;
    final dy = (1 - hsv.value) * size.height;
    canvas.drawCircle(
      Offset(dx, dy),
      6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SVPainter old) => hsv != old.hsv;
}

class _HuePainter extends CustomPainter {
  final double hue;
  _HuePainter(this.hue);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final colors = List.generate(7, (i) =>
      HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor());

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..shader = LinearGradient(colors: colors).createShader(rect),
    );

    // Selector
    final x = hue / 360 * size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, size.height / 2), width: 6, height: size.height),
        const Radius.circular(2),
      ),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_HuePainter old) => hue != old.hue;
}
