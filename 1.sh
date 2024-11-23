#!/bin/bash

current=/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/ubuntu
# 更新软件包列表
pkg update -y

# 升级已安装的软件包
pkg upgrade -y

# 检查并安装 proot-distro（如果尚未安装）
if ! command -v proot-distro &> /dev/null; then
    echo "正在安装 proot-distro..."
    pkg install proot-distro -y
fi

# 检查并安装 Ubuntu（如果尚未安装）
if [ ! -d "$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu" ]; then
    echo "正在安装 Ubuntu..."
    proot-distro install ubuntu
fi

# 在 Ubuntu 中执行命令
proot-distro login ubuntu << EOF
wget -O https://raw.githubusercontent.com/Yozora-sk/SillyTavern-Ci/main/2.sh && chmod +x 2.sh && ./2.sh
EOF