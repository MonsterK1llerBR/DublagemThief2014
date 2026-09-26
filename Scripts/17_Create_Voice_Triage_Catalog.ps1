$ErrorActionPreference = "Stop"

# ============================================================
# THIEF 2014 - SCRIPT 17
# CATALOGO DE TRIAGEM RAPIDA DE VOZES
# ============================================================

$Repo = "B:\DublagemThief2014"
$Lab = "B:\Thief2014_Dubbing"

$InputCsv = Join-Path $Repo "Analysis\WEM\voice_review_template.csv"
$GraphCsv = Join-Path $Repo "Analysis\BNK\hirc_object_graph.csv"
$TechCsv = Join-Path $Repo "Analysis\WEM\wem_technical_inventory.csv"

$OutputDir = Join-Path $Lab "Work\VoiceAudition"
$HtmlPath = Join-Path $OutputDir "triage.html"

$ReportDir = Join-Path $Repo "Analysis\Reports"
$ReportPath = Join-Path $ReportDir "voice_triage_catalog_report.txt"

$ScriptPath = Join-Path $Repo "Scripts\17_Create_Voice_Triage_Catalog.ps1"

Write-Host ""
Write-Host "============================================================"
Write-Host " THIEF 2014 - VOICE TRIAGE CATALOG - SCRIPT 17"
Write-Host "============================================================"
Write-Host ""

# ------------------------------------------------------------
# Validacoes
# ------------------------------------------------------------

