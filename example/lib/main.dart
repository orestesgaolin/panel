// Demo app for the dockable panels framework (lib/panels/).
//
// Enable the experimental windowing feature flag once, then run on macOS:
//
//   fvm flutter config --enable-macos-desktop --enable-windowing
//   fvm flutter run -d macos
//
// (The flag used to be settable per-run via
// --dart-define=FLUTTER_ENABLED_FEATURE_FLAGS=windowing; flutter_tools now
// rejects that and reads feature flags from `flutter config` only.)
//
// The windowing APIs are `@internal` and only exist on the main/master
// channel. WindowManager/WindowEntry match Flutter's current
// examples/multiple_windows app; the two analyzer ignores are still required.

// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/src/widgets/_window.dart';

import 'package:panel/panel.dart';
import 'package:panel_macos/panel_macos.dart';

/// Monospace family used for code/terminal content. Menlo ships on every macOS.
const List<String> kMonoFonts = <String>['Menlo', 'SF Mono', 'monospace'];

/// A neutral, untinted Material theme for the main window chrome, derived from
/// the framework's [PanelTheme] so there's no Material surface tint anywhere.
ThemeData _buildTheme(Brightness brightness) {
  final PanelTheme panel = brightness == Brightness.dark
      ? PanelTheme.dark()
      : PanelTheme.light();
  final ColorScheme scheme =
      ColorScheme.fromSeed(
        seedColor: panel.accent,
        brightness: brightness,
      ).copyWith(
        surface: panel.surface,
        onSurface: panel.text,
        primary: panel.accent,
        surfaceTint: Colors.transparent,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: panel.background,
  );
}

/// Closes the whole app when the main window is destroyed.
class _MainWindowDelegate with WindowControllerDelegate {
  @override
  void onWindowDestroyed() {
    super.onWindowDestroyed();
    exit(0);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final MacosWindowingBackend backend = MacosWindowingBackend();
  final PanelManager manager =
      PanelManager(
          config: PanelDockConfig(storage: JsonFileStorage()),
          windowing: backend,
        )
        ..registerPanel(_explorerPanel, side: DockSide.left)
        ..registerPanel(_outlinePanel, side: DockSide.left, activate: false)
        ..registerPanel(_editorPanel, side: DockSide.center)
        ..registerPanel(_pdfPanel, side: DockSide.center, activate: false)
        ..registerPanel(_stylesPanel, side: DockSide.center, activate: false)
        ..registerPanel(_readmePanel, side: DockSide.center, activate: false)
        ..registerPanel(_inspectorPanel, side: DockSide.right)
        ..registerPanel(_terminalPanel, side: DockSide.bottom)
        ..registerPanel(_problemsPanel, side: DockSide.bottom, activate: false);

  // Reload the last layout (if any) before showing the window.
  await manager.restore();

  runWidget(PanelExampleApp(manager: manager, backend: backend));
}

/// Example [PanelStorage]: persists the layout to a JSON file. A real app might
/// use shared_preferences or its own settings store instead.
class JsonFileStorage implements PanelStorage {
  File get _file => File('${Directory.systemTemp.path}/panes_layout.json');

