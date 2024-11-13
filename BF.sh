#!/bin/bash

# 颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# SillyTavern 安装路径
INSTALL_PATH="$HOME/SillyTavern"

# 备份和恢复函数

backup_user_data() {
  parent_dir=$(dirname "$INSTALL_PATH")
  timestamp=$(date +%Y%m%d_%H%M%S)
  backup_filename="SillyTavern_data_backup_$timestamp.tar.gz"
  backup_path="$parent_dir/$backup_filename"

  tar -czvf "$backup_path" "$INSTALL_PATH/data" || { echo -e "${RED}创建备份失败: ${?}${NC}"; return 1; }
  echo -e "${GREEN}用户数据已备份到: $backup_path${NC}"
}

restore_user_data() {
  parent_dir=$(dirname "$INSTALL_PATH")
  backup_files=$(find "$parent_dir" -name "SillyTavern_data_backup_*tar.gz" 2>/dev/null)

  if [ -z "$backup_files" ]; then
    echo -e "${RED}未找到备份文件。${NC}"
    return 1
  fi

  echo -e "${YELLOW}找到以下备份文件：${NC}"
  select backup_file in $backup_files; do
    if [[ -n "$backup_file" ]]; then
      break
    else
      echo -e "${RED}无效的选择，请重试。${NC}"
    fi
  done

    if [[ -z "$backup_file" ]]; then # 可能按了Ctrl+C
        return 1
    fi

  read -r -p "确定要恢复此备份文件吗？(y/n) " confirm

  if [[ "$confirm" == "y" ]]; then
      temp_dir=$(mktemp -d) || { echo -e "${RED}创建临时目录失败${NC}"; return 1; }
      tar -xzvf "$backup_file" -C "$temp_dir" || { echo -e "${RED}解压备份文件失败${NC}"; rm -rf "$temp_dir"; return 1; }
      data_dir="$temp_dir/data"

      if [[ ! -d "$data_dir" ]]; then
          echo -e "${RED}备份文件不包含 data 目录${NC}"
          rm -rf "$temp_dir"
          return 1
      fi

      rm -rf "$INSTALL_PATH/data" || { echo -e "${RED}删除原 data 目录失败${NC}"; rm -rf "$temp_dir"; return 1; }
      mv "$data_dir" "$INSTALL_PATH/data" || { echo -e "${RED}移动 data 目录失败${NC}"; rm -rf "$temp_dir"; return 1; }
      rm -rf "$temp_dir"

      echo -e "${GREEN}数据恢复成功！${NC}"

  elif [[ "$confirm" == "n" ]]; then
      echo "已取消恢复操作。"

  else
      echo -e "${RED}无效的输入。${NC}"
  fi
}


# 菜单循环
while true; do
  clear
  echo -e "
  ${GREEN}-------------------------------------${NC}
  ${GREEN}*  SillyTavern 数据备份/恢复菜单  *${NC}
  ${GREEN}-------------------------------------${NC}
  ${YELLOW}1. 备份用户数据${NC}
  ${YELLOW}2. 恢复用户数据${NC}
  ${YELLOW}3. 退出${NC}
  ${GREEN}-------------------------------------${NC}
  "

  read -p "请输入你的选择: " choice

  case $choice in
    1) backup_user_data ;;
    2) restore_user_data ;;
    3) exit 0 ;;
    *) echo -e "${RED}无效的选择，请重试。${NC}" ;;
  esac

  read -p "按 Enter 键继续..." -r
done
