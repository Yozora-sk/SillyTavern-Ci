#!/bin/bash

# 更新软件源列表
sudo apt update

# 安装必要的软件包
apt-get install git vim -y || exit 1

mkdir -p Aiweb/SillyTavern || exit 1

cd ./Aiweb || exit 1

# 安装nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
if [ $? -ne 0 ]; then
  echo "安装nvm失败，请检查网络连接和权限。"
  exit 1
fi

source ~/.bashrc

# 安装Node.js
nvm install --lts || exit 1 # 使用最新的LTS版本，更稳定

# 安装pm2
npm install -g pm2 || exit 1

cd ./SillyTavern || exit 1

# 克隆SillyTavern
git clone https://github.com/SillyTavern/SillyTavern.git . || exit 1

# 安装依赖
npm install || exit 1

# 获取用户输入配置
read -s -p "请输入自定义用户名 (默认: user): " custom_username
read -s -p "请输入自定义密码 (默认: password): " custom_password

# 使用默认值，如果输入为空
custom_username="${custom_username:-user}"
custom_password="${custom_password:-password}"
read -p "请输入自定义端口 (默认: 8000): " custom_port
custom_port="${custom_port:-8000}"

# 安全修改config.yaml的函数
modify_config() {
  local key="$1"
  local value="$2"
  sed -i "s/^\(${key}:\).*$/\1: ${value}/" config.yaml
}

# 尝试启动服务器并创建config.yaml
node server.js &
sleep 5

# 检查config.yaml是否存在
if [ -f config.yaml ]; then
  modify_config "listen" "true"
  modify_config "whitelistMode" "false"
  modify_config "basicAuthMode" "true"
  modify_config "port" "${custom_port}"
  modify_config "username" "${custom_username}"
  modify_config "password" "${custom_password}"
  pkill -f "node server.js"

  # 使用pm2启动
  pm2 start server.js --name "sillytavern" || exit 1
  pm2 startup systemd || exit 1 # 使用systemd，系统重启后自动启动
  pm2 save || exit 1

  # 获取服务器IP (更健壮的方法)
  server_ip=$(ip route show default | awk '{print $5}')

  echo "SillyTavern部署成功，由pm2管理进程。"
  echo "你的配置信息如下:"
  echo "用户名: ${custom_username}"
  echo "端口: ${custom_port}"
  echo "访问地址: ${server_ip}:${custom_port}"

else
  echo "错误: config.yaml未创建。请检查你的server.js文件。"
  exit 1
fi
