# Keyboard Grid Clicker

A keyboard-driven mouse grid navigation tool for Windows using AutoHotkey. Click anywhere on your screen(s) using only your keyboard - perfect for accessibility, productivity, or when you just don't want to reach for the mouse.

## What It Does

This tool divides your screen into a 3×3 grid overlay. Select a section, and it divides again into another 3×3 grid. Continue zooming in until you reach the exact pixel you want, then click. All controlled via keyboard.

## Features

- ✅ **Multi-monitor support** (4+ monitors)
- ✅ **DPI-aware** for accurate positioning on high-DPI displays
- ✅ **Configurable monitor layout** to match your physical setup
- ✅ **Ergonomic ASDF home-row selection**
- ✅ **Customizable grid colors**
- ✅ **Left click, right click, and double click support**
- ✅ **Undo navigation** to go back one level

## Requirements

- **AutoHotkey v2.0+** (download from [autohotkey.com](https://www.autohotkey.com/))
- Windows 10/11

## Installation

1. Install AutoHotkey v2.0 or higher
2. Double-click `dnc_v2.ahk` to run the script
3. The script will run in the background (tray icon visible)

## Configuration

### Monitor Layout

If your Windows monitor numbering doesn't match your physical layout, edit the `MONITOR_LAYOUT` setting at the top of `dnc_v2.ahk`:

```ahk
MONITOR_LAYOUT := [1, 4, 2, 3]  ; Edit to match your setup
```

The array represents your monitors from **left to right** physically. Each number is the Windows monitor number.

### Grid Color

Edit `dnc.ini` to change the grid line color:

```ini
color=00FF00     ; Hex color (default: bright green)
transparency=70  ; Transparency level (0-255)
```

Popular colors:
- `00FF00` - Bright green (default)
- `FF0000` - Red
- `00FFFF` - Cyan
- `FFFF00` - Yellow

## Usage

### Activation

| Hotkey | Action |
|--------|--------|
| **PgUp** | Select monitor with A/S/D/F keys (1st/2nd/3rd/4th physical monitor) |
| **PgDn** | Activate on current monitor (wherever mouse is) |

### Navigation

Once the grid appears:

```
W  E  R    ← Top row
S  D  F    ← Middle row (home row!)
X  C  V    ← Bottom row
```

Press the key corresponding to the grid section you want. The grid zooms into that section and divides again.

### Actions

| Key | Action |
|-----|--------|
| **J** | Left click |
| **K** | Double click |
| **L** | Right click |
| **Space** | Go back one level (undo) |
| **Escape** | Cancel and close grid |

## Example Workflow

1. Press **PgDn** to activate on current monitor
2. Mouse jumps to center, green grid appears
3. Press **D** to select middle-right section
4. Grid zooms in, press **S** to select middle-left of that section
5. Continue navigating until cursor is where you want
6. Press **J** to left-click

## Tips

- The mouse automatically moves to the center of each selected cell
- Keep zooming in for pixel-perfect accuracy
- Use **Space** to undo if you select the wrong section
- The grid automatically clears after clicking or pressing Escape
- For multi-monitor setups, configure `MONITOR_LAYOUT` once and forget it

## Version History

- **v2.0** - AutoHotkey v2 conversion with modern improvements
  - DPI awareness for multi-monitor setups
  - Configurable monitor layout
  - ASDF home-row navigation
  - Improved grid cleanup
  - Customizable colors
- **v1.0** - Original AutoHotkey v1 version

## Credits

- Original Author: Michael Soza
- Based on 'Mouser' by Adam Pash
- Based on DNC by Petr 'Vorkronor' Stedry

## License

Free to use and modify.
