#!/bin/zsh
# Bolan Theme Color Extractor
# Run this in your terminal to extract its color scheme.
# Copy the output and use it to create a Bolan theme.

echo "=== Terminal Theme Colors ==="
echo ""

# Background and foreground
echo "--- Window Colors ---"
echo "Copy these from your terminal's preferences/settings."
echo ""

# Show ANSI 16 colors with their codes
echo "--- ANSI 16 Colors ---"
echo ""

# Standard colors (0-7)
echo "Normal colors:"
for i in {0..7}; do
  printf "\e[48;5;${i}m  %3d  \e[0m " $i
done
echo ""
echo "  Black   Red    Green  Yellow  Blue  Magenta  Cyan   White"
echo ""

# Bright colors (8-15)
echo "Bright colors:"
for i in {8..15}; do
  printf "\e[48;5;${i}m  %3d  \e[0m " $i
done
echo ""
echo "  Black   Red    Green  Yellow  Blue  Magenta  Cyan   White"
echo ""

# Show foreground text samples
echo "--- Foreground Samples ---"
echo ""
printf "\e[30m Black  \e[0m \e[31m Red    \e[0m \e[32m Green  \e[0m \e[33m Yellow \e[0m "
printf "\e[34m Blue   \e[0m \e[35m Magenta\e[0m \e[36m Cyan   \e[0m \e[37m White  \e[0m"
echo ""
printf "\e[90m Black  \e[0m \e[91m Red    \e[0m \e[92m Green  \e[0m \e[93m Yellow \e[0m "
printf "\e[94m Blue   \e[0m \e[95m Magenta\e[0m \e[96m Cyan   \e[0m \e[97m White  \e[0m"
echo ""
echo ""

# Show text styles
echo "--- Text Styles ---"
printf "\e[1mBold\e[0m  \e[2mDim\e[0m  \e[3mItalic\e[0m  \e[4mUnderline\e[0m  \e[9mStrike\e[0m"
echo ""
echo ""

# 256 color palette
echo "--- 256 Color Palette ---"
echo ""
for row in $(seq 0 15); do
  for col in $(seq 0 15); do
    i=$((row * 16 + col))
    printf "\e[48;5;${i}m%4d\e[0m" $i
  done
  echo ""
done
echo ""

# Template for Bolan theme
echo "=== Bolan Theme Template ==="
echo ""
echo "Fill in the hex values from your terminal's color settings:"
echo ""
cat << 'TEMPLATE'
const raskohTheme = BolonTheme(
  name: 'raskoh',
  displayName: 'Raskoh',
  brightness: Brightness.dark,  // or Brightness.light
  isBuiltIn: true,

  // Window — get from terminal preferences
  background:          Color(0xFF______),
  tabBarBackground:    Color(0xFF______),  // slightly darker than background
  statusBarBackground: Color(0xFF______),  // slightly darker than tab bar
  promptBackground:    Color(0xFF______),  // slightly lighter than background

  // Blocks
  blockBackground:     Color(0xFF______),  // same as prompt or slightly different
  blockBorder:         Color(0xFF______),  // subtle border color
  blockHeaderFg:       Color(0xFF______),  // text color for command headers
  exitSuccessFg:       Color(0xFF______),  // green for success
  exitFailureFg:       Color(0xFF______),  // red for failure

  // Status chips
  statusChipBg:        Color(0xFF______),  // chip background
  statusCwdFg:         Color(0xFF______),  // blue for CWD
  statusGitFg:         Color(0xFF______),  // purple for git
  statusShellFg:       Color(0xFF______),  // green/teal for shell
  dimForeground:       Color(0xFF______),  // muted text color

  // Terminal
  foreground:          Color(0xFF______),  // main text color
  cursor:              Color(0xFF______),  // cursor color
  selectionColor:      Color(0x40______),  // selection with alpha

  // ANSI colors — map from the color blocks above
  ansiBlack:           Color(0xFF______),  // color 0
  ansiRed:             Color(0xFF______),  // color 1
  ansiGreen:           Color(0xFF______),  // color 2
  ansiYellow:          Color(0xFF______),  // color 3
  ansiBlue:            Color(0xFF______),  // color 4
  ansiMagenta:         Color(0xFF______),  // color 5
  ansiCyan:            Color(0xFF______),  // color 6
  ansiWhite:           Color(0xFF______),  // color 7
  ansiBrightBlack:     Color(0xFF______),  // color 8
  ansiBrightRed:       Color(0xFF______),  // color 9
  ansiBrightGreen:     Color(0xFF______),  // color 10
  ansiBrightYellow:    Color(0xFF______),  // color 11
  ansiBrightBlue:      Color(0xFF______),  // color 12
  ansiBrightMagenta:   Color(0xFF______),  // color 13
  ansiBrightCyan:      Color(0xFF______),  // color 14
  ansiBrightWhite:     Color(0xFF______),  // color 15
);
TEMPLATE
