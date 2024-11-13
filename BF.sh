#!/bin/bash

# 颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# SillyTavern 安装路径 (根据实际情况修改)
INSTALL_PATH="$HOME/SillyTavern"

# 备份/恢复数据目录
DATA_DIR="$INSTALL_PATH/data"

# 备份文件名前缀
BACKUP_PREFIX="SillyTavern_data_backup_"

# 备份目录 (与 SillyTavern 安装目录同级)
BACKUP_DIR=$(dirname "$INSTALL_PATH")


# 备份用户数据
backup_data() {
  timestamp=$(date +%Y%m%d_%H%M%S)
  backup_filename="$BACKUP_PREFIX$timestamp.tar.gz"
  backup_path="$BACKUP_DIR/$backup_filename"

  if tar -czvf "$backup_path" "$DATA_DIR"; then
    echo -e "${GREEN}用户数据已备份到: $backup_path${NC}"
  else
    echo -e "${RED}创建备份失败: ${?}${NC}"
    return 1
  fi
}

# 恢复用户数据
restore_data() {
  backup_files=$(find "$BACKUP_DIR" -name "$BACKUP_PREFIX*.tar.gz" 2>/dev/null)

  if [ -z "$backup_files" ]; then
    echo -e "${RED}未找到备份文件。${NC}"
    return 1
  fi

  echo -e "${YELLOW}找到以下备份文件：${NC}"
  select backup_file in $backup_files; do
    if [[ -n "$backup_file" ]]; then
      if tar -xzvf "$backup_file" -C "$INSTALL_PATH"; then
        echo -e "${GREEN}数据已从 $backup_file 恢复。${NC}"
      else
        echo -e "${RED}恢复数据失败: ${?}${NC}"
        return 1
      fi
      break  # 恢复成功后退出循环
    else
      echo -e "${RED}无效的选择，请重试。${NC}"
    fi
  done
}

# 主菜单
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
    1) backup_data ;;
    2) restore_data ;;
    3) exit 0 ;;
    *) echo -e "${RED}无效的选择，请重试。${NC}" ;;
  esac

  read -p "按 Enter 键继续..." -r
done
