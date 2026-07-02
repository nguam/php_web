#!/bin/bash
# ============================================================
# Ubuntu 服务器环境自动安装脚本
# 功能：自动检测 Ubuntu 版本并安装对应的软件版本
# 包括：Nginx, PHP, MongoDB, Redis 及相关扩展
# ============================================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 权限运行此脚本"
        echo "运行方式: sudo bash $0"
        exit 1
    fi
}

# 检测 Ubuntu 版本
detect_ubuntu_version() {
    if [ ! -f /etc/os-release ]; then
        log_error "无法检测系统版本，请确保这是 Ubuntu 系统"
        exit 1
    fi

    . /etc/os-release
    UBUNTU_VERSION=$VERSION_ID
    UBUNTU_CODENAME=$VERSION_CODENAME

    log_info "检测到 Ubuntu 版本: $VERSION ($UBUNTU_CODENAME)"
}

# 根据 Ubuntu 版本确定软件版本
determine_versions() {
    log_step "根据 Ubuntu 版本确定软件版本..."

    case $UBUNTU_VERSION in
        "24.04")
            # Ubuntu 24.04 LTS (Noble)
            PHP_VERSION="8.3"
            MONGODB_VERSION="7.0"
            REDIS_VERSION="7.2"
            NGINX_VERSION="latest"
            log_info "Ubuntu 24.04 → PHP 8.3, MongoDB 7.0, Redis 7.2"
            ;;
        "23.10"|"23.04")
            # Ubuntu 23.x
            PHP_VERSION="8.2"
            MONGODB_VERSION="7.0"
            REDIS_VERSION="7.0"
            NGINX_VERSION="latest"
            log_info "Ubuntu 23.x → PHP 8.2, MongoDB 7.0, Redis 7.0"
            ;;
        "22.04")
            # Ubuntu 22.04 LTS (Jammy) - 最常用
            PHP_VERSION="8.1"
            MONGODB_VERSION="6.0"
            REDIS_VERSION="6.2"
            NGINX_VERSION="latest"
            log_info "Ubuntu 22.04 LTS → PHP 8.1, MongoDB 6.0, Redis 6.2"
            ;;
        "20.04")
            # Ubuntu 20.04 LTS (Focal)
            PHP_VERSION="8.0"
            MONGODB_VERSION="5.0"
            REDIS_VERSION="6.0"
            NGINX_VERSION="latest"
            log_info "Ubuntu 20.04 LTS → PHP 8.0, MongoDB 5.0, Redis 6.0"
            ;;
        "18.04")
            # Ubuntu 18.04 LTS (Bionic) - 较旧
            PHP_VERSION="7.4"
            MONGODB_VERSION="4.4"
            REDIS_VERSION="5.0"
            NGINX_VERSION="latest"
            log_warn "Ubuntu 18.04 已较旧，建议升级系统"
            log_info "Ubuntu 18.04 → PHP 7.4, MongoDB 4.4, Redis 5.0"
            ;;
        *)
            log_warn "未识别的 Ubuntu 版本，使用默认配置"
            PHP_VERSION="8.1"
            MONGODB_VERSION="6.0"
            REDIS_VERSION="6.2"
            NGINX_VERSION="latest"
            ;;
    esac

    # PHP MongoDB 扩展版本（通常跟随 PHP 版本）
    PHP_MONGODB_EXT_VERSION="auto"  # 从仓库自动安装
    PHP_REDIS_EXT_VERSION="auto"

    log_info "=== 确定的版本 ==="
    log_info "PHP: $PHP_VERSION"
    log_info "MongoDB: $MONGODB_VERSION"
    log_info "Redis: $REDIS_VERSION"
    log_info "Nginx: $NGINX_VERSION"
}

# 检查已安装的软件
check_installed() {
    log_step "检查当前已安装的软件..."

    echo ""
    if command -v nginx &> /dev/null; then
        NGINX_INSTALLED=$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+')
        log_info "✓ Nginx 已安装: $NGINX_INSTALLED"
    else
        log_warn "✗ Nginx 未安装"
    fi

    if command -v php &> /dev/null; then
        PHP_INSTALLED=$(php -v | head -n1 | grep -oP '\d+\.\d+\.\d+')
        log_info "✓ PHP 已安装: $PHP_INSTALLED"
    else
        log_warn "✗ PHP 未安装"
    fi

    if command -v mongod &> /dev/null; then
        MONGO_INSTALLED=$(mongod --version | grep -oP 'v\d+\.\d+\.\d+' | head -1 | sed 's/v//')
        log_info "✓ MongoDB 已安装: $MONGO_INSTALLED"
    else
        log_warn "✗ MongoDB 未安装"
    fi

    if command -v redis-server &> /dev/null; then
        REDIS_INSTALLED=$(redis-server --version | grep -oP '\d+\.\d+\.\d+')
        log_info "✓ Redis 已安装: $REDIS_INSTALLED"
    else
        log_warn "✗ Redis 未安装"
    fi
    echo ""
}

