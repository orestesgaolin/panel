// Static slide markup, rendered with Jaspr's `raw()` as direct <section>
// children of the deck. The interactive slides are real Flutter docks inserted
// as Jaspr components between these raw blocks (see app.dart).

const String heroHtml = r'''
<section data-title="Panel">
  <div class="kicker">A Flutter desktop micro-framework</div>
  <h1>Panel</h1>
  <p class="lede">Dockable, splittable, detachable panels, like an IDE, built on Flutter's experimental multi-window APIs plus a thin native AppKit layer on macOS.</p>
  <div>
    <span class="tag">drag tabs to dock &amp; split</span>
    <span class="tag">tear off into real OS windows</span>
    <span class="tag">drag back to snap in</span>
    <span class="tag">themeable · persistable · keyboard-driven</span>
  </div>
  <a class="hero-cta" href="https://github.com/your-org/panel/releases/latest/download/Panel-macos.dmg">
    <svg class="apple" viewBox="0 0 384 512" aria-hidden="true"><path fill="currentColor" d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.7 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-56.6-164.2c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26.1 2 49.9-11.4 69.5-34.3z"/></svg>
    <span class="cta-text"><strong>Download for macOS</strong><small>Apple-notarized · the example app · .dmg</small></span>
  </a>
</section>
''';

// After the intro demo: how multi-window works, popping out, and distribution.
const String blockA = r'''
<section data-title="Multi-window">
  <div class="kicker">How it works · Multi-window</div>
  <h2>Real OS windows, one engine</h2>
  <p>Flutter desktop is gaining true multi-window support (led by Canonical). One engine and one isolate drive many native windows: each window is a Flutter <strong>view</strong> rendered from the same widget tree, all sharing the same state. No second isolate, no IPC.</p>
  <p>It's experimental, on the <strong>main/master</strong> channel behind a flag. Enable it once:</p>
  <pre>fvm flutter config --enable-windowing</pre>
  <p class="muted">Background: <a href="https://ubuntu.com/blog/multiple-window-flutter-desktop" target="_blank" rel="noopener">Canonical's write-up</a> · <a href="https://github.com/flutter/flutter/issues/142845" target="_blank" rel="noopener">Flutter tracking issue #142845</a>.</p>
</section>

<section data-title="Pop out">
  <div class="kicker">How it works · Pop-out</div>
  <h2>Pop a panel into its own window</h2>
  <p>Detaching a panel creates a new top-level window from Dart, and the windowing layer renders it as another sibling view of the same tree. Because every window shares one <code>PanelManager</code>, the torn-off panel keeps working and can be dragged back to snap into the dock.</p>
  <svg class="popsvg" viewBox="0 0 480 250" role="img" aria-label="A panel popping out into its own window and snapping back into the dock">
    <!-- dock target shown while the panel is popped out -->
    <rect class="ps-slot" x="146" y="78" width="112" height="128" rx="6"/>
    <rect class="ps-snap" x="146" y="78" width="112" height="128" rx="6"/>
    <!-- main window -->
    <g class="ps-main">
      <rect class="ps-win" x="20" y="48" width="250" height="170" rx="10"/>
      <circle class="ps-dot ps-r" cx="36" cy="62" r="4"/>
      <circle class="ps-dot ps-y" cx="50" cy="62" r="4"/>
      <circle class="ps-dot ps-g" cx="64" cy="62" r="4"/>
      <line class="ps-sep" x1="20" y1="76" x2="270" y2="76"/>
      <rect class="ps-col" x="32" y="86" width="104" height="120" rx="5"/>
      <rect class="ps-acc" x="40" y="94" width="40" height="6" rx="3"/>
      <rect class="ps-line" x="40" y="112" width="80" height="5" rx="2"/>
      <rect class="ps-line" x="40" y="124" width="64" height="5" rx="2"/>
      <rect class="ps-line" x="40" y="136" width="72" height="5" rx="2"/>
    </g>
    <!-- the panel that pops out into its own window, then snaps back -->
    <g class="ps-pop">
      <rect class="ps-shadow" x="148" y="82" width="112" height="128" rx="8"/>
      <rect class="ps-popwin" x="146" y="78" width="112" height="128" rx="8"/>
      <line class="ps-sep" x1="146" y1="100" x2="258" y2="100"/>
      <rect class="ps-acc" x="156" y="86" width="44" height="6" rx="3"/>
      <rect class="ps-line" x="156" y="116" width="86" height="5" rx="2"/>
      <rect class="ps-line" x="156" y="128" width="68" height="5" rx="2"/>
      <rect class="ps-line" x="156" y="140" width="78" height="5" rx="2"/>
    </g>
  </svg>
  <pre><span class="k">runWidget</span>(<span class="t">PanelScope</span>(
  manager: manager,                       <span class="c">// shared by every window</span>
  child: <span class="t">WindowManager</span>(                   <span class="c">// hosts every window</span>
    initialWindows: [<span class="t">WindowEntry</span>(        <span class="c">// the main window</span>
      controller: <span class="t">WindowController</span>(),
      builder: (_) =&gt; <span class="t">AppShell</span>(home: <span class="t">PanelDock</span>()),
    )],
  ),
));
<span class="c">// detach → register another WindowEntry as a new view</span></pre>
</section>

<section data-title="Packages">
  <div class="kicker">Distribution</div>
  <h2>Pure Flutter + a macOS native part</h2>
  <p>The docking core is plain Flutter and runs anywhere, including this web page. The native window integration lives in a separate macOS piece; detaching is delegated to a backend, so the core carries no windowing or FFI.</p>
  <div class="grid">
    <div class="card"><h3>package:panel</h3><p>Pure Flutter core: docking, tabs, splits, persistence, shortcuts. No windowing or FFI.</p></div>
    <div class="card"><h3>package:panel_macos</h3><p>The macOS native integration: real detachable windows via Flutter windowing + an FFI bridge to AppKit.</p></div>
    <div class="card"><h3>example/</h3><p>A demo app wiring both together on macOS.</p></div>
  </div>
</section>
''';

