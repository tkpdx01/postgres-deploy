#!/bin/bash
# pgAdmin 4 Web 管理端安装脚本 (Docker 方式 - 推荐离线部署)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/../packages"

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

log_info "=== pgAdmin 4 Web 安装 ==="

# 检查 Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker 未安装，请先安装 Docker"
    log_info "离线安装 Docker 请参考: https://docs.docker.com/engine/install/ubuntu/"
    exit 1
fi

# 配置参数
PGADMIN_PORT="${PGADMIN_PORT:-5050}"
PGADMIN_EMAIL="${PGADMIN_EMAIL:-admin@local.dev}"
PGADMIN_DATA="/var/lib/pgadmin"

# 获取密码
read -sp "请设置 pgAdmin 登录密码: " PGADMIN_PASSWORD
echo

# 创建数据目录
mkdir -p "$PGADMIN_DATA"
chown -R 5050:5050 "$PGADMIN_DATA"

# 检查是否有离线镜像
PGADMIN_IMAGE="dpage/pgadmin4:latest"
if [ -f "$PACKAGE_DIR/pgadmin4.tar" ]; then
    log_info "加载离线镜像..."
    docker load -i "$PACKAGE_DIR/pgadmin4.tar"
fi

# 停止旧容器
docker rm -f pgadmin 2>/dev/null || true

# 启动 pgAdmin
log_info "启动 pgAdmin 容器..."
docker run -d \
    --name pgadmin \
    --restart unless-stopped \
    -p "$PGADMIN_PORT:80" \
    -e "PGADMIN_DEFAULT_EMAIL=$PGADMIN_EMAIL" \
    -e "PGADMIN_DEFAULT_PASSWORD=$PGADMIN_PASSWORD" \
    -v "$PGADMIN_DATA:/var/lib/pgadmin" \
    "$PGADMIN_IMAGE"

# 等待启动
log_info "等待服务启动..."
sleep 5

# 检查状态
if docker ps | grep -q pgadmin; then
    log_info "=== pgAdmin 4 安装完成 ==="
    log_info ""
    log_info "访问地址: http://<服务器IP>:$PGADMIN_PORT"
    log_info "登录邮箱: $PGADMIN_EMAIL"
    log_info "登录密码: <你设置的密码>"
    log_info ""
    log_info "添加 PostgreSQL 服务器时使用:"
    log_info "  主机: host.docker.internal 或 服务器IP"
    log_info "  端口: 5432"
    log_info "  用户: postgres"
else
    log_error "pgAdmin 启动失败，请检查 Docker 日志: docker logs pgadmin"
fi
