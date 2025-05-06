#!/bin/bash

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m' # 添加蓝色用于脚本信息
NC='\033[0m' # 无颜色

# --- 配置 ---
INSTALL_PATH="$HOME/SillyTavern"       # SillyTavern 安装路径
SCRIPT_VERSION="1.1"                  # 当前脚本版本 (手动更新)
SCRIPT_REPO_URL="https://github.com/Yozora-sk/SillyTavern-Manager.git" # 脚本的 Git 仓库地址 (示例)
CLEWDR_INSTALL_PATH="$HOME/clewdr"     # Clewdr安装路径
CLEWDR_SOFTWARE_NAME="clewdr"

# --- 版本信息 ---
ST_CURRENT_VERSION="未知版本"
ST_LATEST_VERSION="未知版本"
CLEWDR_CURRENT_VERSION="未知版本"
CLEWDR_LATEST_VERSION="未知版本"

# --- 状态变量 ---
ANNOUNCEMENT="获取公告失败"
GEOGRAPHIC_LOCATION="检测中..."  # 修改状态名称
LAST_UPDATE=0

get_version_color() {
    local current_version_raw="$1"
    local latest_version_raw="$2"
    local default_color="${YELLOW}"

    if [[ "$current_version_raw" == *"失败"* || "$latest_version_raw" == *"失败"* || \
          "$current_version_raw" == "未知版本" || "$latest_version_raw" == "未知版本" || \
          "$current_version_raw" == "未安装" || "$latest_version_raw" == "未知" ]]; then
        if [[ "$current_version_raw" == *"失败"* || "$current_version_raw" == "未知版本" || "$current_version_raw" == "未安装" ]]; then
             echo "${RED}"
        else
             echo "$default_color"
        fi
        return
    fi

    local current_version="${current_version_raw#v}" 
    local latest_version="${latest_version_raw#v}" 
    local version_regex='^[0-9]+(\.[0-9]+)*$'
    if ! [[ "$current_version" =~ $version_regex && "$latest_version" =~ $version_regex ]]; then
        echo "$default_color"
        return
    fi
    
    if [ "$current_version" == "$latest_version" ]; then
        echo "${GREEN}"
    elif version_gt "$latest_version" "$current_version" ; then
        echo "${RED}"
    else
        echo "${YELLOW}"
    fi
}

version_gt() {
    test "$(printf '%s\n' "$2" "$1" | sort -V | head -n 1)" == "$2"
}

# 检查是否需要更新 SillyTavern 信息 (缓存时间 5 分钟)
need_update() {
    local current_time
    local time_diff
    current_time=$(date +%s)
    time_diff=$((current_time - LAST_UPDATE))
    # 如果距离上次更新超过 300 秒 或 版本信息为空
    if [ $time_diff -gt 300 ] || [ "$ST_CURRENT_VERSION" == "未知版本" ] || [ "$CLEWDR_CURRENT_VERSION" == "未知版本" ]; then
        return 0 # 返回 0 表示需要更新
    fi
    return 1 # 返回 1 表示不需要更新
}

# 获取 Clewdr最新版本 (这个函数需要根据你的实际获取方式修改)
get_latest_clewdr_version() {
    local CLEWDR_GH_API_URL="https://api.github.com/repos/Xerxes-2/clewdr/releases/latest"
    local latest_info=$(curl -s --connect-timeout 10 "$CLEWDR_GH_API_URL")
    if [ -z "$latest_info" ]; then
        echo "获取最新Clewdr版本失败"
        return
    fi
    local LATEST_CLEWDR_VERSION=$(echo "$latest_info" | jq -r '.tag_name // empty')
    echo "$LATEST_CLEWDR_VERSION"
}

