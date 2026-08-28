// Configuration for the Panes dockable-panel framework.
//
// A single immutable [PanelDockConfig] carries every knob: layout sizes,
// minimums, capability toggles, detached-window options, re-dock behavior,
// native-chrome integration, animation timings, and all user-facing strings
// (so the UI can be localized). It is handed to [PanelManager] once and read by
// both the manager and the widgets, so there is a single source of truth.

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'panel.dart';

/// A Material-independent visual theme for a Panes workspace. Every color the
/// framework paints comes from here, so the dock does not inherit Material's
/// `ColorScheme` (and its surface tint). Provide light/dark variants on
/// [PanelDockConfig]; the active one is chosen from the platform brightness.
@immutable
class PanelTheme {
  const PanelTheme({
    required this.background,
    required this.surface,
    required this.tabBar,
    required this.tabActive,
    required this.tabHover,
    required this.border,
    required this.accent,
    required this.text,
    required this.mutedText,
    required this.splitter,
    required this.splitterActive,
    required this.floatingHeader,
    required this.overlayBackground,
    this.tabTextStyle,
    this.titleTextStyle,
    this.tabRadius = BorderRadius.zero,
    this.tabUnderlineThickness = 2.0,
    this.showPanelBorder = true,
    this.tabDividerThickness = 1.0,
  });

  /// Workspace background (gaps, empty center).
  final Color background;

  /// Panel content background.
  final Color surface;

  /// Tab strip / header background.
  final Color tabBar;

  /// Background of the selected tab.
  final Color tabActive;

  /// Hover wash applied to unselected tabs (usually translucent).
  final Color tabHover;

  /// Hairline borders around panels.
  final Color border;

  /// Accent used for the active-tab underline, drop zones and splitters.
  final Color accent;

  /// Primary and secondary text colors.
  final Color text;
  final Color mutedText;

  /// Splitter line, idle and active.
  final Color splitter;
  final Color splitterActive;

  /// Floating-window header background.
  final Color floatingHeader;

  /// Background for popup menus / tooltips in floating windows.
  final Color overlayBackground;

  /// Optional text styles for tab labels / floating titles.
  final TextStyle? tabTextStyle;
  final TextStyle? titleTextStyle;

  /// Corner radius of tabs. Non-zero gives rounded / pill-shaped tabs; when set,
  /// the selected tab is indicated by its [tabActive] fill rather than an
  /// underline (a uniform radius and a single-side border can't coexist).
  final BorderRadius tabRadius;

  /// Thickness of the accent underline under the selected tab (square tabs).
  /// Set to 0 to drop the underline indicator.
  final double tabUnderlineThickness;

  /// Whether panels draw a resting [border]. The focus ring (accent) still
  /// shows when a group is focused. Set false to skip the border decoration.
  final bool showPanelBorder;

  /// Thickness of the divider between a tab strip and its content (drawn in
  /// [border]). Set to 0 to drop the divider, or raise it for a heavier rule.
  final double tabDividerThickness;

  /// A neutral light palette (no Material surface tint).
  factory PanelTheme.light() => const PanelTheme(
    background: Color(0xFFF3F4F6),
    surface: Color(0xFFFFFFFF),
    tabBar: Color(0xFFEAECEF),
    tabActive: Color(0xFFFFFFFF),
    tabHover: Color(0x0D000000),
    border: Color(0xFFD7DBE0),
    accent: Color(0xFF3B82F6),
    text: Color(0xFF1F2329),
    mutedText: Color(0xFF6B7280),
    splitter: Color(0xFFD7DBE0),
    splitterActive: Color(0xFF3B82F6),
    floatingHeader: Color(0xFFEAECEF),
    overlayBackground: Color(0xFFFFFFFF),
  );

  /// A neutral dark palette (no Material surface tint).
  factory PanelTheme.dark() => const PanelTheme(
    background: Color(0xFF1E1F22),
    surface: Color(0xFF26282C),
    tabBar: Color(0xFF2B2D31),
    tabActive: Color(0xFF34373C),
    tabHover: Color(0x14FFFFFF),
    border: Color(0xFF3A3D42),
    accent: Color(0xFF5B9DF7),
    text: Color(0xFFE6E7E9),
    mutedText: Color(0xFF9AA0A6),
    splitter: Color(0xFF3A3D42),
    splitterActive: Color(0xFF5B9DF7),
    floatingHeader: Color(0xFF2B2D31),
    overlayBackground: Color(0xFF26282C),
  );
}

/// Passed to [PanelDockConfig.tabBuilder] so apps can render tabs arbitrarily.
@immutable
class PanelTabSpec {
  const PanelTabSpec({
    required this.descriptor,
    required this.selected,
    required this.hovered,
    required this.theme,
  });

  final PanelDescriptor descriptor;
  final bool selected;
  final bool hovered;
  final PanelTheme theme;
}

