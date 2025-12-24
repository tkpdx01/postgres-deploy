# PostgreSQL 16 + pgAdmin 4 offline package download script (Windows PowerShell)
# For Ubuntu 24.04 (noble)

$ErrorActionPreference = "Stop"
$PackageDir = "$PSScriptRoot\..\packages"

New-Item -ItemType Directory -Force -Path $PackageDir | Out-Null

Write-Host "=== PostgreSQL 16 + pgAdmin 4 Offline Package Download ===" -ForegroundColor Cyan
Write-Host "Target: Ubuntu 24.04 (noble)" -ForegroundColor Yellow

# GPG Keys
Write-Host "`n[1/3] Downloading GPG Keys..." -ForegroundColor Green
Invoke-WebRequest -Uri "https://www.postgresql.org/media/keys/ACCC4CF8.asc" -OutFile "$PackageDir\postgresql.asc"
Invoke-WebRequest -Uri "https://www.pgadmin.org/static/packages_pgadmin_org.pub" -OutFile "$PackageDir\pgadmin.asc"

Write-Host "`n[2/3] Downloading PostgreSQL 16.11 packages..." -ForegroundColor Green

# PostgreSQL 16.11 for Ubuntu 24.04 (latest as of Dec 2024)
# Note: %2B in URL = + sign (URL encoded)
$PG_PACKAGES = @(
    @{name="postgresql-16_16.11-1.pgdg24.04+1_amd64.deb"; url="https://apt.postgresql.org/pub/repos/apt/pool/main/p/postgresql-16/postgresql-16_16.11-1.pgdg24.04%2B1_amd64.deb"}
    @{name="postgresql-client-16_16.11-1.pgdg24.04+1_amd64.deb"; url="https://apt.postgresql.org/pub/repos/apt/pool/main/p/postgresql-16/postgresql-client-16_16.11-1.pgdg24.04%2B1_amd64.deb"}
    @{name="libpq5_16.11-1.pgdg24.04+1_amd64.deb"; url="https://apt.postgresql.org/pub/repos/apt/pool/main/p/postgresql-16/libpq5_16.11-1.pgdg24.04%2B1_amd64.deb"}
    @{name="postgresql-common_287.pgdg24.04+1_all.deb"; url="https://apt.postgresql.org/pub/repos/apt/pool/main/p/postgresql-common/postgresql-common_287.pgdg24.04%2B1_all.deb"}
    @{name="postgresql-client-common_287.pgdg24.04+1_all.deb"; url="https://apt.postgresql.org/pub/repos/apt/pool/main/p/postgresql-common/postgresql-client-common_287.pgdg24.04%2B1_all.deb"}
)

foreach ($pkg in $PG_PACKAGES) {
    Write-Host "  Downloading: $($pkg.name)"
    try {
        Invoke-WebRequest -Uri $pkg.url -OutFile "$PackageDir\$($pkg.name)"
        Write-Host "    OK" -ForegroundColor Green
    } catch {
        Write-Host "    FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n[3/3] Downloading pgAdmin 4 Docker image info..." -ForegroundColor Green
Write-Host "  pgAdmin will be deployed via Docker (recommended for offline)" -ForegroundColor Yellow
Write-Host "  Run download-pgadmin-image.ps1 if Docker Desktop is available" -ForegroundColor Yellow

Write-Host "`n=== Download Complete ===" -ForegroundColor Cyan
Write-Host "Packages saved to: $PackageDir" -ForegroundColor Green

Get-ChildItem $PackageDir | Format-Table Name, @{N="Size(MB)";E={[math]::Round($_.Length/1MB,2)}} -AutoSize
