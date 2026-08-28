// Core state for the dockable panel framework.
//
// [PanelManager] is a [ChangeNotifier] that owns:
//   * the registry of all [PanelDescriptor]s,
//   * where each panel currently lives: a [DockSide] region is an ordered list
//     of *groups* (each a tab strip) laid out along the region's axis, so panels
//     can sit side-by-side; or a panel can be floating in its own OS window,
//   * per-region layout state (active group, region size, collapsed/minimized)
//     and per-group weights,
//   * the live drag/drop state used to paint drop zones.
//
// This file is platform-generic: it has NO dependency on the experimental
// windowing APIs or any native code. Detaching is delegated to a
// [PanelWindowingBackend] (see panel_windowing.dart); the default backend makes
// it a no-op, so the core compiles and runs anywhere (including web).

import 'dart:async';

import 'package:flutter/material.dart';

import 'panel.dart';
import 'panel_config.dart';
import 'panel_windowing.dart';

/// A tabbed group of panels within a region.
class _Group {
  _Group({this.weight = 1.0});
  final List<String> panelIds = <String>[];
  String? activeId;
  double weight;
}

/// A dock region: an ordered list of [_Group]s laid out along the region axis.
class _Region {
  _Region(this.size);
  final List<_Group> groups = <_Group>[];
  int activeGroup = 0;
  bool collapsed = false;
  double size;
}

/// Owns all panel placement and drives the UI via [ChangeNotifier].
///
/// Construct one, [registerPanel] your panels, expose it via [PanelScope], and
/// render a `PanelDock`. All tunables live in [config]. Detaching panels into
/// external windows is delegated to [windowing] (a [PanelWindowingBackend]);
/// the default backend disables detaching so the core runs on any platform.
class PanelManager extends ChangeNotifier {
  PanelManager({
    this.config = const PanelDockConfig(),
    PanelWindowingBackend windowing = const DisabledWindowing(),
  }) {
    _windowing = windowing;
    _regions = <DockSide, _Region>{
      for (final DockSide side in DockSide.values)
        side: _Region(config.initialSize(side)),
    };
    _windowing.attach(this);
  }

  /// Immutable configuration shared by the manager and the widgets.
  final PanelDockConfig config;

  /// Backend that hosts detached panels (OS windows). Defaults to a no-op.
  late final PanelWindowingBackend _windowing;

  /// Whether the active backend can detach panels into external windows.
  bool get supportsDetach => _windowing.supportsDetach;

  final Map<String, PanelDescriptor> _descriptors = <String, PanelDescriptor>{};
  late final Map<DockSide, _Region> _regions;
  // id -> the dock it should snap back to. Generic (no platform types).
  final Map<String, DockSide> _floatingOrigin = <String, DockSide>{};

  // ---- Drag/drop state -----------------------------------------------------
  bool _isDragging = false;
  DockSide? _dragSide;
  int _dragGroup = -1;
  String? _dragPanelId;

  /// Whether a tab is currently being dragged (drives the drop-zone overlays).
  bool get isDragging => _isDragging;

  /// The panel id of the in-flight tab drag, if any.
  String? get draggedPanelId => _dragPanelId;

  /// Whether group [gi] of [side] is the group the in-flight drag came from.
  /// Drop targets use this to suppress no-op "drop onto yourself" actions.
  bool isDragSource(DockSide side, int gi) =>
      _dragSide == side && _dragGroup == gi;

  /// Called by the UI when a tab drag begins, with the tab's origin group and id.
  void beginDrag({DockSide? side, int? group, String? panelId}) {
    _isDragging = true;
    _dragSide = side;
    _dragGroup = group ?? -1;
    _dragPanelId = panelId;
    notifyListeners();
  }

  /// Called by the UI when a tab drag ends.
  void endDrag() {
    if (!_isDragging) return;
    _isDragging = false;
    _dragSide = null;
    _dragGroup = -1;
    _dragPanelId = null;
    notifyListeners();
  }

  // ---- Registration --------------------------------------------------------

