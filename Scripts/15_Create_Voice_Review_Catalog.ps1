$ErrorActionPreference = "Stop"

$Repo = "B:\DublagemThief2014"
$Manifest = Join-Path $Repo "Analysis\WEM\voice_audition_manifest.csv"
$Template = Join-Path $Repo "Analysis\WEM\voice_review_template.csv"
$Report = Join-Path $Repo "Analysis\Reports\voice_review_catalog_report.txt"
$Work = "B:\Thief2014_Dubbing\Work\VoiceAudition"
$Html = Join-Path $Work "review.html"

New-Item -ItemType Directory -Force -Path $Work | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $Template) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $Report) | Out-Null

if (-not (Test-Path $Manifest)) {
    throw "Manifesto nao encontrado: $Manifest"
}

$ManifestRows = @(Import-Csv $Manifest)

if ($ManifestRows.Count -eq 0) {
    throw "Manifesto vazio."
}

Write-Host ""
Write-Host "VOICE REVIEW CATALOG - SCRIPT 15"
Write-Host "Registros encontrados: $($ManifestRows.Count)"
Write-Host ""

$ExistingReviews = @{}

if (Test-Path $Template) {
    try {
        foreach ($r in @(Import-Csv $Template)) {
            if ($r.Index) {
                $ExistingReviews[[string]$r.Index] = $r
            }
        }
    }
    catch {
        Write-Warning "Template existente nao pode ser lido. Sera recriado."
    }
}

$Records = @()

foreach ($row in $ManifestRows) {

    $index = [string]$row.Index
    $wavAbsolute = [string]$row.WAV

    $audioRelative = ""

    if ($wavAbsolute) {

        $prefix = $Work.TrimEnd('\') + '\'

        if ($wavAbsolute.StartsWith(
            $prefix,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            $audioRelative = $wavAbsolute.Substring($prefix.Length)
        }
        else {
            $audioRelative = $wavAbsolute
        }

        $audioRelative = $audioRelative -replace '\\','/'
    }

    $review = $null

    if ($ExistingReviews.ContainsKey($index)) {
        $review = $ExistingReviews[$index]
    }

    $status = "PENDING"
    $type = "VOICE"
    $character = ""
    $context = ""
    $originalText = ""
    $ptbrText = ""
    $notes = ""

    if ($review) {

        if ($review.Status) {
            $status = [string]$review.Status
        }

        if ($review.Type) {
            $type = [string]$review.Type
        }

        if ($review.Character) {
            $character = [string]$review.Character
        }

        if ($review.Context) {
            $context = [string]$review.Context
        }

        if ($review.OriginalText) {
            $originalText = [string]$review.OriginalText
        }

        if ($review.PTBRText) {
            $ptbrText = [string]$review.PTBRText
        }

        if ($review.Notes) {
            $notes = [string]$review.Notes
        }
    }

    $Records += [pscustomobject][ordered]@{

        index        = $index
        batch        = [string]$row.Batch
        wem          = [string]$row.WEM
        wav          = $wavAbsolute
        audio        = $audioRelative

        eventID      = [string]$row.EventID
        actionID     = [string]$row.ActionID
        soundID      = [string]$row.SoundID
        sourceID     = [string]$row.SourceID

        streamType   = [string]$row.StreamType
        duration     = [string]$row.DurationSec
        bitrate      = [string]$row.BitrateKbps
        encoding     = [string]$row.Encoding
        sampleRate   = [string]$row.SampleRate
        channels     = [string]$row.Channels
        bucket       = [string]$row.Bucket

        status       = $status
        type         = $type
        character    = $character
        context      = $context
        originalText = $originalText
        ptbrText     = $ptbrText
        notes        = $notes
    }
}

# ============================================================
# TEMPLATE CSV
# ============================================================

$TemplateRows = foreach ($r in $Records) {

    [pscustomobject][ordered]@{
        Index        = $r.index
        WEM          = $r.wem
        Type         = $r.type
        Character    = $r.character
        Context      = $r.context
        Status       = $r.status
        OriginalText = $r.originalText
        PTBRText     = $r.ptbrText
        Notes        = $r.notes
    }
}

$TemplateRows |
    Export-Csv `
        -Path $Template `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host "Template CSV criado:"
Write-Host $Template

# ============================================================
# JSON
# ============================================================

$DataJson = $Records |
    ConvertTo-Json `
        -Depth 8 `
        -Compress

$DataJson = $DataJson.Replace(
    "</script",
    "<\/script"
)

# ============================================================
# HTML
# ============================================================

$HtmlTemplate = @"
<!DOCTYPE html>

<html lang="pt-BR">

<head>

<meta charset="UTF-8">

<meta name="viewport"
      content="width=device-width, initial-scale=1.0">

<title>Thief 2014 - Voice Review Catalog</title>

<style>

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    background: #111;
    color: #eee;
    font-family: Arial, Helvetica, sans-serif;
}

header {
    position: sticky;
    top: 0;
    z-index: 10;
    background: #181818;
    border-bottom: 1px solid #333;
    padding: 16px;
}

h1 {
    margin: 0 0 6px 0;
    font-size: 22px;
}

.subtitle {
    color: #999;
    font-size: 13px;
}

.toolbar {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 14px;
}

input,
select,
button,
textarea {
    background: #222;
    color: #eee;
    border: 1px solid #444;
    border-radius: 5px;
    padding: 8px;
}

button {
    cursor: pointer;
}

button:hover {
    background: #333;
}

#counter {
    margin-top: 10px;
    color: #aaa;
    font-size: 13px;
}

