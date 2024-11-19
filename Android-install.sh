#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

INSTALL_PATH="$HOME/SillyTavern"

SCRIPT_URL="https://raw.githubusercontent.com/Yozora-sk/SillyTavern-Ci/main/Android-manager.sh"

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
    apt install -y nodejs || { echo -e "${RED}Node.js 安装失败${NC}"; exit 1; }
    node_version=$(node --version)
    echo -e "${GREEN}Node.js 安装成功: $node_version${NC}"
  fi

  if command -v git &> /dev/null; then
    git_version=$(git --version | cut -d ' ' -f 3)
    echo -e "${GREEN}已找到 Git: $git_version${NC}"
  else
    echo -e "${YELLOW}未找到 Git，正在尝试安装...${NC}"
    apt install -y git || { echo -e "${RED}Git 安装失败${NC}"; exit 1; }
    git_version=$(git --version | cut -d ' ' -f 3)
    echo -e "${GREEN}Git 安装成功: $git_version${NC}"
  fi
}

# 检查并安装 esbuild
check_esbuild() {
  if ! command -v esbuild &> /dev/null; then
    echo -e "${YELLOW}未找到 esbuild，正在尝试安装...${NC}"
    apt install -y esbuild || { echo -e "${RED}esbuild 安装失败${NC}"; exit 1; }
    echo -e "${GREEN}esbuild 安装成功${NC}"
  fi
}

# 克隆仓库并安装依赖
setup_sillytavern() {
  if [ ! -d "$INSTALL_PATH" ]; then
    echo -e "${YELLOW}SillyTavern 目录不存在，正在克隆仓库并安装依赖...${NC}"
    git clone https://github.com/SillyTavern/SillyTavern.git "$INSTALL_PATH" || { echo -e "${RED}克隆仓库失败${NC}"; exit 1; }
    cd "$INSTALL_PATH" || { echo -e "${RED}切换到 SillyTavern 目录失败${NC}"; exit 1; }
    npm install || { echo -e "${RED}安装 Node.js 依赖失败${NC}"; exit 1; }
    echo -e "${GREEN}SillyTavern 初始化完成！${NC}"
  else
    cd "$INSTALL_PATH"
  fi
}

# 获取 SillyTavern 版本
get_sillytavern_version() {
  local current_version=$(grep version package.json | cut -d '"' -f 4) || current_version="未知版本"
  local latest_version=$(curl -s https://raw.githubusercontent.com/SillyTavern/SillyTavern/refs/heads/release/package.json 2>/dev/null | grep '"version"' | awk -F '"' '{print $4}' || echo "未知版本")
  echo "$current_version"
  echo "$latest_version"
}

# 更新 SillyTavern
update_sillytavern() {
  cd "$INSTALL_PATH" || { echo -e "${RED}切换到 SillyTavern 目录失败${NC}"; return 1; }
  current_version=$(get_sillytavern_version | head -n 1)
  latest_version=$(get_sillytavern_version | tail -n 1)

  if [[ "$current_version" == "$latest_version" ]]; then
    echo -e "${YELLOW}SillyTavern 已经是最新版本 ($current_version)。${NC}"
    return 0
  fi
  echo "更新 SillyTavern..."
  git pull || { echo -e "${RED}更新 SillyTavern 失败${NC}"; exit 1; }
  echo -e "${GREEN}SillyTavern 更新成功!${NC}"
}

download_second_script() {
  echo -e "${YELLOW}正在下载第二个脚本...${NC}"
  curl -o "$HOME/sillytavern_manager.sh" -L "$SCRIPT_URL" || { echo -e "${RED}下载脚本失败${NC}"; exit 1; }
  chmod +x "$HOME/sillytavern_manager.sh" || { echo -e "${RED}设置脚本执行权限失败${NC}"; exit 1; }
  echo -e "${GREEN}脚本下载完成！${NC}"
}

setup_autostart() {
  echo -e "${YELLOW}正在设置 Termux 自动启动...${NC}"

  if [ ! -f "$HOME/.bashrc" ]; then
    touch "$HOME/.bashrc"
  fi

  if ! grep -q "sillytavern_manager.sh" "$HOME/.bashrc"; then
    echo 'bash "$HOME/sillytavern_manager.sh" ' >> "$HOME/.bashrc"
    echo -e "${GREEN}已成功添加自动启动命令到 .bashrc${NC}"
  else
    echo -e "${YELLOW}自动启动命令已存在于 .bashrc 中，跳过添加${NC}"
  fi
}

run_second_script() {
  echo -e "${YELLOW}正在运行第二个脚本...${NC}"
  bash "$HOME/sillytavern_manager.sh"
}

update_system
check_node_git
check_esbuild
setup_sillytavern
update_sillytavern

download_second_script

setup_autostart

run_second_script

echo -e "${GREEN}所有设置完成！${NC}"