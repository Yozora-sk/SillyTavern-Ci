#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

INSTALL_PATH="$HOME/SillyTavern"

CURRENT_VERSION=""
LATEST_VERSION=""
ANNOUNCEMENT=""
LAST_UPDATE=0

need_update() {
    current_time=$(date +%s)
    time_diff=$((current_time - LAST_UPDATE))
    if [ $time_diff -gt 300 ] || [ -z "$CURRENT_VERSION" ]; then
        return 0  
    fi
    return 1     
}

update_info() {
    cd "$INSTALL_PATH" || return
    CURRENT_VERSION=$(grep version package.json | cut -d '"' -f 4) || CURRENT_VERSION="未知版本"
    LATEST_VERSION=$(curl -s "https://raw.githubusercontent.com/SillyTavern/SillyTavern/refs/heads/release/package.json" | grep '"version"' | cut -d '"' -f 4) || LATEST_VERSION="未知版本"
    ANNOUNCEMENT=$(curl -s "https://raw.githubusercontent.com/Yozora-sk/SillyTavern-Ci/refs/heads/main/ANNOUNCEMENT") || ANNOUNCEMENT="获取公告失败"
    LAST_UPDATE=$(date +%s)
}

get_sillytavern_version() {
    local current_version=$(grep version package.json | cut -d '"' -f 4) || current_version="未知版本"
    local latest_version=$(curl -s https://raw.githubusercontent.com/SillyTavern/SillyTavern/refs/heads/release/package.json 2>/dev/null | grep '"version"' | awk -F '"' '{print $4}' || echo "未知版本")
    echo "$current_version"
    echo "$latest_version"
}

get_announcement() {
    announcement=$(curl -s "https://raw.githubusercontent.com/Yozora-sk/SillyTavern-Ci/refs/heads/main/ANNOUNCEMENT") || return 1
    echo "$announcement"
}

update_error_db() {
    local tmp_file="/data/data/com.termux/files/home/error_db_tmp"
    if curl -s "https://raw.githubusercontent.com/Yozora-sk/SillyTavern-Ci/refs/heads/main/Bug" -o "$tmp_file"; then
        mv "$tmp_file" "/data/data/com.termux/files/home/error_db"
        return 0
    else
        rm -f "$tmp_file"
        return 1
    fi
}

start_sillytavern() {
    echo "启动 SillyTavern..."
    cd "$INSTALL_PATH" || { echo -e "${RED}切换到 SillyTavern 目录失败${NC}"; exit 1; }
    ./start.sh || { echo -e "${RED}启动 SillyTavern 失败${NC}"; exit 1; }
}

backup_user_data() {
    cd "$INSTALL_PATH" || { echo -e "${RED}切换到 SillyTavern 目录失败${NC}"; return 1; }
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_path="$HOME/SillyTavern_backup_$timestamp.tar.gz"
    tar -czf "$backup_path" data && \
    echo -e "${GREEN}备份成功: $backup_path${NC}" || \
    echo -e "${RED}备份失败${NC}"
    read -p "按 Enter 继续..." -r
}

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

reinstall_menu() {
    while true; do
        clear
        echo -e "\n${GREEN}=== 重装酒馆 ===${NC}"
        echo -e "1. 彻底重装"
        echo -e "2. 保留角色重装"
        echo -e "3. 返回主菜单"
        
        read -p "请选择: " choice
        case $choice in
            1) reinstall_tavern ;;
            2) reinstall_tavern_keep_characters ;;
            3) return ;;
            *) echo -e "${RED}无效的选择${NC}" ;;
        esac
    done
}

