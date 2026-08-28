// Keyboard support for splitting/merging panels via the Actions & Intents
// framework. These act on the *focused* group (set when a group is clicked),
// so the shortcut does the right thing wherever the user is working.
//
// Wire them up by wrapping your workspace:
// ```dart
// Shortcuts(
//   shortcuts: defaultPanelShortcuts(),
//   child: Actions(
//     actions: panelActions(manager),
//     child: const Focus(autofocus: true, child: PanelDock()),
//   ),
// );
// ```

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'panel_manager.dart';

/// Splits the focused group's active panel into a new adjacent group.
class SplitPanelIntent extends Intent {
  const SplitPanelIntent();
}

/// Merges the focused group into its neighbor (collapses a split).
class MergePanelIntent extends Intent {
  const MergePanelIntent();
}

/// Default key bindings: ⌘\ to split, ⌘⇧\ to merge (Ctrl on non-Apple).
Map<ShortcutActivator, Intent> defaultPanelShortcuts() {
  final bool apple = <TargetPlatform>{
    TargetPlatform.macOS,
    TargetPlatform.iOS,
  }.contains(defaultTargetPlatform);
  return <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.backslash, meta: apple, control: !apple):
        const SplitPanelIntent(),
    SingleActivator(
          LogicalKeyboardKey.backslash,
          meta: apple,
          control: !apple,
          shift: true,
        ):
        const MergePanelIntent(),
  };
}

/// Actions that route the panel intents to [manager].
Map<Type, Action<Intent>> panelActions(PanelManager manager) {
  return <Type, Action<Intent>>{
    SplitPanelIntent: CallbackAction<SplitPanelIntent>(
      onInvoke: (_) {
        manager.splitFocused();
        return null;
      },
    ),
    MergePanelIntent: CallbackAction<MergePanelIntent>(
      onInvoke: (_) {
        manager.mergeFocused();
        return null;
      },
    ),
  };
}
