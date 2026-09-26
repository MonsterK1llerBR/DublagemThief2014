#requires -Version 5.1

<#
============================================================
 THIEF 2014 - TRANSCRIPTION REVIEW
 SCRIPT 20
============================================================

Entrada:
  Analysis\WEM\dubbing_transcription.csv

Audio:
  B:\Thief2014_Dubbing\Work\VoiceAudition

Saida:
  B:\Thief2014_Dubbing\Work\VoiceAudition\TranscriptionReview\
      transcription_review.html

Relatorio:
  Analysis\Reports\dubbing_transcription_review_catalog_report.txt

Objetivo:
  Criar um catalogo HTML para revisar as transcricoes
  geradas pelo Faster-Whisper.

Recursos:
  - Reproducao de audio
  - Transcricao automatica
  - Revisao CORRETA / PARCIAL / INCORRETA / SEM FALA
  - Correcao manual da transcricao
  - Observacoes
  - Filtros
  - Anterior / Proximo
  - Play / Pause
  - Atalhos de teclado
  - Salvamento automatico em localStorage
  - Exportacao CSV
  - Compatibilidade com PowerShell 5.1 / .NET Framework
============================================================
#>

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " THIEF 2014 - TRANSCRIPTION REVIEW - SCRIPT 20" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# CONFIGURACAO
# ============================================================

$RepoRoot = "B:\DublagemThief2014"

$InputCsv = Join-Path `
    $RepoRoot `
    "Analysis\WEM\dubbing_transcription.csv"

$VoiceRoot = "B:\Thief2014_Dubbing\Work\VoiceAudition"

$OutputDir = Join-Path `
    $VoiceRoot `
    "TranscriptionReview"

$OutputHtml = Join-Path `
    $OutputDir `
    "transcription_review.html"

$ReportDir = Join-Path `
    $RepoRoot `
    "Analysis\Reports"

$ReportFile = Join-Path `
    $ReportDir `
    "dubbing_transcription_review_catalog_report.txt"

$LocalStorageKey = "thief2014_transcription_review_v1"

# ============================================================
# VALIDACAO DOS CAMINHOS
# ============================================================

if (-not (Test-Path -LiteralPath $InputCsv)) {
    throw "CSV de transcricao nao encontrado: $InputCsv"
}

if (-not (Test-Path -LiteralPath $VoiceRoot)) {
    throw "Pasta de audio nao encontrada: $VoiceRoot"
}

New-Item `
    -ItemType Directory `
    -Path $OutputDir `
    -Force | Out-Null

New-Item `
    -ItemType Directory `
    -Path $ReportDir `
    -Force | Out-Null

Write-Host "CSV encontrado:" -ForegroundColor Green
Write-Host $InputCsv
Write-Host ""

# ============================================================
# LEITURA DO CSV
# ============================================================

Write-Host "Lendo transcricoes..." -ForegroundColor Yellow

$Rows = @(Import-Csv -LiteralPath $InputCsv)

Write-Host "Registros encontrados: $($Rows.Count)" -ForegroundColor Green
Write-Host ""

if ($Rows.Count -eq 0) {
    throw "O CSV nao possui registros."
}

# ============================================================
# FUNCOES
# ============================================================

function Get-SafeString {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return ""
    }

    return [string]$Value
}

function Get-RelativeAudioInfo {
    param(
        [Parameter(Mandatory = $true)]
        $Row
    )

    $IndexValue = Get-SafeString $Row.Index
    $WemValue = Get-SafeString $Row.WEM

    $Batch = Get-SafeString $Row.Batch

    if ([string]::IsNullOrWhiteSpace($Batch)) {
        try {
            $IndexNumber = [int]$IndexValue
            $BatchNumber = [math]::Floor(($IndexNumber - 1) / 100) + 1
            $Batch = "Batch_{0:D3}" -f $BatchNumber
        }
        catch {
            $Batch = "Batch_001"
        }
    }

    $WemBase = [System.IO.Path]::GetFileNameWithoutExtension($WemValue)

    try {
        $IndexNumber = [int]$IndexValue
        $WavName = "{0:D4}_{1}.wav" -f $IndexNumber, $WemBase
    }
    catch {
        $WavName = $WemBase + ".wav"
    }

    $RelativePath = "$Batch/$WavName"

    $PhysicalPath = Join-Path `
        (Join-Path $VoiceRoot $Batch) `
        $WavName

    [PSCustomObject]@{
        Batch        = $Batch
        WavName      = $WavName
        RelativePath = $RelativePath
        PhysicalPath = $PhysicalPath
        Exists       = (Test-Path -LiteralPath $PhysicalPath)
    }
}

