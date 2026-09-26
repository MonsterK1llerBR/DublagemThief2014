#requires -Version 5.1

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host " THIEF 2014 - VOICE CLASSIFICATION CATALOG"
Write-Host " SCRIPT 16 - VERSAO CORRIGIDA"
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# CONFIGURACAO
# ============================================================

$Repo = "B:\DublagemThief2014"
$Lab = "B:\Thief2014_Dubbing"

$ReviewCsv = Join-Path $Repo "Analysis\WEM\voice_review_template.csv"
$GraphCsv = Join-Path $Repo "Analysis\BNK\hirc_object_graph.csv"
$TechnicalCsv = Join-Path $Repo "Analysis\WEM\wem_technical_inventory.csv"

$OutputDir = Join-Path $Lab "Work\VoiceAudition"
$OutputHtml = Join-Path $OutputDir "classification.html"

$VoiceRoot = Join-Path $OutputDir ""

# ============================================================
# VALIDACAO DOS ARQUIVOS
# ============================================================

Write-Host "[1/8] Validando arquivos..." -ForegroundColor Yellow

if (-not (Test-Path -LiteralPath $ReviewCsv)) {
    throw "Arquivo nao encontrado: $ReviewCsv"
}

if (-not (Test-Path -LiteralPath $GraphCsv)) {
    throw "Arquivo nao encontrado: $GraphCsv"
}

