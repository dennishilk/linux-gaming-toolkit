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
DISTRO=""          # arch | debian | ubuntu
PKG=""             # package install command
YAY_OK=1
AUR="yay -S --noconfirm"
FLATPAK_REMOTE="https://flathub.org/repo/flathub.flatpakrepo"

# ============ HELPERS ============
check_root() {
  # without root, you're observing, not gaming
  if [ "${EUID:-999}" -ne 0 ]; then
    echo "❌ Please run as root (sudo)."; exit 1
  fi
}

log()     { echo -e "$(date '+%F %T') | $*" | tee -a "$LOGFILE" >/dev/null; }
success() { log "✅ $*"; }
failure() { log "❌ $*"; }

# Run a command with live console output AND logging.
# Captures the real exit code even with pipes.
run_cmd() {
  local desc="$1"; shift
  log "▶ $desc"
  set -o pipefail
  ( "$@" 2>&1 | tee -a "$LOGFILE" )
  local rc=${PIPESTATUS[0]}
  set +o pipefail
  if [ $rc -eq 0 ]; then success "$desc"; else failure "$desc"; fi
  return $rc
}

ensure_cmd() {  # ensure_cmd <binary> <pkg>
  command -v "$1" &>/dev/null || run_cmd "Install $2" $PKG "$2"
}

pkg_exists_apt()    { apt-cache show "$1" >/dev/null 2>&1; }
pkg_exists_pacman() { pacman -Si "$1"     >/dev/null 2>&1; }

# Safe read of /etc/os-release (no set -u explosions)
read_os_release() {
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
  else
    ID=""; ID_LIKE=""; VERSION_CODENAME=""; UBUNTU_CODENAME=""
  fi
  ID="${ID:-}"; ID_LIKE="${ID_LIKE:-}"
  VERSION_CODENAME="${VERSION_CODENAME:-}"; UBUNTU_CODENAME="${UBUNTU_CODENAME:-}"
}

detect_distro() {
  read_os_release
  local blob="${ID} ${ID_LIKE}"
  if [[ "$blob" == *"arch"* ]]; then
    DISTRO="arch";   PKG="pacman -S --noconfirm --needed"
  elif [[ "$blob" == *"debian"* || "$ID" == "debian" ]]; then
    DISTRO="debian"; PKG="apt install -y"
  elif [[ "$ID" == "ubuntu" || "$ID" == "linuxmint" || "$blob" == *"ubuntu"* ]]; then
    DISTRO="ubuntu"; PKG="apt install -y"
  else
    echo "⚠️ Unsupported distribution (ID='${ID}', LIKE='${ID_LIKE}')."; exit 1
  fi
  log "Detected distro: ${DISTRO}"
}

enable_i386() {
  if [[ "$DISTRO" == "debian" || "$DISTRO" == "ubuntu" ]]; then
    if ! dpkg --print-foreign-architectures | grep -qw i386; then
      run_cmd "Enable i386 multiarch" dpkg --add-architecture i386
    fi
    run_cmd "apt update" apt update -o Dpkg::Progress-Fancy=1
  fi
}

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
  [ "$changed" -eq 1 ] && run_cmd "apt update" apt update -o Dpkg::Progress-Fancy=1
}

enable_ubuntu_components() {
  ensure_cmd add-apt-repository software-properties-common
  run_cmd "Enable restricted"  add-apt-repository -y restricted
  run_cmd "Enable universe"    add-apt-repository -y universe
  run_cmd "Enable multiverse"  add-apt-repository -y multiverse
  run_cmd "apt update" apt update -o Dpkg::Progress-Fancy=1
}

enable_arch_multilib() {
  if ! grep -Eq '^\[multilib\]' /etc/pacman.conf; then
    echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
  else
    sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
  fi
  run_cmd "Refresh pacman DB" pacman -Sy
}

ensure_yay() {
  if ! command -v yay &>/dev/null; then
    if pacman -Si yay &>/dev/null; then
      run_cmd "Install yay (AUR helper)" pacman -S --noconfirm --needed yay || YAY_OK=0
    else
      YAY_OK=0
    fi
  fi
}

ask_flatpak_or_native() { whiptail --title "Install $1" --yesno "Install $1 as Flatpak?\nYes = Flatpak, No = Native" 10 64; }

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
    run_cmd "apt update" apt update -o Dpkg::Progress-Fancy=1
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
  if [[ "$DISTRO" == "arch" ]]; then
    run_cmd "System update" pacman -Syu --noconfirm
  else
    run_cmd "apt update"  apt update  -o Dpkg::Progress-Fancy=1
    run_cmd "apt upgrade" apt upgrade -y -o Dpkg::Progress-Fancy=1
  fi
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
  if [[ "$DISTRO" == "arch" ]]; then
    run_cmd "Install AMD Vulkan (Arch)" $PKG mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon mesa-demos vulkan-tools
  else
    enable_i386
    run_cmd "Install AMD Vulkan (Deb/Ubuntu)" $PKG mesa-vulkan-drivers mesa-vulkan-drivers:i386 mesa-utils vulkan-tools
  fi
}