  /// Registers [descriptor] and docks it as a tab in [side]'s first group.
  void registerPanel(
    PanelDescriptor descriptor, {
    DockSide side = DockSide.right,
    bool activate = true,
  }) {
    _descriptors[descriptor.id] = descriptor;
    final _Region region = _regions[side]!;
    if (region.groups.isEmpty) region.groups.add(_Group());
    final _Group g = region.groups.first;
    g.panelIds.add(descriptor.id);
    if (activate || g.activeId == null) g.activeId = descriptor.id;
    notifyListeners();
  }

  /// The descriptor registered for [id].
  PanelDescriptor descriptor(String id) => _descriptors[id]!;

  // ---- Region / group queries ---------------------------------------------

  /// Whether [side] currently has any docked panels.
  bool hasPanels(DockSide side) => _regions[side]!.groups.isNotEmpty;

  /// Whether [side]'s dock is collapsed (minimized to a strip).
  bool isCollapsed(DockSide side) => _regions[side]!.collapsed;

  /// Current extent (width for left/right, height for bottom) of [side].
  double sizeOf(DockSide side) => _regions[side]!.size;

  /// Number of side-by-side groups in [side].
  int groupCount(DockSide side) => _regions[side]!.groups.length;

  /// All panels in [side], across every group, in visual order.
  List<PanelDescriptor> panelsIn(DockSide side) => _regions[side]!.groups
      .expand((_Group g) => g.panelIds)
      .map((String id) => _descriptors[id]!)
      .toList(growable: false);

  /// Panels in group [gi] of [side] (empty if out of range).
  List<PanelDescriptor> panelsInGroup(DockSide side, int gi) {
    final List<_Group> groups = _regions[side]!.groups;
    if (gi < 0 || gi >= groups.length) return const <PanelDescriptor>[];
    return groups[gi].panelIds
        .map((String id) => _descriptors[id]!)
        .toList(growable: false);
  }

  /// The selected panel id of group [gi] in [side], or null.
  String? activeInGroup(DockSide side, int gi) {
    final List<_Group> groups = _regions[side]!.groups;
    if (gi < 0 || gi >= groups.length) return null;
    final _Group g = groups[gi];
    return g.panelIds.contains(g.activeId)
        ? g.activeId
        : (g.panelIds.isEmpty ? null : g.panelIds.first);
  }

  /// Active panel of the region's active group (handy for summaries).
  String? activeIdOf(DockSide side) =>
      activeInGroup(side, _regions[side]!.activeGroup);

  /// Relative flex weight of group [gi] within [side].
  double groupWeight(DockSide side, int gi) {
    final List<_Group> groups = _regions[side]!.groups;
    return (gi >= 0 && gi < groups.length) ? groups[gi].weight : 1.0;
  }

  /// Whether [id] is currently in a detached (floating) window.
  bool isFloating(String id) => _floatingOrigin.containsKey(id);

  /// Ids of all panels currently floating.
  Iterable<String> get floatingIds => _floatingOrigin.keys;

  // ---- Region / group mutations -------------------------------------------

  /// Selects [id] as the active tab of group [gi] in [side].
  void setActiveInGroup(DockSide side, int gi, String id) {
    final _Region r = _regions[side]!;
    if (gi < 0 || gi >= r.groups.length) return;
    r.groups[gi].activeId = id;
    r.activeGroup = gi;
    notifyListeners();
  }

  /// Collapses/restores [side]'s dock (minimize to a strip).
  void toggleCollapsed(DockSide side) {
    _regions[side]!.collapsed = !_regions[side]!.collapsed;
    notifyListeners();
  }

  /// Sets [side]'s extent, clamped to `config.minDockExtent`.
  void setSize(DockSide side, double size) {
    _regions[side]!.size = size.clamp(config.minDockExtent, 1600);
    notifyListeners();
  }

  /// Shifts weight between group [gi] and [gi+1] by [deltaPx] of [totalPx].
  void adjustGroupWeights(
    DockSide side,
    int gi,
    double deltaPx,
    double totalPx,
  ) {
    final List<_Group> groups = _regions[side]!.groups;
    if (gi < 0 || gi + 1 >= groups.length || totalPx <= 0) return;
    final double sum = groups.fold(0.0, (double a, _Group g) => a + g.weight);
    final double shift = (deltaPx / totalPx) * sum;
    final double minW = sum * config.minGroupFraction;
    final double a = groups[gi].weight + shift;
    final double b = groups[gi + 1].weight - shift;
    if (a < minW || b < minW) return;
    groups[gi].weight = a;
    groups[gi + 1].weight = b;
    notifyListeners();
  }