if (-not (Test-Path -LiteralPath $TechnicalCsv)) {
    throw "Arquivo nao encontrado: $TechnicalCsv"
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-Host "Review CSV:     OK" -ForegroundColor Green
Write-Host "Graph CSV:       OK" -ForegroundColor Green
Write-Host "Technical CSV:   OK" -ForegroundColor Green
Write-Host "Output:          $OutputHtml" -ForegroundColor Green
Write-Host ""

# ============================================================
# LEITURA DOS CSVs
# ============================================================

Write-Host "[2/8] Lendo dados..." -ForegroundColor Yellow

$ReviewRows = @(Import-Csv -LiteralPath $ReviewCsv)
$GraphRows = @(Import-Csv -LiteralPath $GraphCsv)
$TechnicalRows = @(Import-Csv -LiteralPath $TechnicalCsv)

if ($ReviewRows.Count -eq 0) {
    throw "O voice_review_template.csv nao possui registros."
}

Write-Host "Review:          $($ReviewRows.Count) registros" -ForegroundColor Green
Write-Host "Graph:           $($GraphRows.Count) registros" -ForegroundColor Green
Write-Host "Technical:       $($TechnicalRows.Count) registros" -ForegroundColor Green
Write-Host ""

# ============================================================
# INDICES
# ============================================================

Write-Host "[3/8] Criando indices..." -ForegroundColor Yellow

$GraphByWem = @{}
foreach ($item in $GraphRows) {

    $WemName = [string]$item.WEM

    if ([string]::IsNullOrWhiteSpace($WemName)) {
        continue
    }

    $Key = $WemName.Trim().ToLowerInvariant()

    if (-not $GraphByWem.ContainsKey($Key)) {
        $GraphByWem[$Key] = $item
    }
}

$TechnicalByWem = @{}
foreach ($item in $TechnicalRows) {

    $WemName = [string]$item.WEM

    if ([string]::IsNullOrWhiteSpace($WemName)) {
        continue
    }

    $Key = $WemName.Trim().ToLowerInvariant()

    if (-not $TechnicalByWem.ContainsKey($Key)) {
        $TechnicalByWem[$Key] = $item
    }
}

Write-Host "Graph index:     $($GraphByWem.Count)" -ForegroundColor Green
Write-Host "Technical index: $($TechnicalByWem.Count)" -ForegroundColor Green
Write-Host ""

# ============================================================
# FUNCAO PARA ESCAPAR JSON
# ============================================================

function ConvertTo-SafeJsonString {
    param(
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value) {
        return ""
    }

    return $Value
}

# ============================================================
# MONTAGEM DOS DADOS
# ============================================================

Write-Host "[4/8] Montando catalogo..." -ForegroundColor Yellow

$Data = New-Object System.Collections.Generic.List[object]

$Counter = 0
$AudioCount = 0
$EventCount = 0
$ActionCount = 0
$SoundCount = 0
$SourceCount = 0
$MissingAudio = 0

foreach ($row in $ReviewRows) {

    $Counter++

    # --------------------------------------------------------
    # WEM
    # --------------------------------------------------------

    $Wem = [string]$row.WEM

    if ([string]::IsNullOrWhiteSpace($Wem)) {
        Write-Warning "Registro $Counter sem WEM. Ignorando."
        continue
    }

    $Wem = $Wem.Trim()

    # --------------------------------------------------------
    # INDICE
    # --------------------------------------------------------

    $IndexValue = $Counter

    if ($row.Index) {

        $ParsedIndex = 0

        if ([int]::TryParse(
            ([string]$row.Index).Trim(),
            [ref]$ParsedIndex
        )) {
            $IndexValue = $ParsedIndex
        }
    }

    # --------------------------------------------------------
    # BATCH
    #
    # Nao usamos mais o campo Batch do CSV.
    # O lote e reconstruido diretamente pelo indice.
    # BatchSize = 100
    # --------------------------------------------------------

    $BatchNumber = [int][math]::Floor(($IndexValue - 1) / 100) + 1

    $Batch = "Batch_{0:D3}" -f $BatchNumber

    # --------------------------------------------------------
    # WAV
    #
    # O WAV original do catalogo segue:
    #
    # Batch_001
    #   0001_731766908.wav
    #
    # Portanto reconstruimos diretamente.
    # --------------------------------------------------------

    $WavFileName = "{0:D4}_{1}.wav" -f $IndexValue, `
        ([System.IO.Path]::GetFileNameWithoutExtension($Wem))

    $RelativeAudio = "$Batch/$WavFileName"

    $PhysicalAudio = Join-Path `
        (Join-Path $OutputDir $Batch) `
        $WavFileName

    # --------------------------------------------------------
    # METADADOS HIRC
    # --------------------------------------------------------

    $GraphItem = $null
    $GraphKey = $Wem.ToLowerInvariant()

    if ($GraphByWem.ContainsKey($GraphKey)) {
        $GraphItem = $GraphByWem[$GraphKey]
    }

    # --------------------------------------------------------
    # METADADOS TECNICOS
    # --------------------------------------------------------

    $TechnicalItem = $null

    if ($TechnicalByWem.ContainsKey($GraphKey)) {
        $TechnicalItem = $TechnicalByWem[$GraphKey]
    }

    # --------------------------------------------------------
    # EVENT ID
    # --------------------------------------------------------

    $EventID = ""

    if ($GraphItem -and $GraphItem.EventID) {
        $EventID = [string]$GraphItem.EventID
    }
    elseif ($row.EventID) {
        $EventID = [string]$row.EventID
    }

    if (-not [string]::IsNullOrWhiteSpace($EventID)) {
        $EventCount++
    }

    # --------------------------------------------------------
    # ACTION ID
    # --------------------------------------------------------

    $ActionID = ""

    if ($GraphItem -and $GraphItem.ActionID) {
        $ActionID = [string]$GraphItem.ActionID
    }
    elseif ($row.ActionID) {
        $ActionID = [string]$row.ActionID
    }

    if (-not [string]::IsNullOrWhiteSpace($ActionID)) {
        $ActionCount++
    }

    # --------------------------------------------------------
    # SOUND ID
    # --------------------------------------------------------

    $SoundID = ""

    if ($GraphItem -and $GraphItem.SoundID) {
        $SoundID = [string]$GraphItem.SoundID
    }
    elseif ($row.SoundID) {
        $SoundID = [string]$row.SoundID
    }

    if (-not [string]::IsNullOrWhiteSpace($SoundID)) {
        $SoundCount++
    }

    # --------------------------------------------------------
    # SOURCE ID
    # --------------------------------------------------------

    $SourceID = ""

    if ($GraphItem -and $GraphItem.SourceID) {
        $SourceID = [string]$GraphItem.SourceID
    }
    elseif ($row.SourceID) {
        $SourceID = [string]$row.SourceID
    }
    else {
        $SourceID = [System.IO.Path]::GetFileNameWithoutExtension($Wem)
    }

    if (-not [string]::IsNullOrWhiteSpace($SourceID)) {
        $SourceCount++
    }

    # --------------------------------------------------------
    # DURACAO
    # --------------------------------------------------------

    $Duration = ""

    if ($TechnicalItem -and $TechnicalItem.DurationSec) {
        $Duration = [string]$TechnicalItem.DurationSec
    }
    elseif ($row.DurationSec) {
        $Duration = [string]$row.DurationSec
    }
    elseif ($row.Duration) {
        $Duration = [string]$row.Duration
    }

    # --------------------------------------------------------
    # BITRATE
    # --------------------------------------------------------

    $Bitrate = ""

    if ($TechnicalItem -and $TechnicalItem.Bitrate) {
        $Bitrate = [string]$TechnicalItem.Bitrate
    }
    elseif ($row.BitrateKbps) {
        $Bitrate = [string]$row.BitrateKbps
    }
    elseif ($row.Bitrate) {
        $Bitrate = [string]$row.Bitrate
    }

    if (
        -not [string]::IsNullOrWhiteSpace($Bitrate) -and
        $Bitrate -notmatch "kbps"
    ) {
        $Bitrate = "$Bitrate kbps"
    }

    # --------------------------------------------------------
    # ENCODING
    # --------------------------------------------------------

    $Encoding = ""

    if ($TechnicalItem -and $TechnicalItem.Encoding) {
        $Encoding = [string]$TechnicalItem.Encoding
    }
    elseif ($row.Encoding) {
        $Encoding = [string]$row.Encoding
    }

    # --------------------------------------------------------
    # SAMPLE RATE
    # --------------------------------------------------------

    $SampleRate = ""

    if ($TechnicalItem -and $TechnicalItem.SampleRate) {
        $SampleRate = [string]$TechnicalItem.SampleRate
    }
    elseif ($row.SampleRate) {
        $SampleRate = [string]$row.SampleRate
    }

    if (
        -not [string]::IsNullOrWhiteSpace($SampleRate) -and
        $SampleRate -notmatch "Hz"
    ) {
        $SampleRate = "$SampleRate Hz"
    }

    # --------------------------------------------------------
    # CHANNELS
    # --------------------------------------------------------

    $Channels = ""

    if ($TechnicalItem -and $TechnicalItem.Channels) {
        $Channels = [string]$TechnicalItem.Channels
    }
    elseif ($row.Channels) {
        $Channels = [string]$row.Channels
    }

    # --------------------------------------------------------
    # VERIFICACAO FISICA
    # --------------------------------------------------------

    $Status = "AUDIO_MISSING"

    if (Test-Path -LiteralPath $PhysicalAudio) {
        $AudioCount++
        $Status = "READY"
    }
    else {
        $MissingAudio++
    }

    # --------------------------------------------------------
    # OBJETO
    # --------------------------------------------------------

    $Object = [ordered]@{
        index      = [string]$IndexValue
        batch      = $Batch
        wem        = $Wem
        audio      = $RelativeAudio
        eventID    = $EventID
        actionID   = $ActionID
        soundID    = $SoundID
        sourceID   = $SourceID
        duration   = $Duration
        bitrate    = $Bitrate
        encoding   = $Encoding
        sampleRate = $SampleRate
        channels   = $Channels
        status     = $Status
    }

    $Data.Add($Object)
}

Write-Host "Registros:       $($Data.Count)" -ForegroundColor Green
Write-Host "Audios validos:  $AudioCount" -ForegroundColor Green
Write-Host "Audios ausentes: $MissingAudio" -ForegroundColor $(if ($MissingAudio -eq 0) { "Green" } else { "Yellow" })
Write-Host "EventID:         $EventCount" -ForegroundColor Green
Write-Host "ActionID:        $ActionCount" -ForegroundColor Green
Write-Host "SoundID:         $SoundCount" -ForegroundColor Green
Write-Host "SourceID:        $SourceCount" -ForegroundColor Green
Write-Host ""

# ============================================================
# VALIDACAO DO PRIMEIRO REGISTRO
# ============================================================

Write-Host "[5/8] Validando primeiro registro..." -ForegroundColor Yellow

if ($Data.Count -eq 0) {
    throw "Nenhum registro foi criado."
}

$First = $Data[0]

Write-Host ""
Write-Host "Primeiro registro:" -ForegroundColor Cyan
Write-Host "  Index:      $($First.index)"
Write-Host "  Batch:      $($First.batch)"
Write-Host "  WEM:        $($First.wem)"
Write-Host "  Audio:      $($First.audio)"
Write-Host "  EventID:    $($First.eventID)"
Write-Host "  ActionID:   $($First.actionID)"
Write-Host "  SoundID:    $($First.soundID)"
Write-Host "  SourceID:   $($First.sourceID)"
Write-Host "  Duration:   $($First.duration)"
Write-Host "  Bitrate:    $($First.bitrate)"
Write-Host "  Encoding:   $($First.encoding)"
Write-Host "  SampleRate: $($First.sampleRate)"
Write-Host "  Channels:   $($First.channels)"
Write-Host "  Status:     $($First.status)"
Write-Host ""

if ([string]::IsNullOrWhiteSpace($First.audio)) {
    throw "ERRO: o primeiro registro possui audio vazio."
}

if ([string]::IsNullOrWhiteSpace($First.batch)) {
    throw "ERRO: o primeiro registro possui batch vazio."
}

$FirstPhysical = Join-Path $OutputDir `
    ($First.audio -replace "/", "\")

Write-Host "Arquivo fisico esperado:" -ForegroundColor Cyan
Write-Host "  $FirstPhysical"

if (Test-Path -LiteralPath $FirstPhysical) {
    Write-Host "  ARQUIVO EXISTE: SIM" -ForegroundColor Green
}
else {
    Write-Warning "ARQUIVO EXISTE: NAO"
}

Write-Host ""

# ============================================================
# JSON
# ============================================================

Write-Host "[6/8] Gerando JSON..." -ForegroundColor Yellow

$Json = $Data | ConvertTo-Json -Depth 10 -Compress

if ([string]::IsNullOrWhiteSpace($Json)) {
    throw "Falha ao gerar JSON."
}

if ($Json -notmatch "Batch_001") {
    throw "ERRO CRITICO: JSON nao contem Batch_001."
}

if ($Json -notmatch "0001_731766908\.wav") {
    throw "ERRO CRITICO: JSON nao contem o primeiro WAV esperado."
}

Write-Host "JSON gerado." -ForegroundColor Green
Write-Host "Tamanho: $($Json.Length) caracteres" -ForegroundColor Green
Write-Host ""

# ============================================================
# HTML
# ============================================================

Write-Host "[7/8] Gerando HTML..." -ForegroundColor Yellow

$Html = @"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<title>Thief 2014 - Voice Classification</title>

<style>

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    padding: 0;
    background: #111;
    color: #eee;
    font-family: Arial, Helvetica, sans-serif;
}

header {
    position: sticky;
    top: 0;
    z-index: 1000;

    background: #181818;
    border-bottom: 1px solid #333;

    padding: 15px 20px;
}

h1 {
    margin: 0 0 10px 0;
    font-size: 22px;
}

#toolbar {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    align-items: center;
}

button {
    cursor: pointer;
    pointer-events: auto;

    border: 1px solid #555;
    border-radius: 5px;

    background: #2a2a2a;
    color: #fff;

    padding: 7px 11px;
    font-size: 13px;
}

button:hover {
    background: #3a3a3a;
}

button.active {
    background: #555;
}

button.class-speech.active {
    background: #2e7d32;
}

button.class-shout.active {
    background: #b71c1c;
}

button.class-vocal.active {
    background: #6a1b9a;
}

button.class-effect.active {
    background: #1565c0;
}

button.class-discard.active {
    background: #424242;
}

#counter {
    margin-left: 10px;
    font-size: 13px;
    color: #aaa;
}

