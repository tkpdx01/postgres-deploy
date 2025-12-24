#!/bin/bash
# PostgreSQL 维护脚本
set -e

PG_VERSION="16"
PG_PORT="25433"
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

usage() {
    echo "PostgreSQL 维护脚本"
    echo ""
    echo "用法: $0 <命令> [参数]"
    echo ""
    echo "命令:"
    echo "  status          查看服务状态"
    echo "  start           启动服务"
    echo "  stop            停止服务"
    echo "  restart         重启服务"
    echo "  backup [db]     备份数据库 (默认全部)"
    echo "  restore <file>  恢复备份"
    echo "  logs [n]        查看日志 (默认100行)"
    echo "  config          编辑配置"
    echo "  reload          重载配置"
    echo "  createdb <name> 创建数据库"
    echo "  dropdb <name>   删除数据库"
    echo "  listdb          列出数据库"
    echo "  psql            进入 psql 终端"
    exit 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 权限运行"
        exit 1
    fi
}

case "${1:-}" in
    status)
        systemctl status postgresql --no-pager
        echo ""
        log_info "数据库列表:"
        sudo -u postgres psql -p $PG_PORT -c "\l"
        ;;
    start)
        check_root
        systemctl start postgresql
        log_info "PostgreSQL 已启动"
        ;;
    stop)
        check_root
        systemctl stop postgresql
        log_info "PostgreSQL 已停止"
        ;;
    restart)
        check_root
        systemctl restart postgresql
        log_info "PostgreSQL 已重启"
        ;;
    backup)
        check_root
        mkdir -p "$BACKUP_DIR"
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        DB_NAME="${2:-}"

        if [ -z "$DB_NAME" ]; then
            # 全量备份
            BACKUP_FILE="$BACKUP_DIR/pg_all_$TIMESTAMP.sql.gz"
            log_info "全量备份到: $BACKUP_FILE"
            sudo -u postgres pg_dumpall -p $PG_PORT | gzip > "$BACKUP_FILE"
        else
            # 单库备份
            BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_$TIMESTAMP.sql.gz"
            log_info "备份 $DB_NAME 到: $BACKUP_FILE"
            sudo -u postgres pg_dump -p $PG_PORT "$DB_NAME" | gzip > "$BACKUP_FILE"
        fi

        log_info "备份完成: $(ls -lh "$BACKUP_FILE" | awk '{print $5}')"
        ;;
    restore)
        check_root
        BACKUP_FILE="${2:-}"
        if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
            log_error "请指定有效的备份文件"
            exit 1
        fi

        log_warn "即将恢复备份: $BACKUP_FILE"
        read -p "确认恢复? (y/N): " confirm
        if [ "$confirm" = "y" ]; then
            gunzip -c "$BACKUP_FILE" | sudo -u postgres psql -p $PG_PORT
            log_info "恢复完成"
        fi
        ;;
    logs)
        LINES="${2:-100}"
        journalctl -u postgresql -n "$LINES" --no-pager
        ;;
    config)
        check_root
        ${EDITOR:-nano} "$PG_CONF/postgresql.conf"
        ;;
    reload)
        check_root
        systemctl reload postgresql
        log_info "配置已重载"
        ;;
    createdb)
        DB_NAME="${2:-}"
        if [ -z "$DB_NAME" ]; then
            log_error "请指定数据库名"
            exit 1
        fi
        sudo -u postgres createdb -p $PG_PORT "$DB_NAME"
        log_info "数据库 $DB_NAME 已创建"
        ;;
    dropdb)
        DB_NAME="${2:-}"
        if [ -z "$DB_NAME" ]; then
            log_error "请指定数据库名"
            exit 1
        fi
        log_warn "即将删除数据库: $DB_NAME"
        read -p "确认删除? (y/N): " confirm
        if [ "$confirm" = "y" ]; then
            sudo -u postgres dropdb -p $PG_PORT "$DB_NAME"
            log_info "数据库 $DB_NAME 已删除"
        fi
        ;;
    listdb)
        sudo -u postgres psql -p $PG_PORT -c "\l"
        ;;
    psql)
        sudo -u postgres psql -p $PG_PORT "${@:2}"
        ;;
    *)
        usage
        ;;
esac
