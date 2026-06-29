#!/bin/bash
# ============================================================
# 部署 API 项目到服务器并配置 Nginx
# ============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 服务器配置
SERVER_HOST="192.168.2.87"
SERVER_USER="ubuntu"
SERVER_PORT="22"
SERVER_PASSWORD="Aa123456"

# 路径配置
LOCAL_API_DIR="./api"
REMOTE_API_DIR="/var/www/api"

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  API 项目部署脚本${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

# 检查本地 api 目录是否存在
if [ ! -d "$LOCAL_API_DIR" ]; then
    echo -e "${RED}错误: api 目录不存在${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 找到 API 项目目录${NC}"
echo ""

# 显示将要上传的文件
echo -e "${YELLOW}项目文件：${NC}"
echo "  • index.php"
echo "  • scripts/ (3 个脚本)"
echo "  • data/ (2 个 JSON 文件)"
echo ""

read -p "确认部署到 $SERVER_USER@$SERVER_HOST？(y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}部署已取消${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}[1/4] 上传项目文件...${NC}"

# 检查是否有 sshpass
USE_SSHPASS=false
if command -v sshpass &> /dev/null; then
    USE_SSHPASS=true
    SCP_CMD="sshpass -p $SERVER_PASSWORD scp -r -P $SERVER_PORT -o StrictHostKeyChecking=no"
    SSH_CMD="sshpass -p $SERVER_PASSWORD ssh -p $SERVER_PORT -o StrictHostKeyChecking=no"
else
    SCP_CMD="scp -r -P $SERVER_PORT"
    SSH_CMD="ssh -p $SERVER_PORT"
fi

# 上传 index.php
echo "  上传 index.php..."
$SCP_CMD "$LOCAL_API_DIR/index.php" "$SERVER_USER@$SERVER_HOST:$REMOTE_API_DIR/"

# 上传 scripts 目录
echo "  上传 scripts/..."
$SCP_CMD "$LOCAL_API_DIR/scripts/"* "$SERVER_USER@$SERVER_HOST:$REMOTE_API_DIR/scripts/"

# 上传 data 目录
echo "  上传 data/..."
$SCP_CMD "$LOCAL_API_DIR/data/"* "$SERVER_USER@$SERVER_HOST:$REMOTE_API_DIR/data/"

echo -e "${GREEN}✓ 文件上传完成${NC}"
echo ""

echo -e "${BLUE}[2/4] 设置文件权限...${NC}"

$SSH_CMD "$SERVER_USER@$SERVER_HOST" "sudo chown -R www-data:www-data $REMOTE_API_DIR && \
sudo chmod -R 755 $REMOTE_API_DIR && \
sudo chmod +x $REMOTE_API_DIR/scripts/*.sh"

echo -e "${GREEN}✓ 权限设置完成${NC}"
echo ""

echo -e "${BLUE}[3/4] 配置 Nginx...${NC}"

# 创建 Nginx 配置（使用变量替换）
$SSH_CMD "$SERVER_USER@$SERVER_HOST" "sudo tee /etc/nginx/sites-available/api > /dev/null" <<EOF
server {
    listen 80;
    server_name localhost;

    root $REMOTE_API_DIR;
    index index.php index.html;

    access_log /var/log/nginx/api_access.log;
    error_log /var/log/nginx/api_error.log;

    # 所有请求都路由到 index.php
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # PHP 处理
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # 隐藏敏感文件
    location ~ \.(sh|log|conf)\$ {
        deny all;
    }

    # 允许 data 目录下的 JSON 文件被 PHP 读取，但不能直接访问
    location ~ ^/data/.*\.json\$ {
        deny all;
    }

    # 允许大文件上传
    client_max_body_size 50M;
}
EOF

# 启用站点
$SSH_CMD "$SERVER_USER@$SERVER_HOST" "sudo ln -sf /etc/nginx/sites-available/api /etc/nginx/sites-enabled/api"

# 测试 Nginx 配置
$SSH_CMD "$SERVER_USER@$SERVER_HOST" "sudo nginx -t"

# 重启 Nginx
$SSH_CMD "$SERVER_USER@$SERVER_HOST" "sudo systemctl reload nginx"

echo -e "${GREEN}✓ Nginx 配置完成${NC}"
echo ""

echo -e "${BLUE}[4/4] 验证部署...${NC}"

# 等待服务重启
sleep 2

# 测试 API
echo "  测试 API 接口..."
API_RESPONSE=$($SSH_CMD "$SERVER_USER@$SERVER_HOST" "curl -s http://localhost/api")

if echo "$API_RESPONSE" | grep -q "MongoDB & Shell API"; then
    echo -e "${GREEN}✓ API 响应正常${NC}"
else
    echo -e "${YELLOW}! API 响应异常，请检查日志${NC}"
fi

echo ""
echo -e "${BLUE}============================================================${NC}"
echo -e "${GREEN}部署完成！${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo -e "访问地址："
echo -e "  • API 信息: ${GREEN}http://$SERVER_HOST/api${NC}"
echo -e "  • 健康检查: ${GREEN}http://$SERVER_HOST/api/health${NC}"
echo -e "  • PHP 测试: ${GREEN}http://$SERVER_HOST/info.php${NC}"
echo ""
echo -e "日志位置："
echo -e "  • Nginx 访问日志: /var/log/nginx/api_access.log"
echo -e "  • Nginx 错误日志: /var/log/nginx/api_error.log"
echo -e "  • PHP 错误日志: /var/log/php8.3-fpm.log"
echo ""
echo -e "${YELLOW}测试命令示例：${NC}"
echo ""
echo -e "# 1. 获取 API 信息"
echo -e "curl http://$SERVER_HOST/api"
echo ""
echo -e "# 2. 健康检查"
echo -e "curl http://$SERVER_HOST/api/health"
echo ""
echo -e "# 3. 执行测试脚本"
echo -e "curl -X POST http://$SERVER_HOST/api/exec-script \\"
echo -e "  -H 'Content-Type: application/json' \\"
echo -e "  -d '{\"script\": \"test.sh\", \"args\": [\"hello\", \"world\"]}'"
echo ""
echo -e "# 4. 导入用户数据"
echo -e "curl -X POST http://$SERVER_HOST/api/mongo/import \\"
echo -e "  -H 'Content-Type: application/json' \\"
echo -e "  -d '{\"collection\": \"users\", \"file\": \"users.json\"}'"
echo ""
echo -e "# 5. 查询用户数据"
echo -e "curl 'http://$SERVER_HOST/api/mongo/query?collection=users&limit=10'"
echo ""