# ============================================================
# PREPARACAO DOS DADOS
# ============================================================

$Data = New-Object System.Collections.Generic.List[object]

$AudioFound = 0
$AudioMissing = 0
$Transcribed = 0
$NoSpeech = 0
$Errors = 0

$Counter = 0

foreach ($Row in $Rows) {

    $Counter++

    $AudioInfo = Get-RelativeAudioInfo -Row $Row

    if ($AudioInfo.Exists) {
        $AudioFound++
    }
    else {
        $AudioMissing++
    }

    $Transcript = Get-SafeString $Row.OriginalTranscript

    if ([string]::IsNullOrWhiteSpace($Transcript)) {
        $Transcript = Get-SafeString $Row.Transcript
    }

    $Status = Get-SafeString $Row.Status

    if ($Status -eq "NO_SPEECH") {
        $NoSpeech++
    }

    if ($Status -eq "ERROR") {
        $Errors++
    }

    $Probability = Get-SafeString $Row.WhisperProbability

    if ([string]::IsNullOrWhiteSpace($Probability)) {
        $Probability = Get-SafeString $Row.Probability
    }

    $TranscriptionTime = Get-SafeString $Row.TranscriptionTimeSec

    $Object = [ordered]@{
        Index               = Get-SafeString $Row.Index
        Batch               = $AudioInfo.Batch
        WEM                 = Get-SafeString $Row.WEM
        Audio               = $AudioInfo.RelativePath
        AudioExists         = $AudioInfo.Exists
        EventID             = Get-SafeString $Row.EventID
        ActionID            = Get-SafeString $Row.ActionID
        SoundID             = Get-SafeString $Row.SoundID
        SourceID            = Get-SafeString $Row.SourceID
        DurationSec         = Get-SafeString $Row.DurationSec
        Bitrate             = Get-SafeString $Row.Bitrate
        Encoding            = Get-SafeString $Row.Encoding
        SampleRate          = Get-SafeString $Row.SampleRate
        Channels            = Get-SafeString $Row.Channels
        Category            = Get-SafeString $Row.Category
        Character           = Get-SafeString $Row.Character
        Transcript          = $Transcript
        Status              = $Status
        WhisperModel        = Get-SafeString $Row.WhisperModel
        WhisperProbability  = $Probability
        TranscriptionTimeSec = $TranscriptionTime
        Notes               = Get-SafeString $Row.Notes
    }

    [void]$Data.Add([PSCustomObject]$Object)
}

Write-Host "Audios encontrados: $AudioFound" -ForegroundColor Green
Write-Host "Audios ausentes:   $AudioMissing" -ForegroundColor Yellow
Write-Host "Transcricoes:       $Transcribed" -ForegroundColor Green
Write-Host "Sem fala:           $NoSpeech" -ForegroundColor Yellow
Write-Host "Erros:              $Errors" -ForegroundColor Red
Write-Host ""

# ============================================================
# CONVERSAO PARA JSON
# ============================================================

Write-Host "Preparando dados para o catalogo..." -ForegroundColor Yellow

$JsonData = $Data | ConvertTo-Json -Depth 8 -Compress

# Protecoes para insercao segura no JavaScript
$JsonData = $JsonData.Replace("</", "<\/")

# ============================================================
# HTML
#
# IMPORTANTE:
# O HTML abaixo e uma string de aspas simples.
# Dessa forma o PowerShell NAO interpreta:
#
# ${...}
# $...
# `...
#
# pertencentes ao JavaScript.
# ============================================================

$HtmlTemplate = @'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">

<meta
    name="viewport"
    content="width=device-width, initial-scale=1.0">

<title>Thief 2014 - Revisao de Transcricoes</title>

<style>

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    background: #111;
    color: #eee;
    font-family:
        Segoe UI,
        Arial,
        sans-serif;
}

header {
    padding: 20px;
    background: #181818;
    border-bottom: 1px solid #333;
    position: sticky;
    top: 0;
    z-index: 20;
}

h1 {
    margin: 0 0 6px 0;
    font-size: 22px;
}

.subtitle {
    color: #aaa;
    font-size: 13px;
}

.toolbar {
    margin-top: 15px;
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
}

button,
select,
input,
textarea {
    font-family: inherit;
}

button {
    background: #252525;
    color: #eee;
    border: 1px solid #444;
    border-radius: 6px;
    padding: 8px 12px;
    cursor: pointer;
}

