# This fork

Mirror of [`noctalia-dev/noctalia-qs`](https://github.com/noctalia-dev/noctalia-qs)
at commit [`606aded`](https://github.com/noctalia-dev/noctalia-qs/commit/606adedbfea92caba306730edd0f6adba4acf310)
(`chore(flake): update flake.lock`, 2026-07-12), plus a build script.

**There are no source changes in this fork.** It exists to pin the exact tree
that is built and run locally, and to have somewhere to hang patches if the
upstream fork ever needs one.

## Why this tree and not the packaged build

The Fedora Terra package `noctalia-qs-0.0.12-7` is built from revision
`fb0cc1557d8321fb2e3f34e94beddefe56211e04`, which is on a diverged line that
predates commit [`ecdc0b1`](https://github.com/noctalia-dev/noctalia-qs/commit/ecdc0b1def603378d21488ca7f7def09f3544c99)
*"fix(pipewire): avoid crash on device disconnect in default tracker"*
(2026-04-16).

That commit changes the four `PwDefaultTracker` node pointers from raw
`PwNode*` to `QPointer<PwNode>`:

```diff
-	PwNode* mDefaultConfiguredSink = nullptr;
+	QPointer<PwNode> mDefaultConfiguredSink = nullptr;
```

`QPointer` nulls itself when the `QObject` is destroyed, so this guard in
`src/services/pipewire/defaults.cpp` skips instead of dereferencing freed
memory:

```cpp
if (this->mDefaultConfiguredSink != nullptr) {
    QObject::disconnect(this->mDefaultConfiguredSink, nullptr, this, nullptr);
}
```

### What that fixes

With raw pointers the tracker could hold a node that PipeWire had already
destroyed — for example when a Bluetooth headset's A2DP transport failed while
its node was the default sink. The next default-node update then called
`QObject::disconnect()` on the freed object:

```
#0  QObject::disconnect(QObject const*, char const*, QObject const*, char const*)
#1  qs::service::pipewire::PwDefaultTracker::setDefaultConfiguredSink(PwNode*)
#2  qs::service::pipewire::PwConnection::onFatalError()
```

SIGSEGV, and the shell does not come back on its own. With `QPointer` the
pointer is already null by then, and the guard is a no-op.

Upstream Quickshell fixed the same class of bug independently in
[`13fe9b0d98`](https://github.com/quickshell-mirror/quickshell/commit/13fe9b0d98028361344b7422b1ebe238d1d29d02)
(quickshell v0.3.0), by using targeted disconnects instead of blanket ones.
This fork has the `QPointer` approach, not that one.

## Building

```sh
./scripts/build-local.sh
```

Produces a staged tree at `$HOME/.local/qs` (override with `STAGE=...`) and a
`qs-patched` wrapper that sets `QML_IMPORT_PATH`, since Qt does not search the
staging prefix for QML modules.

Build dependencies on Fedora 45 (Qt 6.11.2):

```sh
sudo dnf install meson gcc-c++ ninja-build \
  qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtshadertools-devel \
  qt6-qtwayland-devel qt6-qtbase-private-devel \
  wayland-devel wayland-protocols-devel \
  libdrm-devel mesa-libgbm-devel vulkan-headers \
  libxkbcommon-devel glib2-devel \
  pipewire-devel jemalloc-devel cli11-devel \
  polkit-devel pam-devel
```

`qt6-qtbase-private-devel` is easy to miss — it provides `Qt6CorePrivate` and
`Qt6GuiPrivate`, which both `Qt6QuickPrivate` and `Qt6WaylandClientPrivate`
require. It is not mentioned in `BUILD.md`.

## Running

```sh
qs-patched -c noctalia-shell
```

## Upstream

Everything below this file is upstream's. See `README.md`, `BUILD.md` and
`HACKING.md`. The fork is LGPL-3.0-only / GPL-3.0-only; see `LICENSE` and
`LICENSE-GPL`.
