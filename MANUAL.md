# Panes — building a dockable / detachable panel micro-framework on macOS

This is a step‑by‑step manual for rebuilding **Panes**: an IDE‑style workspace
where panels can be docked into left/right/bottom/center regions, dragged between
regions to snap into place, minimized, and **detached into real macOS windows**
that have no title bar and can be dragged back onto the main window to re‑dock.

It is built on Flutter's experimental **multi‑window** APIs (the
`examples/multiple_windows` reference app) plus a thin layer of native **AppKit**
code for the borderless‑window look and the drag‑back‑to‑snap behavior.

---

## 0. Why this is fiddly (read first)

Flutter's windowing APIs are experimental and only exist on the `main`/`master`
channel. While building this, three hard facts shaped every decision:

1. **The APIs are `@internal` and live in a private file.** You import
   `package:flutter/src/widgets/_window.dart` and silence two analyzer rules:
   ```dart
   // ignore_for_file: invalid_use_of_internal_member
   // ignore_for_file: implementation_imports
   ```
2. **On macOS you cannot create a borderless window through Flutter.**
   `WindowController(decorated: false)` throws
   `UnimplementedError('Undecorated windows are not yet implemented on macOS.')`
   (`flutter/lib/src/widgets/_window_macos.dart`). So "no title bar" must be done
   natively in AppKit _after_ Flutter creates the (decorated) window.
3. **Regular windows expose no screen position** (no `setPosition`, no position
   getter). So "drag the window back onto the main window to snap" cannot be
   detected from Dart — it requires native `NSWindow` frame tracking.

The design works _with_ these limits: Flutter creates & renders the windows (one
shared isolate, so all panels share one `PanelManager`), and AppKit handles the
chrome + frame tracking.

---

## 1. Prerequisites

- **fvm** with a `master`‑channel Flutter pinned locally. Last verified against
  `master 3.48.0‑1.0.pre‑320` (Dart 3.14). Verify:
  ```bash
  fvm flutter --version      # channel should be master/main
  ```
- Enable the windowing feature flag **once** (it's a build‑time framework flag,
  NOT a `--dart-define` — passing it via `--dart-define` is rejected):
  ```bash
  fvm flutter config --enable-windowing
  ```

---

## 2. Run it

```bash
fvm flutter run -d macos
# optional smoke test: pop a panel out on first frame (headless verification)
fvm flutter run -d macos --dart-define=AUTODETACH=terminal
```

---

## 3. macOS runner changes (the part that crashes if you skip it)

The default Flutter macOS template creates a `MainFlutterWindow` (a
`FlutterViewController`) from the storyboard at launch. The first time Dart asks
the engine to create a window, the engine calls `enableMultiView`, which
**aborts** if a view controller was already attached:

```
*** Terminating app ... reason: 'Multiview can only be enabled before adding any view controllers.'
-[FlutterEngine enableMultiView] ...
```

Fix (mirrors `examples/multiple_windows`): run a **headless engine** and let Dart
create every window.

### 3a. `macos/Runner/AppDelegate.swift`

Create a `FlutterEngine` in `applicationDidFinishLaunching` (no view controller).
This file _also_ holds our native dock helper (see §6).

### 3b. `macos/Runner/Base.lproj/MainMenu.xib`

Remove the auto‑instantiated window and its outlet:

- delete the `<window ... customClass="MainFlutterWindow">…</window>` object,
- delete the `mainFlutterWindow` outlet on the `AppDelegate` object.

(`MainFlutterWindow.swift` can stay in the project unused — it's just never
instantiated. The xib no longer references it.)

---

## 4. How multiple windows render (the composition model)

- `main()` calls **`runWidget(...)`** (not `runApp`).
- The root is a **`WindowManager`**, and the main window is just its first entry:
  ```dart
  PanelScope(                       // shared PanelManager, ABOVE WindowManager (see §5)
    manager: manager,
    child: WindowManager(
      initialWindows: <WindowEntry>[
        WindowEntry(
          controller: mainController, // WindowController(...)
          builder: (ctx) => MaterialApp(home: Workspace()),
        ),
      ],
    ),
  )
  ```
- `WindowManager` owns the `WindowRegistry` and renders **every** registered
  window — the main one included — as a sibling view via `ViewCollection`. Each
  entry's `builder` supplies that window's own `MaterialApp`.
- To open a new window you build a controller + a `WindowEntry` and register it:
  ```dart
  final controller = WindowController(title: ..., size: ...);
  final entry = WindowEntry(controller: controller, builder: (ctx) => MyContent());
  WindowRegistry.of(context).register(entry);   // appears as its own OS window
  // ...controller.destroy() + registry.unregister(entry) to close it.
  ```

---

## 5. Two non‑obvious gotchas inside Flutter