/// Pluggable persistence for the panel layout. Implement with whatever store
/// you like (shared_preferences, a file, a database) and pass via
/// [PanelDockConfig.storage].
abstract class PanelStorage {
  /// Returns a previously [write]-ten layout, or null if none.
  FutureOr<Map<String, Object?>?> read();

  /// Persists [layout] (a plain JSON-encodable map).
  FutureOr<void> write(Map<String, Object?> layout);
}

/// User-facing strings, grouped for localization. Override individual fields or
/// the whole object via [PanelDockConfig.strings].
@immutable
class PanelDockStrings {
  const PanelDockStrings({
    this.addTab = 'Add tab',
    this.newGroup = 'New group',
    this.dropHere = 'Drop here',
    this.emptyCenter = 'Drop a panel here',
    this.minimizeDockTooltip = 'Minimize {side} dock',
    this.detachTooltip = 'Detach to a floating window',
    this.splitTooltip = 'Split: move tab beside',
    this.snapBackTooltip = 'Snap back into dock',
    this.minimizeWindowTooltip = 'Minimize window',
    this.dockMenuTooltip = 'Dock to…',
    this.dockIntoLabel = _defaultDockInto,
    this.dockMenuItemLabel = _defaultDockMenuItem,
  });

  /// Center drop-zone label (add as a tab to the hovered group).
  final String addTab;

  /// Edge drop-zone label (create a new group beside the hovered group).
  final String newGroup;

  /// Label shown on the empty-center drop target while dragging.
  final String dropHere;

  /// Placeholder shown in an empty center region when not dragging.
  final String emptyCenter;

  /// Tooltip for the dock collapse/minimize button. `{side}` is replaced with
  /// the lower-cased side name.
  final String minimizeDockTooltip;

  final String detachTooltip;
  final String splitTooltip;
  final String snapBackTooltip;
  final String minimizeWindowTooltip;
  final String dockMenuTooltip;

  /// Label for an empty-region edge target, e.g. "Dock\nleft".
  final String Function(DockSide side) dockIntoLabel;

  /// Label for an entry in the floating window's "Dock to…" menu.
  final String Function(DockSide side) dockMenuItemLabel;

  static String _defaultDockInto(DockSide side) =>
      'Dock\n${side.label.toLowerCase()}';
  static String _defaultDockMenuItem(DockSide side) =>
      'Dock ${side.label.toLowerCase()}';

  /// Resolves [minimizeDockTooltip] for [side].
  String minimizeDock(DockSide side) =>
      minimizeDockTooltip.replaceAll('{side}', side.label.toLowerCase());
}

/// All configuration for a Panes workspace. Pass to [PanelManager].
///
/// Colors and typography intentionally come from the ambient [ThemeData] rather
/// than this config, so a workspace matches the host app automatically.
@immutable
class PanelDockConfig {
  const PanelDockConfig({
    this.leftDockSize = 240,
    this.rightDockSize = 300,
    this.bottomDockSize = 220,
    this.minDockExtent = 120,
    this.minGroupFraction = 0.12,
    this.minCenterWidth = 280,
    this.minCenterHeight = 160,
    this.collapsedExtent = 36,
    this.tabStripHeight = 38,
    this.splitterHitSize = 8,
    this.dropEdgeFraction = 0.30,
    this.defaultDetachedSize = const Size(480, 600),
    this.detachedConstraints = const BoxConstraints(
      minWidth: 240,
      minHeight: 200,
    ),
    this.redockAsTab = false,
    this.allowDetach = true,
    this.allowSplit = true,
    this.allowCollapse = true,
    this.allowResize = true,
    this.enableNativeChrome = true,
    this.hoverDuration = const Duration(milliseconds: 120),
    this.splitterDuration = const Duration(milliseconds: 100),
    this.strings = const PanelDockStrings(),
    this.lightTheme,
    this.darkTheme,
    this.tabBuilder,
    this.storage,
  }) : assert(dropEdgeFraction > 0 && dropEdgeFraction < 0.5),
       assert(minGroupFraction > 0 && minGroupFraction < 0.5);

  /// Initial widths/height of the side docks, in logical pixels.
  final double leftDockSize;
  final double rightDockSize;
  final double bottomDockSize;

  /// Smallest a dock can be resized to.
  final double minDockExtent;

  /// Smallest fraction of a region's main axis a single group may shrink to.
  final double minGroupFraction;

  /// Minimum size the flexible center keeps when side/bottom docks grow.
  final double minCenterWidth;
  final double minCenterHeight;

  /// Thickness of a collapsed (minimized) dock strip.
  final double collapsedExtent;

  /// Height of a group's tab strip.
  final double tabStripHeight;

  /// Hit thickness of the (1–2px) splitter handles.
  final double splitterHitSize;

  /// Fraction of a group's edge that triggers a "new group" split on drop
  /// (the remaining center triggers "add as tab"). Range (0, 0.5).
  final double dropEdgeFraction;

