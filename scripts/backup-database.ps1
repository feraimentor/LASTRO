param(
  [Parameter(Mandatory=$true)][string]$TargetDirectory
)
$ErrorActionPreference = "Stop"
if (-not $env:LASTRO_DATABASE_URL) { throw "Defina LASTRO_DATABASE_URL com uma credencial de backup restrita." }
$resolvedTarget = [System.IO.Path]::GetFullPath($TargetDirectory)
New-Item -ItemType Directory -Force -Path $resolvedTarget | Out-Null
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$backupFile = Join-Path $resolvedTarget "lastro-$stamp.dump"
$checksumFile = "$backupFile.sha256"
& pg_dump.exe --format=custom --compress=9 --no-owner --no-acl --file=$backupFile $env:LASTRO_DATABASE_URL
if ($LASTEXITCODE -ne 0) { throw "pg_dump falhou." }
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $backupFile).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksumFile -Value "$hash  $([System.IO.Path]::GetFileName($backupFile))" -Encoding ascii
Write-Output $backupFile
