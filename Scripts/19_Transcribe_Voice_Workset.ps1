# ============================================================
# THIEF 2014 - SCRIPT 19
# TRANSCRIÇÃO AUTOMÁTICA DAS FALAS
# ============================================================

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# CONFIGURAÇÃO
# ------------------------------------------------------------

$Repo = "B:\DublagemThief2014"
$Lab  = "B:\Thief2014_Dubbing"

$AnalysisDir = Join-Path $Repo "Analysis\WEM"
$ReportsDir  = Join-Path $Repo "Analysis\Reports"
$ScriptsDir  = Join-Path $Repo "Scripts"

$WorkDir = Join-Path $Lab "Work\VoiceAudition"

$InputCsv = Join-Path $AnalysisDir "dubbing_workset.csv"
$OutputCsv = Join-Path $AnalysisDir "dubbing_transcription.csv"
$Report = Join-Path $ReportsDir "dubbing_transcription_report.txt"

$PythonEnv = Join-Path $Lab "Tools\PythonEnv"
$PythonExe = Join-Path $PythonEnv "Scripts\python.exe"

# ------------------------------------------------------------
# TESTE
# ------------------------------------------------------------

# 10 = processar somente as primeiras 10 FALAS
# 0  = processar todas
$Limit = 10

# ------------------------------------------------------------
# WHISPER
# ------------------------------------------------------------

$ModelName = "small.en"
$Device = "cpu"
$ComputeType = "int8"

# ------------------------------------------------------------
# CABEÇALHO
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================="
Write-Host " THIEF 2014 - TRANSCRIPTION - SCRIPT 19"
Write-Host "============================================="
Write-Host ""

# ------------------------------------------------------------
# VALIDAR CAMINHOS
# ------------------------------------------------------------

if (-not (Test-Path -LiteralPath $Repo)) {
    throw "Repositorio nao encontrado: $Repo"
}

if (-not (Test-Path -LiteralPath $InputCsv)) {
    throw "dubbing_workset.csv nao encontrado: $InputCsv"
}

if (-not (Test-Path -LiteralPath $PythonExe)) {
    throw "Python nao encontrado: $PythonExe"
}

Write-Host "Workset encontrado:"
Write-Host $InputCsv
Write-Host ""

Write-Host "Python encontrado:"
Write-Host $PythonExe
Write-Host ""

# ------------------------------------------------------------
# FUNÇÃO: EXECUTAR PYTHON SEM QUE O STDERR ABORTE O POWERSHELL
# ------------------------------------------------------------

function Invoke-PythonCommand {
    param(
        [string[]]$Arguments
    )

    # O Python envia warnings e mensagens normais para stderr.
    # Com ErrorActionPreference = Stop, o PowerShell pode
    # transformar isso em NativeCommandError.
    #
    # Durante a execução do Python, temporariamente permitimos
    # que stderr seja tratado apenas como saída.

    $PreviousErrorActionPreference = $ErrorActionPreference

    try {

        $ErrorActionPreference = "Continue"

        $Output = & $PythonExe @Arguments 2>&1

        $ExitCode = $LASTEXITCODE

    }
    finally {

        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    return [PSCustomObject]@{
        Output = $Output
        ExitCode = $ExitCode
    }
}
# ------------------------------------------------------------
# VERIFICAR FASTER-WHISPER
# ------------------------------------------------------------

Write-Host "Verificando faster-whisper..."

$Check = Invoke-PythonCommand @(
    "-c",
    "import faster_whisper; print(faster_whisper.__version__)"
)

if ($Check.ExitCode -eq 0) {

    $WhisperVersion = (
        $Check.Output |
        Select-Object -Last 1
    ).ToString().Trim()

    Write-Host "faster-whisper encontrado:"
    Write-Host $WhisperVersion
    Write-Host ""

}
else {

    Write-Host ""
    Write-Host "faster-whisper nao esta instalado." `
        -ForegroundColor Yellow

    Write-Host ""
    Write-Host "Instalando faster-whisper..."
    Write-Host ""

    $Install = Invoke-PythonCommand @(
        "-m",
        "pip",
        "install",
        "--upgrade",
        "faster-whisper"
    )

    $Install.Output | ForEach-Object {
        Write-Host $_
    }

    if ($Install.ExitCode -ne 0) {

        Write-Host ""
        Write-Host "ERRO AO INSTALAR FASTER-WHISPER" `
            -ForegroundColor Red
        Write-Host ""

        exit 1
    }

    Write-Host ""
    Write-Host "faster-whisper instalado."
    Write-Host ""
}

