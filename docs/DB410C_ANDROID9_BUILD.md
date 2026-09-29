# Verified DB410c Android 9 build guide

This guide documents the successful ProjectGero Android 9 `db410c-userdebug` build. It validates source and build production, not physical-board flashing or boot.

## Host bootstrap

The setup script supports x86_64 Debian and Ubuntu hosts. **Tested:** Debian GNU/Linux 13 (trixie), x86_64, from a fresh minimal `debootstrap --variant=minbase` environment. The clean-host run validated host setup only; it did not run an Android build or kernel build. Ubuntu is supported by the script, but has not had an equivalent clean-host validation.

ProjectGero provides a repeatable bootstrap for the validated host dependency set: 22 apt packages, including `gettext` for Mesa's `xgettext` build step and `rsync` for recovery-image assembly, ABI-compatible legacy ncurses/tinfo libraries, a private Python 2.7.18 runtime with zlib, Mako 1.1.4, MarkupSafe 1.1.1, and a modern-host rebuild of Flex 2.5.39. The persisted clean-host check covered the original 20-package host-setup set using a `HOST_BOOTSTRAP_TEST_ONLY` checkout; it did not run Android or kernel builds. The full Android build exposed the additional `gettext` and `rsync` requirements.

The private Python setup also enables the versioned `pip` and `setuptools` wheels bundled with Python 2.7.18's `ensurepip`, which are needed to install the validated legacy Python source distributions on a clean host.

This build does **not** require Android Studio or a normal external Android SDK/NDK installation. ProjectGero supplies and pins the historical GCC, Clang, JDK, and other tool prebuilts used by this Android 9 build. The host bootstrap supplies Linux packages, legacy host ABI libraries, Python 2.7.18 and its modules, modern-host-compatible Flex, and environment setup.

The bootstrap never replaces `/usr/bin/python`; its private tools default to `$HOME/.local/projectgero-tools`. It also never creates unsafe `libtinfo.so.6` or `libncurses.so.6` symlinks: the historical prebuilts require ABI-compatible `.so.5` libraries.

## Clone, LFS, and setup

Install Git LFS before checkout and use the first-level-only model:

```sh
git lfs install
git clone --depth 1 https://github.com/ProjectGero/android.git
cd android
git -c submodule.recurse=false submodule update --init --depth 1 --jobs 8

# Read-only diagnostic. Missing requirements are reported without changes.
./scripts/setup-db410c-android9-host.sh --check --projectgero-root "$PWD"

# Install only missing validated host dependencies and verify them afterwards.
./scripts/setup-db410c-android9-host.sh --install

# Use the rebuilt Flex only for this checkout's build; this intentionally dirties
# one tracked executable and is never committed.
./scripts/setup-db410c-android9-host.sh --apply-flex-override "$PWD"

# Export the private Python 2 runtime and deterministic locale for this shell.
source scripts/projectgero-db410c-env.sh
```

Bootstrap mode behavior:

- `--check` is a read-only diagnostic. It can report missing requirements and
  still exits 0 when the diagnostic itself succeeds.
- `--install` installs or prepares missing validated requirements, then checks
  readiness. It exits nonzero if required items remain missing.
- `--verify` is a strict read-only readiness gate. It exits 0 only when all
  required host and supplied source checks pass.

`--install` uses `sudo` only for apt packages; all ProjectGero-owned host tools live under the invoking user's tools prefix. It downloads only over HTTPS and validates the Python, Mako, MarkupSafe, and ProjectGero-pinned Flex source checksums. On a Debian/Ubuntu release where legacy ABI packages are absent from configured apt repositories, the script requires explicit HTTPS URL and SHA256 environment-variable pairs rather than using a random or stale mirror; `--help` lists those variables.

Run the final read-only validation at any time:

```sh
./scripts/setup-db410c-android9-host.sh --verify --projectgero-root "$PWD"
```

The submodule command initializes the 670 ProjectGero first-level components.
Do not use `git clone --recurse-submodules`: component-owned nested upstream
submodules are intentionally not initialized. Git LFS must materialize selected
payloads; affected paths include `device/google/wahoo-kernel`, `tools/dexter`,
`prebuilts/clang/host/linux-x86`, `tools/external/gradle`, `prebuilts/jdk/jdk9`,
`prebuilts/misc`, and `prebuilts/tools`.

## Modern-host Flex 2.5.39 compatibility

The tracked historical `prebuilts/misc/linux-x86/flex/flex-2.5.39` may start and pass simple lexer tests, yet crash in the real build while generating `external/mesa3d/src/mesa/program/program_lexer.l`:

