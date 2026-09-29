#!/usr/bin/env bash
# Reproducible Debian/Ubuntu host bootstrap for ProjectGero Android 9 DB410c.
# This script deliberately installs no Android SDK, Android Studio, or modern NDK:
# ProjectGero pins the historical compiler/toolchain prebuilts in the checkout.
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly DEFAULT_TOOLS_DIR="$HOME/.local/projectgero-tools"
readonly PYTHON_VERSION="2.7.18"
readonly MAKO_VERSION="1.1.4"
readonly MARKUPSAFE_VERSION="1.1.1"
readonly FLEX_VERSION="2.5.39"
readonly PYTHON_URL="https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz"
readonly PYTHON_SHA256="da3080e3b488f648a3d7a4560ddee895284c3380b11d6de75edb986526b9a814"
readonly MAKO_URL="https://files.pythonhosted.org/packages/source/M/Mako/Mako-1.1.4.tar.gz"
readonly MAKO_SHA256="17831f0b7087c313c0ffae2bcbbd3c1d5ba9eeac9c38f2eb7b50e8c99fe9d5ab"
readonly MARKUPSAFE_URL="https://files.pythonhosted.org/packages/source/M/MarkupSafe/MarkupSafe-1.1.1.tar.gz"
readonly MARKUPSAFE_SHA256="29872e92839765e546828bb7754a68c418d927cd064fd4708fab9fe9c8bb116b"
# This is the source archive tracked by ProjectGero prebuilts/misc.
readonly FLEX_ARCHIVE_SHA256="71dd1b58158c935027104c830c019e48c73250708af5def45ea256c789318948"

readonly -a REQUIRED_PACKAGES=(
  bc m4 zip unzip wget curl git git-lfs build-essential gcc g++ make gettext rsync
  zlib1g zlib1g-dev libffi-dev libbz2-dev libreadline-dev libsqlite3-dev
  file ca-certificates
)

MODE=""
PROJECTGERO_ROOT="${PROJECTGERO_ROOT:-}"
PROJECTGERO_TOOLS_DIR="${PROJECTGERO_TOOLS_DIR:-$DEFAULT_TOOLS_DIR}"
OVERRIDE_ROOT=""
MISSING_COUNT=0

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

on_error() {
  local line=$1 status=$2
  printf 'ERROR: setup stopped at line %s (exit %s).\n' "$line" "$status" >&2
}
trap 'on_error "$LINENO" "$?"' ERR

usage() {
  cat <<'EOF'
Usage:
  scripts/setup-db410c-android9-host.sh --check [--projectgero-root ROOT]
  scripts/setup-db410c-android9-host.sh --verify [--projectgero-root ROOT]
  scripts/setup-db410c-android9-host.sh --install [--projectgero-root ROOT]
  scripts/setup-db410c-android9-host.sh --prepare-flex [--projectgero-root ROOT]
  scripts/setup-db410c-android9-host.sh --apply-flex-override ROOT
  scripts/setup-db410c-android9-host.sh --restore-flex ROOT

Environment:
  PROJECTGERO_TOOLS_DIR  Private tools prefix (default: $HOME/.local/projectgero-tools)
  PROJECTGERO_ROOT       ProjectGero checkout used for source-dependent checks

On releases without libtinfo5/libncurses5 in their configured apt repositories,
the controlled fallback requires the following HTTPS URL and SHA256 pairs:
  PROJECTGERO_LEGACY_TINFO_DEB_URL / PROJECTGERO_LEGACY_TINFO_DEB_SHA256
  PROJECTGERO_LEGACY_NCURSES_DEB_URL / PROJECTGERO_LEGACY_NCURSES_DEB_SHA256
EOF
}

report() {
  local label=$1 result=$2 detail=${3:-}
  printf '%-34s %-7s %s\n' "$label" "$result" "$detail"
  [[ $result == PASS ]] || MISSING_COUNT=$((MISSING_COUNT + 1))
}

is_x86_64() { [[ $(uname -m) == x86_64 ]]; }

supported_distro() {
  [[ -r /etc/os-release ]] || return 1
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ ${ID:-} == debian || ${ID:-} == ubuntu || ${ID_LIKE:-} == *debian* ]]
}

