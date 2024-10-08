# Definir parâmetros gerais para o S3 e local
$s3Bucket = "sql-server-bkp-ep"                               # Nome do bucket do S3
$localRestoreDir = "C:\AmbientedeBackup04\restore"            # Diretório local para salvar os backups
$awsCliPath = "aws"                                           # Caminho para o AWS CLI (assumindo que está no PATH)

# Certificar que o diretório de restauração existe
if (!(Test-Path -Path $localRestoreDir)) {
    New-Item -Path $localRestoreDir -ItemType Directory
}

# Lista de bancos de dados disponíveis
$bancosDados = @("AdventureWorks2022", "applogs", "hades", "matricula")

# Perguntar ao usuário qual banco de dados ele deseja baixar
Write-Host "Escolha um banco de dados para baixar o backup:"
for ($i = 0; $i -lt $bancosDados.Count; $i++) {
    Write-Host "$($i+1). $($bancosDados[$i])"
}

$escolha = Read-Host "Digite o numero correspondente ao banco de dados"

# Validar escolha do usuário
if ($escolha -lt 1 -or $escolha -gt $bancosDados.Count) {
    Write-Host "Escolha inválida. Saindo..."
    exit
}

$bancoSelecionado = $bancosDados[$escolha - 1]
Write-Host "Banco de dados selecionado: $bancoSelecionado"

# Definir os caminhos S3 baseados no banco de dados selecionado
$s3FullPath = "s3://$s3Bucket/$bancoSelecionado/Full/"                  # Caminho no S3 para backups completos
$s3DiffPath = "s3://$s3Bucket/$bancoSelecionado/Diferencial/"           # Caminho no S3 para backups diferenciais
$s3LogPath = "s3://$s3Bucket/$bancoSelecionado/Log/"                    # Caminho no S3 para backups de log

# Função para baixar o arquivo mais recente de uma pasta S3
function Download-LatestBackup {
    param (
        [string]$s3SourcePath,
        [string]$localDestDir,
        [string]$filterType
    )

    Write-Host "Listando backups no Amazon S3 em $s3SourcePath..."

    # Listar os arquivos no bucket S3 e obter o mais recente
    $listCmd = "$awsCliPath s3 ls `"$s3SourcePath`" --recursive"
    $listOutput = Invoke-Expression $listCmd

    # Verificar se o comando retornou algo
    if ($listOutput -eq $null -or $listOutput -eq "") {
        Write-Host "Erro: Nenhum arquivo $filterType encontrado no caminho $s3SourcePath."
        exit
    }

    # Obter o arquivo mais recente
    $latestFile = $listOutput | Sort-Object { [datetime]$_.Substring(0, 19) } -Descending | Select-Object -First 1

    if ($latestFile -eq $null) {
        Write-Host "Erro: Nenhum arquivo $filterType encontrado no caminho $s3SourcePath."
        exit
    }

    # Extrair o nome do arquivo do resultado (somente o nome do arquivo e não o caminho completo)
    $latestFileKey = ($latestFile -split '\s+')[-1].Trim()

    # Montar o caminho completo do arquivo no S3 e o destino local
    $s3FilePath = "s3://$s3Bucket/$latestFileKey"
    $localFileName = [System.IO.Path]::GetFileName($latestFileKey)
    $localFilePath = Join-Path -Path $localDestDir -ChildPath $localFileName

    # Baixar o arquivo mais recente
    Write-Host "Baixando o arquivo mais recente ($localFileName) de $s3FilePath para $localDestDir..."
    $downloadCmd = "$awsCliPath s3 cp `"$s3FilePath`" `"$localFilePath`""
    Invoke-Expression $downloadCmd

    if ($LASTEXITCODE -eq 0) {
        Write-Host "$filterType baixado com sucesso para $localFilePath"
    } else {
        Write-Host "Erro ao baixar o $filterType do Amazon S3. Código de erro: $LASTEXITCODE"
        exit
    }
}

# Baixar o backup completo mais recente
Download-LatestBackup $s3FullPath $localRestoreDir "backup completo"

# Baixar o backup diferencial mais recente
Download-LatestBackup $s3DiffPath $localRestoreDir "backup diferencial"

# Baixar os backups de log mais recentes
Write-Host "Baixando todos os backups de log do Amazon S3..."
$downloadLogsCmd = "$awsCliPath s3 sync `"$s3LogPath`" `"$localRestoreDir`""
Invoke-Expression $downloadLogsCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host "Backups de log baixados com sucesso para $localRestoreDir"
} else {
    Write-Host "Erro ao baixar os backups de log do Amazon S3. Código de erro: $LASTEXITCODE"
    exit
}
