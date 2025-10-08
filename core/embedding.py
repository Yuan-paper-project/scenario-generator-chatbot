from langchain.embeddings import HuggingFaceEmbeddings
import torch


class EmbeddingModel:
    def __init__(self, model_name="BAAI/bge-base-en", device=None):
        device = device or ("cuda" if torch.cuda.is_available() else "cpu")
        self.embedding = HuggingFaceEmbeddings(
            model_name=model_name,
            model_kwargs={"device": device},
            encode_kwargs={"normalize_embeddings": True},
        )

    def encode(self, text: str) -> list[float]:
        return self.embedding.embed_query(text)