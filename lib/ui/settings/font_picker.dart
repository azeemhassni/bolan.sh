import 'package:flutter/material.dart';

import '../../core/fonts/system_fonts.dart';
import '../../core/theme/bolan_theme.dart';

/// Font picker with search, preview, and monospace font filtering.
///
/// Shows all system monospace fonts with a live preview of each font.
/// The currently selected font is highlighted.
class FontPicker extends StatefulWidget {
  final String selectedFont;
  final ValueChanged<String> onSelected;
  final BolonTheme theme;

  const FontPicker({
    super.key,
    required this.selectedFont,
    required this.onSelected,
    required this.theme,
  });

  @override
  State<FontPicker> createState() => _FontPickerState();
}

class _FontPickerState extends State<FontPicker> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<String> _allFonts = [];
  List<String> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadFonts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFonts() async {
    final fonts = await SystemFonts.getMonospaceFonts();
    if (!mounted) return;
    setState(() {
      _allFonts = fonts;
      _filtered = fonts;
      _loading = false;
    });

    // Scroll to selected font
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _allFonts
          : _allFonts
              .where((f) => f.toLowerCase().contains(query))
              .toList();
    });
  }

  void _scrollToSelected() {
    final index = _filtered.indexOf(widget.selectedFont);
    if (index > 0 && _scrollController.hasClients) {
      _scrollController.jumpTo((index * 52.0).clamp(
        0,
        _scrollController.position.maxScrollExtent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;

    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: t.blockBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.blockBorder, width: 1),
      ),
      child: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: t.foreground,
                fontFamily: t.fontFamily,
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
              cursorColor: t.cursor,
              decoration: InputDecoration(
                hintText: 'Search fonts...',
                hintStyle: TextStyle(
                  color: t.dimForeground,
                  fontFamily: t.fontFamily,
                  fontSize: 13,
                ),
                prefixIcon:
                    Icon(Icons.search, color: t.dimForeground, size: 16),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          Divider(color: t.blockBorder, height: 1),

          // Font list
          Expanded(
            child: _loading
                ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: t.dimForeground,
                      ),
                    ),
                  )
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No fonts found',
                          style: TextStyle(
                            color: t.dimForeground,
                            fontFamily: t.fontFamily,
                            fontSize: 12,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _filtered.length,
                        itemExtent: 52,
                        itemBuilder: (context, index) {
                          final font = _filtered[index];
                          final isSelected =
                              font == widget.selectedFont;
                          return _FontRow(
                            fontName: font,
                            isSelected: isSelected,
                            theme: t,
                            onTap: () => widget.onSelected(font),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _FontRow extends StatelessWidget {
  final String fontName;
  final bool isSelected;
  final BolonTheme theme;
  final VoidCallback onTap;

  const _FontRow({
    required this.fontName,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: isSelected
              ? theme.statusChipBg
              : Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: theme.ansiGreen,
                      ),
                    ),
                  Text(
                    fontName,
                    style: TextStyle(
                      color: isSelected
                          ? theme.foreground
                          : theme.blockHeaderFg,
                      fontFamily: theme.fontFamily,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // Preview in the actual font
              Text(
                'The quick brown fox => 0O 1lI',
                style: TextStyle(
                  color: theme.dimForeground,
                  fontFamily: fontName,
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