  /// Adds [id] into the group at ([side], [gi]) as a tab.
  void addPanelAsTab(String id, DockSide side, int gi) {
    final _Region r = _regions[side]!;
    if (gi < 0 || gi >= r.groups.length) {
      _addAsNewGroup(id, side, r.groups.length);
      return;
    }
    final _Group target = r.groups[gi];
    final ({DockSide side, int gi})? loc = _locOf(id);
    if (loc != null && identical(_regions[loc.side]!.groups[loc.gi], target)) {
      target.activeId = id;
      r.activeGroup = gi;
      notifyListeners();
      return;
    }
    _removeFromDock(id);
    target.panelIds.add(id);
    target.activeId = id;
    r.activeGroup = r.groups.indexOf(target);
    notifyListeners();
  }

  /// Inserts [id] into group [gi] of [side] at tab position [index]. Reorders
  /// within the same group (used by tab drag-to-reorder) or moves [id] in from
  /// another group/window at that position.
  void movePanelToGroupAt(String id, DockSide side, int gi, int index) {
    final _Region r = _regions[side]!;
    if (gi < 0 || gi >= r.groups.length) {
      _addAsNewGroup(id, side, r.groups.length);
      return;
    }
    final _Group target = r.groups[gi];
    final ({DockSide side, int gi})? loc = _locOf(id);
    final bool sameGroup =
        loc != null && identical(_regions[loc.side]!.groups[loc.gi], target);

    if (sameGroup) {
      final int old = target.panelIds.indexOf(id);
      if (old < 0) return;
      int insert = index;
      if (old < insert) insert -= 1; // account for the removal shift
      insert = insert.clamp(0, target.panelIds.length - 1);
      if (insert == old) {
        target.activeId = id;
        r.activeGroup = gi;
        notifyListeners();
        return;
      }
      target.panelIds.removeAt(old);
      target.panelIds.insert(insert, id);
      target.activeId = id;
      r.activeGroup = gi;
      notifyListeners();
      return;
    }

    _removeFromDock(id);
    final int insert = index.clamp(0, target.panelIds.length);
    target.panelIds.insert(insert, id);
    target.activeId = id;
    r.activeGroup = r.groups.indexOf(target);
    notifyListeners();
  }

  /// Splits: puts [id] into a NEW group beside the group at ([side], [gi]).
  /// [before] places it on the leading side of that group.
  void splitBeside(String id, DockSide side, int gi, {required bool before}) {
    final _Region r = _regions[side]!;
    if (gi < 0 || gi >= r.groups.length) {
      _addAsNewGroup(id, side, r.groups.length);
      return;
    }
    final _Group ref = r.groups[gi];
    final ({DockSide side, int gi})? loc = _locOf(id);
    // Dropping a single-panel group beside itself is a no-op.
    if (loc != null &&
        identical(_regions[loc.side]!.groups[loc.gi], ref) &&
        ref.panelIds.length == 1) {
      return;
    }
    final double w = ref.weight;
    _removeFromDock(id);
    final _Group g =
        _Group(weight: w)
          ..panelIds.add(id)
          ..activeId = id;
    int idx = r.groups.indexOf(ref);
    idx = idx < 0 ? r.groups.length : (before ? idx : idx + 1);
    r.groups.insert(idx, g);
    r.activeGroup = idx;
    r.collapsed = false;
    notifyListeners();
  }

  /// Split button: pops the active panel of group [gi] into a new group after it.
  void splitActiveGroup(DockSide side, int gi) {
    final _Region r = _regions[side]!;
    if (gi < 0 || gi >= r.groups.length) return;
    final _Group g = r.groups[gi];
    if (g.panelIds.length < 2 || g.activeId == null) return;
    splitBeside(g.activeId!, side, gi, before: false);
  }

