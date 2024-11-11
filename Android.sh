#!/bin/bash

# 颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'  # 无颜色
# 更新数据源
apt update && apt upgrade

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
    git_version=$(git --version)
    echo -e "${GREEN}已找到 Git: $git_version${NC}"
  else
    echo -e "${YELLOW}未找到 Git，正在尝试安装...${NC}"
    apt install -y git || { echo -e "${RED}Git 安装失败${NC}"; exit 1; }
    git_version=$(git --version)
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
  if [ ! -d "SillyTavern" ]; then
    echo -e "${YELLOW}SillyTavern 目录不存在，正在克隆仓库并安装依赖...${NC}"
    git clone https://github.com/SillyTavern/SillyTavern.git || { echo -e "${RED}克隆仓库失败${NC}"; exit 1; }
    cd SillyTavern || { echo -e "${RED}切换到 SillyTavern 目录失败${NC}"; exit 1; }
    npm install || { echo -e "${RED}安装 Node.js 依赖失败${NC}"; exit 1; }
    echo -e "${GREEN}SillyTavern 初始化完成！${NC}"
  else
    cd SillyTavern
  fi
}

# 获取 SillyTavern 版本
get_sillytavern_version() {
  local current_version=$(grep version package.json | cut -d '"' -f 4) || current_version="未知版本"
  local latest_version=$(curl -s https://raw.githubusercontent.com/SillyTavern/SillyTavern/refs/heads/release/package.json 2>/dev/null | grep '"version"' | awk -F '"' '{print $4}' || echo "未知版本")
  echo "$current_version"
  echo "$latest_version"
}

# 启动 SillyTavern
start_sillytavern() {
  echo "启动 SillyTavern..."
  ./start.sh || { echo -e "${RED}启动 SillyTavern 失败${NC}"; exit 1; }
  echo -e "${GREEN}SillyTavern 启动成功!${NC}"
}

# 更新 SillyTavern
update_sillytavern() {
  if [[ "$current_version" == "$latest_version" ]]; then
    echo -e "${YELLOW}SillyTavern 已经是最新版本 ($current_version)。${NC}"
    return 0
  fi
  echo "更新 SillyTavern..."
  git pull https://github.com/SillyTavern/SillyTavern || { echo -e "${RED}更新 SillyTavern 失败${NC}"; exit 1; }
  echo -e "${GREEN}SillyTavern 更新成功!${NC}"
}

# 备份用户数据
backup_user_data() {
  parent_dir=$(dirname "$(pwd)")
  timestamp=$(date +%Y%m%d_%H%M%S)
  backup_filename="SillyTavern_data_backup_$timestamp.tar.gz"
  backup_path="$parent_dir/$backup_filename"

  tar -czvf "$backup_path" data || { echo -e "${RED}创建备份失败: ${?}${NC}"; exit 1; }
  echo -e "${GREEN}用户数据已备份到: $backup_path${NC}"
  read -p "备份完成。按 Enter 键继续..." -r
}

# 数据恢复功能
restore_user_data() {
  parent_dir=$(dirname "$(pwd)")
  backup_files=$(find "$parent_dir" -name "SillyTavern_data_backup_*tar.gz" 2>/dev/null)

  if [ -z "$backup_files" ]; then
    echo -e "${RED}未找到备份文件。${NC}"
    return 1
  fi

  echo -e "${YELLOW}找到以下备份文件：${NC}"
  i=1
  for file in $backup_files; do
    echo "$i. $file"
    i=$((i+1))
  done

  read -p "请输入要恢复的备份文件的序号 (输入 0 取消恢复): " choice

  if [[ "$choice" == "0" ]]; then
    return 0
  fi

  if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -gt "$i" ]] || [[ "$choice" -lt "1" ]]; then
    echo -e "${RED}无效的序号，请重试。${NC}"
    return 1
  fi


  selected_file=$(echo "$backup_files" | awk -v choice="$choice" 'NR==choice{print $0}')

  if [ ! -f "$selected_file" ]; then
      echo -e "${RED}备份文件不存在，请重试。${NC}"
      return 1
  fi

  temp_dir=$(mktemp -d) || { echo -e "${RED}创建临时目录失败${NC}"; return 1; }

  # 解压备份文件到临时目录
  tar -xzvf "$selected_file" -C "$temp_dir" || { echo -e "${RED}解压备份文件失败${NC}"; rm -rf "$temp_dir"; return 1; }

  # 检查解压后的data目录
  data_dir="$temp_dir/data"
  if [ ! -d "$data_dir" ]; then
      echo -e "${RED}备份文件不包含data目录${NC}"
      rm -rf "$temp_dir"
      return 1
  fi

  # 替换原data目录
  rm -rf data || { echo -e "${RED}删除原data目录失败${NC}"; rm -rf "$temp_dir"; return 1; }
  mv "$data_dir" data || { echo -e "${RED}移动data目录失败${NC}"; rm -rf "$temp_dir"; return 1; }
  rm -rf "$temp_dir"


  echo -e "${GREEN}数据恢复成功！${NC}"
  read -p "数据恢复完成。按 Enter 键继续..." -r
}