#catalog {
    padding: 16px;
    display: grid;
    gap: 14px;
}

.card {
    background: #191919;
    border: 1px solid #333;
    border-radius: 8px;
    overflow: hidden;
}

.card-header {
    padding: 12px;
    background: #202020;
    display: flex;
    justify-content: space-between;
    gap: 12px;
}

.card-title {
    font-weight: bold;
}

.card-meta {
    margin-top: 5px;
    color: #999;
    font-size: 12px;
}

.status {
    font-size: 11px;
    font-weight: bold;
    padding: 5px 8px;
    border-radius: 4px;
}

.status-PENDING {
    background: #4b4200;
    color: #ffe66d;
}

.status-REVIEWED {
    background: #164c25;
    color: #7cff99;
}

.status-PROBLEM {
    background: #5b1717;
    color: #ff8b8b;
}

.card-body {
    padding: 14px;
}

audio {
    width: 100%;
    margin-bottom: 14px;
}

.grid {
    display: grid;
    grid-template-columns:
        repeat(auto-fit, minmax(180px, 1fr));
    gap: 10px;
}

.field {
    display: flex;
    flex-direction: column;
    gap: 5px;
}

.field label {
    color: #999;
    font-size: 11px;
}

.field input,
.field select,
.field textarea {
    width: 100%;
}

.field-wide {
    grid-column: 1 / -1;
}

textarea {
    min-height: 70px;
    resize: vertical;
}

.pagination {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 10px;
    padding: 20px;
}

.empty {
    padding: 40px;
    text-align: center;
    color: #888;
}

</style>

</head>

<body>

<header>

<h1>Thief 2014 - Voice Review Catalog</h1>

<div class="subtitle">
Catálogo de revisão da biblioteca de voz extraída
</div>

<div class="toolbar">

<input
    id="search"
    type="text"
    placeholder="Buscar WEM, EventID, texto..."
>

<select id="statusFilter">

<option value="">
Todos os status
</option>

<option value="PENDING">
PENDING
</option>

<option value="REVIEWED">
REVIEWED
</option>

<option value="PROBLEM">
PROBLEM
</option>

</select>

<select id="typeFilter">

<option value="">
Todos os tipos
</option>

<option value="VOICE">
VOICE
</option>

<option value="BREATH">
BREATH
</option>

<option value="PAIN">
PAIN
</option>

<option value="GRUNT">
GRUNT
</option>

<option value="OTHER">
OTHER
</option>

<option value="NOT_VOICE">
NOT_VOICE
</option>

</select>

<button id="exportButton">
Exportar CSV
</button>

<button id="clearStorageButton">
Limpar memória local
</button>

</div>

<div id="counter"></div>

</header>

<main id="catalog"></main>

<div class="pagination">

<button id="previousButton">
← Anterior
</button>

<span id="pageInfo"></span>

<button id="nextButton">
Próxima →
</button>

</div>

<script>

const DATA = __DATA_JSON__;

const PAGE_SIZE = 25;

let currentPage = 1;

let filteredRows = [];

const STORAGE_KEY =
    "thief2014_voice_review_v2";

function loadReviews() {

    try {

        const raw =
            localStorage.getItem(STORAGE_KEY);

        if (!raw) {
            return {};
        }

        return JSON.parse(raw);

    } catch (error) {

        console.error(error);

        return {};
    }
}

let reviews = loadReviews();

function saveReviews() {

    localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify(reviews)
    );
}

