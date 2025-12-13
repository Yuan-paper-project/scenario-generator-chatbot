import os
from pathlib import Path
from langchain_community.document_loaders import TextLoader
from core.milvus_client import MilvusClient

def insert_documentation(path: str) -> None:
    loader = TextLoader(path, encoding='utf-8')
    documents = loader.load()
    print(f"Loaded {len(documents)} document(s).")
    
    milvus = MilvusClient(collection_name="documentation_new", embedding_provider="google_genai", embedding_model_name="models/gemini-embedding-001")
    for doc in documents:
        milvus.insert(doc.page_content)
    print(f"Inserted documentation into Milvus: {path}")
  
if __name__ == "__main__":
    data_folder = Path(r"C:\Workspace\scenario-generation-chatbot\data\documentation\markdown_test")
    
    data = list(data_folder.glob("*.md"))
    
    print(f"Found {len(data)} markdown file(s) to insert.")
    for file_path in data:
        print(f"\n{'='*60}")
        print(f"Processing: {file_path.name}")
        print(f"{'='*60}")
        insert_documentation(str(file_path))
    print(f"\n{'='*60}")
    print(f"Completed! Inserted {len(data)} file(s) into Milvus.")
    print(f"{'='*60}")