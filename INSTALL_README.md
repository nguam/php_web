# Ubuntu 服务器环境安装说明

## 📋 脚本功能

这个安装脚本会自动检测你的 Ubuntu 版本，并安装对应的软件版本组合。

## 🔍 版本对应关系

| Ubuntu 版本 | PHP 版本 | MongoDB 版本 | Redis 版本 | Nginx 版本 |
|------------|---------|-------------|-----------|-----------|
| **24.04 LTS** (Noble) | **8.3** | **7.0** | **7.2** | 最新稳定版 |
| **23.10/23.04** | **8.2** | **7.0** | **7.0** | 最新稳定版 |
| **22.04 LTS** (Jammy) ⭐ | **8.1** | **6.0** | **6.2** | 最新稳定版 |
| **20.04 LTS** (Focal) | **8.0** | **5.0** | **6.0** | 最新稳定版 |
| **18.04 LTS** (Bionic) | **7.4** | **4.4** | **5.0** | 最新稳定版 |

⭐ **推荐使用 Ubuntu 22.04 LTS**（长期支持到 2027 年）

## 📦 安装的软件和扩展

### 核心软件
- ✅ **Nginx** - Web 服务器和反向代理
- ✅ **PHP + PHP-FPM** - 后端脚本语言和进程管理器
- ✅ **MongoDB** - NoSQL 数据库
- ✅ **Redis** - 内存数据库/缓存

### PHP 核心扩展
- `php-fpm` - FastCGI 进程管理器
- `php-cli` - 命令行接口
- `php-common` - 通用文件
- `php-mysql` - MySQL/MariaDB 支持
- `php-curl` - HTTP 请求客户端
- `php-json` - JSON 处理
- `php-mbstring` - 多字节字符串支持
- `php-xml` - XML 解析
- `php-zip` - ZIP 压缩支持
- `php-bcmath` - 高精度数学运算
- `php-intl` - 国际化支持
- `php-gd` - 图像处理
- `php-opcache` - 代码缓存加速

### PHP 数据库扩展
- ✅ **php-mongodb** - MongoDB 驱动（通过 apt 或 PECL）
- ✅ **php-redis** - Redis 客户端（通过 apt 或 PECL）

### 其他工具
- ✅ **Composer** - PHP 包管理器
- ✅ **MongoDB Tools** - mongodump、mongorestore 等
- ✅ **Node.js + npm** - 前端工具链（可选）
- ✅ **Git** - 版本控制
- ✅ **Curl/Wget** - 下载工具
- ✅ **Vim/Nano** - 文本编辑器
- ✅ **Htop** - 系统监控

## 🚀 使用方法

### 1. 上传脚本到 Ubuntu 服务器

**方式 A：使用你的 ssh_manager**
```bash
# 在你的 Mac 上
cd /Users/zhaoneng/zhaon/ssh_manager
./ssh_connect.sh

# 选择 "树莓派5 Ubuntu(内网)" 连接后执行：
cd ~
nano install_server.sh
# 粘贴脚本内容，保存
```

**方式 B：使用 SCP 直接传输**
```bash
# 在你的 Mac 上
scp /Users/zhaoneng/zhaon/ttgame/migrate/web/install_server.sh ubuntu@192.168.2.87:~/
```

**方式 C：使用 curl 下载（如果你把脚本放到云端）**
```bash
# 在 Ubuntu 服务器上
curl -o install_server.sh https://your-url/install_server.sh
```

### 2. 赋予执行权限
```bash
chmod +x install_server.sh
```

### 3. 运行安装（需要 root 权限）
```bash
sudo bash install_server.sh
```

### 4. 安装过程

脚本会：
1. 检测你的 Ubuntu 版本
2. 显示将要安装的软件版本
3. 询问是否确认安装
4. 自动安装所有组件
5. 配置服务自动启动
6. 创建项目目录 `/var/www/api`
7. 生成 Nginx 配置
8. 创建测试文件

## 🧪 安装后测试

脚本安装完成后，会显示测试链接。在浏览器中访问：

### 1. 测试 PHP 是否工作
```
http://your-server-ip/info.php
```
应该看到 PHP 信息页面。

### 2. 测试 MongoDB 连接
```
http://your-server-ip/test_mongo.php
```
应该返回：
```json
{"status":"success","message":"MongoDB 连接成功"}
```

### 3. 测试 Redis 连接
```
http://your-server-ip/test_redis.php
```
应该返回：
```json
{"status":"success","message":"Redis 连接成功"}
```

### 4. 命令行测试

**测试 PHP 扩展**
```bash
php -m | grep mongodb
php -m | grep redis
```

**测试 MongoDB**
```bash
mongosh
> db.version()
> exit
```

**测试 Redis**
```bash
redis-cli ping
# 应该返回 PONG
```

## 📁 安装后的目录结构