# 更新 SillyTavern 和 Clewdr 版本和公告信息
update_info() {
    # 切换到安装目录，如果失败则返回
    cd "$INSTALL_PATH" || return 1

    # 获取当前版本 (使用 jq 更稳健，如果安装了的话)
    if command -v jq &> /dev/null; then
        ST_CURRENT_VERSION=$(jq -r '.version' package.json 2>/dev/null) || ST_CURRENT_VERSION="读取本地版本失败"
    else
        # jq 未安装时回退到 grep/cut，但更脆弱
        ST_CURRENT_VERSION=$(grep '"version":' package.json | head -n 1 | cut -d '"' -f 4) || ST_CURRENT_VERSION="读取本地版本失败 (建议安装jq)"
    fi
    [ -z "$ST_CURRENT_VERSION" ] && ST_CURRENT_VERSION="读取本地版本失败" # 再次检查空值

    # 获取最新版本
    ST_LATEST_VERSION=$(curl -s "https://raw.githubusercontent.com/SillyTavern/SillyTavern/release/package.json" | \
                     (command -v jq &> /dev/null && jq -r '.version' 2>/dev/null || grep '"version":' | head -n 1 | cut -d '"' -f 4) \
                    ) || ST_LATEST_VERSION="获取最新版本失败"
    [ -z "$ST_LATEST_VERSION" ] && ST_LATEST_VERSION="获取最新版本失败" # 再次检查空值


    # 获取公告
    ANNOUNCEMENT=$(curl -s "https://raw.githubusercontent.com/Yozora-sk/SillyTavern-Ci/main/ANNOUNCEMENT") || ANNOUNCEMENT="获取公告失败"
    [ -z "$ANNOUNCEMENT" ] && ANNOUNCEMENT="获取公告失败或公告为空"

    # 获取 Clewdr 版本信息
    if [ -f "$CLEWDR_INSTALL_PATH/$CLEWDR_SOFTWARE_NAME" ]; then
        if [ -f "$CLEWDR_INSTALL_PATH/version.txt" ]; then
            CLEWDR_CURRENT_VERSION=$(cat "$CLEWDR_INSTALL_PATH/version.txt")
        else
            CLEWDR_CURRENT_VERSION="未找到版本文件"
        fi
        CLEWDR_LATEST_VERSION=$(get_latest_clewdr_version) || CLEWDR_LATEST_VERSION="获取最新版本失败"

    else
        CLEWDR_CURRENT_VERSION="未安装"
        CLEWDR_LATEST_VERSION="未知"
    fi

    LAST_UPDATE=$(date +%s)
}

# 检查地理位置
check_geographic_location() {
    USER_COUNTRY=$(curl -s --connect-timeout 5 ipinfo.io/country)
    if [ -n "$USER_COUNTRY" ]; then
        if [ "$USER_COUNTRY" = "CN" ]; then
            GEOGRAPHIC_LOCATION="${RED}中国${NC}"
        else
            GEOGRAPHIC_LOCATION="${GREEN}境外${NC}"
        fi
    else
        GEOGRAPHIC_LOCATION="${YELLOW}无法检测${NC}"
    fi
}

# 启动 SillyTavern
start_sillytavern() {
    echo -e "${GREEN}启动SillyTavern...${NC}"
    cd "$INSTALL_PATH" || { echo -e "${RED}错误:无法切换到SillyTavern目录:${INSTALL_PATH}${NC}"; read -p "按Enter继续..." -r; return 1; }
    if [ ! -f "./start.sh" ]; then
        echo -e "${RED}错误:未找到启动脚本start.sh${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi
    # 执行 start.sh
    ./start.sh || { echo -e "${RED}启动SillyTavern失败，请检查错误信息。${NC}"; read -p "按Enter继续..." -r; return 1; }
    echo -e "${YELLOW}SillyTavern正在启动...${NC}"
}

