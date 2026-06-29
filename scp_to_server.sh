#!/bin/bash
# ============================================================
# SCP 文件传输脚本
# 功能：将安装脚本和说明文档传输到 Ubuntu 服务器
# ============================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认配置（从 ssh_manager/servers.conf 读取）
DEFAULT_HOST="192.168.2.87"
DEFAULT_USER="ubuntu"
DEFAULT_PORT="22"
DEFAULT_PASSWORD="Aa123456"
DEFAULT_REMOTE_PATH="/home/ubuntu/zhaon/ttgame"

# 当前脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 要传输的文件
FILES=(
    "install_server.sh"
    "INSTALL_README.md"
    "deploy_api.sh"
)

# 要传输的文件夹
DIRS=(
    "api"
)

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  文件传输脚本 - 上传到 Ubuntu 服务器${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

# 显示当前配置
echo -e "${YELLOW}当前配置：${NC}"
echo -e "  服务器地址: ${GREEN}$DEFAULT_USER@$DEFAULT_HOST${NC}"
echo -e "  SSH 端口: ${GREEN}$DEFAULT_PORT${NC}"
echo -e "  目标路径: ${GREEN}$DEFAULT_REMOTE_PATH${NC}"
echo ""

# 询问是否修改配置
read -p "是否使用以上配置？(y/n，回车默认 y): " -r USE_DEFAULT
USE_DEFAULT=${USE_DEFAULT:-y}

if [[ ! $USE_DEFAULT =~ ^[Yy]$ ]]; then
    echo ""
    read -p "请输入服务器 IP: " CUSTOM_HOST
    read -p "请输入用户名: " CUSTOM_USER
    read -p "请输入 SSH 端口 (默认 22): " CUSTOM_PORT
    read -p "请输入目标路径 (默认 ~/): " CUSTOM_PATH

    DEFAULT_HOST=${CUSTOM_HOST:-$DEFAULT_HOST}
    DEFAULT_USER=${CUSTOM_USER:-$DEFAULT_USER}
    DEFAULT_PORT=${CUSTOM_PORT:-$DEFAULT_PORT}
    DEFAULT_REMOTE_PATH=${CUSTOM_PATH:-$DEFAULT_REMOTE_PATH}
fi

echo ""
echo -e "${YELLOW}准备传输以下文件：${NC}"
for file in "${FILES[@]}"; do
    if [ -f "$SCRIPT_DIR/$file" ]; then
        SIZE=$(ls -lh "$SCRIPT_DIR/$file" | awk '{print $5}')
        echo -e "  ✓ ${GREEN}$file${NC} ($SIZE)"
    else
        echo -e "  ✗ ${RED}$file${NC} (文件不存在)"
    fi
done

echo ""
echo -e "${YELLOW}准备传输以下文件夹：${NC}"
for dir in "${DIRS[@]}"; do
    if [ -d "$SCRIPT_DIR/$dir" ]; then
        COUNT=$(find "$SCRIPT_DIR/$dir" -type f | wc -l | xargs)
        echo -e "  ✓ ${GREEN}$dir/${NC} ($COUNT 个文件)"
    else
        echo -e "  ✗ ${RED}$dir/${NC} (文件夹不存在)"
    fi
done

echo ""
read -p "确认开始传输？(y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}传输已取消${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}开始传输...${NC}"
echo ""

# 检查是否安装 sshpass
USE_SSHPASS=false
if command -v sshpass &> /dev/null; then
    USE_SSHPASS=true
    echo -e "${GREEN}✓ 检测到 sshpass，将使用密码自动登录${NC}"
else
    echo -e "${YELLOW}! 未检测到 sshpass，需要手动输入密码${NC}"
    echo -e "${YELLOW}! 提示：可运行 'brew install hudochenkov/sshpass/sshpass' 安装${NC}"
fi

echo ""

# 传输文件
SUCCESS_COUNT=0
FAIL_COUNT=0

# 传输文件
for file in "${FILES[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$file" ]; then
        echo -e "${RED}✗ 跳过 $file (文件不存在)${NC}"
        ((FAIL_COUNT++))
        continue
    fi

    echo -e "${BLUE}[传输文件]${NC} $file ..."

    if [ "$USE_SSHPASS" = true ]; then
        # 使用 sshpass 自动输入密码
        if sshpass -p "$DEFAULT_PASSWORD" scp -P "$DEFAULT_PORT" -o StrictHostKeyChecking=no \
            "$SCRIPT_DIR/$file" "${DEFAULT_USER}@${DEFAULT_HOST}:${DEFAULT_REMOTE_PATH}"; then
            echo -e "${GREEN}✓ $file 传输成功${NC}"
            ((SUCCESS_COUNT++))
        else
            echo -e "${RED}✗ $file 传输失败${NC}"
            ((FAIL_COUNT++))
        fi
    else
        # 手动输入密码
        if scp -P "$DEFAULT_PORT" "$SCRIPT_DIR/$file" "${DEFAULT_USER}@${DEFAULT_HOST}:${DEFAULT_REMOTE_PATH}"; then
            echo -e "${GREEN}✓ $file 传输成功${NC}"
            ((SUCCESS_COUNT++))
        else
            echo -e "${RED}✗ $file 传输失败${NC}"
            ((FAIL_COUNT++))
        fi
    fi
    echo ""
