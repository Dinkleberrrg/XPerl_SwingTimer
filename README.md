# X-Perl SwingTimer

Eigenständiges Zusatzmodul für X-Perl UnitFrames (WoW 1.12): Swing-Timer für Haupthand, Schildhand, Fernkampf und das Ziel, angedockt an die XPerl-Frames.

## Funktionen
- Leisten für Haupthand, Schildhand (Beidhandkampf) und Fernkampf/Wurf/Zauberstab
- Swing-Timer des Ziels, getrennt schaltbar für Kreaturen und feindliche Spieler
- Andocken an `XPerl_Player` und `XPerl_Target` oder frei platzierbar
- Breite automatisch vom Unitframe oder fest einstellbar, Höhe und Abstände einstellbar
- Optional nur im Kampf einblenden

## Bedienung
- `/xps` öffnet die Einstellungen.
- Alternativ über den Knopf in den XPerl-Optionen.

## Wie es funktioniert
Die Erkennung ist von [AttackBar](https://github.com/Siventt/AttackBar) abgeleitet, braucht AttackBar aber nicht. Vanilla hat kein Swing-Ereignis, deshalb wird jeder eigene Nahkampftreffer oder -fehlschlag im Kampflog als Start eines Swings gewertet. Die Balkenlänge kommt aus `UnitAttackSpeed()`.

## Voraussetzungen
XPerl

## Gespeicherte Daten
`XPerlSwingConfig`

## Hinweis
Ersetzt `AttackBarXPerl`. Beide gleichzeitig zu nutzen ergibt doppelte Leisten.