```text
flex-2.5.39: loadlocale.c:130: _nl_intern_locale_data assertion failed
```

The setup script rebuilds **exactly Flex 2.5.39** from the checksum-verified archive already tracked in `prebuilts/misc`, applies the historical `scanflags.c` source compatibility correction exactly once, records the rebuilt executable SHA256, and validates both the Mesa program lexer and GLSL lexer when a ProjectGero root is supplied. The correction changes the historical `lerrsf_fatal(... %ld ..., (long)...);` form to `lerrif(... %d ..., (int)...);`; it is a source compatibility correction, not a claim that this line alone causes the glibc locale assertion. The critical runtime remedy is a Flex executable rebuilt for the current host.

`--apply-flex-override` copies that rebuilt executable to the effective Android path, preserves the original mode and hashes, and records state for a safe restore. It is a `BUILD_TOOL_RUNTIME_OVERRIDE`, not ProjectGero history; do not commit the rebuilt ELF. To restore only that recorded override later:

```sh
./scripts/setup-db410c-android9-host.sh --restore-flex "$PWD"
```

The restore refuses to overwrite an unrecognized modification and uses Git only for `prebuilts/misc/linux-x86/flex/flex-2.5.39`. It never runs a broad reset or clean.

## DB410c environment

From the ProjectGero root, after the bootstrap commands above:

```sh
source scripts/projectgero-db410c-env.sh
source build/envsetup.sh
lunch db410c-userdebug
source scripts/projectgero-db410c-env.sh
hash -r
```

Assert the environment helper again after `lunch` so build tools select the intended Python. `lunch` should report `PLATFORM_VERSION=9`, `TARGET_PRODUCT=db410c`, `TARGET_BUILD_VARIANT=userdebug`, `TARGET_ARCH=arm`, and `TARGET_ARCH_VARIANT=armv7-a-neon`; query individual values with `get_build_var`.

Envsetup generates ignored local directories under `device/linaro/generic/`: `db410c`, `linaro_arm`, `linaro_arm64`, `linaro_arm64_only`, and `linaro_x86_64`. Do not commit them. ProjectGero already contains the persistent `PRODUCT_NAME` compatibility fix in `vendorsetup.sh`.

## Kernel

From the ProjectGero root, build the ARM64 qcomlt-4.14 kernel:

```sh
source scripts/projectgero-db410c-env.sh
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
source scripts/projectgero-db410c-env.sh
source build/envsetup.sh
lunch db410c-userdebug
source scripts/projectgero-db410c-env.sh
hash -r
python --version
python -c 'import zlib; print("zlib OK:", zlib.ZLIB_VERSION)'
make -j"$(nproc)"
```

An earlier successful validation used `make -j12`. This finalization completed
the build with `make -j6` on a 12-core Debian 13 host to retain memory headroom;
its final incremental invocation completed in 25 minutes 37 seconds. Resume
incrementally after installing any missing host dependency. Principal outputs
are under `out/target/product/db410c/`: `boot.img`, `recovery.img`, `system.img`,
`userdata.img`, and `cache.img`. Do not expect binary-identical hashes across
different hosts or build environments.

## Incremental policy and troubleshooting

If a build fails, preserve `out/`, fix the first causal error, then rerun `make`. Ninja reuses completed intermediates; this bring-up succeeded by incremental continuation. Do not automatically run `make clean`, `make clobber`, or remove `out/`.

For the Mesa locale assertion, run `--verify --projectgero-root "$PWD"`, confirm the effective Flex override, then resume incrementally. If the override must be recreated, run `--prepare-flex --projectgero-root "$PWD"` followed by `--apply-flex-override "$PWD"`.

Warnings observed as non-fatal in this validation included invalid freedreno/virgl GPU drivers, unspecified `BOARD_SEPOLICY_VERS`, root `init.rc` command override, LLVM threads disabled, and AAPT2 resource warnings. They are not universally safe in every context.

## Local-state and capacity notes

Expected local state includes `out/`, `db410c-kernel/out-db410c/`, generated `device/linaro/generic` products, `device/linaro/generic-kernels/db410c-qcomlt-4.14.gz-dtb`, and the local Flex override. Do not accidentally commit them.

Measured guidance: shallow source is about 34.5 GB, kernel output about 2.3 GB, and completed Android `out/` about 64.5 GB. These are observations, not minima; retain significant headroom. Full-history recursive clones can require hundreds of GB.

## Hardware deployment

Build validation is complete. Flashing and physical DragonBoard boot validation are a separate, not-yet-validated step; this guide intentionally provides no deployment procedure.