done

# 传输文件夹
for dir in "${DIRS[@]}"; do
    if [ ! -d "$SCRIPT_DIR/$dir" ]; then
        echo -e "${RED}✗ 跳过 $dir (文件夹不存在)${NC}"
        ((FAIL_COUNT++))
        continue
    fi

    echo -e "${BLUE}[传输文件夹]${NC} $dir/ ..."

    if [ "$USE_SSHPASS" = true ]; then
        # 使用 sshpass 自动输入密码 (-r 递归传输)
        if sshpass -p "$DEFAULT_PASSWORD" scp -r -P "$DEFAULT_PORT" -o StrictHostKeyChecking=no \
            "$SCRIPT_DIR/$dir" "${DEFAULT_USER}@${DEFAULT_HOST}:${DEFAULT_REMOTE_PATH}"; then
            echo -e "${GREEN}✓ $dir/ 传输成功${NC}"
            ((SUCCESS_COUNT++))
        else
            echo -e "${RED}✗ $dir/ 传输失败${NC}"
            ((FAIL_COUNT++))
        fi
    else
        # 手动输入密码 (-r 递归传输)
        if scp -r -P "$DEFAULT_PORT" "$SCRIPT_DIR/$dir" "${DEFAULT_USER}@${DEFAULT_HOST}:${DEFAULT_REMOTE_PATH}"; then
            echo -e "${GREEN}✓ $dir/ 传输成功${NC}"
            ((SUCCESS_COUNT++))
        else
            echo -e "${RED}✗ $dir/ 传输失败${NC}"
            ((FAIL_COUNT++))
        fi
    fi
    echo ""
done

# 显示传输结果
echo -e "${BLUE}============================================================${NC}"
echo -e "${GREEN}传输完成！${NC}"
echo -e "  成功: ${GREEN}$SUCCESS_COUNT${NC} 个文件"
echo -e "  失败: ${RED}$FAIL_COUNT${NC} 个文件"
echo -e "${BLUE}============================================================${NC}"

if [ $SUCCESS_COUNT -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}下一步操作：${NC}"
    echo -e "1. 连接到服务器："
    echo -e "   ${GREEN}ssh ${DEFAULT_USER}@${DEFAULT_HOST} -p ${DEFAULT_PORT}${NC}"
    echo ""
    echo -e "2. 赋予执行权限："
    echo -e "   ${GREEN}chmod +x install_server.sh deploy_api.sh${NC}"
    echo ""
    echo -e "3. 运行安装脚本（如果还没安装环境）："
    echo -e "   ${GREEN}sudo bash install_server.sh${NC}"
    echo ""
    echo -e "4. 运行部署脚本（部署 API 项目）："
    echo -e "   ${GREEN}./deploy_api.sh${NC}"
    echo ""
fi
