#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

INSTALL_PATH="$HOME/SillyTavern"

LOG_FILE="$INSTALL_PATH/sillytavern.log"

ANNOUNCEMENT_URL="https://raw.githubusercontent.com/Yozora-sk/SillyTavern-Ci/refs/heads/main/ANNOUNCEMENT"

LOG_COMMENT="\
如报错，请查看以下日志信息，阅读错误处理。
SillyTavern 程序 90% 的错误来源于网络环境，请检查网络连接。"

error_message() {
  echo -e "${RED}$1${NC}"
  sleep 3
}

warn() {
  echo -e "${YELLOW}$1${NC}"
}

success() {
  echo -e "${GREEN}$1${NC}"
}

# 版本获取
get_sillytavern_version() {
  cd "$INSTALL_PATH"
  local current_version=$(grep version package.json | cut -d '"' -f 4 2>/dev/null || echo "未知版本")
  local latest_version=$(curl -s https://raw.githubusercontent.com/SillyTavern/SillyTavern/refs/heads/release/package.json 2>/dev/null | grep '"version"' | awk -F '"' '{print $4}' 2>/dev/null || echo "未知版本")
  echo "$current_version"
  echo "$latest_version"
}

# 公告
get_announcement() {
  local announcement=$(curl -s -o /dev/null -w "%{http_code}" "$ANNOUNCEMENT_URL")
  local http_code=$?

  if [ "$http_code" -eq 0 ]; then # 检查成功响应代码 (200)
    announcement=$(curl -s "$ANNOUNCEMENT_URL")
    if [ -z "$announcement" ]; then # 检查内容是否为空
      announcement="无法获取公告内容。"
    fi
  else
    announcement="无法获取公告内容 (HTTP错误代码: $http_code)."
  fi
  echo "$announcement"
}

# 启动
start_sillytavern() {
  success "启动 SillyTavern..."
  cd "$INSTALL_PATH" || { error_message "切换到 SillyTavern 目录失败"; return 1; }

  if [ -f "$LOG_FILE" ]; then
    rm "$LOG_FILE" || warn "删除之前的日志文件 $LOG_FILE 失败，可能文件已被占用或权限不足。"
  fi

  exec > >(tee -a "$LOG_FILE") 2>&1
  if ! ./start.sh; then
    error_message "启动 SillyTavern 失败: $?"
    return 1
  fi
  success "SillyTavern 启动成功!"
}

# 备份
backup_user_data() {
  cd "$INSTALL_PATH" || { error_message "切换到 SillyTavern 目录失败"; return 1; }
  local parent_dir=$(dirname "$(pwd)")
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_filename="SillyTavern_data_backup_$timestamp.tar.gz"
  local backup_path="$parent_dir/$backup_filename"

  if ! tar -czvf "$backup_path" data; then
    error_message "创建备份失败: $?"
    return 1
  fi
  success "用户数据已备份到: $backup_path"
  read -p "备份完成。按 Enter 键继续..." -r
}

# 恢复
restore_user_data() {
  local parent_dir=$(dirname "$(pwd)")
  local backup_files=$(find "$parent_dir" -name "SillyTavern_data_backup_*tar.gz" 2>/dev/null)

  if [ -z "$backup_files" ]; then
    error_message "未找到备份文件。"
    return 1
  fi

  warn "找到以下备份文件："
  select file in $backup_files; do
    if [ -n "$file" ]; then
      break
    fi
  done

  if [ -z "$file" ]; then
    return 0  # 用户取消选择
  fi

  local temp_dir=$(mktemp -d) || { error_message "创建临时目录失败"; return 1; }

  if ! tar -xzvf "$file" -C "$temp_dir"; then
    error_message "解压备份文件失败"
    rm -rf "$temp_dir"
    return 1
  fi

  local data_dir="$temp_dir/data"
  if [ ! -d "$data_dir" ]; then
    error_message "备份文件不包含data目录"
    rm -rf "$temp_dir"
    return 1
  fi

  if ! rm -rf data; then
    error_message "删除原data目录失败"
    rm -rf "$temp_dir"
    return 1
  fi
  if ! mv "$data_dir" data; then
    error_message "移动data目录失败"
    rm -rf "$temp_dir"
    return 1
  fi
  rm -rf "$temp_dir"

  success "数据恢复成功！"
  read -p "数据恢复完成。按 Enter 键继续..." -r
}

# 备份文件删除
delete_backup_files() {
  local parent_dir=$(dirname "$(pwd)")
  local backup_files=$(find "$parent_dir" -name "SillyTavern_data_backup_*tar.gz" 2>/dev/null)

  if [ -z "$backup_files" ]; then
    error_message "未找到备份文件。"
    return 1
  fi

  echo -e "${YELLOW}找到以下备份文件：${NC}"
  local i=1
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
      error_message "无效的序号 $num，请重试。"
      return 1
    fi
    if ! rm "${backup_file_map[$num]}"; then
      error_message "删除备份文件 ${backup_file_map[$num]} 失败!"
      return 1
    fi
  done
  success "备份文件删除成功!"
  read -p "按 Enter 键继续..." -r
}

# 日志
view_logs() {
  cd "$INSTALL_PATH" || { error_message "切换到 SillyTavern 目录失败"; return 1; }
  if [ -f "$LOG_FILE" ]; then
    warn "$LOG_COMMENT"
    less "$LOG_FILE"
  else
    error_message "未找到日志文件 $LOG_FILE"
    return 1
  fi
}

# 子菜单
sillytavern_quick_config_menu() {
  while true; do
    clear
    echo -e "
    ${GREEN}-------------------------------------${NC}
    ${GREEN}*     SillyTavern 快捷配置菜单     *${NC}
    ${GREEN}-------------------------------------${NC}
    ${YELLOW}1. URL导入角色卡${NC}
    ${YELLOW}2. 返回上一级菜单${NC}
    ${GREEN}-------------------------------------${NC}
    "

    read -p "请输入你的选择: " choice

    case $choice in
      1)
        local current_dir=$(dirname "$(readlink -f "$0")")
        cd ~ || { error_message "切换到用户目录失败"; return 1; }

        read -p "请输入角色卡图片的 URL: " image_url
        local filename=$(basename "$image_url" | cut -d'?' -f1)

        if ! curl -s -L "$image_url" -o "$current_dir/$filename"; then
          error_message "图片下载失败，请检查 URL 或网络连接."
          return 1
        fi

        if ! chmod 644 "$current_dir/$filename"; then
          error_message "权限设置失败."
          return 1
        fi

        local sillytavern_data_dir="$HOME/SillyTavern/data/default-user"
        local thumbnail_dir="$sillytavern_data_dir/thumbnails/avatar"
        local character_dir="$sillytavern_data_dir/characters"

        if ! cp "$current_dir/$filename" "$thumbnail_dir"; then
          error_message "复制图片到缩略图目录失败，请检查目录路径和权限."
          return 1
        fi
        success "图片已复制到缩略图目录: $thumbnail_dir/$filename"

        if ! cp "$current_dir/$filename" "$character_dir"; then
          error_message "复制图片到角色目录失败，请检查目录路径和权限."
          return 1
        fi
        success "图片已复制到角色目录: $character_dir/$filename"

        success "导入完成."
        read -p "按 Enter 键继续..." -r
        ;;
      2) break ;;
      *) error_message "无效的选择，请重试。" ;;
    esac
  done
}