#app {
    padding: 20px;
}

.card {
    border: 1px solid #333;
    border-radius: 8px;

    background: #181818;

    margin-bottom: 14px;
    padding: 14px;
}

.card.selected {
    border-color: #777;
}

.card-header {
    display: flex;
    justify-content: space-between;
    gap: 15px;

    margin-bottom: 10px;
}

.card-title {
    font-weight: bold;
    font-size: 15px;
}

.card-meta {
    color: #999;
    font-size: 12px;
    line-height: 1.6;
}

audio {
    display: block;
    width: 100%;
    margin: 10px 0;
}

.classification-buttons {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    margin-top: 10px;
}

textarea,
input {
    width: 100%;

    background: #101010;
    color: #eee;

    border: 1px solid #444;
    border-radius: 5px;

    padding: 8px;

    margin-top: 7px;
}

textarea {
    min-height: 55px;
    resize: vertical;
}

.status {
    margin-top: 8px;
    font-size: 12px;
    color: #888;
}

.status.ready {
    color: #81c784;
}

.status.missing {
    color: #e57373;
}

</style>
</head>

<body>

<header>

<h1>Thief 2014 - Voice Classification</h1>

<div id="toolbar">

<button id="prevButton">◀ Anterior</button>
<button id="nextButton">Próximo ▶</button>

