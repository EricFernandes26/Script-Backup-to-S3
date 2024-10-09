# Lista de bancos de dados para backup
$bancosDados = @("AdventureWorks2022", "applogs", "hades", "matricula")

# Diretório local para salvar os backups
$localBackupDir = "C:\AmbientedeBackup04\Full\"
$s3Bucket = "sql-server-bkp-ep"
$awsCliPath = "aws"

# Configuração de login SQL Server
$sqlLogin = "backup_user"  # Nome do login SQL Server
$sqlPassword = "P@ssw0rd123!"  # Senha do login

# Certificar que o diretório de backup existe
if (!(Test-Path -Path $localBackupDir)) {
    New-Item -Path $localBackupDir -ItemType Directory
}

# Função para realizar o backup com compressão nativa e enviar ao S3
function Realizar-Backup {
    param (
        [string]$bancoDados
    )

    # Definir nome do backup
    $nomeBackup = "${bancoDados}-Full-$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss').bak"
    $caminhoBackup = "$localBackupDir$nomeBackup"

    # Caminho específico do banco de dados no S3
    $s3Path = "$bancoDados/Full/"

    # Realizar o backup completo do banco de dados com compressão
    Write-Host "Iniciando o backup completo do banco de dados $bancoDados com compressão..."
    try {
        $backupQuery = @"
BACKUP DATABASE [$bancoDados]
TO DISK = '$caminhoBackup'
WITH FORMAT, INIT, COMPRESSION, NAME = 'Full Backup de $bancoDados'
"@
        Invoke-Sqlcmd -Query $backupQuery -ServerInstance "localhost" -Username $sqlLogin -Password $sqlPassword -QueryTimeout 600
        Write-Host "Backup completo e compactado do banco de dados $bancoDados concluído com sucesso em $caminhoBackup"
    } catch {
        Write-Host "Erro ao fazer backup completo do banco de dados ${bancoDados}: $($_.Exception.Message)"
        exit
    }

    # Carregar o backup compactado para o S3
    Write-Host "Carregando o backup completo para o Amazon S3..."
    $uploadCmd = "$awsCliPath s3 cp `"$caminhoBackup`" `"$("s3://$s3Bucket/$s3Path$(Split-Path $caminhoBackup -Leaf)")`""
    Invoke-Expression $uploadCmd

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Backup completo carregado com sucesso para s3://$s3Bucket/$s3Path"
    } else {
        Write-Host "Erro ao carregar o backup completo para o Amazon S3. Código de erro: $LASTEXITCODE"
    }

    # Limpeza de backups antigos - manter apenas os 4 mais recentes no diretório local
    $arquivosBackup = Get-ChildItem -Path $localBackupDir -Filter "*.bak" | Sort-Object LastWriteTime -Descending
    if ($arquivosBackup.Count -gt 4) {
        Write-Host "Limpando backups completos antigos..."
        $arquivosBackup | Select-Object -Skip 4 | ForEach-Object {
            Remove-Item -Path $_.FullName -Force
            Write-Host "Removido backup antigo: $($_.FullName)"
        }
    }
}

# Executar o backup para cada banco de dados na lista
foreach ($banco in $bancosDados) {
    Realizar-Backup -bancoDados $banco
}