trap '' INT

display_menu() {
  local current_version=$(get_sillytavern_version | head -n 1)
  local latest_version=$(get_sillytavern_version | tail -n 1)
  local node_version=$(node --version 2>/dev/null)
  local git_version=$(git --version 2>/dev/null | cut -d ' ' -f 3)
  local announcement=$(get_announcement)

  echo -e "
  ${GREEN}-------------------------------------${NC}
  ${GREEN}*     SillyTavern管理菜单     *${NC}
  ${GREEN}-------------------------------------${NC}
  ${YELLOW}By: Yozora  Bilibili: 601449119${NC}
  ${YELLOW}TG:https://t.me/Yzorask1${NC}
  ${GREEN}-------------------------------------${NC}
  ${GREEN}SillyTavern本地版本: $current_version${NC}
  ${GREEN}SillyTavern最新版本: $latest_version${NC}
  ${GREEN}-------------------------------------${NC}
  ${YELLOW}公告：${NC}
  ${YELLOW}$announcement${NC}
  ${GREEN}-------------------------------------${NC}
  ${YELLOW}1. 启动SillyTavern${NC}
  ${YELLOW}2. 备份用户数据${NC}
  ${YELLOW}3. 恢复用户数据${NC}
  ${YELLOW}4. 删除备份文件${NC}
  ${YELLOW}5. 日志错误解析${NC}
  ${YELLOW}6. 快捷功能菜单${NC}
  ${YELLOW}7. 退出${NC}
  ${GREEN}-------------------------------------${NC}
  "
}

display_menu

  read -p "请输入你的选择 (1-7): " choice

  if [[ ! "$choice" =~ ^[1-7]$ ]]; then
    error_message "无效的选择，请输入1到7之间的数字。"
    continue
  fi

  case $choice in
    1) start_sillytavern ;;
    2) backup_user_data ;;
    3) restore_user_data ;;
    4) delete_backup_files ;;
    5) view_logs ;;
    6) sillytavern_quick_config_menu ;;
    7) exit 0 ;;
  esac
done