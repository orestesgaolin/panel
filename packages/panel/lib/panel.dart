/// Panel — a reusable, IDE-style dockable / tabbed / splittable panel framework
/// for Flutter. Platform-generic and web-capable: docking, tabs, side-by-side
/// splits, drag-and-drop, layout persistence and keyboard shortcuts all work
/// anywhere.
///
/// Detaching panels into separate OS windows is delegated to a
/// [PanelWindowingBackend]; the default [DisabledWindowing] makes detach a
/// no-op. A platform package (e.g. `panel_macos`) supplies a real backend.
///
/// Quick start:
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:panel/panel.dart';
///
/// final manager = PanelManager(config: const PanelDockConfig())
///   ..registerPanel(PanelDescriptor(id: 'explorer', title: 'Explorer',
///       builder: (_) => const Explorer()), side: DockSide.left)
///   ..registerPanel(PanelDescriptor(id: 'editor', title: 'Editor',
///       builder: (_) => const Editor()), side: DockSide.center);
///
/// // Expose the manager, then render a PanelDock in your Scaffold body:
/// PanelScope(manager: manager, child: MaterialApp(home: Scaffold(body: PanelDock())));
/// ```
///
/// See `package:panel_macos` to enable real detachable windows on macOS.
library;

export 'src/panel.dart'
    show DockSide, DockSideLabel, PanelContentBuilder, PanelDescriptor;
export 'src/panel_config.dart'
    show
        PanelDockConfig,
        PanelDockStrings,
        PanelTheme,
        PanelTabSpec,
        PanelStorage;
export 'src/panel_dock.dart' show PanelDock;
export 'src/panel_manager.dart' show PanelManager, PanelScope;
export 'src/panel_shortcuts.dart'
    show
        MergePanelIntent,
        SplitPanelIntent,
        defaultPanelShortcuts,
        panelActions;
export 'src/panel_windowing.dart' show PanelWindowingBackend, DisabledWindowing;
