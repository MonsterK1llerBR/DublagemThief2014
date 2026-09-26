$ErrorActionPreference = "Stop"

$Repo = "B:\DublagemThief2014"

$ReviewCsv = Join-Path $Repo "Analysis\WEM\voice_review_template.csv"
$GraphCsv = Join-Path $Repo "Analysis\BNK\hirc_object_graph.csv"
$TechnicalCsv = Join-Path $Repo "Analysis\WEM\wem_technical_inventory.csv"

$OutputDir = "B:\Thief2014_Dubbing\Work\VoiceAudition"
$OutputHtml = Join-Path $OutputDir "classification.html"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " VOICE CLASSIFICATION CATALOG - SCRIPT 16"
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# VALIDACAO
# ============================================================

foreach ($File in @(
    $ReviewCsv,
    $GraphCsv,
    $TechnicalCsv
)) {

    if (!(Test-Path $File)) {

        throw "Arquivo nao encontrado: $File"

    }

}

New-Item `
    -ItemType Directory `
    -Force `
    -Path $OutputDir |
    Out-Null

# ============================================================
# LEITURA
# ============================================================

Write-Host "Carregando catalogo original..."

$ReviewRows =
    Import-Csv `
        -Path $ReviewCsv

Write-Host (
    "Registros do catalogo original: {0}" -f
    $ReviewRows.Count
)

Write-Host "Carregando grafo HIRC..."

$GraphRows =
    Import-Csv `
        -Path $GraphCsv

Write-Host (
    "Registros HIRC: {0}" -f
    $GraphRows.Count
)

Write-Host "Carregando inventario tecnico..."

$TechnicalRows =
    Import-Csv `
        -Path $TechnicalCsv

Write-Host (
    "Registros tecnicos: {0}" -f
    $TechnicalRows.Count
)

# ============================================================
# FUNCAO GENERICA DE PROPRIEDADE
# ============================================================

function Get-PropertyValue {

    param(
        [Parameter(Mandatory=$true)]
        $Object,

        [Parameter(Mandatory=$true)]
        [string[]]$Names
    )

    foreach ($Name in $Names) {

        $Property =
            $Object.PSObject.Properties |
            Where-Object {
                $_.Name -ieq $Name
            } |
            Select-Object -First 1

        if ($null -ne $Property) {

            $Value =
                [string]$Property.Value

            if (
                -not [string]::IsNullOrWhiteSpace(
                    $Value
                )
            ) {

                return $Value

            }

        }

    }

    return ""

}

# ============================================================
# INDEXAR GRAFO POR WEM
# ============================================================

$GraphByWem = @{}

foreach ($Row in $GraphRows) {

    $Wem =
        Get-PropertyValue $Row @(
            "WEM",
            "wem",
            "Wem"
        )

    $SourceID =
        Get-PropertyValue $Row @(
            "SourceID",
            "sourceID",
            "SourceId"
        )

    if (
        [string]::IsNullOrWhiteSpace($Wem) -and
        -not [string]::IsNullOrWhiteSpace($SourceID)
    ) {

        $Wem =
            "$SourceID.wem"

    }

    if (
        -not [string]::IsNullOrWhiteSpace($Wem)
    ) {

        $Key =
            [System.IO.Path]::GetFileName(
                $Wem
            ).ToLowerInvariant()

        if (
            -not $GraphByWem.ContainsKey($Key)
        ) {

            $GraphByWem[$Key] =
                $Row

        }

    }

}

Write-Host (
    "WEM indexados no grafo: {0}" -f
    $GraphByWem.Count
)

# ============================================================
# INDEXAR INVENTARIO TECNICO POR WEM
# ============================================================

$TechnicalByWem = @{}

foreach ($Row in $TechnicalRows) {

    $Wem =
        Get-PropertyValue $Row @(
            "WEM",
            "wem",
            "Wem"
        )

    if (
        -not [string]::IsNullOrWhiteSpace($Wem)
    ) {

        $Key =
            [System.IO.Path]::GetFileName(
                $Wem
            ).ToLowerInvariant()

        if (
            -not $TechnicalByWem.ContainsKey($Key)
        ) {

            $TechnicalByWem[$Key] =
                $Row

        }

    }

}

