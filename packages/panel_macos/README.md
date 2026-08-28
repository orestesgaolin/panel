# panel_macos

macOS windowing backend for [`package:panel`](https://pub.dev/packages/panel).
Detached panels become **real borderless top-level windows** with native chrome
(hidden title bar, movable by body) and **drag-back snapping**, implemented with
Flutter's windowing APIs + a small FFI bridge to AppKit.

## Usage

```dart
import 'package:panel/panel.dart';
import 'package:panel_macos/panel_macos.dart';

final backend = MacosWindowingBackend();
final manager = PanelManager(config: const PanelDockConfig(), windowing: backend);

// Inside your MaterialApp, above the PanelDock:
MacosPanelHost(backend: backend, child: const Workspace());
```

## Requirements

This package uses Flutter's **experimental** windowing feature:

* Build on the **main/master** channel.
* Enable it once: `flutter config --enable-windowing`.
* Your macOS runner must use the multi-window bootstrap — a headless
  `FlutterEngine` in `AppDelegate` and a windowless storyboard (otherwise
  `enableMultiView` aborts). See the example app's `macos/Runner`.

See Flutter's official
[Desktop Windowing API introduction](https://flutter.dev/blog/desktop-windowing-apis)
for the API's design and a minimal example.

The native dock helper ships in this plugin (Swift + FFI, resolved via
`DynamicLibrary.process()`), so consuming apps need no Swift in their Runner
beyond the bootstrap above. Supports both Swift Package Manager and CocoaPods.

> Experimental: the windowing APIs can change in any Flutter release.
