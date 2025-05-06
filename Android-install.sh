#!/bin/bash

# === Konnichiwa! Let's get things set up! ===

# Colors for fancy messages! ✨
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- SillyTavern Stuff ---
ST_INSTALL_PATH="$HOME/SillyTavern"
ST_REPO_URL="https://github.com/SillyTavern/SillyTavern.git"

# --- Clewdr Stuff ---
CLEWDR_SOFTWARE_NAME="clewdr"
CLEWDR_GITHUB_REPO="Xerxes-2/clewdr"
CLEWDR_INSTALL_PATH="${HOME}/clewdr" # Installing Clewdr in its own cozy spot
CLEWDR_GH_API_URL="https://api.github.com/repos/${CLEWDR_GITHUB_REPO}/releases/latest"
CLEWDR_GH_DOWNLOAD_URL_BASE="https://github.com/${CLEWDR_GITHUB_REPO}/releases/latest/download"
CLEWDR_VERSION_FILE="${CLEWDR_INSTALL_PATH}/version.txt"
CLEWDR_PORT=8484
CLEWDR_ARCH="aarch64" # Hardcoding for Termux Android
CLEWDR_DOWNLOAD_FILENAME="${CLEWDR_SOFTWARE_NAME}-android-${CLEWDR_ARCH}.zip"

# --- Helper Stuff ---
MANAGER_SCRIPT="$HOME/manager.sh"
MANAGER_SCRIPT_URL="https://raw.githubusercontent.com/Yozora-sk/SillyTavern-Ci/refs/heads/main/Android-manager.sh"
BASHRC_FILE="$HOME/.bashrc"

# === Let's check your internet connection! ===
echo -e "${BLUE}正在检查您的IP位置和与GitHub的连接速度...${NC}"
USER_COUNTRY=$(curl -s --connect-timeout 5 ipinfo.io/country)
if [ -n "$USER_COUNTRY" ]; then
    echo -e "${GREEN}看起来您正在从${USER_COUNTRY}连接!你好!👋${NC}"
    if [ "$USER_COUNTRY" = "CN" ]; then
        echo -e "${YELLOW}您位于中国，很大概率安装不成功。请考虑使用代理。${NC}"
    fi
else
    echo -e "${YELLOW}嗯，无法确定您的位置，不过没关系!${NC}"
fi

# Check ping command availability
if command -v ping &> /dev/null; then
    GITHUB_PING_RESULT=$(ping -c 1 github.com | grep 'time=' | awk -F'time=' '{ print $2 }' | awk '{ print $1 }')
    if [ -n "$GITHUB_PING_RESULT" ]; then
        echo -e "${GREEN}到GitHub的Ping大约是${GITHUB_PING_RESULT}毫秒。很快!🚀${NC}"
    else
        echo -e "${YELLOW}现在无法测量到GitHub的ping。希望它很快!${NC}"
    fi
else
     echo -e "${YELLOW}找不到'ping'命令，跳过到GitHub的速度测试。${NC}"
fi
echo "-------------------------------------"

# Ask user to continue
read -r -p "是否继续执行安装？[Y/N]" continue_install
if [[ "$continue_install" != [Yy] ]]; then
    echo -e "${YELLOW}安装已取消。${NC}"
    exit 0
fi

# === Function Land! Where the magic happens! ===

# Oopsie handler!
handle_error() {
    echo -e "${RED}💥糟糕!出了点问题:${1}${NC}"
    exit 1
}

# Let's update your system packages first!
update_system() {
    echo -e "${YELLOW}正在请求Termux更新其软件包列表...${NC}"
    pkg update -y || echo -e "${YELLOW}无法更新列表，也许稍后再试？仍然继续...${NC}"
    echo -e "${YELLOW}正在请求Termux升级软件包（这可能需要一段时间！）...${NC}"
    pkg upgrade -y || echo -e "${YELLOW}无法升级软件包。如果出现问题，请尝试自己运行'pkg upgrade'！${NC}"
    echo -e "${GREEN}系统软件包检查完成！✨${NC}"
}