start_clewdr() {
    local clewdr_executable="${CLEWDR_INSTALL_PATH}/${CLEWDR_SOFTWARE_NAME}"

    # 检查 Clewdr 安装目录是否存在
    if [ ! -d "$CLEWDR_INSTALL_PATH" ]; then
        echo -e "${RED}错误: Clewdr 安装目录未找到: ${CLEWDR_INSTALL_PATH}${NC}"
        echo -e "${YELLOW}请确保 Clewdr 已正确安装。${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi

    # 检查 Clewdr 可执行文件是否存在
    if [ ! -f "$clewdr_executable" ]; then
        echo -e "${RED}错误: 未找到 Clewdr 可执行文件: ${clewdr_executable}${NC}"
        echo -e "${YELLOW}请检查 Clewdr 安装是否完整。${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi

    # 检查可执行权限
    if [ ! -x "$clewdr_executable" ]; then
        echo -e "${RED}错误: Clewdr 可执行文件没有执行权限: ${clewdr_executable}${NC}"
        echo -e "${YELLOW}请尝试运行 'chmod +x ${clewdr_executable}'${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi

    echo -e "${GREEN}正在切换到 Clewdr 目录并启动... (按 Ctrl+C 停止)${NC}"
    echo -e "${BLUE}工作目录: ${CLEWDR_INSTALL_PATH}${NC}"

    # 记录当前目录，切换，执行，然后切回
    # 使用 pushd/popd 来管理目录切换更安全
    pushd "$CLEWDR_INSTALL_PATH" > /dev/null || {
        echo -e "${RED}错误: 无法切换到 Clewdr 目录: ${CLEWDR_INSTALL_PATH}${NC}";
        read -p "按Enter继续..." -r;
        return 1;
    }

    # 执行 clewdr
    echo -e "${YELLOW}正在执行: ./${CLEWDR_SOFTWARE_NAME}${NC}"
    "./${CLEWDR_SOFTWARE_NAME}"

    local exit_status=$?
    echo -e "\n${YELLOW}Clewdr 进程已退出 (退出状态: $exit_status)。${NC}"

    # 切回原来的目录
    popd > /dev/null || echo -e "${YELLOW}警告: 无法切回原始目录。${NC}"

    read -p "按Enter返回主菜单..." -r
}

# 备份用户数据
backup_user_data() {
    cd "$INSTALL_PATH" || { echo -e "${RED}错误:无法切换到SillyTavern目录:${INSTALL_PATH}${NC}"; return 1; }
    if [ ! -d "data" ]; then
        echo -e "${RED}错误:未找到'data'目录，无法备份。${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi
    local timestamp
    local backup_path
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_path="$HOME/SillyTavern_backup_$timestamp.tar.gz"
    echo -e "${YELLOW}正在备份'data'目录到${backup_path}...${NC}"
    if tar -czf "$backup_path" data; then
        echo -e "${GREEN}备份成功:$backup_path${NC}"
    else
        echo -e "${RED}备份失败!${NC}"
        # 尝试删除可能产生的空或不完整备份文件
        rm -f "$backup_path" 2>/dev/null
    fi
    read -p "按Enter继续..." -r
}

