from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import START, END, StateGraph
from langgraph.graph.message import add_messages
from langchain_core.messages import HumanMessage, AIMessage
from typing import Literal, TypedDict, Annotated

from .agents.Interpretor import InterpretorAgent
from .agents.CodeGenerator import CodeGenerator
from .agents.CodeValidator import CodeValidator
from .agents.ErrorCorrector import ErrorCorrector
from .agents.HeaderGenerator import HeaderGenerator


class WorkflowState(TypedDict):
    """State for the agent workflow."""
    messages: Annotated[list, add_messages]
    user_query: str  # Original user query
    interpretation: str  # Output from interpreter
    generated_code: str  # Generated Scenic code
    validation_result: dict  # Validation result from CodeValidator
    retry_count: int  # Number of retry attempts


class AgentWorkflow:
    """LangGraph workflow connecting multiple agents."""
    
    def __init__(self, thread_id: str = "default_thread", max_retries: int = 3):
        """
        Initialize the agent workflow.
        
        Args:
            thread_id: Thread ID for conversation memory
            max_retries: Maximum number of error correction retries
        """
        self.thread_id = thread_id
        self.max_retries = max_retries
        
        # Initialize all agents
        self.interpreter = InterpretorAgent()
        self.code_generator = CodeGenerator()
        self.validator = CodeValidator()
        self.error_corrector = ErrorCorrector()
        self.header_generator = HeaderGenerator()
        
        # Set up the workflow graph
        self.workflow = StateGraph(state_schema=WorkflowState)
        
        # Add nodes
        self.workflow.add_node("interpreter", self._interpret_node)
        self.workflow.add_node("code_generation", self._code_generation_node)
        self.workflow.add_node("validate", self._validate_node)
        self.workflow.add_node("error_correction", self._error_correction_node)
        
        # Define edges
        self.workflow.add_edge(START, "interpreter")
        self.workflow.add_edge("interpreter", "code_generation")
        # After code generation, always validate
        self.workflow.add_edge("code_generation", "validate")
        
        # Conditional edge: validate -> either error_correction or end
        self.workflow.add_conditional_edges(
            "validate",
            self._check_validation_result,
            {
                "error_correction": "error_correction",
                "end": END
            }
        )
        

        self.workflow.add_edge("error_correction", "validate")
        
        # Compile the workflow with memory
        self.memory = MemorySaver()
        self.app = self.workflow.compile(checkpointer=self.memory)
        print("\n" + "="*50)
        print("Workflow Graph Structure:")
        print("="*50)
        print(self.app.get_graph().draw_ascii())
        print("="*50 + "\n")

    def _interpret_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Interpret user query using InterpretorAgent."""
        print("\n🔍 Step: Interpreting user query")
        user_query = state.get("user_query", "")
        print(f"📝 Processing query: {user_query[:100]}...")
        
        # Process through interpreter agent
        result = self.interpreter.process(user_query)
        interpretation = result.get("interpretation", "")
        
        print(f"✅ Interpretation completed")
        print(f"📄 Interpretation: {interpretation[:200]}...")
        
        return {
            "interpretation": interpretation,
            "messages": [HumanMessage(content=user_query)]
        }

    def _code_generation_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Generate code using CodeGenerator (with RAG context)."""
        print("\n🤖 Step: Generating Scenic code")
        
        # Get interpretation or user query
        interpretation = state.get("interpretation", "")
        user_query = state.get("user_query", "")
        
        # Use interpretation if available, otherwise use user query
        query_for_generation = interpretation if interpretation else user_query
        
        print(f"📝 Using query: {query_for_generation[:100]}...")
        
        # CodeGenerator uses RAG automatically (use_rag=True in constructor)
        generated_code = self.code_generator.process(query_for_generation)
        
        # Add header to the generated code
        generated_code_with_header = self.header_generator.process(generated_code)
        
        print(f"✅ Code generation completed")
        print(f"📄 Generated code length: {len(generated_code_with_header)} characters (with header)")
        
        return {
            "generated_code": generated_code_with_header,
            "messages": state.get("messages", []) + [
                AIMessage(content=f"Generated Scenic code:\n```scenic\n{generated_code_with_header}\n```")
            ]
        }

    def _validate_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Validate generated code using CodeValidator."""
        print("\n✓ Step: Validating generated code")
        generated_code = state.get("generated_code", "")
        
        if not generated_code:
            print("❌ No code to validate")
            return {
                "validation_result": {
                    "valid": False,
                    "error": "No code generated",
                    "code": ""
                }
            }
        
        # Validate using CodeValidator
        validation_result = self.validator.process(generated_code)
        
        if validation_result.get("valid"):
            print("✅ Code validation succeeded")
        else:
            print(f"❌ Code validation failed: {validation_result.get('error', 'Unknown error')}")
        
        return {
            "validation_result": validation_result
        }

    def _error_correction_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Correct errors using ErrorCorrector (with RAG context)."""
        print("\n🔧 Step: Correcting errors in code")
        
        validation_result = state.get("validation_result", {})
        retry_count = state.get("retry_count", 0)
        
        dsl_code = validation_result.get("code", "")
        error_message = validation_result.get("error", "Unknown error")
        
        print(f"❌ Error to fix: {error_message[:200]}...")
        print(f"🔄 Retry attempt: {retry_count + 1}/{self.max_retries}")
        
        # ErrorCorrector uses RAG automatically (use_rag=True in constructor)
        corrected_code = self.error_corrector.process(dsl_code, error_message)
        
        # Ensure header is present in corrected code
        corrected_code_with_header = self.header_generator.process(corrected_code)
        
        print(f"✅ Error correction completed")
        print(f"📄 Corrected code length: {len(corrected_code_with_header)} characters (with header)")
        
        return {
            "generated_code": corrected_code_with_header,
            "retry_count": retry_count + 1,
            "messages": state.get("messages", []) + [
                HumanMessage(content=f"Error correction request (retry {retry_count + 1})"),
                AIMessage(content=f"Corrected Scenic code:\n```scenic\n{corrected_code_with_header}\n```")
            ]
        }

    def _check_validation_result(self, state: WorkflowState) -> Literal["error_correction", "end"]:
        print("\n✨ Step: Checking validation results")
        
        validation_result = state.get("validation_result", {})
        retry_count = state.get("retry_count", 0)
        
        is_valid = validation_result.get("valid", False)
        
        if is_valid:
            print("✅ Validation successful - ending workflow")
            return "end"
        
        if retry_count >= self.max_retries:
            print(f"⛔ Maximum retries ({self.max_retries}) reached - ending workflow")
            return "end"
        
        print(f"🔄 Validation failed - proceeding with error correction (retry {retry_count + 1}/{self.max_retries})")
        return "error_correction"

    def run(self, user_input: str) -> str:
        """
        Run the complete workflow with user input.
        
        Args:
            user_input: User's natural language query
            
        Returns:
            Final generated and validated Scenic code
        """
        print("\n" + "="*50)
        print("🚀 Starting Agent Workflow")
        print("="*50)
        print(f"📥 User input: {user_input}")
        print("="*50 + "\n")
        
        config = {"configurable": {"thread_id": self.thread_id}}
        
        # Invoke the workflow
        output = self.app.invoke(
            {
                "messages": [],
                "user_query": user_input,
                "interpretation": "",
                "generated_code": "",
                "validation_result": {},
                "retry_count": 0
            },
            config
        )
        
        # Extract final result
        final_code = output.get("generated_code", "")
        validation_result = output.get("validation_result", {})
        
        print("\n" + "="*50)
        print("📤 Workflow Completed")
        print("="*50)
        
        if validation_result.get("valid"):
            print("✅ Final code is valid")
            print(f"📄 Final code: {final_code}")
        else:
            print("⚠️ Final code has validation errors (max retries reached)")
            if validation_result.get("error"):
                print(f"❌ Error: {validation_result.get('error')}")
        
        print("="*50 + "\n")
        
        return final_code


if __name__ == "__main__":
    workflow = AgentWorkflow()
    workflow.run("The ego vehicle is driving on a straight road when a pedestrian suddenly crosses from the right front and suddenly stops as the ego vehicle approaches.")