function getReview(index) {

    const key = String(index);

    if (!reviews[key]) {

        const source =
            DATA.find(function(item) {
                return String(item.index) === key;
            });

        reviews[key] = {

            status:
                source.status || "PENDING",

            type:
                source.type || "VOICE",

            character:
                source.character || "",

            context:
                source.context || "",

            originalText:
                source.originalText || "",

            ptbrText:
                source.ptbrText || "",

            notes:
                source.notes || ""
        };
    }

    return reviews[key];
}

function updateReview(index, field, value) {

    const review =
        getReview(index);

    review[field] = value;

    saveReviews();
}

function getFilteredRows() {

    const search =
        document
            .getElementById("search")
            .value
            .toLowerCase()
            .trim();

    const status =
        document
            .getElementById("statusFilter")
            .value;

    const type =
        document
            .getElementById("typeFilter")
            .value;

    return DATA.filter(function(row) {

        const review =
            getReview(row.index);

        if (
            status &&
            review.status !== status
        ) {
            return false;
        }

        if (
            type &&
            review.type !== type
        ) {
            return false;
        }

        if (search) {

            const haystack = [

                row.index,
                row.wem,
                row.eventID,
                row.actionID,
                row.soundID,
                row.sourceID,
                row.duration,
                row.bitrate,
                row.encoding,
                review.character,
                review.context,
                review.originalText,
                review.ptbrText,
                review.notes

            ].join(" ").toLowerCase();

            if (!haystack.includes(search)) {
                return false;
            }
        }

        return true;
    });
}

function render() {

    filteredRows =
        getFilteredRows();

    const totalPages =
        Math.max(
            1,
            Math.ceil(
                filteredRows.length /
                PAGE_SIZE
            )
        );

    if (currentPage > totalPages) {
        currentPage = totalPages;
    }

    const start =
        (currentPage - 1) *
        PAGE_SIZE;

    const pageRows =
        filteredRows.slice(
            start,
            start + PAGE_SIZE
        );

    const catalog =
        document.getElementById("catalog");

    catalog.innerHTML = "";

    if (pageRows.length === 0) {

        const empty =
            document.createElement("div");

        empty.className = "empty";

        empty.textContent =
            "Nenhum registro encontrado.";

        catalog.appendChild(empty);

    } else {

        pageRows.forEach(function(row) {

            const review =
                getReview(row.index);

            const card =
                document.createElement("section");

            card.className = "card";

            const header =
                document.createElement("div");

            header.className =
                "card-header";

            const info =
                document.createElement("div");

            const title =
                document.createElement("div");

            title.className =
                "card-title";

            title.textContent =
                "#" +
                row.index +
                " · " +
                row.wem;

            const meta =
                document.createElement("div");

            meta.className =
                "card-meta";

            meta.textContent =
                "Event " +
                row.eventID +
                " · Action " +
                row.actionID +
                " · Sound " +
                row.soundID +
                " · " +
                row.duration +
                " s · " +
                row.bitrate +
                " kbps";

            info.appendChild(title);
            info.appendChild(meta);

            const status =
                document.createElement("div");

            status.className =
                "status status-" +
                review.status;

            status.textContent =
                review.status;

            header.appendChild(info);
            header.appendChild(status);

            const body =
                document.createElement("div");

            body.className =
                "card-body";

            /*
             * CORREÇÃO PRINCIPAL
             *
             * O caminho já vem relativo à pasta
             * VoiceAudition.
             *
             * Exemplo:
             *
             * Batch_001/0001_731766908.wav
             */

            const audio =
                document.createElement("audio");

            audio.controls = true;

            audio.preload = "none";

            audio.src =
                row.audio;

            audio.title =
                "WEM " +
                row.wem;

            body.appendChild(audio);

            const grid =
                document.createElement("div");

            grid.className =
                "grid";

            function addField(
                labelText,
                field,
                value,
                options
            ) {

                const wrapper =
                    document.createElement("div");

                wrapper.className =
                    options &&
                    options.wide
                    ? "field field-wide"
                    : "field";

                const label =
                    document.createElement("label");

                label.textContent =
                    labelText;

                wrapper.appendChild(label);

                let control;

                if (
                    options &&
                    options.textarea
                ) {

                    control =
                        document.createElement(
                            "textarea"
                        );

                } else if (
                    options &&
                    options.select
                ) {

                    control =
                        document.createElement(
                            "select"
                        );

                    options.select.forEach(
                        function(optionValue) {

                            const option =
                                document.createElement(
                                    "option"
                                );

                            option.value =
                                optionValue;

                            option.textContent =
                                optionValue;

                            if (
                                optionValue ===
                                value
                            ) {
                                option.selected =
                                    true;
                            }

                            control.appendChild(
                                option
                            );
                        }
                    );

                } else {

                    control =
                        document.createElement(
                            "input"
                        );

                    control.type = "text";
                }

                control.value =
                    value || "";

                control.addEventListener(
                    "change",
                    function() {

                        updateReview(
                            row.index,
                            field,
                            control.value
                        );

                        render();
                    }
                );

                wrapper.appendChild(control);

                grid.appendChild(wrapper);
            }

            addField(
                "Tipo",
                "type",
                review.type,
                {
                    select: [
                        "VOICE",
                        "BREATH",
                        "PAIN",
                        "GRUNT",
                        "OTHER",
                        "NOT_VOICE"
                    ]
                }
            );

            addField(
                "Status",
                "status",
                review.status,
                {
                    select: [
                        "PENDING",
                        "REVIEWED",
                        "PROBLEM"
                    ]
                }
            );

            addField(
                "Personagem",
                "character",
                review.character,
                {}
            );

            addField(
                "Contexto",
                "context",
                review.context,
                {}
            );

            addField(
                "Texto original",
                "originalText",
                review.originalText,
                {
                    textarea: true,
                    wide: true
                }
            );

            addField(
                "Texto PT-BR",
                "ptbrText",
                review.ptbrText,
                {
                    textarea: true,
                    wide: true
                }
            );

            addField(
                "Observações",
                "notes",
                review.notes,
                {
                    textarea: true,
                    wide: true
                }
            );

            body.appendChild(grid);

            card.appendChild(header);
            card.appendChild(body);

            catalog.appendChild(card);
        });
    }

    document.getElementById("counter").textContent =
        filteredRows.length +
        " registros encontrados de " +
        DATA.length +
        " totais.";

    document.getElementById("pageInfo").textContent =
        "Página " +
        currentPage +
        " / " +
        totalPages;

    document.getElementById("previousButton").disabled =
        currentPage <= 1;

    document.getElementById("nextButton").disabled =
        currentPage >= totalPages;
}