# 恢复用户数据
restore_user_data() {
    # 首先检查 SillyTavern 目录是否存在
    if [ ! -d "$INSTALL_PATH" ]; then
         echo -e "${RED}错误:SillyTavern安装目录不存在:${INSTALL_PATH}${NC}"
         read -p "按Enter继续..." -r
         return 1
    fi

    local backup_files
    local file_list=() # 使用数组存储文件列表
    local i=1
    local choice
    local selected_file

    # 查找备份文件
    echo -e "${YELLOW}正在搜索备份文件($HOME/SillyTavern_backup_*.tar.gz)...${NC}"
    # 使用 find 和 mapfile 读取，更安全处理带空格的文件名
    mapfile -t backup_files < <(find "$HOME" -maxdepth 1 -name "SillyTavern_backup_*.tar.gz" -print0 | xargs -0 -r ls -t)

    if [ ${#backup_files[@]} -eq 0 ]; then
        echo -e "${RED}未找到任何备份文件。${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi

    echo -e "${YELLOW}找到以下备份文件(按时间倒序):${NC}"
    for file in "${backup_files[@]}"; do
        echo "$i.$(basename "$file")"
        file_list+=("$file") # 将完整路径存入数组
        i=$((i+1))
    done

    read -p "请选择要恢复的备份文件序号[1-$((i-1))]:" choice
    # 输入验证 (必须是数字且在范围内)
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge "$i" ]; then
        echo -e "${RED}无效的选择。${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi

    selected_file="${file_list[$((choice-1))]}" # 从数组获取选中的文件

    echo -e "${YELLOW}准备从'$(basename "$selected_file")'恢复数据到'${INSTALL_PATH}'...${NC}"
    read -p "这将覆盖'${INSTALL_PATH}/data'目录(如果存在)，确认恢复?(y/N):" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}已取消恢复。${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi

    # 执行恢复
    # 先尝试切换目录，如果失败则不执行解压
    if cd "$INSTALL_PATH"; then
        if tar -xzf "$selected_file" -C "$INSTALL_PATH"; then # 指定解压到安装目录
            echo -e "${GREEN}数据恢复成功!${NC}"
        else
            echo -e "${RED}数据恢复失败!请检查文件权限或备份文件是否完整。${NC}"
        fi
    else
         echo -e "${RED}错误:无法切换到SillyTavern目录:${INSTALL_PATH}${NC}"
    fi
    read -p "按Enter继续..." -r
}

# 删除备份文件
delete_backup_files() {
    local backup_files
    local file_list=()
    local i=1
    local choices
    local choice
    local file_to_delete

    echo -e "${YELLOW}正在搜索备份文件($HOME/SillyTavern_backup_*.tar.gz)...${NC}"
    mapfile -t backup_files < <(find "$HOME" -maxdepth 1 -name "SillyTavern_backup_*.tar.gz" -print0 | xargs -0 -r ls -t)

    if [ ${#backup_files[@]} -eq 0 ]; then
        echo -e "${RED}未找到任何备份文件。${NC}"
        read -p "按Enter继续..." -r
        return 0 # 没有文件可删，正常退出
    fi

    echo -e "${YELLOW}找到以下备份文件(按时间倒序):${NC}"
    for file in "${backup_files[@]}"; do
        echo "$i.$(basename "$file")"
        file_list+=("$file")
        i=$((i+1))
    done

    read -p "输入要删除的备份文件序号[1-$((i-1))] (多个用空格分隔):" choices
    if [ -z "$choices" ]; then
        echo -e "${YELLOW}未选择任何文件。${NC}"
        read -p "按Enter继续..." -r
        return 0
    fi

    local deleted_count=0
    local failed_count=0
    for choice in $choices; do
        # 验证每个输入是否为有效数字和范围
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge "$i" ]; then
            echo -e "${YELLOW}警告:无效的序号'$choice'，已跳过。${NC}"
            continue
        fi

        file_to_delete="${file_list[$((choice-1))]}"
        if [ -f "$file_to_delete" ]; then
            read -p "确认删除'$(basename "$file_to_delete")'?(y/N):" confirm_del
            if [[ "$confirm_del" =~ ^[Yy]$ ]]; then
                if rm "$file_to_delete"; then
                    echo -e "${GREEN}已删除:$(basename "$file_to_delete")${NC}"
                    deleted_count=$((deleted_count + 1))
                else
                    echo -e "${RED}删除失败:$(basename "$file_to_delete")${NC}"
                    failed_count=$((failed_count + 1))
                fi
            else
                echo -e "${YELLOW}已跳过删除:$(basename "$file_to_delete")${NC}"
            fi
        else
             echo -e "${RED}错误:文件不存在'$file_to_delete' (可能已被删除)。${NC}"
             failed_count=$((failed_count + 1))
        fi
    done
    echo -e "${GREEN}操作完成。成功删除${deleted_count}个文件，失败${failed_count}个。${NC}"
    read -p "按Enter继续..." -r
}

# 安装 SillyTavern (指定分支)
install_tavern() {
    local branch="$1" # "staging" 或 "release"
    clear
    echo -e "${YELLOW}===安装SillyTavern(${branch}分支)===${NC}"
    echo -e "${RED}警告：此操作将【完全删除】现有的SillyTavern安装目录(${INSTALL_PATH})！${NC}"
    echo -e "${YELLOW}强烈建议在继续之前备份您的数据！${NC}"

    read -p "您确定要继续安装${branch}分支吗?(y/N):" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}已取消安装。${NC}"
        read -p "按Enter继续..." -r
        return
    fi

    # 检查 Git 和 npm 是否安装
    if ! command -v git &> /dev/null; then
        echo -e "${RED}错误:未找到'git'命令。请先安装git。${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi
     if ! command -v npm &> /dev/null; then
        echo -e "${RED}错误:未找到'npm'命令。请先安装Node.js和npm。${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi

    cd "$HOME" || { echo -e "${RED}错误:无法切换到主目录'$HOME'。${NC}"; exit 1; } # 如果连家目录都进不去，脚本无法继续

    echo -e "\n${YELLOW}1.正在删除现有安装目录...${NC}"
    # 安全性检查：确保 INSTALL_PATH 不为空且不是 HOME 目录或根目录
    if [ -z "$INSTALL_PATH" ] || [ "$INSTALL_PATH" == "$HOME" ] || [ "$INSTALL_PATH" == "/" ]; then
        echo -e "${RED}错误:安装路径(${INSTALL_PATH})无效或不安全，已中止删除。${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi
    # 只有目录存在时才执行删除
    if [ -d "$INSTALL_PATH" ]; then
        if rm -rf "$INSTALL_PATH"; then
            echo -e "${GREEN}✓旧目录已删除${NC}"
        else
            echo -e "${RED}×删除旧目录失败!请检查权限或手动删除:${INSTALL_PATH}${NC}"
            read -p "按Enter继续..." -r
            return 1
        fi
    else
         echo -e "${YELLOW}✓现有安装目录不存在，无需删除。${NC}"
    fi

    echo -e "\n${YELLOW}2.正在从GitHub克隆${branch}分支...${NC}"
    if git clone --depth 1 -b "$branch" https://github.com/SillyTavern/SillyTavern.git "$INSTALL_PATH"; then
        echo -e "${GREEN}✓克隆成功${NC}"

        cd "$INSTALL_PATH" || { echo -e "${RED}错误:克隆后无法切换到安装目录:${INSTALL_PATH}${NC}"; read -p "按Enter继续..." -r; return 1; }

        echo -e "\n${YELLOW}3.正在安装依赖(npm install)...这可能需要一些时间。${NC}"
        if npm install; then
            echo -e "${GREEN}✓依赖安装成功${NC}"
        else
            echo -e "${RED}×依赖安装失败!请检查网络连接和npm/Node.js环境，或稍后手动执行'npm install'。${NC}"
            # 即使依赖失败，也告知用户安装过程基本完成
            echo -e "${YELLOW}安装过程已完成，但依赖安装遇到问题。${NC}"
            read -p "按Enter返回主菜单..." -r
            return 1 # 返回错误状态
        fi
    else
        echo -e "${RED}×克隆失败，请检查网络连接或Git是否能访问GitHub。${NC}"
        # 克隆失败时尝试清理可能创建的空目录
        rm -rf "$INSTALL_PATH" 2>/dev/null
        read -p "按Enter返回主菜单..." -r
        return 1 # 返回错误状态
    fi

    echo -e "\n${GREEN}SillyTavern(${branch}分支)安装完成！${NC}"
    # 安装完成后，强制更新一次信息
    update_info
    read -p "按Enter返回主菜单..." -r
}

# 更新 SillyTavern 到当前分支的最新版
update_tavern() {
    clear
    check_geographic_location # 获取地理位置

    if [ "$GEOGRAPHIC_LOCATION" = "${RED}中国${NC}" ]; then
        echo -e "${RED}你无法执行更新操作，因为你位于中国。${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi

    echo -e "${YELLOW}===更新SillyTavern到最新版===${NC}"

    cd "$INSTALL_PATH" || { echo -e "${RED}错误:无法切换到SillyTavern目录:${INSTALL_PATH}${NC}"; read -p "按Enter继续..." -r; return 1; }

    # 检查 .git 目录是否存在，确认是 Git 仓库
    if [ ! -d ".git" ]; then
        echo -e "${RED}错误:${INSTALL_PATH}不是一个有效的Git仓库。无法使用gitpull更新。${NC}"
        echo -e "${YELLOW}您可能需要通过“版本管理”中的安装选项来重新安装。${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi

    echo -e "\n${YELLOW}1.正在从Git拉取最新代码(git pull)...${NC}"
    if git pull; then
        echo -e "${GREEN}✓代码更新成功${NC}"
        echo -e "\n${YELLOW}2.正在检查并安装/更新依赖(npm install)...这可能需要一些时间。${NC}"
        if npm install; then
            echo -e "${GREEN}✓依赖安装/更新成功${NC}"
        else
            # 即使依赖失败，更新也算部分成功
            echo -e "${YELLOW}⚠️依赖安装/更新可能失败，请检查npm/Node.js环境或稍后手动执行'npm install'。${NC}"
        fi
        # 更新成功后，刷新信息
        update_info
    else
        echo -e "${RED}×代码更新失败!${NC}"
        echo -e "${YELLOW}可能原因：${NC}"
        echo -e "${YELLOW}-网络连接问题。${NC}"
        echo -e "${YELLOW}-您本地修改了代码导致冲突(请先stash或commit更改)。${NC}"
        echo -e "${YELLOW}-Git仓库状态异常。${NC}"
    fi

    read -p "按Enter继续..." -r
}

# 添加自定义 Gemini 模型到 index.html (依然脆弱，谨慎使用)
add_gemini_model() {
    local index_file="$INSTALL_PATH/public/index.html"
    if [ ! -f "$index_file" ]; then
        echo -e "${RED}错误:找不到SillyTavern的界面文件${index_file}${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi

    read -p "请输入要添加的Gemini模型名称(例如:gemini-pro-1.5):" model_name
    if [ -z "$model_name" ]; then
        echo -e "${RED}错误:模型名称不能为空！${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi

    # 检查模型是否已存在
    if grep -q "<option value=\"$model_name\">$model_name</option>" "$index_file"; then
        echo -e "${YELLOW}警告:模型'$model_name'似乎已经存在于${index_file}中。${NC}"
        read -p "按Enter继续..." -r
        return 0
    fi

    # 找到插入点 (更健壮一点的模式匹配)
    local insert_marker="<optgroup label=\"Subversions\">"
    if ! grep -q "$insert_marker" "$index_file"; then
        echo -e "${RED}错误:未能在${index_file}中找到Gemini模型的插入标记'${insert_marker}'。文件结构可能已更改。${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi

    # 使用 sed 在标记后添加新行 (注意转义)
    # 创建备份
    cp "$index_file" "${index_file}.bak"
    echo -e "${YELLOW}正在尝试向${index_file}添加模型...(已创建备份.bak)${NC}"
    # 使用 awk 可能更可靠，但 sed 也能工作
    sed -i "/${insert_marker}/a \                        <option value=\"${model_name}\">${model_name}<\/option>" "$index_file"

    # 检查 sed 是否成功执行 (这只能检查命令本身是否出错，不保证逻辑正确)
    if [ $? -eq 0 ]; then
         # 再次检查是否真的添加成功
         if grep -q "<option value=\"$model_name\">$model_name</option>" "$index_file"; then
              echo -e "${GREEN}成功添加Gemini模型:${model_name}到${index_file}${NC}"
              echo -e "${YELLOW}注意:SillyTavern更新可能会覆盖此更改。${NC}"
         else
             echo -e "${RED}添加Gemini模型失败。sed命令执行了但未成功添加。请检查文件内容。${NC}"
             # 尝试恢复备份
             mv "${index_file}.bak" "$index_file"
         fi
    else
        echo -e "${RED}使用sed添加Gemini模型时出错。${NC}"
        # 尝试恢复备份
        mv "${index_file}.bak" "$index_file"
    fi
    read -p "按Enter继续..." -r
}

# 删除自定义 Gemini 模型 (依然脆弱)
delete_gemini_model() {
    local index_file="$INSTALL_PATH/public/index.html"
    if [ ! -f "$index_file" ]; then
        echo -e "${RED}错误:找不到SillyTavern的界面文件${index_file}${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi

    read -p "请输入要删除的Gemini模型名称:" model_name
    if [ -z "$model_name" ]; then
        echo -e "${RED}错误:模型名称不能为空！${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi

    # 检查模型是否存在
    local model_line_pattern="<option value=\"$model_name\">$model_name</option>"
    if ! grep -q "$model_line_pattern" "$index_file"; then
        echo -e "${YELLOW}警告:在${index_file}中未找到模型'$model_name'，无需删除。${NC}"
        read -p "按Enter继续..." -r
        return 0
    fi

    # 创建备份
    cp "$index_file" "${index_file}.bak"
    echo -e "${YELLOW}正在尝试从${index_file}删除模型'$model_name'...(已创建备份.bak)${NC}"

    # 使用 sed 删除匹配行 (注意特殊字符转义)
    # 使用 /.../d 模式，对特殊字符更安全些
    sed -i "/<option value=\"${model_name//\//\\\/}\">${model_name//\//\\\/}<\/option>/d" "$index_file"

    if [ $? -eq 0 ]; then
        # 再次检查是否真的删除了
        if ! grep -q "$model_line_pattern" "$index_file"; then
            echo -e "${GREEN}已成功从${index_file}删除模型:${model_name}${NC}"
            echo -e "${YELLOW}注意:SillyTavern更新可能会重新添加官方模型。${NC}"
        else
             echo -e "${RED}删除Gemini模型失败。sed命令执行了但未成功删除。请检查文件内容。${NC}"
             # 尝试恢复备份
             mv "${index_file}.bak" "$index_file"
        fi
    else
        echo -e "${RED}使用sed删除Gemini模型时出错。${NC}"
         # 尝试恢复备份
         mv "${index_file}.bak" "$index_file"
    fi
    read -p "按Enter继续..." -r
}

# 更新本管理脚本
update_script() {
    clear
    echo -e "${YELLOW}===更新管理脚本===${NC}"

    # 获取脚本所在的目录
    local script_path
    local script_dir
    script_path=$(readlink -f "${BASH_SOURCE[0]}") || script_path="${BASH_SOURCE[0]}" # 处理软链接
    script_dir=$(dirname "$script_path")

    echo "脚本当前所在目录:$script_dir"
    cd "$script_dir" || { echo -e "${RED}错误:无法切换到脚本所在目录。${NC}"; read -p "按Enter继续..." -r; return 1; }

    # 检查是否是 Git 仓库
    if [ ! -d ".git" ]; then
        echo -e "${RED}错误:脚本目录不是一个Git仓库。无法使用'gitpull'更新。${NC}"
        echo -e "${YELLOW}请确保您是通过gitclone获取的脚本，或者手动下载最新版本。${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi

    echo -e "${YELLOW}正在尝试从Git拉取最新版本的脚本(git pull)...${NC}"
    if git pull; then
        echo -e "${GREEN}✓脚本更新成功！${NC}"
        echo -e "${YELLOW}请【重新启动】此脚本以应用更新。${NC}"
        read -p "按Enter退出脚本..." -r
        exit 0 # 退出脚本，让用户重新运行
    else
        echo -e "${RED}×脚本更新失败！${NC}"
        echo -e "${YELLOW}可能原因：网络问题，或您本地修改了脚本导致冲突。${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi
}

# --- 菜单函数 ---

version_management_menu() {
    clear
    check_geographic_location # 获取地理位置

    if [ "$GEOGRAPHIC_LOCATION" = "${RED}中国${NC}" ]; then
        echo -e "${RED}你无法执行更新操作，因为你位于中国。${NC}"
        read -p "按Enter继续..." -r
        return 1
    fi
    while true; do
        clear
        echo -e "\n${GREEN}===版本管理===${NC}"
        echo -e "1.${YELLOW}安装/重装Staging版${NC}(开发测试版,${RED}会删除现有安装${NC})"
        echo -e "2.${YELLOW}安装/重装Release版${NC}(官方稳定版,${RED}会删除现有安装${NC})"
        echo -e "3.${GREEN}更新当前版本${NC}(使用git pull)"
        echo -e "4.返回主菜单"
        echo -e "--------------------"
        read -p "请选择:" choice
        case $choice in
            1) install_tavern "staging" ;;
            2) install_tavern "release" ;;
            3) update_tavern ;;
            4) return ;; # 使用 return 返回上一级菜单
            *) echo -e "${RED}无效的选择，请输入1-4之间的数字。${NC}"; sleep 1 ;;
        esac
    done
}

