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

version_management_menu() {
    while true; do
        clear
        echo -e "\n${GREEN}=== 版本管理 ===${NC}"
        echo -e "1. 安装测试版"
        echo -e "2. 安装稳定版"
        echo -e "3. 更新最新版"
        echo -e "4. 返回主菜单"

        read -p "请选择: " choice
        case $choice in
            1) install_tavern "staging" ;;
            2) install_tavern "release" ;;
            3) update_tavern ;;
            4) return ;;
            *) echo -e "${RED}无效的选择${NC}" ;;
        esac
    done
}

install_tavern() {
    local branch="$1"
    clear
    echo -e "${YELLOW}[安装 ${branch} 分支]${NC}"
    echo -e "${RED}警告：此操作将完全重新安装 SillyTavern！${NC}"

    read -p "确认继续安装 ${branch} 分支？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}已取消安装${NC}"
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

    echo -e "\n${GREEN}安装完成！${NC}"
    echo -e "已安装 ${YELLOW}$branch${NC} 分支版本"
    read -p "按 Enter 返回主菜单..." -r
}

update_tavern() {
    clear
    echo -e "${YELLOW}[更新 SillyTavern 到最新版]${NC}"

    cd "$INSTALL_PATH" || { echo -e "${RED}切换到 SillyTavern 目录失败${NC}"; return 1; }

    echo -e "\n${YELLOW}正在更新...${NC}"
    git pull && {
        echo -e "${GREEN}✓ 更新成功${NC}"
        echo -e "\n${YELLOW}正在安装/更新依赖...${NC}"
        npm install && echo -e "${GREEN}✓ 依赖安装/更新成功${NC}" || echo -e "${YELLOW}⚠️ 依赖安装/更新可能失败，请手动执行 npm install${NC}"
    } || echo -e "${RED}× 更新失败，请检查网络或 Git 仓库状态${NC}"

    read -p "按 Enter 继续..." -r
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

add_gemini_model() {
    read -p "请输入 Gemini 模型名称 (例如: gemini-exp-9999): " model_name
    if [ -z "$model_name" ]; then
        echo -e "${RED}模型名称不能为空！${NC}"
        read -p "按 Enter 继续..." -r
        return 1
    fi

    local index_file="$INSTALL_PATH/public/index.html"
    if [ ! -f "$index_file" ]; then
        echo -e "${RED}错误：找不到文件 ${index_file}${NC}"
        read -p "按 Enter 继续..." -r
        return 1
    fi

    local temp_file=$(mktemp)
    if ! grep '<optgroup label="Subversions">' "$index_file" > /dev/null; then
        echo -e "${RED}错误：未在 ${index_file} 中找到 '<optgroup label=\"Subversions\">'${NC}"
        rm -f "$temp_file"
        read -p "按 Enter 继续..." -r
        return 1
    fi

    sed -i "/<optgroup label=\"Subversions\">/a \
                                        <option value=\"$model_name\">$model_name</option>" "$index_file"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}已添加 Gemini 模型: ${model_name}${NC}"
    else
        echo -e "${RED}添加 Gemini 模型失败${NC}"
    fi
    read -p "按 Enter 继续..." -r
}

delete_gemini_model() {
    read -p "请输入要删除的 Gemini 模型名称: " model_name
    if [ -z "$model_name" ]; then
        echo -e "${RED}模型名称不能为空！${NC}"
        read -p "按 Enter 继续..." -r
        return 1
    fi

    local index_file="$INSTALL_PATH/public/index.html"
    if [ ! -f "$index_file" ]; then
        echo -e "${RED}错误：找不到文件 ${index_file}${NC}"
        read -p "按 Enter 继续..." -r
        return 1
    fi

    if ! grep "<option value=\"$model_name\">$model_name</option>" "$index_file" > /dev/null; then
        echo -e "${YELLOW}警告：未找到模型 ${model_name}${NC}"
        read -p "按 Enter 继续..." -r
        return 0
    fi

    sed -i "/<option value=\"$model_name\">$model_name<\/option>/d" "$index_file"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}已删除 Gemini 模型: ${model_name}${NC}"
    else
        echo -e "${RED}删除 Gemini 模型失败${NC}"
    fi
    read -p "按 Enter 继续..." -r
}

miscellaneous_tools_menu() {
    while true; do
        clear
        echo -e "\n${GREEN}[杂项工具]${NC}"
        echo -e "1. 添加 Gemini 模型"
        echo -e "2. 删除 Gemini 模型"
        echo -e "3. 返回主菜单"

        read -p "请选择: " choice
        case $choice in
            1) add_gemini_model ;;
            2) delete_gemini_model ;;
            3) break ;;
            *) echo -e "${RED}无效的选择${NC}" ;;
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
        echo -e "3. 版本管理"
        echo -e "4. 杂项工具"
        echo -e "5. 退出"

        read -p "请选择: " choice
        case $choice in
            1) start_sillytavern ;;
            2) data_management_menu ;;
            3) version_management_menu ;;
            4) miscellaneous_tools_menu ;;
            5) exit 0 ;;
            *) echo -e "${RED}无效的选择${NC}" ;;
        esac
    done
}

trap '' INT

main_menu