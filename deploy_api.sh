#!/bin/bash
# ============================================================
# API 项目部署脚本（服务器端）
# 在服务器上运行，配置 Nginx 指向 API 目录
# ============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 路径配置
API_DIR="/data/HT_Server/tools/migration_scripts/lua/webapi/api"

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  API 项目部署脚本${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

# 检测 PHP 版本
detect_php_version() {
    if ! command -v php &> /dev/null; then
        echo -e "${RED}错误: PHP 未安装${NC}"
        echo -e "${YELLOW}请先运行 install_server.sh 安装环境${NC}"
        exit 1
    fi

    PHP_VERSION=$(php -v | head -n1 | grep -oP '\d+\.\d+' | head -1)
    echo -e "${GREEN}✓ 检测到 PHP 版本: $PHP_VERSION${NC}"

    # 检查 PHP-FPM 是否运行
    if systemctl is-active --quiet php${PHP_VERSION}-fpm; then
        echo -e "${GREEN}✓ PHP-FPM 服务运行中${NC}"
    else
        echo -e "${RED}错误: PHP-FPM 服务未运行${NC}"
        echo -e "${YELLOW}尝试启动服务: sudo systemctl start php${PHP_VERSION}-fpm${NC}"
        exit 1
    fi

    # 检查 socket 文件是否存在
    PHP_SOCKET="/run/php/php${PHP_VERSION}-fpm.sock"
    if [ -S "$PHP_SOCKET" ]; then
        echo -e "${GREEN}✓ PHP-FPM Socket 存在: $PHP_SOCKET${NC}"
    else
        echo -e "${RED}错误: PHP-FPM Socket 不存在: $PHP_SOCKET${NC}"
        echo -e "${YELLOW}可用的 socket 文件：${NC}"
        ls -la /run/php/ 2>/dev/null || echo "  无"
        exit 1
    fi
}

# 检查 API 目录是否存在
if [ ! -d "$API_DIR" ]; then
    echo -e "${RED}错误: API 目录不存在: $API_DIR${NC}"
    echo -e "${YELLOW}请先运行 scp_to_server.sh 上传 api 目录${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 找到 API 目录: $API_DIR${NC}"

# 检查是否有必要文件
if [ ! -f "$API_DIR/index.php" ]; then
    echo -e "${RED}错误: index.php 不存在${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 验证文件完整性${NC}"

# 检测 PHP 环境
detect_php_version
echo ""

# 显示项目文件
echo -e "${YELLOW}项目文件：${NC}"
ls -lh "$API_DIR" | tail -n +2 | awk '{print "  • " $9 " (" $5 ")"}'
echo ""

read -p "确认配置 Nginx 指向 $API_DIR？(y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}部署已取消${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}[1/4] 设置目录权限（确保 Nginx 可以访问）...${NC}"

# 给父目录添加执行权限（让 root 可以穿透）
sudo chmod o+x "$API_DIR"

# 设置 API 目录的所有者和权限
sudo chown -R root:root "$API_DIR"
sudo chmod -R 755 "$API_DIR"

# 给脚本执行权限
if [ -d "$API_DIR/scripts" ]; then
    sudo chmod +x "$API_DIR/scripts"/*.sh
fi

# 确保 logs 目录存在
sudo mkdir -p "$API_DIR/logs"
sudo chown root:root "$API_DIR/logs"

echo -e "${GREEN}✓ 权限设置完成${NC}"
echo ""

echo -e "${BLUE}[2/5] 配置 Nginx...${NC}"

# 创建 Nginx 配置（使用检测到的 PHP 版本）
sudo tee /etc/nginx/sites-available/api > /dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    root $API_DIR;
    index index.html index.php;

    access_log /var/log/nginx/api_access.log;
    error_log /var/log/nginx/api_error.log;

    # 所有请求都路由到 index.php
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # PHP 处理
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
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

echo -e "${GREEN}✓ 使用 PHP-FPM Socket: /run/php/php${PHP_VERSION}-fpm.sock${NC}"

# 禁用默认站点（如果存在）
if [ -f /etc/nginx/sites-enabled/default ]; then
    echo "  禁用默认站点..."
    sudo rm -f /etc/nginx/sites-enabled/default
fi

# 启用 API 站点
sudo ln -sf /etc/nginx/sites-available/api /etc/nginx/sites-enabled/api

# 测试 Nginx 配置
echo "  测试 Nginx 配置..."
sudo nginx -t

# 重启 Nginx
echo "  重启 Nginx..."
sudo systemctl restart nginx

echo -e "${GREEN}✓ Nginx 配置完成${NC}"
echo ""

echo -e "${BLUE}[3/5] 验证部署...${NC}"

# 等待服务重启
sleep 2

# 测试 API
echo "  测试 API 接口..."
API_RESPONSE=$(curl -s http://localhost/api)

if echo "$API_RESPONSE" | grep -q "MongoDB & Shell API"; then
    echo -e "${GREEN}✓ API 响应正常${NC}"
elif echo "$API_RESPONSE" | grep -q "502"; then
    echo -e "${RED}✗ 502 错误：PHP-FPM 连接失败${NC}"
    echo -e "${YELLOW}查看错误日志: sudo tail -20 /var/log/nginx/api_error.log${NC}"
    echo -e "${YELLOW}检查 PHP-FPM: sudo systemctl status php${PHP_VERSION}-fpm${NC}"
elif echo "$API_RESPONSE" | grep -q "404"; then
    echo -e "${RED}✗ API 返回 404${NC}"
    echo -e "${YELLOW}检查文件: ls -la $API_DIR/${NC}"
else
    echo -e "${YELLOW}! API 响应异常${NC}"
    echo -e "${YELLOW}响应内容: $API_RESPONSE${NC}"
    echo ""
    echo -e "${YELLOW}诊断命令：${NC}"
    echo -e "  sudo tail -20 /var/log/nginx/api_error.log"
    echo -e "  sudo systemctl status php${PHP_VERSION}-fpm"
fi

# 显示部署的文件列表
echo ""
echo -e "${YELLOW}API 目录内容：${NC}"
ls -lh "$API_DIR" | tail -n +2 | awk '{print "  • " $9 " (" $5 ")"}'

echo ""
echo -e "${BLUE}[4/5] 检查网络和防火墙...${NC}"

# 获取服务器 IP
SERVER_IP=$(hostname -I | awk '{print $1}')
echo -e "${GREEN}✓ 服务器 IP: $SERVER_IP${NC}"

# 检查 Nginx 监听端口
echo "  检查 Nginx 监听状态..."
LISTEN_STATUS=$(sudo netstat -tlnp 2>/dev/null | grep :80 | grep nginx || sudo ss -tlnp 2>/dev/null | grep :80 | grep nginx)
if echo "$LISTEN_STATUS" | grep -q "0.0.0.0:80"; then
    echo -e "${GREEN}✓ Nginx 监听所有接口 (0.0.0.0:80)${NC}"
elif echo "$LISTEN_STATUS" | grep -q "127.0.0.1:80"; then
    echo -e "${RED}✗ Nginx 只监听本地 (127.0.0.1:80)${NC}"
    echo -e "${YELLOW}  需要修改配置让 Nginx 监听所有接口${NC}"
else
    echo -e "${YELLOW}! 无法确定 Nginx 监听状态${NC}"
fi

# 检查防火墙
echo "  检查防火墙状态..."
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(sudo ufw status)
    if echo "$UFW_STATUS" | grep -q "Status: active"; then
        echo -e "${YELLOW}! 防火墙已启用${NC}"
        if echo "$UFW_STATUS" | grep -q "80.*ALLOW"; then
            echo -e "${GREEN}✓ 端口 80 已开放${NC}"
        else
            echo -e "${RED}✗ 端口 80 未开放${NC}"
            echo -e "${YELLOW}  建议执行: sudo ufw allow 80/tcp${NC}"
        fi
    else
        echo -e "${GREEN}✓ 防火墙未启用${NC}"
    fi
fi

# 测试外部 IP 访问
echo "  测试外部 IP 访问 ($SERVER_IP)..."
EXTERNAL_TEST=$(timeout 5 curl -s http://$SERVER_IP/api 2>&1)
if echo "$EXTERNAL_TEST" | grep -q "MongoDB & Shell API"; then
    echo -e "${GREEN}✓ 外部 IP 访问正常${NC}"
elif echo "$EXTERNAL_TEST" | grep -q "timed out\|Connection refused\|Failed to connect"; then
    echo -e "${RED}✗ 外部 IP 无法访问${NC}"
    echo -e "${YELLOW}  可能原因：${NC}"
    echo -e "${YELLOW}  1. 防火墙阻止了 80 端口${NC}"
    echo -e "${YELLOW}  2. Nginx 只监听了 localhost${NC}"
    echo -e "${YELLOW}  3. 网络路由问题${NC}"
else
    echo -e "${YELLOW}! 外部 IP 访问异常${NC}"
fi

echo ""
echo -e "${BLUE}[5/5] 测试 API 接口...${NC}"

# 测试健康检查
echo "  测试健康检查..."
HEALTH_RESPONSE=$(curl -s http://localhost/api/health)
if echo "$HEALTH_RESPONSE" | grep -q "ok"; then
    echo -e "${GREEN}✓ 健康检查正常${NC}"
else
    echo -e "${YELLOW}! 健康检查异常${NC}"
fi

# 测试脚本执行
echo "  测试脚本执行..."
SCRIPT_RESPONSE=$(curl -s -X POST http://localhost/api/exec-script \
    -H "Content-Type: application/json" \
    -d '{"script": "test.sh", "args": ["deploy", "test"]}')
if echo "$SCRIPT_RESPONSE" | grep -q "success"; then
    echo -e "${GREEN}✓ 脚本执行正常${NC}"
else
    echo -e "${YELLOW}! 脚本执行异常${NC}"
fi

echo ""
echo -e "${BLUE}============================================================${NC}"
echo -e "${GREEN}部署完成！${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo -e "环境信息："
echo -e "  • 服务器 IP: ${GREEN}$SERVER_IP${NC}"
echo -e "  • PHP 版本: ${GREEN}$PHP_VERSION${NC}"
echo -e "  • PHP-FPM Socket: ${GREEN}/run/php/php${PHP_VERSION}-fpm.sock${NC}"
echo -e "  • API 目录: ${GREEN}$API_DIR${NC}"
echo ""
echo -e "访问地址："
echo -e "  • 本地: ${GREEN}http://localhost/api${NC}"
echo -e "  • 外部: ${GREEN}http://$SERVER_IP/api${NC}"
echo ""

# 如果外部访问失败，给出解决建议
if ! echo "$EXTERNAL_TEST" | grep -q "MongoDB & Shell API"; then
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}外部访问故障排查建议：${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    echo -e "1. 开放防火墙端口："
    echo -e "   ${CYAN}sudo ufw allow 80/tcp${NC}"
    echo -e "   ${CYAN}sudo ufw reload${NC}"
    echo ""
    echo -e "2. 测试外部访问："
    echo -e "   ${CYAN}curl http://$SERVER_IP/api${NC}"
    echo ""
    echo -e "3. 检查 Nginx 监听："
    echo -e "   ${CYAN}sudo netstat -tlnp | grep :80${NC}"
    echo ""
    echo -e "4. 查看防火墙状态："
    echo -e "   ${CYAN}sudo ufw status verbose${NC}"
    echo ""
fi

echo -e "日志位置："
echo -e "  • Nginx 访问日志: /var/log/nginx/api_access.log"
echo -e "  • Nginx 错误日志: /var/log/nginx/api_error.log"
echo -e "  • PHP 错误日志: /var/log/php${PHP_VERSION}-fpm.log"
echo ""
echo -e "${YELLOW}测试命令示例：${NC}"
echo ""
echo -e "# 1. 获取 API 信息"
echo -e "${CYAN}curl http://$SERVER_IP/api${NC}"
echo ""
echo -e "# 2. 健康检查"
echo -e "${CYAN}curl http://$SERVER_IP/api/health${NC}"
echo ""
echo -e "# 3. 执行测试脚本"
echo -e "${CYAN}curl -X POST http://$SERVER_IP/api/exec-script \\${NC}"
echo -e "${CYAN}  -H 'Content-Type: application/json' \\${NC}"
echo -e "${CYAN}  -d '{\"script\": \"test.sh\", \"args\": [\"hello\", \"world\"]}'${NC}"
echo ""
echo -e "# 4. 导入用户数据"
echo -e "${CYAN}curl -X POST http://$SERVER_IP/api/mongo/import \\${NC}"
echo -e "${CYAN}  -H 'Content-Type: application/json' \\${NC}"
echo -e "${CYAN}  -d '{\"collection\": \"users\", \"file\": \"users.json\"}'${NC}"
echo ""
echo -e "# 5. 查询用户数据"
echo -e "${CYAN}curl 'http://$SERVER_IP/api/mongo/query?collection=users&limit=10'${NC}"
echo ""
