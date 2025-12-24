# 下载 pgAdmin Docker 镜像用于离线部署 (Windows PowerShell)
# 需要本机已安装 Docker Desktop

$ErrorActionPreference = "Stop"
$PackageDir = "$PSScriptRoot\..\packages"

Write-Host "=== 下载 pgAdmin 4 Docker 镜像 ===" -ForegroundColor Cyan

# 检查 Docker
try {
    docker version | Out-Null
} catch {
    Write-Host "错误: Docker 未运行，请启动 Docker Desktop" -ForegroundColor Red
    exit 1
}

Write-Host "拉取 pgAdmin 4 镜像..." -ForegroundColor Green
docker pull dpage/pgadmin4:latest

Write-Host "导出镜像到文件..." -ForegroundColor Green
docker save dpage/pgadmin4:latest -o "$PackageDir\pgadmin4.tar"

$size = (Get-Item "$PackageDir\pgadmin4.tar").Length / 1MB
Write-Host "完成! 镜像大小: $([math]::Round($size, 2)) MB" -ForegroundColor Cyan
Write-Host "文件: $PackageDir\pgadmin4.tar" -ForegroundColor Green