  /// Size used for a detached window when its [PanelDescriptor.detachedSize]
  /// is null.
  final Size defaultDetachedSize;

  /// Constraints applied to detached windows.
  final BoxConstraints detachedConstraints;

  /// When re-docking a floating panel, add it as a tab to the side's last group
  /// (`true`) instead of creating a new group beside it (`false`, default).
  final bool redockAsTab;

  /// Capability toggles. Disable to lock down parts of the UX.
  final bool allowDetach;
  final bool allowSplit;
  final bool allowCollapse;
  final bool allowResize;

  /// Whether to invoke the native macOS chrome helper (hide title bars, report
  /// window drags for snap-back). Has no effect off macOS.
  final bool enableNativeChrome;

  /// Animation durations for hover/splitter feedback.
  final Duration hoverDuration;
  final Duration splitterDuration;

  /// User-facing strings (localization).
  final PanelDockStrings strings;

  /// Visual themes; the active one is chosen from the platform brightness.
  /// Default to [PanelTheme.light]/[PanelTheme.dark] when null.
  final PanelTheme? lightTheme;
  final PanelTheme? darkTheme;

  /// Optional builder to render tab labels arbitrarily. When null, a default
  /// label (icon + title, themed via [PanelTheme]) is used.
  final Widget Function(BuildContext context, PanelTabSpec spec)? tabBuilder;

  /// Optional layout persistence. When set, the manager auto-saves on changes
  /// and `PanelManager.restore()` reloads.
  final PanelStorage? storage;

  /// Resolves the active [PanelTheme] for [context]'s platform brightness.
  PanelTheme themeOf(BuildContext context) {
    final bool dark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return dark
        ? (darkTheme ?? PanelTheme.dark())
        : (lightTheme ?? PanelTheme.light());
  }

  /// Initial size for [side]'s dock.
  double initialSize(DockSide side) => switch (side) {
    DockSide.left => leftDockSize,
    DockSide.right => rightDockSize,
    DockSide.bottom => bottomDockSize,
    DockSide.center => 0,
  };

  PanelDockConfig copyWith({
    double? leftDockSize,
    double? rightDockSize,
    double? bottomDockSize,
    double? minDockExtent,
    double? minGroupFraction,
    double? minCenterWidth,
    double? minCenterHeight,
    double? collapsedExtent,
    double? tabStripHeight,
    double? splitterHitSize,
    double? dropEdgeFraction,
    Size? defaultDetachedSize,
    BoxConstraints? detachedConstraints,
    bool? redockAsTab,
    bool? allowDetach,
    bool? allowSplit,
    bool? allowCollapse,
    bool? allowResize,
    bool? enableNativeChrome,
    Duration? hoverDuration,
    Duration? splitterDuration,
    PanelDockStrings? strings,
    PanelTheme? lightTheme,
    PanelTheme? darkTheme,
    Widget Function(BuildContext, PanelTabSpec)? tabBuilder,
    PanelStorage? storage,
  }) {
    return PanelDockConfig(
      leftDockSize: leftDockSize ?? this.leftDockSize,
      rightDockSize: rightDockSize ?? this.rightDockSize,
      bottomDockSize: bottomDockSize ?? this.bottomDockSize,
      minDockExtent: minDockExtent ?? this.minDockExtent,
      minGroupFraction: minGroupFraction ?? this.minGroupFraction,
      minCenterWidth: minCenterWidth ?? this.minCenterWidth,
      minCenterHeight: minCenterHeight ?? this.minCenterHeight,
      collapsedExtent: collapsedExtent ?? this.collapsedExtent,
      tabStripHeight: tabStripHeight ?? this.tabStripHeight,
      splitterHitSize: splitterHitSize ?? this.splitterHitSize,
      dropEdgeFraction: dropEdgeFraction ?? this.dropEdgeFraction,
      defaultDetachedSize: defaultDetachedSize ?? this.defaultDetachedSize,
      detachedConstraints: detachedConstraints ?? this.detachedConstraints,
      redockAsTab: redockAsTab ?? this.redockAsTab,
      allowDetach: allowDetach ?? this.allowDetach,
      allowSplit: allowSplit ?? this.allowSplit,
      allowCollapse: allowCollapse ?? this.allowCollapse,
      allowResize: allowResize ?? this.allowResize,
      enableNativeChrome: enableNativeChrome ?? this.enableNativeChrome,
      hoverDuration: hoverDuration ?? this.hoverDuration,
      splitterDuration: splitterDuration ?? this.splitterDuration,
      strings: strings ?? this.strings,
      lightTheme: lightTheme ?? this.lightTheme,
      darkTheme: darkTheme ?? this.darkTheme,
      tabBuilder: tabBuilder ?? this.tabBuilder,
      storage: storage ?? this.storage,
    );
  }
}
