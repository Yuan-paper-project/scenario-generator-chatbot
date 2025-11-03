from core.agents.base import BaseAgent
from typing import Dict

class RAGAgent(BaseAgent):
    def __init__(self, milvus_client=None):
        self.milvus_client = milvus_client
    
    def process(self, query: str, top_k: int = 5) -> str:
        if not self.milvus_client:
            return ""
        
        docs = self.milvus_client.search(query, top_k=top_k)
        context = "\n\n".join([doc.page_content for doc in docs])
        return context
    
    def invoke(self, context: Dict = None) -> str:
        """Not used for RAG agent."""
        raise NotImplementedError("RAG agent uses retrieval instead of LLM invocation")