# ------------------------------------------------------------
# HUGGING FACE
# ------------------------------------------------------------

$env:HF_HUB_DISABLE_SYMLINKS_WARNING = "1"

# ------------------------------------------------------------
# CRIAR SCRIPT PYTHON
# ------------------------------------------------------------

$PythonScript = Join-Path `
    $ScriptsDir `
    "19_transcribe_faster_whisper.py"

@'
import csv
import sys
import time
from pathlib import Path

from faster_whisper import WhisperModel


# ============================================================
# ARGUMENTOS
# ============================================================

INPUT_CSV = Path(sys.argv[1])
OUTPUT_CSV = Path(sys.argv[2])
WORK_DIR = Path(sys.argv[3])

MODEL_NAME = sys.argv[4]
DEVICE = sys.argv[5]
COMPUTE_TYPE = sys.argv[6]
LIMIT = int(sys.argv[7])


# ============================================================
# LEITURA DO WORKSET
# ============================================================

with INPUT_CSV.open(
    "r",
    encoding="utf-8-sig",
    newline=""
) as f:

    rows = list(csv.DictReader(f))


# ============================================================
# SOMENTE FALA
# ============================================================

fala_rows = []

for row in rows:

    category = (
        row.get("Category", "")
        or row.get("Classification", "")
    ).strip().upper()

    if category == "FALA":
        fala_rows.append(row)


if LIMIT > 0:
    fala_rows = fala_rows[:LIMIT]


print("")
print("=============================================")
print(" FASTER-WHISPER")
print("=============================================")
print("")
print(f"FALAS selecionadas: {len(fala_rows)}")
print(f"Modelo:             {MODEL_NAME}")
print(f"Device:             {DEVICE}")
print(f"Compute type:       {COMPUTE_TYPE}")
print("")


# ============================================================
# RESULTADOS EXISTENTES
# ============================================================

existing = {}

if OUTPUT_CSV.exists():

    try:

        with OUTPUT_CSV.open(
            "r",
            encoding="utf-8-sig",
            newline=""
        ) as f:

            reader = csv.DictReader(f)

            for row in reader:

                key = (
                    row.get("Index", "")
                    or row.get("WEM", "")
                )

                if key:
                    existing[key] = row

    except Exception:

        existing = {}


# ============================================================
# CARREGAR MODELO
# ============================================================

print("Carregando modelo...")
print("")

model = WhisperModel(
    MODEL_NAME,
    device=DEVICE,
    compute_type=COMPUTE_TYPE
)

print("Modelo carregado.")
print("")


# ============================================================
# CAMPOS
# ============================================================

fieldnames = [
    "Index",
    "Batch",
    "WEM",
    "Audio",
    "EventID",
    "ActionID",
    "SoundID",
    "SourceID",
    "DurationSec",
    "Category",
    "Character",
    "OriginalTranscript",
    "PTBR",
    "Notes",
    "Status",
    "WhisperModel",
    "WhisperLanguage",
    "WhisperProbability",
    "TranscriptionTimeSec"
]


# ============================================================
# SALVAR
# ============================================================

def save_output():

    ordered = []

    for source in fala_rows:

        key = (
            source.get("Index", "")
            or source.get("WEM", "")
        )

        if key in existing:
            ordered.append(existing[key])

    with OUTPUT_CSV.open(
        "w",
        encoding="utf-8-sig",
        newline=""
    ) as f:

        writer = csv.DictWriter(
            f,
            fieldnames=fieldnames
        )

        writer.writeheader()

        for row in ordered:

            writer.writerow({
                field: row.get(field, "")
                for field in fieldnames
            })


# ============================================================
# PROCESSAMENTO
# ============================================================

total = len(fala_rows)

processed = 0
success = 0
errors = 0
skipped = 0

start_all = time.time()


