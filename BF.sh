#!/bin/bash

# 下载并解压文件
curl -L https://file.uhsea.com/2411/9a5d8359cc364bd092636838d8c6479b91.zip -o download.zip
unzip download.zip
rm download.zip

# 进入 SillyTavern 目录并修改权限
cd SillyTavern || { echo "目录 SillyTavern 不存在"; exit 1; }

# 检查 node_modules 目录是否存在，如果不存在则运行 npm install
if [ ! -d "node_modules" ]; then
    echo "node_modules 目录不存在，正在运行 npm install..."
    npm install
else
    echo "node_modules 目录已存在，无需安装依赖。"
fi

# 修改 start.sh 的权限
chmod 700 start.sh

# 下载并运行 Android.sh
curl -O https://raw.githubusercontent.com/Yozora-sk/SillyTavern-Ci/refs/heads/main/Android.sh
chmod +x Android.sh
./Android.sh
