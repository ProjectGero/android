# ProjectGero DB410c Android 9 known-good baseline

This record identifies the source revision and host configuration used for the
verified ProjectGero Android 9 build. Artifact hashes below were recomputed
from the completed build outputs. The archive manifest verified all 25 archived
payload and report files.

## Baseline and validation

- Android: 9, `android-9.0.0_r61`
- Product: `db410c-userdebug` for Qualcomm DragonBoard 410c
- Architecture: ARM64 qcomlt-4.14 kernel and ARM32 `armv7-a-neon` userspace
- ProjectGero/android build source commit: `804afc10bec74e324f132e8907b9cc7adc3d2bb2`
- Source checkout: all 670 first-level components initialized; no missing
  components, gitlink mismatches, or conflicts
- Git LFS: 7 repositories and 13 selected payloads materialized; total
  materialized payload size 1,617,939,610 bytes; all seven repository checks
  passed
- Full Android build host: Debian GNU/Linux 13 (trixie) 13.6, x86_64
- Android build: **PASS**, `make -j6`; final incremental invocation completed
  in 25 minutes 37 seconds
- Kernel build: **PASS**, qcomlt-4.14 `qcom_defconfig`, ARM64 with
  `CONFIG_ARM64=y` and `CONFIG_ARCH_QCOM=y`
- Hardware deployment: **NOT YET VALIDATED**

A separate fresh minimal `debootstrap --variant=minbase` run on Debian 13.7
passed host setup. That test validated the original 20-package host setup only;
it did not build Android or the kernel. The complete build host was separately
checked with the current 22-package bootstrap, including `gettext` for Mesa's
`xgettext` step and `rsync` for recovery-image assembly. `--install` and strict
`--verify` both ended with `PROJECTGERO DB410C HOST: READY`. Ubuntu is supported
by the script but has not had equivalent clean-host validation.

The successful Android build used the host-rebuilt Flex 2.5.39 runtime
override. The override was restored afterwards; the tracked Flex executable
matches its original SHA-256 and mode. No physical device was flashed.

## Android artifacts

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `boot.img` | 10,442,752 | `993fd44a59ed3960f3c33ea559a914a265ab823cb2ce3f33d10dda5a0758f3b3` |
| `recovery.img` | 14,768,128 | `b046f0a8f6e2e1ab39cda04c63cdfa5fdacc24d47b836784346c927cf9213580` |
| `system.img` | 728,248,564 | `cd11d25f2ce92e7ea8b8499077cf72f5a9034df529afacf94c0719f95bee6b34` |
| `userdata.img` | 1,724,804 | `e0bd7d440b57cd2bea8e7ce5a7acdc1936f3ddbed29d44bff7940675c1e87285` |
| `cache.img` | 73,876 | `853ba3156e4625ba333a89d504fc427fc2034d39c7f3620af9bc40fabda8ff0a` |

The system, userdata, and cache images are Android sparse images. Generated
build properties and `installed-files.txt` are also preserved with the build
reference. No target-files package was generated.

## Kernel artifacts

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `Image.gz` | 8,765,581 | `1cb932ec6953ea8f2db3953b1a8421a84cdd1396b0009a4b18e7096a9643d728` |
| `apq8016-sbc.dtb` | 53,229 | `d23e24b4c02c1b723577e7ca47f90b14af64d3c689c7383ff013f07199917c7c` |
| `db410c-qcomlt-4.14.gz-dtb` | 8,818,810 | `f3e5d2d8ebc9a9a72246b299e3f20d0fef449f4b84c4d7360c5843d67b87d4a2` |

The DTB hash matches the earlier successful reference. The compressed kernel
image hash differs slightly from that earlier record; the kernel configuration
and build checks passed.

## Release tag

No ProjectGero/android tag convention was found locally or on the remote.
Recommended candidate: `android-9.0.0_r61-db410c-v1`. No tag was created because
this would establish a new public versioning convention.

For machine-readable details, see
[`KNOWN_GOOD_DB410C_ANDROID9.json`](KNOWN_GOOD_DB410C_ANDROID9.json).
