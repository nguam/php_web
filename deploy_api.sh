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
NC='\033[0m'

# 路径配置
API_DIR="/home/ubuntu/zhaon/ttgame/api"

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  API 项目部署脚本${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

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

# 给父目录添加执行权限（让 www-data 可以穿透）
sudo chmod o+x /home/ubuntu
sudo chmod o+x /home/ubuntu/zhaon
sudo chmod o+x /home/ubuntu/zhaon/ttgame

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

echo -e "${BLUE}[2/4] 配置 Nginx...${NC}"

# 创建 Nginx 配置
sudo tee /etc/nginx/sites-available/api > /dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    root $API_DIR;
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

echo -e "${BLUE}[3/4] 验证部署...${NC}"

# 等待服务重启
sleep 2

# 测试 API
echo "  测试 API 接口..."
API_RESPONSE=$(curl -s http://localhost/api)

if echo "$API_RESPONSE" | grep -q "MongoDB & Shell API"; then
    echo -e "${GREEN}✓ API 响应正常${NC}"
elif echo "$API_RESPONSE" | grep -q "404"; then
    echo -e "${RED}✗ API 返回 404${NC}"
    echo -e "${YELLOW}检查文件: ls -la $API_DIR/${NC}"
else
    echo -e "${YELLOW}! API 响应异常${NC}"
    echo -e "${YELLOW}响应内容: $API_RESPONSE${NC}"
fi

# 显示部署的文件列表
echo ""
echo -e "${YELLOW}API 目录内容：${NC}"
ls -lh "$API_DIR" | tail -n +2 | awk '{print "  • " $9 " (" $5 ")"}'

echo ""
echo -e "${BLUE}[4/4] 测试其他接口...${NC}"

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
echo -e "访问地址："
echo -e "  • API 信息: ${GREEN}http://192.168.2.87/api${NC}"
echo -e "  • 健康检查: ${GREEN}http://192.168.2.87/api/health${NC}"
echo ""
echo -e "日志位置："
echo -e "  • Nginx 访问日志: /var/log/nginx/api_access.log"
echo -e "  • Nginx 错误日志: /var/log/nginx/api_error.log"
echo -e "  • PHP 错误日志: /var/log/php8.3-fpm.log"
echo ""
echo -e "${YELLOW}测试命令示例：${NC}"
echo ""
echo -e "# 1. 获取 API 信息"
echo -e "${CYAN}curl http://192.168.2.87/api${NC}"
echo ""
echo -e "# 2. 健康检查"
echo -e "${CYAN}curl http://192.168.2.87/api/health${NC}"
echo ""
echo -e "# 3. 执行测试脚本"
echo -e "${CYAN}curl -X POST http://192.168.2.87/api/exec-script \\${NC}"
echo -e "${CYAN}  -H 'Content-Type: application/json' \\${NC}"
echo -e "${CYAN}  -d '{\"script\": \"test.sh\", \"args\": [\"hello\", \"world\"]}'${NC}"
echo ""
echo -e "# 4. 导入用户数据"
echo -e "${CYAN}curl -X POST http://192.168.2.87/api/mongo/import \\${NC}"
echo -e "${CYAN}  -H 'Content-Type: application/json' \\${NC}"
echo -e "${CYAN}  -d '{\"collection\": \"users\", \"file\": \"users.json\"}'${NC}"
echo ""
echo -e "# 5. 查询用户数据"
echo -e "${CYAN}curl 'http://192.168.2.87/api/mongo/query?collection=users&limit=10'${NC}"
echo ""
