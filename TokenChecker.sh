#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TIMEOUT=10
RESULTS_DIR="$HOME/tokencheck"
mkdir -p "$RESULTS_DIR"

check_session() {
    local key=$1
    local silent=$2
    
    [[ "$silent" != "silent" ]] && echo -e "\n${YELLOW}Checking Session Key...${NC}"
    
    response=$(curl -s -w "\n%{http_code}" -H "Cookie: sessionKey=${key}" \
        -H "User-Agent: Mozilla/5.0" \
        -m "$TIMEOUT" \
        "https://api.claude.ai/api/organizations")
        
    local status_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$status_code" = "200" ] && echo "$body" | grep -q "name"; then
        [[ "$silent" != "silent" ]] && {
            echo -e "${GREEN}Valid Session Key!${NC}"
            echo -e "Organization: $(echo "$body" | grep -o '"name":"[^"]*' | head -1 | cut -d'"' -f4)"
        }
        echo "$key,true,$status_code"
    else
        [[ "$silent" != "silent" ]] && echo -e "${RED}Invalid Session Key! Status: $status_code${NC}"
        echo "$key,false,$status_code"
    fi
}

check_gemini() {
    local key=$1
    local silent=$2
    
    [[ "$silent" != "silent" ]] && echo -e "\n${YELLOW}Checking Gemini API Key...${NC}"
    
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "contents": [{
                "parts": [{"text": "Hello, please introduce yourself."}]
            }]
        }' \
        -m "$TIMEOUT" \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.0-pro:generateContent?key=${key}")
    
    local status_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$status_code" = "200" ] && echo "$body" | grep -q "text"; then
        [[ "$silent" != "silent" ]] && echo -e "${GREEN}Valid Gemini API Key!${NC}"
        echo "$key,true,$status_code"
    else
        [[ "$silent" != "silent" ]] && {
            echo -e "${RED}Invalid Gemini API Key! Status: $status_code${NC}"
            error=$(echo "$body" | grep -o '"error":[^}]*' | head -1)
            [ -n "$error" ] && echo -e "${RED}Error: $error${NC}"
        }
        echo "$key,false,$status_code"
    fi
}

batch_process() {
    local type=$1
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local valid_file="$RESULTS_DIR/${type}_valid_${timestamp}.txt"
    local invalid_file="$RESULTS_DIR/${type}_invalid_${timestamp}.txt"
    local status_file="$RESULTS_DIR/${type}_status_${timestamp}.txt"
    
    echo -e "${YELLOW}Enter tokens (one per line, Ctrl+D when finished):${NC}"
    tokens=$(cat)
    
    total_count=0
    declare -A status_counts
    
    echo -e "\n${YELLOW}Processing tokens...${NC}"
    echo "token,valid,status_code" > "$status_file"
    
    while IFS= read -r token; do
        [ -z "$token" ] && continue
        ((total_count++))
        
        echo -ne "\rProcessing $total_count tokens..."
        
        if [ "$type" = "session" ]; then
            result=$(check_session "$token" "silent")
        else
            result=$(check_gemini "$token" "silent")
        fi
        
        echo "$result" >> "$status_file"
        
        token_status=$(echo "$result" | cut -d',' -f2)
        status_code=$(echo "$result" | cut -d',' -f3)
        
        ((status_counts["$status_code"]++))
        
        if [ "$token_status" = "true" ]; then
            echo "$token" >> "$valid_file"
        else
            echo "$token" >> "$invalid_file"
        fi
        
        sleep 0.5
    done <<< "$tokens"
    
    echo -e "\n\n${GREEN}Processing complete!${NC}"
    echo "Total processed: $total_count"
    echo -e "\n${YELLOW}Status Code Statistics:${NC}"
    for status in "${!status_counts[@]}"; do
        echo "Status $status: ${status_counts[$status]} tokens"
    done
    
    echo -e "\nResults saved to:"
    echo "Valid tokens: $valid_file"
    echo "Invalid tokens: $invalid_file"
    echo "Detailed status: $status_file"
}

while true; do
    clear
    echo -e "${BLUE}===========================${NC}"
    echo -e "${BLUE}      Token Checker        ${NC}"
    echo -e "${BLUE}===========================${NC}"
    echo
    echo "1. Check Single Session Key"
    echo "2. Check Single Gemini API Key"
    echo "3. Batch Check Session Keys"
    echo "4. Batch Check Gemini API Keys"
    echo "0. Exit"
    echo
    echo -n "Choose option: "
    read -r choice

    case $choice in
        1)
            echo -n "Enter Session Key: "
            read -r key
            [ -n "$key" ] && check_session "$key"
            ;;
        2)
            echo -n "Enter Gemini API Key: "
            read -r key
            [ -n "$key" ] && check_gemini "$key"
            ;;
        3)
            batch_process "session"
            ;;
        4)
            batch_process "gemini"
            ;;
        0)
            echo -e "\n${YELLOW}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
done
    
