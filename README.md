# X-Perl SwingTimer

Standalone add-on module for X-Perl UnitFrames (WoW 1.12): swing timers for main hand, off hand, ranged and your target, docked to the X-Perl frames.

## Features
- Bars for main hand, off hand (dual wield) and ranged/thrown/wand
- Target swing timer, switchable separately for creatures and enemy players
- Docks to `XPerl_Player` and `XPerl_Target` or can be placed freely
- Width taken from the unit frame or fixed; height and spacing adjustable
- Optionally shown only in combat

## Usage
- `/xps` opens the settings.
- Alternatively use the button in the X-Perl options.

## How it works
Detection is derived from [AttackBar](https://github.com/Siventt/AttackBar) but does not need AttackBar. Vanilla has no swing event, so every own melee hit or miss in the combat log counts as the start of a swing. The bar length comes from `UnitAttackSpeed()`.

## Requirements
XPerl

## Saved data
`XPerlSwingConfig`

## Note
Replaces `AttackBarXPerl`. Using both at the same time gives duplicate bars.