data_management_menu() {
    while true; do
        clear
        echo -e "\n${GREEN}===数据管理===${NC}"
        echo -e "1.${YELLOW}备份酒馆数据${NC}"
        echo -e "2.${GREEN}恢复酒馆数据${NC}"
        echo -e "3.${RED}删除酒馆数据${NC}"
        echo -e "4.返回主菜单"
        echo -e "--------------------"
        read -p "请选择:" choice
        case $choice in
            1) backup_user_data ;;
            2) restore_user_data ;;
            3) delete_backup_files ;;
            4) return ;; 
            *) echo -e "${RED}无效的选择，请输入1-4之间的数字。${NC}"; sleep 1 ;;
        esac
    done
}

miscellaneous_tools_menu() {
     while true; do
        clear
        echo -e "\n${GREEN}===杂项工具===${NC}"
        echo -e "${YELLOW}警告:修改index.html是临时方案，可能会被更新覆盖。${NC}"
        echo -e "1.添加自定义Gemini模型到列表"
        echo -e "2.从列表删除自定义Gemini模型"
        echo -e "3.返回主菜单"
        echo -e "--------------------"
        read -p "请选择:" choice
        case $choice in
            1) add_gemini_model ;;
            2) delete_gemini_model ;;
            3) return ;;
            *) echo -e "${RED}无效的选择，请输入1-3之间的数字。${NC}"; sleep 1 ;;
        esac
    done
}