require_supported_host() {
  is_x86_64 || die "DB410c Android 9 host setup requires x86_64 (found: $(uname -m))."
  supported_distro || die "Unsupported host. Only Debian and Ubuntu are supported; apt will not be run."
}

infer_root() {
  if [[ -z $PROJECTGERO_ROOT && -f "$DEFAULT_ROOT/prebuilts/misc/linux-x86/flex/flex-2.5.39.tar.gz" ]]; then
    PROJECTGERO_ROOT=$DEFAULT_ROOT
  fi
  if [[ -n $PROJECTGERO_ROOT ]]; then
    PROJECTGERO_ROOT="$(cd "$PROJECTGERO_ROOT" && pwd)"
  fi
}

command_ready() { command -v "$1" >/dev/null 2>&1; }

package_installed() { dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null | grep -qx installed; }

library_present() {
  local ldconfig_bin
  ldconfig_bin=$(command -v ldconfig 2>/dev/null || true)
  if [[ -z $ldconfig_bin ]]; then
    for candidate in /sbin/ldconfig /usr/sbin/ldconfig; do
      if [[ -x $candidate ]]; then
        ldconfig_bin=$candidate
        break
      fi
    done
  fi
  [[ -n $ldconfig_bin ]] || return 1
  "$ldconfig_bin" -p 2>/dev/null | awk '{print $1}' | grep -Fxq "$1"
}

python_bin() { printf '%s/python2/bin/python\n' "$PROJECTGERO_TOOLS_DIR"; }
flex_bin() { printf '%s/flex/bin/flex-2.5.39\n' "$PROJECTGERO_TOOLS_DIR"; }

python_ready() {
  local python
  python=$(python_bin)
  [[ -x $python ]] && [[ $($python --version 2>&1) == "Python $PYTHON_VERSION" ]] && "$python" -c 'import zlib' >/dev/null 2>&1
}

mako_ready() {
  local python
  python=$(python_bin)
  "$python" -c 'import mako.template; import mako; assert mako.__version__ == "1.1.4"' >/dev/null 2>&1
}

markupsafe_ready() {
  local python
  python=$(python_bin)
  "$python" -c 'import markupsafe; assert markupsafe.__version__ == "1.1.1"' >/dev/null 2>&1
}

python_packaging_ready() {
  local python
  python=$(python_bin)
  "$python" -c 'import pip; import setuptools' >/dev/null 2>&1
}

flex_ready() {
  local flex
  flex=$(flex_bin)
  [[ -x $flex ]] && "$flex" --version 2>&1 | grep -Fq " $FLEX_VERSION"
}

wrapper_uses_env_python() {
  [[ -f $1 ]] && [[ $(head -n 1 "$1") == '#!/usr/bin/env python' ]]
}

verify_host_basics() {
  MISSING_COUNT=0
  if is_x86_64; then report "Host architecture" PASS "x86_64"; else report "Host architecture" MISSING "requires x86_64"; fi
  if supported_distro; then report "Supported distro" PASS "Debian/Ubuntu"; else report "Supported distro" MISSING "only Debian/Ubuntu supported"; fi

  local package
  for package in "${REQUIRED_PACKAGES[@]}"; do
    if package_installed "$package"; then
      report "$package" PASS
    else
      report "$package" MISSING "install with --install"
    fi
  done
  if [[ -f /usr/include/zlib.h ]]; then report "zlib headers" PASS; else report "zlib headers" MISSING; fi
  if library_present libtinfo.so.5; then report "libtinfo.so.5" PASS; else report "libtinfo.so.5" MISSING "ABI package required; never use a .so.6 symlink"; fi
  if library_present libncurses.so.5; then report "libncurses.so.5" PASS; else report "libncurses.so.5" MISSING "ABI package required; never use a .so.6 symlink"; fi

  local python
  python=$(python_bin)
  if [[ -x $python ]] && [[ $($python --version 2>&1) == "Python $PYTHON_VERSION" ]]; then report "Python 2.7.18" PASS "$python"; else report "Python 2.7.18" MISSING "$python"; fi
  if [[ -x $python ]] && "$python" -c 'import zlib' >/dev/null 2>&1; then report "Python zlib" PASS; else report "Python zlib" MISSING; fi
  if [[ -x $python ]] && mako_ready; then report "Mako 1.1.4" PASS; else report "Mako 1.1.4" MISSING; fi
  if [[ -x $python ]] && markupsafe_ready; then report "MarkupSafe 1.1.1" PASS; else report "MarkupSafe 1.1.1" MISSING; fi
  if command_ready git && git lfs version >/dev/null 2>&1; then report "Git LFS" PASS; else report "Git LFS" MISSING; fi

  local flex
  flex=$(flex_bin)
  if flex_ready; then report "Flex 2.5.39 rebuilt tool" PASS "$flex"; else report "Flex 2.5.39 rebuilt tool" MISSING "$flex"; fi
}

