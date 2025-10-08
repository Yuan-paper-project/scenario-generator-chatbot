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
uv pip install -r requirements.txt
```

Or install all dependencies directly from `pyproject.toml`:

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

---

If you encounter dependency conflicts or installation issues, first check your Python version (recommended: 3.11 or 3.12), and review the contents of `pyproject.toml` and `requirements.txt`.

For further help, contact the project maintainer.
