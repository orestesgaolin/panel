// Static slide markup, rendered with Jaspr's `raw()` as direct <section>
// children of the deck. The interactive slides are real Flutter docks inserted
// as Jaspr components between these raw blocks (see app.dart).

const String heroHtml = r'''
<section data-title="Panel">
  <div class="kicker">Dockable panels for Flutter desktop</div>
  <h1>Panel</h1>
  <p class="lede">Build an IDE-style workspace in Flutter. Dock tabs, split the layout, or pull a panel into its own macOS window.</p>
  <div>
    <span class="tag">drag tabs to dock &amp; split</span>
    <span class="tag">tear off into real OS windows</span>
    <span class="tag">drag back to snap in</span>
    <span class="tag">themeable · persistable · keyboard-driven</span>
  </div>
</section>
''';

// After the intro demo: how multi-window works, popping out, and distribution.
const String blockA = r'''
<section data-title="Multi-window">
  <div class="kicker">How it works · Flutter windowing</div>
  <h2>A panel can become a real window</h2>
  <p>Flutter's new desktop windowing API lets one app draw into several native windows. They remain part of the same widget tree, so a detached panel keeps the same state as the dock it came from.</p>
  <p>The API is still experimental and available on Flutter's <strong>main/master</strong> channel behind a flag. Enable it once:</p>
  <pre>fvm flutter config --enable-windowing</pre>
  <p class="muted">Start with Flutter's official article: <a href="https://flutter.dev/blog/desktop-windowing-apis" target="_blank" rel="noopener">Introducing the Desktop Windowing API</a>. For more detail, see <a href="https://ubuntu.com/blog/multiple-window-flutter-desktop" target="_blank" rel="noopener">Canonical's write-up</a> or <a href="https://github.com/flutter/flutter/issues/142845" target="_blank" rel="noopener">the tracking issue</a>.</p>
</section>

<section data-title="Pop out">
  <div class="kicker">How it works · Pop-out</div>
  <h2>Pop a panel into its own window</h2>
  <p>Pull a tab away and Panel opens it in a new macOS window. It keeps working with the same app state, and you can drag it back over the main window to dock it again.</p>
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
  <div class="kicker">Use only what you need</div>
  <h2>Flutter for the dock, macOS for the windows</h2>
  <p>The dock itself is regular Flutter and even runs in this web page. The optional macOS package adds detachable windows without tying the core package to one platform.</p>
  <div class="grid">
    <div class="card"><h3>package:panel</h3><p>Tabs, docking, splits, saved layouts, themes, and keyboard shortcuts.</p></div>
    <div class="card"><h3>package:panel_macos</h3><p>Turns detached panels into native macOS windows and lets them snap back.</p></div>
    <div class="card"><h3>example/</h3><p>A complete macOS app showing the two packages together.</p></div>
  </div>
</section>
''';

// After the regions + drag demos: the native layer.
const String blockB = r'''
<section data-title="Native dock">
  <div class="kicker">A small macOS helper</div>
  <h2>Flutter creates the window; AppKit finishes it</h2>
  <p>Flutter now handles the windows themselves. A small Swift helper fills the few gaps needed for an IDE-style detachable panel:</p>
  <ul>
    <li><strong>Custom appearance:</strong> remove the title bar and window buttons.</li>
    <li><strong>Sensible placement:</strong> open near the pointer on the active desktop.</li>
    <li><strong>Docking:</strong> follow the window while it is dragged and snap it back on release.</li>
  </ul>
  <p>The helper ships inside <code>package:panel_macos</code>, so apps using Panel do not need to copy its Swift code.</p>
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
  <h2>A Flutter dock that feels at home on desktop</h2>
  <p class="lede">Use Flutter's windowing API for real windows and a small macOS helper for the final desktop details.</p>
  <p>Splits, themes, saved layouts, and shortcuts stay in Dart. The live examples on this page are the same <code>package:panel</code> widgets running in your browser.</p>
  <p class="muted">See <code>MANUAL.md</code> for the full build guide and the package READMEs for the API.</p>
</section>

<section data-title="Subscribe">
  <div class="kicker">Stay in the loop</div>
  <h2>Occasional Flutter</h2>
  <p>Practical notes on Flutter desktop, native platform work, and projects like this one.</p>
  <iframe src="https://occasionalflutter.substack.com/embed?transparent=1&light=1" width="480" height="150" style="border: 1px solid #EEE;" frameborder="0" scrolling="no"></iframe>
</section>
''';