verify_project_source() {
  [[ -n $PROJECTGERO_ROOT ]] || {
    report "Flex program_lexer test" PASS "SKIPPED (no ProjectGero root supplied)"
    report "ProjectGero prebuilts" PASS "SKIPPED (no ProjectGero root supplied)"
    return
  }
  if [[ -f "$PROJECTGERO_ROOT/external/mesa3d/src/mesa/program/program_lexer.l" && -f "$PROJECTGERO_ROOT/external/mesa3d/src/compiler/glsl/glsl_lexer.ll" ]]; then
    if flex_ready && validate_flex_inputs "$PROJECTGERO_ROOT"; then
      report "Flex program_lexer test" PASS "program and GLSL lexers"
    elif flex_ready; then
      report "Flex program_lexer test" MISSING "lexer generation failed"
    else
      report "Flex program_lexer test" MISSING "rebuilt Flex unavailable"
    fi
  else
    report "Flex program_lexer test" MISSING "incomplete ProjectGero source tree"
  fi

  local a64="$PROJECTGERO_ROOT/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9"
  local arm="$PROJECTGERO_ROOT/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9"
  local clang="$PROJECTGERO_ROOT/prebuilts/clang/host/linux-x86/clang-3289846/bin"
  if [[ -d $a64 && -d $arm && -d "$PROJECTGERO_ROOT/prebuilts/clang/host/linux-x86" ]] && \
     wrapper_uses_env_python "$a64/bin/aarch64-linux-android-gcc" && \
     wrapper_uses_env_python "$arm/bin/arm-linux-androideabi-gcc" && \
     wrapper_uses_env_python "$clang/clang" && \
     wrapper_uses_env_python "$clang/clang++"; then
    report "ProjectGero prebuilts" PASS "GCC/Clang wrappers use env python"
  else
    report "ProjectGero prebuilts" MISSING "checkout incomplete or wrapper mismatch"
  fi
}

validate_flex_inputs() {
  local root=$1 flex
  flex=$(flex_bin)
  # /dev/null exercises full lexer generation without creating source-tree or
  # host files; this keeps --check and --verify read-only.
  "$flex" -o /dev/null "$root/external/mesa3d/src/mesa/program/program_lexer.l" >/dev/null
  "$flex" --nounistd -o /dev/null "$root/external/mesa3d/src/compiler/glsl/glsl_lexer.ll" >/dev/null
}