1. **`PanelScope` must sit ABOVE `WindowManager`.** Detached windows render as
   _sibling_ views under `WindowManager`, not as descendants of the main window.
   They only inherit ancestors of `WindowManager`, so the shared `PanelManager`
   has to be provided above it or the floating windows can't see it.

2. **Each detached window needs its OWN `MaterialApp` + a `Material` ancestor.** A
   sibling view is not a descendant of the main window's `Navigator`/`Overlay`, so
   `Tooltip`/`PopupMenuButton` throw **"No Overlay widget found"** and layout can
   blow up (a giant `RenderFlex overflowed by … pixels`). And without a `Material`
   in the subtree, `WidgetsApp` paints text with its debug "missing style" (red
   text, yellow underline). So each window wraps its content in
   `MaterialApp(theme: …, home: Material(color: …, child: …))` — a neutral theme
   derived from `PanelTheme`, and a plain `Material` (not a full `Scaffold`).

---

## 6. Native AppKit layer (`AppDelegate.swift` + a `dart:ffi` bridge)

Dart talks to AppKit over **FFI**, not a method channel:

- **Forward calls** (Dart → Swift) go through **ffigen** bindings
  (`lib/panels/panes_dock_bindings.dart`, generated from `macos/Runner/panes_dock.h`
  via `ffigen.yaml`) resolved against `DynamicLibrary.executable()`. Swift exposes
  the entry points as top‑level `@_cdecl` C‑ABI functions
  (`panes_dock_register/decorate/decorate_main/start_window_drag`) that forward to
  a `PanesDock: NSObject` singleton.
- **Reverse events** (Swift → Dart: drag/drop) are delivered through
  `NativeCallable.listener` function pointers that Dart registers once via
  `panes_dock_register`. Tokens crossing the boundary are `strdup`'d in Swift and
  freed in Dart (`malloc.free`).
- `lib/panels/native_dock.dart` wraps all of this; its public API
  (`decorate`/`decorateMain`/`startWindowDrag`/`onPanelDrag`/`onPanelDrop`) is the
  same shape it had as a channel, so callers didn't change.

> Regenerate bindings after editing the header: `dart run ffigen --config ffigen.yaml`.
> (`swiftgen` is **not** used — it binds standalone Swift modules, not app‑embedded
> Runner logic; `@_cdecl` + ffigen‑from‑C‑header is the right fit.)

### Title‑bar hiding (Stage 1)

When Dart detaches a panel it sets the window **title to a token** `panel::<id>`
(invisible once the bar is hidden) and calls `decorate(token)`. Swift finds the
`NSWindow` by that title, applies the hidden‑title‑bar look, then repositions it to
the pointer on the active Space (`setFrameTopLeftPoint` + `.moveToActiveSpace`) so a
tear‑off lands where the cursor is:

```swift
window.styleMask.insert(.fullSizeContentView)
window.titleVisibility = .hidden
window.titlebarAppearsTransparent = true
window.isMovableByWindowBackground = true            // drag by the body
window.standardWindowButton(.closeButton)?.isHidden = true
window.standardWindowButton(.miniaturizeButton)?.isHidden = true
window.standardWindowButton(.zoomButton)?.isHidden = true
```

> We deliberately do **not** use a true `.borderless` window: borderless windows
> can't become key (input breaks) and aren't resizable. The hidden‑title‑bar
> approach looks identical but keeps focus/resize working.

### Main window title bar

`decorateMain` makes the **main** window's title bar transparent + full‑size
(`fullSizeContentView`, `titleVisibility = .hidden`, `titlebarAppearsTransparent`)
but keeps the traffic‑light buttons. Because content now draws under the bar, the
Flutter side reserves a ~30px top strip (also the native drag region) so the dock
clears the traffic lights. There is no Flutter `AppBar`.

### Drag‑back snapping (Stage 2)

- `NSWindow.didMoveNotification` tells Swift a panel window started moving. It
  then runs a **60 fps timer** that streams `onPanelDrag` with the panel frame,
  the main‑window frame, and the live **pointer** location (all flipped to a
  shared top‑left origin — an affine flip preserves relative geometry).
- Drop is detected by polling `NSEvent.pressedMouseButtons` in that timer, not a
  `leftMouseUp` monitor: `movableByWindowBackground` runs a nested event‑tracking
  loop that swallows local mouse‑up monitors, which is why the indicator used to
  stick after release. When the button clears, Swift fires `onPanelDrop`.
- Dart (`PanelManager`) maps the **pointer** onto the main window's dock regions
  using the real dock extents. The preview appears **only while the pointer is
  over the main window**, shows the **single** target region sized to where the
  panel will land, and animates between regions as the pointer moves (à la
  iTerm). On drop it calls `redock(id, toSide: side)`.

### Header drag

