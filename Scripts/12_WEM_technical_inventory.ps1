# ============================================================
# THIEF 2014 - SCRIPT 12
# INVENTARIO TECNICO DOS WEM
# ============================================================

$ErrorActionPreference = "Stop"

$Repo = "B:\DublagemThief2014"

$GraphCsv = Join-Path $Repo "Analysis\BNK\hirc_object_graph.csv"
$WemInventoryCsv = Join-Path $Repo "Analysis\WEM\wem_inventory.csv"

$WemRoot = "B:\Thief2014_Dubbing\Extracted\th4_000_common_vo"
$Vgmstream = "B:\Thief2014_Dubbing\Tools\vgmstream\vgmstream-cli.exe"

$OutputCsv = Join-Path $Repo "Analysis\WEM\wem_technical_inventory.csv"
$ErrorCsv = Join-Path $Repo "Analysis\WEM\wem_metadata_errors.csv"
$Report = Join-Path $Repo "Analysis\Reports\wem_technical_inventory_report.txt"
$RawDir = Join-Path $Repo "Analysis\WEM\vgmstream_raw"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " THIEF 2014 - WEM TECHNICAL INVENTORY 12" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $GraphCsv)) {
    throw "Grafo HIRC nao encontrado: $GraphCsv"
}

if (-not (Test-Path $WemInventoryCsv)) {
    throw "Inventario WEM nao encontrado: $WemInventoryCsv"
}

if (-not (Test-Path $Vgmstream)) {
    throw "vgmstream-cli nao encontrado: $Vgmstream"
}

if (-not (Test-Path $WemRoot)) {
    throw "Pasta WEM nao encontrada: $WemRoot"
}

New-Item -ItemType Directory -Force -Path $RawDir | Out-Null

Write-Host "[1/6] Lendo grafo HIRC..."

$Graph = Import-Csv $GraphCsv

Write-Host "      Registros no grafo: $($Graph.Count)"

Write-Host ""
Write-Host "[2/6] Lendo inventario WEM..."

$Inventory = Import-Csv $WemInventoryCsv

Write-Host "      WEM no inventario: $($Inventory.Count)"

Write-Host ""
Write-Host "[3/6] Consultando vgmstream..." -ForegroundColor Yellow
Write-Host "      Aguarde. Serao analisados $($Graph.Count) arquivos."
Write-Host ""

$Results = New-Object System.Collections.Generic.List[object]
$Errors = New-Object System.Collections.Generic.List[object]

$Total = $Graph.Count
$Index = 0

foreach ($Row in $Graph) {

    $Index++

    $Percent = [math]::Round(($Index / $Total) * 100, 1)

    Write-Progress `
        -Activity "Analisando WEM" `
        -Status "$Index / $Total - $($Row.WEM)" `
        -PercentComplete $Percent

    $WemName = [string]$Row.WEM
    $SourceID = [string]$Row.SourceID

    $WemPath = Join-Path $WemRoot $WemName

    if (-not (Test-Path $WemPath)) {

        $Found = Get-ChildItem `
            -Path $WemRoot `
            -Filter $WemName `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($null -ne $Found) {
            $WemPath = $Found.FullName
        }
    }

    if (-not (Test-Path $WemPath)) {

        $Errors.Add([pscustomobject]@{
            WEM       = $WemName
            SourceID  = $SourceID
            ErrorType = "FILE_NOT_FOUND"
            Details   = $WemPath
        })

        continue
    }

    $FileInfo = Get-Item $WemPath

    try {

        $Output = & $Vgmstream -m $WemPath 2>&1 | Out-String

        $ExitCode = $LASTEXITCODE

        $SafeName = [System.IO.Path]::GetFileNameWithoutExtension($WemName)
        $RawFile = Join-Path $RawDir "$SafeName.txt"

        $Output | Set-Content -Path $RawFile -Encoding UTF8

        if ($ExitCode -ne 0) {

            $Errors.Add([pscustomobject]@{
                WEM       = $WemName
                SourceID  = $SourceID
                ErrorType = "VGMSTREAM_ERROR"
                Details   = $Output.Trim()
            })

            continue
        }

        $Codec = ""
        $SampleRate = ""
        $Channels = ""
        $Streams = ""
        $Looping = ""
        $DurationSec = $null

        if ($Output -match '(?im)^\s*stream codec:\s*(.+)$') {
            $Codec = $Matches[1].Trim()
        }

        if ($Output -match '(?im)^\s*sample rate:\s*(.+)$') {
            $SampleRate = $Matches[1].Trim()
        }

        if ($Output -match '(?im)^\s*channels:\s*(.+)$') {
            $Channels = $Matches[1].Trim()
        }

        if ($Output -match '(?im)^\s*stream count:\s*(.+)$') {
            $Streams = $Matches[1].Trim()
        }

        if ($Output -match '(?im)^\s*looping:\s*(.+)$') {
            $Looping = $Matches[1].Trim()
        }

        if ($Output -match '(?im)^\s*play duration:\s*(.+)$') {

            $DurationText = $Matches[1].Trim()

            if ($DurationText -match '^(\d+):(\d{2})\.(\d+)$') {

                $Minutes = [double]$Matches[1]
                $Seconds = [double]$Matches[2]
                $Fraction = [double]("0." + $Matches[3])

                $DurationSec =
                    ($Minutes * 60) +
                    $Seconds +
                    $Fraction
            }
            elseif ($DurationText -match '^(\d+):(\d{2}):(\d{2})\.(\d+)$') {

                $Hours = [double]$Matches[1]
                $Minutes = [double]$Matches[2]
                $Seconds = [double]$Matches[3]
                $Fraction = [double]("0." + $Matches[4])

                $DurationSec =
                    ($Hours * 3600) +
                    ($Minutes * 60) +
                    $Seconds +
                    $Fraction
            }
        }

        $Results.Add([pscustomobject]@{
            EventID        = $Row.EventID
            ActionID       = $Row.ActionID
            SoundID        = $Row.SoundID
            SourceID       = $SourceID
            WEM            = $WemName
            StreamType     = $Row.StreamType
            SizeBytes      = $FileInfo.Length
            SizeKB         = [math]::Round($FileInfo.Length / 1KB, 2)
            Codec          = $Codec
            SampleRate     = $SampleRate
            Channels       = $Channels
            Streams        = $Streams
            DurationSec    = $DurationSec
            Looping        = $Looping
            VgmstreamExit  = $ExitCode
        })
    }
    catch {

        $Errors.Add([pscustomobject]@{
            WEM       = $WemName
            SourceID  = $SourceID
            ErrorType = "POWERSHELL_EXCEPTION"
            Details   = $_.Exception.Message
        })
    }
}

