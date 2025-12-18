#!/usr/bin/env bash
# ==========================================================
#  Linux Gaming Toolkit v4
#  by Dennis Hilk
#  Debian | Ubuntu | Mint | Arch
# ==========================================================

set -Eeuo pipefail
trap 'echo "❌ Error on line $LINENO. See log for details."' ERR

# ================= GLOBALS =================
readonly FLATPAK_REMOTE="https://flathub.org/repo/flathub.flatpakrepo"
LOGFILE="/var/log/linux-gaming-toolkit.log"
DISTRO=""
PKG=""
AUR="yay -S --noconfirm"
YAY_OK=1
GPU_VENDOR="unknown"

# ================= LOGGING =================
init_log() {
  if ! touch "$LOGFILE" &>/dev/null; then
    LOGFILE="/tmp/linux-gaming-toolkit.log"
    touch "$LOGFILE"
  fi
}

log()     { echo -e "$(date '+%F %T') | $*" | tee -a "$LOGFILE" >/dev/null; }
success() { log "✅ $*"; }
failure() { log "❌ $*"; }

run_cmd() {
  local desc="$1"; shift
  log "▶ $desc"
  set -o pipefail
  ( "$@" 2>&1 | tee -a "$LOGFILE" )
  local rc=${PIPESTATUS[0]}
  set +o pipefail
  (( rc == 0 )) && success "$desc" || failure "$desc"
  return $rc
}

# ================= PRECHECK =================
check_root() {
  [[ "${EUID:-999}" -eq 0 ]] || { echo "❌ Run as root (sudo)."; exit 1; }
}

# ================= DISTRO ==================
read_os_release() {
  source /etc/os-release || true
  ID="${ID:-}"; ID_LIKE="${ID_LIKE:-}"
  VERSION_CODENAME="${VERSION_CODENAME:-}"
  UBUNTU_CODENAME="${UBUNTU_CODENAME:-}"
}

detect_distro() {
  read_os_release
  local blob="${ID} ${ID_LIKE}"
  if [[ "$blob" == *arch* ]]; then
    DISTRO="arch"; PKG="pacman -S --noconfirm --needed"
  elif [[ "$blob" == *debian* ]]; then
    DISTRO="debian"; PKG="apt install -y"
  elif [[ "$blob" == *ubuntu* || "$ID" == "linuxmint" ]]; then
    DISTRO="ubuntu"; PKG="apt install -y"
  else
    echo "Unsupported distro."; exit 1
  fi
  log "Detected distro: $DISTRO"
}

# ================= GPU =====================
detect_gpu() {
  run_cmd "Detect GPU" lspci
  if lspci | grep -iq nvidia; then
    GPU_VENDOR="nvidia"
  elif lspci | grep -iq amd; then
    GPU_VENDOR="amd"
  elif lspci | grep -iq intel; then
    GPU_VENDOR="intel"
  fi
  log "GPU vendor: $GPU_VENDOR"
}

# ================= REPOS ===================
setup_repos() {
  if [[ "$DISTRO" == "arch" ]]; then
    run_cmd "pacman refresh" pacman -Sy --noconfirm
    grep -q "^\[multilib\]" /etc/pacman.conf || {
      echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
    }
    run_cmd "Enable multilib" pacman -Sy
    command -v yay &>/dev/null || YAY_OK=0
  else
    dpkg --add-architecture i386 || true
    run_cmd "apt update" apt update
    run_cmd "Install base deps" apt install -y wget ca-certificates whiptail flatpak
  fi
  run_cmd "Add Flathub" flatpak remote-add --if-not-exists flathub "$FLATPAK_REMOTE"
}

# ================= INSTALLS ================
install_gpu_drivers() {
  case "$GPU_VENDOR" in
    nvidia)
      [[ "$DISTRO" == "arch" ]] \
        && run_cmd "NVIDIA Arch" $PKG nvidia nvidia-utils lib32-nvidia-utils \
        || run_cmd "NVIDIA Deb/Ubuntu" $PKG nvidia-driver
      ;;
    amd)
      run_cmd "AMD Vulkan" $PKG mesa vulkan-tools mesa-demos
      ;;
    intel)
      run_cmd "Intel Vulkan" $PKG mesa-vulkan-drivers vulkan-tools
      ;;
    *)
      log "No GPU drivers installed."
      ;;
  esac
}

install_gaming_stack() {
  run_cmd "Steam" $PKG steam
  run_cmd "Gamemode + MangoHud" $PKG gamemode mangohud || true
  run_cmd "Heroic (Flatpak)" flatpak install -y flathub com.heroicgameslauncher.hgl
  run_cmd "OBS Studio" $PKG obs-studio || flatpak install -y flathub com.obsproject.Studio
}

install_benchmarks() {
  run_cmd "Benchmarks" $PKG glmark2 vulkan-tools mesa-utils
}

# ================= MENU ====================
main_menu() {
  while true; do
    CHOICE=$(whiptail --title "Linux Gaming Toolkit v4" --menu "Select action 🕹️" 22 72 10 \
      "1" "Install FULL Gaming Stack" \
      "2" "Detect GPU" \
      "3" "Install GPU Drivers" \
      "4" "Install Gaming Tools" \
      "5" "Install Benchmarks" \
      "6" "Exit" 3>&1 1>&2 2>&3)

    case "$CHOICE" in
      1) detect_gpu; install_gpu_drivers; install_gaming_stack; install_benchmarks ;;
      2) detect_gpu ;;
      3) detect_gpu; install_gpu_drivers ;;
      4) install_gaming_stack ;;
      5) install_benchmarks ;;
      6) exit 0 ;;
    esac
  done
}

# ================= RUN =====================
check_root
init_log
detect_distro
setup_repos
main_menu