button:hover {
    background: #333;
}

button.active {
    background: #555;
}

button.primary {
    background: #5a1515;
    border-color: #9b2929;
}

button.primary:hover {
    background: #752020;
}

select,
input,
textarea {
    background: #191919;
    color: #eee;
    border: 1px solid #444;
    border-radius: 6px;
    padding: 8px;
}

#search {
    min-width: 260px;
}

.stats {
    margin-top: 15px;
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
}

.stat {
    background: #202020;
    border: 1px solid #333;
    border-radius: 6px;
    padding: 8px 12px;
    font-size: 13px;
}

.main {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
}

.card {
    background: #181818;
    border: 1px solid #333;
    border-radius: 10px;
    padding: 20px;
    margin-bottom: 20px;
}

.card.current {
    border-color: #8b2929;
    box-shadow: 0 0 20px rgba(130, 20, 20, 0.15);
}

.cardHeader {
    display: flex;
    justify-content: space-between;
    gap: 15px;
    flex-wrap: wrap;
    margin-bottom: 15px;
}

.index {
    font-size: 22px;
    font-weight: bold;
}

.wem {
    color: #aaa;
    font-family: Consolas, monospace;
    font-size: 13px;
}

.status {
    display: inline-block;
    padding: 4px 8px;
    border-radius: 5px;
    font-size: 12px;
    background: #333;
}

.status.ok {
    background: #173d20;
    color: #8ee89d;
}

.status.warning {
    background: #443814;
    color: #f0d66d;
}

.status.error {
    background: #481717;
    color: #ff8c8c;
}

audio {
    width: 100%;
    margin: 10px 0 18px 0;
}

.meta {
    display: grid;
    grid-template-columns:
        repeat(auto-fit, minmax(160px, 1fr));
    gap: 10px;
    margin-bottom: 18px;
}

.metaBox {
    background: #202020;
    border-radius: 6px;
    padding: 10px;
}

.metaLabel {
    color: #888;
    font-size: 11px;
    margin-bottom: 4px;
    text-transform: uppercase;
}

.metaValue {
    font-size: 13px;
    word-break: break-word;
}

.transcriptionBox {
    background: #101010;
    border: 1px solid #333;
    border-radius: 8px;
    padding: 15px;
    margin-top: 10px;
}

.transcriptionLabel {
    color: #999;
    font-size: 12px;
    margin-bottom: 8px;
}

.transcriptionText {
    font-size: 19px;
    line-height: 1.5;
    min-height: 35px;
}

.noSpeech {
    color: #888;
    font-style: italic;
}

.reviewBox {
    margin-top: 18px;
    border-top: 1px solid #333;
    padding-top: 18px;
}

.reviewGrid {
    display: grid;
    grid-template-columns:
        repeat(auto-fit, minmax(250px, 1fr));
    gap: 12px;
}

.field {
    display: flex;
    flex-direction: column;
    gap: 6px;
}

.field label {
    color: #aaa;
    font-size: 12px;
}

.field textarea {
    width: 100%;
    min-height: 80px;
    resize: vertical;
}

.field input {
    width: 100%;
}

.actions {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 12px;
}

.reviewButton {
    min-width: 115px;
}

.reviewButton.correct {
    border-color: #317b40;
}

.reviewButton.partial {
    border-color: #89772a;
}

.reviewButton.incorrect {
    border-color: #9a3232;
}

.reviewButton.none {
    border-color: #555;
}

.reviewButton.selected {
    background: #555;
    box-shadow: inset 0 0 0 1px #aaa;
}

.counter {
    color: #aaa;
    margin-top: 10px;
    font-size: 13px;
}

.hidden {
    display: none !important;
}

.empty {
    text-align: center;
    color: #888;
    padding: 60px 20px;
}

.help {
    margin-top: 12px;
    color: #777;
    font-size: 12px;
}

kbd {
    background: #222;
    border: 1px solid #444;
    border-radius: 4px;
    padding: 2px 5px;
    font-family: Consolas, monospace;
}

</style>
</head>

<body>

<header>

<h1>Thief 2014 - Revisao de Transcricoes</h1>

<div class="subtitle">
Catalogo gerado pelo Script 20
</div>

<div class="toolbar">

<button id="prevButton">
← Anterior
</button>

<button id="nextButton">
Proximo →
</button>

<button id="playButton">
▶ Reproduzir
</button>

<button id="pauseButton">
⏸ Pausar
</button>