Write-Host (
    "WEM indexados tecnicamente: {0}" -f
    $TechnicalByWem.Count
)

# ============================================================
# MONTAR DADOS
#
# IMPORTANTE:
# A ORDEM E O AUDIO VEM DO voice_review_template.csv
#
# O GRAFO E O INVENTARIO APENAS ENRIQUECEM OS DADOS.
# ============================================================

$Data =
    New-Object System.Collections.Generic.List[object]

$Index = 0

foreach ($Review in $ReviewRows) {

    $Index++

    # --------------------------------------------------------
    # WEM
    # --------------------------------------------------------

    $WEM =
        Get-PropertyValue $Review @(
            "WEM",
            "wem"
        )

    # --------------------------------------------------------
    # BATCH ORIGINAL
    # --------------------------------------------------------

    $Batch =
        Get-PropertyValue $Review @(
            "Batch",
            "batch"
        )

    # --------------------------------------------------------
    # AUDIO ORIGINAL
    # --------------------------------------------------------

    $Audio = ""

    $OriginalWav =
        Get-PropertyValue $Review @(
            "WAV",
            "wav"
        )

    if (
        -not [string]::IsNullOrWhiteSpace(
            $OriginalWav
        )
    ) {

        $Root =
            "B:\Thief2014_Dubbing\Work\VoiceAudition\"

        if (
            $OriginalWav.StartsWith(
                $Root,
                [System.StringComparison]::OrdinalIgnoreCase
            )
        ) {

            $Audio =
                $OriginalWav.Substring(
                    $Root.Length
                ) -replace '\\','/'

        }
        else {

            $Audio =
                $OriginalWav -replace '\\','/'

        }

    }

    # --------------------------------------------------------
    # FALLBACK DO AUDIO
    # --------------------------------------------------------

    if (
        [string]::IsNullOrWhiteSpace(
            $Audio
        )
    ) {

        if (
            -not [string]::IsNullOrWhiteSpace(
                $Batch
            ) -and
            -not [string]::IsNullOrWhiteSpace(
                $WEM
            )
        ) {

            $WemBase =
                [System.IO.Path]::GetFileNameWithoutExtension(
                    $WEM
                )

            $Position =
                $Index

            $PositionInBatch =
                (($Position - 1) % 100) + 1

            $AudioFile =
                "{0:D4}_{1}.wav" -f `
                    $PositionInBatch,
                    $WemBase

            $Audio =
                "$Batch/$AudioFile"

        }

    }

    # --------------------------------------------------------
    # CHAVE DO WEM
    # --------------------------------------------------------

    $WemKey = ""

    if (
        -not [string]::IsNullOrWhiteSpace(
            $WEM
        )
    ) {

        $WemKey =
            [System.IO.Path]::GetFileName(
                $WEM
            ).ToLowerInvariant()

    }

    # --------------------------------------------------------
    # GRAFO
    # --------------------------------------------------------

    $Graph = $null

    if (
        $GraphByWem.ContainsKey(
            $WemKey
        )
    ) {

        $Graph =
            $GraphByWem[$WemKey]

    }

    # --------------------------------------------------------
    # METADADOS DO GRAFO
    # --------------------------------------------------------

    $EventID = ""
    $ActionID = ""
    $SoundID = ""
    $SourceID = ""

    if ($null -ne $Graph) {

        $EventID =
            Get-PropertyValue $Graph @(
                "EventID",
                "eventID",
                "EventId"
            )

        $ActionID =
            Get-PropertyValue $Graph @(
                "ActionID",
                "actionID",
                "ActionId"
            )

        $SoundID =
            Get-PropertyValue $Graph @(
                "SoundID",
                "soundID",
                "SoundId"
            )

        $SourceID =
            Get-PropertyValue $Graph @(
                "SourceID",
                "sourceID",
                "SourceId"
            )

    }

    # --------------------------------------------------------
    # FALLBACK PARA CAMPOS DO REVIEW
    # --------------------------------------------------------

    if ([string]::IsNullOrWhiteSpace($EventID)) {

        $EventID =
            Get-PropertyValue $Review @(
                "EventID",
                "eventID"
            )

    }

    if ([string]::IsNullOrWhiteSpace($ActionID)) {

        $ActionID =
            Get-PropertyValue $Review @(
                "ActionID",
                "actionID"
            )

    }

    if ([string]::IsNullOrWhiteSpace($SoundID)) {

        $SoundID =
            Get-PropertyValue $Review @(
                "SoundID",
                "soundID"
            )

    }

    if ([string]::IsNullOrWhiteSpace($SourceID)) {

        $SourceID =
            Get-PropertyValue $Review @(
                "SourceID",
                "sourceID"
            )

    }

    # --------------------------------------------------------
    # INVENTARIO TECNICO
    # --------------------------------------------------------

    $Technical = $null

    if (
        $TechnicalByWem.ContainsKey(
            $WemKey
        )
    ) {

        $Technical =
            $TechnicalByWem[$WemKey]

    }

    $Duration = ""
    $Bitrate = ""
    $Encoding = ""
    $SampleRate = ""
    $Channels = ""

    if ($null -ne $Technical) {

        $Duration =
            Get-PropertyValue $Technical @(
                "DurationSec",
                "duration",
                "Duration"
            )

        $Bitrate =
            Get-PropertyValue $Technical @(
                "BitrateKbps",
                "bitrate",
                "Bitrate"
            )

        $Encoding =
            Get-PropertyValue $Technical @(
                "Encoding",
                "encoding"
            )

        $SampleRate =
            Get-PropertyValue $Technical @(
                "SampleRate",
                "sampleRate"
            )

        $Channels =
            Get-PropertyValue $Technical @(
                "Channels",
                "channels"
            )

    }

    # --------------------------------------------------------
    # FALLBACK TECNICO
    # --------------------------------------------------------

    if ([string]::IsNullOrWhiteSpace($Duration)) {

        $Duration =
            Get-PropertyValue $Review @(
                "DurationSec",
                "duration"
            )

    }

    if ([string]::IsNullOrWhiteSpace($Bitrate)) {

        $Bitrate =
            Get-PropertyValue $Review @(
                "BitrateKbps",
                "bitrate"
            )

    }

    if ([string]::IsNullOrWhiteSpace($Encoding)) {

        $Encoding =
            Get-PropertyValue $Review @(
                "Encoding",
                "encoding"
            )

    }

    if ([string]::IsNullOrWhiteSpace($SampleRate)) {

        $SampleRate =
            Get-PropertyValue $Review @(
                "SampleRate",
                "sampleRate"
            )

    }

    if ([string]::IsNullOrWhiteSpace($Channels)) {

        $Channels =
            Get-PropertyValue $Review @(
                "Channels",
                "channels"
            )

    }

    # --------------------------------------------------------
    # REGISTRO FINAL
    # --------------------------------------------------------

    $Data.Add(
        [PSCustomObject]@{

            index      = [string]$Index

            batch      = $Batch

            wem        = $WEM

            audio      = $Audio

            eventID    = $EventID
            actionID   = $ActionID
            soundID    = $SoundID
            sourceID   = $SourceID

            duration   = $Duration
            bitrate    = $Bitrate
            encoding   = $Encoding
            sampleRate = $SampleRate
            channels   = $Channels

        }
    )

}

# ============================================================
# VALIDACAO
# ============================================================

$Total =
    $Data.Count

$AudioCount =
    @(
        $Data |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace(
                $_.audio
            )
        }
    ).Count

$EventCount =
    @(
        $Data |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace(
                $_.eventID
            )
        }
    ).Count

$ActionCount =
    @(
        $Data |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace(
                $_.actionID
            )
        }
    ).Count

$SoundCount =
    @(
        $Data |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace(
                $_.soundID
            )
        }
    ).Count

$SourceCount =
    @(
        $Data |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace(
                $_.sourceID
            )
        }
    ).Count

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " VALIDACAO"
Write-Host "============================================================" -ForegroundColor Green

Write-Host ("Total:          {0}" -f $Total)
Write-Host ("Audios:         {0}" -f $AudioCount)
Write-Host ("EventID:        {0}" -f $EventCount)
Write-Host ("ActionID:       {0}" -f $ActionCount)
Write-Host ("SoundID:        {0}" -f $SoundCount)
Write-Host ("SourceID:       {0}" -f $SourceCount)

if ($Total -gt 0) {

    Write-Host ""
    Write-Host "PRIMEIRO REGISTRO:" -ForegroundColor Yellow

    $Data[0] |
        Format-List

}

# ============================================================
# JSON
# ============================================================

$Json =
    $Data |
    ConvertTo-Json `
        -Compress `
        -Depth 5

# ============================================================
# HTML
# ============================================================

$Html = @"
<!DOCTYPE html>

<html lang="pt-BR">

<head>

<meta charset="UTF-8">

<title>Thief 2014 - Classificação de Voz</title>

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
    z-index: 20;

    padding: 14px 18px;

    background: #181818;
    border-bottom: 1px solid #333;
}

h1 {
    margin: 0 0 10px 0;
    font-size: 22px;
}

.toolbar {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    align-items: center;
}

button,
select,
input {
    background: #222;
    color: #eee;
    border: 1px solid #444;
    border-radius: 5px;
    padding: 7px 10px;
}

button {
    cursor: pointer;
}

button:hover {
    background: #333;
}

.counter {
    margin-left: auto;
    font-weight: bold;
}

#search {
    width: 280px;
}

main {
    padding: 18px;
}

.card {
    background: #191919;
    border: 1px solid #333;
    border-radius: 8px;
    margin-bottom: 12px;
    overflow: hidden;
}

.card.pending {
    border-left: 4px solid #777;
}

.card.done {
    border-left: 4px solid #4caf50;
}

.card-header {
    padding: 10px 14px;
    background: #202020;

    display: flex;
    justify-content: space-between;
    gap: 15px;
}

.title {
    font-size: 16px;
    font-weight: bold;
}

.meta {
    color: #aaa;
    font-size: 12px;
    margin-top: 4px;
}

.status {
    font-weight: bold;
}

.card-body {
    padding: 14px;
}

audio {
    width: 100%;
    margin-bottom: 12px;
}

.classification {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    margin-bottom: 12px;
}

.classification button.active {
    outline: 2px solid #fff;
}

.fields {
    display: grid;
    grid-template-columns: 1fr 2fr;
    gap: 8px;
}

.fields label {
    color: #aaa;
    padding-top: 7px;
}

.fields input,
.fields textarea {
    width: 100%;

    background: #111;
    color: #eee;

    border: 1px solid #444;
    border-radius: 5px;

    padding: 8px;
}

.fields textarea {
    min-height: 70px;
    resize: vertical;
}

.nav {
    display: flex;
    gap: 8px;
    margin-top: 12px;
}

.small {
    color: #888;
    font-size: 11px;
    margin-top: 12px;
}

</style>

</head>

<body>

<header>

<h1>Thief 2014 - Classificação de Voz</h1>

<div class="toolbar">

<button onclick="previousItem()">⏮ Anterior</button>

<button onclick="nextItem()">Próximo ⏭</button>

<select id="filter" onchange="render()">

<option value="ALL">Todos</option>
<option value="PENDING">Pendentes</option>
<option value="FALA">Fala</option>
<option value="GRITO">Grito</option>
<option value="VOCALIZACAO">Vocalização</option>
<option value="EFEITO">Efeito</option>
<option value="DESCARTAR">Descartar</option>

</select>

<input
    id="search"
    placeholder="Buscar WEM / EventID / personagem..."
    oninput="render()"
/>

<button onclick="exportCSV()">
Exportar CSV
</button>

<button onclick="clearAll()">
Limpar classificação
</button>

<div class="counter" id="counter"></div>

</div>

<div class="small">
← anterior · → próximo ·
1 FALA · 2 GRITO · 3 VOCALIZAÇÃO ·
4 EFEITO · 5 DESCARTAR
</div>

</header>

<main id="app"></main>

<script>

const DATA = $Json;

const STORAGE_KEY =
    "thief2014_voice_classification_v3";

let review =
    JSON.parse(
        localStorage.getItem(
            STORAGE_KEY
        ) || "{}"
    );

let visibleRows = [];

let currentPosition = 0;

function getReview(index) {

    if (!review[index]) {

        review[index] = {

            classification: "PENDENTE",
            character: "",
            transcript: "",
            notes: ""

        };

    }

    return review[index];

}

function save() {

    localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify(review)
    );

}

function classify(index, value) {

    const r =
        getReview(index);

    r.classification =
        value;

    save();

    render();

}

function updateField(
    index,
    field,
    value
) {

    const r =
        getReview(index);

    r[field] =
        value;

    save();

}

function matchesSearch(row) {

    const query =
        document
            .getElementById("search")
            .value
            .trim()
            .toLowerCase();

    if (!query) {
        return true;
    }

    const r =
        getReview(row.index);

    const text = [

        row.wem,
        row.eventID,
        row.actionID,
        row.soundID,
        row.sourceID,

        r.character,
        r.transcript,
        r.notes

    ].join(" ").toLowerCase();

    return text.includes(query);

}

function matchesFilter(row) {

    const filter =
        document
            .getElementById("filter")
            .value;

    if (filter === "ALL") {
        return true;
    }

    const r =
        getReview(row.index);

    if (filter === "PENDING") {

        return (
            r.classification ===
            "PENDENTE"
        );

    }

    return (
        r.classification ===
        filter
    );

}

function render() {

    const app =
        document.getElementById(
            "app"
        );

    visibleRows =
        DATA.filter(
            row =>
                matchesFilter(row) &&
                matchesSearch(row)
        );

    if (
        currentPosition >=
        visibleRows.length
    ) {

        currentPosition =
            Math.max(
                0,
                visibleRows.length - 1
            );

    }

    app.innerHTML = "";

    visibleRows.forEach(
        row => {

            const r =
                getReview(
                    row.index
                );

            const card =
                document.createElement(
                    "section"
                );

            card.className =
                "card " +
                (
                    r.classification ===
                    "PENDENTE"
                        ? "pending"
                        : "done"
                );

            const header =
                document.createElement(
                    "div"
                );

            header.className =
                "card-header";

            const titleBlock =
                document.createElement(
                    "div"
                );

            const title =
                document.createElement(
                    "div"
                );

            title.className =
                "title";

            title.textContent =
                "#" +
                row.index +
                " · " +
                row.wem;

            const meta =
                document.createElement(
                    "div"
                );

            meta.className =
                "meta";

            meta.textContent =
                "Event " +
                row.eventID +
                " · Action " +
                row.actionID +
                " · Sound " +
                row.soundID +
                " · Source " +
                row.sourceID +
                " · " +
                row.duration +
                "s · " +
                row.bitrate +
                " kbps";

            titleBlock.appendChild(title);
            titleBlock.appendChild(meta);

            const status =
                document.createElement(
                    "div"
                );

            status.className =
                "status";

            status.textContent =
                r.classification;

            header.appendChild(titleBlock);
            header.appendChild(status);

            const body =
                document.createElement(
                    "div"
                );

            body.className =
                "card-body";

            const audio =
                document.createElement(
                    "audio"
                );

            audio.controls = true;
            audio.preload = "none";

            /*
             * O caminho vem diretamente do
             * voice_review_template.csv.
             *
             * Portanto ele corresponde exatamente
             * aos WAVs gerados pelo Script 14.
             */

            audio.src =
                row.audio.replace(
                    /\\/g,
                    "/"
                );

            body.appendChild(audio);

            const classification =
                document.createElement(
                    "div"
                );

            classification.className =
                "classification";

            const types = [

                ["1", "FALA"],
                ["2", "GRITO"],
                ["3", "VOCALIZACAO"],
                ["4", "EFEITO"],
                ["5", "DESCARTAR"]

            ];

            types.forEach(
                item => {

                    const button =
                        document.createElement(
                            "button"
                        );

                    button.textContent =
                        item[0] +
                        " · " +
                        item[1];

                    if (
                        r.classification ===
                        item[1]
                    ) {

                        button.classList.add(
                            "active"
                        );

                    }

                    button.onclick =
                        () =>
                            classify(
                                row.index,
                                item[1]
                            );

                    classification.appendChild(
                        button
                    );

                }
            );

            body.appendChild(
                classification
            );

            const fields =
                document.createElement(
                    "div"
                );

            fields.className =
                "fields";

            const characterLabel =
                document.createElement(
                    "label"
                );

            characterLabel.textContent =
                "Personagem";

            const character =
                document.createElement(
                    "input"
                );

            character.value =
                r.character;

            character.placeholder =
                "Ex.: Garrett";

            character.oninput =
                event =>
                    updateField(
                        row.index,
                        "character",
                        event.target.value
                    );

            fields.appendChild(
                characterLabel
            );

            fields.appendChild(
                character
            );

            const transcriptLabel =
                document.createElement(
                    "label"
                );

            transcriptLabel.textContent =
                "Transcrição";

            const transcript =
                document.createElement(
                    "textarea"
                );

            transcript.value =
                r.transcript;

            transcript.placeholder =
                "Texto original da fala...";

            transcript.oninput =
                event =>
                    updateField(
                        row.index,
                        "transcript",
                        event.target.value
                    );

            fields.appendChild(
                transcriptLabel
            );

            fields.appendChild(
                transcript
            );

            const notesLabel =
                document.createElement(
                    "label"
                );

            notesLabel.textContent =
                "Observações";

            const notes =
                document.createElement(
                    "textarea"
                );

            notes.value =
                r.notes;

            notes.placeholder =
                "Contexto, emoção, intenção, ruído, etc.";

            notes.oninput =
                event =>
                    updateField(
                        row.index,
                        "notes",
                        event.target.value
                    );

            fields.appendChild(
                notesLabel
            );

            fields.appendChild(
                notes
            );

            body.appendChild(fields);

            const nav =
                document.createElement(
                    "div"
                );

            nav.className =
                "nav";

            const prev =
                document.createElement(
                    "button"
                );

            prev.textContent =
                "⏮ Anterior";

            prev.onclick =
                previousItem;

            const next =
                document.createElement(
                    "button"
                );

            next.textContent =
                "Próximo ⏭";

            next.onclick =
                nextItem;

            nav.appendChild(prev);
            nav.appendChild(next);

            body.appendChild(nav);

            card.appendChild(header);
            card.appendChild(body);

            app.appendChild(card);

        }
    );

    updateCounter();

}

function updateCounter() {

    const total =
        DATA.length;

    let classified = 0;

    DATA.forEach(
        row => {

            if (
                getReview(row.index)
                    .classification !==
                "PENDENTE"
            ) {

                classified++;

            }

        }
    );

    document.getElementById(
        "counter"
    ).textContent =
        classified +
        " / " +
        total +
        " classificados";

}

function nextItem() {

    if (
        visibleRows.length === 0
    ) {
        return;
    }

    if (
        currentPosition <
        visibleRows.length - 1
    ) {

        currentPosition++;

    }
    else {

        currentPosition = 0;

    }

    render();

}

function previousItem() {

    if (
        visibleRows.length === 0
    ) {
        return;
    }

    if (
        currentPosition > 0
    ) {

        currentPosition--;

    }
    else {

        currentPosition =
            visibleRows.length - 1;

    }

    render();

}

function exportCSV() {

    const headers = [

        "Index",
        "Batch",
        "WEM",
        "EventID",
        "ActionID",
        "SoundID",
        "SourceID",
        "DurationSec",
        "BitrateKbps",
        "Encoding",
        "SampleRate",
        "Channels",
        "Classification",
        "Character",
        "Transcript",
        "Notes"

    ];

    const lines =
        [headers];

    DATA.forEach(
        row => {

            const r =
                getReview(row.index);

            lines.push([

                row.index,
                row.batch,
                row.wem,

                row.eventID,
                row.actionID,
                row.soundID,
                row.sourceID,

                row.duration,
                row.bitrate,
                row.encoding,
                row.sampleRate,
                row.channels,

                r.classification,
                r.character,
                r.transcript,
                r.notes

            ]);

        }
    );

    const csv =
        lines
            .map(
                row =>
                    row
                        .map(
                            value =>
                                '"' +
                                String(
                                    value ?? ""
                                )
                                .replace(
                                    /"/g,
                                    '""'
                                ) +
                                '"'
                        )
                        .join(",")
            )
            .join("\r\n");

    const blob =
        new Blob(
            [
                "\ufeff" +
                csv
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

    a.href = url;

    a.download =
        "thief2014_voice_classification.csv";

    a.click();

    URL.revokeObjectURL(url);

}

function clearAll() {

    if (
        !confirm(
            "Isso apagará todas as classificações, personagens, transcrições e observações deste navegador. Continuar?"
        )
    ) {

        return;

    }

    review = {};

    save();

    render();

}

document.addEventListener(
    "keydown",
    event => {

        const tag =
            event.target.tagName;

        if (
            tag === "INPUT" ||
            tag === "TEXTAREA" ||
            tag === "SELECT"
        ) {

            return;

        }

        if (
            event.key === "ArrowRight"
        ) {

            nextItem();

        }

        if (
            event.key === "ArrowLeft"
        ) {

            previousItem();

        }

        const types = {

            "1": "FALA",
            "2": "GRITO",
            "3": "VOCALIZACAO",
            "4": "EFEITO",
            "5": "DESCARTAR"

        };

        if (
            types[event.key] &&
            visibleRows.length
        ) {

            classify(
                visibleRows[
                    currentPosition
                ].index,
                types[event.key]
            );

        }

    }
);

render();

</script>

</body>

</html>
"@

Set-Content `
    -Path $OutputHtml `
    -Value $Html `
    -Encoding UTF8

# ============================================================
# VALIDACAO DO PRIMEIRO WAV
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " CATALOGO RECONSTRUIDO"
Write-Host "============================================================" -ForegroundColor Green

Write-Host ""
Write-Host ("Total:       {0}" -f $Total)
Write-Host ("Com audio:   {0}" -f $AudioCount)
Write-Host ("Com EventID: {0}" -f $EventCount)
Write-Host ("Com Action:  {0}" -f $ActionCount)
Write-Host ("Com Sound:   {0}" -f $SoundCount)
Write-Host ("Com Source:  {0}" -f $SourceCount)

if ($Total -gt 0) {

    Write-Host ""
    Write-Host "Primeiro audio:" -ForegroundColor Yellow
    Write-Host $Data[0].audio

    $FirstRelative =
        $Data[0].audio -replace '/','\'

    $FirstPhysical =
        Join-Path `
            $OutputDir `
            $FirstRelative

    Write-Host ""
    Write-Host "Primeiro arquivo fisico:" -ForegroundColor Yellow
    Write-Host $FirstPhysical

    if (Test-Path $FirstPhysical) {

        Write-Host "ARQUIVO EXISTE: SIM" -ForegroundColor Green

    }
    else {

        Write-Host "ARQUIVO EXISTE: NAO" -ForegroundColor Red

    }

}

Write-Host ""
Write-Host "HTML:"
Write-Host $OutputHtml

Write-Host ""
Write-Host "Abrindo catalogo..."

Start-Process $OutputHtml