<button id="filterPending">Pendentes</button>
<button id="filterAll">Todos</button>

<button id="exportButton">Exportar CSV</button>
<button id="clearButton">Limpar classificações</button>

<span id="counter"></span>

</div>

</header>

<main id="app"></main>

<script>

const DATA = $Json;

const STORAGE_KEY = "thief2014_voice_classification_v4";

let state = {
    current: 0,
    filter: "all",
    classifications: {}
};

try {

    const saved = localStorage.getItem(STORAGE_KEY);

    if (saved) {
        state.classifications = JSON.parse(saved);
    }

} catch (error) {

    console.error("Erro ao carregar localStorage:", error);

}

function saveState() {

    try {

        localStorage.setItem(
            STORAGE_KEY,
            JSON.stringify(state.classifications)
        );

    } catch (error) {

        console.error("Erro ao salvar classificacoes:", error);

    }

}

function getClassification(index) {

    return state.classifications[index] || {
        classification: "PENDENTE",
        character: "",
        transcript: "",
        notes: ""
    };

}

function setClassification(index, classification) {

    const current = getClassification(index);

    current.classification = classification;

    state.classifications[index] = current;

    saveState();

    render();

}

function updateField(index, field, value) {

    const current = getClassification(index);

    current[field] = value;

    state.classifications[index] = current;

    saveState();

}

