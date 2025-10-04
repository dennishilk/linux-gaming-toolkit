#!/bin/bash
# ==============================
#  Linux Gaming Toolkit v3
#  by Dennis Hilk
#  Debian | Ubuntu | Mint | Arch
#  Nerd Edition 🕹️🐧
# ==============================

set -u  # be strict about unbound vars

# ============ GLOBALS ============
LOGFILE="/var/log/linux-gaming-toolkit.log"
DISTRO=""          # will be set: arch | debian | ubuntu
PKG=""             # package install cmd for current distro
YAY_OK=1           # 1 if yay usable
AUR="yay -S --noconfirm"
FLATPAK_REMOTE="https://flathub.org/repo/flathub.flatpakrepo"

# ============ HELPERS ============
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (sudo)."; exit 1
  fi
}

log()       { echo -e "$(date '+%F %T') | $*" | tee -a "$LOGFILE"; }
success()   { log "✅ $*"; }
failure()   { log "❌ $*"; }
run_cmd() {  # run_cmd "Description" cmd...
  local desc="$1"; shift
  log "▶ $desc"
  if "$@" >>"$LOGFILE" 2>&1; then success "$desc"; return 0; else failure "$desc"; return 1; fi
}

ensure_cmd() { # ensure_cmd <binary> <pkg-name>
  command -v "$1" &>/dev/null || run_cmd "Install $2" $PKG "$2"
}

pkg_exists_apt()    { apt-cache show "$1" >/dev/null 2>&1; }
pkg_exists_pacman() { pacman -Si "$1"     >/dev/null 2>&1; }

# Robust distro detection
detect_distro() {
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
  else
    echo "⚠️ /etc/os-release not found. Unsupported system."; exit 1
  fi

  local _id="${ID:-}" _like="${ID_LIKE:-}" blob="$_id $_like"

  if [[ "$blob" == *"arch"* ]]; then
    DISTRO="arch";   PKG="pacman -S --noconfirm --needed"
  elif [[ "$blob" == *"debian"* || "$_id" == "debian" ]]; then
    DISTRO="debian"; PKG="apt install -y"
  elif [[ "$_id" == "ubuntu" || "$_id" == "linuxmint" || "$blob" == *"ubuntu"* ]]; then
    DISTRO="ubuntu"; PKG="apt install -y"
  else
    echo "⚠️ Unsupported distribution (ID='$_id', LIKE='$_like')."; exit 1
  fi

  log "Detected distro: $DISTRO"
}

# Debian/Ubuntu: enable 32-bit libs
enable_i386() {
  if [[ "$DISTRO" == "debian" || "$DISTRO" == "ubuntu" ]]; then
    if ! dpkg --print-foreign-architectures | grep -qw i386; then
      run_cmd "Enable i386 multiarch" dpkg --add-architecture i386
    fi
    run_cmd "apt update" apt update
  fi
}

