Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Set-Location "B:\DublagemThief2014"

$InputCsv = ".\Analysis\WEM\dubbing_transcription.csv"
$OutputDir = "B:\Thief2014_Dubbing\Work\VoiceAudition\DubbingReview"
$OutputHtml = Join-Path $OutputDir "dubbing_review.html"
$ReportPath = ".\Analysis\Reports\dubbing_review_catalog_report.txt"

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " SCRIPT 21 - CATALOGO DE REVISAO DE DUBLAGEM" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path -LiteralPath $InputCsv)) {
    throw "CSV de transcricao nao encontrado: $InputCsv"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$Rows = @(Import-Csv -LiteralPath $InputCsv)

$Rows = @(
    $Rows |
        Where-Object {
            $_.Category -eq "FALA"
        }
)

Write-Host "FALAS carregadas: $($Rows.Count)" -ForegroundColor Green

function Get-SafeString {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return ""
    }

    return ([string]$Value).Trim()
}

function Escape-Html {
    param(
        [AllowNull()]
        [object]$Value
    )

    $Text = Get-SafeString $Value

    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function Get-AudioInfo {
    param(
        [string]$Index,
        [string]$Batch,
        [string]$Wem
    )

    $VoiceRoot = "B:\Thief2014_Dubbing\Work\VoiceAudition"

    $IndexNumber = 0

    if (-not [int]::TryParse($Index, [ref]$IndexNumber)) {
        return @{
            RelativePath = ""
            PhysicalPath = ""
            Exists = $false
        }
    }

    [int]$BatchNumber = [math]::Floor(($IndexNumber - 1) / 100) + 1

    $CalculatedBatch = "Batch_{0:D3}" -f $BatchNumber

    $WavName = "{0:D4}_{1}.wav" -f `
        $IndexNumber, `
        ([System.IO.Path]::GetFileNameWithoutExtension($Wem))

    $PhysicalPath = Join-Path `
        (Join-Path $VoiceRoot $CalculatedBatch) `
        $WavName

    return @{
        RelativePath = "../$CalculatedBatch/$WavName"
        PhysicalPath = $PhysicalPath
        Exists = (Test-Path -LiteralPath $PhysicalPath)
    }
}

$Data = New-Object System.Collections.Generic.List[object]

$AudioFound = 0
$AudioMissing = 0
$Transcribed = 0

foreach ($Row in $Rows) {

    $Index = Get-SafeString $Row.Index
    $Wem = Get-SafeString $Row.WEM
    $Batch = Get-SafeString $Row.Batch

    $Transcript = Get-SafeString $Row.OriginalTranscript

    if (-not [string]::IsNullOrWhiteSpace($Transcript)) {
        $Transcribed++
    }

    $AudioInfo = Get-AudioInfo `
        -Index $Index `
        -Batch $Batch `
        -Wem $Wem

    if ($AudioInfo.Exists) {
        $AudioFound++
    }
    else {
        $AudioMissing++
    }

    $Data.Add(
        [ordered]@{
            Index = $Index
            Batch = $Batch
            WEM = $Wem
            EventID = Get-SafeString $Row.EventID
            ActionID = Get-SafeString $Row.ActionID
            SoundID = Get-SafeString $Row.SoundID
            SourceID = Get-SafeString $Row.SourceID
            DurationSec = Get-SafeString $Row.DurationSec
            Character = Get-SafeString $Row.Character
            OriginalTranscript = $Transcript
            Audio = $AudioInfo.RelativePath
            AudioExists = $AudioInfo.Exists
        }
    )
}

$Json = $Data | ConvertTo-Json -Depth 5 -Compress

$HtmlTemplate = @'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">

<title>Thief 2014 - Revisão da Dublagem PT-BR</title>

<style>

:root {
    color-scheme: dark;
    --bg: #0b0d10;
    --panel: #13171c;
    --panel2: #1a2027;
    --border: #2b333d;
    --text: #e8edf2;
    --muted: #8e9aa7;
    --accent: #d7a83e;
    --green: #4fd18b;
    --red: #e06464;
}

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    background: var(--bg);
    color: var(--text);
    font-family:
        Segoe UI,
        Arial,
        sans-serif;
}

header {
    position: sticky;
    top: 0;
    z-index: 10;
    background: rgba(11,13,16,.96);
    border-bottom: 1px solid var(--border);
    padding: 18px 24px;
}

.header-grid {
    display: grid;
    grid-template-columns: 1fr auto;
    gap: 20px;
    align-items: center;
}

h1 {
    margin: 0 0 5px;
    font-size: 23px;
}

.subtitle {
    color: var(--muted);
    font-size: 13px;
}

.stats {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
}

.stat {
    background: var(--panel);
    border: 1px solid var(--border);
    border-radius: 9px;
    padding: 8px 12px;
    min-width: 100px;
}

.stat-label {
    color: var(--muted);
    font-size: 11px;
}

.stat-value {
    font-size: 18px;
    font-weight: 700;
}

.toolbar {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
    padding: 14px 24px;
    border-bottom: 1px solid var(--border);
    background: #0f1216;
}

button,
select,
input {
    background: var(--panel2);
    color: var(--text);
    border: 1px solid var(--border);
    border-radius: 7px;
    padding: 9px 11px;
    font: inherit;
}

button {
    cursor: pointer;
}

button:hover {
    border-color: var(--accent);
}

button.active {
    border-color: var(--accent);
    color: var(--accent);
}

input {
    min-width: 260px;
}

main {
    max-width: 1400px;
    margin: 0 auto;
    padding: 20px 24px 80px;
}

.card {
    background: var(--panel);
    border: 1px solid var(--border);
    border-radius: 12px;
    margin-bottom: 18px;
    overflow: hidden;
}

.card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 12px;
    padding: 13px 16px;
    background: #171c22;
    border-bottom: 1px solid var(--border);
}

.index {
    color: var(--accent);
    font-weight: 700;
}

.meta {
    color: var(--muted);
    font-size: 12px;
}

.card-body {
    padding: 16px;
}

audio {
    width: 100%;
    margin-bottom: 15px;
}

.grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 14px;
}

.field {
    display: flex;
    flex-direction: column;
    gap: 6px;
}

.field.full {
    grid-column: 1 / -1;
}

label {
    color: var(--muted);
    font-size: 12px;
    font-weight: 600;
}

textarea,
.field input {
    width: 100%;
    background: #0d1014;
    color: var(--text);
    border: 1px solid var(--border);
    border-radius: 7px;
    padding: 10px;
    font: inherit;
}

textarea {
    min-height: 90px;
    resize: vertical;
}

textarea:focus,
.field input:focus {
    outline: none;
    border-color: var(--accent);
}

.original {
    color: #dfe5ea;
    background: #0e1216;
    border: 1px solid var(--border);
    border-radius: 7px;
    padding: 12px;
    min-height: 90px;
    white-space: pre-wrap;
}

.status-row {
    display: flex;
    gap: 8px;
    margin-top: 14px;
    flex-wrap: wrap;
}

.status-btn {
    font-size: 12px;
}

.status-btn.selected {
    background: var(--accent);
    color: #111;
    border-color: var(--accent);
}

.footer-actions {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    margin-top: 14px;
}

.empty {
    text-align: center;
    color: var(--muted);
    padding: 50px;
}

@media (max-width: 900px) {

    .header-grid {
        grid-template-columns: 1fr;
    }

    .grid {
        grid-template-columns: 1fr;
    }

    .field.full {
        grid-column: auto;
    }

    main {
        padding: 15px;
    }
}

</style>
</head>

<body>

<header>

<div class="header-grid">

<div>
<h1>Thief 2014 · Revisão da Dublagem PT-BR</h1>
<div class="subtitle">
Revisão das falas transcritas antes da tradução/adaptação para dublagem.
</div>
</div>

<div class="stats">

<div class="stat">
<div class="stat-label">Falas</div>
<div class="stat-value" id="total">0</div>
</div>

<div class="stat">
<div class="stat-label">Revisadas</div>
<div class="stat-value" id="reviewed">0</div>
</div>

<div class="stat">
<div class="stat-label">Pendentes</div>
<div class="stat-value" id="pending">0</div>
</div>

</div>

</div>

</header>

<div class="toolbar">

<input
    id="search"
    type="text"
    placeholder="Pesquisar WEM, personagem ou transcrição..."
>

<select id="filter">
<option value="ALL">Todas</option>
<option value="PENDING">Pendentes</option>
<option value="REVIEWED">Revisadas</option>
</select>

<button id="exportBtn">Exportar CSV</button>
<button id="clearBtn">Limpar revisões</button>

</div>

<main id="app"></main>

<script>

const DATA = __DATA__;

const STORAGE_KEY = "thief2014_dubbing_review_v1";

let state = {};

try {
    state = JSON.parse(
        localStorage.getItem(STORAGE_KEY) || "{}"
    );
} catch {
    state = {};
}

function esc(value) {

    return String(value ?? "")
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}

function getState(index) {

    if (!state[index]) {

        state[index] = {
            character: "",
            ptbr: "",
            notes: "",
            status: "PENDING"
        };
    }

    return state[index];
}

function save() {

    localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify(state)
    );

    updateStats();
}

function updateStats() {

    const total = DATA.length;

    const reviewed = DATA.filter(item => {

        const s = state[item.Index];

        return s && s.status === "REVIEWED";

    }).length;

    document.getElementById("total").textContent = total;
    document.getElementById("reviewed").textContent = reviewed;
    document.getElementById("pending").textContent =
        total - reviewed;
}

function render() {

    const search =
        document.getElementById("search")
            .value
            .toLowerCase()
            .trim();

    const filter =
        document.getElementById("filter").value;

    const app =
        document.getElementById("app");

    const filtered = DATA.filter(item => {

        const s = getState(item.Index);

        if (
            filter === "PENDING" &&
            s.status === "REVIEWED"
        ) {
            return false;
        }

        if (
            filter === "REVIEWED" &&
            s.status !== "REVIEWED"
        ) {
            return false;
        }

        if (!search) {
            return true;
        }

        const haystack = [
            item.Index,
            item.WEM,
            item.Character,
            item.OriginalTranscript,
            s.character,
            s.ptbr,
            s.notes
        ]
        .join(" ")
        .toLowerCase();

        return haystack.includes(search);
    });

    if (filtered.length === 0) {

        app.innerHTML =
            '<div class="empty">Nenhum registro encontrado.</div>';

        updateStats();

        return;
    }

    app.innerHTML = filtered.map(item => {

        const s = getState(item.Index);

        const audio = item.AudioExists
            ? `
                <audio
                    controls
                    preload="metadata"
                    src="${esc(item.Audio)}">
                </audio>
              `
            : `
                <div class="empty">
                    Áudio não encontrado.
                </div>
              `;

        return `
        <section class="card">

            <div class="card-header">

                <div>
                    <span class="index">
                        #${esc(item.Index)}
                    </span>

                    <span class="meta">
                        ${esc(item.WEM)}
                    </span>
                </div>

                <div class="meta">
                    ${esc(item.DurationSec)} s
                    · Event ${esc(item.EventID)}
                </div>

            </div>

            <div class="card-body">

                ${audio}

                <div class="grid">

                    <div class="field">

                        <label>
                            Personagem
                        </label>

                        <input
                            data-field="character"
                            data-index="${esc(item.Index)}"
                            value="${esc(s.character)}"
                            placeholder="Ex.: Garrett"
                        >

                    </div>

                    <div class="field">

                        <label>
                            Status
                        </label>

                        <div class="status-row">

                            <button
                                class="status-btn ${
                                    s.status === "PENDING"
                                    ? "selected"
                                    : ""
                                }"
                                data-status="PENDING"
                                data-index="${esc(item.Index)}">
                                Pendente
                            </button>

                            <button
                                class="status-btn ${
                                    s.status === "REVIEWED"
                                    ? "selected"
                                    : ""
                                }"
                                data-status="REVIEWED"
                                data-index="${esc(item.Index)}">
                                Revisada
                            </button>

                        </div>

                    </div>

                    <div class="field full">

                        <label>
                            Transcrição original
                        </label>

                        <div class="original">
                            ${esc(item.OriginalTranscript)}
                        </div>

                    </div>

                    <div class="field full">

                        <label>
                            Adaptação PT-BR para dublagem
                        </label>

                        <textarea
                            data-field="ptbr"
                            data-index="${esc(item.Index)}"
                            placeholder="Digite a fala adaptada para o português brasileiro..."
                        >${esc(s.ptbr)}</textarea>

                    </div>

                    <div class="field full">

                        <label>
                            Observações
                        </label>

                        <textarea
                            data-field="notes"
                            data-index="${esc(item.Index)}"
                            placeholder="Contexto, emoção, intenção, sincronização, observações..."
                        >${esc(s.notes)}</textarea>

                    </div>

                </div>

            </div>

        </section>
        `;

    }).join("");

    bindEvents();

    updateStats();
}

function bindEvents() {

    document.querySelectorAll("[data-field]")
        .forEach(element => {

            element.addEventListener("input", event => {

                const index =
                    event.target.dataset.index;

                const field =
                    event.target.dataset.field;

                getState(index)[field] =
                    event.target.value;

                save();
            });
        });

    document.querySelectorAll("[data-status]")
        .forEach(button => {

            button.addEventListener("click", event => {

                const index =
                    event.currentTarget.dataset.index;

                const status =
                    event.currentTarget.dataset.status;

                getState(index).status = status;

                save();
                render();
            });
        });
}

function csvEscape(value) {

    const text = String(value ?? "");

    return '"' +
        text.replaceAll('"', '""') +
        '"';
}

function exportCsv() {

    const header = [
        "Index",
        "Batch",
        "WEM",
        "EventID",
        "ActionID",
        "SoundID",
        "SourceID",
        "DurationSec",
        "Character",
        "OriginalTranscript",
        "PTBR",
        "Notes",
        "Status"
    ];

    const lines = [
        header.map(csvEscape).join(",")
    ];

    DATA.forEach(item => {

        const s = getState(item.Index);

        lines.push([
            item.Index,
            item.Batch,
            item.WEM,
            item.EventID,
            item.ActionID,
            item.SoundID,
            item.SourceID,
            item.DurationSec,
            s.character,
            item.OriginalTranscript,
            s.ptbr,
            s.notes,
            s.status
        ]
        .map(csvEscape)
        .join(","));
    });

    const blob = new Blob(
        ["\uFEFF" + lines.join("\r\n")],
        {
            type: "text/csv;charset=utf-8;"
        }
    );

    const url =
        URL.createObjectURL(blob);

    const a =
        document.createElement("a");

    const date =
        new Date()
            .toISOString()
            .replaceAll(":", "-");

    a.href = url;
    a.download =
        "thief2014_dubbing_review_" +
        date +
        ".csv";

    a.click();

    URL.revokeObjectURL(url);
}

document
    .getElementById("search")
    .addEventListener("input", render);

document
    .getElementById("filter")
    .addEventListener("change", render);

document
    .getElementById("exportBtn")
    .addEventListener("click", exportCsv);

document
    .getElementById("clearBtn")
    .addEventListener("click", () => {

        const confirmed =
            confirm(
                "Isso apagará todas as revisões salvas neste navegador. Continuar?"
            );

        if (!confirmed) {
            return;
        }

        state = {};

        localStorage.removeItem(STORAGE_KEY);

        render();
    });

render();

</script>

</body>
</html>
'@

$Html = $HtmlTemplate.Replace(
    "__DATA__",
    $Json
)

Set-Content `
    -LiteralPath $OutputHtml `
    -Value $Html `
    -Encoding UTF8

$Report = @"

THIEF 2014 - CATALOGO DE REVISAO DA DUBLAGEM
==============================================

Data:
$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

CSV de origem:
$InputCsv

HTML:
$OutputHtml

Total de FALAS:
$($Rows.Count)

Com transcricao:
$Transcribed

Audios encontrados:
$AudioFound

Audios ausentes:
$AudioMissing

Storage:
thief2014_dubbing_review_v1

Etapa:
Revisao das transcricoes e adaptacao PT-BR.

==============================================
"@

Set-Content `
    -LiteralPath $ReportPath `
    -Value $Report `
    -Encoding UTF8

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host " SCRIPT 21 CONCLUIDO" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "FALAS:              $($Rows.Count)"
Write-Host "Com transcricao:    $Transcribed"
Write-Host "Audios encontrados: $AudioFound"
Write-Host "Audios ausentes:    $AudioMissing"
Write-Host ""
Write-Host "HTML:"
Write-Host $OutputHtml -ForegroundColor Cyan
Write-Host ""
Write-Host "Relatorio:"
Write-Host $ReportPath -ForegroundColor Cyan
Write-Host ""

