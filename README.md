# ProjectGero Android

ProjectGero preserves a reproducible Android 9 source baseline (`android-9.0.0_r61`) for DragonBoard 410c-oriented development.

This repository is a Git superproject: one ProjectGero repository represents each AOSP project, while this top-level repository pins the exact component commits. `source_sha` records upstream AOSP provenance; `target_sha` records the ProjectGero representation selected by each gitlink.

Some components carry approved ProjectGero local patches, GitHub-compatibility history transformations, Git LFS transformations, or security credential redaction. The transformed categories are `unchanged`, `local_patch`, `history_transformation`, `lfs_history_transformation`, and `secret_redaction`. In particular, `platform_external_toolchain-utils` intentionally omits sensitive historical credential material.

## Clone

Install Git LFS before cloning because some selected submodules contain LFS-managed prebuilt, test, or tool content:

```sh
git lfs install
git clone --depth 1 https://github.com/ProjectGero/android.git
cd android
git -c submodule.recurse=false submodule update --init --depth 1 --jobs 8
```

This initializes the 670 ProjectGero AOSP component repositories only. Some
preserved upstream components contain their own nested Git submodules; those
are intentionally not initialized by the standard ProjectGero checkout.

The final Phase 2B inventory identifies these LFS-affected submodules:

- `ProjectGero/device_google_wahoo-kernel`
- `ProjectGero/platform_tools_dexter`
- `ProjectGero/platform_prebuilts_clang_host_linux-x86`
- `ProjectGero/platform_tools_external_gradle`
- `ProjectGero/platform_prebuilts_jdk_jdk9`
- `ProjectGero/platform_prebuilts_misc`
- `ProjectGero/platform_prebuilts_tools`

Detailed component provenance and transformation evidence are retained in the ProjectGero migration reports.