# Debian: enable contrib/non-free
enable_debian_components() {
  local changed=0
  local files=(/etc/apt/sources.list /etc/apt/sources.list.d/*.list)
  for f in "${files[@]}"; do
    [ -f "$f" ] || continue
    if grep -Eq '^[[:space:]]*deb[[:space:]].*\bmain\b' "$f" && \
       ! grep -Eq '^[[:space:]]*deb[[:space:]].*\bcontrib\b' "$f"; then
      run_cmd "Enable contrib/non-free in $f" \
        sed -E -i 's/^( *deb +[^#]*\bmain\b)(.*)$/\1 contrib non-free non-free-firmware\2/' "$f"
      changed=1
    fi
  done
  [ "$changed" -eq 1 ] && run_cmd "apt update" apt update
}

# Ubuntu: restricted/universe/multiverse
enable_ubuntu_components() {
  ensure_cmd add-apt-repository software-properties-common
  run_cmd "Enable restricted"  add-apt-repository -y restricted
  run_cmd "Enable universe"    add-apt-repository -y universe
  run_cmd "Enable multiverse"  add-apt-repository -y multiverse
  run_cmd "apt update" apt update
}

# Arch: multilib
enable_arch_multilib() {
  if ! grep -Eq '^\[multilib\]' /etc/pacman.conf; then
    echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
  else
    sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
  fi
  run_cmd "Refresh pacman DB" pacman -Sy
}

# Arch: yay
ensure_yay() {
  if ! command -v yay &>/dev/null; then
    if pacman -Si yay &>/dev/null; then
      run_cmd "Install yay" pacman -S --noconfirm --needed yay || YAY_OK=0
    else
      YAY_OK=0
    fi
  fi
}

# Prompt: Flatpak vs Native
ask_flatpak_or_native() { whiptail --title "Install $1" --yesno "Install $1 as Flatpak?\nYes=Flatpak, No=Native" 10 60; }

# ============ PRE-FLIGHT ============
pre_checks() {
  log "Running pre-installation checks..."
  touch "$LOGFILE" || { echo "Cannot write log: $LOGFILE"; exit 1; }

  if [[ "$DISTRO" == "arch" ]]; then
    run_cmd "pacman -Sy" pacman -Sy --noconfirm
    enable_arch_multilib
    ensure_cmd whiptail libnewt
    ensure_cmd flatpak flatpak
    ensure_yay
  else
    run_cmd "apt update" apt update
    [[ "$DISTRO" == "debian" ]] && enable_debian_components
    [[ "$DISTRO" == "ubuntu" ]] && enable_ubuntu_components
    ensure_cmd whiptail whiptail
    ensure_cmd flatpak flatpak
    run_cmd "Install wget/ca-certificates" apt install -y wget ca-certificates
  fi
  run_cmd "Add Flathub" flatpak remote-add --if-not-exists flathub "$FLATPAK_REMOTE"
  success "Pre-flight checks complete."
}

# ============ UI ============
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

# ============ ACTIONS ============
detect_gpu() {
  ensure_cmd lspci pciutils
  if lspci | grep -i nvidia >/dev/null; then log "✅ NVIDIA GPU detected";
  elif lspci | grep -i amd   >/dev/null; then log "✅ AMD GPU detected";
  elif lspci | grep -i intel >/dev/null; then log "✅ Intel GPU detected";
  else log "⚠️ No supported GPU found"; fi
}

install_update() {
  [[ "$DISTRO" == "arch" ]] && run_cmd "System update" pacman -Syu --noconfirm || run_cmd "System update" bash -c "apt update && apt upgrade -y"
}

install_nvidia() {
  if [[ "$DISTRO" == "arch" ]]; then
    run_cmd "Install NVIDIA (Arch)" $PKG nvidia nvidia-utils lib32-nvidia-utils
  else
    if command -v ubuntu-drivers &>/dev/null; then
      run_cmd "Install ubuntu-drivers-common" apt install -y ubuntu-drivers-common
      run_cmd "ubuntu-drivers autoinstall" ubuntu-drivers autoinstall
    else
      run_cmd "Install NVIDIA (Debian)" $PKG nvidia-driver firmware-misc-nonfree
    fi
  fi
}

install_amd() {
  [[ "$DISTRO" == "arch" ]] && run_cmd "Install AMD Vulkan (Arch)" $PKG mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon mesa-demos vulkan-tools || { enable_i386; run_cmd "Install AMD Vulkan (Deb/Ubuntu)" $PKG mesa-vulkan-drivers mesa-vulkan-drivers:i386 mesa-utils vulkan-tools; }
}

install_steam() {
  [[ "$DISTRO" == "arch" ]] && run_cmd "Install Steam (Arch)" $PKG steam || { enable_i386; run_cmd "Install Steam (Deb/Ubuntu)" $PKG steam; }
}

install_lutris() {
  if ask_flatpak_or_native "Lutris"; then
    run_cmd "Install Lutris (Flatpak)" flatpak install -y flathub net.lutris.Lutris
  else
    [[ "$DISTRO" == "arch" ]] && run_cmd "Install Lutris (Arch)" $PKG lutris || run_cmd "Install Lutris (APT)" $PKG lutris
  fi
}

install_wine() {
  [[ "$DISTRO" == "arch" ]] && run_cmd "Install Wine (Arch)" $PKG wine-staging winetricks || { enable_i386; run_cmd "Install WineHQ (Deb/Ubuntu)" $PKG winehq-staging; }
}

install_gamemode() { run_cmd "Install Gamemode + MangoHud" $PKG gamemode mangohud; }
install_heroic()   { run_cmd "Install Heroic (Flatpak)" flatpak install -y flathub com.heroicgameslauncher.hgl; }
install_itch()     { run_cmd "Install itch.io (Flatpak)" flatpak install -y flathub io.itch.itch; }

install_obs() {
  if ask_flatpak_or_native "OBS Studio"; then
    run_cmd "Install OBS (Flatpak)" flatpak install -y flathub com.obsproject.Studio
  else
    run_cmd "Install OBS (Native)" $PKG obs-studio
  fi
}

install_chat() {
  run_cmd "Install Discord (Flatpak)" flatpak install -y flathub com.discordapp.Discord
  run_cmd "Install TeamSpeak (Flatpak)" flatpak install -y flathub com.teamspeak.TeamSpeak
}

install_benchmarks() {
  [[ "$DISTRO" == "arch" ]] && run_cmd "Install Benchmarks (Arch)" $PKG vulkan-tools mesa-demos glmark2 || run_cmd "Install Benchmarks (Deb/Ubuntu)" $PKG glmark2 vulkan-tools mesa-utils
}

install_dxvk_vkd3d() {
  [[ "$DISTRO" == "arch" ]] && run_cmd "Install DXVK + VKD3D (Arch)" $PKG dxvk vkd3d-proton || run_cmd "Install DXVK + VKD3D (Deb/Ubuntu)" $PKG dxvk vkd3d-proton
}

install_kernel() {
  if [[ "$DISTRO" == "arch" ]]; then
    whiptail --title "Gaming Kernel" --yesno "Install linux-zen kernel (Arch)?" 10 60 && run_cmd "Install linux-zen" $PKG linux-zen linux-zen-headers
  else
    whiptail --title "Gaming Kernel" --yesno "Install linux-lowlatency kernel (Ubuntu/Mint)?" 10 60 && run_cmd "Install linux-lowlatency" apt install -y linux-lowlatency
  fi
}

install_all() {
  install_update; detect_gpu; install_nvidia; install_amd; install_steam; install_lutris; install_wine; install_gamemode; install_heroic; install_itch; install_obs; install_chat; install_benchmarks; install_dxvk_vkd3d
  whiptail --msgbox "🎉 All main components installed. Consider installing the Gaming Kernel next!" 10 60
}

cleanup_all() {
  log "🧹 Removing gaming packages..."
  if [[ "$DISTRO" == "arch" ]]; then
    run_cmd "Remove Arch packages" pacman -Rns --noconfirm steam lutris wine-staging winetricks gamemode mangohud lib32-mangohud obs-studio discord teamspeak3 vulkan-tools mesa-demos glmark2 || true
  else
    run_cmd "Remove Deb/Ubuntu packages" apt purge -y steam lutris winehq-staging gamemode mangohud obs-studio teamspeak3-client glmark2 vulkan-tools mesa-utils discord || true
  fi
  run_cmd "Remove Flatpaks" flatpak uninstall -y --delete-data com.heroicgameslauncher.hgl io.itch.itch com.obsproject.Studio com.discordapp.Discord com.teamspeak.TeamSpeak net.lutris.Lutris || true
  log "🧹 Cleanup done."
}

# ============ MENU ============
main_menu() {
  while true; do
    CHOICE=$(whiptail --title "Linux Gaming Toolkit v3" --menu "Pick your poison 🕹️" 27 78 18 \
      "1"  "Install ALL (One-Click Gaming Overlord)" \
      "2"  "System Update & Upgrade" \
      "3"  "Detect GPU" \
      "4"  "Install NVIDIA Drivers" \
      "5"  "Install AMD Drivers" \
      "6"  "Install Steam + Proton" \
      "7"  "Install Lutris" \
      "8"  "Install WineHQ (staging)" \
      "9"  "Install Gamemode + MangoHud" \
      "10" "Install Heroic Games Launcher" \
      "11" "Install itch.io Client" \
      "12" "Install OBS Studio" \
      "13" "Install Discord + TeamSpeak" \
      "14" "Install Benchmark Tools" \
      "15" "Install DXVK + VKD3D-Proton" \
      "16" "Install Gaming Kernel" \
      "17" "Cleanup: remove gaming packages" \
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
      15) install_dxvk_vkd3d ;;
      16) install_kernel ;;
      17) cleanup_all ;;
      18) exit 0 ;;
    esac
  done
}

# ============ RUN ============
check_root
detect_distro
pre_checks
show_banner
main_menu
