# Changelog – XPerl_SwingTimer

Versions follow `MAJOR.MINOR.PATCH`. Each release is a git tag `v<version>`; older versions can be downloaded from the tag page on GitHub.

## 1.4.1 – 2026-10-04
- Fixed: old AttackBar bars kept appearing next to ours when AttackBar / AttackBarXPerl were still enabled. Their bars sit directly on UIParent and AttackBar showed them again on every swing; it is now switched off completely, with a chat hint to disable it.
- Fixed: "Prototype font" without ShaguPlates installed broke the text ("Font not set" errors) and left bars frozen on screen. It now falls back to the default font.
- Fixed: the spark of the unlocked placeholder bars stayed where the last swing had left it.
- Checked with the druid mana bar in cat/bear form (XPerl octo.2): the docked bars move down with it.

## 1.4.0 – 2026-10-04
- Options: new buttons "Unlock bars" / "Lock bars" (shows the bars so they can be dragged) and "Demo".
- Demo (also `/xps demo`): runs swings on all bars for 12 seconds with the current settings and your real weapon speeds, so changes to colours, size, font, spark etc. can be seen live. Afterwards (or when the options are closed) everything goes back to normal.

## 1.3.0 – 2026-10-04
- Optional SuperWoW support (option "Use SuperWoW", on by default): every real swing is reported per hand, so main hand and off hand are exact instead of guessed, Heroic Strike & co. and ranged shots come from the actual cast, and the target bar also runs when the target swings at someone else.
- Without SuperWoW, or with the option off, the combat log detection works as before.

## 1.2.0 – 2026-10-04
- Docked bars now sit below the lowest visible X-Perl part instead of the fixed 220x60 main frame: creature type, combo points, stats frame (XP bar, druid mana bar, energy/mana ticker) and target buffs shown below the frame. Previously they could cover these.
- The dock position follows layout changes on the fly (shapeshift, bars appearing, new buff rows, frame moved); "Distance to frame" is measured from that lowest part.

## 1.1.0 – 2026-10-04
- Bars can be moved: `/xps unlock` / `/xps lock` or the new "Lock bars" option. Dragging a docked bar detaches it; the position is saved. `/xps reset` docks them again.
- Fixed: turning off docking left the bar stuck to the unit frame, and after a reload it had no anchor at all and was invisible.
- Fixed: bar width ignored the X-Perl frame scale, and the target bar fell back to the fixed width when there was no target at login.
- Fixed: falling, drowning and lava damage started a fake melee swing.
- Fixed: unknown messages in the spell damage channel started a fake melee swing; "missed" and "was dodged/blocked" abilities (e.g. Heroic Strike) were not recognised.
- Fixed: changing the target recoloured a running ranged bar.
- Opening the options no longer writes every slider value into the saved variables.
- All texts and comments are in English now.

## 1.0.0 – 2026-10-03
- First tagged release (state of the OctoWoW install).