show_menu_info() {
    if need_update; then
        echo -e "${BLUE}正在获取最新信息...${NC}"
        update_info
        clear
    fi

    # 检查地理位置
    check_geographic_location

    local st_current_color=$(get_version_color "$ST_CURRENT_VERSION" "$ST_LATEST_VERSION" )
    local clewdr_current_color=$(get_version_color "$CLEWDR_CURRENT_VERSION" "$CLEWDR_LATEST_VERSION" )
    echo -e "\n${BLUE}================SillyTavern管理器v${SCRIPT_VERSION}=================${NC}"
    echo -e "地理位置: ${GEOGRAPHIC_LOCATION}"
    echo -e "------------------------------------------------------------"
    echo -e "SillyTavern | ${st_current_color}${ST_CURRENT_VERSION}${NC} | ${GREEN}${ST_LATEST_VERSION}${NC}"
    echo -e "Clewdr      | ${clewdr_current_color}${CLEWDR_CURRENT_VERSION}${NC}  | ${GREEN}${CLEWDR_LATEST_VERSION}${NC}"
    echo -e "------------------------------------------------------------"
    echo -e "${YELLOW}公告:${NC}"

    echo -e "${ANNOUNCEMENT}" | while IFS= read -r line; do echo "  $line"; done
    echo -e "${BLUE}==========================================================${NC}"
}

