# ============================================================
# SCRIPT 19 - TRANSCRICAO AUTOMATICA DAS FALAS
# THIEF 2014 PT-BR DUBBING
# ============================================================

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# CONFIGURACAO
# ------------------------------------------------------------

$RepoRoot = "B:\DublagemThief2014"

$InputCsv = Join-Path `
    $RepoRoot `
    "Analysis\WEM\dubbing_workset.csv"

$OutputCsv = Join-Path `
    $RepoRoot `
    "Analysis\WEM\dubbing_transcription.csv"

$ReportPath = Join-Path `
    $RepoRoot `
    "Analysis\Reports\dubbing_transcription_report.txt"

$PythonScript = Join-Path `
    $RepoRoot `
    "Scripts\19_transcribe_faster_whisper.py"

$PythonExe = `
    "B:\Thief2014_Dubbing\Tools\PythonEnv\Scripts\python.exe"

$WorkDir = `
    "B:\Thief2014_Dubbing\Work\VoiceAudition"

$ModelName = "small.en"

$Device = "cpu"

$ComputeType = "int8"

# 0 = processar tudo que estiver pendente
$Limit = 0

# ------------------------------------------------------------
# VALIDACOES
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " THIEF 2014 - TRANSCRICAO AUTOMATICA" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path -LiteralPath $InputCsv)) {
    throw "CSV de entrada nao encontrado: $InputCsv"
}

if (-not (Test-Path -LiteralPath $PythonScript)) {
    throw "Script Python nao encontrado: $PythonScript"
}

if (-not (Test-Path -LiteralPath $PythonExe)) {
    throw "Python nao encontrado: $PythonExe"
}

if (-not (Test-Path -LiteralPath $WorkDir)) {
    throw "Diretorio de trabalho nao encontrado: $WorkDir"
}

# Desabilita o aviso de symlink do Hugging Face
$env:HF_HUB_DISABLE_SYMLINKS_WARNING = "1"

# ------------------------------------------------------------
# INFORMACOES
# ------------------------------------------------------------

Write-Host "Modelo        : $ModelName"
Write-Host "Dispositivo   : $Device"
Write-Host "Compute type  : $ComputeType"
Write-Host "Limite        : $Limit"
Write-Host ""

Write-Host "CSV entrada:"
Write-Host $InputCsv
Write-Host ""

Write-Host "CSV saida:"
Write-Host $OutputCsv
Write-Host ""

# ------------------------------------------------------------
# CRIA DIRETORIOS
# ------------------------------------------------------------

$ReportDir = Split-Path -Parent $ReportPath

if (-not (Test-Path -LiteralPath $ReportDir)) {
    New-Item `
        -ItemType Directory `
        -Path $ReportDir `
        -Force | Out-Null
}

# ------------------------------------------------------------
# EXECUCAO DO PYTHON
# ------------------------------------------------------------

$StartTime = Get-Date

$Arguments = @(
    $PythonScript
    $InputCsv
    $OutputCsv
    $WorkDir
    $ModelName
    $Device
    $ComputeType
    $Limit
)

Write-Host "Iniciando Whisper..." -ForegroundColor Yellow
Write-Host ""

# ------------------------------------------------------------
# CONTADORES
# ------------------------------------------------------------

$Total = 0
$Processed = 0
$Transcribed = 0
$NoSpeech = 0
$Errors = 0
$AlreadyExists = 0

$CurrentIndex = 0
$CurrentWem = ""

# ------------------------------------------------------------
# START PROCESS
# ------------------------------------------------------------

$ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo

$ProcessInfo.FileName = $PythonExe

$ProcessInfo.UseShellExecute = $false

$ProcessInfo.RedirectStandardOutput = $true

$ProcessInfo.RedirectStandardError = $true

$ProcessInfo.CreateNoWindow = $true

# Monta argumentos com aspas seguras
$EscapedArguments = foreach ($Argument in $Arguments) {

    $StringArgument = [string]$Argument

    if ($StringArgument -match '[\s"]') {

        '"' + ($StringArgument -replace '"', '\"') + '"'

    } else {

        $StringArgument
    }
}

$ProcessInfo.Arguments = $EscapedArguments -join " "

$Process = New-Object System.Diagnostics.Process

$Process.StartInfo = $ProcessInfo

$null = $Process.Start()

# ------------------------------------------------------------
# FUNCAO DE PROGRESSO
# ------------------------------------------------------------

function Update-TranscriptionProgress {

    param(
        [int]$Current,
        [int]$TotalItems,
        [string]$Wem,
        [string]$Status,
        [int]$Done,
        [int]$Ok,
        [int]$NoSpeechCount,
        [int]$ErrorCount,
        [datetime]$Started
    )

    if ($TotalItems -le 0) {
        return
    }

    $Percent = [math]::Min(
        100,
        [math]::Max(
            0,
            ($Current / $TotalItems) * 100
        )
    )

    $Elapsed = (Get-Date) - $Started

    if ($Current -gt 0) {

        $SecondsPerItem =
            $Elapsed.TotalSeconds / $Current

        $RemainingItems =
            [math]::Max(
                0,
                $TotalItems - $Current
            )

        $RemainingSeconds =
            $SecondsPerItem * $RemainingItems

        $Remaining = [TimeSpan]::FromSeconds(
            $RemainingSeconds
        )

        $ElapsedText =
            $Elapsed.ToString("hh\:mm\:ss")

        $RemainingText =
            $Remaining.ToString("hh\:mm\:ss")

        $Speed =
            $Current / [math]::Max(
                0.1,
                $Elapsed.TotalSeconds
            )

        $SpeedText =
            "{0:N2} audio/s" -f $Speed

    } else {

        $ElapsedText = "00:00:00"

        $RemainingText = "--:--:--"

        $SpeedText = "-- audio/s"
    }

    $Activity =
        "Transcrevendo $Current/$TotalItems"

    $StatusText =
        "$Wem | $Status | " +
        "OK: $Ok | Sem fala: $NoSpeechCount | Erros: $ErrorCount | " +
        "Tempo: $ElapsedText | Restante: $RemainingText | $SpeedText"

    Write-Progress `
        -Activity $Activity `
        -Status $StatusText `
        -PercentComplete $Percent
}

