# Chat2Scenic

This repo contains a RAG-based framework for scenario generation and a chatbot for interactive use. The generation workflow is component-based (interpret → retrieve/generate components → assemble code) and can optionally use Milvus for retrieval.

## Quickstart

### 1) Python environment

Requires **Python 3.11 or 3.12**.

```bash
python -m venv .venv
\.venv\Scripts\activate
pip install -r requirements.txt
```

### 2) Configure `.env`

Copy `env.example` to `.env` and set the environment variables. Other settings can be configured in `core/config.py`.

### 3) Run the UI

```bash
python app.py
```

Open `http://127.0.0.1:7860`.

How the UI flow works:

1. Send a natural-language request.
2. The app proposes a **Logical Scenario Structure Representation**.
3. Reply `yes`/`ok` to confirm (or provide feedback to refine).
4. The generated Scenic code appears in the right panel.


## Repo layout (high level)

- `app.py`: Gradio UI entrypoint.
- `core/`: workflow, agents, prompts, embedding + LLM adapters, Milvus clients.
- `utilities/`: helper scripts (CARLA helpers, ingestion utilities, parsing, logging).
- `Benchmark/`: benchmark of scenario descriptions.
- `maps/`: CARLA maps.


## Server env

The code is located under `/home/dellpro2/wenting/scenario-generation-chatbot/`.

1. Start the database server: `docker start milvus_wenting`
2. Activate the virtual environment: `conda activate wenting`
3. Run the server: `python app.py`

**Reminder**: Do not install any other packages in this environment without discussing with the author in case to break the virtual env. 