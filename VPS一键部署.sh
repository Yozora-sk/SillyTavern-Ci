#!/bin/bash

# 更新软件包
apt-get update -y
apt-get upgrade -y

# 安装 git
apt-get install git -y

# 创建新的文件夹 (替换为你的实际路径)
mkdir -p /opt/sillytavern

# 切换到新的文件夹
cd /opt/sillytavern

# 安装 nvm (需要 curl)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash

# 重新加载 shell 配置
source ~/.bashrc

# 安装 node (使用 nvm 安装指定版本，替换为你的实际版本)
nvm install 18

# 安装 pm2
npm install -g pm2

# 安装 vim
apt-get install vim -y

# 克隆 SillyTavern (替换为你的实际仓库地址)
git clone https://github.com/SillyTavern/SillyTavern.git .

# 切换到 SillyTavern 目录
cd SillyTavern

# 安装依赖
npm install

# 使用 node 命令启动一次，尝试创建 config.yaml
node server.js &  # 使用 & 在后台运行，避免阻塞后续操作

# 等待几秒钟让服务器有机会创建 config.yaml
sleep 5

# 检查 config.yaml 是否存在
if [ -f config.yaml ]; then
  echo "config.yaml 文件已存在，正在进行修改..."

  # 使用 sed 命令修改 config.yaml 文件
  sed -i 's/listen: false/listen: true/g' config.yaml
  sed -i 's/whitelistMode: true/whitelistMode: false/g' config.yaml
  sed -i 's/basicAuthMode: false/basicAuthMode: true/g' config.yaml

  # 获取用户自定义端口
  read -p "请输入自定义端口 (默认为 8000): " custom_port
  custom_port="${custom_port:-8000}" # 使用默认值 8000

  # 使用 sed 命令修改端口
  sed -i "s/port: 8000/port: ${custom_port}/g" config.yaml

  # 获取用户自定义用户名和密码
  read -p "请输入自定义用户名 (默认为 user): " custom_username
  custom_username="${custom_username:-user}"
  read -p "请输入自定义密码 (默认为 password): " custom_password
  custom_password="${custom_password:-password}"

  # 使用 sed 命令修改用户名和密码 (安全警告依然适用！)
  sed -i "s/username: user/username: ${custom_username}/g" config.yaml
  sed -i "s/password: password/password: ${custom_password}/g" config.yaml

  # 停止之前用 node 启动的进程 (可选，但建议加上，避免冲突)
  pkill -f "node server.js"

  # 使用 pm2 启动 SillyTavern
  pm2 start server.js --name "sillytavern"

  # 设置 pm2 在系统启动时自动启动
  pm2 startup

  # 保存配置
  pm2 save

  # 获取服务器IP地址 (可能需要根据你的系统调整)
  server_ip=$(ip route get 1 | awk '{print $NF;exit}')

  echo "SillyTavern 部署完成，使用 pm2 管理进程。"
  echo "你的配置信息如下:"
  echo "用户名: ${custom_username}"
  echo "密码: ${custom_password}"  # 安全警告！生产环境中不要直接显示密码！
  echo "端口: ${custom_port}"
  echo "访问地址: ${server_ip}:${custom_port}"

else
  echo "config.yaml 文件未创建，请检查你的 server.js 文件是否正确创建了该文件。"
  exit 1 # 退出脚本，提示错误
fi