// macOS implementation of [PanelWindowingBackend]: detached panels become real
// borderless top-level windows via Flutter's experimental windowing APIs, with
// native chrome + drag-back snapping over FFI.
//
// This is the ONLY place in the framework that touches the experimental
// windowing APIs and the native bridge, so it carries the two analyzer ignores
// the official `examples/multiple_windows` sample uses. (In the package split
// this whole file moves to `panel_macos`.)

// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: implementation_imports

import 'package:flutter/widgets.dart';
import 'package:flutter/src/widgets/_window.dart';

import 'package:panel/panel.dart';

import 'floating_panel.dart';
import 'native_dock.dart';

/// One detached panel window.
class _FloatingWindow {
  _FloatingWindow(this.controller, this.entry);
  final WindowController controller;
  final WindowEntry entry;
}

/// Forwards window lifecycle events to closures (intercepts native close so it
/// re-docks instead of destroying, and cleans up on destroy).
class _PanelWindowDelegate with WindowControllerDelegate {
  _PanelWindowDelegate({required this.onCloseRequested, required this.onDestroyed});
  final VoidCallback onCloseRequested;
  final VoidCallback onDestroyed;

  @override
  void onWindowCloseRequested(WindowController controller) => onCloseRequested();

  @override
  void onWindowDestroyed() {
    onDestroyed();
    super.onWindowDestroyed();
  }
}

/// Hosts detached panels in real macOS windows.
///
/// Construct one, pass it to `PanelManager(windowing: backend)`, and mount a
/// [MacosPanelHost] under your `MaterialApp` so the backend can obtain the
/// `WindowRegistry` and decorate the main window.
class MacosWindowingBackend extends PanelWindowingBackend {
  MacosWindowingBackend();

  PanelManager? _manager;
  WindowRegistry? _registry;
  final Map<String, _FloatingWindow> _windows = <String, _FloatingWindow>{};

  @override
  bool get supportsDetach => true;

  @override
  void attach(PanelManager manager) {
    _manager = manager;
    NativeDock.instance
      ..ensureWired()
      ..onPanelDrag = _onPanelDrag
      ..onPanelDrop = _onPanelDrop;
  }

  /// Wires the windowing `WindowRegistry` (from a [MacosPanelHost] context).
  /// Detached windows are rendered as sibling views by that registry.
  void bindRegistry(WindowRegistry registry) => _registry = registry;

  /// Makes the main window's title bar transparent/full-size.
  void decorateMainWindow() => NativeDock.instance.decorateMain();

  @override
  void open(PanelDescriptor descriptor, {required DockSide origin}) {
    final PanelManager manager = _manager!;
    final WindowRegistry? registry = _registry;
    if (registry == null) return; // host not mounted yet
    final String id = descriptor.id;
    final String token = panelWindowToken(id);
    late final WindowEntry entry;
    final WindowController controller = WindowController(
      title: token,
      size: descriptor.detachedSize ?? manager.config.defaultDetachedSize,
      constraints: manager.config.detachedConstraints,
      delegate: _PanelWindowDelegate(
        onCloseRequested: () => manager.redock(id),
        onDestroyed: () => _windows.remove(id),
      ),
    );
    entry = WindowEntry(controller: controller, builder: (BuildContext context) => FloatingPanelContent(panelId: id));
    _windows[id] = _FloatingWindow(controller, entry);
    registry.register(entry);
    if (manager.config.enableNativeChrome) NativeDock.instance.decorate(token);
  }

  @override
  void close(String id) {
    final _FloatingWindow? w = _windows.remove(id);
    if (w == null) return;
    _registry?.unregister(w.entry);
    w.controller.destroy();
  }

  @override
  void minimize(String id) => _windows[id]?.controller.setMinimized(true);

  @override
  void focus(String id) => _windows[id]?.controller.activate();

  @override
  void beginWindowDrag(String id) {
    if (_windows.containsKey(id)) NativeDock.instance.startWindowDrag(panelWindowToken(id));
  }

  // Native drag-back reporting -> generic manager hooks.
  void _onPanelDrag(WindowFrame panel, Rect main, Offset pointer) =>
      _manager?.updateExternalDragHover(pointer, main);

  void _onPanelDrop(String token) =>
      _manager?.endExternalDrag(commitId: panelIdFromToken(token));
}

/// Mount under your `MaterialApp` (above the `PanelDock`). It hands the
/// windowing `WindowRegistry` to the [backend] and makes the main window's
/// title bar transparent on first frame.
class MacosPanelHost extends StatefulWidget {
  const MacosPanelHost({super.key, required this.backend, required this.child});

  final MacosWindowingBackend backend;
  final Widget child;

  @override
  State<MacosPanelHost> createState() => _MacosPanelHostState();
}

class _MacosPanelHostState extends State<MacosPanelHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.backend.decorateMainWindow());
  }

  @override
  Widget build(BuildContext context) {
    widget.backend.bindRegistry(WindowRegistry.of(context));
    return widget.child;
  }
}
