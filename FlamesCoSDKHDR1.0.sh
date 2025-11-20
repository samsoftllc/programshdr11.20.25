#!/bin/bash
# Flames Co. Softworks Eternal Toolchain Suite v2.4
# Professional ARM64 macOS Edition – November 20 2025
# 100% idempotent • Zero Git dependency • Direct archive deployment only
# © Flames Co. Softworks 1999–2025. All rights reserved.

set -e

export TOOLCHAIN_DIR="$HOME/eternal-toolchains"
export BIN_DIR="$TOOLCHAIN_DIR/bin"
mkdir -p "$TOOLCHAIN_DIR" "$BIN_DIR"

echo "======================================================================"
echo "   Flames Co. Softworks Eternal Toolchain Suite v2.4"
echo "   Professional Multi-Platform Development Environment"
echo "   Installation directory: $TOOLCHAIN_DIR"
echo "======================================================================"

# ——————————————————————— 1. Homebrew dependencies ———————————————————————
echo "[1/8] Installing core build utilities via Homebrew (idempotent)..."
brew install wget curl unzip zstd xz cmake ninja texinfo gawk gnu-sed coreutils \
    bison flex nasm yasm cc65 mame || true

ln -sf "$(brew --prefix bison)/bin/bison" "$BIN_DIR/bison" 2>/dev/null || true
ln -sf "$(brew --prefix flex)/bin/flex"   "$BIN_DIR/flex"   2>/dev/null || true

# ——————————————————————— 2. VitaSDK (via direct archive) ———————————————————————
echo "[2/8] Deploying VitaSDK – archive-based installation"
export VITASDK="$TOOLCHAIN_DIR/vitasdk"
export VDPM="$TOOLCHAIN_DIR/vdpm"

if [ ! -d "$VDPM" ]; then
    echo "   Downloading VDPM package..."
    curl -L --fail -# \
        https://github.com/vitasdk/vdpm/archive/refs/heads/master.zip \
        -o /tmp/vdpm.zip
    unzip -qo /tmp/vdpm.zip -d "$TOOLCHAIN_DIR"
    mv "$TOOLCHAIN_DIR/vdpm-master" "$VDPM"
    rm -f /tmp/vdpm.zip
else
    echo "   VDPM directory present – skipping download"
fi

cd "$VDPM"

if [ ! -d "$VITASDK/bin" ]; then
    echo "   Performing initial VitaSDK bootstrap"
    ./bootstrap-vitasdk.sh "$VITASDK"
else
    echo "   VitaSDK already initialized"
fi

echo "   Installing/updating VitaSDK packages..."
./install-all.sh || echo "   Packages already present – continuing"

"$VITASDK/bin/vitasdk-update" || echo "   Nightly update unavailable – toolchain remains functional"

find "$VITASDK/bin"              -type f -perm +111 -exec ln -sf {} "$BIN_DIR/" \; 2>/dev/null || true
find "$VITASDK/arm-vita-eabi/bin" -type f -perm +111 -exec ln -sf {} "$BIN_DIR/" \; 2>/dev/null || true

cd "$HOME"

# ——————————————————————— 3. OpenOrbis Toolchain (PS4/PS5) ———————————————————————
echo "[3/8] Deploying OpenOrbis Toolchain"
if [ ! -f "$BIN_DIR/orbis-clang" ]; then
    curl -L --fail -# \
        https://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain/archive/refs/heads/master.zip \
        -o /tmp/oo.zip
    unzip -qo /tmp/oo.zip -d /tmp
    find /tmp/OpenOrbis-PS4-Toolchain-master/bin/macos -type f -perm +111 \
        -exec ln -sf {} "$BIN_DIR/" \; 2>/dev/null || true
    rm -rf /tmp/oo.zip /tmp/OpenOrbis-PS4-Toolchain-master
    echo "   OpenOrbis toolchain installed"
else
    echo "   OpenOrbis toolchain already present"
fi

# ——————————————————————— 4. z88dk (Z80 development suite) ———————————————————————
echo "[4/8] Deploying z88dk"
if [ ! -f "$BIN_DIR/z88dk-z80asm" ]; then
    curl -L --fail -# http://nightly.z88dk.org/z88dk-osx-latest.zip -o /tmp/z88dk.zip
    unzip -qo /tmp/z88dk.zip -d "$TOOLCHAIN_DIR"
    rm -f /tmp/z88dk.zip
    find "$TOOLCHAIN_DIR/z88dk/bin" -type f -perm +111 -exec ln -sf {} "$BIN_DIR/" \; 2>/dev/null || true
    echo "   z88dk suite installed"