```
/var/www/api/
├── scripts/          # 存放 Shell 脚本
├── data/             # 存放数据文件（如 JSON）
├── logs/             # 日志目录
├── index.php         # 你的主应用（需要自己创建）
├── info.php          # PHP 信息页（测试用）
├── test_mongo.php    # MongoDB 测试（测试用）
└── test_redis.php    # Redis 测试（测试用）
```

## 🔧 配置文件位置

| 软件 | 配置文件路径 |
|-----|------------|
| Nginx | `/etc/nginx/nginx.conf` |
| Nginx 站点配置 | `/etc/nginx/sites-available/api` |
| PHP-FPM | `/etc/php/{版本}/fpm/php-fpm.conf` |
| PHP 配置 | `/etc/php/{版本}/fpm/php.ini` |
| MongoDB | `/etc/mongod.conf` |
| Redis | `/etc/redis/redis.conf` |

## 🔐 安全建议

### 1. 安装完成后删除测试文件
```bash
sudo rm /var/www/api/info.php
sudo rm /var/www/api/test_*.php
```

### 2. 配置 MongoDB 认证
```bash
mongosh
use admin
db.createUser({
  user: "admin",
  pwd: "your-strong-password",
  roles: [{role: "root", db: "admin"}]
})
exit

# 编辑配置启用认证
sudo nano /etc/mongod.conf
# 添加：
# security:
#   authorization: enabled

sudo systemctl restart mongod
```

### 3. 配置 Redis 密码
```bash
sudo nano /etc/redis/redis.conf
# 找到并修改：
# requirepass your-strong-password

sudo systemctl restart redis-server
```

### 4. 配置防火墙（仅允许必要端口）
```bash
sudo ufw status
# 脚本已自动配置：22(SSH), 80(HTTP), 443(HTTPS)
```

### 5. 禁止外网访问数据库
MongoDB 和 Redis 默认只监听 127.0.0.1（本地），这是安全的。
如需确认：
```bash
sudo netstat -tlnp | grep mongod   # 应该看到 127.0.0.1:27017
sudo netstat -tlnp | grep redis    # 应该看到 127.0.0.1:6379
```

## 📊 服务管理命令

### 查看服务状态
```bash
sudo systemctl status nginx
sudo systemctl status php8.1-fpm    # 根据你的版本调整
sudo systemctl status mongod
sudo systemctl status redis-server
```

### 启动/停止/重启服务
```bash
# Nginx
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx
sudo systemctl reload nginx  # 重载配置不中断服务

# PHP-FPM
sudo systemctl restart php8.1-fpm

# MongoDB
sudo systemctl restart mongod

# Redis
sudo systemctl restart redis-server
```

### 查看日志
```bash
# Nginx 日志
sudo tail -f /var/log/nginx/api_access.log
sudo tail -f /var/log/nginx/api_error.log

# PHP-FPM 日志
sudo tail -f /var/log/php8.1-fpm.log

# MongoDB 日志
sudo tail -f /var/log/mongodb/mongod.log

# Redis 日志
sudo tail -f /var/log/redis/redis-server.log
```

## ❓ 常见问题

### Q1: 脚本提示 "请使用 root 权限运行"
```bash
# 确保使用 sudo
sudo bash install_server.sh
```

### Q2: MongoDB 启动失败
```bash
# 查看日志
sudo tail -50 /var/log/mongodb/mongod.log

# 检查端口占用
sudo netstat -tlnp | grep 27017

# 重新启动
sudo systemctl restart mongod
```

### Q3: PHP 扩展未加载
```bash
# 检查扩展是否存在
php -m | grep mongodb
php -m | grep redis

# 手动启用扩展
sudo phpenmod mongodb
sudo phpenmod redis
sudo systemctl restart php8.1-fpm
```

### Q4: Nginx 502 Bad Gateway
```bash
# 检查 PHP-FPM 是否运行
sudo systemctl status php8.1-fpm

# 检查 socket 文件
ls -la /run/php/

# 确保 Nginx 配置中的 socket 路径正确
sudo nano /etc/nginx/sites-available/api
```

### Q5: 如何卸载重装
```bash
# 停止服务
sudo systemctl stop nginx php8.1-fpm mongod redis-server

# 卸载软件
sudo apt remove --purge nginx php* mongodb-org* redis-server
sudo apt autoremove

# 删除配置和数据（谨慎！）
sudo rm -rf /etc/nginx /etc/php /var/lib/mongodb /var/lib/redis

# 重新运行安装脚本
sudo bash install_server.sh
```

## 📞 技术支持

如果遇到问题：
1. 查看日志文件（上面有路径）
2. 检查服务状态（systemctl status）
3. 确认防火墙规则（sudo ufw status）
4. 验证配置文件语法（nginx -t）

## 🎉 下一步

安装完成后，你可以：
1. 上传我之前提供的 PHP API 代码到 `/var/www/api/index.php`
2. 创建你的 Shell 脚本放到 `/var/www/api/scripts/`
3. 准备 JSON 数据文件放到 `/var/www/api/data/`
4. 开始开发你的应用！

需要我帮你创建完整的 API 代码文件吗？
