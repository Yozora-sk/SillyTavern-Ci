#!/bin/bash

# 设置颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color

# 更新软件源列表
sudo apt update && echo "${GREEN}软件源更新完成${NC}" || { echo "${RED}软件源更新失败${NC}"; exit 1; }

# 安装必要的软件包
sudo apt install -y git vim curl build-essential libssl-dev && echo "${GREEN}必要软件包安装完成${NC}" || { echo "${RED}必要软件包安装失败${NC}"; exit 1; }

# 创建目录
mkdir -p Aiweb/SillyTavern && echo "${GREEN}目录创建完成${NC}" || { echo "${RED}目录创建失败${NC}"; exit 1; }

cd Aiweb/SillyTavern || { echo "${RED}目录切换失败${NC}"; exit 1; }

# 安装nvm (使用更稳定的安装方式)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc

# 安装Node.js (指定版本, 例如v18)
nvm install v20 && echo "${GREEN}Node.js 安装完成${NC}" || { echo "${RED}Node.js 安装失败${NC}"; exit 1; }

# 安装pm2
npm install -g pm2 && echo "${GREEN}pm2 安装完成${NC}" || { echo "${RED}pm2 安装失败${NC}"; exit 1; }

# 克隆SillyTavern (确保目录为空)
git clone https://github.com/SillyTavern/SillyTavern.git . && echo "${GREEN}SillyTavern 克隆完成${NC}" || { echo "${RED}SillyTavern 克隆失败${NC}"; exit 1; }


# 安装依赖
npm install && echo "${GREEN}依赖安装完成${NC}" || { echo "${RED}依赖安装失败${NC}"; exit 1; }

# 获取用户输入配置
read -p "请输入自定义用户名 (默认: user): " custom_username
read -sp "请输入自定义密码 (默认: password): " custom_password
echo "" # 换行，避免密码直接连接到下一行提示
read -p "请输入自定义端口 (默认: 8000): " custom_port


# 使用默认值，如果输入为空
custom_username="${custom_username:-user}"
custom_password="${custom_password:-password}"
custom_port="${custom_port:-8000}"

# 修改config.yaml的函数
modify_config() {
  local key="$1"
  local value="$2"
  sed -i -E "s/^\(${key}:\s*).*/\1${value}/" config.yaml
}

# 启动服务器并等待config.yaml创建
node server.js &
while [ ! -f config.yaml ]; do
  sleep 1
  echo "等待 config.yaml 创建..."
done
pkill -f "node server.js"


# 修改config.yaml
modify_config "listen" "true"
modify_config "whitelistMode" "false"
modify_config "basicAuthMode" "true"
modify_config "port" "${custom_port}"
modify_config "username" "${custom_username}"
modify_config "password" "${custom_password}"



# 使用pm2启动
pm2 start server.js --name "sillytavern" && echo "${GREEN}SillyTavern 启动成功${NC}" || { echo "${RED}SillyTavern 启动失败${NC}"; exit 1; }
pm2 startup systemd && pm2 save && echo "${GREEN}pm2 配置保存完成${NC}" || { echo "${RED}pm2 配置保存失败${NC}"; exit 1; }



# 获取服务器IP (更通用的方法)
server_ip=$(hostname -I | awk '{print $1}')


echo "SillyTavern部署成功，由pm2管理进程。"
echo "你的配置信息如下:"
echo "用户名: ${custom_username}"
echo "密码: ${custom_password}"
echo "端口: ${custom_port}"
echo "访问地址: http://${server_ip}:${custom_port}"
