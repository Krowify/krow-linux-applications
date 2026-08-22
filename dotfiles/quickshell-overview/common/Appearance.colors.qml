// Deployed by 5-dotfiles.sh -- shipped default (Shanu-Kumawat/quickshell-
// overview's own upstream palette, unmodified) so this file is valid QML
// before Matugen has ever run. Once you pick a wallpaper via waypaper,
// Matugen overwrites this in place from
// dotfiles/matugen/templates/quickshell-overview-colors.qml -- see the
// README's color theming section. Unlike the other apps this repo themes,
// there's currently no curated version of this file per theme.sh theme
// (tokyo-night/decay-green/graphite-mono) -- switching those leaves this
// file as whatever Matugen last wrote (or this shipped default, if you
// haven't picked a wallpaper yet).
import QtQuick

QtObject {
    id: m3

    property color m3primary: "#ffb5a1"
    property color m3onPrimary: "#561f10"

    property color m3primaryContainer: "#723524"
    property color m3onPrimaryContainer: "#ffdbd1"

    property color m3secondary: "#e7bdb2"
    property color m3onSecondary: "#442a23"

    property color m3secondaryContainer: "#5d4038"
    property color m3onSecondaryContainer: "#ffdbd1"

    property color m3background: "#1a110f"
    property color m3onBackground: "#f1dfda"

    property color m3surface: "#1a110f"

    property color m3surfaceContainerLow: "#231917"
    property color m3surfaceContainer: "#271d1b"
    property color m3surfaceContainerHigh: "#322825"
    property color m3surfaceContainerHighest: "#3d3230"

    property color m3onSurface: "#f1dfda"

    property color m3surfaceVariant: "#53433f"
    property color m3onSurfaceVariant: "#d8c2bc"

    property color m3inverseSurface: "#f1dfda"
    property color m3inverseOnSurface: "#392e2b"

    property color m3outline: "#a08c88"
    property color m3outlineVariant: "#53433f"

    property color m3shadow: "#000000"
}