<select id="filter">

<option value="ALL">
Todos
</option>

<option value="TRANSCRIBED">
Transcritos
</option>

<option value="NO_SPEECH">
Sem fala
</option>

<option value="ERROR">
Erros
</option>

<option value="MISSING_AUDIO">
Audio ausente
</option>

<option value="REVIEWED">
Revisados
</option>

<option value="PENDING">
Pendentes
</option>

</select>

<input
    id="search"
    type="text"
    placeholder="Pesquisar WEM, EventID ou transcricao...">

<button id="exportButton" class="primary">
Exportar revisao CSV
</button>

<button id="clearButton">
Limpar revisoes locais
</button>

</div>

<div class="stats">

<div class="stat" id="statTotal">
Total: 0
</div>

<div class="stat" id="statVisible">
Visiveis: 0
</div>

<div class="stat" id="statReviewed">
Revisados: 0
</div>

<div class="stat" id="statPending">
Pendentes: 0
</div>

</div>

<div class="help">

Atalhos:
<kbd>←</kbd> anterior
<kbd>→</kbd> proximo
<kbd>Space</kbd> reproduzir/pausar

</div>

</header>

<main class="main">

<div id="counter" class="counter"></div>

<div id="list"></div>

</main>

<script>

const DATA = __DATA_JSON__;

const STORAGE_KEY = "__STORAGE_KEY__";

let visibleItems = [];
let currentPosition = 0;

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

function loadReviews() {

    try {

        const raw = localStorage.getItem(STORAGE_KEY);

        if (!raw) {
            return {};
        }

        return JSON.parse(raw);

    } catch (error) {

        console.error(
            "Falha ao carregar revisoes:",
            error
        );

        return {};
    }
}

function saveReviews(reviews) {

    localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify(reviews)
    );
}

let reviews = loadReviews();

function getReview(index) {

    const key = String(index);

    if (!reviews[key]) {

        reviews[key] = {
            accuracy: "",
            corrected: "",
            notes: ""
        };
    }

    return reviews[key];
}

function isReviewed(item) {

    const review = getReview(item.Index);

    return (
        review.accuracy !== ""
        ||
        review.corrected !== ""
        ||
        review.notes !== ""
    );
}

function getStatusClass(item) {

    if (!item.AudioExists) {
        return "error";
    }

    if (item.Status === "ERROR") {
        return "error";
    }

    if (item.Status === "NO_SPEECH") {
        return "warning";
    }

    if (item.Transcript) {
        return "ok";
    }

    return "warning";
}

function getStatusLabel(item) {

    if (!item.AudioExists) {
        return "AUDIO AUSENTE";
    }

    if (item.Status === "ERROR") {
        return "ERRO";
    }

    if (item.Status === "NO_SPEECH") {
        return "SEM FALA";
    }

    if (item.Transcript) {
        return "TRANSCRITO";
    }

    return "PENDENTE";
}

function matchesFilter(item) {

    const filter = document
        .getElementById("filter")
        .value;

    if (filter === "ALL") {
        return true;
    }

    if (filter === "TRANSCRIBED") {
        return Boolean(item.Transcript);
    }

    if (filter === "NO_SPEECH") {
        return item.Status === "NO_SPEECH";
    }

    if (filter === "ERROR") {
        return item.Status === "ERROR";
    }

    if (filter === "MISSING_AUDIO") {
        return !item.AudioExists;
    }

    if (filter === "REVIEWED") {
        return isReviewed(item);
    }

    if (filter === "PENDING") {
        return !isReviewed(item);
    }

    return true;
}

function matchesSearch(item) {

    const value = document
        .getElementById("search")
        .value
        .trim()
        .toLowerCase();

    if (!value) {
        return true;
    }

    const haystack = [
        item.WEM,
        item.EventID,
        item.ActionID,
        item.SoundID,
        item.SourceID,
        item.Transcript,
        item.Category
    ]
    .join(" ")
    .toLowerCase();

    return haystack.includes(value);
}

function refreshVisibleItems() {

    visibleItems = DATA.filter(function(item) {

        return (
            matchesFilter(item)
            &&
            matchesSearch(item)
        );

    });

    if (currentPosition >= visibleItems.length) {
        currentPosition =
            Math.max(0, visibleItems.length - 1);
    }
}