Write-Progress -Activity "Analisando WEM" -Completed

Write-Host ""
Write-Host "[4/6] Gravando inventario tecnico..."

$Results |
    Export-Csv `
        -Path $OutputCsv `
        -NoTypeInformation `
        -Encoding UTF8

$Errors |
    Export-Csv `
        -Path $ErrorCsv `
        -NoTypeInformation `
        -Encoding UTF8

$CodecGroups = $Results |
    Group-Object Codec |
    Sort-Object Count -Descending

$SampleRateGroups = $Results |
    Group-Object SampleRate |
    Sort-Object Count -Descending

$ChannelGroups = $Results |
    Group-Object Channels |
    Sort-Object Count -Descending

$StreamTypeGroups = $Results |
    Group-Object StreamType |
    Sort-Object Count -Descending

$ValidDurations = @(
    $Results |
    Where-Object {
        $null -ne $_.DurationSec
    } |
    ForEach-Object {
        [double]$_.DurationSec
    }
)

if ($ValidDurations.Count -gt 0) {

    $MinDuration = ($ValidDurations | Measure-Object -Minimum).Minimum
    $MaxDuration = ($ValidDurations | Measure-Object -Maximum).Maximum
    $AvgDuration = ($ValidDurations | Measure-Object -Average).Average
    $TotalDuration = ($ValidDurations | Measure-Object -Sum).Sum
}
else {

    $MinDuration = 0
    $MaxDuration = 0
    $AvgDuration = 0
    $TotalDuration = 0
}

Write-Host ""
Write-Host "[5/6] Gerando relatorio..."

$ReportLines = New-Object System.Collections.Generic.List[string]

$ReportLines.Add("============================================================")
$ReportLines.Add(" THIEF 2014 - WEM TECHNICAL INVENTORY REPORT")
$ReportLines.Add("============================================================")
$ReportLines.Add("")
$ReportLines.Add("Grafo HIRC: $GraphCsv")
$ReportLines.Add("Inventario WEM: $WemInventoryCsv")
$ReportLines.Add("WEM root: $WemRoot")
$ReportLines.Add("")
$ReportLines.Add("============================================================")
$ReportLines.Add(" RESUMO")
$ReportLines.Add("============================================================")
$ReportLines.Add("")
$ReportLines.Add("Registros no grafo:   $Total")
$ReportLines.Add("WEM analisados:       $($Results.Count)")
$ReportLines.Add("Erros:                $($Errors.Count)")
$ReportLines.Add("Duracoes encontradas: $($ValidDurations.Count)")
$ReportLines.Add("")
$ReportLines.Add(("Duracao minima: {0:N3} s" -f $MinDuration))
$ReportLines.Add(("Duracao maxima: {0:N3} s" -f $MaxDuration))
$ReportLines.Add(("Duracao media:  {0:N3} s" -f $AvgDuration))
$ReportLines.Add(("Duracao total:  {0:N3} s" -f $TotalDuration))
$ReportLines.Add("")