  /// Merges group [gi] into an adjacent group (collapsing a split). Its panels
  /// become tabs of the neighbor; no-op if the region has a single group.
  void mergeGroup(DockSide side, int gi) {
    final _Region r = _regions[side]!;
    if (r.groups.length < 2 || gi < 0 || gi >= r.groups.length) return;
    final _Group from = r.groups[gi];
    final int targetIndex = gi > 0 ? gi - 1 : gi + 1;
    final _Group target = r.groups[targetIndex];
    target.panelIds.addAll(from.panelIds);
    target.activeId = from.activeId ?? target.activeId;
    r.groups.removeAt(gi);
    r.activeGroup = r.groups.indexOf(target);
    _focusedGroup = r.activeGroup;
    notifyListeners();
  }

  // ---- Focus & keyboard ----------------------------------------------------

  DockSide? _focusedSide;
  int _focusedGroup = 0;

  /// The dock side that currently holds keyboard/interaction focus.
  DockSide? get focusedSide => _focusedSide;

  /// Index of the focused group within [focusedSide].
  int get focusedGroup => _focusedGroup;

  /// Whether group [gi] of [side] is the focused group.
  bool isFocusedGroup(DockSide side, int gi) =>
      _focusedSide == side && _focusedGroup == gi;

  /// Records the focused group (e.g. on click); also makes it the active group.
  void setFocusedGroup(DockSide side, int gi) {
    final _Region r = _regions[side]!;
    final int clamped = gi.clamp(0, r.groups.isEmpty ? 0 : r.groups.length - 1);
    if (_focusedSide == side && _focusedGroup == clamped) return;
    _focusedSide = side;
    _focusedGroup = clamped;
    r.activeGroup = clamped;
    notifyListeners();
  }

  /// Splits the focused group's active panel into a new adjacent group.
  void splitFocused() {
    if (_focusedSide != null) splitActiveGroup(_focusedSide!, _focusedGroup);
  }

  /// Merges the focused group into its neighbor.
  void mergeFocused() {
    if (_focusedSide != null) mergeGroup(_focusedSide!, _focusedGroup);
  }

  void _addAsNewGroup(String id, DockSide side, int atIndex) {
    final _Region r = _regions[side]!;
    _removeFromDock(id);
    final _Group g =
        _Group()
          ..panelIds.add(id)
          ..activeId = id;
    final int idx = atIndex.clamp(0, r.groups.length);
    r.groups.insert(idx, g);
    r.activeGroup = idx;
    r.collapsed = false;
    notifyListeners();
  }

  // ---- Detach / re-dock ----------------------------------------------------

  /// Tears [id] out of the dock into an external window via the [windowing]
  /// backend. No-op if the backend doesn't support detaching.
  void detach(String id) {
    if (!_windowing.supportsDetach) return;
    if (_floatingOrigin.containsKey(id)) return;
    final DockSide origin = _locOf(id)?.side ?? DockSide.right;
    _removeFromDock(id);
    _floatingOrigin[id] = origin;
    notifyListeners();
    _windowing.open(_descriptors[id]!, origin: origin);
  }

  /// Snaps a floating panel back into the dock as a new group on [toSide]
  /// (defaults to its origin), so it lands beside whatever is already there.
  void redock(String id, {DockSide? toSide}) {
    final DockSide? origin = _floatingOrigin.remove(id);
    if (origin == null) return;
    final DockSide target = toSide ?? origin;
    final _Region r = _regions[target]!;
    if (config.redockAsTab && r.groups.isNotEmpty) {
      final _Group g = r.groups.last;
      g.panelIds.add(id);
      g.activeId = id;
    } else {
      r.groups.add(
        _Group()
          ..panelIds.add(id)
          ..activeId = id,
      );
    }
    r.activeGroup = r.groups.length - 1;
    r.collapsed = false;
    notifyListeners();
    _windowing.close(id);
  }

  /// Starts a backend window-move for the floating panel [id] (e.g. so a custom
  /// header can act as the window's drag handle).
  void beginFloatingWindowDrag(String id) {
    if (_floatingOrigin.containsKey(id)) _windowing.beginWindowDrag(id);
  }

  /// Brings the floating window for [id] to the front.
  void focusFloating(String id) => _windowing.focus(id);