if (-not (Test-Path $InputCsv)) {
    throw "CSV de entrada nao encontrado: $InputCsv"
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

if (-not (Test-Path $ReportDir)) {
    New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
}

# ------------------------------------------------------------
# Leitura CSV principal
# ------------------------------------------------------------

$Rows = @(Import-Csv -Path $InputCsv)

if ($Rows.Count -eq 0) {
    throw "Nenhum registro encontrado em $InputCsv"
}

Write-Host "Registros encontrados: $($Rows.Count)"

# ------------------------------------------------------------
# Carrega grafo HIRC para enriquecer metadata
# ------------------------------------------------------------

$GraphByWem = @{}

if (Test-Path $GraphCsv) {

    try {

        $GraphRows = @(Import-Csv -Path $GraphCsv)

        foreach ($g in $GraphRows) {

            $WemName = [string]$g.WEM

            if ([string]::IsNullOrWhiteSpace($WemName)) {
                $WemName = [string]$g.Wem
            }

            if ([string]::IsNullOrWhiteSpace($WemName)) {
                $SourceId = [string]$g.SourceID

                if (-not [string]::IsNullOrWhiteSpace($SourceId)) {
                    $WemName = "$SourceId.wem"
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($WemName)) {

                $Key = [System.IO.Path]::GetFileName($WemName)

                if (-not $GraphByWem.ContainsKey($Key)) {
                    $GraphByWem[$Key] = $g
                }
            }
        }

        Write-Host "Grafo HIRC carregado: $($GraphRows.Count)"

    }
    catch {
        Write-Warning "Nao foi possivel carregar o grafo HIRC."
    }
}

# ------------------------------------------------------------
# Carrega inventario tecnico
# ------------------------------------------------------------

$TechByWem = @{}

if (Test-Path $TechCsv) {

    try {

        $TechRows = @(Import-Csv -Path $TechCsv)

        foreach ($t in $TechRows) {

            $WemName = [string]$t.WEM

            if (-not [string]::IsNullOrWhiteSpace($WemName)) {

                $Key = [System.IO.Path]::GetFileName($WemName)

                if (-not $TechByWem.ContainsKey($Key)) {
                    $TechByWem[$Key] = $t
                }
            }
        }

        Write-Host "Inventario tecnico carregado: $($TechRows.Count)"

    }
    catch {
        Write-Warning "Nao foi possivel carregar o inventario tecnico."
    }
}

# ------------------------------------------------------------
# Construcao dos registros
# ------------------------------------------------------------

$Data = New-Object System.Collections.Generic.List[object]

$Index = 0

foreach ($Row in $Rows) {

    $Index++

    $Wem = [string]$Row.WEM

    if ([string]::IsNullOrWhiteSpace($Wem)) {
        $Wem = [string]$Row.wem
    }

    if ([string]::IsNullOrWhiteSpace($Wem)) {
        continue
    }

    $WemFile = [System.IO.Path]::GetFileName($Wem)
    $WemBase = [System.IO.Path]::GetFileNameWithoutExtension($Wem)

    # --------------------------------------------------------
    # Batch calculado pelo indice original
    # --------------------------------------------------------

    [int]$BatchNumber = [int][math]::Floor(($Index - 1) / 100) + 1

    $Batch = "Batch_{0:D3}" -f $BatchNumber

    # --------------------------------------------------------
    # WAV correspondente
    # --------------------------------------------------------

    $WavFileName = "{0:D4}_{1}.wav" -f $Index, $WemBase

    $RelativeAudio = "$Batch/$WavFileName"

    $PhysicalAudio = Join-Path `
        (Join-Path $OutputDir $Batch) `
        $WavFileName

    # --------------------------------------------------------
    # Metadata
    # --------------------------------------------------------

    $EventID = ""
    $ActionID = ""
    $SoundID = ""
    $SourceID = $WemBase

    $Duration = ""
    $Bitrate = ""
    $Encoding = ""
    $SampleRate = ""
    $Channels = ""

    if ($GraphByWem.ContainsKey($WemFile)) {

        $g = $GraphByWem[$WemFile]

        $EventID = [string]$g.EventID
        $ActionID = [string]$g.ActionID
        $SoundID = [string]$g.SoundID

        if (-not [string]::IsNullOrWhiteSpace([string]$g.SourceID)) {
            $SourceID = [string]$g.SourceID
        }
    }

    if ($TechByWem.ContainsKey($WemFile)) {

        $t = $TechByWem[$WemFile]

        $Duration = [string]$t.DurationSec
        $Bitrate = [string]$t.Bitrate
        $Encoding = [string]$t.Encoding
        $SampleRate = [string]$t.SampleRate
        $Channels = [string]$t.Channels
    }

    $Exists = Test-Path $PhysicalAudio

    $Data.Add([ordered]@{
        index = $Index
        batch = $Batch
        wem = $WemFile
        audio = $RelativeAudio
        eventID = $EventID
        actionID = $ActionID
        soundID = $SoundID
        sourceID = $SourceID
        duration = $Duration
        bitrate = $Bitrate
        encoding = $Encoding
        sampleRate = $SampleRate
        channels = $Channels
        audioExists = $Exists
    })
}

Write-Host "Registros preparados: $($Data.Count)"

# ------------------------------------------------------------
# JSON
# ------------------------------------------------------------

$Json = $Data | ConvertTo-Json -Depth 5 -Compress

# ------------------------------------------------------------
# HTML
# ------------------------------------------------------------

$Html = @"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">

<title>Thief 2014 - Voice Triage</title>

<style>

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    padding: 0;
    background: #101114;
    color: #eeeeee;
    font-family: Arial, Helvetica, sans-serif;
}

header {
    position: sticky;
    top: 0;
    z-index: 50;

    background: #181a1f;
    border-bottom: 1px solid #30343c;

    padding: 16px 20px;
}

h1 {
    margin: 0 0 8px 0;
    font-size: 22px;
}

.subtitle {
    color: #9ca3af;
    font-size: 13px;
}

.progress-container {
    margin-top: 14px;
}

.progress-text {
    font-size: 14px;
    margin-bottom: 6px;
}

.progress-bar {
    width: 100%;
    height: 10px;
    background: #292d35;
    border-radius: 5px;
    overflow: hidden;
}

.progress-fill {
    width: 0%;
    height: 100%;
    background: #7dd3fc;
    transition: width 0.15s;
}

.stats {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 12px;
}

.stat {
    padding: 7px 10px;
    background: #22252c;
    border: 1px solid #343842;
    border-radius: 5px;
    font-size: 12px;
}

.controls {
    margin-top: 14px;

    display: flex;
    flex-wrap: wrap;
    gap: 8px;
}

button {
    border: 1px solid #454b56;
    background: #242830;
    color: #ffffff;

    padding: 9px 13px;
    border-radius: 5px;

    cursor: pointer;

    font-size: 13px;
}

button:hover {
    background: #303640;
}

button:active {
    transform: translateY(1px);
}

button.primary {
    background: #31566a;
}

button.danger {
    background: #542f35;
}

main {
    max-width: 1050px;
    margin: 0 auto;
    padding: 20px;
}

.card {
    background: #181a1f;
    border: 1px solid #30343c;
    border-radius: 8px;

    padding: 20px;

    box-shadow: 0 8px 30px rgba(0,0,0,.25);
}

.audio-number {
    color: #7dd3fc;
    font-size: 13px;
    margin-bottom: 5px;
}

.wem {
    font-size: 20px;
    font-weight: bold;
}

.metadata {
    margin-top: 15px;

    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));

    gap: 8px;
}

