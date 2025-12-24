#!/bin/bash
# PostgreSQL 16 离线安装脚本 (Ubuntu 24.04)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/../packages"
CONFIG_DIR="$SCRIPT_DIR/../config"
PG_VERSION="16"
PG_PORT="25433"
PG_USER="pguser"
PG_DATA="/var/lib/postgresql/$PG_VERSION/main"
PG_CONF="/etc/postgresql/$PG_VERSION/main"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then
    log_error "请使用 root 权限运行: sudo $0"
    exit 1
fi

log_info "=== PostgreSQL $PG_VERSION 离线安装 ==="

# 安装依赖
log_info "安装系统依赖..."
apt-get update
apt-get install -y ssl-cert locales

locale-gen en_US.UTF-8 zh_CN.UTF-8
update-locale LANG=en_US.UTF-8

# 安装 PostgreSQL 包
log_info "安装 PostgreSQL 包..."
cd "$PACKAGE_DIR"

dpkg -i postgresql-client-common_*.deb || apt-get install -f -y
dpkg -i postgresql-common_*.deb || apt-get install -f -y
dpkg -i postgresql-client-${PG_VERSION}_*.deb || apt-get install -f -y
dpkg -i postgresql-${PG_VERSION}_*.deb || apt-get install -f -y

# 配置 PostgreSQL
log_info "配置 PostgreSQL..."

cp "$PG_CONF/postgresql.conf" "$PG_CONF/postgresql.conf.bak"
cp "$PG_CONF/pg_hba.conf" "$PG_CONF/pg_hba.conf.bak"

# 设置端口和监听地址 (仅本地)
sed -i "s/#port = 5432/port = $PG_PORT/" "$PG_CONF/postgresql.conf"
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" "$PG_CONF/postgresql.conf"

# 应用自定义配置
if [ -f "$CONFIG_DIR/postgresql.conf" ]; then
    cat "$CONFIG_DIR/postgresql.conf" >> "$PG_CONF/postgresql.conf"
fi

# 启动服务
log_info "启动 PostgreSQL 服务..."
systemctl enable postgresql
systemctl restart postgresql

sleep 3

# 创建用户并设置密码
log_info "创建数据库用户 $PG_USER..."
read -sp "请输入 $PG_USER 用户密码: " PG_PASSWORD
echo

sudo -u postgres psql -p $PG_PORT -c "CREATE USER $PG_USER WITH SUPERUSER CREATEDB CREATEROLE PASSWORD '$PG_PASSWORD';"
sudo -u postgres psql -p $PG_PORT -c "ALTER USER postgres PASSWORD '$PG_PASSWORD';"

# 启用常用扩展
log_info "启用常用扩展..."
sudo -u postgres psql -p $PG_PORT -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
sudo -u postgres psql -p $PG_PORT -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
sudo -u postgres psql -p $PG_PORT -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

log_info "=== PostgreSQL $PG_VERSION 安装完成 ==="
systemctl status postgresql --no-pager

log_info ""
log_info "连接信息:"
log_info "  主机: localhost"
log_info "  端口: $PG_PORT"
log_info "  用户: $PG_USER"
log_info "  数据目录: $PG_DATA"
log_info "  配置目录: $PG_CONF"
