$ErrorActionPreference = "Stop"

# ============================================================
# SCRIPT 14
# CREATE VOICE AUDITION LIBRARY
# Thief 2014 PT-BR Dubbing
# ============================================================

$Repo = "B:\DublagemThief2014"
$Lab  = "B:\Thief2014_Dubbing"

$CandidateCsv = Join-Path $Repo "Analysis\WEM\wem_voice_candidates.csv"
$Vgmstream = Join-Path $Lab "Tools\vgmstream\vgmstream-cli.exe"

$WorkRoot = Join-Path $Lab "Work\VoiceAudition"

$ManifestOut = Join-Path $Repo "Analysis\WEM\voice_audition_manifest.csv"
$ReportOut   = Join-Path $Repo "Analysis\Reports\voice_audition_library_report.txt"

$BatchSize = 100

Write-Host ""
Write-Host "============================================================"
Write-Host " VOICE AUDITION LIBRARY - SCRIPT 14"
Write-Host "============================================================"
Write-Host ""

# ------------------------------------------------------------
# VALIDACOES
# ------------------------------------------------------------

if (-not (Test-Path $CandidateCsv)) {
    throw "CSV de candidatos nao encontrado: $CandidateCsv"
}

if (-not (Test-Path $Vgmstream)) {
    throw "vgmstream-cli nao encontrado: $Vgmstream"
}

New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null

$ExtractedRoot = Join-Path $Lab "Extracted"

if (-not (Test-Path $ExtractedRoot)) {
    throw "Pasta de extracao nao encontrada: $ExtractedRoot"
}

Write-Host "Repo:"
Write-Host "  $Repo"
Write-Host ""

Write-Host "CSV candidatos:"
Write-Host "  $CandidateCsv"
Write-Host ""

Write-Host "vgmstream:"
Write-Host "  $Vgmstream"
Write-Host ""

Write-Host "Procurando WEM extraidos..."
Write-Host ""

# ------------------------------------------------------------
# INDEXAR WEM
# ------------------------------------------------------------

$WemFiles = Get-ChildItem `
    -Path $ExtractedRoot `
    -Filter "*.wem" `
    -File `
    -Recurse

if ($WemFiles.Count -eq 0) {
    throw "Nenhum WEM encontrado em $ExtractedRoot"
}

$WemIndex = @{}

foreach ($File in $WemFiles) {

    $Name = $File.Name.ToLowerInvariant()

    if (-not $WemIndex.ContainsKey($Name)) {
        $WemIndex[$Name] = $File.FullName
    }
}

Write-Host "WEM encontrados localmente: $($WemFiles.Count)"
Write-Host ""

# ------------------------------------------------------------
# LER CANDIDATOS
# ------------------------------------------------------------

$Candidates = @(Import-Csv -LiteralPath $CandidateCsv)

if ($Candidates.Count -eq 0) {
    throw "Nenhum candidato encontrado no CSV."
}

Write-Host "Candidatos no CSV: $($Candidates.Count)"
Write-Host ""

# ------------------------------------------------------------
# PREPARAR MANIFEST
# ------------------------------------------------------------

$Manifest = New-Object System.Collections.Generic.List[object]

$Converted = 0
$AlreadyExists = 0
$Missing = 0
$Errors = 0

$StartTime = Get-Date

# ------------------------------------------------------------
# PROCESSAMENTO
# ------------------------------------------------------------

