# DSL-RAG Setup & Usage Guide

## 1. Environment Setup

This project recommends using [uv](https://github.com/astral-sh/uv) for Python dependency management.

### Step 1: Install uv

If you haven't installed uv yet, use pip:

```bash
pip install uv
```

### Step 2: Install dependencies

In the project root directory, run:

```bash 
uv venv --python 3.11
source .venv/bin/activate
```


```bash
uv pip install -r pyproject.toml
```

To add a new dependency (e.g., `unstructured[pdf]`):

```bash
uv add "unstructured[pdf]"
```

## 2. Configure Environment Variables

Set the following in a `.env` file or in `core/config.py` (for OpenAI usage):

```
OPENAI_API_KEY=your_openai_api_key
LLM_PROVIDER=openai
LLM_MODEL_NAME=gpt-3.5-turbo  # or gpt-4
```

If using Ollama, you can also configure local model parameters in `core/config.py`.

## 3. Run the Gradio App

In the project root directory, run:

```bash
python app.py
```

To create a public share link, change the last line in `app.py` to:

```python
gr.ChatInterface(...).launch(share=True)
```

## 4. Access

After running, the terminal will display a local access address (e.g., http://127.0.0.1:7860 ). Open it in your browser.

## 5. Milvus & Attu Docker Network Setup

To connect Attu to Milvus using Docker, follow these steps:

### Step 1: Create a Docker network

```bash
docker network create rag-net
```

### Step 2: Start Milvus and Attu containers on the same network

Example (adjust image tags as needed):

```bash
# Start Milvus Standalone
docker network connect rag-net container1
docker network connect rag-net container2
```

### Step 3: Connect Attu to Milvus

When opening the Attu web page (http://localhost:8000), set the Milvus address to:

```
milvus-standalone:19530/default
```

**Note:** Use the container name (`milvus-standalone`) instead of an IP address, since both containers are on the same Docker network.

---

If you encounter dependency conflicts or installation issues, first check your Python version (recommended: 3.11 or 3.12), and review the contents of `pyproject.toml` and `requirements.txt`.

For further help, contact the project maintainer.
