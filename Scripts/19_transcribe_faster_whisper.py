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
