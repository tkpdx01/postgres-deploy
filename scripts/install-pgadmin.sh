#!/bin/bash
# pgAdmin 4 Web 管理端安装脚本 (使用 docker-compose)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
PACKAGE_DIR="$PROJECT_DIR/packages"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "=== pgAdmin 4 Web 安装 ==="

# 检查 Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker 未安装，请先安装 Docker"
    exit 1
fi

# 检查 docker compose
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    log_error "docker compose 未安装"
    exit 1
fi

# 检查 compose 文件
if [ ! -f "$PROJECT_DIR/docker-compose.yml" ]; then
    log_error "docker-compose.yml 不存在: $PROJECT_DIR/docker-compose.yml"
    exit 1
fi

# 加载离线镜像 (如果有)
if [ -f "$PACKAGE_DIR/pgadmin4.tar" ]; then
    log_info "加载离线镜像..."
    docker load -i "$PACKAGE_DIR/pgadmin4.tar"
fi

# 获取密码
if [ -z "$PGADMIN_PASSWORD" ]; then
    read -sp "请设置 pgAdmin 登录密码: " PGADMIN_PASSWORD
    echo
    export PGADMIN_PASSWORD
fi

if [ -z "$PGADMIN_PASSWORD" ]; then
    log_error "密码不能为空"
    exit 1
fi

# 启动服务
log_info "启动 pgAdmin 容器..."
cd "$PROJECT_DIR"
$COMPOSE_CMD down 2>/dev/null || true
$COMPOSE_CMD up -d

# 等待启动
log_info "等待服务启动..."
sleep 5

# 检查状态
if docker ps | grep -q pgadmin; then
    log_info "=== pgAdmin 4 安装完成 ==="
    log_info ""
    log_info "访问地址: http://<服务器IP>:5050"
    log_info "登录邮箱: admin@local.dev"
    log_info "登录密码: <你设置的密码>"
    log_info ""
    log_info "添加 PostgreSQL 服务器时使用:"
    log_info "  主机: host.docker.internal 或 172.17.0.1"
    log_info "  端口: 25433"
    log_info "  用户: postgres 或 appuser"
    log_info ""
    log_info "管理命令:"
    log_info "  cd $PROJECT_DIR && $COMPOSE_CMD logs -f    # 查看日志"
    log_info "  cd $PROJECT_DIR && $COMPOSE_CMD down       # 停止"
    log_info "  cd $PROJECT_DIR && $COMPOSE_CMD up -d      # 启动"
else
    log_error "pgAdmin 启动失败"
    log_error "查看日志: docker logs pgadmin"
    exit 1
fi