# 主菜单
main_menu() {
    # 首次运行时检查 SillyTavern 是否已安装
    if [ ! -d "$INSTALL_PATH" ] || [ ! -f "$INSTALL_PATH/package.json" ]; then
        echo -e "${RED}错误:未检测到SillyTavern安装或安装不完整(${INSTALL_PATH})。${NC}"
        echo -e "${YELLOW}请先通过'版本管理'->'安装/重装'选项进行安装。${NC}"
        # 提供直接进入版本管理菜单的选项
        read -p "是否现在进入版本管理进行安装?(y/N):" install_now
        if [[ "$install_now" =~ ^[Yy]$ ]]; then
            version_management_menu
            # 从版本管理返回后，再次检查
            if [ ! -d "$INSTALL_PATH" ] || [ ! -f "$INSTALL_PATH/package.json" ]; then
                 echo -e "${RED}安装未完成或失败，退出脚本。${NC}"
                 exit 1
            fi
        else
            echo -e "${YELLOW}请先手动安装SillyTavern。脚本退出。${NC}"
            exit 1
        fi
    fi

    # 主循环
    while true; do
        clear              
        show_menu_info

        echo -e "\n${GREEN}---主菜单---${NC}"
        echo -e "1.${GREEN}启动酒馆${NC}"
        echo -e "2.${BLUE}启动Clewdr${NC}"
        echo -e "3.${YELLOW}数据管理${NC}"
        echo -e "4.${BLUE}版本管理${NC}"
        echo -e "5.${YELLOW}杂项工具${NC}"
        echo -e "6.${GREEN}更新脚本${NC}"
        echo -e "7.${RED}退出${NC}"
        echo -e "--------------------"
        read -p "请输入选项[1-7]:" choice
        case $choice in
            1) start_sillytavern ;;
            2) start_clewdr ;;
            3) data_management_menu ;;
            4) version_management_menu ;;
            5) miscellaneous_tools_menu ;;
            6) update_script ;;
            7) echo -e "${BLUE}感谢使用，再见！${NC}"; exit 0 ;;
            *) echo -e "${RED}无效的选择，请输入1-7之间的数字。${NC}"; sleep 1 ;;
        esac
    done
}

main_menu