reinstall_tavern_keep_characters() {
    clear
    echo -e "${YELLOW}[保留角色重装]${NC}"
    echo -e "${RED}警告：此操作将重新安装 SillyTavern，但会保留你的角色卡！${NC}"
    
    echo -e "\n${GREEN}请选择安装分支：${NC}"
    echo -e "1. 正式版"
    echo -e "2. 测试版"
    
    read -p "请选择分支 [1-2]: " branch_choice
    
    case $branch_choice in
        1) branch="release" ;;
        2) branch="staging" ;;
        *) 
            echo -e "${RED}无效的选择，将使用主分支${NC}"
            branch="main"
            sleep 2
        ;;
    esac

    read -p "确认继续？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}已取消重装${NC}"
        read -p "按 Enter 继续..." -r
        return
    fi

    cd "$HOME" || exit 1

    tmp_dir="$HOME/st_characters_backup_tmp"
    mkdir -p "$tmp_dir"

    echo -e "\n${YELLOW}1. 备份角色卡...${NC}"
    if [ -d "$INSTALL_PATH/data/default-user/characters" ]; then
        if cp -r "$INSTALL_PATH/data/default-user/characters/"* "$tmp_dir/" 2>/dev/null; then
            echo -e "${GREEN}✓ 角色卡备份成功${NC}"
        else
            echo -e "${YELLOW}! 没有找到角色卡或备份失败${NC}"
        fi
    else
        echo -e "${YELLOW}! 未找到角色卡目录${NC}"
    fi

    echo -e "\n${YELLOW}2. 删除现有安装...${NC}"
    if rm -rf "$INSTALL_PATH"; then
        echo -e "${GREEN}✓ 删除成功${NC}"
    else
        echo -e "${RED}× 删除失败${NC}"
        rm -rf "$tmp_dir"  # 清理临时目录
        return
    fi

    echo -e "\n${YELLOW}3. 克隆 $branch 分支...${NC}"
    if git clone -b "$branch" https://github.com/SillyTavern/SillyTavern.git "$INSTALL_PATH"; then
        echo -e "${GREEN}✓ 克隆成功${NC}"
        
        cd "$INSTALL_PATH" || exit 1
        echo -e "\n${YELLOW}4. 安装依赖...${NC}"
        if npm install; then
            echo -e "${GREEN}✓ 依赖安装成功${NC}"
        else
            echo -e "${RED}× 依赖安装失败${NC}"
        fi

        echo -e "\n${YELLOW}5. 恢复角色卡...${NC}"
        mkdir -p "$INSTALL_PATH/data/default-user/characters"
        
        if [ -d "$tmp_dir" ] && [ "$(ls -A "$tmp_dir" 2>/dev/null)" ]; then
            if cp -r "$tmp_dir/"* "$INSTALL_PATH/data/default-user/characters/"; then
                echo -e "${GREEN}✓ 角色卡恢复成功${NC}"
            else
                echo -e "${RED}× 角色卡恢复失败${NC}"
            fi
        else
            echo -e "${YELLOW}! 没有找到备份的角色卡${NC}"
        fi
    else
        echo -e "${RED}× 克隆失败，请检查网络${NC}"
    fi

    rm -rf "$tmp_dir"

    echo -e "\n${GREEN}重装完成！${NC}"
    echo -e "已安装 ${YELLOW}$branch${NC} 分支版本"
    read -p "按 Enter 返回主菜单..." -r
}

reinstall_tavern() {
    clear
    echo -e "${YELLOW}[彻底重装]${NC}"
    echo -e "${RED}警告：此操作将完全重新安装 SillyTavern！${NC}"
    
    echo -e "\n${GREEN}请选择安装分支：${NC}"
    echo -e "1. 正式版"
    echo -e "2. 测试版"
    
    read -p "请选择分支 [1-2]: " branch_choice
    
    case $branch_choice in
        1) branch="release" ;;
        2) branch="staging" ;;
        *) 
            echo -e "${RED}无效的选择，将使用主分支${NC}"
            branch="main"
            sleep 2
        ;;
    esac
    
    read -p "确认继续安装？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}已取消重装${NC}"
        read -p "按 Enter 继续..." -r
        return
    fi

    cd "$HOME" || exit 1

    echo -e "\n${YELLOW}1. 删除现有安装...${NC}"
    if rm -rf "$INSTALL_PATH"; then
        echo -e "${GREEN}✓ 删除成功${NC}"
    else
        echo -e "${RED}× 删除失败${NC}"
        return
    fi

    echo -e "\n${YELLOW}2. 克隆 $branch 分支...${NC}"
    if git clone -b "$branch" https://github.com/SillyTavern/SillyTavern.git "$INSTALL_PATH"; then
        echo -e "${GREEN}✓ 克隆成功${NC}"
        
        cd "$INSTALL_PATH" || exit 1
        echo -e "\n${YELLOW}3. 安装依赖...${NC}"
        if npm install; then
            echo -e "${GREEN}✓ 依赖安装成功${NC}"
        else
            echo -e "${RED}× 依赖安装失败${NC}"
        fi
    else
        echo -e "${RED}× 克隆失败，请检查网络${NC}"
    fi

    echo -e "\n${GREEN}重装完成！${NC}"
    echo -e "已安装 ${YELLOW}$branch${NC} 分支版本"
    read -p "按 Enter 返回主菜单..." -r
}

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

import_character_card() {
    echo -e "${YELLOW}开始导入角色卡...${NC}"
    
    read -p "输入角色卡URL: " image_url
    filename=$(basename "$image_url" | cut -d'?' -f1)

    tmp_dir="/data/data/com.termux/files/home/tmp_character"
    rm -rf "$tmp_dir" 2>/dev/null
    mkdir -p "$tmp_dir"
    chmod 777 "$tmp_dir"

    echo -e "${YELLOW}正在下载文件: $filename${NC}"
    
    if curl -L "$image_url" -o "$tmp_dir/$filename"; then
        echo -e "${GREEN}文件下载成功${NC}"
        
        target_dirs=(
            "$INSTALL_PATH/data/default-user/characters"
            "$INSTALL_PATH/data/default-user/thumbnails/avatar"
        )
        
        for dir in "${target_dirs[@]}"; do
            mkdir -p "$dir"
            chmod 777 "$dir"
        done
        
        for dir in "${target_dirs[@]}"; do
            cp "$tmp_dir/$filename" "$dir/" && \
            chmod 666 "$dir/$filename"
            if [ $? -ne 0 ]; then
                echo -e "${RED}复制到 $dir 失败${NC}"
                rm -rf "$tmp_dir"
                return 1
            fi
        done
        
        echo -e "${GREEN}角色卡导入成功！${NC}"
        echo -e "${GREEN}文件已保存为: $filename${NC}"
    else
        echo -e "${RED}下载失败${NC}"
        echo -e "${YELLOW}尝试的URL: $image_url${NC}"
    fi

    rm -rf "$tmp_dir"
    read -p "按 Enter 继续..." -r
}

