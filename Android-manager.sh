#!/bin/bash

# 颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 默认安装路径
INSTALL_PATH="$HOME/SillyTavern"

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
    ./start.sh || { echo -e "${RED}启动 SillyTavern 失败${NC}"; exit 1; }
}

# 备份用户数据
backup_user_data() {
    cd "$INSTALL_PATH" || { echo -e "${RED}切换到 SillyTavern 目录失败${NC}"; return 1; }
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_path="$HOME/SillyTavern_backup_$timestamp.tar.gz"
    tar -czf "$backup_path" data && \
    echo -e "${GREEN}备份成功: $backup_path${NC}" || \
    echo -e "${RED}备份失败${NC}"
    read -p "按 Enter 继续..." -r
}

# 数据恢复功能
restore_user_data() {
    cd "$INSTALL_PATH" || { echo -e "${RED}切换到 SillyTavern 目录失败${NC}"; return 1; }
    backup_files=$(find "$HOME" -maxdepth 1 -name "SillyTavern_backup_*.tar.gz" 2>/dev/null)

    if [ -z "$backup_files" ]; then
        echo -e "${RED}未找到备份文件${NC}"
        read -p "按 Enter 继续..." -r
        return 1
    fi

    echo -e "${YELLOW}备份文件列表：${NC}"
    i=1
    for file in $backup_files; do
        echo "$i. $(basename "$file")"
        i=$((i+1))
    done

    read -p "选择要恢复的备份 [1-$((i-1))]: " choice
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge "$i" ]; then
        echo -e "${RED}无效的选择${NC}"
        read -p "按 Enter 继续..." -r
        return 1
    fi

    selected_file=$(echo "$backup_files" | sed -n "${choice}p")
    tar -xzf "$selected_file" -C "$INSTALL_PATH" && \
    echo -e "${GREEN}恢复成功${NC}" || \
    echo -e "${RED}恢复失败${NC}"
    read -p "按 Enter 继续..." -r
}

# 删除备份文件
delete_backup_files() {
    backup_files=$(find "$HOME" -maxdepth 1 -name "SillyTavern_backup_*.tar.gz" 2>/dev/null)
    if [ -z "$backup_files" ]; then
        echo -e "${RED}未找到备份文件${NC}"
        read -p "按 Enter 继续..." -r
        return 0
    fi

    echo -e "${YELLOW}备份文件列表：${NC}"
    i=1
    for file in $backup_files; do
        echo "$i. $(basename "$file")"
        i=$((i+1))
    done

    read -p "选择要删除的备份 [1-$((i-1))] (多个用空格分隔): " choices
    for choice in $choices; do
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
            file_to_delete=$(echo "$backup_files" | sed -n "${choice}p")
            rm "$file_to_delete" && \
            echo -e "${GREEN}已删除: $(basename "$file_to_delete")${NC}" || \
            echo -e "${RED}删除失败: $(basename "$file_to_delete")${NC}"
        fi
    done
    read -p "按 Enter 继续..." -r
}

# 数据管理菜单
data_management_menu() {
    while true; do
        clear
        echo -e "\n${GREEN}[数据管理]${NC}"
        echo -e "1. 备份数据"
        echo -e "2. 恢复数据"
        echo -e "3. 删除备份"
        echo -e "4. 返回主菜单"

        read -p "请选择: " choice
        case $choice in
            1) backup_user_data ;;
            2) restore_user_data ;;
            3) delete_backup_files ;;
            4) break ;;
            *) echo -e "${RED}无效的选择${NC}" ;;
        esac
    done
}

# 导入角色卡
import_character_card() {
    read -p "输入角色卡URL: " image_url
    filename=$(basename "$image_url" | cut -d'?' -f1)
    data_dir="$INSTALL_PATH/data/default-user"

    if curl -s -L "$image_url" -o "/tmp/$filename"; then
        mkdir -p "$data_dir/thumbnails/avatar" "$data_dir/characters"
        cp "/tmp/$filename" "$data_dir/thumbnails/avatar/" && \
        cp "/tmp/$filename" "$data_dir/characters/" && \
        echo -e "${GREEN}角色卡导入成功${NC}" || \
        echo -e "${RED}角色卡导入失败${NC}"
        rm -f "/tmp/$filename"
    else
        echo -e "${RED}下载失败${NC}"
    fi
    read -p "按 Enter 继续..." -r
}

# API配置
configure_api() {
    echo -e "一键配置功能待更新..."
    read -p "按 Enter 继续..." -r
}

# 外观设置
configure_appearance() {
    echo -e "主题更改待更新..."
    read -p "按 Enter 继续..." -r
}

# 快捷菜单
quick_menu() {
    while true; do
        clear
        echo -e "\n${GREEN}[快捷功能]${NC}"
        echo -e "1. 角色导入"
        echo -e "2. 一键配置"
        echo -e "3. 主题更改"
        echo -e "4. 返回主菜单"

        read -p "请选择: " choice
        case $choice in
            1) import_character_card ;;
            2) configure_api ;;
            3) configure_appearance ;;
            4) break ;;
            *) echo -e "${RED}无效的选择${NC}" ;;
        esac
    done
}

# 主菜单
main_menu() {
    cd "$INSTALL_PATH" || { echo -e "${RED}SillyTavern未安装，请先运行安装脚本${NC}"; exit 1; }
    while true; do
        clear
        current_version=$(get_sillytavern_version | head -n 1)
        latest_version=$(get_sillytavern_version | tail -n 1)
        
        echo -e "\n${GREEN}SillyTavern 管理器${NC}"
