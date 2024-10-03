# Definir parâmetros
$bancoDados = "applogs"
$localBackupDir = "C:\AmbientedeBackup04\Full\"
$nomeBackup = "$bancoDados-Full-$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss').bak"
$s3Bucket = "sql-server-bkp-ep"
$s3Path = "applogs/Full/"
$awsCliPath = "aws"

# Certificar que o diretório de backup existe
if (!(Test-Path -Path $localBackupDir)) {
    New-Item -Path $localBackupDir -ItemType Directory
}

# Caminho completo do backup
$caminhoBackup = "$localBackupDir$nomeBackup"

# Fazer backup completo do banco de dados SQL Server
Write-Host "Iniciando o backup completo do banco de dados $bancoDados..."
try {
    $backupQuery = @"
BACKUP DATABASE [$bancoDados]
TO DISK = '$caminhoBackup'
WITH FORMAT, INIT, NAME = 'Full Backup de $bancoDados'
"@
    Invoke-Sqlcmd -Query $backupQuery -ServerInstance "localhost" -QueryTimeout 600
    Write-Host "Backup completo do banco de dados $bancoDados concluído com sucesso em $caminhoBackup"
} catch {
    Write-Host "Erro ao fazer backup completo: $($_.Exception.Message)"
    exit
}

# Carregar o backup para o S3
Write-Host "Carregando o backup completo para o Amazon S3..."
$uploadCmd = "$awsCliPath s3 cp `"$caminhoBackup`" `"$("s3://$s3Bucket/$s3Path$nomeBackup")`""
Invoke-Expression $uploadCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host "Backup completo carregado com sucesso para s3://$s3Bucket/$s3Path$nomeBackup"
} else {
    Write-Host "Erro ao carregar o backup completo para o Amazon S3. Código de erro: $LASTEXITCODE"
}

# Limpeza de backups antigos - manter apenas os 2 mais recentes no diretório local
$arquivosBackup = Get-ChildItem -Path $localBackupDir -Filter "*.bak" | Sort-Object LastWriteTime -Descending
if ($arquivosBackup.Count -gt 2) {
    Write-Host "Limpando backups completos antigos..."
    $arquivosBackup | Select-Object -Skip 2 | ForEach-Object {
        Remove-Item -Path $_.FullName -Force
        Write-Host "Removido backup antigo: $($_.FullName)"
    }
}