# 更新系统
update_system() {
    log_step "更新系统包索引..."
    apt update -qq
    log_info "系统更新完成"
}

# 安装基础工具
install_base_tools() {
    log_step "安装基础工具..."

    TOOLS="curl wget gnupg2 ca-certificates lsb-release apt-transport-https software-properties-common git unzip vim htop"

    apt install -y $TOOLS > /dev/null 2>&1
    log_info "基础工具安装完成"
}

# 安装 Nginx
install_nginx() {
    log_step "安装 Nginx..."

    if command -v nginx &> /dev/null; then
        log_warn "Nginx 已安装，跳过"
        return
    fi

    apt install -y nginx > /dev/null 2>&1
    systemctl enable nginx
    systemctl start nginx

    NGINX_VER=$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+')
    log_info "Nginx $NGINX_VER 安装完成"
}

# 安装 PHP 和扩展
install_php() {
    log_step "安装 PHP $PHP_VERSION 及扩展..."

    if command -v php &> /dev/null; then
        CURRENT_PHP=$(php -v | head -n1 | grep -oP '\d+\.\d+')
        if [ "$CURRENT_PHP" == "$PHP_VERSION" ]; then
            log_warn "PHP $PHP_VERSION 已安装，跳过"
            return
        else
            log_warn "已安装 PHP $CURRENT_PHP，将安装 PHP $PHP_VERSION"
        fi
    fi

    # 添加 PHP PPA（适用于需要新版本的情况）
    add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1 || true
    apt update -qq

    # 安装 PHP 核心和扩展
    # 注意：PHP 8.0+ 的 JSON 扩展已内置在 php-common 中，不需要单独安装
    PHP_PACKAGES=(
        "php${PHP_VERSION}-fpm"
        "php${PHP_VERSION}-cli"
        "php${PHP_VERSION}-common"
        "php${PHP_VERSION}-mysql"
        "php${PHP_VERSION}-curl"
        "php${PHP_VERSION}-mbstring"
        "php${PHP_VERSION}-xml"
        "php${PHP_VERSION}-zip"
        "php${PHP_VERSION}-bcmath"
        "php${PHP_VERSION}-intl"
        "php${PHP_VERSION}-gd"
        "php${PHP_VERSION}-opcache"
    )

    for package in "${PHP_PACKAGES[@]}"; do
        if apt install -y "$package" > /dev/null 2>&1; then
            log_info "✓ 安装 $package 成功"
        else
            log_warn "✗ 安装 $package 失败（可能已内置或不存在）"
        fi
    done

    # 启动 PHP-FPM
    systemctl enable php${PHP_VERSION}-fpm
    systemctl start php${PHP_VERSION}-fpm

    PHP_VER=$(php -v | head -n1 | grep -oP '\d+\.\d+\.\d+')
    log_info "PHP $PHP_VER 安装完成"
}

# 安装 PHP MongoDB 扩展
install_php_mongodb() {
    log_step "安装 PHP MongoDB 扩展..."

    # 方式1：尝试从包管理器安装
    if apt-cache show php${PHP_VERSION}-mongodb &> /dev/null; then
        apt install -y php${PHP_VERSION}-mongodb > /dev/null 2>&1
        log_info "PHP MongoDB 扩展安装完成（从包管理器）"
    else
        # 方式2：使用 PECL 安装
        log_warn "包管理器中没有 mongodb 扩展，使用 PECL 安装..."
        apt install -y php${PHP_VERSION}-dev php-pear > /dev/null 2>&1
        pecl install mongodb > /dev/null 2>&1 || true

        # 添加扩展配置
        echo "extension=mongodb.so" > /etc/php/${PHP_VERSION}/mods-available/mongodb.ini
        phpenmod mongodb

        log_info "PHP MongoDB 扩展安装完成（通过 PECL）"
    fi

    # 重启 PHP-FPM
    systemctl restart php${PHP_VERSION}-fpm

    # 验证安装
    if php -m | grep -q mongodb; then
        log_info "✓ PHP MongoDB 扩展已激活"
    else
        log_error "✗ PHP MongoDB 扩展安装失败"
    fi
}