# 备份文件删除功能
delete_backup_files() {
  parent_dir=$(dirname "$(pwd)")
  backup_files=$(find "$parent_dir" -name "SillyTavern_data_backup_*tar.gz" 2>/dev/null)

  if [ -z "$backup_files" ]; then
    echo -e "${RED}未找到备份文件。${NC}"
    return 0
  fi

  echo -e "${YELLOW}找到以下备份文件：${NC}"
  i=1
  declare -A backup_file_map
  for file in $backup_files; do
    echo "$i. $file"
    backup_file_map[$i]=$file
    i=$((i+1))
  done

  read -p "请输入要删除的备份文件的序号，多个序号用空格隔开 (输入 0 取消删除): " choice

  if [[ "$choice" == "0" ]]; then
    return 0
  fi

  for num in $choice; do
    if [[ ! "$num" =~ ^[0-9]+$ ]] || [[ "$num" -gt "$i" ]] || [[ "$num" -lt "1" ]]; then
      echo -e "${RED}无效的序号 $num，请重试。${NC}"
      return 1
    fi
    rm "${backup_file_map[$num]}" || echo -e "${RED}删除备份文件 ${backup_file_map[$num]} 失败!${NC}"
  done
  echo -e "${GREEN}备份文件删除成功!${NC}"
  read -p "按 Enter 键继续..." -r
}

# 初始化
check_node_git
check_esbuild
setup_sillytavern

# 获取版本信息
current_version=$(get_sillytavern_version | head -n 1)
latest_version=$(get_sillytavern_version | tail -n 1)

# Ctrl+C 信号处理
trap '' INT

# 用户菜单
while true; do
  clear
  echo -e "${GREEN}SillyTavern 管理菜单${NC}"
  echo -e "${RED}By Night${NC}"
  echo -e "${YELLOW}My Bilibili:601449119${NC}"
  echo -e "${YELLOW}Tools:alist.nightan.xyz${NC}"
  echo -e "${YELLOW}如果出现黑屏or长时间无法加载，请检查Termux的后台活跃权限${NC}"
  echo -e "${GREEN}Node.js 版本: $node_version${NC}"
  echo -e "${GREEN}Git 版本: $git_version${NC}"
  echo "当前 SillyTavern 版本: $current_version"
  echo "最新 SillyTavern 版本: $latest_version"
  echo "1. 启动 SillyTavern"
  echo "2. 更新 SillyTavern"
  echo "3. 备份用户数据"
  echo "4. 恢复用户数据"
  echo "5. 删除备份文件"
  echo "6. 退出"

  read -p "请输入你的选择: " choice

  case $choice in
    1) start_sillytavern ;;
    2) update_sillytavern ;;
    3) backup_user_data ;;
    4) restore_user_data ;;
    5) delete_backup_files ;;
    6) exit 0 ;;
    *) echo -e "${RED}无效的选择，请重试。${NC}" ;;
  esac
done
