# Lista de bancos de dados para restaurar
$bancosDados = @("AdventureWorks2022", "applogs", "hades", "matricula")

# Perguntar ao usuário qual banco de dados ele deseja restaurar
Write-Host "Escolha um banco de dados para restaurar:"
for ($i = 0; $i -lt $bancosDados.Count; $i++) {
    Write-Host "$($i+1). $($bancosDados[$i])"
}

$escolha = Read-Host "Digite o numero correspondente ao banco de dados"

# Validar escolha do usuário
if ($escolha -lt 1 -or $escolha -gt $bancosDados.Count) {
    Write-Host "Escolha inválida. Saindo..."
    exit
}

$databaseName = $bancosDados[$escolha - 1]
Write-Host "Banco de dados selecionado: $databaseName"

# Definir diretório local para os backups baixados
$localRestoreDir = "C:\AmbientedeBackup04\restore"
$instanceName = "localhost"

# Verificar se o diretório de restauração existe
if (!(Test-Path -Path $localRestoreDir)) {
    Write-Host "Erro: O diretório de restauração não foi encontrado: $localRestoreDir"
    exit
}

# Função para restaurar um backup
function Restore-Backup {
    param (
        [string]$backupPath,
        [string]$databaseName,
        [string]$instanceName,
        [string]$restoreType,
        [bool]$withRecovery = $false
    )

    Write-Host "Restaurando o ${restoreType} do arquivo: $backupPath ..."

    try {
        # Construir o comando de restauração
        if ($restoreType -eq "backup completo") {
            $restoreQuery = @"
RESTORE DATABASE [$databaseName]
FROM DISK = '$backupPath'
WITH NORECOVERY, REPLACE,
MOVE '$databaseName' TO 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\$databaseName.mdf',
MOVE '${databaseName}_log' TO 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\$databaseName.ldf'
"@
        } elseif ($restoreType -eq "backup diferencial") {
            $restoreQuery = @"
RESTORE DATABASE [$databaseName]
FROM DISK = '$backupPath'
WITH NORECOVERY
"@
        } elseif ($withRecovery) {
            $restoreQuery = @"
RESTORE LOG [$databaseName]
FROM DISK = '$backupPath'
WITH RECOVERY
"@
        } else {
            $restoreQuery = @"
RESTORE LOG [$databaseName]
FROM DISK = '$backupPath'
WITH NORECOVERY
"@
        }

        # Executar a restauração no SQL Server
        Invoke-Sqlcmd -Query $restoreQuery -ServerInstance $instanceName -QueryTimeout 600
        Write-Host "Restauracao do ${restoreType} concluída com sucesso."

    } catch {
        Write-Host "Erro ao restaurar o ${restoreType}: $($_.Exception.Message)"
        exit
    }
}

# Verificar e remover o banco de dados se ele já existir
try {
    Write-Host "Verificando se o banco de dados $databaseName já existe..."
    $checkDatabaseQuery = "IF EXISTS (SELECT name FROM sys.databases WHERE name = '$databaseName') DROP DATABASE [$databaseName];"
    Invoke-Sqlcmd -Query $checkDatabaseQuery -ServerInstance $instanceName
    Write-Host "Banco de dados $databaseName removido para evitar conflitos durante a restauração."
} catch {
    Write-Host "Erro ao remover banco de dados existente: $($_.Exception.Message)"
}

# Restaurar o backup completo mais recente
$fullBackup = Get-ChildItem -Path $localRestoreDir -Filter "*$databaseName*Full*.bak" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -eq $fullBackup) {
    Write-Host "Erro: Nenhum backup completo encontrado no diretório $localRestoreDir"
    exit
}
Restore-Backup -backupPath $fullBackup.FullName -databaseName $databaseName -instanceName $instanceName -restoreType "backup completo"

# Restaurar o backup diferencial mais recente, se disponível
$differentialBackup = Get-ChildItem -Path $localRestoreDir -Filter "*$databaseName*Diff*.bak" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -ne $differentialBackup) {
    try {
        Restore-Backup -backupPath $differentialBackup.FullName -databaseName $databaseName -instanceName $instanceName -restoreType "backup diferencial"
    } catch {
        Write-Host "Erro ao restaurar o backup diferencial. Detalhes: $($_.Exception.Message)"
        exit
    }
} else {
    Write-Host "Nenhum backup diferencial encontrado. Prosseguindo para a restauração dos logs..."
}

# Aplicar backups de log na ordem correta
$logBackups = Get-ChildItem -Path $localRestoreDir -Filter "*$databaseName*Log*.trn" | Sort-Object LastWriteTime
if ($logBackups.Count -eq 0) {
    Write-Host "Nenhum backup de log encontrado. Finalizando a restauração do banco de dados."
    Restore-Backup -backupPath $fullBackup.FullName -databaseName $databaseName -instanceName $instanceName -restoreType "finalização do backup" -withRecovery $true
    exit
}

foreach ($logBackup in $logBackups) {
    # Restaurar cada backup de log sequencialmente
    try {
        if ($logBackup -eq $logBackups[-1]) {
            # Aplicar o último backup de log com RECOVERY
            Restore-Backup -backupPath $logBackup.FullName -databaseName $databaseName -instanceName $instanceName -restoreType "backup de log" -withRecovery $true
        } else {
            Restore-Backup -backupPath $logBackup.FullName -databaseName $databaseName -instanceName $instanceName -restoreType "backup de log"
        }
    } catch {
        Write-Host "Erro ao restaurar o backup de log. Detalhes: $($_.Exception.Message)"
        exit
    }
}

Write-Host "Restauracao do banco de dados $databaseName concluída com sucesso."
