# PostgreSQL 16 离线部署包

适用于 Ubuntu 24.04 LTS 离线环境。

## 目录结构

```
postgres-deploy/
├── packages/                # 离线安装包
├── config/
│   └── postgresql.conf      # 自定义配置
├── scripts/
│   ├── download-packages.ps1  # Windows: 下载 deb 包
│   ├── install-postgres.sh    # Ubuntu: 安装 PostgreSQL
│   └── pg-manage.sh           # Ubuntu: 维护脚本
├── docker-compose.yml       # pgAdmin Web 管理端
└── README.md
```

## 默认配置

| 配置项 | 值 |
|--------|-----|
| 端口 | 25433 |
| 监听地址 | localhost |
| 用户名 | pguser |
| 密码 | 安装时设置 |

## 部署步骤

### 1. Windows 下载离线包

```powershell
cd postgres-deploy\scripts
.\download-packages.ps1
```

### 2. 复制到离线服务器

将整个 `postgres-deploy` 目录复制到 Ubuntu 服务器。

### 3. 安装 PostgreSQL

```bash
cd postgres-deploy
chmod +x scripts/*.sh
sudo ./scripts/install-postgres.sh
```

### 4. 安装 pgAdmin (可选，需要 Docker)

```bash
# 设置密码
export PGADMIN_PASSWORD=your_password

# 启动
docker compose up -d

# 访问 http://localhost:5050
# 邮箱: admin@local.dev
# 密码: your_password
```

## 日常维护

```bash
./scripts/pg-manage.sh status       # 状态
./scripts/pg-manage.sh backup       # 全量备份
./scripts/pg-manage.sh backup mydb  # 单库备份
./scripts/pg-manage.sh restore xxx  # 恢复
./scripts/pg-manage.sh createdb xxx # 创建库
./scripts/pg-manage.sh psql         # 进入终端
./scripts/pg-manage.sh logs         # 查看日志
```

## 连接示例

```bash
psql -h localhost -p 25433 -U pguser -d postgres
```

## 内置扩展

安装时自动启用：
- uuid-ossp
- pgcrypto
- pg_stat_statements

其他可用扩展：hstore, ltree, pg_trgm 等，按需启用：
```sql
CREATE EXTENSION hstore;
```

## 配置文件

- PostgreSQL: `/etc/postgresql/16/main/postgresql.conf`
- 数据目录: `/var/lib/postgresql/16/main`
- 备份目录: `/var/backups/postgresql`
