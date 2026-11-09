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

All configuration is in the `dnc.ini` file.

### Hotkeys

Edit `dnc.ini` to customize activation hotkeys:

```ini
hotkey_select_monitor=PgDn    ; Show monitor selection menu
hotkey_current_monitor=PgUp   ; Activate on current monitor
hotkey_current_window=CapsLock ; Activate inside the active window
```

Use AutoHotkey hotkey syntax:
- `^` = Ctrl (e.g., `^F1` = Ctrl+F1)
- `!` = Alt (e.g., `!Space` = Alt+Space)
- `+` = Shift (e.g., `+F12` = Shift+F12)
- `#` = Win key (e.g., `#m` = Win+M)

Examples:
- `F1` and `F2` - Simple function keys
- `^!m` - Ctrl+Alt+M
- `#Space` - Win+Space

### Monitor Layout

Edit `dnc.ini` to configure your physical monitor arrangement (left to right):

```ini
monitor_layout=1,4,2,3    ; Windows monitor numbers from left to right
```

This maps your physical monitor positions to Windows monitor numbers. For example, `1,4,2,3` means:
- Physical position 1 (leftmost) = Windows monitor #1 → Press **A**
- Physical position 2 = Windows monitor #4 → Press **S**
- Physical position 3 = Windows monitor #2 → Press **D**
- Physical position 4 (rightmost) = Windows monitor #3 → Press **F**

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

| Hotkey | Action | Configurable in dnc.ini |
|--------|--------|-------------------------|
| **PgDn** (default) | Select monitor with A/S/D/F keys | `hotkey_select_monitor` |
| **PgUp** (default) | Activate on current monitor | `hotkey_current_monitor` |
| **CapsLock** (default) | Activate inside the active window | `hotkey_current_window` |

The window hotkey includes the title bar and borders, clipping the grid to the
monitor containing the largest portion of the active window. It does not cover
the rest of the screen or subtract areas obscured by other windows. Navigation,
clicks, **Space**, and **Escape** work as usual. CapsLock is consumed by this
hotkey rather than toggling capitalization; configure another key to retain
normal CapsLock use. Existing configuration files get the new setting on reload.

After a left, right, or double click, a monitor activation hotkey resumes the last
clicked cell when the target monitor is the same and the mouse is still at the
exact click coordinates. The zoom level and navigation history are restored, so
**Space** still zooms back out. If the mouse position, target monitor, or monitor
bounds differ, activation starts with the full-monitor grid as usual.

Window activation also resumes the last clicked cell when the same window,
monitor, grid bounds, and exact mouse coordinates match. Moving or resizing the
window starts fresh. Window grids and monitor grids do not resume each other,
even when their bounds match.

Only the most recent click is remembered, until the script exits or restarts.
**Escape** cancels without replacing that saved click.

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
