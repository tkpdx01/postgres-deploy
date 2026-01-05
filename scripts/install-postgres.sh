#!/bin/bash
# PostgreSQL 16 离线安装脚本 (Ubuntu 24.04)
# 标准安装流程：安装包 -> 初始化 -> 配置 -> 设置密码 -> 创建数据库
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/../packages"
CONFIG_DIR="$SCRIPT_DIR/../config"

# ===== 配置项 (可修改) =====
PG_VERSION="16"
PG_PORT="25433"
DEFAULT_DB="ai-cases"          # 默认创建的数据库
# ==========================

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
log_info ""

# ==================== 第一步: 安装 deb 包 ====================
log_info "[1/5] 安装 PostgreSQL 包..."
cd "$PACKAGE_DIR"

# 检查必需的包是否存在
REQUIRED_PKGS=(
    "postgresql-client-common_*.deb"
    "postgresql-common_*.deb"
    "postgresql-client-${PG_VERSION}_*.deb"
    "postgresql-${PG_VERSION}_*.deb"
)

for pattern in "${REQUIRED_PKGS[@]}"; do
    if ! ls $pattern 1>/dev/null 2>&1; then
        log_error "缺少必需的包: $pattern"
        log_error "请先运行 download-packages.ps1 下载所有包"
        exit 1
    fi
done

# 安装系统依赖 (可选)
for pkg in ssl-cert libpq5; do
    if ls ${pkg}_*.deb 1>/dev/null 2>&1; then
        log_info "  安装 ${pkg}..."
        dpkg -i --force-depends ${pkg}_*.deb 2>/dev/null || true
    fi
done

# 按依赖顺序安装 PostgreSQL
log_info "  安装 postgresql-client-common..."
dpkg -i --force-depends postgresql-client-common_*.deb || true

log_info "  安装 postgresql-common..."
dpkg -i --force-depends postgresql-common_*.deb || true

log_info "  安装 postgresql-client-${PG_VERSION}..."
dpkg -i --force-depends postgresql-client-${PG_VERSION}_*.deb || true

log_info "  安装 postgresql-${PG_VERSION}..."
dpkg -i --force-depends postgresql-${PG_VERSION}_*.deb || true

# 验证安装
if ! command -v psql &>/dev/null; then
    log_error "PostgreSQL 安装失败！psql 命令不可用"
    log_error "可能缺少 libpq5，请检查系统是否已安装或添加到 packages 目录"
    exit 1
fi
log_info "  psql 版本: $(psql --version)"

# ==================== 第二步: 配置 ====================
log_info "[2/5] 配置 PostgreSQL..."

# 等待配置文件生成
sleep 2

if [ ! -f "$PG_CONF/postgresql.conf" ]; then
    log_error "配置文件不存在: $PG_CONF/postgresql.conf"
    log_error "PostgreSQL 可能未正确安装"
    exit 1
fi

# 备份原配置
cp "$PG_CONF/postgresql.conf" "$PG_CONF/postgresql.conf.bak"
cp "$PG_CONF/pg_hba.conf" "$PG_CONF/pg_hba.conf.bak"

# 设置端口
sed -i "s/^#\?port = .*/port = $PG_PORT/" "$PG_CONF/postgresql.conf"
sed -i "s/^#\?listen_addresses = .*/listen_addresses = '0.0.0.0'/" "$PG_CONF/postgresql.conf"

# 允许远程连接 (md5 密码认证)
echo "# 允许远程连接" >> "$PG_CONF/pg_hba.conf"
echo "host    all    all    0.0.0.0/0    md5" >> "$PG_CONF/pg_hba.conf"

log_info "  端口: $PG_PORT"
log_info "  监听: 0.0.0.0 (允许远程连接)"

# 应用自定义配置
if [ -f "$CONFIG_DIR/postgresql.conf" ]; then
    cat "$CONFIG_DIR/postgresql.conf" >> "$PG_CONF/postgresql.conf"
    log_info "  已应用自定义配置"