# Gotta have the right tools! Checking dependencies...
check_dependencies() {
    echo -e "${YELLOW}正在检查您是否拥有我们需要的所有工具...${NC}"
    local needed_deps=("nodejs" "git" "curl" "unzip" "jq" "ldd") # Added jq for easier version checking!  Added ldd for clewdr
    local missing_deps=()

    for dep in "${needed_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${YELLOW}缺少工具：${dep}${NC}"
            missing_deps+=("$dep")
        else
             echo -e "${GREEN}找到工具：${dep}！太棒了！${NC}"
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}看起来我们需要安装：${missing_deps[*]}...让我们来获取它们！${NC}"
        if ! pkg install -y "${missing_deps[@]}"; then
            handle_error "无法安装这些工具：${missing_deps[*]}。请尝试使用'pkg install ...'手动安装它们！"
        fi
        echo -e "${GREEN}获取了所有缺少的工具！我们准备好了！🎉${NC}"
    else
        echo -e "${GREEN}您拥有我们需要的所有工具！完美！👍${NC}"
    fi
}

# Setting up SillyTavern! The main star!
setup_sillytavern() {
    echo "-------------------------------------"
    echo -e "${BLUE}现在是主要活动：SillyTavern！${NC}"
    if [ ! -d "$ST_INSTALL_PATH" ]; then
        echo -e "${YELLOW}SillyTavern尚未在此处。让我们从GitHub获取它！${NC}"
        if ! git clone --depth 1 "$ST_REPO_URL" "$ST_INSTALL_PATH"; then
            handle_error "无法下载SillyTavern！GitHub正常吗？还是你的互联网？🤔"
        fi
        cd "$ST_INSTALL_PATH" || handle_error "无法跳转到新的SillyTavern文件夹！"

        echo -e "${YELLOW}正在安装SillyTavern的小助手（Node.js的东西）...这可能需要一段时间，抓点零食吧！🍪${NC}"
        if ! npm install; then
             # Sometimes it helps to remove node_modules and try again
            echo -e "${YELLOW}嗯，那行不通。让我们尝试清理并再次安装...🤞${NC}"
            rm -rf node_modules
            if ! npm install; then
                handle_error "仍然无法安装SillyTavern的助手。也许尝试在$ST_INSTALL_PATH中自己运行'npm install'？"
            fi
        fi
        echo -e "${GREEN}SillyTavern已下载并准备就绪！✨${NC}"
    else
        echo -e "${GREEN}SillyTavern已经在这里了！跳过下载。${NC}"
        cd "$ST_INSTALL_PATH" || handle_error "即使SillyTavern文件夹在那里，也无法跳转到其中？奇怪！"
        # Optional: Offer to update SillyTavern? For now, we just check it exists.
    fi
}

