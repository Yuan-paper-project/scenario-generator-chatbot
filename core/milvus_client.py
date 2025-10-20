from collections.abc import Collection
from langchain_milvus import Milvus
from langchain.schema import Document
from langchain.text_splitter import RecursiveCharacterTextSplitter
from .config import get_settings
from .embedding import EmbeddingModel

import gc
import logging
import time

settings = get_settings()
logger = logging.getLogger(__name__)

class MilvusClient:
    def __init__(self):
        try:
            self.embedding_model = EmbeddingModel()
            logger.info(f"Using {self.embedding_model.provider} embeddings")
            self.embedding = self.embedding_model.embedding
        except Exception as e:
            logger.error(f"Failed to initialize embedding model: {e}")
            raise

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
        """
        Clean up resources used by the MilvusClient
        """
        try:
            # Clean up vector store
            if hasattr(self.vector_store, 'client') and hasattr(self.vector_store.client, 'close'):
                self.vector_store.client.close()
            
            # Clean up embedding model
            if self.embedding_model:
                self.embedding_model.close()
            
            # Clear references
            self.embedding_model = None
            self.embedding = None
            self.vector_store = None
            self.text_splitter = None
            
            # Force garbage collection
            gc.collect()
            
            logger.info("Successfully cleaned up MilvusClient resources")
            
        except Exception as e:
            logger.error(f"Error during MilvusClient cleanup: {e}")