for position, source in enumerate(
    fala_rows,
    start=1
):

    index = source.get("Index", "")
    wem = source.get("WEM", "")

    key = index or wem

    # --------------------------------------------------------
    # IGNORAR JÁ PROCESSADOS
    # --------------------------------------------------------

    if key in existing:

        status = existing[key].get(
            "Status",
            ""
        )

        transcript = existing[key].get(
            "OriginalTranscript",
            ""
        )

        if (
            status == "TRANSCRIBED"
            and transcript.strip()
        ):

            print(
                f"[{position}/{total}] "
                f"SKIP {wem}"
            )

            skipped += 1
            continue

    # --------------------------------------------------------
    # ÁUDIO
    # --------------------------------------------------------

    audio = source.get(
        "Audio",
        ""
    ).strip()

    if not audio:

        print(
            f"[{position}/{total}] "
            f"ERRO: audio vazio"
        )

        existing[key] = {
            **source,
            "OriginalTranscript": "",
            "PTBR": "",
            "Status": "ERROR_NO_AUDIO",
            "WhisperModel": MODEL_NAME,
            "WhisperLanguage": "",
            "WhisperProbability": "",
            "TranscriptionTimeSec": ""
        }

        errors += 1

        save_output()

        continue


    audio_path = Path(audio)

    if not audio_path.is_absolute():

        audio_path = WORK_DIR / audio_path


    if not audio_path.exists():

        print(
            f"[{position}/{total}] "
            f"ERRO: WAV nao encontrado"
        )

        existing[key] = {
            **source,
            "OriginalTranscript": "",
            "PTBR": "",
            "Status": "ERROR_MISSING_WAV",
            "WhisperModel": MODEL_NAME,
            "WhisperLanguage": "",
            "WhisperProbability": "",
            "TranscriptionTimeSec": ""
        }

        errors += 1

        save_output()

        continue


    # --------------------------------------------------------
    # TRANSCRIÇÃO
    # --------------------------------------------------------

    print("")
    print(
        f"[{position}/{total}] "
        f"Transcrevendo: {wem}"
    )

    print(
        f"    Audio: {audio_path}"
    )

    begin = time.time()

    try:

        segments, info = model.transcribe(
            str(audio_path),
            language="en",
            task="transcribe",
            beam_size=5,
            vad_filter=True,
            condition_on_previous_text=False
        )

        parts = []

        for segment in segments:

            text = segment.text.strip()

            if text:
                parts.append(text)


        transcript = " ".join(
            parts
        ).strip()


        elapsed = time.time() - begin


        probability = ""

        try:

            probability = (
                f"{info.language_probability:.4f}"
            )

        except Exception:
            pass


        if transcript:

            status = "TRANSCRIBED"

            success += 1

            print(
                f"    OK: {transcript}"
            )

        else:

            status = "NO_SPEECH"

            print(
                "    Nenhuma fala detectada."
            )


        print(
            f"    Idioma: "
            f"{getattr(info, 'language', 'en')}"
        )

        print(
            f"    Probabilidade: "
            f"{probability}"
        )

        print(
            f"    Tempo: "
            f"{elapsed:.2f}s"
        )


        existing[key] = {
            **source,

            "OriginalTranscript": transcript,

            "PTBR": "",

            "Status": status,

            "WhisperModel": MODEL_NAME,

            "WhisperLanguage": getattr(
                info,
                "language",
                "en"
            ),

            "WhisperProbability": probability,

            "TranscriptionTimeSec": (
                f"{elapsed:.2f}"
            )
        }


        save_output()

        processed += 1


    except Exception as exc:

        elapsed = time.time() - begin

        print(
            f"    ERRO: {exc}"
        )

        existing[key] = {
            **source,

            "OriginalTranscript": "",

            "PTBR": "",

            "Status": "ERROR_TRANSCRIPTION",

            "WhisperModel": MODEL_NAME,

            "WhisperLanguage": "",

            "WhisperProbability": "",

            "TranscriptionTimeSec": (
                f"{elapsed:.2f}"
            ),

            "Notes": (
                source.get("Notes", "")
                + " | "
                + str(exc)
            ).strip()
        }

        errors += 1

        save_output()


# ============================================================
# FINAL
# ============================================================

total_time = time.time() - start_all

save_output()

