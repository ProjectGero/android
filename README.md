# ProjectGero Android

## Overview

ProjectGero is a Git-superproject representation of the Android 9 `android-9.0.0_r61` source baseline. It preserves a reproducible AOSP state using normal Git and GitHub rather than the original repo/Gerrit workflow. The top-level repository contains 670 first-level ProjectGero AOSP components as submodules; its gitlinks pin the integrated operating-system state.

## Current validated status

| Validation | Status |
|---|---|
| Git migration | PASS |
| 670-component checkout | PASS |
| LFS materialization | PASS |
| DB410c envsetup/lunch | PASS |
| qcomlt-4.14 kernel build | PASS |
| Android 9 `db410c-userdebug` build | PASS |
| Physical board boot | NOT YET VALIDATED |

ProjectGero successfully builds Android 9 `db410c-userdebug` for DragonBoard 410c. Hardware flashing and boot validation remain a separate future step.

## Architecture

DragonBoard 410c uses the ARM64 qcomlt-4.14 Linux kernel and ARM32 Android userspace (`TARGET_ARCH=arm`, `TARGET_ARCH_VARIANT=armv7-a-neon`).

`source_sha` identifies upstream/source provenance. `target_sha` identifies the ProjectGero representation selected by the superproject gitlink. Some components intentionally contain local compatibility patches, GitHub history transformations, Git LFS transformations, or secret redaction.

## Clone

Install Git LFS before checkout, then initialize only first-level ProjectGero components:

```sh
git lfs install
git clone --depth 1 https://github.com/ProjectGero/android.git
cd android
git -c submodule.recurse=false submodule update --init --depth 1 --jobs 8
```

This initializes exactly the 670 first-level components. Nested upstream Git submodules owned by individual components are intentionally not part of the standard ProjectGero initialization flow.

## Git LFS

Git LFS must be installed before checkout so selected payloads can be materialized. Current LFS component paths are `device/google/wahoo-kernel`, `tools/dexter`, `prebuilts/clang/host/linux-x86`, `tools/external/gradle`, `prebuilts/jdk/jdk9`, `prebuilts/misc`, and `prebuilts/tools`.

## Quick build overview

The validated DB410c workflow uses a Linux x86_64 host, a dedicated Python 2.7.18 runtime, a locally rebuilt Flex 2.5.39 runtime override for modern glibc hosts, an ARM64 qcomlt kernel build, and then `db410c-userdebug`.

## Detailed DB410c build guide

See [the verified DB410c Android 9 build guide](docs/DB410C_ANDROID9_BUILD.md) for prerequisites, clone and LFS checks, Flex handling, kernel build, Android build, incremental recovery, and expected outputs.

## Repository conventions

Top-level gitlinks are authoritative for component revisions. Generated build state and local host-tool overrides are not source changes and must not be committed accidentally.

## Known limitations

The normal shallow checkout is roughly 34.5 GB, while a completed DB410c Android output is roughly 64.5 GB; retain substantial additional working space. A full-history recursive clone is not the normal workflow and can require hundreds of GB. Deployment, flashing, and physical-board boot have not been validated in this ProjectGero phase.
