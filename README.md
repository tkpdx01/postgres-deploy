# PostgreSQL 16 离线部署包

适用于 Ubuntu 24.04 LTS 离线环境。

## 目录结构

```
postgres-deploy/
├── packages/                   # 离线安装包
├── config/
│   └── postgresql.conf         # 自定义配置
├── scripts/
│   ├── download-packages.ps1   # Windows: 下载 deb 包
│   ├── install-postgres.sh     # Ubuntu: 安装 PostgreSQL
│   ├── uninstall-postgres.sh   # Ubuntu: 卸载脚本
│   └── pg-manage.sh            # Ubuntu: 维护脚本
├── docker-compose.yml          # pgAdmin Web 管理端
└── README.md
```

## 默认配置

| 配置项 | 值 |
|--------|-----|
| 端口 | 25433 |
| 监听地址 | 0.0.0.0 (允许远程连接) |
| 默认数据库 | ai-cases |
| 超级用户 | postgres (安装时设密码) |
| 应用用户 | 安装时创建 (可选) |

## 部署步骤

### 1. Windows 下载离线包

```powershell
cd postgres-deploy\scripts
.\download-packages.ps1
```

下载的包：
- postgresql-16, postgresql-client-16
- postgresql-common, postgresql-client-common
- libpq5, ssl-cert (系统依赖)

### 2. 复制到离线服务器

将整个 `postgres-deploy` 目录复制到 Ubuntu 服务器。

### 3. 安装 PostgreSQL

```bash
cd postgres-deploy
chmod +x scripts/*.sh
sudo ./scripts/install-postgres.sh
```

**安装流程 (5 步):**

| 步骤 | 说明 |
|------|------|
| [1/5] | 安装 deb 包（按依赖顺序） |
| [2/5] | 配置端口和监听地址 |
| [3/5] | 启动服务并验证 |
| [4/5] | 设置密码（postgres + 可选应用用户） |
| [5/5] | 创建 ai-cases 数据库 |

**安装过程中会提示输入:**
1. postgres 超级管理员密码
2. 是否创建应用用户 (Y/n)
3. 应用用户名 (默认: appuser)
4. 应用用户密码

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

## 用户说明

| 用户 | 说明 | 权限 |
|------|------|------|
| postgres | 超级管理员 (系统默认) | SUPERUSER |
| appuser | 应用用户 (安装时创建) | CREATEDB |

- **postgres**: 用于管理任务，不建议应用直接使用
- **appuser**: 用于应用程序连接，权限受限更安全

## 连接示例

```bash
# 使用超级管理员
psql -h localhost -p 25433 -U postgres -d ai-cases

# 使用应用用户
psql -h localhost -p 25433 -U appuser -d ai-cases

# 环境变量方式
export PGPASSWORD=your_password
psql -h localhost -p 25433 -U appuser -d ai-cases
```

**连接字符串:**
```
postgresql://appuser:password@localhost:25433/ai-cases
```

## 日常维护

```bash
./scripts/pg-manage.sh status       # 查看状态
./scripts/pg-manage.sh start        # 启动服务
./scripts/pg-manage.sh stop         # 停止服务
./scripts/pg-manage.sh restart      # 重启服务
./scripts/pg-manage.sh listdb       # 列出数据库
./scripts/pg-manage.sh createdb xxx # 创建数据库
./scripts/pg-manage.sh dropdb xxx   # 删除数据库
./scripts/pg-manage.sh backup       # 全量备份
./scripts/pg-manage.sh backup mydb  # 单库备份
./scripts/pg-manage.sh restore xxx  # 恢复备份
./scripts/pg-manage.sh psql         # 进入终端
./scripts/pg-manage.sh logs         # 查看日志
./scripts/pg-manage.sh config       # 编辑配置
./scripts/pg-manage.sh reload       # 重载配置
```

## 卸载

```bash
sudo ./scripts/uninstall-postgres.sh
```

卸载时会询问：
1. 确认卸载
2. 是否删除数据和配置目录
3. 是否删除备份
4. 是否删除 postgres 系统用户

## 内置扩展

安装时自动启用（在 ai-cases 数据库）：
- uuid-ossp
- pgcrypto

其他可用扩展：hstore, ltree, pg_trgm, pg_stat_statements 等，按需启用：
```sql
CREATE EXTENSION hstore;
CREATE EXTENSION pg_stat_statements;
```

## 配置文件路径

| 文件 | 路径 |
|------|------|
| 主配置 | `/etc/postgresql/16/main/postgresql.conf` |
| 认证配置 | `/etc/postgresql/16/main/pg_hba.conf` |
| 数据目录 | `/var/lib/postgresql/16/main` |
| 备份目录 | `/var/backups/postgresql` |

## 故障排查

```bash
# 查看服务状态
systemctl status postgresql

# 查看日志
journalctl -u postgresql -f

# 检查端口
ss -tlnp | grep 25433

# 检查进程
ps aux | grep postgres

# 测试连接
pg_isready -h localhost -p 25433
```