function updateStats() {

    const reviewed = DATA.filter(
        function(item) {
            return isReviewed(item);
        }
    ).length;

    document.getElementById(
        "statTotal"
    ).textContent =
        "Total: " + DATA.length;

    document.getElementById(
        "statVisible"
    ).textContent =
        "Visiveis: " + visibleItems.length;

    document.getElementById(
        "statReviewed"
    ).textContent =
        "Revisados: " + reviewed;

    document.getElementById(
        "statPending"
    ).textContent =
        "Pendentes: " +
        (DATA.length - reviewed);
}

function createCard(item, position) {

    const review = getReview(item.Index);

    const statusClass =
        getStatusClass(item);

    const statusLabel =
        getStatusLabel(item);

    const transcript =
        item.Transcript
        ||
        "";

    const card = document.createElement("section");

    card.className =
        "card" +
        (
            position === currentPosition
            ? " current"
            : ""
        );

    card.dataset.index =
        String(item.Index);

    let audioHtml = "";

    if (item.AudioExists) {

        audioHtml =
            '<audio controls preload="metadata" ' +
            'src="' +
            escapeHtml(item.Audio) +
            '"></audio>';

    } else {

        audioHtml =
            '<div class="noSpeech">' +
            'Arquivo de audio nao encontrado: ' +
            escapeHtml(item.Audio) +
            '</div>';
    }

    let transcriptHtml = "";

    if (transcript) {

        transcriptHtml =
            '<div class="transcriptionText">' +
            escapeHtml(transcript) +
            '</div>';

    } else {

        transcriptHtml =
            '<div class="transcriptionText noSpeech">' +
            'Nenhuma transcricao disponivel.' +
            '</div>';
    }

    card.innerHTML =

        '<div class="cardHeader">' +

            '<div>' +

                '<div class="index">' +
                    '#' +
                    escapeHtml(item.Index) +
                '</div>' +

                '<div class="wem">' +
                    escapeHtml(item.WEM) +
                '</div>' +

            '</div>' +

            '<div>' +

                '<span class="status ' +
                    statusClass +
                '">' +
                    escapeHtml(statusLabel) +
                '</span>' +

            '</div>' +

        '</div>' +

        audioHtml +

        '<div class="meta">' +

            '<div class="metaBox">' +
                '<div class="metaLabel">Duracao</div>' +
                '<div class="metaValue">' +
                    escapeHtml(item.DurationSec) +
                    ' s' +
                '</div>' +
            '</div>' +

            '<div class="metaBox">' +
                '<div class="metaLabel">Bitrate</div>' +
                '<div class="metaValue">' +
                    escapeHtml(item.Bitrate) +
                '</div>' +
            '</div>' +

            '<div class="metaBox">' +
                '<div class="metaLabel">Sample Rate</div>' +
                '<div class="metaValue">' +
                    escapeHtml(item.SampleRate) +
                '</div>' +
            '</div>' +

            '<div class="metaBox">' +
                '<div class="metaLabel">Canais</div>' +
                '<div class="metaValue">' +
                    escapeHtml(item.Channels) +
                '</div>' +
            '</div>' +

            '<div class="metaBox">' +
                '<div class="metaLabel">EventID</div>' +
                '<div class="metaValue">' +
                    escapeHtml(item.EventID) +
                '</div>' +
            '</div>' +

            '<div class="metaBox">' +
                '<div class="metaLabel">SoundID</div>' +
                '<div class="metaValue">' +
                    escapeHtml(item.SoundID) +
                '</div>' +
            '</div>' +

            '<div class="metaBox">' +
                '<div class="metaLabel">Modelo</div>' +
                '<div class="metaValue">' +
                    escapeHtml(item.WhisperModel) +
                '</div>' +
            '</div>' +

            '<div class="metaBox">' +
                '<div class="metaLabel">Probabilidade</div>' +
                '<div class="metaValue">' +
                    escapeHtml(item.WhisperProbability) +
                '</div>' +
            '</div>' +

        '</div>' +

        '<div class="transcriptionBox">' +

            '<div class="transcriptionLabel">' +
                'TRANSCRICAO AUTOMATICA' +
            '</div>' +

            transcriptHtml +

        '</div>' +

        '<div class="reviewBox">' +

            '<div class="reviewGrid">' +

                '<div class="field">' +

                    '<label>' +
                        'Avaliacao' +
                    '</label>' +

                    '<select class="accuracy">' +

                        '<option value="">' +
                            'Nao revisado' +
                        '</option>' +

                        '<option value="CORRETA"' +
                            (
                                review.accuracy === "CORRETA"
                                ? " selected"
                                : ""
                            ) +
                        '>' +
                            'CORRETA' +
                        '</option>' +

                        '<option value="PARCIAL"' +
                            (
                                review.accuracy === "PARCIAL"
                                ? " selected"
                                : ""
                            ) +
                        '>' +
                            'PARCIAL' +
                        '</option>' +

                        '<option value="INCORRETA"' +
                            (
                                review.accuracy === "INCORRETA"
                                ? " selected"
                                : ""
                            ) +
                        '>' +
                            'INCORRETA' +
                        '</option>' +

                        '<option value="SEM_FALA"' +
                            (
                                review.accuracy === "SEM_FALA"
                                ? " selected"
                                : ""
                            ) +
                        '>' +
                            'SEM FALA' +
                        '</option>' +

                    '</select>' +

                '</div>' +

                '<div class="field">' +

                    '<label>' +
                        'Transcricao corrigida' +
                    '</label>' +

                    '<textarea ' +
                        'class="corrected" ' +
                        'placeholder="Digite a correcao somente se necessario..."' +
                    '>' +
                        escapeHtml(review.corrected) +
                    '</textarea>' +

                '</div>' +

                '<div class="field">' +

                    '<label>' +
                        'Observacoes' +
                    '</label>' +

                    '<textarea ' +
                        'class="notes" ' +
                        'placeholder="Ex.: nome proprio, sussurro, ruido, fala cortada..."' +
                    '>' +
                        escapeHtml(review.notes) +
                    '</textarea>' +

                '</div>' +

            '</div>' +

            '<div class="actions">' +

                '<button ' +
                    'class="reviewButton correct" ' +
                    'data-value="CORRETA">' +
                    '✓ CORRETA' +
                '</button>' +

                '<button ' +
                    'class="reviewButton partial" ' +
                    'data-value="PARCIAL">' +
                    '◐ PARCIAL' +
                '</button>' +

                '<button ' +
                    'class="reviewButton incorrect" ' +
                    'data-value="INCORRETA">' +
                    '✕ INCORRETA' +
                '</button>' +

                '<button ' +
                    'class="reviewButton none" ' +
                    'data-value="SEM_FALA">' +
                    '○ SEM FALA' +
                '</button>' +

            '</div>' +

        '</div>';

    const accuracy =
        card.querySelector(".accuracy");

    const corrected =
        card.querySelector(".corrected");

    const notes =
        card.querySelector(".notes");

    function saveCurrentReview() {

        const currentReview =
            getReview(item.Index);

        currentReview.accuracy =
            accuracy.value;

        currentReview.corrected =
            corrected.value;

        currentReview.notes =
            notes.value;

        saveReviews(reviews);

        updateStats();
    }

    accuracy.addEventListener(
        "change",
        saveCurrentReview
    );

    corrected.addEventListener(
        "input",
        saveCurrentReview
    );

    notes.addEventListener(
        "input",
        saveCurrentReview
    );

    const reviewButtons =
        card.querySelectorAll(".reviewButton");

    reviewButtons.forEach(
        function(button) {

            const value =
                button.dataset.value;

            if (
                review.accuracy === value
            ) {
                button.classList.add(
                    "selected"
                );
            }

            button.addEventListener(
                "click",
                function() {

                    accuracy.value = value;

                    saveCurrentReview();

                    reviewButtons.forEach(
                        function(other) {
                            other.classList.remove(
                                "selected"
                            );
                        }
                    );

                    button.classList.add(
                        "selected"
                    );

                    setTimeout(
                        function() {
                            goNext();
                        },
                        100
                    );
                }
            );
        }
    );

    return card;
}