function filteredData() {

    if (state.filter === "pending") {

        return DATA.filter(function(row) {

            const item = getClassification(row.index);

            return item.classification === "PENDENTE";

        });

    }

    return DATA;

}

function escapeHtml(value) {

    if (value === null || value === undefined) {
        return "";
    }

    return String(value)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");

}

function createButton(row, label, className) {

    const button = document.createElement("button");

    button.textContent = label;

    button.className = className || "";

    button.type = "button";

    button.addEventListener("click", function(event) {

        event.preventDefault();
        event.stopPropagation();

        setClassification(
            row.index,
            label.toUpperCase()
        );

    });

    return button;

}

function createCard(row) {

    const card = document.createElement("section");

    card.className = "card";

    const classification = getClassification(row.index);

    if (classification.classification !== "PENDENTE") {
        card.classList.add("selected");
    }

    const header = document.createElement("div");

    header.className = "card-header";

    const title = document.createElement("div");

    title.className = "card-title";

    title.textContent =
        "#" + row.index +
        " | " +
        row.wem;

    const meta = document.createElement("div");

    meta.className = "card-meta";

    meta.innerHTML =
        "Batch: " + escapeHtml(row.batch) +
        "<br>" +
        "EventID: " + escapeHtml(row.eventID) +
        "<br>" +
        "ActionID: " + escapeHtml(row.actionID) +
        "<br>" +
        "SoundID: " + escapeHtml(row.soundID) +
        "<br>" +
        "SourceID: " + escapeHtml(row.sourceID) +
        "<br>" +
        "Duration: " + escapeHtml(row.duration) +
        "<br>" +
        "Bitrate: " + escapeHtml(row.bitrate) +
        "<br>" +
        "Encoding: " + escapeHtml(row.encoding) +
        "<br>" +
        "Sample Rate: " + escapeHtml(row.sampleRate) +
        "<br>" +
        "Channels: " + escapeHtml(row.channels);

    header.appendChild(title);
    header.appendChild(meta);

    card.appendChild(header);

    const audio = document.createElement("audio");

    audio.controls = true;
    audio.preload = "none";

    /*
        IMPORTANTE:
        O caminho vem diretamente do JSON gerado pelo PowerShell.

        Exemplo:
        Batch_001/0001_731766908.wav
    */

    audio.src = String(row.audio || "").replace(/\\/g, "/");

    card.appendChild(audio);

    const status = document.createElement("div");

    status.className = "status";

    if (row.status === "READY") {

        status.classList.add("ready");

        status.textContent =
            "Áudio pronto: " + row.audio;

    } else {

        status.classList.add("missing");

        status.textContent =
            "Áudio não encontrado: " + row.audio;

    }

    card.appendChild(status);

    const buttons = document.createElement("div");

    buttons.className = "classification-buttons";

    const speech = createButton(
        row,
        "FALA",
        "class-speech"
    );

    const shout = createButton(
        row,
        "GRITO",
        "class-shout"
    );

    const vocal = createButton(
        row,
        "VOCALIZAÇÃO",
        "class-vocal"
    );

    const effect = createButton(
        row,
        "EFEITO",
        "class-effect"
    );

    const discard = createButton(
        row,
        "DESCARTAR",
        "class-discard"
    );

    buttons.appendChild(speech);
    buttons.appendChild(shout);
    buttons.appendChild(vocal);
    buttons.appendChild(effect);
    buttons.appendChild(discard);

    card.appendChild(buttons);

    const character = document.createElement("input");

    character.type = "text";

    character.placeholder = "Personagem";

    character.value = classification.character || "";

    character.addEventListener("input", function() {

        updateField(
            row.index,
            "character",
            character.value
        );

    });

    card.appendChild(character);

    const transcript = document.createElement("textarea");

    transcript.placeholder =
        "Transcrição / texto original";

    transcript.value =
        classification.transcript || "";

    transcript.addEventListener("input", function() {

        updateField(
            row.index,
            "transcript",
            transcript.value
        );

    });

    card.appendChild(transcript);

    const notes = document.createElement("textarea");

    notes.placeholder =
        "Observações";

    notes.value =
        classification.notes || "";

    notes.addEventListener("input", function() {

        updateField(
            row.index,
            "notes",
            notes.value
        );

    });

    card.appendChild(notes);

    return card;

}