.meta {
    background: #22252c;
    padding: 9px;
    border-radius: 5px;
}

.meta-label {
    color: #9ca3af;
    font-size: 11px;
}

.meta-value {
    margin-top: 3px;
    font-size: 13px;
}

audio {
    width: 100%;
    margin-top: 20px;
}

.classification {
    margin-top: 20px;

    display: grid;
    grid-template-columns: repeat(5, 1fr);

    gap: 8px;
}

.classification button {
    padding: 13px 8px;
    font-weight: bold;
}

.classification button.selected {
    outline: 3px solid #7dd3fc;
    background: #31566a;
}

.form {
    margin-top: 20px;
}

.form label {
    display: block;
    margin-bottom: 5px;
    color: #b8bec8;
    font-size: 12px;
}

.form input,
.form textarea {
    width: 100%;

    background: #101114;
    color: #eeeeee;

    border: 1px solid #383d47;
    border-radius: 5px;

    padding: 10px;

    margin-bottom: 12px;
}

.form textarea {
    min-height: 90px;
    resize: vertical;
}

.navigation {
    margin-top: 20px;

    display: flex;
    justify-content: space-between;
    gap: 10px;
}

.navigation button {
    flex: 1;
}

.hint {
    margin-top: 15px;

    color: #8f96a3;
    font-size: 12px;
    line-height: 1.6;
}

.saved {
    margin-top: 10px;

    color: #86efac;
    font-size: 12px;

    min-height: 16px;
}

@media (max-width: 700px) {

    .classification {
        grid-template-columns: 1fr 1fr;
    }

}

</style>
</head>

<body>

<header>

    <h1>THIEF 2014 • TRIAGEM DE VOZES</h1>

    <div class="subtitle">
        Classificação rápida das amostras WEM
    </div>

    <div class="progress-container">

        <div class="progress-text" id="progressText">
            0 / 0
        </div>

        <div class="progress-bar">
            <div class="progress-fill" id="progressFill"></div>
        </div>

    </div>

    <div class="stats">

        <div class="stat">
            FALA:
            <strong id="countFala">0</strong>
        </div>

        <div class="stat">
            GRITO:
            <strong id="countGrito">0</strong>
        </div>

        <div class="stat">
            VOCALIZAÇÃO:
            <strong id="countVocalizacao">0</strong>
        </div>

        <div class="stat">
            EFEITO:
            <strong id="countEfeito">0</strong>
        </div>

        <div class="stat">
            DESCARTAR:
            <strong id="countDescartar">0</strong>
        </div>

        <div class="stat">
            PENDENTE:
            <strong id="countPendente">0</strong>
        </div>

    </div>

    <div class="controls">

        <button onclick="playCurrent()">
            ▶ Reproduzir
        </button>

        <button onclick="previousAudio()">
            ← Anterior
        </button>

        <button onclick="nextAudio()">
            Próximo →
        </button>

        <button class="primary" onclick="exportCSV()">
            Exportar CSV
        </button>

        <button onclick="clearCurrent()">
            Limpar classificação
        </button>

    </div>

</header>