function render() {

    refreshVisibleItems();

    const list =
        document.getElementById("list");

    list.innerHTML = "";

    if (visibleItems.length === 0) {

        list.innerHTML =
            '<div class="empty">' +
                'Nenhum item corresponde ao filtro atual.' +
            '</div>';

        updateCounter();

        updateStats();

        return;
    }

    visibleItems.forEach(
        function(item, index) {

            list.appendChild(
                createCard(item, index)
            );

        }
    );

    updateCounter();

    updateStats();

    scrollToCurrent();
}

function updateCounter() {

    const counter =
        document.getElementById("counter");

    if (visibleItems.length === 0) {

        counter.textContent =
            "0 itens";

        return;
    }

    counter.textContent =
        "Posicao " +
        (currentPosition + 1) +
        " de " +
        visibleItems.length;
}

function scrollToCurrent() {

    const cards =
        document.querySelectorAll(".card");

    if (
        !cards.length
        ||
        currentPosition >= cards.length
    ) {
        return;
    }

    cards[currentPosition].scrollIntoView({
        behavior: "smooth",
        block: "center"
    });
}

function goNext() {

    if (
        currentPosition <
        visibleItems.length - 1
    ) {

        currentPosition++;

        render();
    }
}

function goPrevious() {

    if (currentPosition > 0) {

        currentPosition--;

        render();
    }
}

