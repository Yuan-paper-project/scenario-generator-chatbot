import gradio as gr
from core.milvus_client import MilvusClient
from core.workflow import ScenarioWorkflow
from core.agents import RAGAgent
import torch

class ChatbotApp:
    def __init__(self):
        self.milvus_client = MilvusClient()
        # Create RAG agent for context retrieval
        self.rag_agent = RAGAgent(milvus_client=self.milvus_client)
        # Create workflow with RAG agent
        self.workflow = ScenarioWorkflow(thread_id="test-123", rag_agent=self.rag_agent)

    def respond(self, query, history):
        print(f"Received query: {query}")
        # Process query through the workflow
        # RAG retrieval happens automatically in the workflow
        response = self.workflow.process(user_input=query, use_memory=True)
        return response

    def close(self):
        if hasattr(self, "milvus_client") and self.milvus_client:
            self.milvus_client.close()
        
        try:
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
        except ImportError:
            pass

        
if __name__ == "__main__":
    app = ChatbotApp()
    try:
        gr.ChatInterface(
            fn=app.respond,
            title="Chatbot",
            description="Chatbot for generating DSL ",
        ).launch()
    finally:
        app.close()