function csvEscape(value) {

    return '"' +
        String(value || "")
            .replace(/"/g, '""') +
        '"';
}

function exportCSV() {

    const headers = [

        "Index",
        "WEM",
        "EventID",
        "ActionID",
        "SoundID",
        "SourceID",
        "DurationSec",
        "BitrateKbps",
        "Encoding",
        "Type",
        "Character",
        "Context",
        "Status",
        "OriginalText",
        "PTBRText",
        "Notes"

    ];

    const lines = [];

    lines.push(
        headers.map(csvEscape).join(",")
    );

    DATA.forEach(function(row) {

        const review =
            getReview(row.index);

        const values = [

            row.index,
            row.wem,
            row.eventID,
            row.actionID,
            row.soundID,
            row.sourceID,
            row.duration,
            row.bitrate,
            row.encoding,
            review.type,
            review.character,
            review.context,
            review.status,
            review.originalText,
            review.ptbrText,
            review.notes

        ];

        lines.push(
            values.map(csvEscape).join(",")
        );
    });

    const blob =
        new Blob(
            [lines.join("\r\n")],
            {
                type:
                    "text/csv;charset=utf-8"
            }
        );

    const url =
        URL.createObjectURL(blob);

    const link =
        document.createElement("a");

    link.href = url;

    link.download =
        "voice_review_export.csv";

    document.body.appendChild(link);

    link.click();

    link.remove();

    URL.revokeObjectURL(url);
}

document
    .getElementById("search")
    .addEventListener(
        "input",
        function() {

            currentPage = 1;

            render();
        }
    );

document
    .getElementById("statusFilter")
    .addEventListener(
        "change",
        function() {

            currentPage = 1;

            render();
        }
    );

document
    .getElementById("typeFilter")
    .addEventListener(
        "change",
        function() {

            currentPage = 1;

            render();
        }
    );

document
    .getElementById("previousButton")
    .addEventListener(
        "click",
        function() {

            if (currentPage > 1) {

                currentPage--;

                render();

                window.scrollTo(0, 0);
            }
        }
    );

document
    .getElementById("nextButton")
    .addEventListener(
        "click",
        function() {

            const totalPages =
                Math.max(
                    1,
                    Math.ceil(
                        filteredRows.length /
                        PAGE_SIZE
                    )
                );

            if (currentPage < totalPages) {

                currentPage++;

                render();

                window.scrollTo(0, 0);
            }
        }
    );

document
    .getElementById("exportButton")
    .addEventListener(
        "click",
        exportCSV
    );

document
    .getElementById("clearStorageButton")
    .addEventListener(
        "click",
        function() {

            if (
                !confirm(
                    "Limpar todas as alterações salvas localmente?"
                )
            ) {
                return;
            }

            localStorage.removeItem(
                STORAGE_KEY
            );

            reviews = {};

            render();
        }
    );

document.addEventListener(
    "keydown",
    function(event) {

        const tag =
            event.target.tagName;

        if (
            tag === "INPUT" ||
            tag === "TEXTAREA" ||
            tag === "SELECT"
        ) {
            return;
        }

        if (event.key === "ArrowLeft") {

            document
                .getElementById(
                    "previousButton"
                )
                .click();

        } else if (
            event.key === "ArrowRight"
        ) {

            document
                .getElementById(
                    "nextButton"
                )
                .click();
        }
    }
);

render();

</script>

</body>

</html>
"@

$HtmlContent =
    $HtmlTemplate.Replace(
        "__DATA_JSON__",
        $DataJson
    )

Set-Content `
    -Path $Html `
    -Value $HtmlContent `
    -Encoding UTF8

# ============================================================
# RELATORIO
# ============================================================

$ReportContent = @"
VOICE REVIEW CATALOG - SCRIPT 15

Data: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Manifest:
$Manifest

Registros:
$($Records.Count)

Template:
$Template

HTML:
$Html

Correcao principal:
O player utiliza diretamente:

audio.src = row.audio

Exemplo esperado:

Batch_001/0001_731766908.wav

Funcoes:
- busca
- filtro por status
- filtro por tipo
- paginacao
- player de audio
- personagem
- contexto
- texto original
- texto PT-BR
- observacoes
- localStorage
- exportacao CSV
- navegacao por teclado
"@

Set-Content `
    -Path $Report `
    -Value $ReportContent `
    -Encoding UTF8

# ============================================================
# VALIDACAO
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host " VALIDACAO"
Write-Host "============================================================"
Write-Host ""

$AudioSourceCount =
    (
        Select-String `
            -Path $Html `
            -Pattern "audio.src = row.audio" `
            -SimpleMatch
    ).Count

$BlankSourceCount =
    (
        Select-String `
            -Path $Html `
            -Pattern 'src=""' `
            -SimpleMatch
    ).Count

$FirstAudioPresent =
    (
        Select-String `
            -Path $Html `
            -Pattern "Batch_001/0001_731766908.wav" `
            -SimpleMatch
    ).Count

$EventPresent =
    (
        Select-String `
            -Path $Html `
            -Pattern "row.eventID" `
            -SimpleMatch
    ).Count

Write-Host "Registros:              $($Records.Count)"
Write-Host "audio.src encontrado:   $AudioSourceCount"
Write-Host "src vazio encontrado:   $BlankSourceCount"
Write-Host "Primeiro WAV no HTML:   $FirstAudioPresent"
Write-Host "EventID no JavaScript:  $EventPresent"

if ($Records.Count -ne 1144) {
    Write-Warning "Quantidade diferente de 1144 registros."
}

if ($AudioSourceCount -lt 1) {
    throw "FALHA: audio.src = row.audio nao encontrado."
}

if ($BlankSourceCount -gt 0) {
    throw "FALHA: existe src vazio no HTML."
}

if ($FirstAudioPresent -lt 1) {
    throw "FALHA: primeiro WAV nao encontrado no HTML."
}

if ($EventPresent -lt 1) {
    throw "FALHA: EventID nao encontrado no JavaScript."
}

Write-Host ""
Write-Host "VALIDACAO OK."
Write-Host ""

# ============================================================
# GIT
# ============================================================

Set-Location $Repo

git add `
    "Scripts/15_Create_Voice_Review_Catalog.ps1" `
    "Analysis/WEM/voice_review_template.csv" `
    "Analysis/Reports/voice_review_catalog_report.txt"

Write-Host "----- STATUS GIT -----"
git status --short

git commit `
    -m "Fix voice review catalog audio generation"

if ($LASTEXITCODE -eq 0) {

    git push origin main

} else {

    Write-Host ""
    Write-Host "Commit nao criado. Verifique o status acima."
}

Write-Host ""
Write-Host "============================================================"
Write-Host " SCRIPT 15 CONCLUIDO"
Write-Host "============================================================"
Write-Host ""

git log -1 --oneline