# 安装 MongoDB
install_mongodb() {
    log_step "安装 MongoDB $MONGODB_VERSION..."

    if command -v mongod &> /dev/null; then
        log_warn "MongoDB 已安装，跳过"
        return
    fi

    # 导入 MongoDB GPG 密钥
    curl -fsSL https://www.mongodb.org/static/pgp/server-${MONGODB_VERSION}.asc | \
        gpg --dearmor -o /usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg

    # 添加 MongoDB 仓库
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg ] \
https://repo.mongodb.org/apt/ubuntu $UBUNTU_CODENAME/mongodb-org/${MONGODB_VERSION} multiverse" | \
        tee /etc/apt/sources.list.d/mongodb-org-${MONGODB_VERSION}.list

    apt update -qq

    # 安装 MongoDB
    apt install -y mongodb-org > /dev/null 2>&1

    # 启动 MongoDB
    systemctl enable mongod
    systemctl start mongod

    # 等待 MongoDB 启动
    sleep 3

    MONGO_VER=$(mongod --version | grep -oP 'v\d+\.\d+\.\d+' | head -1 | sed 's/v//')
    log_info "MongoDB $MONGO_VER 安装完成"
}

# 安装 Redis
install_redis() {
    log_step "安装 Redis $REDIS_VERSION..."

    if command -v redis-server &> /dev/null; then
        log_warn "Redis 已安装，跳过"
        return
    fi

    apt install -y redis-server > /dev/null 2>&1

    # 配置 Redis（绑定到本地）
    sed -i 's/^bind 127.0.0.1/bind 127.0.0.1/' /etc/redis/redis.conf
    sed -i 's/^# requirepass/requirepass/' /etc/redis/redis.conf || true

    # 启动 Redis
    systemctl enable redis-server
    systemctl start redis-server

    REDIS_VER=$(redis-server --version | grep -oP '\d+\.\d+\.\d+')
    log_info "Redis $REDIS_VER 安装完成"
}

# 安装 PHP Redis 扩展
install_php_redis() {
    log_step "安装 PHP Redis 扩展..."

    # 方式1：从包管理器安装
    if apt-cache show php${PHP_VERSION}-redis &> /dev/null; then
        apt install -y php${PHP_VERSION}-redis > /dev/null 2>&1
        log_info "PHP Redis 扩展安装完成（从包管理器）"
    else
        # 方式2：使用 PECL 安装
        log_warn "包管理器中没有 redis 扩展，使用 PECL 安装..."
        apt install -y php${PHP_VERSION}-dev php-pear > /dev/null 2>&1
        pecl install redis > /dev/null 2>&1 || true

        # 添加扩展配置
        echo "extension=redis.so" > /etc/php/${PHP_VERSION}/mods-available/redis.ini
        phpenmod redis

        log_info "PHP Redis 扩展安装完成（通过 PECL）"
    fi

    # 重启 PHP-FPM
    systemctl restart php${PHP_VERSION}-fpm

    # 验证安装
    if php -m | grep -q redis; then
        log_info "✓ PHP Redis 扩展已激活"
    else
        log_error "✗ PHP Redis 扩展安装失败"
    fi
}

# 安装其他必要工具
install_additional_tools() {
    log_step "安装其他必要工具..."

    # Composer（PHP 包管理器）
    if ! command -v composer &> /dev/null; then
        log_info "安装 Composer..."
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
        log_info "✓ Composer 安装完成"
    else
        log_info "✓ Composer 已安装"
    fi

    # MongoDB Tools（mongodump, mongorestore 等）
    if ! command -v mongodump &> /dev/null; then
        log_info "安装 MongoDB Tools..."
        apt install -y mongodb-database-tools > /dev/null 2>&1 || log_warn "MongoDB Tools 安装失败"
    fi

    # Node.js 和 npm（可选，用于前端构建）
    if ! command -v node &> /dev/null; then
        log_info "安装 Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - > /dev/null 2>&1
        apt install -y nodejs > /dev/null 2>&1
        NODE_VER=$(node -v)
        log_info "✓ Node.js $NODE_VER 安装完成"
    else
        log_info "✓ Node.js 已安装"
    fi
}

# 配置防火墙
configure_firewall() {
    log_step "配置防火墙..."

    if command -v ufw &> /dev/null; then
        ufw --force enable > /dev/null 2>&1
        ufw allow 22/tcp > /dev/null 2>&1   # SSH
        ufw allow 80/tcp > /dev/null 2>&1   # HTTP
        ufw allow 443/tcp > /dev/null 2>&1  # HTTPS
        log_info "防火墙配置完成（已开放 22, 80, 443 端口）"
    else
        log_warn "未检测到 ufw，跳过防火墙配置"
    fi
}

