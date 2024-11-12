#!/bin/bash

# 颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 默认安装路径
INSTALL_PATH="$HOME/SillyTavern"

SYSTEM_UPDATE_FLAG="$HOME/.termux/system_update.flag"
REPO_CLONE_FLAG="$INSTALL_PATH/clone_complete.flag"

# 日志注释信息
LOG_COMMENT="\
如报错，请查看以下日志信息，阅读错误处理。
SillyTavern 程序 90% 的错误来源于网络环境，请检查网络连接。"

# 日志文件路径
LOG_FILE="$INSTALL_PATH/sillytavern.log"


# 更新数据源
update_system() {
    if [ ! -f "$SYSTEM_UPDATE_FLAG" ] || [ ! -f "$REPO_CLONE_FLAG" ]; then
        echo -e "${YELLOW}开始更新系统...${NC}"
        apt update && apt upgrade -y && touch "$SYSTEM_UPDATE_FLAG" || {
            echo -e "${RED}系统更新失败，请手动更新。${NC}"
            exit 1
        }
    else
        echo -e "${GREEN}系统已经在过去更新过，无需再更新。${NC}"
    fi
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
    touch "$REPO_CLONE_FLAG"
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


# 启动 SillyTavern
start_sillytavern() {
  echo "启动 SillyTavern..."
  cd "$INSTALL_PATH" || { echo -e "${RED}切换到 SillyTavern 目录失败${NC}"; exit 1; }

  # 删除之前的日志文件
  if [ -f "$LOG_FILE" ]; then
    rm "$LOG_FILE" || echo -e "${YELLOW}删除之前的日志文件 $LOG_FILE 失败，可能文件已被占用或权限不足。${NC}"
  fi

  exec > >(tee -a "$LOG_FILE") 2>&1 # Redirect stdout and stderr to log file
  ./start.sh || { echo -e "${RED}启动 SillyTavern 失败${NC}"; exit 1; }
  echo -e "${GREEN}SillyTavern 启动成功!${NC}"
}

# 更新 SillyTavern
update_sillytavern() {
  cd "$INSTALL_PATH" || { echo -e "${RED}切换到 SillyTavern 目录失败${NC}"; return 1; }

  if [[ "$current_version" == "$latest_version" ]]; then
    echo -e "${YELLOW}SillyTavern 已经是最新版本 ($current_version)。${NC}"
    return 0
  fi
  echo "更新 SillyTavern..."
  git pull || { echo -e "${RED}更新 SillyTavern 失败${NC}"; exit 1; }
  echo -e "${GREEN}SillyTavern 更新成功!${NC}"
  read -p "更新已完成。按 Enter 键继续..." -r
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


# 查看日志
view_logs() {
  cd "$INSTALL_PATH" || { echo -e "${RED}切换到 SillyTavern 目录失败${NC}"; return 1; }
  if [ -f "$LOG_FILE" ]; then
    echo -e "${YELLOW}${LOG_COMMENT}${NC}"
    less "$LOG_FILE"
  else
    echo -e "${RED}未找到日志文件 $LOG_FILE${NC}"
  fi
}

check_for_updates() {
  current_version=$(get_sillytavern_version | head -n 1)
  latest_version=$(get_sillytavern_version | tail -n 1)

  if [[ "$current_version" != "$latest_version" ]]; then
    echo -e "${YELLOW}发现新的 SillyTavern 版本 ($latest_version)，正在更新...${NC}"
    update_sillytavern
  else
    echo -e "${GREEN}SillyTavern 已经是最新版本 ($current_version)。${NC}"
  fi
}

# 初始化
update_system
check_node_git
check_esbuild
setup_sillytavern

# 首次启动时检查更新
current_version=$(get_sillytavern_version | head -n 1)
latest_version=$(get_sillytavern_version | tail -n 1)
check_for_updates

# Ctrl+C 信号处理
trap '' INT


# 用户菜单
while true; do
  clear
  echo -e "
  ${GREEN}-------------------------------------${NC}
  ${GREEN}*     SillyTavern 管理菜单        *${NC}
  ${GREEN}-------------------------------------${NC}
  ${YELLOW}By: Yozora  Bilibili: 601449119${NC}
  ${YELLOW}Tools: alist.nightan.xyz          ${NC}
  ${YELLOW}黑屏/加载慢请检查后台活跃权限    ${NC}
  ${GREEN}-------------------------------------${NC}
  ${GREEN}本地安装路径: $INSTALL_PATH${NC}
  ${GREEN}SillyTavern本地版本: $current_version${NC}
  ${GREEN}SillyTavern最新版本: $latest_version${NC}
  ${GREEN}Node.js版本信息: $node_version${NC}
  ${GREEN}Git版本信息: $git_version${NC}
  ${GREEN}-------------------------------------${NC}
  ${YELLOW}1. 启动 SillyTavern${NC}
  ${YELLOW}2. 备份用户数据${NC}
  ${YELLOW}3. 恢复用户数据${NC}
  ${YELLOW}4. 删除备份文件${NC}
  ${YELLOW}5. 查看日志${NC}
  ${YELLOW}6. 退出${NC}
  ${GREEN}-------------------------------------${NC}
  "

  read -p "请输入你的选择: " choice

  case $choice in
    1) start_sillytavern ;;
    2) backup_user_data ;;
    3) restore_user_data ;;
    4) delete_backup_files ;;
    5) view_logs ;;
    6) exit 0 ;;
    *) echo -e "${RED}无效的选择，请重试。${NC}" ;;
  esac
done
