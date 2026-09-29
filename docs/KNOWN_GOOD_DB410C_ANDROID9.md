# ProjectGero DB410c Android 9 baseline record

This record captures the ProjectGero revision checked at finalization start and
the previously recorded successful build outputs. The available build reports
and output files were not present in the finalization workspace, so the output
hashes below were not recomputed here and cannot be tied to a verified build
source commit from the available evidence. See
[`KNOWN_GOOD_DB410C_ANDROID9.json`](KNOWN_GOOD_DB410C_ANDROID9.json) for
machine-readable details.

## Baseline

- Android: 9, `android-9.0.0_r61`
- Product: `db410c-userdebug` for Qualcomm DragonBoard 410c
- Architecture: ARM64 qcomlt-4.14 kernel with ARM32 `armv7-a-neon` userspace
- ProjectGero/android checkout at record creation:
  `7b7fba6ea011dafd0d4487dc77af211c2623a34a`
- `origin/master` at record creation:
  `1e215b50a78cd5a85a5663ae11c333b0ce76e2b4`
- Tested host setup: Debian GNU/Linux 13 (trixie), x86_64, fresh minimal
  `debootstrap --variant=minbase` environment
- Host bootstrap: PASS; the clean-host validation covered setup, not Android or
  kernel builds
- Kernel build: PASS in the prior validation record
- Android build: PASS in the prior validation record
- Physical DB410c deployment: **NOT YET VALIDATED**

The build source commit was not recorded in the reports available in this
workspace. The current checkout is a shallow host-bootstrap validation tree,
with only 5 of 670 first-level components initialized. Treat these hashes as
the prior successful output reference, not as a newly verified archive.

## Previously recorded artifact hashes

| Artifact | SHA-256 |
|---|---|
| `boot.img` | `d472466adb63cdb67fcbe2f80f71d82183df2e3d5e1f11d9005de42be89a3017` |
| `recovery.img` | `bc8032297a36004e71275a97dedf266885bcc6fd20fa38ebd31a0b66b8091147` |
| `system.img` | `b07a131517bdb346952d904feecc469b78dd627de6f0006bd1c8a1720c88fc5c` |
| `Image.gz` | `572af63b9be1daa799caefa3a930649b187d6bbcc89282ceca95d611482998f9` |
| `apq8016-sbc.dtb` | `d23e24b4c02c1b723577e7ca47f90b14af64d3c689c7383ff013f07199917c7c` |
| `db410c-qcomlt-4.14.gz-dtb` | `05859a14b77933b9c71779f0d985f0f5ae7157f6be3d51688e6f9f69aadde4cf` |

The artifact archive, `SHA256SUMS`, and `file-sizes.txt` have not been created
because the successful build outputs were absent from the workspace. No build
output has been deleted.

## Release tag

No existing local or remote tag convention was found. Recommended candidate:
`android-9.0.0_r61-db410c-v1`. No tag was created; this would establish a new
public naming convention.
