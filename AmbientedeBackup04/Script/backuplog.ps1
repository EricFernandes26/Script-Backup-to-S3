# Lista de bancos de dados para backup de logs
$bancosDados = @("AdventureWorks2022", "applogs", "hades", "matricula")

# Diretórios locais para salvar os backups
$localBackupDirFull = "C:\AmbientedeBackup04\Full\"  # Diretório de backup completo
$localBackupDirLog = "C:\AmbientedeBackup04\Logs\"   # Diretório de backup de logs
$s3Bucket = "sql-server-bkp-ep"
$awsCliPath = "aws"

# Configuração de login SQL Server
$sqlLogin = "backup_user"  # Nome do login SQL Server
$sqlPassword = "P@ssw0rd123!"  # Senha do login

# Certificar que os diretórios de backup existem
if (!(Test-Path -Path $localBackupDirLog)) {
    New-Item -Path $localBackupDirLog -ItemType Directory
}

# Função para verificar se existe backup full recente
function Verificar-BackupFull {
    param (
        [string]$bancoDados
    )
    
    # Verificar se existe um backup full nos últimos 7 dias
    $backupFullRecente = Get-ChildItem -Path $localBackupDirFull -Filter "$bancoDados-Full*.bak" | 
                         Where-Object { $_.LastWriteTime -ge (Get-Date).AddDays(-7) } |
                         Sort-Object LastWriteTime -Descending |
                         Select-Object -First 1
    
    if ($null -eq $backupFullRecente) {
        Write-Host "Nenhum backup full recente encontrado para o banco de dados $bancoDados nos últimos 7 dias."
        return $false
    } else {
        Write-Host ("Backup full recente encontrado para o banco de dados {0}: {1}" -f $bancoDados, $backupFullRecente.FullName)
        return $true
    }
}

# Função para realizar o backup de logs e enviar ao S3
function Realizar-BackupLog {
    param (
        [string]$bancoDados
    )

    # Verificar se há um backup full recente
    if (-not (Verificar-BackupFull -bancoDados $bancoDados)) {
        Write-Host "Abortando backup de log para o banco de dados $bancoDados, pois não há backup full recente."
        return
    }

    # Definir nome do backup de log
    $nomeBackup = "${bancoDados}-Log-$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss').trn"
    $caminhoBackup = "$localBackupDirLog$nomeBackup"

    # Caminho específico do banco de dados no S3
    $s3Path = "$bancoDados/Log/"

    # Realizar o backup de log do banco de dados
    Write-Host "Iniciando o backup de log do banco de dados $bancoDados..."
    try {
        $backupQuery = @"
BACKUP LOG [$bancoDados]
TO DISK = '$caminhoBackup'
WITH FORMAT, INIT, NAME = 'Log Backup de $bancoDados'
"@
        Invoke-Sqlcmd -Query $backupQuery -ServerInstance "localhost" -Username $sqlLogin -Password $sqlPassword -QueryTimeout 600
        Write-Host "Backup de log do banco de dados $bancoDados concluído com sucesso em $caminhoBackup"
    } catch {
        Write-Host "Erro ao fazer backup de log do banco de dados ${bancoDados}: $($_.Exception.Message)"
        return
    }

    # Carregar o backup para o S3
    Write-Host "Carregando o backup de log para o Amazon S3..."
    $uploadCmd = "$awsCliPath s3 cp `"$caminhoBackup`" `"$("s3://$s3Bucket/$s3Path$(Split-Path $caminhoBackup -Leaf)")`""
    Invoke-Expression $uploadCmd

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Backup de log carregado com sucesso para s3://$s3Bucket/$s3Path"
    } else {
        Write-Host "Erro ao carregar o backup de log para o Amazon S3. Código de erro: $LASTEXITCODE"
    }

    # Limpeza de backups antigos - manter apenas os 4 mais recentes no diretório local
    $arquivosBackup = Get-ChildItem -Path $localBackupDirLog -Filter "*.trn" | Sort-Object LastWriteTime -Descending
    if ($arquivosBackup.Count -gt 4) {
        Write-Host "Limpando backups de log antigos..."
        $arquivosBackup | Select-Object -Skip 4 | ForEach-Object {
            Remove-Item -Path $_.FullName -Force
            Write-Host "Removido backup antigo: $($_.FullName)"
        }
    }
}

# Executar o backup de logs para cada banco de dados na lista
foreach ($banco in $bancosDados) {
    Realizar-BackupLog -bancoDados $banco
}
