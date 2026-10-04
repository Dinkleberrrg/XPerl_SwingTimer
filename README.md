# X-Perl SwingTimer

Standalone add-on module for X-Perl UnitFrames (WoW 1.12): swing timers for main hand, off hand, ranged and your target, docked to the X-Perl frames.

## Features
- Bars for main hand, off hand (dual wield) and ranged/thrown/wand
- Target swing timer, switchable separately for creatures and enemy players
- Docks to `XPerl_Player` and `XPerl_Target` or can be placed freely by dragging. Docked bars sit below the lowest visible X-Perl part (creature type, combo points, XP/druid mana bar, buffs below the frame) and move along when that changes.
- Width taken from the unit frame or fixed; height and spacing adjustable
- Optionally shown only in combat

## Usage
- `/xps` opens the settings.
- Alternatively use the button in the X-Perl options.
- `/xps unlock` shows the bars and lets you drag them with the left mouse button. Dragging a docked bar detaches it from the unit frame. `/xps lock` locks them again (they are also locked again after every login).
- `/xps reset` docks both bars to the X-Perl frames again.

## How it works
Detection is derived from [AttackBar](https://github.com/Siventt/AttackBar) but does not need AttackBar. Vanilla has no swing event, so every own melee hit or miss in the combat log counts as the start of a swing. The bar length comes from `UnitAttackSpeed()`.

## Requirements
XPerl

## Saved data
`XPerlSwingConfig`

## Note
Replaces `AttackBarXPerl`. Using both at the same time gives duplicate bars.
