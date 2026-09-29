# ProjectGero Android

## Overview

ProjectGero preserves a reproducible Android 9 AOSP baseline,
`android-9.0.0_r61`, using normal Git and GitHub rather than the original
repo/Gerrit workflow. It is a Git superproject: the top-level repository
contains 670 first-level ProjectGero AOSP components as Git submodules, and
its gitlinks pin the integrated OS state.

ProjectGero has successfully built Android 9 `db410c-userdebug` for
DragonBoard 410c. This establishes build reproducibility; it does not claim
production readiness or physical-hardware validation.

## Current validated status

| Validation | Status |
|---|---|
| Git migration | PASS |
| 670-component shallow checkout | PASS |
| Git LFS materialization | PASS |
| DB410c environment setup and lunch | PASS |
| qcomlt-4.14 kernel build | PASS |
| Android 9 `db410c-userdebug` build | PASS |
| DragonBoard flashing and boot | NOT YET VALIDATED |

## Architecture

The DragonBoard 410c configuration pairs an ARM64 qcomlt-4.14 Linux kernel
with ARM32 Android userspace:

- `TARGET_ARCH=arm`
- `TARGET_ARCH_VARIANT=armv7-a-neon`

`source_sha` records upstream/source provenance. `target_sha` records the
ProjectGero representation pinned by the top-level gitlink. Some ProjectGero
repositories intentionally include local compatibility patches, GitHub history
transformations, Git LFS transformations, or secret redaction.

## Clone

Install Git LFS before checkout, then initialize only ProjectGero's
first-level components:

```sh
git lfs install
git clone --depth 1 https://github.com/ProjectGero/android.git
cd android
git -c submodule.recurse=false submodule update --init --depth 1 --jobs 8
```

This initializes exactly the 670 first-level ProjectGero components. Do not
use `git clone --recurse-submodules`: preserved upstream components may own
nested third-party submodules, which are intentionally outside the standard
ProjectGero initialization flow.

## Git LFS

Git LFS must be installed before checkout so that selected payloads are
materialized. Current LFS-managed component paths include:

- `device/google/wahoo-kernel`
- `tools/dexter`
- `prebuilts/clang/host/linux-x86`
- `tools/external/gradle`
- `prebuilts/jdk/jdk9`
- `prebuilts/misc`
- `prebuilts/tools`

## Quick build overview

The verified DB410c workflow uses an x86_64 Linux host, a dedicated Python
2.7.18 runtime, a rebuilt Flex 2.5.39 runtime override, an ARM64 qcomlt-4.14
kernel build, and then the Android `db410c-userdebug` build.

**Tested host:** Debian GNU/Linux 13 (trixie), x86_64, validated from a fresh
minimal `debootstrap --variant=minbase` environment. That clean-host run
validated host setup only; it did not build Android or the kernel. The setup
script supports Debian and Ubuntu x86_64 hosts, but Ubuntu has not had an
equivalent clean-host validation.

ProjectGero does not require an external Android Studio SDK or NDK. The source
checkout pins the historical GCC, Clang, JDK, and other tool prebuilts used by
this Android 9 build. The host bootstrap supplies Linux packages, legacy ABI
libraries, Python 2.7.18 and its modules, rebuilt Flex, and shell environment
setup.

The host setup script has three validation modes: `--check` is read-only and
returns success when the diagnostic completes, even if it reports missing
requirements; `--install` prepares missing validated requirements and checks
readiness afterward; `--verify` is a strict read-only readiness gate and
returns success only when the host is ready. See the detailed guide for the
full workflow and local-state handling.

## Detailed DB410c build guide

The [verified DB410c Android 9 build guide](docs/DB410C_ANDROID9_BUILD.md)
documents prerequisites, LFS checkout, the local-only Flex workflow, kernel
build, incremental Android builds, expected artifacts, and troubleshooting.
The [known-good baseline record](docs/KNOWN_GOOD_DB410C_ANDROID9.md) lists the
previously recorded artifact hashes and clearly marks what was not reverified
or archived in the finalization workspace.

## Repository conventions

Top-level gitlinks are authoritative for component revisions. Generated build
directories, kernel outputs, combined kernel input, and local host-tool
overrides are build/runtime state, not source changes to commit.

## Known limitations

A shallow checkout is approximately 34.5 GB; a completed Android `out/` is
approximately 64.5 GB. These are observed sizes, not minimum requirements;
retain significant extra working space. Full-history recursive clones are not
the normal developer workflow and can require hundreds of GB.

ProjectGero build validation is complete. Hardware deployment, flashing, and
physical DragonBoard boot validation are separate future work.
