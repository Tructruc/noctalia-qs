#!/usr/bin/env bash
# Build this tree and stage it under $STAGE (default ~/.local/qs).
#
# Qt does not search a non-system prefix for QML modules, so the install is
# paired with a `qs-patched` wrapper that exports QML_IMPORT_PATH. The binary
# itself is unmodified.
#
# Usage:
#   ./scripts/build-local.sh            configure + build + stage
#   ./scripts/build-local.sh --clean    wipe build/ first
#
# Env:
#   STAGE   install prefix (default: $HOME/.local/qs)
#   JOBS    parallel compile jobs (default: nproc)

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$SRC/build"
STAGE="${STAGE:-$HOME/.local/qs}"
JOBS="${JOBS:-$(nproc)}"

if [ "${1:-}" = "--clean" ]; then
    echo "== wiping $BUILD =="
    rm -rf "$BUILD"
fi

echo "== source =="
echo "   $SRC"
echo "   $(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo '(not a git tree)')  $(git -C "$SRC" log -1 --format=%s 2>/dev/null || true)"
echo "   stage: $STAGE"
echo

# The reason this fork exists. If the fix is missing, the build would
# reproduce the pipewire use-after-free this fork is meant to avoid.
if ! grep -q "QPointer<PwNode> mDefaultConfiguredSink" "$SRC/src/services/pipewire/defaults.hpp"; then
    echo "error: QPointer fix (ecdc0b1) is not present in this tree." >&2
    echo "       Building it would reproduce the original crash." >&2
    exit 1
fi
echo "== pipewire QPointer fix present =="
echo

echo "== configure =="
cmake -GNinja -B "$BUILD" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX="$STAGE" \
    -DINSTALL_QML_PREFIX="lib64/qt6/qml" \
    -DBUILD_TESTING=OFF \
    -DCRASH_HANDLER=OFF \
    "$SRC"

echo
echo "== build ($JOBS jobs) =="
cmake --build "$BUILD" --parallel "$JOBS"

echo
echo "== stage into $STAGE =="
rm -rf "$STAGE"
cmake --install "$BUILD"

echo
echo "== wrapper =="
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/qs-patched" <<WRAP
#!/bin/sh
# noctalia-qs built from this fork. Qt does not search the staging prefix for
# QML modules, so add it to the import path.
QS_ROOT="\${QS_ROOT:-$STAGE}"
if [ -d "\$QS_ROOT/lib64/qt6/qml/Quickshell" ]; then
    export QML_IMPORT_PATH="\$QS_ROOT/lib64/qt6/qml\${QML_IMPORT_PATH:+:\$QML_IMPORT_PATH}"
fi
exec "\$QS_ROOT/bin/quickshell" "\$@"
WRAP
chmod +x "$HOME/.local/bin/qs-patched"

echo
echo "== done =="
"$HOME/.local/bin/qs-patched" --version 2>&1 | head -1 || true
echo
echo "run:  $HOME/.local/bin/qs-patched -c noctalia-shell"
