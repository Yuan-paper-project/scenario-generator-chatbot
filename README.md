# DSL-RAG Chatbot for Scenario Generation

A Retrieval-Augmented Generation (RAG) chatbot designed to assist with generating Scenic DSL code for autonomous driving scenarios.

## Project Structure

```
.
├── app.py              # Main Gradio web interface
├── core/              # Core functionality
│   ├── config.py     # Configuration and settings
│   ├── embedding.py  # Vector embeddings (OpenAI, HuggingFace, Google)
│   ├── llm.py       # LLM integration and DSL validation
│   └── milvus_client.py # Vector database client
├── utilities/        # Helper functions
│   ├── loader.py    # Document loading utilities
│   ├── ocr_converter.py # OCR processing
│   └── parser.py    # Scenic DSL parser
└── workflow/         # Data processing pipelines
    ├── markdown.py  # Markdown document processing
    └── pdf_ingest.py # PDF ingestion workflow
```

## Setup Instructions

### 1. Environment Setup (Python 3.11+)

This project uses [uv](https://github.com/astral-sh/uv) for dependency management.

```bash
# Install uv if not installed
pip install uv

# Create and activate virtual environment
uv venv --python 3.11
.\.venv\Scripts\activate  # Windows PowerShell
source .venv/bin/activate     # macOS/Linux

# Install dependencies
uv pip install -r pyproject.toml
```

### 2. Vector Database Setup

The project uses Milvus as the vector database. Set up using Docker:

```bash
# Create Docker network
docker network create rag-net

# Start Milvus standalone
docker run -d --name milvus-standalone --network rag-net \
    -p 19530:19530 \
    milvusdb/milvus:latest standalone

# Optional: Start Attu (Milvus UI)
docker run -d --name attu --network rag-net \
    -p 8000:3000 \
    zilliz/attu:latest
```

### 3. Configure Environment

Create a `.env` file in the project root with your API keys:

```env
# Required for embeddings (choose one)
OPENAI_API_KEY=your_openai_api_key
GOOGLE_API_KEY=your_google_api_key

# Optional for OCR
MISTRAL_OCR_KEY=your_mistral_key

# Vector DB (default values)
MILVUS_URI=http://localhost:19530
MILVUS_COLLECTION=gemini
```

Additional settings can be configured in `core/config.py`.

### 4. Running the Application

Start the Gradio web interface:

```bash
python app.py
```

Access the chatbot at `http://127.0.0.1:7860`

## Features

- RAG-powered chatbot for Scenic DSL code generation
- Multiple LLM providers supported (OpenAI, Google Gemini, Ollama)
- Automatic syntax validation of generated Scenic code
- PDF and Markdown document ingestion
- Vector similarity search using Milvus
- Error correction and retry mechanism

## Project Dependencies

Key dependencies (see `pyproject.toml` for complete list):
- LangChain ecosystem (Core, Community, OpenAI, etc.)
- Gradio for web interface
- Sentence Transformers for embeddings
- Unstructured for document processing
- LangGraph for workflow management

## Notes

- Python version required: 3.11 or 3.12
- CUDA support available for GPU acceleration
- Local models supported via Ollama
- See `notes/` directory for additional documentation

For issues or questions, please contact the project maintainer.

## Run CARLA in server
```
cd ~/caiwang/carla
source caiwang-venv/bin/activate
make launch   # or make run
```


### Fixing bug of carla
```
tasklist | findstr /I carla
taskkill /F /IM CarlaUE4.exe
taskkill /F /IM CarlaUE4-Win64-Shipping.exe
```