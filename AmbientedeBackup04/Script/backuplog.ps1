# Definir parâmetros
$bancoDados = "applogs"
$localBackupDir = "C:\AmbientedeBackup04\Logs\"
$nomeBackup = "$bancoDados-Log-$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss').trn"
$s3Bucket = "sql-server-bkp-ep"
$s3Path = "applogs/Log/"
$awsCliPath = "aws"

# Certificar que o diretório de backup existe
if (!(Test-Path -Path $localBackupDir)) {
    New-Item -Path $localBackupDir -ItemType Directory
}

# Caminho completo do backup
$caminhoBackup = "$localBackupDir$nomeBackup"

# Fazer backup de log do banco de dados SQL Server
Write-Host "Iniciando o backup de log do banco de dados $bancoDados..."
try {
    $backupQuery = @"
BACKUP LOG [$bancoDados]
TO DISK = '$caminhoBackup'
WITH FORMAT, INIT, NAME = 'Log Backup de $bancoDados'
"@
    Invoke-Sqlcmd -Query $backupQuery -ServerInstance "localhost" -QueryTimeout 600
    Write-Host "Backup de log do banco de dados $bancoDados concluído com sucesso em $caminhoBackup"
} catch {
    Write-Host "Erro ao fazer backup de log: $($_.Exception.Message)"
    exit
}

# Carregar o backup para o S3
Write-Host "Carregando o backup de log para o Amazon S3..."
$uploadCmd = "$awsCliPath s3 cp `"$caminhoBackup`" `"$("s3://$s3Bucket/$s3Path$nomeBackup")`""
Invoke-Expression $uploadCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host "Backup de log carregado com sucesso para s3://$s3Bucket/$s3Path$nomeBackup"
} else {
    Write-Host "Erro ao carregar o backup de log para o Amazon S3. Código de erro: $LASTEXITCODE"
}

# Limpeza de backups antigos - manter apenas os 10 mais recentes no diretório local
$arquivosBackup = Get-ChildItem -Path $localBackupDir -Filter "*.trn" | Sort-Object LastWriteTime -Descending
if ($arquivosBackup.Count -gt 10) {
    Write-Host "Limpando backups de log antigos..."
    $arquivosBackup | Select-Object -Skip 10 | ForEach-Object {
        Remove-Item -Path $_.FullName -Force
        Write-Host "Removido backup antigo: $($_.FullName)"
    }
}
