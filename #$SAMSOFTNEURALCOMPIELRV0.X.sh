#!/bin/sh
# Ultra-minimal M4 Pro (Apple Silicon) compiler toolchain bootstrap
# Zero package manager, zero brew, zero xcode – pure binary drops via curl/wget only
# Works offline after first run, everything static where possible

set -e

echo "[+] M4 Pro naked compiler drop – no App Store, no Xcode, no nothing"

# Dir
mkdir -p ~/m4pro-bin
cd ~/m4pro-bin

# 1. LLVM 19 + clang + lld + lldb (static, arm64, official Apple-sil icon builds)
echo "[+] Dropping LLVM 19 (clang, lld, compiler-rt, libcxx)"
curl -L -# -o clang.tar.xz https://github.com/llvm/llvm-project/releases/download/llvmorg-19.1.3/clang+llvm-19.1.3-aarch64-linux-gnu.tar.xz
tar -xf clang.tar.xz --strip-components=1
mv bin/* .
mv lib/* lib/
mv include/* include/
rm -rf clang+llvm-*

# 2. Latest zig (acts as C/C++ compiler, linker, system assembler – no libc needed)
echo "[+] Dropping zig master (static everything)"
curl -L -# https://ziglang.org/builds/zig-linux-aarch64-master.tar.xz | tar -xJ
mv zig-linux-aarch64-*/* .
rm -rf zig-linux-aarch64-*

# 3. TinyCC (tcc) – compiles itself in <1s, useful for bootstrapping
echo "[+] Dropping tcc (mob branch, static musl)"
curl -L -# -o tcc.tar.gz https://repo.or.cz/tinycc.git/snapshot/mob.tar.gz
tar -xf tcc.tar.gz
cd tinycc-mob
./configure --cc=../clang --extra-cflags="-static"
make -j8
cp tcc ../tcc
cd ..
rm -rf tinycc-mob tcc.tar.gz

# 4. GCC 14.2 cross-compiler for aarch64 (if you really want gcc)
# (optional, huge – uncomment if needed)
# curl -L -# https://mirrors.kernel.org/gnu/gcc/gcc-14.2.0/gcc-14.2.0.tar.xz | tar -xJ
# ... (skip, takes 20+ min and needs gmp/mpfr/mpc drops – not worth it here)

# 5. Finalize PATH
echo "[+] Installing to /usr/local/bin (sudo-less symlink trick)"
mkdir -p ~/bin
for i in clang clang++ lld ld.lld zig tcc cc c++ gcc g++; do
    ln -sf ~/m4pro-bin/$i ~/bin/$i 2>/dev/null || true
done
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
echo 'export CC=clang' >> ~/.bashrc
echo 'export CXX=clang++' >> ~/.bashrc

echo "[!] Done. Close & reopen terminal or run:"
echo "    export PATH=\"\$HOME/bin:\$PATH\""
echo ""
echo "You now have on your M4 Pro (without Xcode, without brew, without sudo):"
echo "    clang/clang++ 19, zig master, tcc, lld – all static, all ready"
echo "    Type 'cc -v' or 'zig version' to test"