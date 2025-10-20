from pathlib import Path
from langchain_community.document_loaders import PyPDFLoader

from utilities.loader import clean
from core.milvus_client import MilvusClient


def run(pdf_path: str = r"C:\Workspace\scenario-generation-chatbot\data\docs-scenic-lang-org-en-latest.pdf") -> None:
    path = Path(pdf_path)
    if not path.exists():
        print(f"File not found: {path}")
        return

    loader = PyPDFLoader(str(path))
    pages = loader.load()
    full_text = "\n\n".join(page.page_content for page in pages)
    content = clean(full_text).strip()
    if not content:
        print("Empty content after loading/cleaning. Abort.")
        return

    milvus = MilvusClient()
    try:
        milvus.insert(content)
        print(f"Inserted PDF into Milvus (PyPDF): {path}")
    finally:
        milvus.close()


if __name__ == "__main__":
    run()
