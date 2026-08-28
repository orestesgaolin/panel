// A reusable, IDE-style dockable panel framework for Flutter desktop.
//
// This file defines the plain data types of the framework. It has no
// dependency on the (experimental) windowing APIs, so it stays trivially
// testable and import-clean.

import 'package:flutter/widgets.dart';

/// Builds the body of a panel. Receives the [BuildContext] of the host
/// (either the docked tab area in the main window, or a detached OS window).
typedef PanelContentBuilder = Widget Function(BuildContext context);

/// The dockable regions of the workspace.
///
/// [center] is the primary area (think: the editor). [left], [right] and
/// [bottom] are the side docks that hold tool panels.
enum DockSide { left, right, bottom, center }

extension DockSideLabel on DockSide {
  String get label => switch (this) {
    DockSide.left => 'Left',
    DockSide.right => 'Right',
    DockSide.bottom => 'Bottom',
    DockSide.center => 'Center',
  };

  /// Whether the region grows horizontally (side docks) or is the flexible
  /// center.
  bool get isHorizontalDock => this == DockSide.left || this == DockSide.right;
}

/// Immutable description of a panel that can be docked or detached.
///
/// A [PanelDescriptor] is registered once with the [PanelManager]; its
/// [builder] is invoked wherever the panel currently lives.
@immutable
class PanelDescriptor {
  const PanelDescriptor({
    required this.id,
    required this.title,
    required this.builder,
    this.icon,
    this.detachedSize,
  });

  /// Stable, unique identifier used by the manager to track placement.
  final String id;

  /// Human-readable title shown on the tab and the detached window.
  final String title;

  /// Optional icon shown on the tab.
  final IconData? icon;

  /// Builds the panel's content.
  final PanelContentBuilder builder;

  /// Preferred size of this panel's detached floating window. When null,
  /// `PanelDockConfig.defaultDetachedSize` is used.
  final Size? detachedSize;
}