  /// Minimizes the floating window for [id].
  void minimizeFloating(String id) => _windowing.minimize(id);

  // ---- External (backend-driven) drag-back snapping ------------------------
  //
  // A windowing backend that can track a detached window being dragged reports
  // the live pointer here so the main window paints a snap-back target, then
  // commits the drop. All geometry is backend-agnostic.

  bool _externalDragging = false;
  DockSide? _externalHoverSide;

  /// Whether a detached window is currently being dragged over the workspace.
  bool get isExternalDragging => _externalDragging;

  /// The dock the dragged window currently hovers over, if any.
  DockSide? get externalHoverSide => _externalHoverSide;

  /// Backend hook: report the live [pointer] (top-left space) relative to the
  /// main window rect [main] while a detached window is dragged.
  void updateExternalDragHover(Offset pointer, Rect main) {
    _externalDragging = true;
    final DockSide? side = _zoneForPanelOverMain(pointer, main);
    if (side == _externalHoverSide) return; // avoid rebuild storms at 60fps
    _externalHoverSide = side;
    notifyListeners();
  }

  /// Backend hook: the drag ended. If [commitId] is over a dock zone, it
  /// re-docks there; otherwise the drag indicator is just cleared.
  void endExternalDrag({String? commitId}) {
    final DockSide? side = _externalHoverSide;
    _externalDragging = false;
    _externalHoverSide = null;
    if (commitId != null &&
        side != null &&
        _floatingOrigin.containsKey(commitId)) {
      redock(commitId, toSide: side);
    } else {
      notifyListeners();
    }
  }

  /// Maps the live pointer onto a dock zone of the main window, using the
  /// actual dock extents so the highlighted preview matches where the panel
  /// will land. Returns null when the pointer isn't over the main window (so no
  /// drop indicator shows until the dragged window is actually over us).
  DockSide? _zoneForPanelOverMain(Offset pointer, Rect main) {
    if (!main.contains(pointer)) return null;

    double extent(DockSide side, double fallback, double maxFrac, double full) {
      final double v =
          (hasPanels(side) && !isCollapsed(side)) ? sizeOf(side) : fallback;
      return v.clamp(0.0, full * maxFrac);
    }

    final double leftW = extent(
      DockSide.left,
      main.width * 0.18,
      0.45,
      main.width,
    );
    final double rightW = extent(
      DockSide.right,
      main.width * 0.20,
      0.45,
      main.width,
    );
    final double bottomH = extent(
      DockSide.bottom,
      main.height * 0.22,
      0.55,
      main.height,
    );
    final double x = pointer.dx - main.left;
    final double y = pointer.dy - main.top;

    if (y > main.height - bottomH) return DockSide.bottom;
    if (x < leftW) return DockSide.left;
    if (x > main.width - rightW) return DockSide.right;
    return DockSide.center;
  }

  // ---- Persistence ---------------------------------------------------------

