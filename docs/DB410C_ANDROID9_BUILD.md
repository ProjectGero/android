# Verified DB410c Android 9 build guide

This guide documents the successful ProjectGero Android 9 `db410c-userdebug` build. It validates source and build production, not physical-board flashing or boot.

## Host requirements

Use a Linux x86_64 host with `bc`, `m4`, `zip`, `wget`, `build-essential`, zlib development headers, libffi development headers, libbz2 development headers, readline development headers, sqlite development headers, and the legacy `libtinfo.so.5` and `libncurses.so.5` libraries. Do not create `.so.6` to `.so.5` symlinks.

The validated host used a dedicated Python 2.7.18 with working zlib, Mako 1.1.4, and MarkupSafe 1.1.1. This is host setup, not a ProjectGero source modification:

```sh
export PATH="$HOME/aosp-python2/bin:$PATH"
export LC_ALL=C
export LANG=C
hash -r
python --version
python -c 'import zlib; print("zlib OK:", zlib.ZLIB_VERSION)'
```

## Clone and LFS

Install Git LFS before checkout and use the first-level-only model:

```sh
git lfs install
git clone --depth 1 https://github.com/ProjectGero/android.git
cd android
git -c submodule.recurse=false submodule update --init --depth 1 --jobs 8
```

This initializes the 670 ProjectGero first-level components. Do not use `git clone --recurse-submodules`: component-owned nested upstream submodules are intentionally not initialized. Git LFS must materialize selected payloads; affected paths include `device/google/wahoo-kernel`, `tools/dexter`, `prebuilts/clang/host/linux-x86`, `tools/external/gradle`, `prebuilts/jdk/jdk9`, `prebuilts/misc`, and `prebuilts/tools`.

## Modern-host Flex 2.5.39 compatibility

The tracked historical `prebuilts/misc/linux-x86/flex/flex-2.5.39` may start and pass simple lexer tests, yet crash in the real build while generating `external/mesa3d/src/mesa/program/program_lexer.l`:

```text
flex-2.5.39: loadlocale.c:130: _nl_intern_locale_data assertion failed
```

The verified workaround is to rebuild Flex 2.5.39 on the current host and use it as a local build-time override. The historical source compatibility correction in `scanflags.c` is:

```c
/* historical form */
lerrsf_fatal(_("Unable to allocate %ld of stack"), (long)sizeof(scanflags_t));
/* validated compatibility form */
lerrif(_("Unable to allocate %d of stack"), (int)sizeof(scanflags_t));
```

This is a source/build compatibility correction; do not attribute the glibc locale crash to that line alone. The runtime remedy is a Flex executable rebuilt for the current host. After rebuilding, validate both inputs before use:

```sh
<rebuilt-flex> -o /tmp/program-lex.yy.c external/mesa3d/src/mesa/program/program_lexer.l
<rebuilt-flex> --nounistd -o /tmp/glsl-lexer.cpp external/mesa3d/src/compiler/glsl/glsl_lexer.ll
```

Android invokes the fixed path `prebuilts/misc/linux-x86/flex/flex-2.5.39`. For the validated build, the rebuilt executable replaced that path locally. This is a `BUILD_TOOL_RUNTIME_OVERRIDE`, not ProjectGero history; do not commit the rebuilt ELF. Confirm the only intentional change with:

```sh
git status --short prebuilts/misc
```

## DB410c environment

From the ProjectGero root:

```sh
export PATH="$HOME/aosp-python2/bin:$PATH"
export LC_ALL=C
export LANG=C
hash -r
source build/envsetup.sh
lunch db410c-userdebug
export PATH="$HOME/aosp-python2/bin:$PATH"
hash -r
```

Assert PATH again after `lunch` so build tools select the intended Python. Expected variables are `PLATFORM_VERSION=9`, `TARGET_PRODUCT=db410c`, `TARGET_BUILD_VARIANT=userdebug`, `TARGET_ARCH=arm`, and `TARGET_ARCH_VARIANT=armv7-a-neon`.

Envsetup generates ignored local directories under `device/linaro/generic/`: `db410c`, `linaro_arm`, `linaro_arm64`, `linaro_arm64_only`, and `linaro_x86_64`. Do not commit them. ProjectGero already contains the persistent `PRODUCT_NAME` compatibility fix in `vendorsetup.sh`.

## Kernel

From the ProjectGero root, build the ARM64 qcomlt-4.14 kernel:

```sh
export PATH="$HOME/aosp-python2/bin:$PATH"
cd db410c-kernel
export ARCH=arm64
export CROSS_COMPILE="$(cd .. && pwd)/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-"
make O=out-db410c qcom_defconfig
grep -E 'CONFIG_ARM64=y|CONFIG_ARCH_QCOM=y' out-db410c/.config
make O=out-db410c HOSTCFLAGS="-Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89 -fcommon" -j"$(nproc)" Image.gz dtbs
```

Expected outputs are `out-db410c/arch/arm64/boot/Image.gz` and `out-db410c/arch/arm64/boot/dts/qcom/apq8016-sbc.dtb`. Create the local Android input from the root:

```sh
cat db410c-kernel/out-db410c/arch/arm64/boot/Image.gz db410c-kernel/out-db410c/arch/arm64/boot/dts/qcom/apq8016-sbc.dtb > device/linaro/generic-kernels/db410c-qcomlt-4.14.gz-dtb
```

This kernel output and combined artifact are generated local state; do not commit them.

## Full Android build

```sh
cd <ProjectGero root>
export PATH="$HOME/aosp-python2/bin:$PATH"
export LC_ALL=C
export LANG=C
source build/envsetup.sh
lunch db410c-userdebug
export PATH="$HOME/aosp-python2/bin:$PATH"
hash -r
python --version
python -c 'import zlib; print("zlib OK:", zlib.ZLIB_VERSION)'
make -j"$(nproc)"
```

The successful validation used `make -j12`; select parallelism appropriate to the host. Principal outputs are under `out/target/product/db410c/`: `boot.img`, `recovery.img`, `system.img`, `userdata.img`, and `cache.img`. Do not expect binary-identical hashes across different hosts.

## Incremental policy and troubleshooting

If a build fails, preserve `out/`, fix the first causal error, then rerun `make`. Ninja reuses completed intermediates; this bring-up succeeded by incremental continuation. Do not automatically run `make clean`, `make clobber`, or `rm -rf out`.

For the Mesa locale assertion, verify the effective Flex path, rebuild Flex 2.5.39 for the host, validate `program_lexer.l` and the GLSL lexer, then resume incrementally.

Warnings observed as non-fatal in this validation included invalid freedreno/virgl GPU drivers, unspecified `BOARD_SEPOLICY_VERS`, root `init.rc` command override, LLVM threads disabled, and AAPT2 resource warnings. They are not universally safe in every context.

## Local-state and capacity notes

Expected local state includes `out/`, `db410c-kernel/out-db410c/`, generated `device/linaro/generic` products, `device/linaro/generic-kernels/db410c-qcomlt-4.14.gz-dtb`, and the local Flex override. Do not accidentally commit them.

Measured guidance: shallow source is about 34.5 GB, kernel output about 2.3 GB, and completed Android `out/` about 64.5 GB. These are observations, not minima; retain significant headroom. Full-history recursive clones can require hundreds of GB.

## Hardware deployment

Build validation is complete. Flashing and physical DragonBoard boot validation are a separate, not-yet-validated step; this guide intentionally provides no deployment procedure.
