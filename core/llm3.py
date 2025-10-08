from langchain_core.messages import HumanMessage, SystemMessage, AIMessage
from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import START, MessagesState, StateGraph
from langchain.chat_models import init_chat_model
from langchain_core.prompts import ChatPromptTemplate

from .config import get_settings

settings = get_settings()

class LLM: 
    def __init__(self, thread_id="default_thread"):
        self.PROMPT_TEMPLATE = """
            System Instructions:
            {system_prompt}

            Context:
            {context}

            Question:
            {question}

            You are an expert Scenic DSL assistant.  
            Your task is to read the provided documentation chunks and generate executable DSL code that satisfies the user's request. 
            Provide the full DSL code, which should be a valid Scenic DSL code and can be executed directly. Output only a Scenic program in one fenced code block. No prose.
            Do not invent functions or syntax that are not supported by the DSL indicated in the evidence.

            """
        self.thread_id = thread_id
        self.prompt_template = ChatPromptTemplate.from_template(self.PROMPT_TEMPLATE)
        self.llm = init_chat_model(settings.LLM_MODEL_NAME, model_provider = settings.LLM_PROVIDER, base_url=settings.OLLAMA_URL)
        self.workflow = StateGraph(state_schema=MessagesState)

        self.workflow.add_edge(START, "model")
        self.workflow.add_node("model", self._call_model)

        self.memory = MemorySaver()
        self.app = self.workflow.compile(checkpointer=self.memory)


    def inject_prompt_and_context(self, system_prompt:str, context:str):
        """Inject system prompt and context into the prompt template."""
        self.system_prompt = system_prompt
        self.context = context

    def _call_model(self, state: MessagesState):
        # last_message = state["messages"][-1]
        # question = last_message.content
        # prompt = self.prompt_template.format_prompt(system_prompt= self.system_prompt, context=self.context, question=question)
        # messages = [SystemMessage(prompt.to_string()),]
        response = self.llm.invoke(state["messages"])
        return {"messages": response}


    def chat(self, user_input):
        input_messages =   [HumanMessage(user_input)]

        config = {"configurable": {"thread_id": self.thread_id}}
        output = self.app.invoke({"messages": input_messages}, config)
        return output["messages"][-1].content