# 创建项目目录结构
create_project_structure() {
    log_step "创建项目目录结构..."

    PROJECT_DIR="/var/www/api"

    mkdir -p $PROJECT_DIR/{scripts,data,logs}
    chown -R root:root $PROJECT_DIR
    chmod -R 755 $PROJECT_DIR

    log_info "项目目录创建完成: $PROJECT_DIR"
}

# 生成 Nginx 配置
generate_nginx_config() {
    log_step "生成 Nginx 配置..."

    NGINX_CONF="/etc/nginx/sites-available/api"

    cat > $NGINX_CONF <<EOF
server {
    listen 80;
    server_name localhost;

    root /var/www/api;
    index index.php index.html;

    access_log /var/log/nginx/api_access.log;
    error_log /var/log/nginx/api_error.log;

    # PHP 处理
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # 隐藏敏感文件
    location ~ \.(sh|log|json|conf)$ {
        deny all;
    }

    # 允许大文件上传
    client_max_body_size 50M;
}
EOF

    # 启用站点
    ln -sf $NGINX_CONF /etc/nginx/sites-enabled/api

    # 测试配置
    nginx -t > /dev/null 2>&1
    systemctl reload nginx

    log_info "Nginx 配置完成"
}

# 生成测试 PHP 文件
generate_test_files() {
    log_step "生成测试文件..."

    # phpinfo 测试页
    cat > /var/www/api/info.php <<'EOF'
<?php
phpinfo();
?>
EOF

    # MongoDB 连接测试
    cat > /var/www/api/test_mongo.php <<'EOF'
<?php
header('Content-Type: application/json');

try {
    $mongo = new MongoDB\Driver\Manager("mongodb://localhost:27017");
    $command = new MongoDB\Driver\Command(['ping' => 1]);
    $mongo->executeCommand('admin', $command);
    echo json_encode(['status' => 'success', 'message' => 'MongoDB 连接成功']);
} catch (Exception $e) {
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}
?>
EOF

    # Redis 连接测试
    cat > /var/www/api/test_redis.php <<'EOF'
<?php
header('Content-Type: application/json');

try {
    $redis = new Redis();
    $redis->connect('127.0.0.1', 6379);
    $redis->ping();
    echo json_encode(['status' => 'success', 'message' => 'Redis 连接成功']);
} catch (Exception $e) {
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}
?>
EOF

    chown -R root:root /var/www/api

    log_info "测试文件生成完成"
}

# 显示安装总结
show_summary() {
    echo ""
    echo "============================================================"
    log_info "安装完成！"
    echo "============================================================"
    echo ""
    echo "已安装的软件版本："
    echo "  • Ubuntu: $UBUNTU_VERSION ($UBUNTU_CODENAME)"
    echo "  • Nginx: $(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+')"
    echo "  • PHP: $(php -v | head -n1 | grep -oP '\d+\.\d+\.\d+')"
    echo "  • MongoDB: $(mongod --version | grep -oP 'v\d+\.\d+\.\d+' | head -1)"
    echo "  • Redis: $(redis-server --version | grep -oP '\d+\.\d+\.\d+')"
    echo ""
    echo "PHP 扩展："
    php -m | grep -E "(mongodb|redis)" | sed 's/^/  • /'
    echo ""
    echo "项目目录: /var/www/api"
    echo ""
    echo "测试链接："
    echo "  • PHP Info: http://your-server-ip/info.php"
    echo "  • MongoDB 测试: http://your-server-ip/test_mongo.php"
    echo "  • Redis 测试: http://your-server-ip/test_redis.php"
    echo ""
    echo "服务状态："
    systemctl is-active nginx && echo "  • Nginx: 运行中" || echo "  • Nginx: 已停止"
    systemctl is-active php${PHP_VERSION}-fpm && echo "  • PHP-FPM: 运行中" || echo "  • PHP-FPM: 已停止"
    systemctl is-active mongod && echo "  • MongoDB: 运行中" || echo "  • MongoDB: 已停止"
    systemctl is-active redis-server && echo "  • Redis: 运行中" || echo "  • Redis: 已停止"
    echo ""
    echo "============================================================"
}

# 主函数
main() {
    echo ""
    echo "============================================================"
    echo "  Ubuntu 服务器环境自动安装脚本"
    echo "============================================================"
    echo ""

    check_root
    detect_ubuntu_version
    determine_versions
    check_installed

    echo ""
    read -p "确认安装以上版本？(y/n): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "安装已取消"
        exit 0
    fi

    update_system
    install_base_tools
    install_nginx
    install_php
    install_mongodb
    install_php_mongodb
    install_redis
    install_php_redis
    install_additional_tools
    configure_firewall
    create_project_structure
    generate_nginx_config
    generate_test_files
    show_summary
}

# 执行主函数
main