  @override
  Future<Map<String, Object?>?> read() async {
    try {
      if (!_file.existsSync()) return null;
      return jsonDecode(await _file.readAsString()) as Map<String, Object?>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(Map<String, Object?> layout) async {
    try {
      await _file.writeAsString(jsonEncode(layout));
    } catch (_) {
      /* best-effort */
    }
  }
}

class PanelExampleApp extends StatefulWidget {
  const PanelExampleApp({
    super.key,
    required this.manager,
    required this.backend,
  });

  final PanelManager manager;
  final MacosWindowingBackend backend;

  @override
  State<PanelExampleApp> createState() => _PanelExampleAppState();
}

class _PanelExampleAppState extends State<PanelExampleApp> {
  final WindowController _controller = WindowController(
    size: const Size(1180, 760),
    constraints: const BoxConstraints(minWidth: 720, minHeight: 480),
    title: 'Panel — Dockable Panels',
    delegate: _MainWindowDelegate(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PanelScope sits ABOVE WindowManager so the detached window subtrees (which
    // WindowManager renders as sibling views, each with its own MaterialApp) can
    // still read the shared PanelManager.
    return PanelScope(
      manager: widget.manager,
      child: WindowManager(
        initialWindows: <WindowEntry>[
          WindowEntry(
            controller: _controller,
            builder: (BuildContext context) => MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Panel',
              theme: _buildTheme(Brightness.light),
              darkTheme: _buildTheme(Brightness.dark),
              themeMode: ThemeMode.system,
              // MacosPanelHost (under MaterialApp) hands the WindowRegistry to
              // the backend and makes the main window's title bar transparent.
              home: MacosPanelHost(
                backend: widget.backend,
                child: const _Workspace(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Workspace extends StatefulWidget {
  const _Workspace();

  @override
  State<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<_Workspace> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final PanelManager m = PanelScope.of(context);
      // Optional smoke-test hook: `--dart-define=AUTODETACH=terminal` pops a
      // panel out on first frame so the floating path can be exercised headless.
      const String auto = String.fromEnvironment('AUTODETACH');
      if (auto.isNotEmpty) {
        m.detach(auto);
      }
      // `--dart-define=SELFTEST=1` exercises split/merge + focus paths headlessly.
      if (const bool.fromEnvironment('SELFTEST')) {
        m.setFocusedGroup(DockSide.center, 0);
        m.splitFocused(); // center editors -> two groups side-by-side
        m.splitActiveGroup(DockSide.bottom, 0); // terminal | problems
        m.mergeFocused(); // collapse the center split again
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final PanelManager manager = PanelScope.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: <Widget>[
          // Transparent strip under the native traffic lights; also the window
          // drag region. Left-padded so content clears the traffic lights.
          const SizedBox(height: 30),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              // ⌘\ split the focused panel, ⌘⇧\ merge it.
              child: Shortcuts(
                shortcuts: defaultPanelShortcuts(),
                child: Actions(
                  actions: panelActions(manager),
                  child: const Focus(autofocus: true, child: PanelDock()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Demo panel content. These are ordinary widgets — the framework doesn't care
// what's inside a panel.
// ---------------------------------------------------------------------------

PanelDescriptor get _explorerPanel => PanelDescriptor(
  id: 'explorer',
  title: 'Explorer',
  icon: Icons.folder_outlined,
  builder: (_) => const _FileTree(),
);

PanelDescriptor get _outlinePanel => PanelDescriptor(
  id: 'outline',
  title: 'Outline',
  icon: Icons.account_tree_outlined,
  builder: (_) => const _ListPanel(
    items: <String>[
      'class PanelManager',
      '  registerPanel()',
      '  detach()',
      '  redock()',
      'class PanelDock',
      'class FloatingPanelContent',
    ],
  ),
);

PanelDescriptor get _editorPanel => PanelDescriptor(
  id: 'editor',
  title: 'main.dart',
  icon: Icons.description_outlined,
  builder: (_) => const _EditorMock(),
);

PanelDescriptor get _stylesPanel => PanelDescriptor(
  id: 'styles',
  title: 'styles.css',
  icon: Icons.css,
  builder: (_) => const _CodeView(
    code: '''
.workspace {
  display: grid;
  grid-template-columns: 240px 1fr 300px;
  gap: 1px;
  background: var(--border);
}

.tab.active { border-bottom: 2px solid var(--accent); }
''',
  ),
);

PanelDescriptor get _readmePanel => PanelDescriptor(
  id: 'readme',
  title: 'README.md',
  icon: Icons.article_outlined,
  builder: (_) => const _CodeView(
    code: '''
# Panes

A dockable / detachable panel framework.

- Drag a tab to an edge to split a region.
- ⌘\\ splits the focused panel, ⌘⇧\\ merges it.
- Detach by dragging a tab out of the window.
''',
  ),
);

PanelDescriptor get _pdfPanel => PanelDescriptor(
  id: 'pdf',
  title: 'sample.pdf',
  icon: Icons.picture_as_pdf_outlined,
  builder: (_) => const _PdfPreview(),
);

PanelDescriptor get _inspectorPanel => PanelDescriptor(
  id: 'inspector',
  title: 'Inspector',
  icon: Icons.tune,
  builder: (_) => const _InspectorMock(),
);

PanelDescriptor get _terminalPanel => PanelDescriptor(
  id: 'terminal',
  title: 'Terminal',
  icon: Icons.terminal,
  builder: (_) => const _TerminalMock(),
);

PanelDescriptor get _problemsPanel => PanelDescriptor(
  id: 'problems',
  title: 'Problems',
  icon: Icons.error_outline,
  builder: (_) => const _ListPanel(items: <String>['No problems detected 🎉']),
);

class _FileTree extends StatelessWidget {
  const _FileTree();

  @override
  Widget build(BuildContext context) {
    const List<(int, IconData, String)> rows = <(int, IconData, String)>[
      (0, Icons.folder_open, 'panes'),
      (1, Icons.folder_open, 'lib'),
      (2, Icons.folder_outlined, 'panels'),
      (3, Icons.code, 'panel.dart'),
      (3, Icons.code, 'panel_manager.dart'),
      (3, Icons.code, 'panel_dock.dart'),
      (3, Icons.code, 'floating_panel.dart'),
      (2, Icons.code, 'main.dart'),
      (1, Icons.folder_outlined, 'macos'),
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: <Widget>[
        for (final (int depth, IconData icon, String name) in rows)
          Padding(
            padding: EdgeInsets.only(left: 8.0 + depth * 16, top: 2, bottom: 2),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(name, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ListPanel extends StatelessWidget {
  const _ListPanel({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: <Widget>[
        for (final String item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              item,
              style: const TextStyle(
                fontFamily: 'Menlo',
                fontFamilyFallback: kMonoFonts,
                fontSize: 12.5,
              ),
            ),
          ),
      ],
    );
  }
}

class _EditorMock extends StatelessWidget {
  const _EditorMock();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    const String code = '''
import 'package:flutter/material.dart';
import 'panels/panels.dart';

void main() {
  final manager = PanelManager()
    ..registerPanel(explorer, side: DockSide.left)
    ..registerPanel(editor, side: DockSide.center);

  runWidget(PanelExampleApp(manager: manager));
}

// • Drag a tab to an edge to re-dock it.
// • Drag a tab out of the window to detach it
//   into a floating, minimizable OS window.
// • Use "Snap back" in a floating window to
//   re-dock it.
''';
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: SelectableText(
          code,
          style: TextStyle(
            fontFamily: kMonoFonts.first,
            fontFamilyFallback: kMonoFonts,
            fontSize: 13,
            height: 1.5,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _CodeView extends StatelessWidget {
  const _CodeView({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: SelectableText(
          code.trim(),
          style: TextStyle(
            fontFamily: kMonoFonts.first,
            fontFamilyFallback: kMonoFonts,
            fontSize: 13,
            height: 1.5,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Renders the bundled `assets/sample.pdf` with [PdfReader] — a pure-Dart
/// viewer (search, page navigation, thumbnail sidebar) from
/// `package:dart_pdf_editor`. No native printing plugin is involved, so it
/// renders happily inside a detached floating window too: pop this tab out
/// and the viewer keeps working in its own OS window.
class _PdfPreview extends StatefulWidget {
  const _PdfPreview();

  @override
  State<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<_PdfPreview> {
  // Loaded once; the same bytes are reused if this panel is detached/redocked.
  late final Future<Uint8List> _bytes = rootBundle
      .load('assets/sample.pdf')
      .then((ByteData data) => data.buffer.asUint8List());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Failed to load PDF: ${snapshot.error}'));
        }
        final Uint8List? bytes = snapshot.data;
        if (bytes == null) {
          return const Center(child: CircularProgressIndicator());
        }
        // documentId pins the scroll/zoom memory to this document so it
        // survives detaching the panel into a window and docking it back.
        return PdfReader(bytes: bytes, documentId: 'assets/sample.pdf');
      },
    );
  }
}

class _InspectorMock extends StatelessWidget {
  const _InspectorMock();

  String _names(PanelManager m, DockSide side) {
    final List<PanelDescriptor> p = m.panelsIn(side);
    if (p.isEmpty) return '—';
    return p.map((PanelDescriptor d) => d.title).join(', ');
  }

  String _layout(PanelManager m, DockSide side) {
    final int n = m.groupCount(side);
    if (n == 0) return 'empty';
    return n == 1 ? 'merged' : 'split ×$n';
  }

  Iterable<Widget> _region(PanelManager m, DockSide side, String label) sync* {
    yield _Property(
      name: label,
      value: m.isCollapsed(side) ? 'minimized' : '${m.sizeOf(side).round()} px',
    );
    yield _Property(name: '· panels', value: _names(m, side));
    yield _Property(name: '· layout', value: _layout(m, side));
  }

  @override
  Widget build(BuildContext context) {
    // Depends on PanelScope (an InheritedNotifier), so this rebuilds live as
    // panels are docked, resized, split/merged, collapsed or detached.
    final PanelManager m = PanelScope.of(context);
    final String? centerId = m.activeIdOf(DockSide.center);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _Property(
          name: 'Active (center)',
          value: centerId == null ? '—' : m.descriptor(centerId).title,
        ),
        _Property(name: 'Center layout', value: _layout(m, DockSide.center)),
        _Property(name: 'Floating windows', value: '${m.floatingIds.length}'),
        const Divider(height: 20),
        ..._region(m, DockSide.left, 'Left dock'),
        const SizedBox(height: 8),
        ..._region(m, DockSide.right, 'Right dock'),
        const SizedBox(height: 8),
        ..._region(m, DockSide.bottom, 'Bottom dock'),
      ],
    );
  }
}

class _Property extends StatelessWidget {
  const _Property({required this.name, required this.value});

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalMock extends StatelessWidget {
  const _TerminalMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F1115),
      padding: const EdgeInsets.all(12),
      child: const SingleChildScrollView(
        child: Text(
          '\$ fvm flutter config --enable-windowing\n'
          '\$ fvm flutter run -d macos\n'
          'Launching lib/main.dart on macOS in debug mode...\n'
          'Syncing files to device macOS...                    \n'
          'Flutter run key commands.\n'
          'r Hot reload. 🔥🔥🔥',
          style: TextStyle(
            fontFamily: 'Menlo',
            fontFamilyFallback: kMonoFonts,
            fontSize: 12.5,
            color: Color(0xFF8AE234),
          ),
        ),
      ),
    );
  }
}
