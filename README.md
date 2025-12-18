# 🎮 Linux Gaming Toolkit

**Official repository for the Linux Gaming Toolkit by Dennis Hilk**  
Easily set up **Debian, Ubuntu, Linux Mint and Arch Linux** for gaming with one script.  
Includes Steam, Lutris, Proton, WineHQ, Gamemode, Heroic Launcher, OBS, Discord, Benchmarks, DXVK/VKD3D and more.  

🔗 Project URL: [https://github.com/dennishilk/linux-gaming-toolkit](https://github.com/dennishilk/linux-gaming-toolkit)  

---
🚀 Features (v4)

✅ Multi-distro support: Debian, Ubuntu, Linux Mint, Arch (+ derivatives)

✅ GPU-aware installs (NVIDIA / AMD / Intel detected automatically)

✅ One-click full gaming setup or modular installs via menu

✅ Steam + Proton

✅ Lutris, Wine, Heroic Games Launcher, itch.io

✅ Gamemode + MangoHud

✅ OBS Studio (native or Flatpak fallback)

✅ DXVK / VKD3D-Proton (where available)

✅ Benchmark tools (glmark2, Vulkan tools, Mesa utils)

✅ Flatpak support with Flathub auto-setup

✅ Robust logging & error handling

✅ Cleanup option to remove gaming packages

🧠 What’s new in v4

🔒 Safer Bash (set -Eeuo pipefail + error trap)

🧠 Smarter logic (no unnecessary driver installs)

🎮 GPU-specific driver installation

🧼 Cleaner code structure & reduced duplication

📜 Improved logging (with /tmp fallback if needed)

## 📥 Installation

1. Clone this repository:
   
   git clone https://github.com/dennishilk/linux-gaming-toolkit.git
   
   cd linux-gaming-setup
   
3. Make the script executable:

   chmod +x linux-gaming-setup.sh

4. Run it with root privileges:

   sudo ./linux-gaming-setup.sh
   
