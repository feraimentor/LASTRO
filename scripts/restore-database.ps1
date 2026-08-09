param(
  [Parameter(Mandatory=$true)][string]$BackupFile,
  [Parameter(Mandatory=$true)][string]$TargetDatabaseUrl,
  [Parameter(Mandatory=$true)][ValidateSet("development","preview","staging")][string]$TargetEnvironment
)
$ErrorActionPreference = "Stop"
$resolvedBackup = [System.IO.Path]::GetFullPath($BackupFile)
if (-not (Test-Path -LiteralPath $resolvedBackup -PathType Leaf)) { throw "Backup não encontrado." }
if ($TargetDatabaseUrl -match "prod|production") { throw "Restore destrutivo em produção é proibido por este script." }
& pg_restore.exe --clean --if-exists --no-owner --no-acl --exit-on-error --dbname=$TargetDatabaseUrl $resolvedBackup
if ($LASTEXITCODE -ne 0) { throw "pg_restore falhou." }
Write-Output "Restore concluído em $TargetEnvironment. Execute migrations, legal:verify, pgTAP e smoke tests."
