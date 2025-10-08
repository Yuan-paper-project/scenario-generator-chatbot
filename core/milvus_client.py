from collections.abc import Collection
from langchain_milvus import Milvus
from langchain.schema import Document
from .config import get_settings
from langchain_ollama import OllamaEmbeddings
from langchain_huggingface import HuggingFaceEmbeddings
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_openai import OpenAIEmbeddings  

import gc

settings = get_settings()



class MilvusClient:
    def __init__(self):
        provider = (settings.EMBEDDING_PROVIDER or "huggingface").lower()
        if provider == "openai":
            print("Using OpenAI embeddings")
            if OpenAIEmbeddings is None:
                raise ImportError("langchain-openai is not installed. Please install langchain-openai and openai dependencies.")
            if not settings.OPENAI_API_KEY:
                raise ValueError("No OPENAI_API_KEY. Please set it in the environment variables or .env file.")
            self.embedding = OpenAIEmbeddings(
                api_key=settings.OPENAI_API_KEY,
                model=settings.OPENAI_EMBEDDING_MODEL,
            )
        else:
            print("Using HuggingFace embeddings")
            self.embedding = HuggingFaceEmbeddings(
                model=settings.EMBEDDING_MODEL,
                model_kwargs={"device": settings.DEVICE},
                encode_kwargs={"normalize_embeddings": True},
            )

        self.vector_store = Milvus(
            collection_name=settings.MILVUS_COLLECTION,
            embedding_function=self.embedding,
            connection_args={"uri": settings.MILVUS_URI, "token": settings.MILVUS_TOKEN},
        )
        self.text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=settings.CHUNK_SIZE,
            chunk_overlap=settings.CHUNK_OVERLAP,
        )

    def search(self, query: str) -> list[Document]:
        results = self.vector_store.similarity_search(query, k=settings.MAX_CHUNKS)
        return results

    def insert(self, content: str):
        documents = self.split_content(content)
        for doc in documents:
            self.vector_store.add_documents([doc])

    def split_content(self, content: str) -> list[Document]:
        return self.text_splitter.create_documents([content])

    def delete(self, ids: list[str]):
        self.vector_store.delete(ids)

    def close(self):
        try:
            if hasattr(self.vector_store, 'client') and hasattr(self.vector_store.client, 'close'):
                self.vector_store.client.close()
            
            if hasattr(self.embedding, 'client') and hasattr(self.embedding.client, 'model'):
                del self.embedding.client.model

            self.embedding = None
            self.vector_store = None
            self.text_splitter = None
            
            gc.collect()
            
        except Exception as e:
            print(f"❌ Error during MilvusClient cleanup: {e}")
