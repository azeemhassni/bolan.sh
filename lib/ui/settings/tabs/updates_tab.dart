import 'package:flutter/material.dart';

import '../../../core/config/global_config.dart';
import '../../shared/bolan_components.dart';

class UpdatesTab extends StatelessWidget {
  final GlobalConfig globalConfig;
  final ValueChanged<bool> onAutoCheckChanged;

  const UpdatesTab({
    super.key,
    required this.globalConfig,
    required this.onAutoCheckChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      children: [
        BolanToggle(
          label: 'Auto-check for updates',
          help: 'Check for new versions on launch (once per 24 hours)',
          value: globalConfig.update.autoCheck,
          onChanged: onAutoCheckChanged,
        ),
      ],
    );
  }
}