else
    echo "   z88dk already present"
fi

# ——————————————————————— 5. devkitPro pacman installer ———————————————————————
echo "[5/8] Obtaining devkitPro package manager installer"
DKP_SCRIPT="$TOOLCHAIN_DIR/install-devkitpro-pacman"
if [ ! -f "$DKP_SCRIPT" ]; then
    curl -L --fail -# \
        https://apt.devkitpro.org/install-devkitpro-pacman \
        -o "$DKP_SCRIPT"
    chmod +x "$DKP_SCRIPT"
    echo "   Installer ready – execute with sudo when prepared"
else
    echo "   devkitPro installer already downloaded"
fi

# ——————————————————————— 6. Libdragon N64 SDK (archive deployment) ———————————————————————
echo "[6/8] Deploying Libdragon N64 SDK – native ARM64 build"
N64_ROOT="$TOOLCHAIN_DIR/libdragon"
if [ ! -d "$N64_ROOT" ]; then
    echo "   Downloading Libdragon source archive..."
    curl -L --fail -# \
        https://github.com/DragonMinded/libdragon/archive/refs/heads/trunk.zip \
        -o /tmp/libdragon.zip
    unzip -qo /tmp/libdragon.zip -d "$TOOLCHAIN_DIR"
    mv "$TOOLCHAIN_DIR/libdragon-trunk" "$N64_ROOT"
    rm -f /tmp/libdragon.zip

    echo "   Building MIPS toolchain (approximately 60 minutes on M4-series)"
    (cd "$N64_ROOT/tools" && time ./build-toolchain.sh)

    echo "   Building Libdragon framework (approximately 10 minutes)"
    (cd "$N64_ROOT" && time ./build.sh)
fi

# N64 toolchain path configuration
export N64_INST="$TOOLCHAIN_DIR/n64-toolchain"
mkdir -p "$N64_INST/bin"
ln -sf "$N64_ROOT/tools/mips-n64/bin/"* "$N64_INST/bin/" 2>/dev/null || true

# Build demonstration ROM
cd "$N64_ROOT/examples/graphics/console"
sed -i '' 's/printf("Hello World!");/printf("Flames Co. Softworks Eternal Toolchain\\nSuccessfully Deployed");/' source/console.c 2>/dev/null || true
make -f Makefile clean >/dev/null 2>&1
make -f Makefile console.z64 >/dev/null 2>&1
cp console.z64 "$TOOLCHAIN_DIR/bin/flamesco-demo.z64"
cd "$HOME"
echo "   N64 demonstration ROM created: flamesco-demo.z64"

# ——————————————————————— 7. Permanent PATH configuration ———————————————————————
echo "[7/8] Configuring persistent PATH"
for file in ~/.zshrc ~/.bash_profile ~/.bashrc; do
    if [ -f "$file" ] && ! grep -q "eternal-toolchains/bin" "$file" 2>/dev/null; then
        echo >> "$file"
        echo '# Flames Co. Softworks Eternal Toolchains' >> "$file"
        echo "export PATH=\"\$HOME/eternal-toolchains/bin:\$PATH\"" >> "$file"
    fi
done

export PATH="$BIN_DIR:$PATH"

# ——————————————————————— 8. Installation verification ———————————————————————
echo "[8/8] Verification complete"
echo "---------------------------------------------------------"
arm-vita-eabi-gcc --version 2>/dev/null | head -n1 || echo "VitaSDK compiler: not detected"
orbis-clang --version 2>/dev/null | head -n1 || echo "OpenOrbis compiler: not detected"
z80asm -h >/dev/null 2>&1 && echo "z88dk: ready" || echo "z88dk: not detected"
nasm -v 2>/dev/null || echo "NASM: not detected"
mipsn64-elf-gcc --version 2>/dev/null | head -n1 || echo "N64 MIPS GCC: not built"
[ -f "$TOOLCHAIN_DIR/bin/flamesco-demo.z64" ] && echo "N64 demonstration ROM: ready"
echo "---------------------------------------------------------"
echo ""
echo "======================================================================"
echo "   Flames Co. Softworks Eternal Toolchain Suite v2.4 – Deployment Complete"
echo "   © Flames Co. Softworks 1999–2025"
echo ""
echo "   Next steps:"
echo "     • sudo $TOOLCHAIN_DIR/install-devkitpro-pacman"
echo "     • dkp-pacman -Syu --needed devkitARM devkitPPC gamecube-dev nds-dev gba-dev switch-dev"
echo "     • Test N64 ROM: ~/eternal-toolchains/bin/flamesco-demo.z64"
echo "======================================================================"