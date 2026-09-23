# ============================================================
# THIEF 2014 - SCRIPT 13
# ANALISE DE DURACAO E AGRUPAMENTO DOS WEM
# ============================================================

$ErrorActionPreference = "Stop"

$Repo = "B:\DublagemThief2014"

$InputCsv = Join-Path $Repo "Analysis\WEM\wem_technical_inventory.csv"

$OutputCsv = Join-Path $Repo "Analysis\WEM\wem_duration_analysis.csv"
$CandidateCsv = Join-Path $Repo "Analysis\WEM\wem_voice_candidates.csv"
$Report = Join-Path $Repo "Analysis\Reports\wem_duration_analysis_report.txt"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " THIEF 2014 - WEM DURATION ANALYSIS 13" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $InputCsv)) {
    throw "CSV nao encontrado: $InputCsv"
}

Write-Host "[1/5] Lendo inventario tecnico..."

$Rows = Import-Csv $InputCsv

Write-Host "      Registros: $($Rows.Count)"

# ------------------------------------------------------------
# CONVERSAO NUMERICA
# ------------------------------------------------------------

$Analyzed = New-Object System.Collections.Generic.List[object]

foreach ($Row in $Rows) {

    $Duration = 0.0
    $SizeKB = 0.0
    $Bitrate = 0.0

    [double]::TryParse(
        ([string]$Row.DurationSec).Replace(",", "."),
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$Duration
    ) | Out-Null

    [double]::TryParse(
        ([string]$Row.SizeKB).Replace(",", "."),
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$SizeKB
    ) | Out-Null

    if ([string]$Row.Bitrate -match '([0-9.]+)\s*kbps') {
        [double]::TryParse(
            $Matches[1],
            [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$Bitrate
        ) | Out-Null
    }

    if ($Duration -lt 1) {
        $Bucket = "00-01s"
    }
    elseif ($Duration -lt 2) {
        $Bucket = "01-02s"
    }
    elseif ($Duration -lt 3) {
        $Bucket = "02-03s"
    }
    elseif ($Duration -lt 5) {
        $Bucket = "03-05s"
    }
    elseif ($Duration -lt 10) {
        $Bucket = "05-10s"
    }
    elseif ($Duration -lt 20) {
        $Bucket = "10-20s"
    }
    elseif ($Duration -lt 30) {
        $Bucket = "20-30s"
    }
    elseif ($Duration -lt 60) {
        $Bucket = "30-60s"
    }
    else {
        $Bucket = "60s+"
    }

    $Analyzed.Add([pscustomobject]@{
        EventID      = $Row.EventID
        ActionID     = $Row.ActionID
        SoundID      = $Row.SoundID
        SourceID     = $Row.SourceID
        WEM          = $Row.WEM
        StreamType   = $Row.StreamType
        SizeKB       = $SizeKB
        DurationSec  = $Duration
        BitrateKbps  = $Bitrate
        Encoding     = $Row.Encoding
        SampleRate   = $Row.SampleRate
        Channels     = $Row.Channels
        Bucket       = $Bucket
    })
}

# ------------------------------------------------------------
# EXPORTA ANALISE COMPLETA
# ------------------------------------------------------------

Write-Host ""
Write-Host "[2/5] Gravando analise..."

$Analyzed |
    Export-Csv `
        -Path $OutputCsv `
        -NoTypeInformation `
        -Encoding UTF8

# ------------------------------------------------------------
# ESTATISTICAS
# ------------------------------------------------------------

$Total = $Analyzed.Count

$DurationValues = @(
    $Analyzed |
    ForEach-Object {
        [double]$_.DurationSec
    }
)

$Min = ($DurationValues | Measure-Object -Minimum).Minimum
$Max = ($DurationValues | Measure-Object -Maximum).Maximum
$Average = ($DurationValues | Measure-Object -Average).Average
$Sum = ($DurationValues | Measure-Object -Sum).Sum

$MedianValues = $DurationValues | Sort-Object

if ($MedianValues.Count % 2 -eq 0) {

    $Middle = $MedianValues.Count / 2

    $Median = (
        $MedianValues[$Middle - 1] +
        $MedianValues[$Middle]
    ) / 2
}
else {

    $Median = $MedianValues[
        [math]::Floor($MedianValues.Count / 2)
    ]
}

# ------------------------------------------------------------
# CANDIDATOS DE VOZ
#
# NAO significa que sao definitivamente falas.
# Apenas cria um conjunto pratico para a primeira audição.
#
# Critérios:
# - mono
# - Custom Vorbis
# - 32 kHz
# - duracao entre 0.5 e 30 segundos
# ------------------------------------------------------------

Write-Host ""
Write-Host "[3/5] Criando candidatos de voz..."

$Candidates = $Analyzed |
    Where-Object {
        $_.Encoding -eq "Custom Vorbis" -and
        $_.Channels -eq "1" -and
        $_.SampleRate -eq "32000 Hz" -and
        $_.DurationSec -ge 0.5 -and
        $_.DurationSec -le 30
    } |
    Sort-Object DurationSec

$Candidates |
    Export-Csv `
        -Path $CandidateCsv `
        -NoTypeInformation `
        -Encoding UTF8

# ------------------------------------------------------------
# RELATORIO
# ------------------------------------------------------------

Write-Host ""
Write-Host "[4/5] Gerando relatorio..."

$Lines = New-Object System.Collections.Generic.List[string]

$Lines.Add("============================================================")
$Lines.Add(" THIEF 2014 - WEM DURATION ANALYSIS REPORT")
$Lines.Add("============================================================")
$Lines.Add("")
$Lines.Add("Fonte: $InputCsv")
$Lines.Add("")
$Lines.Add("============================================================")
$Lines.Add(" RESUMO")
$Lines.Add("============================================================")
$Lines.Add("")
$Lines.Add("Total WEM:       $Total")
$Lines.Add(("Minimo:          {0:N3} s" -f $Min))
$Lines.Add(("Maximo:          {0:N3} s" -f $Max))
$Lines.Add(("Media:           {0:N3} s" -f $Average))
$Lines.Add(("Mediana:         {0:N3} s" -f $Median))
$Lines.Add(("Total de audio:  {0:N3} s" -f $Sum))
$Lines.Add(("Total de audio:  {0:N2} minutos" -f ($Sum / 60)))
$Lines.Add("")

# ------------------------------------------------------------
# BUCKETS
# ------------------------------------------------------------

$Lines.Add("============================================================")
$Lines.Add(" DISTRIBUICAO POR DURACAO")
$Lines.Add("============================================================")
$Lines.Add("")

$BucketOrder = @(
    "00-01s",
    "01-02s",
    "02-03s",
    "03-05s",
    "05-10s",
    "10-20s",
    "20-30s",
    "30-60s",
    "60s+"
)

foreach ($Bucket in $BucketOrder) {

    $Count = @(
        $Analyzed |
        Where-Object { $_.Bucket -eq $Bucket }
    ).Count

    $Percent = 0

    if ($Total -gt 0) {
        $Percent = ($Count / $Total) * 100
    }

    $Lines.Add(
        ("{0,-10} {1,5} ({2,6:N2}%)" -f `
            $Bucket,
            $Count,
            $Percent)
    )
}

# ------------------------------------------------------------
# STREAM TYPE
# ------------------------------------------------------------

$Lines.Add("")
$Lines.Add("============================================================")
$Lines.Add(" STREAM TYPE")
$Lines.Add("============================================================")
$Lines.Add("")

$Analyzed |
    Group-Object StreamType |
    Sort-Object Name |
    ForEach-Object {

        $Lines.Add(
            ("StreamType {0}: {1}" -f `
                $_.Name,
                $_.Count)
        )
    }

# ------------------------------------------------------------
# BITRATE
# ------------------------------------------------------------

$Lines.Add("")
$Lines.Add("============================================================")
$Lines.Add(" BITRATE")
$Lines.Add("============================================================")
$Lines.Add("")

$Analyzed |
    Group-Object BitrateKbps |
    Sort-Object {
        [double]$_.Name
    } |
    ForEach-Object {

        $Lines.Add(
            ("{0} kbps = {1}" -f `
                $_.Name,
                $_.Count)
        )
    }

# ------------------------------------------------------------
# MAIORES DURACOES
# ------------------------------------------------------------

$Lines.Add("")
$Lines.Add("============================================================")
$Lines.Add(" TOP 50 MAIORES DURACOES")
$Lines.Add("============================================================")
$Lines.Add("")

$Analyzed |
    Sort-Object DurationSec -Descending |
    Select-Object -First 50 |
    ForEach-Object {

        $Lines.Add(
            ("{0} | {1:N3}s | {2:N2} KB | Event={3} | Stream={4}" -f `
                $_.WEM,
                $_.DurationSec,
                $_.SizeKB,
                $_.EventID,
                $_.StreamType)
        )
    }

# ------------------------------------------------------------
# MENORES DURACOES
# ------------------------------------------------------------

$Lines.Add("")
$Lines.Add("============================================================")
$Lines.Add(" 50 MENORES DURACOES")
$Lines.Add("============================================================")
$Lines.Add("")

$Analyzed |
    Sort-Object DurationSec |
    Select-Object -First 50 |
    ForEach-Object {

        $Lines.Add(
            ("{0} | {1:N3}s | {2:N2} KB | Event={3} | Stream={4}" -f `
                $_.WEM,
                $_.DurationSec,
                $_.SizeKB,
                $_.EventID,
                $_.StreamType)
        )
    }

# ------------------------------------------------------------
# CANDIDATOS
# ------------------------------------------------------------

$Lines.Add("")
$Lines.Add("============================================================")
$Lines.Add(" CANDIDATOS DE VOZ")
$Lines.Add("============================================================")
$Lines.Add("")
$Lines.Add("Criterios:")
$Lines.Add("Custom Vorbis + mono + 32 kHz + 0.5s ate 30s")
$Lines.Add("")
$Lines.Add("Total candidato: $($Candidates.Count)")
$Lines.Add("")

$Candidates |
    Select-Object -First 100 |
    ForEach-Object {

        $Lines.Add(
            ("{0} | {1:N3}s | {2:N2} KB | Event={3} | Stream={4}" -f `
                $_.WEM,
                $_.DurationSec,
                $_.SizeKB,
                $_.EventID,
                $_.StreamType)
        )
    }

$Lines.Add("")
$Lines.Add("============================================================")
$Lines.Add(" FIM")
$Lines.Add("============================================================")

$Lines |
    Set-Content `
        -Path $Report `
        -Encoding UTF8

# ------------------------------------------------------------
# GIT
# ------------------------------------------------------------

Write-Host ""
Write-Host "[5/5] Git..."

Set-Location $Repo

git add `
    "Scripts/13_WEM_duration_analysis.ps1" `
    "Analysis/WEM/wem_duration_analysis.csv" `
    "Analysis/WEM/wem_voice_candidates.csv" `
    "Analysis/Reports/wem_duration_analysis_report.txt"

git commit -m "Add WEM duration analysis"

git push

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " WEM DURATION ANALYSIS 13 CONCLUIDO" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Total WEM:       $Total"
Write-Host ("Minimo:          {0:N3}s" -f $Min)
Write-Host ("Maximo:          {0:N3}s" -f $Max)
Write-Host ("Media:           {0:N3}s" -f $Average)
Write-Host ("Mediana:         {0:N3}s" -f $Median)
Write-Host ("Total audio:     {0:N2} minutos" -f ($Sum / 60))
Write-Host "Candidatos voz:  $($Candidates.Count)"
Write-Host ""
Write-Host "Git sincronizado." -ForegroundColor Green
Write-Host ""
