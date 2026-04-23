import 'package:flutter/material.dart';

import '../../../core/ai/ai_provider_helper.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/bolan_theme.dart';

class TestConnectionButton extends StatefulWidget {
  final AiConfig config;
  final BolonTheme theme;

  const TestConnectionButton({
    super.key,
    required this.config,
    required this.theme,
  });

  @override
  State<TestConnectionButton> createState() => _TestConnectionButtonState();
}

class _TestConnectionButtonState extends State<TestConnectionButton> {
  bool _testing = false;
  String? _result;
  bool? _success;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _testing ? null : _test,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.theme.statusChipBg,
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: widget.theme.blockBorder, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_testing)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: widget.theme.cursor,
                      ),
                    )
                  else
                    Icon(Icons.science_outlined,
                        size: 16, color: widget.theme.foreground),
                  const SizedBox(width: 8),
                  Text(
                    _testing ? 'Testing...' : 'Test Connection',
                    style: TextStyle(
                      color: widget.theme.foreground,
                      fontFamily: widget.theme.fontFamily,
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_result != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _success == true ? Icons.check_circle : Icons.error,
                size: 14,
                color: _success == true
                    ? widget.theme.exitSuccessFg
                    : widget.theme.exitFailureFg,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _result!,
                  style: TextStyle(
                    color: _success == true
                        ? widget.theme.exitSuccessFg
                        : widget.theme.exitFailureFg,
                    fontFamily: widget.theme.fontFamily,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _result = null;
      _success = null;
    });

    try {
      final config = widget.config;
      final provider = await AiProviderHelper.create(
        providerName: config.provider,
        geminiModel: config.geminiModel,
        anthropicMode: config.anthropicMode,
        ollamaUrl: config.ollamaUrl,
        ollamaModel: config.model.isNotEmpty ? config.model : 'llama3',
      );

      if (provider == null) {
        setState(() {
          // Ollama and Local LLM never need an API key, so this branch
          // only fires for cloud providers (OpenAI / Anthropic / Gemini).
          _result = 'No API key configured';
          _success = false;
        });
        return;
      }

      if (!await provider.isAvailable()) {
        setState(() {
          _result = '${provider.displayName} not available';
          _success = false;
        });
        return;
      }

      await provider.generateContent('Say "ok" and nothing else.');
      setState(() {
        _result = 'Connected to ${provider.displayName}';
        _success = true;
      });
    } on Exception catch (e) {
      setState(() {
        _result = '$e';
        _success = false;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }
}
