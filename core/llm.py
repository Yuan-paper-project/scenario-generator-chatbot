from langchain_core.messages import HumanMessage, SystemMessage, AIMessage
from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import START,END, MessagesState, StateGraph
from langchain.chat_models import init_chat_model
from langchain_core.prompts import ChatPromptTemplate
from typing import Literal, TypedDict, Annotated
from langgraph.graph.message import add_messages

from .config import get_settings
from utilities.parser import parse_scenic
import re

settings = get_settings()

# Custom state that separates user query from full prompt
class CustomState(TypedDict):
    messages: Annotated[list, add_messages]
    user_query: str  # Store only the original query
    full_prompt: str  # Temporary, not stored in memory
    retry_count: int
    validation_result: dict


class LLM: 
    def __init__(self, thread_id="default_thread", max_retries=3):
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
        self.ERROR_CORRECTION_TEMPLATE = """
            The following Scenic DSL code you generated has syntax errors:

            Generated Code:
            ```
            {dsl_code}
            ```

            Error Message:
            {error_message}

            Please fix the syntax errors and regenerate valid Scenic DSL code. 
            Output only the corrected Scenic program in one fenced code block. No prose or explanations.
            """
        

        self.thread_id = thread_id
        self.max_retries = max_retries
        self.prompt_template = ChatPromptTemplate.from_template(self.PROMPT_TEMPLATE)
        self.error_template = ChatPromptTemplate.from_template(self.ERROR_CORRECTION_TEMPLATE)

        # Set up the workflow graph
        self.workflow = StateGraph(state_schema=CustomState)
        self.workflow.add_node("model", self._call_model)
        self.workflow.add_node("prepare_prompt", self._prepare_prompt)
        self.workflow.add_node("validate", self._validate_dsl)
        self.workflow.add_node("error_correction", self._error_correction)

        # Define edges
        self.workflow.add_edge(START, "prepare_prompt")
        self.workflow.add_edge("prepare_prompt", "model")
        self.workflow.add_conditional_edges(
            "model",
            self._should_validate,
            {
                "validate": "validate",
                "end": END
            }
        )
        self.workflow.add_conditional_edges(
            "validate",
            self._check_validation_result,
            {
                "error_correction": "error_correction",
                "end": END
            }
        )

        self.workflow.add_edge("error_correction", "prepare_prompt")

        self.memory = MemorySaver()
        self.app = self.workflow.compile(checkpointer=self.memory)
        print(self.app.get_graph().draw_ascii())


        # Initialize LLM based on provider
        if settings.LLM_PROVIDER == "ollama":
            self.llm = init_chat_model(settings.LLM_MODEL_NAME, model_provider = settings.LLM_PROVIDER, base_url=settings.OLLAMA_URL)
        else:
            self.llm = init_chat_model(settings.LLM_MODEL_NAME, model_provider = settings.LLM_PROVIDER)



    def inject_prompt_and_context(self, system_prompt:str, context:str):
        """Inject system prompt and context into the prompt template."""
        self.system_prompt = system_prompt
        self.context = context

    def _extract_code_from_response(self, response: str) -> str:
        """Extract code from markdown code blocks."""
        code_block_pattern = r"```(?:scenic|python)?\n(.*?)```"
        matches = re.findall(code_block_pattern, response, re.DOTALL)
        if matches:
            return matches[0].strip()
        return response.strip()

    def _prepare_prompt(self, state: CustomState):
        """Prepare the full prompt with context, but only store user query in messages."""
        retry_count = state.get("retry_count", 0)
        print(f"\n🔄 Step: Preparing prompt (Retry count: {retry_count})")
        
        # For initial request, format with context
        if retry_count == 0:
            user_query = state.get("user_query", "")
            print(f"📝 Processing user query: {user_query[:100]}...")
            full_prompt = self.prompt_template.format(
                system_prompt=self.system_prompt,
                context=self.context,
                question=user_query
            )
        else:
            print("🔄 Using error correction prompt")
            full_prompt = state.get("full_prompt", "")
        
        return {
            "full_prompt": full_prompt
        }

    def _call_model(self, state: CustomState):
        print("\n🤖 Step: Calling LLM model")
        full_prompt = state.get("full_prompt", "")
        retry_count = state.get("retry_count", 0)
        previous_messages = state.get("messages", [])
        
        # # For initial call, create message with full prompt
        if retry_count == 0:
            current_messages = previous_messages + [HumanMessage(content=full_prompt)]
        else:
            # For retries, append the error correction prompt
            current_messages = previous_messages + [HumanMessage(content=full_prompt)]

        response = self.llm.invoke(current_messages)
        # response = self.llm.invoke([HumanMessage(content=full_prompt)])
        print(f"📥 Received response: {response}")

        if retry_count == 0:
            # First interaction: store original user query
            user_query = state.get("user_query", "")
            messages_to_store = [
                HumanMessage(content=user_query),
                response
            ]
            print("✨ Initial response stored with user query")
        else:
            # Retry: store the error correction request and response
            messages_to_store = [response]
            print("🔄 Retry response stored")
            
        return {
            "messages": messages_to_store,
            "retry_count": retry_count
        }

        # last_message = state["messages"][-1]
        # question = last_message.content
        # prompt = self.prompt_template.format_prompt(system_prompt= self.system_prompt, context=self.context, question=question)
        # messages = [SystemMessage(prompt.to_string()),]
        # response = self.llm.invoke(state["messages"])
        # return {"messages": response}

    def _should_validate(self, state: CustomState) -> Literal["validate", "end"]:
        print("\n🔍 Step: Checking if validation is needed")
        messages = state.get("messages", [])
        if not messages:
            print("❌ No messages to validate")
            return "end"
        
        last_message = messages[-1]
        if isinstance(last_message, AIMessage):
            content = last_message.content
            if "```" in content or "scenic" in content.lower():
                print("✅ Code block detected - proceeding to validation")
                return "validate"
        print("➡️ No code block found - skipping validation")
        return "end"

    def _validate_dsl(self, state: CustomState):
        """Validate the generated DSL code."""
        messages = state.get("messages", [])
        last_message = messages[-1]
        dsl_code = self._extract_code_from_response(last_message.content)
        
        try:
            parse_scenic(dsl_code)
            validation_result = {
                "valid": True,
                "error": None,
                "code": dsl_code
            }
            print("✓ DSL validation succeeded.")
        except Exception as e:
            validation_result = {
                "valid": False,
                "error": str(e),
                "code": dsl_code
            }
            print(f"✗ DSL validation failed: {e}")
        
        return {
            "validation_result": validation_result
        }
    
    def _check_validation_result(self, state: CustomState) -> Literal["error_correction", "end"]:
        """Check validation result and decide next step."""
        print("\n✨ Step: Checking validation results")
        validation_result = state.get("validation_result", {})
        retry_count = state.get("retry_count", 0)
        
        if not validation_result.get("valid", True):
            print(f"⚠️ Validation failed - Retry count: {retry_count}/{self.max_retries}")
            if retry_count < self.max_retries:
                print("🔄 Proceeding with error correction")
                return "error_correction"
            else:
                print(f"⛔ Maximum retries ({self.max_retries}) reached. Returning code with errors.")
        else:
            print("✅ Validation successful")
        return "end"

    def _error_correction(self, state: CustomState):
        """Create error correction prompt."""
        print("\n🔧 Step: Preparing error correction")
        validation_result = state.get("validation_result", {})
        retry_count = state.get("retry_count", 0)
        
        print(f"❌ Error found: {validation_result['error']}")
        error_prompt = self.error_template.format(
            dsl_code=validation_result["code"],
            error_message=validation_result["error"]
        )
        print("📝 Error correction prompt prepared")
        
        return {
            "full_prompt": error_prompt,
            "retry_count": retry_count + 1
        }


    def chat(self, user_input):
        """Main chat interface."""
        print("\n🚀 Starting chat interaction")
        print(f"📥 Received user input (length: {len(user_input)} chars)")
        
        config = {"configurable": {"thread_id": self.thread_id}}
        
        print("⚙️ Invoking workflow graph")
        output = self.app.invoke(
            {
                "messages": [],
                "user_query": user_input,  # Store only the user query
                "retry_count": 0
            },
            config
        )
        
        # Return the last AI message
        print("\n🔍 Finding final response")
        messages = output.get("messages", [])
        for msg in reversed(messages):
            if isinstance(msg, AIMessage):
                print("✅ Found AI response")
                return msg.content
        
        response = messages[-1].content if messages else "No response generated."
        print(f"📤 Returning response (length: {len(response)} chars)")
        return response
    
