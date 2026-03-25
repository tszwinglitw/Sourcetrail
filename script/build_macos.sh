#!/bin/bash
#
# Build Sourcetrail on macOS using Homebrew system packages.
#
# Usage:
#   ./script/build_macos.sh                  # release build (default)
#   ./script/build_macos.sh debug            # debug build
#   ./script/build_macos.sh release bundle   # release build + .app bundle
#   ./script/build_macos.sh clean            # remove build directory
#
# Prerequisites (installed automatically if missing):
#   brew install llvm@18 qt@6 boost icu4c sqlite tinyxml2 catch2 googletest maven

set -euo pipefail

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

abort()   { echo -e "${RED}Error:${RESET} $1"; exit 1; }
info()    { echo -e "${YELLOW}>>>${RESET} $1"; }
success() { echo -e "${GREEN}>>>${RESET} $1"; }

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BUILD_TYPE="${1:-release}"
ACTION="${2:-}"

case "$BUILD_TYPE" in
    release|r)  BUILD_TYPE="release"; PRESET="system-macos-release" ;;
    debug|d)    BUILD_TYPE="debug";   PRESET="system-macos-debug" ;;
    relwithdebinfo|rwdi) BUILD_TYPE="relwithdebinfo"; PRESET="system-macos-relwithdebinfo" ;;
    clean)
        info "Removing macOS build directories"
        rm -rf "$REPO_ROOT/../build/system-macos-"*
        success "Clean complete"
        exit 0
        ;;
    *)
        echo "Usage: $0 [release|debug|relwithdebinfo|clean] [bundle]"
        exit 1
        ;;
esac

BUILD_DIR="$REPO_ROOT/../build/$PRESET"

# ---------------------------------------------------------------------------
# Check platform
# ---------------------------------------------------------------------------

[[ "$(uname)" == "Darwin" ]] || abort "This script is for macOS only."

# ---------------------------------------------------------------------------
# Check / install Homebrew dependencies
# ---------------------------------------------------------------------------

BREW_DEPS=(llvm@18 qt@6 boost icu4c sqlite tinyxml2 catch2 googletest maven)

info "Checking Homebrew dependencies"
MISSING=()
for dep in "${BREW_DEPS[@]}"; do
    # Normalize: brew list uses the base name for some packages
    if ! brew list "$dep" &>/dev/null; then
        MISSING+=("$dep")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    info "Installing missing packages: ${MISSING[*]}"
    brew install "${MISSING[@]}"
fi

# Also need openjdk@21 for Java indexer
if ! brew list openjdk@21 &>/dev/null; then
    info "Installing openjdk@21"
    brew install openjdk@21
fi

# Also need ninja
if ! command -v ninja &>/dev/null; then
    info "Installing ninja"
    brew install ninja
fi

success "All dependencies installed"

# ---------------------------------------------------------------------------
# Resolve Homebrew paths
# ---------------------------------------------------------------------------

LLVM_PREFIX="$(brew --prefix llvm@18)"
QT_PREFIX="$(brew --prefix qt@6 2>/dev/null || brew --prefix qt)"
BOOST_PREFIX="$(brew --prefix boost)"
ICU_PREFIX="$(brew --prefix icu4c 2>/dev/null || brew --prefix icu4c@78)"
SQLITE_PREFIX="$(brew --prefix sqlite)"

CMAKE_PREFIX_PATH="${LLVM_PREFIX};${QT_PREFIX};${BOOST_PREFIX};${ICU_PREFIX};${SQLITE_PREFIX}"

# Java / JNI
JAVA_HOME_DIR="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
[[ -d "$JAVA_HOME_DIR" ]] || abort "OpenJDK 21 not found at $JAVA_HOME_DIR"

# ---------------------------------------------------------------------------
# Configure
# ---------------------------------------------------------------------------

cd "$REPO_ROOT"

if [[ ! -f "$BUILD_DIR/CMakeCache.txt" ]]; then
    info "Configuring ($PRESET)"
    export JAVA_HOME="$JAVA_HOME_DIR"
    cmake --preset "$PRESET" \
        -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH" \
        -DJAVA_INCLUDE_PATH="$JAVA_HOME_DIR/include" \
        -DJAVA_INCLUDE_PATH2="$JAVA_HOME_DIR/include/darwin" \
        -DJAVA_AWT_LIBRARY="$JAVA_HOME_DIR/lib/libjawt.dylib" \
        -DJAVA_JVM_LIBRARY="$JAVA_HOME_DIR/lib/server/libjvm.dylib" \
        -DBUILD_UNIT_TESTS_PACKAGE=OFF
else
    info "Build directory exists, skipping configure (delete $BUILD_DIR to reconfigure)"
fi

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

info "Building ($BUILD_TYPE)"
cmake --build "$BUILD_DIR"

success "Build complete: $BUILD_DIR/app/Sourcetrail"

# ---------------------------------------------------------------------------
# Optional: bundle
# ---------------------------------------------------------------------------

if [[ "$ACTION" == "bundle" ]]; then
    BUNDLE_SCRIPT="$REPO_ROOT/setup/macOS/bundle_macos.sh"
    if [[ -x "$BUNDLE_SCRIPT" ]]; then
        echo ""
        "$BUNDLE_SCRIPT" "$BUILD_DIR"
    else
        abort "Bundle script not found at $BUNDLE_SCRIPT"
    fi
fi
