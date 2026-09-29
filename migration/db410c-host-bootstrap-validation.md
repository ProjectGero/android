# ProjectGero DB410c host bootstrap validation

**Result:** `PROJECTGERO FRESH HOST BOOTSTRAP: PASS`  
**Validated:** 2026-09-29

## Test host

- Debian GNU/Linux 13 (trixie), point release 13.7, x86_64.
- Fresh `debootstrap --variant=minbase` root filesystem. A temporary account and `sudo` were added for apt administration; no ProjectGero Python, Mako, MarkupSafe, Flex, or tools prefix was present before the check.
- The host bootstrap ran as the temporary unprivileged user. Required dependencies were installed by `--install`.

## Checkout scope

- Top-level commit: `1e215b50a78cd5a85a5663ae11c333b0ce76e2b4`.
- Checkout mode: `HOST_BOOTSTRAP_TEST_ONLY` (shallow top-level clone, with the source paths needed by the checks).
- Initialized five first-level components: `external/mesa3d`, `prebuilts/clang/host/linux-x86`, both ProjectGero GCC 4.9 prebuilts, and `prebuilts/misc`. The other first-level components were not initialized.
- This test validates host setup only. No Android build, DB410c kernel build, deployment, or flashing was run.

## Results

| Check | Result | Evidence |
| --- | --- | --- |
| Pre-install `--check` | PASS | Exit 0; reported 28 missing requirements. dpkg status, apt archive cache, and the ProjectGero tools prefix were unchanged. |
| First `--install` | PASS | Exit 0; ended with `PROJECTGERO DB410C HOST: READY`. |
| Final `--verify` | PASS | Exit 0; ended with `PROJECTGERO DB410C HOST: READY`, including after the second install and after Flex restore. |
| Second `--install` | IDEMPOTENT | Exit 0; apt set, Python, Python packaging tools, and rebuilt Flex were reused. Python and Flex hashes and mtimes were unchanged. |
| Private Python | PASS | Python 2.7.18; `zlib` imports; bundled `pip` 19.2.3 and `setuptools` 41.2.0 available. |
| Mako and MarkupSafe | PASS | Mako 1.1.4 and MarkupSafe 1.1.1 import from the private prefix. |
| Legacy ABI | PASS | Debian `libtinfo5` and `libncurses5` 6.4-4 packages own the real `.so.5` libraries. Resolved files are `.so.5.9`; no `.so.6` symlink is used. |
| Flex rebuild | PASS | Rebuilt Flex 2.5.39; both Mesa `program_lexer.l` and GLSL `glsl_lexer.ll` generation passed. |
| Flex apply and restore | PASS | Apply modified only `prebuilts/misc/linux-x86/flex/flex-2.5.39`; its hash matched the rebuilt executable and the program lexer passed. Restore returned the original SHA256 and mode 755; component status returned to clean and no override state file remained. |
| Environment helper | PASS | `PATH` starts with the private Python 2 bin directory, `LC_ALL=C`, `LANG=C`, and `python --version` reports Python 2.7.18. |

Debian 13 does not provide the required ABI 5 packages in its configured repositories. The script's checksum-verified fallback installed the official Debian `libtinfo5` and `libncurses5` 6.4-4 packages:

- `libtinfo5`: `https://deb.debian.org/debian/pool/main/n/ncurses/libtinfo5_6.4-4_amd64.deb`, SHA256 `dd347f794e651039e7b4c391f86c674fed7f415b3dca6b0937beb0d470f09c1a`.
- `libncurses5`: `https://deb.debian.org/debian/pool/main/n/ncurses/libncurses5_6.4-4_amd64.deb`, SHA256 `02f4f7f52c4ce2fc4021793a931bfd85f7870554b8e4d56576d73a4ed0bdb390`.

## Bootstrap defects fixed

- Provision Python 2.7.18's bundled `ensurepip` tools before installing legacy sdists; MarkupSafe needs `setuptools` on a clean prefix.
- Build Flex's `lib/libcompat.la` before the top-level `flex` target.
- Check the Flex version token without requiring the executable's basename to be exactly `flex` (`flex-2.5.39 --version` prints `flex-2.5.39 2.5.39`).

The final clean-host run completed with `PROJECTGERO DB410C HOST: READY` and the overall result `PROJECTGERO FRESH HOST BOOTSTRAP: PASS`.