for ($i = 0; $i -lt $Candidates.Count; $i++) {

    $Row = $Candidates[$i]

    $Number = $i + 1

    # CORRECAO:
    # Floor retorna Double, portanto convertemos explicitamente
    # para Int antes de utilizar o formato D3.
    [int]$BatchNumber = [math]::Floor($i / $BatchSize) + 1

    $BatchName = "Batch_{0:D3}" -f $BatchNumber

    $BatchDir = Join-Path $WorkRoot $BatchName

    New-Item -ItemType Directory -Force -Path $BatchDir | Out-Null

    $WemName = [string]$Row.WEM

    $WemKey = $WemName.ToLowerInvariant()

    $SourcePath = $null

    if ($WemIndex.ContainsKey($WemKey)) {
        $SourcePath = $WemIndex[$WemKey]
    }

    $SafeBase = [System.IO.Path]::GetFileNameWithoutExtension($WemName)

    $OutputName = "{0:D4}_{1}.wav" -f $Number, $SafeBase

    $OutputPath = Join-Path $BatchDir $OutputName

    $Status = ""

    # --------------------------------------------------------
    # WEM AUSENTE
    # --------------------------------------------------------

    if ($null -eq $SourcePath) {

        $Status = "MISSING_SOURCE"

        $Missing++

    }

    # --------------------------------------------------------
    # WAV JA EXISTE
    # --------------------------------------------------------

    elseif (Test-Path $OutputPath) {

        $Status = "EXISTS"

        $AlreadyExists++

    }

    # --------------------------------------------------------
    # CONVERTER
    # --------------------------------------------------------

    else {

        Write-Host ("[{0}/{1}] Convertendo {2}" -f `
            $Number, `
            $Candidates.Count, `
            $WemName)

        try {

            & $Vgmstream `
                "-i" `
                "-o" $OutputPath `
                $SourcePath `
                2>$null

            if ($LASTEXITCODE -eq 0 -and (Test-Path $OutputPath)) {

                $Status = "CONVERTED"

                $Converted++

            }
            else {

                $Status = "ERROR"

                $Errors++

            }

        }
        catch {

            $Status = "ERROR"

            $Errors++

        }
    }

    # --------------------------------------------------------
    # MANIFEST
    # --------------------------------------------------------

    $Manifest.Add([pscustomobject]@{
        Index       = $Number
        Batch       = $BatchName
        WEM         = $Row.WEM
        SourcePath  = $SourcePath
        WAV         = $OutputPath
        EventID     = $Row.EventID
        ActionID    = $Row.ActionID
        SoundID     = $Row.SoundID
        SourceID    = $Row.SourceID
        StreamType  = $Row.StreamType
        DurationSec = $Row.DurationSec
        BitrateKbps = $Row.BitrateKbps
        Encoding    = $Row.Encoding
        SampleRate  = $Row.SampleRate
        Channels    = $Row.Channels
        Bucket      = $Row.Bucket
        Status      = $Status
    })

    # --------------------------------------------------------
    # PROGRESSO
    # --------------------------------------------------------

    if (($Number % 25) -eq 0) {

        Write-Host ""
        Write-Host "Progresso:"
        Write-Host "  Processados: $Number / $($Candidates.Count)"
        Write-Host "  Convertidos: $Converted"
        Write-Host "  Existentes:  $AlreadyExists"
        Write-Host "  Ausentes:    $Missing"
        Write-Host "  Erros:       $Errors"
        Write-Host ""
    }
}

# ------------------------------------------------------------
# SALVAR MANIFEST
# ------------------------------------------------------------

$Manifest |
    Export-Csv `
        -LiteralPath $ManifestOut `
        -NoTypeInformation `
        -Encoding UTF8

# ------------------------------------------------------------
# GERAR HTML
# ------------------------------------------------------------

$HtmlPath = Join-Path $WorkRoot "index.html"

$Html = New-Object System.Text.StringBuilder

[void]$Html.AppendLine("<!DOCTYPE html>")
[void]$Html.AppendLine("<html lang='pt-BR'>")
[void]$Html.AppendLine("<head>")
[void]$Html.AppendLine("<meta charset='UTF-8'>")
[void]$Html.AppendLine("<meta name='viewport' content='width=device-width, initial-scale=1.0'>")
[void]$Html.AppendLine("<title>Thief 2014 - Voice Audition Library</title>")

[void]$Html.AppendLine("<style>")
[void]$Html.AppendLine(@"
body {
    font-family: Arial, sans-serif;
    background: #151515;
    color: #eeeeee;
    margin: 0;
    padding: 25px;
}

h1 {
    margin-top: 0;
}

.summary {
    padding: 15px;
    background: #222;
    border-radius: 8px;
    margin-bottom: 25px;
}

.batch {
    margin-top: 35px;
}

.item {
    background: #202020;
    border: 1px solid #333;
    border-radius: 8px;
    padding: 14px;
    margin: 10px 0;
}

.item:hover {
    background: #272727;
}

.meta {
    font-size: 13px;
    color: #aaaaaa;
    margin-top: 7px;
}

audio {
    width: 100%;
    margin-top: 10px;
}
"@)
[void]$Html.AppendLine("</style>")
[void]$Html.AppendLine("</head>")
[void]$Html.AppendLine("<body>")

[void]$Html.AppendLine("<h1>Thief 2014 - Voice Audition Library</h1>")

[void]$Html.AppendLine("<div class='summary'>")
[void]$Html.AppendLine("<strong>Total candidatos:</strong> $($Candidates.Count)<br>")
[void]$Html.AppendLine("<strong>Convertidos:</strong> $Converted<br>")
[void]$Html.AppendLine("<strong>Ja existentes:</strong> $AlreadyExists<br>")
[void]$Html.AppendLine("<strong>Fonte ausente:</strong> $Missing<br>")
[void]$Html.AppendLine("<strong>Erros:</strong> $Errors")
[void]$Html.AppendLine("</div>")

$CurrentBatch = ""

foreach ($Item in $Manifest) {

    if ($Item.Batch -ne $CurrentBatch) {

        if ($CurrentBatch -ne "") {
            [void]$Html.AppendLine("</div>")
        }

        $CurrentBatch = $Item.Batch

        [void]$Html.AppendLine("<div class='batch'>")
        [void]$Html.AppendLine("<h2>$CurrentBatch</h2>")
    }

    if ($Item.Status -eq "MISSING_SOURCE") {

        [void]$Html.AppendLine("<div class='item'>")
        [void]$Html.AppendLine("<strong>$($Item.Index) - $($Item.WEM)</strong>")
        [void]$Html.AppendLine("<div class='meta'>SOURCE AUSENTE</div>")
        [void]$Html.AppendLine("</div>")

        continue
    }

    if ($Item.Status -eq "ERROR") {

        [void]$Html.AppendLine("<div class='item'>")
        [void]$Html.AppendLine("<strong>$($Item.Index) - $($Item.WEM)</strong>")
        [void]$Html.AppendLine("<div class='meta'>ERRO NA CONVERSAO</div>")
        [void]$Html.AppendLine("</div>")

        continue
    }

    $RelativeWav = "$($Item.Batch)/$([System.IO.Path]::GetFileName($Item.WAV))"

    [void]$Html.AppendLine("<div class='item'>")

    [void]$Html.AppendLine("<strong>$($Item.Index) - $($Item.WEM)</strong>")

    [void]$Html.AppendLine("<div class='meta'>")
    [void]$Html.AppendLine("EventID: $($Item.EventID) | ")
    [void]$Html.AppendLine("ActionID: $($Item.ActionID) | ")
    [void]$Html.AppendLine("SoundID: $($Item.SoundID) | ")
    [void]$Html.AppendLine("Duration: $($Item.DurationSec)s | ")
    [void]$Html.AppendLine("Bitrate: $($Item.BitrateKbps) kbps")
    [void]$Html.AppendLine("</div>")

    [void]$Html.AppendLine("<audio controls preload='none' src='$RelativeWav'></audio>")

    [void]$Html.AppendLine("</div>")
}

if ($CurrentBatch -ne "") {
    [void]$Html.AppendLine("</div>")
}

[void]$Html.AppendLine("</body>")
[void]$Html.AppendLine("</html>")

$Html.ToString() |
    Set-Content `
        -LiteralPath $HtmlPath `
        -Encoding UTF8

# ------------------------------------------------------------
# RELATORIO
# ------------------------------------------------------------

$EndTime = Get-Date
$Elapsed = $EndTime - $StartTime

$Report = @"

============================================================
 THIEF 2014 - VOICE AUDITION LIBRARY
 SCRIPT 14
============================================================

Execucao:
$StartTime

Final:
$EndTime

Tempo:
$($Elapsed.ToString())

------------------------------------------------------------
RESUMO
------------------------------------------------------------

Candidatos CSV:       $($Candidates.Count)
WEM locais:           $($WemFiles.Count)

Convertidos:          $Converted
Ja existentes:        $AlreadyExists
Fonte ausente:        $Missing
Erros conversao:      $Errors

Tamanho dos lotes:    $BatchSize

------------------------------------------------------------
ARQUIVOS
------------------------------------------------------------

Manifest:
$ManifestOut

HTML:
$HtmlPath

Pasta de trabalho:
$WorkRoot

============================================================
"@

$Report |
    Set-Content `
        -LiteralPath $ReportOut `
        -Encoding UTF8

# ------------------------------------------------------------
# GIT
# ------------------------------------------------------------

Set-Location $Repo

git add `
    ".\Scripts\14_Create_Voice_Audition_Library.ps1" `
    ".\Analysis\WEM\voice_audition_manifest.csv" `
    ".\Analysis\Reports\voice_audition_library_report.txt"

git commit -m "Fix voice audition library generator"

git push

Write-Host ""
Write-Host "============================================================"
Write-Host " VOICE AUDITION LIBRARY 14 CONCLUIDA"
Write-Host "============================================================"
Write-Host ""
Write-Host "Candidatos:    $($Candidates.Count)"
Write-Host "Convertidos:   $Converted"
Write-Host "Existentes:    $AlreadyExists"
Write-Host "Ausentes:      $Missing"
Write-Host "Erros:         $Errors"
Write-Host ""
Write-Host "HTML:"
Write-Host "  $HtmlPath"
Write-Host ""
Write-Host "Manifest:"
Write-Host "  $ManifestOut"
Write-Host ""
Write-Host "Git sincronizado."
Write-Host ""