  Timer? _saveTimer;

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (config.storage == null) return;
    // Debounce: coalesce rapid changes (drags, resizes) into one write.
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () {
      config.storage?.write(saveLayout());
    });
  }

  /// Serializes the current docked layout to a JSON-encodable map. Floating
  /// windows are not persisted (they re-dock on restore).
  Map<String, Object?> saveLayout() {
    return <String, Object?>{
      'version': 1,
      'regions': <String, Object?>{
        for (final DockSide side in DockSide.values)
          side.name: <String, Object?>{
            'size': _regions[side]!.size,
            'collapsed': _regions[side]!.collapsed,
            'activeGroup': _regions[side]!.activeGroup,
            'groups': <Object?>[
              for (final _Group g in _regions[side]!.groups)
                <String, Object?>{
                  'active': g.activeId,
                  'panels': List<String>.from(g.panelIds),
                },
            ],
          },
      },
    };
  }

  /// Restores a layout produced by [saveLayout]. Only currently-registered
  /// panels are placed; unknown ids are ignored and any registered panel not in
  /// [data] is appended to the center so nothing is lost.
  void loadLayout(Map<String, Object?> data) {
    final Object? regionsData = data['regions'];
    if (regionsData is! Map) return;
    final Set<String> known = _descriptors.keys.toSet();
    final Set<String> placed = <String>{};

    for (final DockSide side in DockSide.values) {
      final _Region r = _regions[side]!;
      final Object? rd = regionsData[side.name];
      r.groups.clear();
      if (rd is Map) {
        r.size = (rd['size'] as num?)?.toDouble() ?? config.initialSize(side);
        r.collapsed = rd['collapsed'] as bool? ?? false;
        final Object? groups = rd['groups'];
        if (groups is List) {
          for (final Object? gd in groups) {
            if (gd is! Map) continue;
            final List<String> ids = <String>[
              for (final Object? id
                  in (gd['panels'] as List? ?? const <Object?>[]))
                if (id is String &&
                    known.contains(id) &&
                    !placed.contains(id) &&
                    !isFloating(id))
                  id,
            ];
            if (ids.isEmpty) continue;
            placed.addAll(ids);
            String? active = gd['active'] as String?;
            if (active == null || !ids.contains(active)) active = ids.first;
            r.groups.add(
              _Group()
                ..panelIds.addAll(ids)
                ..activeId = active,
            );
          }
        }
        r.activeGroup = ((rd['activeGroup'] as num?)?.toInt() ?? 0).clamp(
          0,
          r.groups.isEmpty ? 0 : r.groups.length - 1,
        );
      } else {
        r.size = config.initialSize(side);
        r.collapsed = false;
        r.activeGroup = 0;
      }
    }

    // Don't lose registered, non-floating panels that weren't in the layout.
    final List<String> orphans = <String>[
      for (final String id in known)
        if (!placed.contains(id) && !isFloating(id)) id,
    ];
    if (orphans.isNotEmpty) {
      final _Region c = _regions[DockSide.center]!;
      if (c.groups.isEmpty) c.groups.add(_Group());
      c.groups.last.panelIds.addAll(orphans);
      c.groups.last.activeId ??= orphans.first;
    }
    notifyListeners();
  }

  /// Reads and applies a layout from `config.storage`, if any. Call after
  /// registering all panels (e.g. on startup).
  Future<void> restore() async {
    final PanelStorage? s = config.storage;
    if (s == null) return;
    final Map<String, Object?>? data = await s.read();
    if (data != null) loadLayout(data);
  }

  // ---- Internals -----------------------------------------------------------

  ({DockSide side, int gi})? _locOf(String id) {
    for (final MapEntry<DockSide, _Region> e in _regions.entries) {
      for (int i = 0; i < e.value.groups.length; i++) {
        if (e.value.groups[i].panelIds.contains(id)) {
          return (side: e.key, gi: i);
        }
      }
    }
    return null;
  }

  /// Removes [id] from its dock group (if any), pruning the group when it
  /// becomes empty. No-op for floating panels.
  void _removeFromDock(String id) {
    final ({DockSide side, int gi})? loc = _locOf(id);
    if (loc == null) return;
    final _Region r = _regions[loc.side]!;
    final _Group g = r.groups[loc.gi];
    g.panelIds.remove(id);
    if (g.activeId == id) {
      g.activeId = g.panelIds.isEmpty ? null : g.panelIds.last;
    }
    if (g.panelIds.isEmpty) {
      r.groups.removeAt(loc.gi);
      if (r.activeGroup >= r.groups.length) {
        r.activeGroup = r.groups.isEmpty ? 0 : r.groups.length - 1;
      }
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final String id in _floatingOrigin.keys.toList()) {
      _windowing.close(id);
    }
    _floatingOrigin.clear();
    super.dispose();
  }
}

/// Exposes the [PanelManager] to the widget tree, including the detached
/// window subtrees (rendered as sibling views by the framework's
/// `WindowManager`, so they still inherit ancestors placed above `MaterialApp`).
class PanelScope extends InheritedNotifier<PanelManager> {
  const PanelScope({
    super.key,
    required PanelManager manager,
    required super.child,
  }) : super(notifier: manager);

  static PanelManager of(BuildContext context) {
    final PanelScope? scope =
        context.dependOnInheritedWidgetOfExactType<PanelScope>();
    assert(scope != null, 'No PanelScope found in context');
    return scope!.notifier!;
  }
}
