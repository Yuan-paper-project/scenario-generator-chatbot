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
from .agents.RoadGenerator import RoadGenerator
from .agents.EgoVehicleSetup import EgoVehicleSetup
from .agents.AdversarialObjectsGenerator import AdversarialObjectsGenerator
from .agents.BehaviorGenerator import BehaviorGenerator
from .agents.CodeAssembler import CodeAssembler


class WorkflowState(TypedDict):
    """State for the agent workflow."""
    messages: Annotated[list, add_messages]
    user_query: str  # Original user query
    interpretation: str  # Output from interpreter
    header_code: str  # Header code from HeaderGenerator
    road_code: str  # Road setup code
    ego_vehicle_code: str  # Ego vehicle setup code
    adversarial_objects_code: str  # Adversarial objects code
    behavior_code: str  # Behavior definitions code
    generated_code: str  # Assembled Scenic code
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
        self.validator = CodeValidator()
        self.error_corrector = ErrorCorrector()
        self.header_generator = HeaderGenerator()
        self.road_generator = RoadGenerator()
        self.ego_vehicle_setup = EgoVehicleSetup()
        self.adversarial_objects_generator = AdversarialObjectsGenerator()
        self.behavior_generator = BehaviorGenerator()
        self.code_assembler = CodeAssembler()
        
        # Set up the workflow graph
        self.workflow = StateGraph(state_schema=WorkflowState)
        
        # Add nodes
        self.workflow.add_node("interpreter", self._interpret_node)
        self.workflow.add_node("header_generation", self._header_generation_node)
        self.workflow.add_node("assemble_header", self._assemble_header_node)
        self.workflow.add_node("road_generation", self._road_generation_node)
        self.workflow.add_node("assemble_road", self._assemble_road_node)
        self.workflow.add_node("ego_vehicle_setup", self._ego_vehicle_setup_node)
        self.workflow.add_node("assemble_ego", self._assemble_ego_node)
        self.workflow.add_node("adversarial_objects_generation", self._adversarial_objects_generation_node)
        self.workflow.add_node("assemble_adversarial", self._assemble_adversarial_node)
        self.workflow.add_node("behavior_generation", self._behavior_generation_node)
        self.workflow.add_node("assemble_behavior", self._assemble_behavior_node)
        self.workflow.add_node("validate", self._validate_node)
        self.workflow.add_node("error_correction", self._error_correction_node)
        
        # Define edges - sequential code generation and assembly steps
        self.workflow.add_edge(START, "interpreter")
        self.workflow.add_edge("interpreter", "header_generation")
        self.workflow.add_edge("header_generation", "assemble_header")
        self.workflow.add_edge("assemble_header", "road_generation")
        self.workflow.add_edge("road_generation", "assemble_road")
        self.workflow.add_edge("assemble_road", "ego_vehicle_setup")
        self.workflow.add_edge("ego_vehicle_setup", "assemble_ego")
        self.workflow.add_edge("assemble_ego", "adversarial_objects_generation")
        self.workflow.add_edge("adversarial_objects_generation", "assemble_adversarial")
        self.workflow.add_edge("assemble_adversarial", "behavior_generation")
        self.workflow.add_edge("behavior_generation", "assemble_behavior")
        # After final assembly, always validate
        self.workflow.add_edge("assemble_behavior", "validate")
        
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

    def _header_generation_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Generate header using HeaderGenerator."""
        print("\n📋 Step: Generating header")
        
        # HeaderGenerator returns the hardcoded header
        header_code = self.header_generator.process("")
        
        print(f"✅ Header generation completed")
        print(f"📄 Header: {header_code[:100]}...")
        
        return {
            "header_code": header_code
        }

    def _assemble_header_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Assemble header code."""
        print("\n🔨 Step: Assembling header")
        
        header_code = state.get("header_code", "")
        previous_assembled = state.get("generated_code", "")
        
        # Assemble header (first component, so no previous code)
        assembled_code = self.code_assembler.process(
            previous_assembled_code=previous_assembled,
            new_component=header_code,
            component_type="header"
        )
        
        print(f"✅ Header assembly completed")
        print(f"\n📋 Assembled code snippet:\n{'-'*60}")
        print(assembled_code)
        print(f"{'-'*60}\n")
        
        return {
            "generated_code": assembled_code
        }

    def _road_generation_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Generate road setup code using RoadGenerator (with RAG context)."""
        print("\n🛣️ Step: Generating road setup")
        
        interpretation = state.get("interpretation", "")
        previous_assembled = state.get("generated_code", "")
        
        # RoadGenerator uses RAG automatically (use_rag=True in constructor)
        # Pass previous assembled code as context
        road_code = self.road_generator.process(interpretation, previous_assembled)
        
        print(f"✅ Road generation completed")
        print(f"📄 Road code length: {len(road_code)} characters")
        
        return {
            "road_code": road_code
        }

    def _assemble_road_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Assemble road code with previous assembled code."""
        print("\n🔨 Step: Assembling road setup")
        
        road_code = state.get("road_code", "")
        previous_assembled = state.get("generated_code", "")
        
        # Assemble road code with previous assembled code
        assembled_code = self.code_assembler.process(
            previous_assembled_code=previous_assembled,
            new_component=road_code,
            component_type="road"
        )
        
        print(f"✅ Road assembly completed")
        print(f"\n🛣️ Assembled code snippet:\n{'-'*60}")
        print(assembled_code)
        print(f"{'-'*60}\n")
        
        return {
            "generated_code": assembled_code
        }

    def _ego_vehicle_setup_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Generate ego vehicle setup using EgoVehicleSetup (with RAG context)."""
        print("\n🚗 Step: Generating ego vehicle setup")
        
        interpretation = state.get("interpretation", "")
        previous_assembled = state.get("generated_code", "")
        
        # EgoVehicleSetup uses RAG automatically (use_rag=True in constructor)
        # Pass previous assembled code as context
        ego_vehicle_code = self.ego_vehicle_setup.process(interpretation, previous_assembled)
        
        print(f"✅ Ego vehicle setup completed")
        print(f"📄 Ego vehicle code length: {len(ego_vehicle_code)} characters")
        
        return {
            "ego_vehicle_code": ego_vehicle_code
        }

    def _assemble_ego_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Assemble ego vehicle code with previous assembled code."""
        print("\n🔨 Step: Assembling ego vehicle setup")
        
        ego_vehicle_code = state.get("ego_vehicle_code", "")
        previous_assembled = state.get("generated_code", "")
        
        # Assemble ego vehicle code with previous assembled code
        assembled_code = self.code_assembler.process(
            previous_assembled_code=previous_assembled,
            new_component=ego_vehicle_code,
            component_type="ego_vehicle"
        )
        
        print(f"✅ Ego vehicle assembly completed")
        print(f"\n🚗 Assembled code snippet:\n{'-'*60}")
        print(assembled_code)
        print(f"{'-'*60}\n")
        
        return {
            "generated_code": assembled_code
        }

    def _adversarial_objects_generation_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Generate adversarial objects using AdversarialObjectsGenerator (with RAG context)."""
        print("\n👤 Step: Generating adversarial objects")
        
        interpretation = state.get("interpretation", "")
        previous_assembled = state.get("generated_code", "")
        
        # AdversarialObjectsGenerator uses RAG automatically (use_rag=True in constructor)
        # Pass previous assembled code as context
        adversarial_objects_code = self.adversarial_objects_generator.process(interpretation, previous_assembled)
        
        print(f"✅ Adversarial objects generation completed")
        print(f"📄 Adversarial objects code length: {len(adversarial_objects_code)} characters")
        
        return {
            "adversarial_objects_code": adversarial_objects_code
        }

    def _assemble_adversarial_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Assemble adversarial objects code with previous assembled code."""
        print("\n🔨 Step: Assembling adversarial objects")
        
        adversarial_objects_code = state.get("adversarial_objects_code", "")
        previous_assembled = state.get("generated_code", "")
        
        # Assemble adversarial objects code with previous assembled code
        assembled_code = self.code_assembler.process(
            previous_assembled_code=previous_assembled,
            new_component=adversarial_objects_code,
            component_type="adversarial_objects"
        )
        
        print(f"✅ Adversarial objects assembly completed")
        print(f"\n👤 Assembled code snippet:\n{'-'*60}")
        print(assembled_code)
        print(f"{'-'*60}\n")
        
        return {
            "generated_code": assembled_code
        }

    def _behavior_generation_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Generate behavior code using BehaviorGenerator (with RAG context)."""
        print("\n🎭 Step: Generating behavior definitions")
        
        interpretation = state.get("interpretation", "")
        previous_assembled = state.get("generated_code", "")
        
        # BehaviorGenerator uses RAG automatically (use_rag=True in constructor)
        # Pass previous assembled code as context
        behavior_code = self.behavior_generator.process(interpretation, previous_assembled)
        
        print(f"✅ Behavior generation completed")
        print(f"📄 Behavior code length: {len(behavior_code)} characters")
        
        return {
            "behavior_code": behavior_code
        }

    def _assemble_behavior_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Assemble behavior code with previous assembled code (final assembly)."""
        print("\n🔨 Step: Assembling behavior definitions (final assembly)")
        
        behavior_code = state.get("behavior_code", "")
        previous_assembled = state.get("generated_code", "")
        
        # Assemble behavior code with previous assembled code (final step)
        assembled_code = self.code_assembler.process(
            previous_assembled_code=previous_assembled,
            new_component=behavior_code,
            component_type="behavior"
        )
        
        print(f"✅ Final assembly completed")
        print(f"📄 Complete assembled code length: {len(assembled_code)} characters")
        print(f"\n🎭 Final assembled code snippet:\n{'-'*60}")
        print(assembled_code)
        print(f"{'-'*60}\n")
        
        return {
            "generated_code": assembled_code,
            "messages": state.get("messages", []) + [
                AIMessage(content=f"Complete assembled Scenic code:\n```scenic\n{assembled_code}\n```")
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
        
        # Check if we've reached max retries BEFORE attempting error correction
        if retry_count >= self.max_retries:
            print(f"\n⛔ Maximum retries ({self.max_retries}) reached - ending workflow")
            print(f"⚠️ Returning code with errors")
            generated_code = state.get("generated_code", "")
            error_message = validation_result.get("error", "Unknown error")
            print(f"\n❌ Final Error: {error_message}")
            print(f"\n📄 Wrong Code Output:\n{'-'*60}")
            print(generated_code)
            print(f"{'-'*60}\n")
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
                "header_code": "",
                "road_code": "",
                "ego_vehicle_code": "",
                "adversarial_objects_code": "",
                "behavior_code": "",
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
            print(f"\n📄 Final Code:\n{'-'*60}")
            print(final_code)
            print(f"{'-'*60}\n")
        else:
            print("⚠️ Final code has validation errors (max retries reached)")
            error_msg = validation_result.get("error", "Unknown error")
            print(f"❌ Error: {error_msg}")
            print(f"\n📄 Wrong Code Output:\n{'-'*60}")
            print(final_code)
            print(f"{'-'*60}\n")
        
        print("="*50 + "\n")
        
        return final_code


if __name__ == "__main__":
    workflow = AgentWorkflow()
    workflow.run("The ego vehicle is driving on a straight road when a pedestrian suddenly crosses from the right front and suddenly stops as the ego vehicle approaches.")