# ------------------------------------------------------------
# LEITURA DAS LINHAS DO PYTHON
# ------------------------------------------------------------

while (-not $Process.HasExited -or -not $Process.StandardOutput.EndOfStream) {

    if (-not $Process.StandardOutput.EndOfStream) {

        $Line = $Process.StandardOutput.ReadLine()

        if ([string]::IsNullOrWhiteSpace($Line)) {
            continue
        }

        # ----------------------------------------------------
        # FORMATO DE PROGRESSO:
        #
        # PROGRESS|current|total|wem|status|ok|nospeech|errors
        # ----------------------------------------------------

        if ($Line.StartsWith("PROGRESS|")) {

            $Parts = $Line -split "\|", 8

            if ($Parts.Count -ge 8) {

                $CurrentIndex = 0
                $Total = 0
                $CurrentWem = $Parts[3]

                [int]::TryParse(
                    $Parts[1],
                    [ref]$CurrentIndex
                ) | Out-Null

                [int]::TryParse(
                    $Parts[2],
                    [ref]$Total
                ) | Out-Null

                $Status = $Parts[4]

                $Ok = 0
                $NoSpeechCount = 0
                $ErrorCount = 0

                [int]::TryParse(
                    $Parts[5],
                    [ref]$Ok
                ) | Out-Null

                [int]::TryParse(
                    $Parts[6],
                    [ref]$NoSpeechCount
                ) | Out-Null

                [int]::TryParse(
                    $Parts[7],
                    [ref]$ErrorCount
                ) | Out-Null

                $Processed = $CurrentIndex

                Update-TranscriptionProgress `
                    -Current $CurrentIndex `
                    -TotalItems $Total `
                    -Wem $CurrentWem `
                    -Status $Status `
                    -Done $Processed `
                    -Ok $Ok `
                    -NoSpeechCount $NoSpeechCount `
                    -ErrorCount $ErrorCount `
                    -Started $StartTime
            }

            continue
        }

        # ----------------------------------------------------
        # RESULTADO FINAL
        # ----------------------------------------------------

        if ($Line.StartsWith("RESULT|")) {

            $Parts = $Line -split "\|"

            if ($Parts.Count -ge 6) {

                [int]::TryParse(
                    $Parts[1],
                    [ref]$Total
                ) | Out-Null

                [int]::TryParse(
                    $Parts[2],
                    [ref]$Processed
                ) | Out-Null

                [int]::TryParse(
                    $Parts[3],
                    [ref]$Transcribed
                ) | Out-Null

                [int]::TryParse(
                    $Parts[4],
                    [ref]$NoSpeech
                ) | Out-Null

                [int]::TryParse(
                    $Parts[5],
                    [ref]$Errors
                ) | Out-Null
            }

            continue
        }

        Write-Host $Line
    }
    else {

        Start-Sleep -Milliseconds 50
    }
}

# ------------------------------------------------------------
# STDERR
# ------------------------------------------------------------

$StdErr = $Process.StandardError.ReadToEnd()

if (-not [string]::IsNullOrWhiteSpace($StdErr)) {

    Write-Host ""
    Write-Host "Avisos do Python:" -ForegroundColor DarkYellow
    Write-Host $StdErr -ForegroundColor DarkYellow
}

$Process.WaitForExit()

$ExitCode = $Process.ExitCode

# Fecha a barra
Write-Progress `
    -Activity "Transcrição concluída" `
    -Completed

$EndTime = Get-Date

$TotalTime = $EndTime - $StartTime

# ------------------------------------------------------------
# ERRO DE EXECUCAO
# ------------------------------------------------------------

if ($ExitCode -ne 0) {

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host " ERRO NA TRANSCRICAO" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Codigo de saida: $ExitCode" -ForegroundColor Red
    Write-Host ""

    throw "O processo Python terminou com codigo $ExitCode."
}

# ------------------------------------------------------------
# RELATORIO
# ------------------------------------------------------------

$Report = @"

============================================================
THIEF 2014 - RELATORIO DE TRANSCRICAO
============================================================

Data inicio:
$StartTime

Data fim:
$EndTime

Tempo total:
$($TotalTime.ToString("hh\:mm\:ss"))

Modelo:
$ModelName

Device:
$Device

ComputeType:
$ComputeType

CSV entrada:
$InputCsv

CSV saida:
$OutputCsv

============================================================
RESULTADOS
============================================================

Total FALAS:
$Total

Processadas:
$Processed

Transcricoes OK:
$Transcribed

Sem fala:
$NoSpeech

Erros:
$Errors

============================================================
FIM
============================================================
"@

Set-Content `
    -LiteralPath $ReportPath `
    -Value $Report `
    -Encoding UTF8

# ------------------------------------------------------------
# RESUMO
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " TRANSCRICAO CONCLUIDA" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Total FALAS:       $Total"
Write-Host "Processadas:       $Processed"
Write-Host "Transcricoes OK:   $Transcribed"
Write-Host "Sem fala:          $NoSpeech"
Write-Host "Erros:             $Errors"
Write-Host "Tempo total:       $($TotalTime.ToString("hh\:mm\:ss"))"

Write-Host ""

Write-Host "CSV:"
Write-Host $OutputCsv

Write-Host ""

Write-Host "Relatorio:"
Write-Host $ReportPath

Write-Host ""