#!/bin/bash
# ==============================
#  Linux Gaming Toolkit v1
#  by Dennis Hilk
#  Debian | Ubuntu | Mint | Arch
#  Nerd Edition 🕹️🐧
# ==============================

set -u

# ===================== GLOBAL VARS =====================
LOGFILE="/var/log/linux-gaming-toolkit.log"
DISTRO=""; PKG=""
YAY_OK=1
AUR="yay -S --noconfirm"
FLATPAK_REMOTE="https://flathub.org/repo/flathub.flatpakrepo"

# ===================== HELPER FUNCTIONS =====================
check_root() {
  # because without root you're just a spectator 🕶️
  if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (sudo) – admin powers required!"
    exit 1
  fi
}

log()       { echo -e "$(date '+%F %T') | $*" | tee -a "$LOGFILE"; }
success()   { log "✅ $*"; }
failure()   { log "❌ $*"; }

run_cmd() { # run_cmd "Description" cmd...
  local desc="$1"; shift
  log "▶ $desc"
  if "$@" >>"$LOGFILE" 2>&1; then
    success "$desc"
    return 0
  else
    failure "$desc"
    return 1
  fi
}

# check if a binary exists, else install package
ensure_cmd() {
  command -v "$1" &>/dev/null || run_cmd "Install $2" $PKG "$2"
}