install_steam() {
  if [[ "$DISTRO" == "arch" ]]; then
    run_cmd "Install Steam (Arch)" $PKG steam
  else
    enable_i386
    run_cmd "Install Steam (Deb/Ubuntu)" $PKG steam
  fi
}

install_lutris() {
  if ask_flatpak_or_native "Lutris"; then
    run_cmd "Install Lutris (Flatpak)" flatpak install -y flathub net.lutris.Lutris
  else
    if [[ "$DISTRO" == "arch" ]]; then
      run_cmd "Install Lutris (Arch)" $PKG lutris || { [[ $YAY_OK -eq 1 ]] && run_cmd "Install Lutris (AUR)" $AUR lutris || run_cmd "Install Lutris (Flatpak fallback)" flatpak install -y flathub net.lutris.Lutris; }
    else
      run_cmd "Install Lutris (APT)" $PKG lutris || run_cmd "Install Lutris (Flatpak fallback)" flatpak install -y flathub net.lutris.Lutris
    fi
  fi
}

install_wine() {
  if [[ "$DISTRO" == "arch" ]]; then
    run_cmd "Install Wine (Arch)" $PKG wine-staging winetricks
  else
    enable_i386
    read_os_release
    local codename=""
    if [[ "${ID}" == "debian" ]]; then
      codename="${VERSION_CODENAME}"
      run_cmd "Add WineHQ key" wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
      run_cmd "Add WineHQ source (Debian)" wget -qNP /etc/apt/sources.list.d/ "https://dl.winehq.org/wine-builds/debian/dists/${codename}/winehq-${codename}.sources" || true
    else
      codename="${UBUNTU_CODENAME}"
      if [ -z "$codename" ] && command -v lsb_release &>/dev/null; then codename="$(lsb_release -sc)"; fi
      run_cmd "Add WineHQ key" wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
      run_cmd "Add WineHQ source (Ubuntu/Mint)" wget -qNP /etc/apt/sources.list.d/ "https://dl.winehq.org/wine-builds/ubuntu/dists/${codename}/winehq-${codename}.sources" || true
    fi
    run_cmd "apt update" apt update -o Dpkg::Progress-Fancy=1
    run_cmd "Install WineHQ (staging)" $PKG --install-recommends winehq-staging || \
    run_cmd "Install distro wine (fallback)" $PKG wine-staging || \
    run_cmd "Install wine (fallback2)" $PKG wine
  fi
}

install_gamemode() {
  if [[ "$DISTRO" == "arch" ]]; then
    run_cmd "Install Gamemode + MangoHud (Arch)" $PKG gamemode mangohud lib32-mangohud
  else
    run_cmd "Install Gamemode + MangoHud (Deb/Ubuntu)" $PKG gamemode mangohud
  fi
}

install_heroic() {
  if [[ "$DISTRO" == "arch" ]]; then
    if [[ $YAY_OK -eq 1 ]]; then
      run_cmd "Install Heroic (AUR)" $AUR heroic-games-launcher-bin
    else
      run_cmd "Install Heroic (Flatpak)" flatpak install -y flathub com.heroicgameslauncher.hgl
    fi
  else
    run_cmd "Install Heroic (Flatpak)" flatpak install -y flathub com.heroicgameslauncher.hgl
  fi
}

install_itch() { run_cmd "Install itch.io (Flatpak)" flatpak install -y flathub io.itch.itch; }

install_obs() {
  if ask_flatpak_or_native "OBS Studio"; then
    run_cmd "Install OBS (Flatpak)" flatpak install -y flathub com.obsproject.Studio
  else
    if [[ "$DISTRO" == "arch" ]]; then
      run_cmd "Install OBS (Arch)" $PKG obs-studio
    else
      run_cmd "Install OBS (APT)" $PKG obs-studio || run_cmd "OBS Flatpak fallback" flatpak install -y flathub com.obsproject.Studio
    fi
  fi
}

