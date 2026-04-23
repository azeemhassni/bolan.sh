import 'package:flutter/material.dart';

import '../../../core/ai/api_key_storage.dart';
import '../../../core/theme/bolan_theme.dart';
import '../../shared/bolan_components.dart';
import 'action_button.dart';

class ApiKeyField extends StatefulWidget {
  final String provider;
  final BolonTheme theme;

  const ApiKeyField({
    super.key,
    required this.provider,
    required this.theme,
  });

  @override
  State<ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends State<ApiKeyField> {
  bool _hasKey = false;
  bool _editing = false;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkKey();
  }

  Future<void> _checkKey() async {
    try {
      final has = await ApiKeyStorage.hasKey(widget.provider);
      if (mounted) setState(() => _hasKey = has);
    } on Exception {
      // Keychain error
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'API Key',
            style: TextStyle(
              color: widget.theme.foreground,
              fontFamily: widget.theme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          if (_editing)
            Row(
              children: [
                Expanded(
                  child: BolanTextField(
                    value: '',
                    hint: 'Paste API key...',
                    obscure: true,
                    onChanged: (v) => _controller.text = v,
                  ),
                ),
                const SizedBox(width: 8),
                ActionButton(
                  label: 'Save',
                  color: widget.theme.exitSuccessFg,
                  theme: widget.theme,
                  onTap: _saveKey,
                ),
              ],
            )
          else
            Row(
              children: [
                Text(
                  _hasKey ? '••••••••••••••••' : 'Not configured',
                  style: TextStyle(
                    color: _hasKey
                        ? widget.theme.foreground
                        : widget.theme.dimForeground,
                    fontFamily: widget.theme.fontFamily,
                    fontSize: 13,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 12),
                ActionButton(
                  label: _hasKey ? 'Change' : 'Set',
                  color: widget.theme.cursor,
                  theme: widget.theme,
                  onTap: () => setState(() => _editing = true),
                ),
                if (_hasKey) ...[
                  const SizedBox(width: 8),
                  ActionButton(
                    label: 'Remove',
                    color: widget.theme.exitFailureFg,
                    theme: widget.theme,
                    onTap: _deleteKey,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _saveKey() async {
    final key = _controller.text.trim();
    if (key.isEmpty) return;
    try {
      await ApiKeyStorage.saveKey(widget.provider, key);
      _controller.clear();
      setState(() {
        _hasKey = true;
        _editing = false;
      });
    } on Exception {
      // Keychain error
    }
  }

  Future<void> _deleteKey() async {
    try {
      await ApiKeyStorage.deleteKey(widget.provider);
      setState(() => _hasKey = false);
    } on Exception {
      // Keychain error
    }
  }
}