download_checked() {
  local url=$1 expected_sha=$2 destination=$3 actual
  [[ $url == https://* ]] || die "Refusing non-HTTPS download: $url"
  printf 'Downloading %s\n' "$url"
  if command_ready curl; then
    curl --fail --location --retry 3 --output "$destination" "$url"
  else
    wget --https-only --output-document="$destination" "$url"
  fi
  actual=$(sha256sum "$destination" | awk '{print $1}')
  [[ $actual == "$expected_sha" ]] || die "Checksum mismatch for $url"
}

install_packages() {
  require_supported_host
  local missing=() package
  for package in "${REQUIRED_PACKAGES[@]}"; do package_installed "$package" || missing+=("$package"); done
  if ((${#missing[@]})); then
    printf 'Installing missing apt packages: %s\n' "${missing[*]}"
    sudo apt-get update
    sudo apt-get install --yes "${missing[@]}"
  else
    printf 'Validated apt package set is already installed.\n'
  fi
  install_legacy_abi
}

install_legacy_deb() {
  local name=$1 url=$2 checksum=$3 temp
  [[ -n $url && -n $checksum ]] || die "No apt package provides $name. Set its PROJECTGERO_LEGACY_*_DEB_URL and SHA256 controlled fallback variables."
  [[ $checksum =~ ^[0-9a-fA-F]{64}$ ]] || die "Invalid SHA256 for $name fallback package."
  temp=$(mktemp "${TMPDIR:-/tmp}/projectgero-${name}.XXXXXX.deb")
  download_checked "$url" "$checksum" "$temp"
  [[ $(dpkg-deb -f "$temp" Architecture) == amd64 ]] || die "$name fallback package is not amd64."
  printf 'Installing verified legacy ABI package for %s\n' "$name"
  sudo apt-get install --yes "$temp"
}

install_legacy_abi() {
  library_present libtinfo.so.5 && library_present libncurses.so.5 && return
  local available=() package
  for package in libtinfo5 libncurses5; do apt-cache show "$package" >/dev/null 2>&1 && available+=("$package"); done
  if ((${#available[@]})); then
    printf 'Installing legacy ABI packages from configured apt repositories: %s\n' "${available[*]}"
    sudo apt-get install --yes "${available[@]}"
  fi
  library_present libtinfo.so.5 || install_legacy_deb libtinfo.so.5 "${PROJECTGERO_LEGACY_TINFO_DEB_URL:-}" "${PROJECTGERO_LEGACY_TINFO_DEB_SHA256:-}"
  library_present libncurses.so.5 || install_legacy_deb libncurses.so.5 "${PROJECTGERO_LEGACY_NCURSES_DEB_URL:-}" "${PROJECTGERO_LEGACY_NCURSES_DEB_SHA256:-}"
}

install_python() {
  python_ready && { printf 'Reusing dedicated Python %s.\n' "$(python_bin)"; return; }
  local work archive source prefix_new prefix_old jobs
  work=$(mktemp -d "${TMPDIR:-/tmp}/projectgero-python.XXXXXX")
  archive="$work/Python-$PYTHON_VERSION.tgz"
  download_checked "$PYTHON_URL" "$PYTHON_SHA256" "$archive"
  tar -xzf "$archive" -C "$work"
  source="$work/Python-$PYTHON_VERSION"
  prefix_new="$PROJECTGERO_TOOLS_DIR/python2.new.$$"
  prefix_old="$PROJECTGERO_TOOLS_DIR/python2.previous.$(date +%Y%m%d%H%M%S)"
  mkdir -p "$PROJECTGERO_TOOLS_DIR"
  jobs=$(nproc)
  (cd "$source" && ./configure --prefix="$prefix_new" && make -j"$jobs" && make install)
  [[ $($prefix_new/bin/python --version 2>&1) == "Python $PYTHON_VERSION" ]] || die "Built Python version did not match $PYTHON_VERSION."
  "$prefix_new/bin/python" -c 'import zlib' || die "Built Python lacks zlib. Check zlib1g-dev."
  if [[ -e "$PROJECTGERO_TOOLS_DIR/python2" ]]; then
    mv "$PROJECTGERO_TOOLS_DIR/python2" "$prefix_old"
    printf 'Preserved previous Python prefix at %s\n' "$prefix_old"
  fi
  mv "$prefix_new" "$PROJECTGERO_TOOLS_DIR/python2"
  printf 'Installed dedicated Python at %s\n' "$(python_bin)"
}

install_python_module() {
  local name=$1 version=$2 url=$3 checksum=$4 work archive source python
  python=$(python_bin)
  work=$(mktemp -d "${TMPDIR:-/tmp}/projectgero-${name}.XXXXXX")
  archive="$work/$name-$version.tar.gz"
  download_checked "$url" "$checksum" "$archive"
  tar -xzf "$archive" -C "$work"
  source=$(find "$work" -mindepth 1 -maxdepth 1 -type d -name "$name-$version" -print -quit)
  [[ -n $source ]] || die "Could not find unpacked $name source."
  (cd "$source" && "$python" setup.py install)
}

install_python_modules() {
  install_python
  if ! python_packaging_ready; then
    local python
    python=$(python_bin)
    # Python 2.7.18 bundles pinned pip/setuptools wheels in ensurepip. Bootstrap
    # them locally so legacy sdists that import setuptools install on a clean host.
    "$python" -m ensurepip --default-pip
    python_packaging_ready || die "Could not provision the bundled Python packaging tools."
  else
    printf 'Reusing private Python packaging tools.\n'
  fi
  markupsafe_ready || install_python_module MarkupSafe "$MARKUPSAFE_VERSION" "$MARKUPSAFE_URL" "$MARKUPSAFE_SHA256"
  mako_ready || install_python_module Mako "$MAKO_VERSION" "$MAKO_URL" "$MAKO_SHA256"
  markupsafe_ready || die "MarkupSafe $MARKUPSAFE_VERSION installation failed."
  mako_ready || die "Mako $MAKO_VERSION installation failed."
}

flex_archive() {
  local archive="${PROJECTGERO_FLEX_ARCHIVE:-}"
  if [[ -z $archive && -n $PROJECTGERO_ROOT ]]; then archive="$PROJECTGERO_ROOT/prebuilts/misc/linux-x86/flex/flex-2.5.39.tar.gz"; fi
  [[ -f $archive ]] || die "Flex source archive unavailable. Supply --projectgero-root with a complete ProjectGero checkout."
  [[ $(sha256sum "$archive" | awk '{print $1}') == "$FLEX_ARCHIVE_SHA256" ]] || die "Flex source archive checksum does not match the ProjectGero-pinned Flex 2.5.39 archive."
  printf '%s\n' "$archive"
}

prepare_flex() {
  flex_ready && { printf 'Reusing rebuilt Flex at %s.\n' "$(flex_bin)"; return; }
  local archive work source jobs old_count new_count flex
  archive=$(flex_archive)
  work=$(mktemp -d "${TMPDIR:-/tmp}/projectgero-flex.XXXXXX")
  tar -xzf "$archive" -C "$work"
  source="$work/flex-$FLEX_VERSION"
  [[ -d $source ]] || die "Unexpected Flex archive layout."
  old_count=$(grep -Fc 'lerrsf_fatal(_("Unable to allocate %ld of stack"),' "$source/scanflags.c" || true)
  new_count=$(grep -Fc 'lerrif(_("Unable to allocate %d of stack"),' "$source/scanflags.c" || true)
  if [[ $old_count == 1 && $new_count == 0 ]]; then
    sed -i 's/lerrsf_fatal(_("Unable to allocate %ld of stack"),/lerrif(_("Unable to allocate %d of stack"),/' "$source/scanflags.c"
    sed -i 's/(long)sizeof(scanflags_t))/(int)sizeof(scanflags_t))/' "$source/scanflags.c"
  elif [[ $old_count != 0 || $new_count != 1 ]]; then
    die "Flex scanflags.c did not contain exactly one supported compatibility form."
  fi
  [[ $(grep -Fc 'lerrif(_("Unable to allocate %d of stack"),' "$source/scanflags.c" || true) == 1 ]] || die "Flex compatibility patch did not apply exactly once."
  jobs=$(nproc)
  (cd "$source" && ./configure && make -C lib libcompat.la && make -j"$jobs" flex)
  flex="$source/flex"
  "$flex" --version | grep -Eq "flex[[:space:]]+$FLEX_VERSION" || die "Rebuilt Flex did not report $FLEX_VERSION."
  mkdir -p "$PROJECTGERO_TOOLS_DIR/flex/bin"
  install -m 0755 "$flex" "$(flex_bin)"
  sha256sum "$(flex_bin)" > "$PROJECTGERO_TOOLS_DIR/flex/flex-2.5.39.sha256"
  printf 'Prepared Flex %s (%s)\n' "$FLEX_VERSION" "$(sha256sum "$(flex_bin)" | awk '{print $1}')"
}

override_state_file() {
  local root=$1 key
  key=$(printf '%s' "$root" | sha256sum | awk '{print $1}')
  printf '%s/flex/overrides/%s.env\n' "$PROJECTGERO_TOOLS_DIR" "$key"
}

apply_flex_override() {
  local root=$1 target repo original_sha original_mode replacement_sha state
  root=$(cd "$root" && pwd)
  target="$root/prebuilts/misc/linux-x86/flex/flex-2.5.39"
  repo="$root/prebuilts/misc"
  [[ -d "$repo/.git" || -f "$repo/.git" ]] || die "Expected prebuilts/misc Git component is missing."
  git -C "$repo" ls-files --error-unmatch linux-x86/flex/flex-2.5.39 >/dev/null || die "Flex runtime target is not tracked."
  [[ -f $target ]] || die "Expected tracked Flex runtime target is missing."
  git -C "$repo" diff --quiet -- linux-x86/flex/flex-2.5.39 || die "Flex runtime target is already modified; refusing to overwrite an unrecorded change."
  flex_ready || die "Rebuilt Flex is not ready; run --install or --prepare-flex first."
  original_sha=$(sha256sum "$target" | awk '{print $1}')
  original_mode=$(stat -c '%a' "$target")
  replacement_sha=$(sha256sum "$(flex_bin)" | awk '{print $1}')
  state=$(override_state_file "$root")
  mkdir -p "$(dirname "$state")"
  if [[ -e $state ]]; then die "A recorded Flex override already exists for this checkout; restore it first."; fi
  printf '%s\n%s\n%s\n%s\n' "$original_sha" "$original_mode" "$replacement_sha" "$target" > "$state"
  install -m "$original_mode" "$(flex_bin)" "$target"
  [[ $(sha256sum "$target" | awk '{print $1}') == "$replacement_sha" ]] || die "Flex override copy verification failed."
  printf 'BUILD_TOOL_RUNTIME_OVERRIDE APPLIED: %s\n' "$target"
}

restore_flex_override() {
  local root=$1 target repo state expected_sha original_sha recorded_mode recorded_target
  root=$(cd "$root" && pwd)
  target="$root/prebuilts/misc/linux-x86/flex/flex-2.5.39"
  repo="$root/prebuilts/misc"
  state=$(override_state_file "$root")
  [[ -f $state ]] || die "No recorded ProjectGero Flex override exists for this checkout; refusing to touch the file."
  {
    IFS= read -r original_sha
    IFS= read -r recorded_mode
    IFS= read -r expected_sha
    IFS= read -r recorded_target
  } < "$state"
  [[ $original_sha =~ ^[0-9a-f]{64}$ && $expected_sha =~ ^[0-9a-f]{64}$ && $recorded_mode =~ ^[0-7]{3,4}$ ]] || die "Invalid override state; refusing to touch the file."
  [[ $recorded_target == "$target" ]] || die "Override state target does not match this checkout."
  [[ $(sha256sum "$target" | awk '{print $1}') == "$expected_sha" ]] || die "Flex target differs from the recorded override; refusing to overwrite unrelated changes."
  git -C "$repo" checkout -- linux-x86/flex/flex-2.5.39
  [[ $(sha256sum "$target" | awk '{print $1}') == "$original_sha" ]] || die "Git restoration hash did not match recorded original."
  rm -f "$state"
  printf 'BUILD_TOOL_RUNTIME_OVERRIDE RESTORED: %s\n' "$target"
}

main() {
  while (($#)); do
    case $1 in
      --check|--install|--verify|--prepare-flex)
        [[ -z $MODE ]] || die "Select exactly one primary mode."
        MODE=$1 ;;
      --projectgero-root)
        shift; (($#)) || die "--projectgero-root requires a path."; PROJECTGERO_ROOT=$1 ;;
      --apply-flex-override|--restore-flex)
        [[ -z $MODE ]] || die "Select exactly one primary mode."
        MODE=$1; shift; (($#)) || die "$MODE requires a ProjectGero root."; OVERRIDE_ROOT=$1 ;;
      --help|-h) usage; return 0 ;;
      *) die "Unknown argument: $1" ;;
    esac
    shift
  done
  [[ -n $MODE ]] || { usage; return 2; }
  infer_root
  case $MODE in
    --check|--verify)
      verify_host_basics
      verify_project_source
      ;;
    --install)
      install_packages
      git lfs install
      install_python_modules
      prepare_flex
      verify_host_basics
      verify_project_source
      ;;
    --prepare-flex)
      require_supported_host
      prepare_flex
      ;;
    --apply-flex-override)
      apply_flex_override "$OVERRIDE_ROOT"
      ;;
    --restore-flex)
      restore_flex_override "$OVERRIDE_ROOT"
      ;;
  esac
  if [[ $MODE == --check || $MODE == --verify || $MODE == --install ]]; then
    if ((MISSING_COUNT == 0)); then
      printf '\nPROJECTGERO DB410C HOST: READY\n'
    else
      printf '\nPROJECTGERO DB410C HOST: MISSING REQUIREMENTS (%s)\n' "$MISSING_COUNT"
      [[ $MODE == --check ]] || exit 1
    fi
  fi
}

main "$@"
