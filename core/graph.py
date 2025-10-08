from typing import TypedDict
from langgraph.graph import StateGraph, END
from langchain_core.documents import Document

from .milvus_client import MilvusClient
from .llm import LLM
from .config import get_settings


class ChatState(TypedDict, total=False):
    question: str
    context: str
    answer: str


def _retrieve(state: ChatState) -> ChatState:
    query = state.get("question", "").strip()
    if not query:
        return {"context": "", **state}

    milvus = MilvusClient()
    try:
        docs: list[Document] = milvus.search(query=query)
        context = "\n\n".join(doc.page_content for doc in docs)
        return {"context": context, **state}
    finally:
        milvus.close()


def _generate(state: ChatState) -> ChatState:
    context = state.get("context", "")
    question = state.get("question", "")

    llm = LLM()
    answer = llm.generate_response(context=context, question=question)
    return {"answer": answer, **state}


def build_app():
    graph = StateGraph(ChatState)

    graph.add_node("retrieve", _retrieve)
    graph.add_node("generate", _generate)

    graph.set_entry_point("retrieve")
    graph.add_edge("retrieve", "generate")
    graph.add_edge("generate", END)

    return graph.compile()