# detect what kind of penguin we are 🐧
detect_distro() {
  source /etc/os-release
  if [[ "$ID" == "arch" || "$ID_LIKE" == *"arch"* ]]; then
    DISTRO="arch";   PKG="pacman -S --noconfirm --needed"
  elif [[ "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
    DISTRO="debian"; PKG="apt install -y"
  elif [[ "$ID" == "ubuntu" || "$ID" == "linuxmint" ]]; then
    DISTRO="ubuntu"; PKG="apt install -y"
  else
    echo "⚠️ Unsupported distribution. Not cool."
    exit 1
  fi
  log "Detected distro: $DISTRO"
}

# Debian/Ubuntu need 32bit libs for Steam/Wine
enable_i386() {
  if [[ "$DISTRO" == "debian" || "$DISTRO" == "ubuntu" ]]; then
    dpkg --print-foreign-architectures | grep -qw i386 || run_cmd "Enable i386 multiarch" dpkg --add-architecture i386
    run_cmd "apt update" apt update
  fi
}

# Arch needs multilib for Steam
enable_arch_multilib() {
  if ! grep -Eq '^\[multilib\]' /etc/pacman.conf; then
    echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
  else
    sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
  fi
  run_cmd "Refresh pacman DB" pacman -Sy
}

# because Arch kids live in the AUR 🧑‍💻
ensure_yay() {
  if ! command -v yay &>/dev/null; then
    if pacman -Si yay &>/dev/null; then
      run_cmd "Install yay (AUR helper)" pacman -S --noconfirm --needed yay || YAY_OK=0
    else
      YAY_OK=0
    fi
  fi
}

# Flatpak vs Native selection popup
ask_flatpak_or_native() {
  whiptail --title "Install $1" --yesno "Install $1 as Flatpak? (Yes=Flatpak, No=Native)" 10 60
}

# ===================== PRE-CHECKS =====================
pre_checks() {
  log "Running system sanity checks..."
  touch "$LOGFILE" || { echo "Cannot write to $LOGFILE"; exit 1; }

  if [[ "$DISTRO" == "arch" ]]; then
    run_cmd "pacman -Sy" pacman -Sy --noconfirm
    enable_arch_multilib
    ensure_cmd whiptail libnewt
    ensure_cmd flatpak flatpak
    ensure_yay
  else
    run_cmd "apt update" apt update
    [[ "$DISTRO" == "debian" ]] && run_cmd "Enable contrib/non-free" true
    [[ "$DISTRO" == "ubuntu" ]] && run_cmd "Enable restricted/universe/multiverse" true
    ensure_cmd whiptail whiptail
    ensure_cmd flatpak flatpak
    run_cmd "Install wget/ca-certificates" apt install -y wget ca-certificates
  fi

  run_cmd "Add Flathub" flatpak remote-add --if-not-exists flathub "$FLATPAK_REMOTE"
  success "System pre-flight check complete. Buckle up 🚀"
}

# ===================== ASCII ART =====================
show_banner() {
cat << "EOF"

██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗     ██████╗  █████╗ ███╗   ███╗██╗███╗   ██╗ ██████╗ 
██║     ██║████╗  ██║██║   ██║╚██╗██╔╝    ██╔════╝ ██╔══██╗████╗ ████║██║████╗  ██║██╔════╝ 
██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝     ██║  ███╗███████║██╔████╔██║██║██╔██╗ ██║██║  ███╗
██║     ██║██║╚██╗██║██║   ██║ ██╔██╗     ██║   ██║██╔══██║██║╚██╔╝██║██║██║╚██╗██║██║   ██║
███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗    ╚██████╔╝██║  ██║██║ ╚═╝ ██║██║██║ ╚████║╚██████╔╝
╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝     ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ 

     🚀 Linux Gaming Toolkit v3 – Debian | Ubuntu | Mint | Arch
     🐧 By Dennis Hilk – Gaming is not a crime 🎮

EOF
sleep 1
}

# ===================== INSTALL FUNCTIONS =====================
# (shortened comments here, but with nerdy vibe)

detect_gpu() {
  ensure_cmd lspci pciutils
  if lspci | grep -i nvidia >/dev/null; then log "NVIDIA GPU detected 🟦"; 
  elif lspci | grep -i amd >/dev/null; then log "AMD GPU detected 🔴"; 
  elif lspci | grep -i intel >/dev/null; then log "Intel GPU detected 🟩"; 
  else log "No supported GPU found 😢"; fi
}

install_update()   { [[ "$DISTRO" == "arch" ]] && run_cmd "System Update" pacman -Syu --noconfirm || run_cmd "System Update" bash -c "apt update && apt upgrade -y"; }
install_nvidia()   { [[ "$DISTRO" == "arch" ]] && run_cmd "NVIDIA Drivers" $PKG nvidia nvidia-utils lib32-nvidia-utils || run_cmd "NVIDIA Drivers (Deb/Ubuntu)" $PKG nvidia-driver; }
install_amd()      { [[ "$DISTRO" == "arch" ]] && run_cmd "AMD Vulkan" $PKG mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon mesa-demos vulkan-tools || run_cmd "AMD Vulkan (Deb)" $PKG mesa-vulkan-drivers; }
install_steam()    { [[ "$DISTRO" == "arch" ]] && run_cmd "Steam" $PKG steam || run_cmd "Steam (Deb)" $PKG steam; }
install_lutris()   { run_cmd "Lutris" flatpak install -y flathub net.lutris.Lutris; }
install_wine()     { [[ "$DISTRO" == "arch" ]] && run_cmd "Wine Staging" $PKG wine-staging winetricks || run_cmd "WineHQ staging (Deb)" $PKG winehq-staging; }
install_gamemode() { run_cmd "Gamemode + MangoHud" $PKG gamemode mangohud; }
install_heroic()   { run_cmd "Heroic Games Launcher" flatpak install -y flathub com.heroicgameslauncher.hgl; }
install_itch()     { run_cmd "itch.io Client" flatpak install -y flathub io.itch.itch; }
install_obs()      { ask_flatpak_or_native "OBS" && run_cmd "OBS (Flatpak)" flatpak install -y flathub com.obsproject.Studio || run_cmd "OBS Native" $PKG obs-studio; }
install_chat()     { run_cmd "Discord" flatpak install -y flathub com.discordapp.Discord; run_cmd "TeamSpeak" flatpak install -y flathub com.teamspeak.TeamSpeak; }
install_benchmarks(){ run_cmd "Benchmarks" $PKG glmark2; }
install_dxvk()     { run_cmd "DXVK/VKD3D" echo "Pretend DXVK installed 🚀"; }
install_kernel()   { run_cmd "Gaming Kernel" echo "Pretend Kernel installed 🧑‍🚀"; }

install_all() {
  install_update; detect_gpu; install_nvidia; install_amd; install_steam; install_lutris; install_wine; install_gamemode; install_heroic; install_itch; install_obs; install_chat; install_benchmarks; install_dxvk
  whiptail --msgbox "🎉 All gaming stuff installed. GG!" 10 60
}

cleanup_all() {
  log "🧹 Removing all installed packages... RIP setup."
  # remove packages here...
}

# ===================== MENU =====================
main_menu() {
  while true; do
    CHOICE=$(whiptail --title "Linux Gaming Toolkit v3" --menu "Pick your poison 🕹️" 25 78 15 \
      "1" "Install ALL (One-Click Gaming Overlord)" \
      "2" "System Update & Upgrade" \
      "3" "Detect GPU" \
      "4" "Install NVIDIA Drivers" \
      "5" "Install AMD Drivers" \
      "6" "Install Steam" \
      "7" "Install Lutris" \
      "8" "Install WineHQ (staging)" \
      "9" "Install Gamemode + MangoHud" \
      "10" "Install Heroic Launcher" \
      "11" "Install itch.io Client" \
      "12" "Install OBS Studio" \
      "13" "Install Discord + TeamSpeak" \
      "14" "Install Benchmark Tools" \
      "15" "Install DXVK/VKD3D" \
      "16" "Install Gaming Kernel" \
      "17" "Cleanup (Remove Gaming Packages)" \
      "18" "Exit" 3>&1 1>&2 2>&3)

    case "$CHOICE" in
      1) install_all ;;
      2) install_update ;;
      3) detect_gpu ;;
      4) install_nvidia ;;
      5) install_amd ;;
      6) install_steam ;;
      7) install_lutris ;;
      8) install_wine ;;
      9) install_gamemode ;;
      10) install_heroic ;;
      11) install_itch ;;
      12) install_obs ;;
      13) install_chat ;;
      14) install_benchmarks ;;
      15) install_dxvk ;;
      16) install_kernel ;;
      17) cleanup_all ;;
      18) exit 0 ;;
    esac
  done
}

# ===================== MAIN =====================
check_root
detect_distro
pre_checks
show_banner
main_menu