fi

# ==================== 第三步: 启动服务 ====================
log_info "[3/5] 启动 PostgreSQL 服务..."
systemctl daemon-reload
systemctl enable postgresql
systemctl restart postgresql

# 等待服务就绪
for i in {1..10}; do
    if sudo -u postgres pg_isready -p $PG_PORT -q 2>/dev/null; then
        break
    fi
    sleep 1
done

if ! sudo -u postgres pg_isready -p $PG_PORT -q 2>/dev/null; then
    log_error "PostgreSQL 服务启动失败"
    journalctl -u postgresql --no-pager -n 20
    exit 1
fi
log_info "  服务已启动"

# ==================== 第四步: 设置密码 ====================
log_info "[4/5] 设置数据库密码..."
log_info ""
log_warn "PostgreSQL 有两个重要用户:"
log_warn "  - postgres: 超级管理员 (系统默认)"
log_warn "  - 你的应用用户: 用于应用程序连接"
log_info ""

# 设置 postgres 密码
read -sp "请设置 postgres 超级管理员密码: " POSTGRES_PASSWORD
echo
if [ -z "$POSTGRES_PASSWORD" ]; then
    log_error "密码不能为空"
    exit 1
fi

sudo -u postgres psql -p $PG_PORT -c "ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD';" >/dev/null
log_info "  postgres 密码已设置"

# 询问是否创建应用用户
echo ""
read -p "是否创建应用用户? (Y/n): " CREATE_APP_USER
CREATE_APP_USER=${CREATE_APP_USER:-Y}

if [[ "$CREATE_APP_USER" =~ ^[Yy]$ ]]; then
    read -p "应用用户名 [默认: appuser]: " APP_USER
    APP_USER=${APP_USER:-appuser}

    read -sp "应用用户密码: " APP_PASSWORD
    echo
    if [ -z "$APP_PASSWORD" ]; then
        log_error "密码不能为空"
        exit 1
    fi

    sudo -u postgres psql -p $PG_PORT -c "CREATE USER $APP_USER WITH CREATEDB PASSWORD '$APP_PASSWORD';" >/dev/null
    log_info "  用户 $APP_USER 已创建"
fi

# ==================== 第五步: 创建数据库 ====================
log_info "[5/5] 创建数据库..."

# 创建默认数据库
if [ -n "$DEFAULT_DB" ]; then
    OWNER=${APP_USER:-postgres}
    sudo -u postgres psql -p $PG_PORT -c "CREATE DATABASE \"$DEFAULT_DB\" OWNER $OWNER;" >/dev/null 2>&1 || true

    # 启用扩展
    sudo -u postgres psql -p $PG_PORT -d "$DEFAULT_DB" -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" >/dev/null 2>&1
    sudo -u postgres psql -p $PG_PORT -d "$DEFAULT_DB" -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;" >/dev/null 2>&1

    log_info "  数据库 $DEFAULT_DB 已创建 (owner: $OWNER)"
fi

# ==================== 完成 ====================
echo ""
log_info "=========================================="
log_info "  PostgreSQL $PG_VERSION 安装完成!"
log_info "=========================================="
echo ""
log_info "连接信息:"
log_info "  主机: 0.0.0.0 (允许任意IP连接)"
log_info "  端口: $PG_PORT"
log_info "  超级用户: postgres"
if [ -n "$APP_USER" ]; then
    log_info "  应用用户: $APP_USER"
fi
log_info "  默认数据库: $DEFAULT_DB"
echo ""
log_info "连接命令:"
log_info "  psql -h localhost -p $PG_PORT -U postgres -d $DEFAULT_DB"
if [ -n "$APP_USER" ]; then
    log_info "  psql -h localhost -p $PG_PORT -U $APP_USER -d $DEFAULT_DB"
fi
echo ""
log_info "管理脚本:"
log_info "  $SCRIPT_DIR/pg-manage.sh status"
log_info "  $SCRIPT_DIR/pg-manage.sh listdb"
echo ""
