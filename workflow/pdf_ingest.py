from pathlib import Path
from langchain_core.documents import Document

from utilities.loader import load_pdf
from core.milvus_client import MilvusClient


def run(pdf_path: str = r"C:\TUM\DSL_RAG\data\docs-scenic-lang-org-en-latest.pdf") -> None:
    path = Path(pdf_path)
    if not path.exists():
        print(f"File not found: {path}")
        return

    doc: Document | None = load_pdf(path)
    if not doc or not doc.page_content.strip():
        print("Empty content after loading/cleaning. Abort.")
        return

    milvus = MilvusClient()
    try:
        milvus.insert(doc.page_content)
        print(f"Inserted PDF into Milvus: {path}")
    finally:
        milvus.close()


if __name__ == "__main__":
    run()