<main>

    <div class="card">

        <div class="audio-number" id="audioNumber">
            Áudio 1
        </div>

        <div class="wem" id="wemName">
            -
        </div>

        <audio id="player" controls preload="auto"></audio>

        <div class="classification">

            <button type="button"
                    data-classification="FALA"
                    onclick="classify('FALA')">
                1 • FALA
            </button>

            <button type="button"
                    data-classification="GRITO"
                    onclick="classify('GRITO')">
                2 • GRITO
            </button>

            <button type="button"
                    data-classification="VOCALIZAÇÃO"
                    onclick="classify('VOCALIZAÇÃO')">
                3 • VOCALIZAÇÃO
            </button>

            <button type="button"
                    data-classification="EFEITO"
                    onclick="classify('EFEITO')">
                4 • EFEITO
            </button>

            <button type="button"
                    data-classification="DESCARTAR"
                    onclick="classify('DESCARTAR')">
                5 • DESCARTAR
            </button>

        </div>

        <div class="form">

            <label>Personagem</label>

            <input
                id="character"
                type="text"
                placeholder="Opcional nesta etapa"
                oninput="updateField('character', this.value)"
            >

            <label>Transcrição</label>

            <textarea
                id="transcript"
                placeholder="Opcional nesta etapa"
                oninput="updateField('transcript', this.value)"
            ></textarea>

            <label>Observações</label>

            <textarea
                id="notes"
                placeholder="Opcional"
                oninput="updateField('notes', this.value)"
            ></textarea>

        </div>

        <div class="saved" id="savedMessage"></div>

        <div class="navigation">

            <button type="button" onclick="previousAudio()">
                ← ANTERIOR
            </button>

            <button type="button" class="primary" onclick="nextAudio()">
                PRÓXIMO →
            </button>

        </div>

        <div class="hint">

            <strong>Atalhos:</strong><br>

            1 = FALA |
            2 = GRITO |
            3 = VOCALIZAÇÃO |
            4 = EFEITO |
            5 = DESCARTAR |
            P = PENDENTE<br>

            Espaço = reproduzir/pausar |
            ← = anterior |
            → = próximo

        </div>

    </div>

</main>

<script>

const DATA = $Json;

const STORAGE_KEY = "thief2014_voice_triage_v1";

let currentIndex = 0;

let state = {};


// ============================================================
// STORAGE
// ============================================================

function loadState() {

    try {

        const raw = localStorage.getItem(STORAGE_KEY);

        if (raw) {
            state = JSON.parse(raw);
        }

    } catch (error) {

        console.error("Erro ao carregar classificacoes:", error);

        state = {};

    }

}


function saveState() {

    localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify(state)
    );

}


// ============================================================
// CURRENT RECORD
// ============================================================

function getCurrentRecord() {

    return DATA[currentIndex];

}


function getCurrentState() {

    const record = getCurrentRecord();

    if (!record) {
        return {};
    }

    const key = String(record.index);

    if (!state[key]) {

        state[key] = {

            classification: "PENDENTE",

            character: "",

            transcript: "",

            notes: ""

        };

    }

    return state[key];

}


// ============================================================
// RENDER
// ============================================================

function render() {

    const record = getCurrentRecord();

    if (!record) {
        return;
    }

    const current = getCurrentState();

    document.getElementById("audioNumber").textContent =
        "Áudio " +
        record.index +
        " / " +
        DATA.length;

    document.getElementById("wemName").textContent =
        record.wem;

    const player =
        document.getElementById("player");

    player.src = record.audio;

    document.getElementById("character").value =
        current.character || "";

    document.getElementById("transcript").value =
        current.transcript || "";

    document.getElementById("notes").value =
        current.notes || "";

    document.querySelectorAll(
        ".classification button"
    ).forEach(button => {

        button.classList.toggle(
            "selected",
            button.dataset.classification ===
            current.classification
        );

    });

    updateProgress();

    document.getElementById(
        "savedMessage"
    ).textContent =
        current.classification === "PENDENTE"
            ? ""
            : "✓ Classificação salva";

}