function getCurrentAudio() {

    const cards =
        document.querySelectorAll(".card");

    if (
        !cards.length
        ||
        currentPosition >= cards.length
    ) {
        return null;
    }

    return cards[currentPosition]
        .querySelector("audio");
}

function playCurrent() {

    const audio =
        getCurrentAudio();

    if (!audio) {
        return;
    }

    audio.play();
}

function pauseCurrent() {

    const audio =
        getCurrentAudio();

    if (!audio) {
        return;
    }

    audio.pause();
}

function csvEscape(value) {

    if (
        value === null
        ||
        value === undefined
    ) {
        return '""';
    }

    return '"' +
        String(value)
            .replace(/"/g, '""') +
        '"';
}

function exportCsv() {

    const rows = [];

    rows.push([
        "Index",
        "WEM",
        "Audio",
        "EventID",
        "ActionID",
        "SoundID",
        "SourceID",
        "DurationSec",
        "Category",
        "AutomaticTranscript",
        "Review",
        "CorrectedTranscript",
        "Notes"
    ].map(csvEscape).join(","));

    DATA.forEach(
        function(item) {

            const review =
                getReview(item.Index);

            rows.push([
                item.Index,
                item.WEM,
                item.Audio,
                item.EventID,
                item.ActionID,
                item.SoundID,
                item.SourceID,
                item.DurationSec,
                item.Category,
                item.Transcript,
                review.accuracy,
                review.corrected,
                review.notes
            ].map(csvEscape).join(","));

        }
    );

    const blob =
        new Blob(
            [rows.join("\r\n")],
            {
                type:
                    "text/csv;charset=utf-8;"
            }
        );

    const url =
        URL.createObjectURL(blob);

    const link =
        document.createElement("a");

    const timestamp =
        new Date()
            .toISOString()
            .replace(/[:.]/g, "-");

    link.href = url;

    link.download =
        "thief2014_transcription_review_" +
        timestamp +
        ".csv";

    document.body.appendChild(link);

    link.click();

    link.remove();

    URL.revokeObjectURL(url);
}

function clearReviews() {

    const confirmed =
        confirm(
            "Tem certeza que deseja apagar todas as revisoes locais deste catalogo?"
        );

    if (!confirmed) {
        return;
    }

    localStorage.removeItem(
        STORAGE_KEY
    );

    reviews = {};

    render();
}

document
    .getElementById("filter")
    .addEventListener(
        "change",
        function() {

            currentPosition = 0;

            render();
        }
    );

document
    .getElementById("search")
    .addEventListener(
        "input",
        function() {

            currentPosition = 0;

            render();
        }
    );

document
    .getElementById("prevButton")
    .addEventListener(
        "click",
        goPrevious
    );

document
    .getElementById("nextButton")
    .addEventListener(
        "click",
        goNext
    );

document
    .getElementById("playButton")
    .addEventListener(
        "click",
        playCurrent
    );

document
    .getElementById("pauseButton")
    .addEventListener(
        "click",
        pauseCurrent
    );

document
    .getElementById("exportButton")
    .addEventListener(
        "click",
        exportCsv
    );

document
    .getElementById("clearButton")
    .addEventListener(
        "click",
        clearReviews
    );

document.addEventListener(
    "keydown",
    function(event) {

        const tag =
            document.activeElement
                ? document.activeElement.tagName
                : "";

        const editing =
            tag === "INPUT"
            ||
            tag === "TEXTAREA"
            ||
            tag === "SELECT";

        if (editing) {
            return;
        }

        if (event.key === "ArrowRight") {

            event.preventDefault();

            goNext();

        } else if (
            event.key === "ArrowLeft"
        ) {

            event.preventDefault();

            goPrevious();

        } else if (
            event.code === "Space"
        ) {

            event.preventDefault();

            const audio =
                getCurrentAudio();

            if (!audio) {
                return;
            }

            if (audio.paused) {
                audio.play();
            } else {
                audio.pause();
            }
        }
    }
);

render();

</script>

</body>
</html>
'@

# ============================================================
# SUBSTITUICAO DOS TOKENS
# ============================================================

$Html = $HtmlTemplate.Replace(
    "__DATA_JSON__",
    $JsonData
)

$Html = $Html.Replace(
    "__STORAGE_KEY__",
    $LocalStorageKey
)

# ============================================================
# GRAVACAO DO HTML
# ============================================================

Write-Host "Gravando catalogo HTML..." -ForegroundColor Yellow

Set-Content `
    -LiteralPath $OutputHtml `
    -Value $Html `
    -Encoding UTF8

# ============================================================
# VALIDACAO BASICA
# ============================================================

if (-not (Test-Path -LiteralPath $OutputHtml)) {
    throw "Falha ao criar o catalogo HTML."
}

$HtmlSize =
    (Get-Item -LiteralPath $OutputHtml).Length

# ============================================================
# RELATORIO
# ============================================================

$Report = @()

$Report += "============================================================"
$Report += " THIEF 2014 - TRANSCRIPTION REVIEW - SCRIPT 20"
$Report += "============================================================"
$Report += ""
$Report += "Gerado em: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$Report += ""
$Report += "ENTRADA"
$Report += "CSV: $InputCsv"
$Report += ""
$Report += "AUDIO"
$Report += "Root: $VoiceRoot"
$Report += ""
$Report += "SAIDA"
$Report += "HTML: $OutputHtml"
$Report += ""
$Report += "ESTATISTICAS"
$Report += "Registros:        $($Rows.Count)"
$Report += "Audios encontrados: $AudioFound"
$Report += "Audios ausentes:    $AudioMissing"
$Report += "Transcritos:         $Transcribed"
$Report += "Sem fala:            $NoSpeech"
$Report += "Erros:               $Errors"
$Report += ""
$Report += "HTML"
$Report += "Tamanho bytes: $HtmlSize"
$Report += ""
$Report += "RECURSOS"
$Report += "- Reproducao de audio"
$Report += "- Transcricao automatica"
$Report += "- Revisao CORRETA"
$Report += "- Revisao PARCIAL"
$Report += "- Revisao INCORRETA"
$Report += "- Revisao SEM FALA"
$Report += "- Transcricao corrigida"
$Report += "- Observacoes"
$Report += "- Filtros"
$Report += "- Pesquisa"
$Report += "- Navegacao anterior/proximo"
$Report += "- Atalhos de teclado"
$Report += "- localStorage"
$Report += "- Exportacao CSV"
$Report += ""
$Report += "STATUS: CONCLUIDO"
$Report += "============================================================"

Set-Content `
    -LiteralPath $ReportFile `
    -Value ($Report -join "`r`n") `
    -Encoding UTF8

# ============================================================
# GIT
# ============================================================

Write-Host ""
Write-Host "Arquivos gerados:" -ForegroundColor Green
Write-Host "HTML:"
Write-Host $OutputHtml
Write-Host ""
Write-Host "Relatorio:"
Write-Host $ReportFile
Write-Host ""

Set-Location $RepoRoot

Write-Host "Verificando Git..." -ForegroundColor Yellow

git add `
    "Scripts/20_Create_Transcription_Review_Catalog.ps1" `
    "Analysis/Reports/dubbing_transcription_review_catalog_report.txt"

$GitStatus = git status --short

if ($GitStatus) {

    Write-Host ""
    Write-Host "Alteracoes detectadas:" -ForegroundColor Yellow
    Write-Host $GitStatus
    Write-Host ""

    $CommitMessage =
        "Add transcription review catalog"

    git commit -m $CommitMessage

    if ($LASTEXITCODE -eq 0) {

        Write-Host ""
        Write-Host "Commit criado." -ForegroundColor Green

        git push

        if ($LASTEXITCODE -eq 0) {

            Write-Host ""
            Write-Host "Git sincronizado." -ForegroundColor Green
        }
        else {

            Write-Host ""
            Write-Host "Commit criado, mas o push falhou." `
                -ForegroundColor Yellow
        }
    }
}
else {

    Write-Host "Nenhuma alteracao nova para commit." `
        -ForegroundColor DarkGray
}

# ============================================================
# FINAL
# ============================================================

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host " SCRIPT 20 CONCLUIDO" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "HTML:"
Write-Host $OutputHtml
Write-Host ""
Write-Host "Registros:          $($Rows.Count)"
Write-Host "Audios encontrados: $AudioFound"
Write-Host "Audios ausentes:    $AudioMissing"
Write-Host "Transcritos:        $Transcribed"
Write-Host ""