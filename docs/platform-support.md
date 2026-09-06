# Platform support and validation

Assessment date: 6 September 2026. The implementation target is
[`engels74/taps`](https://github.com/engels74/homebrew-taps). The five former
single-app taps are retired. The account inventory found no additional active
Homebrew tap. Other repositories such as
[Claude Atoll](https://github.com/engels74/claude-atoll) and
[EasyHDR](https://github.com/engels74/EasyHDR) are not additional entries in this
tap; adding a different application is outside this change.

## Compatibility decisions

“Universal” below means the inspected macOS executable and bundled Mach-O
libraries contain both ARM64 and x86_64. It does not establish Intel runtime
compatibility. Linux formulae deliberately reject macOS; use the existing casks.

| App/version assessed | macOS | Linux ARM64 / x86_64 | Evidence and remaining work |
| --- | --- | --- | --- |
| FCast Sender 0.0.3 beta | Support existing ARM64 cask; retain Intel restriction | Support with native formula, GStreamer plugin and desktop session requirements | The [desktop sender](https://github.com/futo-org/fcast/tree/sender-0.0.3-beta/senders/desktop) is Rust/Slint, not the Electron receiver or terminal sender. [Upstream's Flatpak recipe](https://github.com/flathub/org.fcast.Sender/blob/master/org.fcast.Sender.yaml) documents Linux dependencies. Screen/audio capture needs real-session validation. |
| Flixor beta2.4.0 | Retain universal cask, macOS 13+ | Retain restriction | [Flixor source](https://github.com/Flixorui/flixor) contains multiple variants. `FlixorMac.app` / `com.flixor.mac` uses SwiftUI, AppKit and native media frameworks. Shipping its web variant would change the packaged application. Porting the native variant requires substantial upstream work. |
| Fred TV 1.9.1 | Support universal cask; install missing external media tools | Support native formula with Node 20, Rust/Tauri, GTK3/WebKitGTK 4.1 and media tools | [Pinned source/build configuration](https://github.com/Fredolx/open-tv/tree/v1.9.1) supports Linux. The formula builds the Angular frontend into the Tauri executable and wraps `mpv`, `ffmpeg`, `yt-dlp` paths. Node 20 matches Angular 17; an upstream frontend toolchain upgrade is needed before removing that build dependency. |
| Paicord 2026-08-05-473c780 | Support universal cask, macOS 14+ | Retain restriction | [Source](https://github.com/llsc12/Paicord) and build workflow package a SwiftUI macOS app; Linux support is unfinished upstream. The resolver now binds a successful build run to its immutable release tag, exact asset and source commit. |
| qView 7.1 | Support universal cask, macOS 12+ | Support native Qt 6 formula | [Release source](https://github.com/jurplel/qView/tree/7.1) uses qmake (current development uses a different build system). Reuse core Qt base, SVG, image-format and Wayland packages. Validate real image decoding, not just `--version`. |

### Homebrew requirements and package choice

Use the [official Linux installation requirements](https://docs.brew.sh/Homebrew-on-Linux)
and [support tiers](https://docs.brew.sh/Support-Tiers), rather than old Linuxbrew
guidance. The intended bottle configuration is Ubuntu 24.04+ with glibc 2.39+,
ARM64 or x86_64, at `/home/linuxbrew/.linuxbrew`. Intel macOS is Tier 3; a cask's
app minimum OS does not guarantee a supported Homebrew installation.

The original premise that casks are categorically macOS-only is no longer true
in current Homebrew: its [cask DSL](https://docs.brew.sh/Cask-Cookbook) includes
Linux/AppImage support. These five existing definitions remain macOS app-bundle
casks. Native Linux formulae are appropriate here because the selected source
variants build against Homebrew libraries, have normal launch commands and
desktop files, and can receive independently tested bottles for both architectures.
No AppImage extraction, FUSE requirement or system-library guessing is needed.

Core dependencies are reused. The only additional support recipe is
`pipewire-gstreamer`: core [PipeWire's recipe](https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/p/pipewire.rb)
disables its GStreamer plugin. This tap compiles only that plugin against installed
PipeWire/GStreamer. It does not install or manage a second desktop audio server.

## What “working” means

A supported release must install from a clean formula/bottle, resolve its linked
libraries, expose launch commands and desktop files, and render an actual window
under both X11 and Wayland. Reinstalling from the produced bottles must pass the
same checks. Removal must remove packaged files while preserving user data.

Feature acceptance adds the following manual checks:

| App | Desktop acceptance beyond CI |
| --- | --- |
| qView | Open PNG, SVG and animated GIF; navigate images, zoom, fullscreen; verify file association and desktop-menu launch |
| Fred TV | Import a permitted M3U source, play a stream with sound, seek, record with ffmpeg, exercise a supported yt-dlp URL, quit and reopen without losing the source |
| FCast Sender | Discover and connect to a real receiver; cast a permitted file/URL; screen and audio capture on X11; Wayland ScreenCast portal permission, cancellation and reconnect |
| Flixor | Launch the native app, authenticate to a permitted Plex server, play media with sound, quit/reopen |
| Paicord | Launch, then authenticated operations only with an explicitly provided test account; no credentials are needed for packaging checks |

### Evidence collected

- All five current tap DMGs were downloaded and checked against their declared
  SHA256. `scripts/inspect-macos.py` verified actual bundle identifiers and every
  included Mach-O architecture. FCast's main executable is ARM64 only; the other
  four bundles are universal. No cask version or checksum was manually changed.
- On `cvps`, Ubuntu 26.04.1 x86_64, Homebrew 6.0.22: qView, Fred TV and FCast Sender built from
  source and passed Xvfb/X11 and headless Weston/Wayland launch tests in disposable
  homes. qView rendered PNG and SVG fixtures (checked pixels), and opened a GIF.
  Fred TV rendered its initial source-setup screen. PipeWire source/sink plugins
  loaded successfully in Homebrew GStreamer.
- FCast Sender rendered its receiver-discovery interface under both display
  backends. Tests loaded PipeWire/X11/PulseAudio capture elements, VP8, Opus and
  WebRTC, and ran a synthetic VP8/RTP encoding pipeline. No real receiver was used.
- Source archives were generated for all four formulae. The archived Fred TV and
  FCast Cargo dependency graphs resolved offline using their vendored sources.
- Fred TV's formula test generated a short synthetic video with ffmpeg, decoded
  it with mpv's null outputs, and invoked yt-dlp. This verifies the external tools
  without claiming playback through the app or a real audio device.
- A separate manual test used the bottled Fred TV UI to import an M3U URL served
  on localhost and play a generated video. Visible video frames rendered in mpv
  under Xvfb with test-profile parameters `--vo=x11 --hwdec=no --ao=null`. Default
  GPU output failed on this displayless host. This proves the import/player flow
  with software video, not audible playback or acceleration. The profile and
  local server were disposable; no account or third-party stream was used.
- The host is bare metal without a connected display or usable GPU render node.
  Virtual-display tests use software rendering. They do not establish GPU,
  audible playback, receiver discovery or portal capture behavior.
- Native ARM64/x86_64 GitHub Actions builds provide the release gates. Consult
  [Linux formula workflow runs](https://github.com/engels74/homebrew-taps/actions/workflows/formulae.yml)
  and their GUI/log artifacts for the exact commit and results.
- No Intel Mac runtime, authenticated Flixor/Paicord session, live IPTV source or
  physical FCast receiver was available. Those feature checks remain manual.

Run the repeatable checks with:

```bash
python3 -m unittest discover -s scripts/tests -v
actionlint
# On Linux with the formulae installed and host xvfb/xauth/weston/dbus tools:
bash scripts/test-linux-gui.sh
# On macOS, inspect a downloaded artifact without installing or launching it:
python3 scripts/inspect-macos.py qview /path/to/qView.dmg
```

The GUI harness uses private HOME/XDG directories and isolated D-Bus/display
sessions. Evidence is written to `/tmp/tap-gui-results`. X11 checks window titles
and image pixels; Wayland checks that a live client submits surface buffers.
A static GIF fixture proves loading, not animation timing. Manual upgrade checks
should additionally start with real prior-version settings and verify persistence.

## Release and license controls

Linux publication requires all four formulae on both architectures, successful
formula/linkage/GUI checks, local bottle reinstall, matching versions/checksums,
and a corresponding source archive for each formula. The source archive contains
the exact pinned source, Cargo-vendored dependencies, Fred TV's npm packages,
license files and tap build recipes. Bottle JSON records build provenance and
separately installed Homebrew dependencies; those dependencies are not repackaged
inside these application archives. Binaries and sources are retained together.
Same-version packaging/ABI fixes require a formula `revision` bump to trigger
upgrades; a fresh bottle checksum alone is insufficient.

qView (GPL-3.0), Fred TV (GPL-2.0), Paicord (GPL-3.0), and the MIT-licensed
PipeWire plugin permit redistribution subject to their notices and source
obligations. FCast's top-level code is MIT, while the Linux desktop distribution
uses [GPL-3.0](https://github.com/futo-org/fcast/blob/master/senders/extra/LICENSE-GPL)
with Slint's GPL option; treating the combined binary as MIT-only is incorrect.
See the README license table and the dependency licenses preserved in the sources.

[Flixor's custom license](https://github.com/Flixorui/flixor/blob/main/LICENSE.md)
adds noncommercial and public-source conditions to AGPL terms. Retain upstream
binaries and license notices, make the matching source accessible, and obtain
upstream permission before commercial use/distribution. This change does not
introduce a Flixor Linux build or assume that a standard AGPL grant applies.

VirusTotal reports are optional and informational. The release pipeline verifies
bytes and completeness independently of whether a scan key is configured.

## Follow-up platform work

1. Complete the manual media/audio/portal matrix on ordinary Linux desktops before
   claiming full feature parity. Keep Xvfb and Weston: each exercises a different
   backend, and neither requires a connected monitor.
2. For Intel FCast, upstream's [macOS packaging task](https://github.com/futo-org/fcast/blob/sender-0.0.3-beta/xtask/src/sender.rs)
   builds the host target, bundles GStreamer and names the result `macos-aarch64`.
   SDK x86_64 jobs are not proof of desktop Sender support. Build the actual
   `desktop-sender` on Intel with compatible GStreamer, inspect every dylib,
   then test launch, receiver playback and capture. Signing/notarization and an
   architecture-specific asset/resolver contract are prerequisites for expanding
   the cask. This is feasible work to investigate, not verified Intel support.
3. Track upstream native Linux progress for Paicord and Flixor. Do not silently
   substitute a web client under an existing native-app token.
