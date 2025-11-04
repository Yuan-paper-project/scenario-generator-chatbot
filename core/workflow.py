from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import START, END, StateGraph
from langgraph.graph.message import add_messages
from langchain_core.messages import HumanMessage, AIMessage
from typing import Literal, TypedDict, Annotated, Optional

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
from .workflow_logger import WorkflowLogger


class WorkflowState(TypedDict):
    messages: Annotated[list, add_messages]
    user_query: str
    interpretation: str
    header_code: str
    road_code: str
    ego_vehicle_code: str
    adversarial_objects_code: str
    behavior_code: str
    generated_code: str
    validation_result: dict
    retry_count: int


class AgentWorkflow:
    
    def __init__(self, thread_id: str = "default_thread", max_retries: int = 3):
        self.thread_id = thread_id
        self.max_retries = max_retries
        self.logger: Optional[WorkflowLogger] = None
        
        self.interpreter = InterpretorAgent()
        self.validator = CodeValidator()
        self.error_corrector = ErrorCorrector()
        self.header_generator = HeaderGenerator()
        self.road_generator = RoadGenerator()
        self.ego_vehicle_setup = EgoVehicleSetup()
        self.adversarial_objects_generator = AdversarialObjectsGenerator()
        self.behavior_generator = BehaviorGenerator()
        self.code_assembler = CodeAssembler()
        
        self.workflow = StateGraph(state_schema=WorkflowState)
        
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
        self.workflow.add_edge("assemble_behavior", "validate")
        
        self.workflow.add_conditional_edges(
            "validate",
            self._check_validation_result,
            {
                "error_correction": "error_correction",
                "end": END
            }
        )
        

        self.workflow.add_edge("error_correction", "validate")
        
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
        
        result = self.interpreter.process(user_query)
        interpretation = result.get("interpretation", "")
        
        print(f"✅ Interpretation completed")
        print(f"📄 Interpretation: {interpretation[:200]}...")
        
        new_state = {
            "interpretation": interpretation,
            "messages": [HumanMessage(content=user_query)]
        }
        
        if self.logger:
            formatted_prompt = self.interpreter.get_last_formatted_prompt() or "No prompt available"
            response = self.interpreter.get_last_response() or "No response available"
            self.logger.log_step("interpreter", formatted_prompt, response)
        
        return new_state

    def _header_generation_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Generate header using HeaderGenerator."""
        print("\n📋 Step: Generating header")
        
        header_code = self.header_generator.process("")
        
        print(f"✅ Header generation completed")
        print(f"📄 Header: {header_code[:100]}...")
        
        new_state = {
            "header_code": header_code
        }
        
        if self.logger:
            prompt_content = "Header Generator (hardcoded header, no prompt)"
            response_content = header_code
            self.logger.log_step("header_generation", prompt_content, response_content)
        
        return new_state

    def _assemble_header_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Assemble header code."""
        print("\n🔨 Step: Assembling header")
        
        header_code = state.get("header_code", "")
        previous_assembled = state.get("generated_code", "")
        
        assembled_code = self.code_assembler.process(
            previous_assembled_code=previous_assembled,
            new_component=header_code,
            component_type="header"
        )
        
        print(f"✅ Header assembly completed")
        print(f"\n📋 Assembled code snippet:\n{'-'*60}")
        print(assembled_code)
        print(f"{'-'*60}\n")
        
        new_state = {
            "generated_code": assembled_code
        }
        
        if self.logger:
            formatted_prompt = self.code_assembler.get_last_formatted_prompt() or "No prompt available"
            response = self.code_assembler.get_last_response() or "No response available"
            self.logger.log_step("assemble_header", formatted_prompt, response)
        
        return new_state

    def _road_generation_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Generate road setup code using RoadGenerator (with RAG context)."""
        print("\n🛣️ Step: Generating road setup")
        
        interpretation = state.get("interpretation", "")
        previous_assembled = state.get("generated_code", "")
        

        road_code = self.road_generator.process(interpretation, previous_assembled)
        
        print(f"✅ Road generation completed")
        print(f"📄 Road code length: {len(road_code)} characters")
        
        new_state = {
            "road_code": road_code
        }
        
        if self.logger:
            formatted_prompt = self.road_generator.get_last_formatted_prompt() or "No prompt available"
            response = self.road_generator.get_last_response() or "No response available"
            self.logger.log_step("road_generation", formatted_prompt, response)
        
        return new_state

    def _assemble_road_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Assemble road code with previous assembled code."""
        print("\n🔨 Step: Assembling road setup")
        
        road_code = state.get("road_code", "")
        previous_assembled = state.get("generated_code", "")
        
        assembled_code = self.code_assembler.process(
            previous_assembled_code=previous_assembled,
            new_component=road_code,
            component_type="road"
        )
        
        print(f"✅ Road assembly completed")
        print(f"\n🛣️ Assembled code snippet:\n{'-'*60}")
        print(assembled_code)
        print(f"{'-'*60}\n")
        
        new_state = {
            "generated_code": assembled_code
        }
        
        if self.logger:
            formatted_prompt = self.code_assembler.get_last_formatted_prompt() or "No prompt available"
            response = self.code_assembler.get_last_response() or "No response available"
            self.logger.log_step("assemble_road", formatted_prompt, response)
        
        return new_state

    def _ego_vehicle_setup_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Generate ego vehicle setup using EgoVehicleSetup (with RAG context)."""
        print("\n🚗 Step: Generating ego vehicle setup")
        
        interpretation = state.get("interpretation", "")
        previous_assembled = state.get("generated_code", "")
        
        ego_vehicle_code = self.ego_vehicle_setup.process(interpretation, previous_assembled)
        
        print(f"✅ Ego vehicle setup completed")
        print(f"📄 Ego vehicle code length: {len(ego_vehicle_code)} characters")
        
        new_state = {
            "ego_vehicle_code": ego_vehicle_code
        }
        
        if self.logger:
            formatted_prompt = self.ego_vehicle_setup.get_last_formatted_prompt() or "No prompt available"
            response = self.ego_vehicle_setup.get_last_response() or "No response available"
            self.logger.log_step("ego_vehicle_setup", formatted_prompt, response)
        
        return new_state

    def _assemble_ego_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Assemble ego vehicle code with previous assembled code."""
        print("\n🔨 Step: Assembling ego vehicle setup")
        
        ego_vehicle_code = state.get("ego_vehicle_code", "")
        previous_assembled = state.get("generated_code", "")
        
        assembled_code = self.code_assembler.process(
            previous_assembled_code=previous_assembled,
            new_component=ego_vehicle_code,
            component_type="ego_vehicle"
        )
        
        print(f"✅ Ego vehicle assembly completed")
        print(f"\n🚗 Assembled code snippet:\n{'-'*60}")
        print(assembled_code)
        print(f"{'-'*60}\n")
        
        new_state = {
            "generated_code": assembled_code
        }
        
        if self.logger:
            formatted_prompt = self.code_assembler.get_last_formatted_prompt() or "No prompt available"
            response = self.code_assembler.get_last_response() or "No response available"
            self.logger.log_step("assemble_ego", formatted_prompt, response)
        
        return new_state

    def _adversarial_objects_generation_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Generate adversarial objects using AdversarialObjectsGenerator (with RAG context)."""
        print("\n👤 Step: Generating adversarial objects")
        
        interpretation = state.get("interpretation", "")
        previous_assembled = state.get("generated_code", "")
        
        adversarial_objects_code = self.adversarial_objects_generator.process(interpretation, previous_assembled)
        
        print(f"✅ Adversarial objects generation completed")
        print(f"📄 Adversarial objects code length: {len(adversarial_objects_code)} characters")
        
        new_state = {
            "adversarial_objects_code": adversarial_objects_code
        }
        
        if self.logger:
            formatted_prompt = self.adversarial_objects_generator.get_last_formatted_prompt() or "No prompt available"
            response = self.adversarial_objects_generator.get_last_response() or "No response available"
            self.logger.log_step("adversarial_objects_generation", formatted_prompt, response)
        
        return new_state

    def _assemble_adversarial_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Assemble adversarial objects code with previous assembled code."""
        print("\n🔨 Step: Assembling adversarial objects")
        
        adversarial_objects_code = state.get("adversarial_objects_code", "")
        previous_assembled = state.get("generated_code", "")
        
        assembled_code = self.code_assembler.process(
            previous_assembled_code=previous_assembled,
            new_component=adversarial_objects_code,
            component_type="adversarial_objects"
        )
        
        print(f"✅ Adversarial objects assembly completed")
        print(f"\n👤 Assembled code snippet:\n{'-'*60}")
        print(assembled_code)
        print(f"{'-'*60}\n")
        
        new_state = {
            "generated_code": assembled_code
        }
        
        if self.logger:
            formatted_prompt = self.code_assembler.get_last_formatted_prompt() or "No prompt available"
            response = self.code_assembler.get_last_response() or "No response available"
            self.logger.log_step("assemble_adversarial", formatted_prompt, response)
        
        return new_state

    def _behavior_generation_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Generate behavior code using BehaviorGenerator (with RAG context)."""
        print("\n🎭 Step: Generating behavior definitions")
        
        interpretation = state.get("interpretation", "")
        previous_assembled = state.get("generated_code", "")
        
        behavior_code = self.behavior_generator.process(interpretation, previous_assembled)
        
        print(f"✅ Behavior generation completed")
        print(f"📄 Behavior code length: {len(behavior_code)} characters")
        
        new_state = {
            "behavior_code": behavior_code
        }
        
        if self.logger:
            formatted_prompt = self.behavior_generator.get_last_formatted_prompt() or "No prompt available"
            response = self.behavior_generator.get_last_response() or "No response available"
            self.logger.log_step("behavior_generation", formatted_prompt, response)
        
        return new_state

    def _assemble_behavior_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Assemble behavior code with previous assembled code (final assembly)."""
        print("\n🔨 Step: Assembling behavior definitions (final assembly)")
        
        behavior_code = state.get("behavior_code", "")
        previous_assembled = state.get("generated_code", "")
        
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
        
        new_state = {
            "generated_code": assembled_code,
            "messages": state.get("messages", []) + [
                AIMessage(content=f"Complete assembled Scenic code:\n```scenic\n{assembled_code}\n```")
            ]
        }
        
        if self.logger:
            formatted_prompt = self.code_assembler.get_last_formatted_prompt() or "No prompt available"
            response = self.code_assembler.get_last_response() or "No response available"
            self.logger.log_step("assemble_behavior", formatted_prompt, response)
        
        return new_state

    def _validate_node(self, state: WorkflowState) -> WorkflowState:
        """Node: Validate generated code using CodeValidator."""
        print("\n✓ Step: Validating generated code")
        generated_code = state.get("generated_code", "")
        
        if not generated_code:
            print("❌ No code to validate")
            validation_result = {
                "valid": False,
                "error": "No code generated",
                "code": ""
            }
            new_state = {
                "validation_result": validation_result
            }
            
            if self.logger:
                prompt_content = f"Code Validator (no prompt, direct validation):\n\nCode to validate: {generated_code or 'No code provided'}"
                response_content = f"Validation Result: {validation_result['error']}"
                self.logger.log_step("validate", prompt_content, response_content)
            
            return new_state
        
        validation_result = self.validator.process(generated_code)
        
        if validation_result.get("valid"):
            print("✅ Code validation succeeded")
        else:
            error_msg = validation_result.get('error', 'Unknown error')
            print(f"❌ Code validation failed: {error_msg}")
        
        new_state = {
            "validation_result": validation_result
        }
        
        if self.logger:
            prompt_content = f"Code Validator (no prompt, direct validation):\n\nCode to validate:\n{generated_code}"
            response_content = f"Validation Result:\nValid: {validation_result.get('valid', False)}\nError: {validation_result.get('error', 'None')}"
            self.logger.log_step("validate", prompt_content, response_content)
        
        return new_state

    def _error_correction_node(self, state: WorkflowState) -> WorkflowState:
        print("\n🔧 Step: Correcting errors in code")
        
        validation_result = state.get("validation_result", {})
        retry_count = state.get("retry_count", 0)
        
        dsl_code = validation_result.get("code", "")
        error_message = validation_result.get("error", "Unknown error")
        
        print(f"❌ Error to fix: {error_message[:200]}...")
        print(f"🔄 Retry attempt: {retry_count + 1}/{self.max_retries}")
        
        corrected_code = self.error_corrector.process(dsl_code, error_message)
        
        corrected_code_with_header = self.header_generator.process(corrected_code)
        
        print(f"✅ Error correction completed")
        print(f"📄 Corrected code length: {len(corrected_code_with_header)} characters (with header)")
        
        new_state = {
            "generated_code": corrected_code_with_header,
            "retry_count": retry_count + 1,
            "messages": state.get("messages", []) + [
                HumanMessage(content=f"Error correction request (retry {retry_count + 1})"),
                AIMessage(content=f"Corrected Scenic code:\n```scenic\n{corrected_code_with_header}\n```")
            ]
        }
        
        if self.logger: 
            formatted_prompt = self.error_corrector.get_last_formatted_prompt() or "No prompt available"
            response = self.error_corrector.get_last_response() or "No response available"
            self.logger.log_step("error_correction", formatted_prompt, response)
        
        return new_state

    def _check_validation_result(self, state: WorkflowState) -> Literal["error_correction", "end"]:
        print("\n✨ Step: Checking validation results")
        
        validation_result = state.get("validation_result", {})
        retry_count = state.get("retry_count", 0)

        is_valid = validation_result.get("valid", False)
        
        if is_valid:
            print("✅ Validation successful - ending workflow")
            if self.logger:
                prompt_content = "Validation Check (decision node, no prompt)"
                response_content = "Validation successful - ending workflow"
                self.logger.log_step("check_validation_result", prompt_content, response_content)
            return "end"
        
        if retry_count >= self.max_retries:
            print(f"\n⛔ Maximum retries ({self.max_retries}) reached - ending workflow")
            print(f"⚠️ Returning code with errors")
            generated_code = state.get("generated_code", "")
            error_message = validation_result.get("error", "Unknown error")
            print(f"\n❌ Final Error: {error_message}")
            print(f"\n📄 Wrong Code Output:\n{'-'*60}")
            print(generated_code)
            print(f"{'-'*60}\n")
            if self.logger:
                prompt_content = "Validation Check (decision node, no prompt)"
                response_content = f"Maximum retries ({self.max_retries}) reached\nFinal Error: {error_message}\n\nCode:\n{generated_code}"
                self.logger.log_step("check_validation_result", prompt_content, response_content)
            return "end"
        
        print(f"🔄 Validation failed - proceeding with error correction (retry {retry_count + 1}/{self.max_retries})")
        if self.logger:
            prompt_content = "Validation Check (decision node, no prompt)"
            response_content = f"Validation failed - proceeding with error correction (retry {retry_count + 1}/{self.max_retries})"
            self.logger.log_step("check_validation_result", prompt_content, response_content)
        return "error_correction"

    def run(self, user_input: str) -> str:
        """
        Run the complete workflow with user input.
        
        Args:
            user_input: User's natural language query
            
        Returns:
            Final generated and validated Scenic code
        """
        self.logger = WorkflowLogger()
        workflow_dir = self.logger.create_workflow_folder(user_input)
        print(f"📁 Logging workflow to: {workflow_dir}")
        
        print("\n" + "="*50)
        print("🚀 Starting Agent Workflow")
        print("="*50)
        print(f"📥 User input: {user_input}")
        print("="*50 + "\n")
        
        config = {"configurable": {"thread_id": self.thread_id}}
        
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
        
        final_code = output.get("generated_code", "")
        validation_result = output.get("validation_result", {})
        
        print("\n" + "="*50)
        print("📤 Workflow Completed")
        print("="*50)
        
        if self.logger:
            prompt_content = "Final Result (summary, no prompt)"
            if validation_result.get("valid"):
                response_content = f"Workflow completed successfully\n\nFinal Code:\n{final_code}"
            else:
                error_msg = validation_result.get("error", "Unknown error")
                response_content = f"Workflow completed with errors (max retries reached)\nError: {error_msg}\n\nFinal Code:\n{final_code}"
            self.logger.log_step("final_result", prompt_content, response_content)
        
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
        
        self.logger = None
        
        return final_code


if __name__ == "__main__":
    workflow = AgentWorkflow()
    workflow.run("The ego vehicle is driving on a straight road when a pedestrian suddenly crosses from the right front and suddenly stops as the ego vehicle approaches.")