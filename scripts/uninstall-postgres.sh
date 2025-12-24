#!/bin/bash
# PostgreSQL 16 卸载脚本 (Ubuntu 24.04)
set -e

PG_VERSION="16"
PG_DATA="/var/lib/postgresql/$PG_VERSION/main"
PG_CONF="/etc/postgresql/$PG_VERSION/main"
BACKUP_DIR="/var/backups/postgresql"

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

echo ""
log_warn "=== PostgreSQL $PG_VERSION 卸载脚本 ==="
log_warn ""
log_warn "此操作将:"
log_warn "  1. 停止 PostgreSQL 服务"
log_warn "  2. 卸载 PostgreSQL 相关包"
log_warn "  3. 可选删除数据目录"
echo ""

read -p "确认卸载 PostgreSQL? (y/N): " confirm
if [ "$confirm" != "y" ]; then
    log_info "已取消"
    exit 0
fi

# 停止服务
log_info "停止 PostgreSQL 服务..."
systemctl stop postgresql 2>/dev/null || true
systemctl disable postgresql 2>/dev/null || true

# 卸载包
log_info "卸载 PostgreSQL 包..."
dpkg --purge postgresql-${PG_VERSION} 2>/dev/null || true
dpkg --purge postgresql-client-${PG_VERSION} 2>/dev/null || true
dpkg --purge postgresql-common 2>/dev/null || true
dpkg --purge postgresql-client-common 2>/dev/null || true

# 清理残留配置
apt-get autoremove -y 2>/dev/null || true

# 询问是否删除数据
echo ""
log_warn "数据目录: $PG_DATA"
log_warn "配置目录: $PG_CONF"
read -p "是否删除数据和配置? (y/N): " delete_data

if [ "$delete_data" = "y" ]; then
    log_info "删除数据目录..."
    rm -rf "/var/lib/postgresql" 2>/dev/null || true
    rm -rf "/etc/postgresql" 2>/dev/null || true
    rm -rf "/var/log/postgresql" 2>/dev/null || true
    log_info "数据已删除"
else
    log_info "保留数据目录"
fi

# 询问是否删除备份
if [ -d "$BACKUP_DIR" ]; then
    echo ""
    log_warn "备份目录: $BACKUP_DIR"
    read -p "是否删除备份? (y/N): " delete_backup
    if [ "$delete_backup" = "y" ]; then
        rm -rf "$BACKUP_DIR"
        log_info "备份已删除"
    fi
fi

# 删除 postgres 用户 (可选)
if id "postgres" &>/dev/null; then
    echo ""
    read -p "是否删除 postgres 系统用户? (y/N): " delete_user
    if [ "$delete_user" = "y" ]; then
        userdel -r postgres 2>/dev/null || userdel postgres 2>/dev/null || true
        log_info "用户已删除"
    fi
fi

echo ""
log_info "=== PostgreSQL 卸载完成 ==="
