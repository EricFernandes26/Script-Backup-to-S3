# Script-Backup-to-S3

# SQL Server Backup & Restore with Amazon S3
Este repositório contém três scripts PowerShell para realizar backups e restauração de bancos de dados SQL Server, utilizando a Amazon S3 para armazenamento de backups. As rotinas incluem:

* Backup completo (Full Backup)
* Backup diferencial (Differential Backup)
* Backup de logs (Log Backup)
* Restauração a partir dos backups armazenados no S3

# Requisitos
##  Software:
* SQL Server: Os scripts utilizam comandos do SQL Server para realizar os backups/restores.
* AWS CLI: Para enviar e baixar os arquivos de backup para/de buckets S3 da Amazon.
* PowerShell: Executa os scripts de automação do backup e restauração.

## Pré-requisitos:
1. AWS CLI instalada e configurada (credenciais, região e acesso ao bucket).
2. Permissões adequadas no SQL Server para realizar backup/restore.
3. Diretórios de backup configurados no servidor (ex: C:\AmbientedeBackup04).
4. Criação de bucket no S3 para armazenamento dos backups.

## Estrutura do Projeto
```bash
## Estrutura do Projeto
├── AmbientedeBackup04/
│   ├── Full/                 # Armazena os backups completos
│   ├── Diferencial/          # Armazena os backups diferenciais
│   ├── Logs/                 # Armazena os backups de logs
│   ├── restore/              # Utilizado para armazenar backups baixados para restauração
├── Script/
│   │   ├── backupfull.ps1       # Script de backup completo
│   │   ├── backupdiff.ps1       # Script de backup diferencial
│   │   ├── backuplog.ps1        # Script de backup de logs
│   ├── Script de restore/
│   │   ├── downloadbkp.ps1      # Script para baixar os backups do S3
│   │   ├── restorebkp.ps1       # Script para restaurar os backups
```

## Configuração
AWS CLI
Certifique-se de que a AWS CLI esteja instalada e configurada corretamente. Acesse o Guia de Instalação da AWS CLI para instruções.

Configure suas credenciais de acesso ao S3 com:
```bash
aws configure
```

## Configurações dos Scripts
Os parâmetros importantes a configurar para os scripts são:
* $bancoDados: Nome do banco de dados SQL Server a ser utilizado.
* $localBackupDir: Diretório local onde os backups serão salvos.
* $s3Bucket: Nome do bucket S3 onde os backups serão armazenados.
* $s3Path: Caminho dentro do bucket S3 para cada tipo de backup (Full, Diferencial, Log).
* $awsCliPath: Caminho do executável da AWS CLI.

## Configurações no Task Scheduler
Para garantir a execução periódica dos backups, configure o Task Scheduler do Windows:

1. Backup Full: Executar semanalmente (ex: domingo às 9h).
2. Backup Diferencial: Executar diariamente (ex: todas as noites às 23h).
3. Backup de Logs: Executar a cada 15 minutos.


##  Scripts de Backup
1. Backup Completo (backupfull.ps1)
Este script realiza o backup completo do banco de dados SQL Server e envia o arquivo resultante para o bucket S3.

Uso:
```bash
.\backupfull.ps1
```

* Salva os arquivos de backup completos localmente em C:\AmbientedeBackup04\Full\.
* Faz o upload do arquivo para o S3.
* Limpa backups antigos, mantendo apenas os dois mais recentes no servidor.

## 2. Backup Diferencial (backupdiff.ps1)
Este script realiza o backup diferencial do banco de dados e envia o arquivo resultante para o bucket S3.

Uso:
```bash
.\backupdiff.ps1
```
* Salva os backups diferenciais em C:\AmbientedeBackup04\Diferencial\.
* Faz o upload para o S3.
* Mantém apenas os cinco backups diferenciais mais recentes no servidor.


## 3. Backup de Logs (backuplog.ps1)
Este script realiza o backup dos logs de transações do banco de dados SQL Server e envia o arquivo para o bucket S3.
```bash
.\backuplog.ps1
```
* Salva os backups de log localmente em C:\AmbientedeBackup04\Logs\.
* Faz o upload para o S3.
* Mantém os 10 backups de log mais recentes no servidor.


## Scripts de Restauração
1. Download dos Backups (downloadbkp.ps1)
Baixa os backups mais recentes (Full, Diferencial e Logs) do S3 para o diretório local de restauração.
```bash
.\downloadbkp.ps1
```
* Baixa o backup completo, diferencial e os logs de transações mais recentes do bucket S3 para C:\AmbientedeBackup04\restore.

2. Restauração dos Backups (restorebkp.ps1)
Restaura o banco de dados usando o backup completo, diferencial e os logs de transação baixados previamente.
Uso:
```bash
.\restorebkp.ps1
```
* Verifica se o banco de dados já existe, remove-o e, em seguida, restaura o backup completo.
* Aplica o backup diferencial mais recente e, por fim, restaura os backups de log na ordem correta


## Limpeza de Backups
Os scripts de backup já incluem a função de limpeza para evitar acúmulo excessivo de arquivos no servidor:
* Backup Completo: Mantém apenas os dois backups mais recentes.
* Backup Diferencial: Mantém apenas os cinco backups mais recentes.
* Backup de Logs: Mantém apenas os dez backups mais recentes.

## Autor
  Eric Pereira - linkedin.com/in/eric-fernandes-pereira