A floating window is `movableByWindowBackground`, but Flutter's content view eats
the mouse so dragging the custom header alone wouldn't move it. On pointer‑down in
the header, Dart calls `startWindowDrag(token)` → Swift runs
`NSWindow.performDrag(with: NSApp.currentEvent)` (the standard custom‑titlebar
technique). The header buttons sit outside that hit region so they stay clickable.

---

## 7. Framework structure (`lib/panels/`)

| File                       | Responsibility                                                                                                                                                                                                                       |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `panel.dart`               | `PanelDescriptor` (id, title, icon, builder) + `DockSide` enum. Pure data, no windowing import.                                                                                                                                      |
| `panel_config.dart`        | `PanelDockConfig` (sizes, capability toggles, durations, `storage`), `PanelTheme` (Material‑independent colors), `PanelTabSpec`, `PanelStorage`, `PanelDockStrings`.                                                                 |
| `panel_manager.dart`       | `PanelManager` (ChangeNotifier): registry, regions‑as‑groups state, detach/redock, split/merge, focus, drag state, save/load/restore, native drag handlers. `PanelScope` InheritedNotifier.                                          |
| `panel_dock.dart`          | The dock UI: resizable regions & groups, tabbed groups, **Draggable** tabs (reorder within strip / split / tear‑off), drop‑zone overlays (interactive + native), collapse/minimize, pop‑out/split buttons. Paints from `PanelTheme`. |
| `floating_panel.dart`      | `FloatingPanelContent`: the detached window body — own `MaterialApp` + `Material`, slim header (drag handle + minimize / dock‑to‑menu / snap‑back).                                                                                  |
| `native_dock.dart`         | `dart:ffi` bridge to AppKit (`decorate`, `decorateMain`, `startWindowDrag`, reverse `onPanelDrag`/`onPanelDrop` via `NativeCallable`).                                                                                               |
| `panes_dock_bindings.dart` | ffigen‑generated FFI bindings (from `macos/Runner/panes_dock.h`).                                                                                                                                                                    |
| `panel_shortcuts.dart`     | `SplitPanelIntent`/`MergePanelIntent`, `defaultPanelShortcuts()`, `panelActions()`.                                                                                                                                                  |
| `panels.dart`              | Barrel / public API.                                                                                                                                                                                                                 |

### Using the framework in your own app

```dart
final manager = PanelManager()
  ..registerPanel(PanelDescriptor(id: 'explorer', title: 'Explorer',
      icon: Icons.folder, builder: (_) => const Explorer()), side: DockSide.left)
  ..registerPanel(PanelDescriptor(id: 'editor', title: 'Editor',
      builder: (_) => const Editor()), side: DockSide.center);

runWidget(PanelScope(
  manager: manager,
  child: WindowManager(
    initialWindows: <WindowEntry>[
      WindowEntry(
        controller: WindowController(size: const Size(1180, 760)),
        builder: (_) => MaterialApp(home: Scaffold(body: PanelDock())),
      ),
    ],
  ),
));
```

### Region subdivisions (split views)

Each region is an **ordered list of groups** laid out along the region's axis
(bottom/center = side-by-side columns, left/right = stacked rows), with weighted
splitters between them — so panels can sit next to each other, not just as tabs.
In `PanelManager` a region is `List<_Group>` + per-group `weight` + `activeGroup`;
the key ops are `addPanelAsTab`, `splitBeside(before:)`, `splitActiveGroup`, and
`adjustGroupWeights`. The layout is non-recursive (one axis per region).

While dragging a tab, each group shows three drop zones with a live preview:
center = **Add tab**, leading/trailing edge = **New group** (split). Empty side
regions show thin edge targets; the empty center shows a drop target. A **split
button** on any group with ≥2 tabs pops the active tab into a new adjacent group.

### Interactions

- **Reorder tabs** by dragging a tab sideways within its strip → an accent
  insertion line shows where it will land.
- **Drag a tab** onto a group's center → add as a tab; onto a group's edge → split
  into a new group beside it; onto an empty side/center region → dock there.
- **Drag a tab outside the window** (or click the **⧉ pop‑out** button) → detaches
  into a borderless floating window.
- **Drag a floating window** over the main window → the single target region lights
  up under the pointer; release to snap back. (Also: header **Snap back** button,
  **Dock to…** menu, or native close.)
- **Split / merge with the keyboard**: focus a group (click it — it gets an accent
  border), then ⌘\ splits its active tab into a new group, ⌘⇧\ merges it back.
- **Minimize** a dock to a thin strip via the dock's `–` button; minimize a
  floating window via its header `–`.
- Dragging a tab onto **its own** group does nothing (no spurious targets).

---

## 8. Known limitations

- **macOS only** for the native chrome (the FFI bridge no‑ops elsewhere — the
  Dart dock itself works cross‑platform).
- Detached windows are real OS windows, so they can move to any screen — but the
  snap‑back zone math assumes the panel is over the main window.
- All of `package:flutter/src/widgets/_window.dart` is experimental and may change
  in any Flutter patch release.
