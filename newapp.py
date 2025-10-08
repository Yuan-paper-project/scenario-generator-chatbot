import gradio as gr
from core.milvus_client import MilvusClient
from core.llm3 import LLM
import torch

class ChatbotApp:
    def __init__(self):
        self.milvus_client = MilvusClient()
        self.llm = LLM(thread_id="test-123")

    def respond(self, query, history):
        # Get relevant documents
        # docs = self.milvus_client.search(query)
        # context = "\n\n".join([doc.page_content for doc in docs])
        
        context=''
        self.llm.inject_prompt_and_context(
            system_prompt="",
            context=context
        )

        print("Context is ready, calling LLM...")
        response = self.llm.chat(query)

        return response

    def close(self):
        if hasattr(self, "milvus_client") and self.milvus_client:
            self.milvus_client.close()
        if hasattr(self, "llm") and self.llm and hasattr(self.llm, "close"):
            self.llm.close()

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