function updateProgress() {

    let classified = 0;

    const counts = {

        FALA: 0,
        GRITO: 0,
        "VOCALIZAÇÃO": 0,
        EFEITO: 0,
        DESCARTAR: 0,
        PENDENTE: 0

    };


    DATA.forEach(record => {

        const item =
            state[String(record.index)];

        const classification =
            item?.classification ||
            "PENDENTE";

        if (classification !== "PENDENTE") {
            classified++;
        }

        if (counts[classification] !== undefined) {
            counts[classification]++;
        }

    });


    const total = DATA.length;

    const percent =
        total > 0
            ? (classified / total) * 100
            : 0;


    document.getElementById(
        "progressText"
    ).textContent =
        classified +
        " classificados / " +
        total +
        " (" +
        percent.toFixed(1) +
        "%)";


    document.getElementById(
        "progressFill"
    ).style.width =
        percent + "%";


    document.getElementById(
        "countFala"
    ).textContent =
        counts.FALA;


    document.getElementById(
        "countGrito"
    ).textContent =
        counts.GRITO;


    document.getElementById(
        "countVocalizacao"
    ).textContent =
        counts["VOCALIZAÇÃO"];


    document.getElementById(
        "countEfeito"
    ).textContent =
        counts.EFEITO;


    document.getElementById(
        "countDescartar"
    ).textContent =
        counts.DESCARTAR;


    document.getElementById(
        "countPendente"
    ).textContent =
        counts.PENDENTE;

}


// ============================================================
// CLASSIFICATION
// ============================================================

function classify(value) {

    const current =
        getCurrentState();

    current.classification =
        value;

    saveState();

    render();

    setTimeout(() => {

        nextAudio();

    }, 100);

}


// ============================================================
// FIELD UPDATE
// ============================================================

function updateField(field, value) {

    const current =
        getCurrentState();

    current[field] =
        value;

    saveState();

    updateProgress();

}


// ============================================================
// NAVIGATION
// ============================================================

function nextAudio() {

    if (currentIndex < DATA.length - 1) {

        currentIndex++;

        render();

        window.scrollTo({
            top: 0,
            behavior: "instant"
        });

    }

}


function previousAudio() {

    if (currentIndex > 0) {

        currentIndex--;

        render();

        window.scrollTo({
            top: 0,
            behavior: "instant"
        });

    }

}


// ============================================================
// PLAYER
// ============================================================

function playCurrent() {

    const player =
        document.getElementById("player");

    if (player.paused) {

        player.play();

    } else {

        player.pause();

    }

}


// ============================================================
// CLEAR
// ============================================================

function clearCurrent() {

    const record =
        getCurrentRecord();

    if (!record) {
        return;
    }

    state[String(record.index)] = {

        classification: "PENDENTE",

        character: "",

        transcript: "",

        notes: ""

    };

    saveState();

    render();

}


// ============================================================
// CSV
// ============================================================

