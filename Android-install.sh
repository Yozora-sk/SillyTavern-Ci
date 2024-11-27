#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

INSTALL_PATH="$HOME/SillyTavern"
MANAGER_SCRIPT="$HOME/manager.sh"
BASHRC_FILE="$HOME/.bashrc"

SYSTEM_UPDATE_FLAG="$HOME/.termux/system_update.flag"
REPO_CLONE_FLAG="$INSTALL_PATH/clone_complete.flag"

update_system() {
    apt update && apt upgrade -y
}

# 检查并安装 Node.js 和 Git
check_node_git() {
    if command -v node &> /dev/null; then
        node_version=$(node --version)
        echo -e "${GREEN}已找到 Node.js: $node_version${NC}"
    else
        echo -e "${YELLOW}未找到 Node.js，正在尝试安装...${NC}"
        pkg install -y nodejs || { echo -e "${RED}Node.js 安装失败${NC}"; exit 1; }
        node_version=$(node --version)
        echo -e "${GREEN}Node.js 安装成功: $node_version${NC}"
    fi

    if command -v git &> /dev/null; then
        git_version=$(git --version | cut -d ' ' -f 3)
        echo -e "${GREEN}已找到 Git: $git_version${NC}"
    else
        echo -e "${YELLOW}未找到 Git，正在尝试安装...${NC}"
        pkg install -y git || { echo -e "${RED}Git 安装失败${NC}"; exit 1; }
        git_version=$(git --version | cut -d ' ' -f 3)
        echo -e "${GREEN}Git 安装成功: $git_version${NC}"
    fi
}

check_esbuild() {
    if ! command -v esbuild &> /dev/null; then
        echo -e "${YELLOW}未找到 esbuild，正在尝试安装...${NC}"
        apt install -y esbuild || { echo -e "${RED}esbuild 安装失败${NC}"; exit 1; }
        echo -e "${GREEN}esbuild 安装成功${NC}"
    fi
}

setup_sillytavern() {
    if [ ! -d "$INSTALL_PATH" ]; then
        echo -e "${YELLOW}SillyTavern 目录不存在，正在克隆仓库并安装依赖...${NC}"
        git clone https://github.com/SillyTavern/SillyTavern.git "$INSTALL_PATH" || { echo -e "${RED}克隆仓库失败${NC}"; exit 1; }
        cd "$INSTALL_PATH" || { echo -e "${RED}切换到 SillyTavern 目录失败${NC}"; exit 1; }
        npm install || { echo -e "${RED}安装 Node.js 依赖失败${NC}"; exit 1; }
        echo -e "${GREEN}SillyTavern 初始化完成！${NC}"
    else
        touch "$REPO_CLONE_FLAG"
        cd "$INSTALL_PATH"
        echo -e "${GREEN}SillyTavern 已经安装！${NC}"
    fi
}

setup_manager_script() {
    echo -e "${YELLOW}正在下载管理脚本...${NC}"
    curl -o "$MANAGER_SCRIPT" https://raw.githubusercontent.com/Yozora-sk/SillyTavern-Ci/refs/heads/main/Android-manager.sh || { 
        echo -e "${RED}管理脚本下载失败${NC}"
        exit 1
    }
    chmod +x "$MANAGER_SCRIPT"
    echo -e "${GREEN}管理脚本下载完成并已设置执行权限${NC}"
}

setup_auto_start() {
    echo -e "${YELLOW}正在设置自动启动...${NC}"
    
    touch "$BASHRC_FILE"
    
    if ! grep -q "bash manager.sh" "$BASHRC_FILE"; then
        echo "bash manager.sh" >> "$BASHRC_FILE"
        echo -e "${GREEN}自动启动配置完成${NC}"
    else
        echo -e "${YELLOW}自动启动已经配置${NC}"
    fi
}

start_manager() {
    echo -e "${YELLOW}正在启动管理脚本...${NC}"
    bash "$MANAGER_SCRIPT" || {
        echo -e "${RED}管理脚本启动失败${NC}"
        exit 1
    }
}

main() {
    clear
    echo -e "${GREEN}-------------------------------------${NC}"
    echo -e "${GREEN}*     SillyTavern 安装程序         *${NC}"
    echo -e "${GREEN}-------------------------------------${NC}"
    echo -e "${YELLOW}开始安装 SillyTavern...${NC}"
    
    update_system
    check_node_git
    check_esbuild
    setup_sillytavern
    setup_manager_script
    setup_auto_start
    
    echo -e "${GREEN}-------------------------------------${NC}"
    echo -e "${GREEN}SillyTavern 安装完成！${NC}"
    echo -e "${GREEN}已设置自动启动${NC}"
    echo -e "${GREEN}正在启动管理脚本...${NC}"
    echo -e "${GREEN}-------------------------------------${NC}"
    
    start_manager
}

main