// After the regions + drag demos: the native layer.
const String blockB = r'''
<section data-title="Native dock">
  <div class="kicker">The native layer</div>
  <h2>AppKit does what Flutter can't</h2>
  <p>On macOS a <code>dart:ffi</code> bridge connects Dart and Swift (forward calls via <strong>ffigen</strong> into Swift <code>@_cdecl</code> functions, reverse drag/drop events via <code>NativeCallable</code> pointers) for things Flutter can't do itself:</p>
  <ul>
    <li><strong>Hide the title bar:</strong> the detached window is styled <code>fullSizeContentView</code> with a transparent titlebar, hidden traffic lights and <code>isMovableByWindowBackground</code>.</li>
    <li><strong>Open where you are:</strong> it's positioned at the mouse and moved to the active Space.</li>
    <li><strong>Drag-back snapping:</strong> a 60 fps timer streams the live pointer + window frames and detects release via <code>NSEvent.pressedMouseButtons</code>.</li>
  </ul>
  <p>Symbols ship in the plugin framework and resolve from Dart via <code>DynamicLibrary.process()</code>, so the example needs no Swift in its runner.</p>
</section>
''';

// After the themes demo: persistence, keyboard, recap.
const String blockC = r'''
<section data-title="Persistence">
  <div class="kicker">Layout state</div>
  <h2>Pluggable persistence</h2>
  <p>Implement <code>PanelStorage</code> and the manager auto-saves (debounced) on every change; <code>restore()</code> reloads it on startup.</p>
  <pre><span class="k">class</span> <span class="t">MyStorage</span> <span class="k">implements</span> <span class="t">PanelStorage</span> {
  <span class="t">FutureOr</span>&lt;<span class="t">Map</span>&lt;<span class="t">String</span>, <span class="t">Object?</span>&gt;?&gt; read() =&gt; <span class="c">/* load */</span>;
  <span class="t">FutureOr</span>&lt;<span class="k">void</span>&gt; write(<span class="t">Map</span>&lt;<span class="t">String</span>, <span class="t">Object?</span>&gt; m) =&gt; <span class="c">/* save */</span>;
}

<span class="k">final</span> manager = <span class="t">PanelManager</span>(config: <span class="t">PanelDockConfig</span>(storage: <span class="t">MyStorage</span>()))
  ..registerPanel(<span class="c">/* … */</span>);
<span class="k">await</span> manager.restore();   <span class="c">// applies the saved layout</span></pre>
</section>

<section data-title="Keyboard">
  <div class="kicker">Keyboard-driven</div>
  <h2>Split &amp; merge with the keyboard</h2>
  <p>Splitting/merging is exposed as Actions &amp; Intents acting on the <strong>focused</strong> group (a group focuses on click and shows an accent border).</p>
  <p><span class="kbd">⌘ \</span> &nbsp;split the focused panel &nbsp;&nbsp; <span class="kbd">⌘ ⇧ \</span> &nbsp;merge it back</p>
  <pre><span class="t">Shortcuts</span>(
  shortcuts: defaultPanelShortcuts(),
  child: <span class="t">Actions</span>(
    actions: panelActions(manager),
    child: <span class="k">const</span> <span class="t">Focus</span>(autofocus: <span class="k">true</span>, child: <span class="t">PanelDock</span>()),
  ),
);</pre>
</section>

<section data-title="Recap">
  <div class="kicker">That's the whole thing</div>
  <h2>Flutter windows + a little Swift</h2>
  <p class="lede">Experimental multi-window Flutter gives real OS windows in one shared isolate; a thin AppKit layer supplies the borderless chrome and pointer-tracked docking.</p>
  <p>Everything else, splits, theming, persistence and shortcuts, is plain Dart, so the core compiles to web too. The live docks on this page are <code>package:panel</code> running in your browser, embedded with <code>jaspr_flutter_embed</code>.</p>
  <p class="muted">See <code>MANUAL.md</code> for the full build guide and the package READMEs for the API.</p>
</section>

<section data-title="Subscribe">
  <div class="kicker">Stay in the loop</div>
  <h2>Occasional Flutter</h2>
  <p>Notes on Flutter, native-interop, multi-window, and building things like this.</p>
  <iframe src="https://occasionalflutter.substack.com/embed?transparent=1&light=1" width="480" height="150" style="border: 1px solid #EEE;" frameborder="0" scrolling="no"></iframe>
</section>
''';
