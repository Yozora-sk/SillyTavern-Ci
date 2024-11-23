#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 更新数据源
echo -e "${GREEN}正在更新数据源...${NC}"
apt update -y

# 安装必要工具
echo -e "${GREEN}正在安装 curl, git, vim...${NC}"
apt install -y curl git vim

# 克隆 SillyTavern 仓库
echo -e "${GREEN}正在克隆 SillyTavern 仓库...${NC}"
git clone https://github.com/SillyTavern/SillyTavern.git

# 安装 NVM
echo -e "${GREEN}正在安装 NVM...${NC}"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash

# 提醒用户
echo -e "${RED}重要提示：请手动执行以下命令以加载 NVM：${NC}"
echo -e "${RED}source ~/.bashrc${NC}"

# 切换到 SillyTavern 目录
cd SillyTavern

# 加载 NVM 和 Node.js
echo -e "${GREEN}加载 NVM 和 Node.js...${NC}"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # 加载 NVM
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # 加载 NVM bash 补全

# 安装最新的 LTS Node.js 版本
nvm install --lts

# 安装依赖
echo -e "${GREEN}正在安装依赖...${NC}"
npm install

# 启动 SillyTavern
echo -e "${GREEN}正在启动 SillyTavern...${NC}"
bash start.sh