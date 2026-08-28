# Panel

See demo at https://roszkowski.dev/panel

Flutter's official introduction to the windowing API:
https://flutter.dev/blog/desktop-windowing-apis

IDE-style dockable / tabbed / splittable / detachable panels for Flutter, split
into a platform-generic core and a macOS backend (Melos workspace).

Support for multi-window Flutter apps on macOS.

```
packages/
  panel/          core — pure Flutter, web-capable (no windowing/FFI/IO)
  panel_macos/    macOS backend — detachable OS windows (Flutter windowing + FFI)
example/          demo app (depends on both packages)
docs/docs/        Jaspr site (will embed Flutter-web builds of `panel`)
```

## Develop

```bash
fvm exec melos bootstrap          # resolve all packages
fvm exec melos run analyze        # analyze all packages
```

## Run the example (macOS)

```bash
fvm flutter config --enable-windowing   # once (experimental feature flag)
cd example && fvm flutter run -d macos
```

Requires the **main/master** Flutter channel for the macOS windowing path. The
core `panel` package targets stable and compiles for web.

See [`packages/panel/README.md`](packages/panel/README.md),
[`packages/panel_macos/README.md`](packages/panel_macos/README.md), and
[`MANUAL.md`](MANUAL.md) for details.
