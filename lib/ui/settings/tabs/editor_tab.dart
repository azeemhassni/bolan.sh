import 'package:flutter/material.dart';

import '../../../core/config/global_config.dart';
import '../../../core/theme/bolan_theme.dart';
import '../../shared/bolan_components.dart';
import '../font_picker.dart';

typedef EditorUpdater = void Function({
  String? fontFamily,
  double? fontSize,
  double? lineHeight,
  String? cursorStyle,
  bool? cursorBlink,
  int? scrollbackLines,
  bool? ligatures,
});

class EditorTab extends StatelessWidget {
  final GlobalConfig globalConfig;
  final BolonTheme theme;
  final EditorUpdater onChanged;

  const EditorTab({
    super.key,
    required this.globalConfig,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      children: [
        BolanField(
          label: 'Font Family',
          child: FontPicker(
            selectedFont: globalConfig.editor.fontFamily,
            theme: theme,
            onSelected: (v) => onChanged(fontFamily: v),
          ),
        ),
        BolanField(
          label: 'Font Size',
          child: BolanSlider(
            value: globalConfig.editor.fontSize,
            min: 8,
            max: 32,
            step: 1,
            suffix: 'px',
            onChanged: (v) => onChanged(fontSize: v),
          ),
        ),
        BolanField(
          label: 'Line Height',
          child: BolanSlider(
            value: globalConfig.editor.lineHeight,
            min: 1.0,
            max: 2.0,
            step: 0.1,
            onChanged: (v) => onChanged(lineHeight: v),
          ),
        ),
        BolanField(
          label: 'Cursor Style',
          child: BolanSegmentedControl(
            value: globalConfig.editor.cursorStyle,
            options: const ['block', 'underline', 'bar'],
            onChanged: (v) => onChanged(cursorStyle: v),
          ),
        ),
        BolanField(
          label: 'Scrollback Lines',
          child: BolanSlider(
            value: globalConfig.editor.scrollbackLines.toDouble(),
            min: 1000,
            max: 50000,
            step: 1000,
            onChanged: (v) => onChanged(scrollbackLines: v.round()),
          ),
        ),
        BolanToggle(
          label: 'Ligatures',
          help: 'Enable font ligatures in block output (e.g., => != ->)',
          value: globalConfig.editor.ligatures,
          onChanged: (v) => onChanged(ligatures: v),
        ),
      ],
    );
  }
}
