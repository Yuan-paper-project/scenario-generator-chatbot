import gradio as gr
from core.milvus_client import MilvusClient
from core.llm import LLM
import torch

class ChatbotApp:
    def __init__(self):
        self.milvus_client = MilvusClient()
        self.llm = LLM()
        self.memory_size = 5  # Keep last 5 exchanges
        self.conversation_memory = []

    def respond(self, message, history):
        # Update conversation memory
        if history:
            self.conversation_memory = history[-self.memory_size:]
        
        # Format conversation history
        conversation_context = "\n".join([
            f"Human: {h[0]}\nAssistant: {h[1]}" 
            for h in self.conversation_memory
        ])
        
        # Get relevant documents
        docs = self.milvus_client.search(message)
        doc_context = "\n\n".join([doc.page_content for doc in docs])
        
        # Combine both contexts
        full_context = f"""Previous Conversation:
                {conversation_context}

                Relevant Documentation:
                {doc_context}"""



        print("Context is ready, calling LLM...")
        answer = self.llm.generate_response(context=full_context, question=message)
        
        # Update memory with current exchange
        self.conversation_memory.append((message, answer))
        if len(self.conversation_memory) > self.memory_size:
            self.conversation_memory.pop(0)
            
        return answer

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
            # type="messages",
            # save_history=True
        ).launch()
    finally:
        app.close()