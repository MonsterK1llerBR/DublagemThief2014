# ============================================================
# THIEF 2014 - SCRIPT 18
# CREATE DUBBING WORKSET
# ============================================================
#
# Objetivo:
#   Criar um conjunto de trabalho para a próxima etapa da
#   dublagem usando o CSV exportado pelo Script 17.
#
# CSV DE ORIGEM:
#   C:\Users\natan\OneDrive\Área de Trabalho\Thief MODS\!\
#   thief2014_voice_triage_2026-09-26T02-54-05-772Z.csv
#
# Categorias incluídas:
#   FALA
#   GRITO
#   VOCALIZAÇÃO
#
# Categorias excluídas:
#   EFEITO
#   DESCARTAR
#   PENDENTE
#
# Este script NÃO modifica:
#   - WEM originais
#   - BNK
#   - PCK
#   - catálogo de triagem
#   - arquivos de áudio originais
#
# ============================================================

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# CAMINHOS PRINCIPAIS
# ------------------------------------------------------------

$Repo = "B:\DublagemThief2014"
$Lab  = "B:\Thief2014_Dubbing"

$AnalysisDir = Join-Path $Repo "Analysis\WEM"
$ReportsDir  = Join-Path $Repo "Analysis\Reports"
$ScriptsDir  = Join-Path $Repo "Scripts"

$WorkDir = Join-Path $Lab "Work\VoiceAudition"
$DubbingWorkDir = Join-Path $Lab "Work\DubbingWorkset"

# ------------------------------------------------------------
# CSV DE ORIGEM
# ------------------------------------------------------------

$ClassificationCsv = "C:\Users\natan\OneDrive\Área de Trabalho\Thief MODS\!\thief2014_voice_triage_2026-09-26T02-54-05-772Z.csv"

# ------------------------------------------------------------
# ARQUIVOS DE SAÍDA
# ------------------------------------------------------------

$OutputCsv = Join-Path $AnalysisDir "dubbing_workset.csv"
$Report = Join-Path $ReportsDir "dubbing_workset_report.txt"

# ------------------------------------------------------------
# CRIAR DIRETÓRIOS
# ------------------------------------------------------------

New-Item `
    -ItemType Directory `
    -Force `
    -Path $AnalysisDir |
    Out-Null

New-Item `
    -ItemType Directory `
    -Force `
    -Path $ReportsDir |
    Out-Null

New-Item `
    -ItemType Directory `
    -Force `
    -Path $ScriptsDir |
    Out-Null

New-Item `
    -ItemType Directory `
    -Force `
    -Path $DubbingWorkDir |
    Out-Null

# ------------------------------------------------------------
# CABEÇALHO
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================="
Write-Host " THIEF 2014 - DUBBING WORKSET - SCRIPT 18"
Write-Host "============================================="
Write-Host ""

# ------------------------------------------------------------
# 1. VALIDAR CSV
# ------------------------------------------------------------

Write-Host "Verificando CSV..."

if (-not (Test-Path -LiteralPath $ClassificationCsv)) {

    Write-Host ""
    Write-Host "ERRO: CSV nao encontrado." `
        -ForegroundColor Red

    Write-Host ""
    Write-Host "Caminho procurado:"
    Write-Host $ClassificationCsv
    Write-Host ""

    exit 1
}

Write-Host "CSV encontrado." `
    -ForegroundColor Green

Write-Host $ClassificationCsv
Write-Host ""

# ------------------------------------------------------------
# 2. LER CSV
# ------------------------------------------------------------

Write-Host "Lendo CSV..."

$Rows = Import-Csv `
    -LiteralPath $ClassificationCsv

if (-not $Rows -or $Rows.Count -eq 0) {

    Write-Host ""
    Write-Host "ERRO: o CSV esta vazio." `
        -ForegroundColor Red

    exit 1
}

Write-Host "Registros encontrados: $($Rows.Count)"
Write-Host ""

# ------------------------------------------------------------
# 3. MOSTRAR COLUNAS
# ------------------------------------------------------------

$Headers = $Rows[0].PSObject.Properties.Name

Write-Host "Colunas detectadas:"

foreach ($Header in $Headers) {
    Write-Host "  $Header"
}

Write-Host ""

# ------------------------------------------------------------
# 4. FUNÇÃO PARA LER COLUNAS
# ------------------------------------------------------------

function Get-ColumnValue {

    param(
        [Parameter(Mandatory = $true)]
        $Row,

        [Parameter(Mandatory = $true)]
        [string[]]$Names
    )

    foreach ($Name in $Names) {

        $Property = $Row.PSObject.Properties |
            Where-Object {
                $_.Name -ieq $Name
            } |
            Select-Object -First 1

        if ($null -ne $Property) {
            return [string]$Property.Value
        }
    }

    return ""
}

# ------------------------------------------------------------
# 5. VALIDAR COLUNA DE CLASSIFICAÇÃO
# ------------------------------------------------------------

$ClassificationColumn = $null