function render() {

    const app = document.getElementById("app");

    app.innerHTML = "";

    const rows = filteredData();

    rows.forEach(function(row) {

        app.appendChild(
            createCard(row)
        );

    });

    const classified = Object.values(
        state.classifications
    ).filter(function(item) {

        return item.classification &&
            item.classification !== "PENDENTE";

    }).length;

    document.getElementById("counter").textContent =
        "Registros: " +
        DATA.length +
        " | Classificados: " +
        classified +
        " | Exibindo: " +
        rows.length;

}

function nextPending() {

    const rows = filteredData();

    if (rows.length === 0) {
        return;
    }

    const cards =
        document.querySelectorAll(".card");

    if (cards.length === 0) {
        return;
    }

    cards[0].scrollIntoView({
        behavior: "smooth",
        block: "center"
    });

}

function exportCSV() {

    const lines = [];

    lines.push([
        "Index",
        "Batch",
        "WEM",
        "Audio",
        "EventID",
        "ActionID",
        "SoundID",
        "SourceID",
        "Duration",
        "Bitrate",
        "Encoding",
        "SampleRate",
        "Channels",
        "Classification",
        "Character",
        "Transcript",
        "Notes"
    ].join(","));

    DATA.forEach(function(row) {

        const item =
            getClassification(row.index);

        const values = [
            row.index,
            row.batch,
            row.wem,
            row.audio,
            row.eventID,
            row.actionID,
            row.soundID,
            row.sourceID,
            row.duration,
            row.bitrate,
            row.encoding,
            row.sampleRate,
            row.channels,
            item.classification,
            item.character,
            item.transcript,
            item.notes
        ];

        const escaped = values.map(function(value) {

            return '"' +
                String(value ?? "")
                    .replace(/"/g, '""') +
                '"';

        });

        lines.push(
            escaped.join(",")
        );

    });

    const blob = new Blob(
        [lines.join("\\r\\n")],
        {
            type: "text/csv;charset=utf-8"
        }
    );

    const url =
        URL.createObjectURL(blob);

    const a =
        document.createElement("a");

    a.href = url;

    a.download =
        "thief2014_voice_classification.csv";

    document.body.appendChild(a);

    a.click();

    a.remove();

    URL.revokeObjectURL(url);

}

document
    .getElementById("filterPending")
    .addEventListener("click", function() {

        state.filter = "pending";

        render();

    });

document
    .getElementById("filterAll")
    .addEventListener("click", function() {

        state.filter = "all";

        render();

    });

document
    .getElementById("exportButton")
    .addEventListener("click", function() {

        exportCSV();

    });

document
    .getElementById("clearButton")
    .addEventListener("click", function() {

        const confirmed =
            confirm(
                "Tem certeza que deseja apagar todas as classificações salvas?"
            );

        if (!confirmed) {
            return;
        }

        state.classifications = {};

        localStorage.removeItem(
            STORAGE_KEY
        );

        render();

    });

document
    .getElementById("nextButton")
    .addEventListener("click", function() {

        nextPending();

    });

document
    .getElementById("prevButton")
    .addEventListener("click", function() {

        window.scrollTo({
            top: 0,
            behavior: "smooth"
        });

    });

document.addEventListener(
    "keydown",
    function(event) {

        /*
            Ignora atalhos quando o usuario
            esta digitando em um campo.
        */

        const tag =
            event.target.tagName.toLowerCase();

        if (
            tag === "input" ||
            tag === "textarea"
        ) {
            return;
        }

        const firstVisible =
            filteredData()[0];

        if (!firstVisible) {
            return;
        }

        switch (event.key.toLowerCase()) {

            case "1":
                setClassification(
                    firstVisible.index,
                    "FALA"
                );
                break;

            case "2":
                setClassification(
                    firstVisible.index,
                    "GRITO"
                );
                break;

            case "3":
                setClassification(
                    firstVisible.index,
                    "VOCALIZAÇÃO"
                );
                break;

            case "4":
                setClassification(
                    firstVisible.index,
                    "EFEITO"
                );
                break;

            case "5":
                setClassification(
                    firstVisible.index,
                    "DESCARTAR"
                );
                break;

        }

    }
);

/*
    Inicializacao
*/

console.log(
    "THIEF CLASSIFICATION CATALOG"
);

console.log(
    "DATA quantidade:",
    DATA.length
);

console.log(
    "Primeiro registro:",
    DATA[0]
);

console.log(
    "Primeiro audio:",
    DATA[0] ? DATA[0].audio : null
);

render();

</script>

</body>
</html>
"@

# ============================================================
# SALVAR HTML
# ============================================================

$Html | Set-Content `
    -LiteralPath $OutputHtml `
    -Encoding UTF8

Write-Host "HTML salvo:" -ForegroundColor Green
Write-Host $OutputHtml
Write-Host ""

# ============================================================
# VALIDACAO DO HTML GERADO
# ============================================================

Write-Host "[8/8] Validando HTML..." -ForegroundColor Yellow

$GeneratedHtml = Get-Content `
    -LiteralPath $OutputHtml `
    -Raw

$Checks = @(
    @{
        Name = "DATA existe"
        Pattern = "const DATA ="
    },
    @{
        Name = "Batch_001"
        Pattern = "Batch_001"
    },
    @{
        Name = "Primeiro WAV"
        Pattern = "0001_731766908\.wav"
    },
    @{
        Name = "audio.src"
        Pattern = "audio\.src"
    },
    @{
        Name = "createCard"
        Pattern = "function createCard"
    },
    @{
        Name = "FALA"
        Pattern = "FALA"
    },
    @{
        Name = "GRITO"
        Pattern = "GRITO"
    },
    @{
        Name = "localStorage"
        Pattern = "localStorage"
    }
)

foreach ($Check in $Checks) {

    if ($GeneratedHtml -match $Check.Pattern) {

        Write-Host `
            ("  {0}: OK" -f $Check.Name) `
            -ForegroundColor Green

    }
    else {

        Write-Host `
            ("  {0}: FALHOU" -f $Check.Name) `
            -ForegroundColor Red

    }

}

Write-Host ""

# ============================================================
# EXTRACAO DO PRIMEIRO AUDIO DO HTML
# ============================================================

$FirstAudioMatch = [regex]::Match(
    $GeneratedHtml,
    '0001_731766908\.wav'
)

if ($FirstAudioMatch.Success) {

    Write-Host `
        "Primeiro WAV encontrado no HTML: SIM" `
        -ForegroundColor Green

}
else {

    Write-Host `
        "Primeiro WAV encontrado no HTML: NAO" `
        -ForegroundColor Red

}

# ============================================================
# ABRIR
# ============================================================

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host " CATALOG0 GERADO COM SUCESSO"
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""

Write-Host "HTML:"
Write-Host $OutputHtml
Write-Host ""

Write-Host "Total:"
Write-Host $Data.Count
Write-Host ""

Write-Host "Primeiro audio:"
Write-Host $First.audio
Write-Host ""

Write-Host "Primeiro arquivo fisico:"
Write-Host $FirstPhysical
Write-Host ""

if (Test-Path -LiteralPath $FirstPhysical) {

    Write-Host "ARQUIVO EXISTE: SIM" -ForegroundColor Green

}
else {

    Write-Host "ARQUIVO EXISTE: NAO" -ForegroundColor Red

}

Write-Host ""

Start-Process `
    -FilePath $OutputHtml

Write-Host "Catalogo aberto no navegador." -ForegroundColor Cyan
Write-Host ""