$ReportLines.Add("============================================================")
$ReportLines.Add(" CODECS")
$ReportLines.Add("============================================================")
$ReportLines.Add("")

foreach ($Group in $CodecGroups) {
    $ReportLines.Add(
        ("{0} = {1}" -f $Group.Name, $Group.Count)
    )
}

$ReportLines.Add("")
$ReportLines.Add("============================================================")
$ReportLines.Add(" SAMPLE RATE")
$ReportLines.Add("============================================================")
$ReportLines.Add("")

foreach ($Group in $SampleRateGroups) {
    $ReportLines.Add(
        ("{0} = {1}" -f $Group.Name, $Group.Count)
    )
}

$ReportLines.Add("")
$ReportLines.Add("============================================================")
$ReportLines.Add(" CHANNELS")
$ReportLines.Add("============================================================")
$ReportLines.Add("")

foreach ($Group in $ChannelGroups) {
    $ReportLines.Add(
        ("{0} = {1}" -f $Group.Name, $Group.Count)
    )
}

$ReportLines.Add("")
$ReportLines.Add("============================================================")
$ReportLines.Add(" STREAM TYPE")
$ReportLines.Add("============================================================")
$ReportLines.Add("")

foreach ($Group in $StreamTypeGroups) {
    $ReportLines.Add(
        ("{0} = {1}" -f $Group.Name, $Group.Count)
    )
}

$ReportLines.Add("")
$ReportLines.Add("============================================================")
$ReportLines.Add(" MAIORES ARQUIVOS")
$ReportLines.Add("============================================================")
$ReportLines.Add("")

$Results |
    Sort-Object {[int64]$_.SizeBytes} -Descending |
    Select-Object -First 20 |
    ForEach-Object {

        $ReportLines.Add(
            ("{0} | {1:N2} KB | {2:N3}s | {3} | {4}" -f `
                $_.WEM,
                [double]$_.SizeKB,
                [double]$_.DurationSec,
                $_.Codec,
                $_.Channels)
        )
    }

$ReportLines.Add("")
$ReportLines.Add("============================================================")
$ReportLines.Add(" MAIORES DURACOES")
$ReportLines.Add("============================================================")
$ReportLines.Add("")

$Results |
    Where-Object {
        $null -ne $_.DurationSec
    } |
    Sort-Object {[double]$_.DurationSec} -Descending |
    Select-Object -First 20 |
    ForEach-Object {

        $ReportLines.Add(
            ("{0} | {1:N3}s | {2:N2} KB | {3} | Event={4}" -f `
                $_.WEM,
                [double]$_.DurationSec,
                [double]$_.SizeKB,
                $_.Codec,
                $_.EventID)
        )
    }

$ReportLines.Add("")
$ReportLines.Add("============================================================")
$ReportLines.Add(" ERROS")
$ReportLines.Add("============================================================")
$ReportLines.Add("")

if ($Errors.Count -eq 0) {

    $ReportLines.Add("Nenhum erro encontrado.")
}
else {

    foreach ($ErrorItem in $Errors) {

        $ReportLines.Add(
            ("{0} | {1} | {2}" -f `
                $ErrorItem.WEM,
                $ErrorItem.ErrorType,
                $ErrorItem.Details)
        )
    }
}

$ReportLines.Add("")
$ReportLines.Add("============================================================")
$ReportLines.Add(" FIM")
$ReportLines.Add("============================================================")

$ReportLines |
    Set-Content -Path $Report -Encoding UTF8

Write-Host ""
Write-Host "[6/6] Git..." -ForegroundColor Yellow

Set-Location $Repo

git add `
    "Scripts/12_WEM_technical_inventory.ps1" `
    "Analysis/WEM/wem_technical_inventory.csv" `
    "Analysis/WEM/wem_metadata_errors.csv" `
    "Analysis/WEM/vgmstream_raw" `
    "Analysis/Reports/wem_technical_inventory_report.txt"

git commit -m "Add WEM technical inventory"

git push

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " WEM TECHNICAL INVENTORY 12 CONCLUIDO" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Grafo:       $Total"
Write-Host "Analisados:  $($Results.Count)"
Write-Host "Erros:       $($Errors.Count)"
Write-Host "Duracoes:    $($ValidDurations.Count)"
Write-Host ""
Write-Host "Arquivo:"
Write-Host $Report
Write-Host ""
Write-Host "Git sincronizado." -ForegroundColor Green
Write-Host ""