print("")
print("=============================================")
print(" TRANSCRICAO CONCLUIDA")
print("=============================================")
print("")
print(f"Total FALAS:     {total}")
print(f"Processadas:     {processed}")
print(f"Transcricoes OK: {success}")
print(f"Sem fala:        {total - success - errors}")
print(f"Erros:           {errors}")
print(f"Ja existentes:   {skipped}")
print(f"Tempo total:     {total_time:.2f}s")
print("")
print(f"CSV: {OUTPUT_CSV}")
print("")
'@ |
    Set-Content `
        -LiteralPath $PythonScript `
        -Encoding UTF8

Write-Host "Script Python preparado:"
Write-Host $PythonScript
Write-Host ""

# ------------------------------------------------------------
# EXECUTAR
# ------------------------------------------------------------

Write-Host "Iniciando transcricao..."
Write-Host ""
Write-Host "Modelo:  $ModelName"
Write-Host "Device:  $Device"
Write-Host "Compute: $ComputeType"
Write-Host "Limite:  $Limit"
Write-Host ""

$Process = Invoke-PythonCommand @(
    $PythonScript,
    $InputCsv,
    $OutputCsv,
    $WorkDir,
    $ModelName,
    $Device,
    $ComputeType,
    $Limit
)

$Process.Output | ForEach-Object {
    Write-Host $_
}

if ($Process.ExitCode -ne 0) {

    Write-Host ""
    Write-Host "============================================="
    Write-Host " ERRO NA TRANSCRICAO"
    Write-Host "============================================="
    Write-Host ""

    exit 1
}

# ------------------------------------------------------------
# VALIDAR CSV
# ------------------------------------------------------------

if (-not (Test-Path -LiteralPath $OutputCsv)) {

    throw "CSV de transcricao nao foi criado."
}

$Rows = Import-Csv `
    -LiteralPath $OutputCsv

$TotalOutput = @($Rows).Count

$Transcribed = @(
    $Rows |
    Where-Object {
        $_.Status -eq "TRANSCRIBED"
    }
).Count

$NoSpeech = @(
    $Rows |
    Where-Object {
        $_.Status -eq "NO_SPEECH"
    }
).Count

$Errors = @(
    $Rows |
    Where-Object {
        $_.Status -like "ERROR*"
    }
).Count

# ------------------------------------------------------------
# RELATÓRIO
# ------------------------------------------------------------

$ReportLines = @()

$ReportLines += "THIEF 2014 - DUBBING TRANSCRIPTION"
$ReportLines += "SCRIPT 19"
$ReportLines += ""
$ReportLines += "Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$ReportLines += ""
$ReportLines += "Entrada:"
$ReportLines += $InputCsv
$ReportLines += ""
$ReportLines += "Modelo:"
$ReportLines += $ModelName
$ReportLines += ""
$ReportLines += "Device:"
$ReportLines += $Device
$ReportLines += ""
$ReportLines += "Compute:"
$ReportLines += $ComputeType
$ReportLines += ""
$ReportLines += "Limite:"
$ReportLines += $Limit
$ReportLines += ""
$ReportLines += "RESULTADO"
$ReportLines += "----------------------------------------"
$ReportLines += "Registros:       $TotalOutput"
$ReportLines += "Transcritas:     $Transcribed"
$ReportLines += "Sem fala:        $NoSpeech"
$ReportLines += "Erros:           $Errors"
$ReportLines += ""
$ReportLines += "CSV:"
$ReportLines += $OutputCsv
$ReportLines += ""
$ReportLines += "PTBR permanece vazio nesta etapa."
$ReportLines += ""
$ReportLines += "Nenhum WEM, BNK ou PCK foi alterado."

$ReportLines |
    Set-Content `
        -LiteralPath $Report `
        -Encoding UTF8

# ------------------------------------------------------------
# GIT
# ------------------------------------------------------------

Set-Location $Repo

git add `
    "Scripts/19_Transcribe_Voice_Workset.ps1" `
    "Scripts/19_transcribe_faster_whisper.py" `
    "Analysis/WEM/dubbing_transcription.csv" `
    "Analysis/Reports/dubbing_transcription_report.txt"

Write-Host ""
Write-Host "Status do Git:"
git status --short

Write-Host ""

git commit `
    -m "Add voice transcription pipeline"

git push origin main

Write-Host ""
Write-Host "Ultimo commit:"
git log -1 --oneline

Write-Host ""
Write-Host "============================================="
Write-Host " SCRIPT 19 CONCLUIDO"
Write-Host "============================================="
Write-Host ""