# Checking if Clewdr needs an update!
check_clewdr_version() {
    echo "-------------------------------------"
    echo -e "${BLUE}正在检查我们的小伙伴，Clewdr...${NC}"

    # Need to create the directory first if it doesn't exist
     if [ ! -d "$CLEWDR_INSTALL_PATH" ]; then
        echo -e "${YELLOW}Clewdr文件夹尚不存在。在${CLEWDR_INSTALL_PATH}创建它${NC}"
        mkdir -p "$CLEWDR_INSTALL_PATH" || handle_error "无法创建Clewdr文件夹！"
    fi

    local local_version=""
    if [ -f "$CLEWDR_VERSION_FILE" ]; then
        local_version=$(cat "$CLEWDR_VERSION_FILE")
        echo -e "${GREEN}您当前拥有的Clewdr版本：${local_version}${NC}"
    else
        echo -e "${YELLOW}嗯，找不到Clewdr的版本文件。我们将获取最新的一个！${NC}"
    fi

    echo -e "${YELLOW}正在向GitHub询问最新的Clewdr...${NC}"
    # Use jq for reliable parsing!
    local latest_info
    latest_info=$(curl -s --connect-timeout 10 "$CLEWDR_GH_API_URL")

    if [ -z "$latest_info" ]; then
        echo -e "${YELLOW}无法访问GitHub以检查最新的Clewdr版本。我们将保留您拥有的版本（如果有）。${NC}"
        # If we couldn't check and there's no local version, we can't proceed with Clewdr install
        if [ -z "$local_version" ]; then
             echo -e "${RED}无法在没有版本信息的情况下继续安装Clewdr。${NC}"
             return 2 # Special return code indicating check failure and no local version
        fi
        return 1 # Keep existing version
    fi

    # Use jq to safely get the tag name
    LATEST_CLEWDR_VERSION=$(echo "$latest_info" | jq -r '.tag_name // empty')

    if [ -z "$LATEST_CLEWDR_VERSION" ]; then
        echo -e "${YELLOW}GitHub没有正确告诉我们最新版本。奇怪！保留您拥有的版本（如果有）。${NC}"
         if [ -z "$local_version" ]; then
             echo -e "${RED}无法在没有版本信息的情况下继续安装Clewdr。${NC}"
             return 2
        fi
        return 1 # Keep existing version
    fi

    echo -e "${GREEN}可用的最新Clewdr版本：${LATEST_CLEWDR_VERSION}${NC}"

    if [ "$local_version" = "$LATEST_CLEWDR_VERSION" ]; then
        echo -e "${GREEN}太棒了！您的Clewdr已经是最新版本了！🎉${NC}"
        read -p "$(echo -e "${YELLOW}您是否仍然要下载并重新安装它？(y/N):${NC}")" force_update
        if [[ "$force_update" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}好的，如您所愿，重新安装Clewdr${LATEST_CLEWDR_VERSION}！${NC}"
            return 0 # Proceed with installation
        else
            echo -e "${GREEN}好的，保留您当前的Clewdr。${NC}"
            return 1 # Skip installation
        fi
    else
        echo -e "${GREEN}哦，一个新的Clewdr版本！让我们获取${LATEST_CLEWDR_VERSION}！✨${NC}"
        return 0 # Proceed with installation
    fi
}

# Installing or updating Clewdr!
install_clewdr() {
    CLEWDR_TARGET_DIR="${CLEWDR_INSTALL_PATH}"  #定义clewdr的安装目录
    CLEWDR_DOWNLOAD_FILENAME="$CLEWDR_SOFTWARE_NAME-android-$CLEWDR_ARCH.zip" #定义下载文件名
    local download_url="${CLEWDR_GH_DOWNLOAD_URL_BASE}/${CLEWDR_DOWNLOAD_FILENAME}"
    local download_path="${CLEWDR_INSTALL_PATH}/${CLEWDR_DOWNLOAD_FILENAME}"
    local executable_path="${CLEWDR_INSTALL_PATH}/${CLEWDR_SOFTWARE_NAME}"

    echo -e "${YELLOW}正在从GitHub下载${CLEWDR_DOWNLOAD_FILENAME}...请稍候！${NC}"

    local max_retries=3
    local retry_count=0
    local wait_time=5

    while [ $retry_count -lt $max_retries ]; do
        # Use -# for progress bar, -L to follow redirects, -f to fail silently on server errors
        if curl -fL --connect-timeout 15 --retry 3 --retry-delay 5 -o "$download_path" "$download_url" -#; then
             echo "" # Newline after progress bar
             # Basic check if download was successful (file exists and is not empty)
            if [ -f "$download_path" ] && [ -s "$download_path" ]; then
                echo -e "${GREEN}下载完成！获取文件！✔️${NC}"
                break
            else
                 echo -e "${YELLOW}下载似乎已完成，但该文件看起来为空或丢失。🤔正在重试...${NC}"
            fi
        else
             echo -e "${YELLOW}下载失败。也许网络打了个嗝？🤔${NC}"
        fi

        # Cleanup failed download attempt
        rm -f "$download_path"
        retry_count=$((retry_count + 1))

        if [ $retry_count -lt $max_retries ]; then
            echo -e "${YELLOW}将在${wait_time}秒后重试（${retry_count}/${max_retries}）...${NC}"
            sleep $wait_time
            wait_time=$((wait_time + 5)) # Increase wait time for next retry
        else
            handle_error "经过${max_retries}次尝试后，无法从${download_url}下载Clewdr。请检查URL或您的连接。"
        fi
    done

    echo -e "${YELLOW}正在解压Clewdr...就像打开礼物一样！🎁${NC}"
    if ! unzip -o "$download_path" -d "$CLEWDR_TARGET_DIR"; then
        rm -f "$download_path" # Clean up the zip even if unzip fails
        handle_error "解压失败: $download_path"
    fi

    rm -f "$download_path"
        if [ -f "$CLEWDR_TARGET_DIR/$CLEWDR_SOFTWARE_NAME" ]; then
        chmod +x "$CLEWDR_TARGET_DIR/$CLEWDR_SOFTWARE_NAME"
    fi

        if [ -n "$LATEST_CLEWDR_VERSION" ]; then
        echo "$LATEST_CLEWDR_VERSION" > "$CLEWDR_VERSION_FILE"
        echo "版本信息已保存: $LATEST_CLEWDR_VERSION"
    fi
  echo -e "${GREEN}Clewdr已安装！${NC}"
  echo -e "${GREEN}你可以运行:$CLEWDR_TARGET_DIR/$CLEWDR_SOFTWARE_NAME来运行程序${NC}"

}

# Getting the helper script for easy starting!
setup_manager_script() {
    echo "-------------------------------------"
    echo -e "${YELLOW}获取一个小助手脚本来轻松管理事物...${NC}"
    if ! curl -o "$MANAGER_SCRIPT" "$MANAGER_SCRIPT_URL"; then
        handle_error "无法从${MANAGER_SCRIPT_URL}下载助手脚本。倒霉！"
    fi
    chmod +x "$MANAGER_SCRIPT"
    echo -e "${GREEN}获取了助手脚本！（${MANAGER_SCRIPT}）${NC}"
}

# Make it easy to start next time!
setup_auto_start() {
    echo "-------------------------------------"
    echo -e "${YELLOW}正在进行设置，以便您下次只需键入'bash manager.sh'即可启动...${NC}"

    # Ensure .bashrc exists
    touch "$BASHRC_FILE"

    # Check if the alias/command already exists to avoid duplicates
    if ! grep -q "bash $MANAGER_SCRIPT" "$BASHRC_FILE"; then
        echo -e "\n# 别名可以轻松启动SillyTavern，也许还有其他东西！" >> "$BASHRC_FILE"
        #set auto start
        echo "bash \"$MANAGER_SCRIPT\"" >> "$BASHRC_FILE"
        echo -e "${GREEN}设置完成！下次打开Termux时，它将自动启动！${NC}"

    else
        echo -e "${YELLOW}看起来您的设置中已经提到了启动助手。好的！${NC}"
        echo -e "${GREEN}下次打开Termux时，它将自动启动！${NC}"
    fi
     # Make the current shell aware of changes immediately (optional, might confuse users)
    source "$BASHRC_FILE"
}


# === Main Show! Let's do this! ===
main() {
    clear # Start fresh!
    echo -e "${GREEN}=====================================${NC}"
    echo -e "${GREEN}* SillyTavern & Friends 安装程序！ *${NC}"
    echo -e "${GREEN}=====================================${NC}"
    echo -e "${YELLOW}好的，让我们为您准备好一切...${NC}"

    update_system
    check_dependencies
    setup_sillytavern

    # Check Clewdr version and decide whether to install/update
    check_clewdr_version
    local clewdr_check_result=$?

    if [ $clewdr_check_result -eq 0 ]; then
        # 0 means install/update needed or forced
        install_clewdr
    elif [ $clewdr_check_result -eq 2 ]; then
        # 2 means failed to check and no local version exists
         echo -e "${RED}跳过Clewdr安装，因为我们无法验证其版本。${NC}"
    else
        # 1 means up-to-date and not forced, or failed check but local exists
        echo -e "${GREEN}根据版本检查跳过Clewdr下载/安装。${NC}"
    fi

    setup_manager_script
    setup_auto_start # Changed setup_auto_start to just inform, not auto-run

    echo -e "${GREEN}=====================================${NC}"
    echo -e "${GREEN}全部完成！SillyTavern已设置！✨${NC}"
    if [ -f "${CLEWDR_INSTALL_PATH}/${CLEWDR_SOFTWARE_NAME}" ]; then
         echo -e "${GREEN}Clewdr也已准备就绪，位于：${CLEWDR_INSTALL_PATH}${NC}"
         echo -e "${GREEN}使用以下命令运行它：${CLEWDR_INSTALL_PATH}/${CLEWDR_SOFTWARE_NAME}${NC}"
    fi
    echo -e "${GREEN}Termux下次启动时SillyTavern会自动启动!${NC}"
    echo -e "${GREEN}=====================================${NC}"
    echo ""

}

# Annnnd... ACTION! 🎬
main