install_chat() {
  if ask_flatpak_or_native "Discord"; then
    run_cmd "Install Discord (Flatpak)" flatpak install -y flathub com.discordapp.Discord
  else
    if [[ "$DISTRO" == "arch" ]]; then
      run_cmd "Install Discord (Arch)" $PKG discord || { [[ $YAY_OK -eq 1 ]] && run_cmd "Install Discord (AUR)" $AUR discord || run_cmd "Discord Flatpak fallback" flatpak install -y flathub com.discordapp.Discord; }
    else
      run_cmd "Install Discord (APT)" $PKG discord || run_cmd "Discord Flatpak fallback" flatpak install -y flathub com.discordapp.Discord
    fi
  fi
  if [[ "$DISTRO" == "arch" ]]; then
    run_cmd "Install TeamSpeak (Arch)" $PKG teamspeak3 || { [[ $YAY_OK -eq 1 ]] && run_cmd "Install TeamSpeak (AUR)" $AUR teamspeak3 || run_cmd "TeamSpeak (Flatpak)" flatpak install -y flathub com.teamspeak.TeamSpeak; }
  else
    run_cmd "Install TeamSpeak (APT)" $PKG teamspeak3-client || run_cmd "TeamSpeak (Flatpak)" flatpak install -y flathub com.teamspeak.TeamSpeak
  fi
}

install_benchmarks() {
  if [[ "$DISTRO" == "arch" ]]; then
    run_cmd "Install Benchmarks (Arch)" $PKG vulkan-tools mesa-demos glmark2
    [[ $YAY_OK -eq 1 ]] && whiptail --title "Optional" --yesno "Install Unigine Heaven (AUR)?" 10 60 && run_cmd "Install Unigine Heaven (AUR)" $AUR unigine-heaven
  else
    run_cmd "Install Benchmarks (Deb/Ubuntu)" $PKG glmark2 vulkan-tools mesa-utils
  fi
}

install_dxvk_vkd3d() {
  if [[ "$DISTRO" == "arch" ]]; then
    if pkg_exists_pacman dxvk; then run_cmd "Install DXVK (Arch)" pacman -S --noconfirm --needed dxvk
    elif [[ $YAY_OK -eq 1 ]]; then run_cmd "Install DXVK (AUR bin)" $AUR dxvk-bin; else success "DXVK via Proton/Lutris."; fi
    if pkg_exists_pacman vkd3d-proton; then run_cmd "Install VKD3D-Proton (Arch)" pacman -S --noconfirm --needed vkd3d-proton; else success "VKD3D via Proton."; fi
  else
    if pkg_exists_apt dxvk; then run_cmd "Install DXVK (APT)" apt install -y dxvk; else success "DXVK via Proton/Lutris."; fi
    if pkg_exists_apt vkd3d-proton; then run_cmd "Install VKD3D-Proton (APT)" apt install -y vkd3d-proton; else success "VKD3D via Proton."; fi
  fi
}

install_kernel() {
  if [[ "$DISTRO" == "arch" ]]; then
    whiptail --title "Gaming Kernel" --yesno "Install linux-zen kernel (Arch)?" 10 60 && run_cmd "Install linux-zen" $PKG linux-zen linux-zen-headers && log "ℹ️ Reboot to use linux-zen."
  else
    whiptail --title "Gaming Kernel" --yesno "Install linux-lowlatency kernel (Ubuntu/Mint)?" 10 60 && run_cmd "Install linux-lowlatency" apt install -y linux-lowlatency && log "ℹ️ Reboot to use linux-lowlatency."
  fi
}

install_all() {
  install_update
  detect_gpu
  install_nvidia
  install_amd
  install_steam
  install_lutris
  install_wine
  install_gamemode
  install_heroic
  install_itch
  install_obs
  install_chat
  install_benchmarks
  install_dxvk_vkd3d
  whiptail --msgbox "🎉 All main components installed. Consider installing the Gaming Kernel next!" 10 60
}

cleanup_all() {
  log "🧹 Removing gaming packages..."
  if [[ "$DISTRO" == "arch" ]]; then
    run_cmd "Remove Arch packages" pacman -Rns --noconfirm steam lutris wine-staging winetricks gamemode mangohud lib32-mangohud obs-studio discord teamspeak3 vulkan-tools mesa-demos glmark2 || true
    [[ $YAY_OK -eq 1 ]] && run_cmd "Remove AUR apps" yay -Rns --noconfirm heroic-games-launcher-bin dxvk-bin teamspeak3 discord || true
  else
    run_cmd "Remove Deb/Ubuntu packages" apt purge -y steam lutris winehq-staging wine-staging wine gamemode mangohud obs-studio teamspeak3-client glmark2 vulkan-tools mesa-utils discord || true
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
      "7"  "Install Lutris (choose Flatpak/Native)" \
      "8"  "Install WineHQ (staging)" \
      "9"  "Install Gamemode + MangoHud" \
      "10" "Install Heroic Games Launcher" \
      "11" "Install itch.io Client" \
      "12" "Install OBS Studio (choose Flatpak/Native)" \
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