function csvEscape(value) {

    if (value === null ||
        value === undefined) {

        return "";

    }

    const text =
        String(value);

    return '"' +
        text.replace(/"/g, '""') +
        '"';

}


function exportCSV() {

    const headers = [

        "Index",
        "Batch",
        "WEM",
        "Audio",
        "EventID",
        "ActionID",
        "SoundID",
        "SourceID",
        "DurationSec",
        "Bitrate",
        "Encoding",
        "SampleRate",
        "Channels",
        "Classification",
        "Character",
        "Transcript",
        "Notes"

    ];


    const lines = [];

    lines.push(
        headers.map(csvEscape).join(",")
    );


    DATA.forEach(record => {

        const item =
            state[String(record.index)] ||
            {

                classification: "PENDENTE",
                character: "",
                transcript: "",
                notes: ""

            };


        const row = [

            record.index,
            record.batch,
            record.wem,
            record.audio,
            record.eventID,
            record.actionID,
            record.soundID,
            record.sourceID,
            record.duration,
            record.bitrate,
            record.encoding,
            record.sampleRate,
            record.channels,
            item.classification,
            item.character,
            item.transcript,
            item.notes

        ];


        lines.push(
            row.map(csvEscape).join(",")
        );

    });


    const blob =
        new Blob(
            [
                "\uFEFF" +
                lines.join("\r\n")
            ],
            {
                type:
                    "text/csv;charset=utf-8;"
            }
        );


    const url =
        URL.createObjectURL(blob);


    const a =
        document.createElement("a");


    const now =
        new Date()
            .toISOString()
            .replace(/[:.]/g, "-");


    a.href = url;

    a.download =
        "thief2014_voice_triage_" +
        now +
        ".csv";


    document.body.appendChild(a);

    a.click();

    a.remove();

    URL.revokeObjectURL(url);

}


// ============================================================
// KEYBOARD
// ============================================================

document.addEventListener(
    "keydown",
    function(event) {

        const tag =
            document.activeElement?.tagName;

        const typing =
            tag === "INPUT" ||
            tag === "TEXTAREA";


        if (typing) {
            return;
        }


        if (event.code === "Space") {

            event.preventDefault();

            playCurrent();

            return;

        }


        if (event.key === "ArrowRight") {

            event.preventDefault();

            nextAudio();

            return;

        }


        if (event.key === "ArrowLeft") {

            event.preventDefault();

            previousAudio();

            return;

        }


        switch (
            event.key.toLowerCase()
        ) {

            case "1":
                classify("FALA");
                break;

            case "2":
                classify("GRITO");
                break;

            case "3":
                classify("VOCALIZAÇÃO");
                break;

            case "4":
                classify("EFEITO");
                break;

            case "5":
                classify("DESCARTAR");
                break;

            case "p":
                classify("PENDENTE");
                break;

        }

    }
);


// ============================================================
// START
// ============================================================

loadState();

render();

</script>

</body>
</html>
"@

# ------------------------------------------------------------
# Grava HTML
# ------------------------------------------------------------

Set-Content `
    -Path $HtmlPath `
    -Value $Html `
    -Encoding UTF8

# ------------------------------------------------------------
# Relatorio
# ------------------------------------------------------------

$ExistingAudio = @(
    $Data |
    Where-Object {
        $_.audioExists -eq $true
    }
).Count

$MissingAudio = $Data.Count - $ExistingAudio

$Report = @"
THIEF 2014 - VOICE TRIAGE CATALOG
=================================

Script:
17_Create_Voice_Triage_Catalog.ps1

Data:
$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Registros:
$($Data.Count)

WAV existentes:
$ExistingAudio

WAV ausentes:
$MissingAudio

HTML:
$HtmlPath

Storage key:
thief2014_voice_triage_v1

Atalhos:
1 = FALA
2 = GRITO
3 = VOCALIZAÇÃO
4 = EFEITO
5 = DESCARTAR
P = PENDENTE
Espaço = reproduzir/pausar
Seta esquerda = anterior
Seta direita = próximo

Fonte principal da ordem:
voice_review_template.csv

HIRC:
Somente enriquecimento de metadata.

Inventario tecnico:
Somente enriquecimento de metadata.

Nenhum WEM original foi modificado.
Nenhum arquivo da instalação Steam foi modificado.
"@

Set-Content `
    -Path $ReportPath `
    -Value $Report `
    -Encoding UTF8

# ------------------------------------------------------------
# Validacao
# ------------------------------------------------------------

Write-Host ""
Write-Host "VALIDACAO"
Write-Host "---------"

if (-not (Test-Path $HtmlPath)) {
    throw "HTML nao foi criado."
}

$HtmlCheck = Get-Content `
    -Path $HtmlPath `
    -Raw

if ($HtmlCheck -notmatch "Batch_001/0001_731766908.wav") {
    Write-Warning "Primeiro WAV esperado nao encontrado no HTML."
}
else {
    Write-Host "Primeiro WAV: OK"
}

if ($HtmlCheck -notmatch "const DATA =") {
    throw "DATA nao encontrada no HTML."
}

if ($HtmlCheck -notmatch "thief2014_voice_triage_v1") {
    throw "Storage key nao encontrada."
}

if ($HtmlCheck -notmatch "function exportCSV") {
    throw "Funcao exportCSV nao encontrada."
}

if ($HtmlCheck -notmatch "function classify") {
    throw "Funcao classify nao encontrada."
}

if ($HtmlCheck -notmatch "ArrowRight") {
    throw "Navegacao por teclado nao encontrada."
}

Write-Host "DATA: OK"
Write-Host "localStorage: OK"
Write-Host "classificacao: OK"
Write-Host "exportacao CSV: OK"
Write-Host "atalhos: OK"

# ------------------------------------------------------------
# Abre catalogo
# ------------------------------------------------------------

Write-Host ""
Write-Host "VOICE TRIAGE CATALOG 17 CONCLUIDO"
Write-Host ""
Write-Host "HTML:"
Write-Host $HtmlPath
Write-Host ""
Write-Host "Registros: $($Data.Count)"
Write-Host "WAV existentes: $ExistingAudio"
Write-Host "WAV ausentes: $MissingAudio"
Write-Host ""

Start-Process $HtmlPath