foreach ($Name in @(
    "Classification",
    "classification",
    "Categoria",
    "Category",
    "category"
)) {

    $Found = $Headers |
        Where-Object {
            $_ -ieq $Name
        } |
        Select-Object -First 1

    if ($Found) {
        $ClassificationColumn = $Found
        break
    }
}

if (-not $ClassificationColumn) {

    Write-Host ""
    Write-Host "ERRO: nenhuma coluna de classificacao foi encontrada." `
        -ForegroundColor Red

    Write-Host ""
    Write-Host "Colunas disponíveis:"

    foreach ($Header in $Headers) {
        Write-Host "  $Header"
    }

    Write-Host ""

    exit 1
}

Write-Host "Coluna de classificacao:"
Write-Host "  $ClassificationColumn"
Write-Host ""

# ------------------------------------------------------------
# 6. CRIAR WORKSET
# ------------------------------------------------------------

$Workset = New-Object System.Collections.Generic.List[object]

$IgnoredCount = 0

foreach ($Row in $Rows) {

    # --------------------------------------------------------
    # Dados principais
    # --------------------------------------------------------

    $Index = Get-ColumnValue `
        -Row $Row `
        -Names @(
            "Index",
            "index"
        )

    $Batch = Get-ColumnValue `
        -Row $Row `
        -Names @(
            "Batch",
            "batch"
        )

    $WEM = Get-ColumnValue `
        -Row $Row `
        -Names @(
            "WEM",
            "wem"
        )

    $Audio = Get-ColumnValue `
        -Row $Row `
        -Names @(
            "Audio",
            "audio"
        )

    # --------------------------------------------------------
    # Classificação
    # --------------------------------------------------------

    $Classification = Get-ColumnValue `
        -Row $Row `
        -Names @(
            "Classification",
            "classification",
            "Categoria",
            "Category",
            "category"
        )

    # --------------------------------------------------------
    # Dados opcionais
    # --------------------------------------------------------

    $Character = Get-ColumnValue `
        -Row $Row `
        -Names @(
            "Character",
            "character",
            "Personagem",
            "personagem"
        )

    $Transcript = Get-ColumnValue `
        -Row $Row `
        -Names @(
            "Transcript",
            "transcript",
            "OriginalTranscript",
            "originalTranscript",
            "Transcricao",
            "Transcrição"
        )

    $Notes = Get-ColumnValue `
        -Row $Row `
        -Names @(
            "Notes",
            "notes",
            "Observacoes",
            "Observações"
        )

    # --------------------------------------------------------
    # Metadados Wwise
    # --------------------------------------------------------

    $EventID = Get-ColumnValue `
        -Row $Row `
        -Names @(
            "EventID",
            "eventID"
        )

    $ActionID = Get-ColumnValue `
        -Row $Row `
        -Names @(
            "ActionID",
            "actionID"
        )

    $SoundID = Get-ColumnValue `
        -Row $Row `
        -Names @(
            "SoundID",
            "soundID"
        )

    $SourceID = Get-ColumnValue `
        -Row $Row `
        -Names @(
            "SourceID",
            "sourceID"
        )

    $Duration = Get-ColumnValue `
        -Row $Row `
        -Names @(
            "DurationSec",
            "durationSec",
            "Duration",
            "duration"
        )

    # --------------------------------------------------------
    # Normalizar classificação
    # --------------------------------------------------------

    $Category = $Classification.Trim().ToUpperInvariant()

    # --------------------------------------------------------
    # Aceitar somente material vocal
    # --------------------------------------------------------

    if (
        $Category -ne "FALA" -and
        $Category -ne "GRITO" -and
        $Category -ne "VOCALIZAÇÃO" -and
        $Category -ne "VOCALIZACAO"
    ) {

        $IgnoredCount++

        continue
    }

    # Normalizar sem acento para acentuado
    if ($Category -eq "VOCALIZACAO") {
        $Category = "VOCALIZAÇÃO"
    }

    # --------------------------------------------------------
    # Adicionar ao workset
    # --------------------------------------------------------

    $Workset.Add(
        [PSCustomObject]@{

            Index = $Index

            Batch = $Batch

            WEM = $WEM

            Audio = $Audio

            EventID = $EventID

            ActionID = $ActionID

            SoundID = $SoundID

            SourceID = $SourceID

            DurationSec = $Duration

            Category = $Category

            Character = $Character

            OriginalTranscript = $Transcript

            PTBR = ""

            Notes = $Notes

            Status = "PENDING"
        }
    )
}

# ------------------------------------------------------------
# 7. ORDENAR PELO ÍNDICE ORIGINAL
# ------------------------------------------------------------

$Workset = $Workset |
    Sort-Object {

        try {
            [int]$_.Index
        }
        catch {
            999999999
        }
    }

# ------------------------------------------------------------
# 8. EXPORTAR WORKSET
# ------------------------------------------------------------

$Workset |
    Export-Csv `
        -LiteralPath $OutputCsv `
        -NoTypeInformation `
        -Encoding UTF8

# ------------------------------------------------------------
# 9. CONTADORES
# ------------------------------------------------------------

$TotalWorkset = @($Workset).Count

$FalaCount = @(
    $Workset |
    Where-Object {
        $_.Category -eq "FALA"
    }
).Count

$GritoCount = @(
    $Workset |
    Where-Object {
        $_.Category -eq "GRITO"
    }
).Count

$VocalizacaoCount = @(
    $Workset |
    Where-Object {
        $_.Category -eq "VOCALIZAÇÃO"
    }
).Count

$WithTranscript = @(
    $Workset |
    Where-Object {
        -not [string]::IsNullOrWhiteSpace(
            $_.OriginalTranscript
        )
    }
).Count

$WithCharacter = @(
    $Workset |
    Where-Object {
        -not [string]::IsNullOrWhiteSpace(
            $_.Character
        )
    }
).Count

# ------------------------------------------------------------
# 10. VERIFICAR ÁUDIOS
# ------------------------------------------------------------

$AudioFound = 0
$AudioMissing = 0

foreach ($Item in $Workset) {

    $AudioPath = ""

    if (
        -not [string]::IsNullOrWhiteSpace(
            $Item.Audio
        )
    ) {

        if (
            [System.IO.Path]::IsPathRooted(
                $Item.Audio
            )
        ) {

            $AudioPath = $Item.Audio

        }
        else {

            $AudioPath = Join-Path `
                $WorkDir `
                $Item.Audio
        }
    }

    if (
        $AudioPath -and
        (Test-Path -LiteralPath $AudioPath)
    ) {

        $AudioFound++

    }
    else {

        $AudioMissing++
    }
}

# ------------------------------------------------------------
# 11. RELATÓRIO
# ------------------------------------------------------------

$ReportLines = @()

$ReportLines += "THIEF 2014 - DUBBING WORKSET"
$ReportLines += "SCRIPT 18"
$ReportLines += ""
$ReportLines += "Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$ReportLines += ""
$ReportLines += "CSV de origem:"
$ReportLines += $ClassificationCsv
$ReportLines += ""
$ReportLines += "RESULTADO"
$ReportLines += "----------------------------------------"
$ReportLines += "Registros no CSV:      $($Rows.Count)"
$ReportLines += "Registros no workset:  $TotalWorkset"
$ReportLines += "Registros ignorados:   $IgnoredCount"
$ReportLines += ""
$ReportLines += "FALA:                  $FalaCount"
$ReportLines += "GRITO:                 $GritoCount"
$ReportLines += "VOCALIZAÇÃO:           $VocalizacaoCount"
$ReportLines += ""
$ReportLines += "Com transcrição:       $WithTranscript"
$ReportLines += "Com personagem:        $WithCharacter"
$ReportLines += ""
$ReportLines += "Áudios encontrados:     $AudioFound"
$ReportLines += "Áudios ausentes:        $AudioMissing"
$ReportLines += ""
$ReportLines += "CSV gerado:"
$ReportLines += $OutputCsv
$ReportLines += ""
$ReportLines += "REGRAS"
$ReportLines += "----------------------------------------"
$ReportLines += "Incluídos:"
$ReportLines += "  FALA"
$ReportLines += "  GRITO"
$ReportLines += "  VOCALIZAÇÃO"
$ReportLines += ""
$ReportLines += "Excluídos:"
$ReportLines += "  EFEITO"
$ReportLines += "  DESCARTAR"
$ReportLines += "  PENDENTE"
$ReportLines += ""
$ReportLines += "Character, OriginalTranscript e PTBR"
$ReportLines += "podem ser preenchidos posteriormente."

$ReportLines |
    Set-Content `
        -LiteralPath $Report `
        -Encoding UTF8

# ------------------------------------------------------------
# 12. CONSOLE
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================="
Write-Host " WORKSET CRIADO"
Write-Host "============================================="
Write-Host ""

Write-Host "Registros no CSV:      $($Rows.Count)"
Write-Host "Registros no workset:  $TotalWorkset"
Write-Host "Registros ignorados:   $IgnoredCount"
Write-Host ""

Write-Host "FALA:                  $FalaCount"
Write-Host "GRITO:                 $GritoCount"
Write-Host "VOCALIZACAO:           $VocalizacaoCount"
Write-Host ""

Write-Host "Com transcricao:       $WithTranscript"
Write-Host "Com personagem:        $WithCharacter"
Write-Host ""

Write-Host "Audios encontrados:    $AudioFound"
Write-Host "Audios ausentes:       $AudioMissing"
Write-Host ""

Write-Host "CSV:"
Write-Host $OutputCsv
Write-Host ""

Write-Host "Relatorio:"
Write-Host $Report
Write-Host ""

# ------------------------------------------------------------
# 13. GIT
# ------------------------------------------------------------

Set-Location $Repo

git add `
    "Scripts/18_Create_Dubbing_Workset.ps1" `
    "Analysis/WEM/dubbing_workset.csv" `
    "Analysis/Reports/dubbing_workset_report.txt"

Write-Host "Status do Git:"
git status --short

Write-Host ""

git commit -m "Add dubbing workset builder"

git push origin main

Write-Host ""
Write-Host "Ultimo commit:"
git log -1 --oneline

Write-Host ""
Write-Host "SCRIPT 18 CONCLUIDO." `
    -ForegroundColor Green

Write-Host ""