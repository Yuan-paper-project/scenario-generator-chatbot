import gradio as gr
from core.milvus_client import MilvusClient
from core.llm import LLM

# Initialize once for efficiency
milvus_client = MilvusClient()
llm = LLM()

def respond(message, history):
    # 1. Search vector DB for relevant chunks
    docs = milvus_client.search(message)
    # Combine the content of the retrieved documents
    context = "\n\n".join([doc.page_content for doc in docs])
    # 2. Pass chunks and query to LLM
    answer = llm.generate_response(context=context, question=message)
    # 3. Return the answer
    return answer

gr.ChatInterface(
    fn=respond,
    title="Chatbot",
    description="Chatbot for generating DSL "
).launch()