configure_api() {
    echo -e "一键配置功能待更新..."
    read -p "按 Enter 继续..." -r
}

configure_appearance() {
    echo -e "主题更改待更新..."
    read -p "按 Enter 继续..." -r
}

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

search_error() {
    local search_term="$1"
    local error_db="/data/data/com.termux/files/home/error_db"
    local results=()
    local found=0

    search_term=$(echo "$search_term" | tr '[:upper:]' '[:lower:]')

    if [ ! -f "$error_db" ]; then
        echo -e "${YELLOW}正在更新错误数据库...${NC}"
        if ! update_error_db; then
            echo -e "${RED}无法获取错误数据库，请检查网络连接${NC}"
            return 1
        fi
    fi

    while IFS= read -r line; do
        local error_key=$(echo "$line" | cut -d'#' -f1 | tr '[:upper:]' '[:lower:]')
        
        if [[ "$error_key" == "$search_term" ]]; then
            local solution=$(echo "$line" | cut -d'#' -f2-)
            if [ ! -z "$solution" ]; then
                results+=("$solution")
                found=1
            fi
        fi
    done < "$error_db"

    if [ $found -eq 1 ]; then
        echo -e "${GREEN}找到以下解决方案：${NC}"
        for solution in "${results[@]}"; do
            echo -e "${YELLOW}$solution${NC}"
        done
    else
        echo -e "${RED}未找到相关错误的解决方案${NC}"
    fi
}

error_query_menu() {
    while true; do
        clear
        echo -e "${GREEN}设备信息${NC}"
        echo -e "制造商: ${YELLOW}$(getprop ro.product.manufacturer)${NC}"
        echo -e "型号: ${YELLOW}$(getprop ro.product.model)${NC}"
        echo -e "Android版本: ${YELLOW}$(getprop ro.build.version.release)${NC}"
        echo -e "CPU架构: ${YELLOW}$(getprop ro.product.cpu.abi)${NC}"

        echo -e "${GREEN}=================${NC}"       
        echo -e "${GREEN}报错查询${NC}"
        echo -e "${YELLOW}使用说明：${NC}"
        echo -e "未被记录的报错请反馈给我"
        echo -e "查询方式：输入你的报错主题，无需附带内容"
        echo -e "不可以省略空格，例子:API returned an error"
        echo -e "${GREEN}=================${NC}"
        echo -e "1. 查询报错"
        echo -e "2. 更新错误数据库"
        echo -e "3. 返回主菜单"

        read -p "请选择: " choice
        case $choice in
            1)
                echo -e "\n${YELLOW}请输入报错内容：${NC}"
                read -r error_input
                if [ ! -z "$error_input" ]; then
                    search_error "$error_input"
                    read -p "按 Enter 继续..." -r
                fi
                ;;
            2)
                echo -e "\n${YELLOW}正在更新错误数据库...${NC}"
                if update_error_db; then
                    echo -e "${GREEN}更新成功！${NC}"
                else
                    echo -e "${RED}更新失败，请检查网络连接${NC}"
                fi
                read -p "按 Enter 继续..." -r
                ;;
            3)
                return
                ;;
            *)
                echo -e "${RED}无效的选择${NC}"
                read -p "按 Enter 继续..." -r
                ;;
        esac
    done
}

show_menu_info() {
    if need_update; then
        update_info
    fi
    
    echo -e "\n${GREEN}SillyTavern 管理器${NC}"
    echo -e "当前版本: $CURRENT_VERSION"
    echo -e "最新版本: $LATEST_VERSION"
    
    echo -e "\n${YELLOW}====== 公告 ======${NC}"
    echo -e "$ANNOUNCEMENT"
    echo -e "${YELLOW}=================${NC}"
}

main_menu() {
    cd "$INSTALL_PATH" || { echo -e "${RED}SillyTavern未安装，请先运行安装脚本${NC}"; exit 1; }
    
    update_info
    
    while true; do
        clear
        show_menu_info
        
        echo -e "\n1. 启动程序"
        echo -e "2. 数据管理"
        echo -e "3. 快捷功能"
        echo -e "4. 重装酒馆"
        echo -e "5. 报错查询"
        echo -e "6. 退出"

        read -p "请选择: " choice
        case $choice in
            1) start_sillytavern ;;
            2) data_management_menu ;;
            3) quick_menu ;;
            4) reinstall_menu ;;
            5) error_query_menu ;;
            6) exit 0 ;;
            *) echo -e "${RED}无效的选择${NC}" ;;
        esac
    done
}

trap '' INT

main_menu