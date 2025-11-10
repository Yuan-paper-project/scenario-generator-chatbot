from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import START, END, StateGraph
from langgraph.graph.message import add_messages
from langchain_core.messages import HumanMessage, AIMessage
from typing import Literal, TypedDict, Annotated, Optional

from .agents.Interpretor import InterpretorAgent
from .agents.LogicalScenarioInterpreter import LogicalScenarioInterpreter
from .agents.DetailEnricher import DetailEnricher
from .agents.FeedbackHandler import FeedbackHandler
from .agents.CodeGenerator import CodeGenerator
from .agents.CodeValidator import CodeValidator
from .agents.CodeVerifier import CodeVerifier
from .agents.CodeRefiner import CodeRefiner
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
    logical_interpretation: str
    interpretation: str
    user_feedback: str
    confirmation_status: str
    header_code: str
    road_code: str
    ego_vehicle_code: str
    adversarial_objects_code: str
    behavior_code: str
    generated_code: str
    validation_result: dict
    retry_count: int
    workflow_status: str
    current_component_type: str
    verification_satisfied: bool
    verification_suggestions: str
    component_retry_count: int


class AgentWorkflow:
    
    def __init__(self, thread_id: str = "default_thread", max_retries: int = 3):
        self.thread_id = thread_id
        self.max_retries = max_retries
        self.logger: Optional[WorkflowLogger] = None
        
        self.interpreter = InterpretorAgent()
        self.logical_interpreter = LogicalScenarioInterpreter()
        self.detail_enricher = DetailEnricher()
        self.feedback_handler = FeedbackHandler()
        self.validator = CodeValidator()
        self.code_verifier = CodeVerifier()
        self.code_refiner = CodeRefiner()
        self.error_corrector = ErrorCorrector()
        self.header_generator = HeaderGenerator()
        self.road_generator = RoadGenerator()
        self.ego_vehicle_setup = EgoVehicleSetup()
        self.adversarial_objects_generator = AdversarialObjectsGenerator()
        self.behavior_generator = BehaviorGenerator()
        self.code_assembler = CodeAssembler()
        
        self.workflow = StateGraph(state_schema=WorkflowState)
        
        self.workflow.add_node("logical_interpreter", self._logical_interpret_node)
        self.workflow.add_node("handle_logical_feedback", self._handle_logical_feedback_node)
        self.workflow.add_node("detail_enrichment", self._detail_enrichment_node)
        self.workflow.add_node("handle_detailed_feedback", self._handle_detailed_feedback_node)
        self.workflow.add_node("header_generation", self._header_generation_node)
        self.workflow.add_node("assemble_header", self._assemble_header_node)
        self.workflow.add_node("road_generation", self._road_generation_node)
        self.workflow.add_node("verify_code", self._verify_code_node)
        self.workflow.add_node("refine_code", self._refine_code_node)
        self.workflow.add_node("assemble_road", self._assemble_road_node)
        self.workflow.add_node("ego_vehicle_setup", self._ego_vehicle_setup_node)
        self.workflow.add_node("assemble_ego", self._assemble_ego_node)
        self.workflow.add_node("adversarial_objects_generation", self._adversarial_objects_generation_node)
        self.workflow.add_node("assemble_adversarial", self._assemble_adversarial_node)
        self.workflow.add_node("behavior_generation", self._behavior_generation_node)
        self.workflow.add_node("assemble_behavior", self._assemble_behavior_node)
        self.workflow.add_node("validate", self._validate_node)
        self.workflow.add_node("error_correction", self._error_correction_node)
        
        # Conditional routing from START - decide start point (logical interpretation, detail enrichment, code generation, or start new)
        self.workflow.add_conditional_edges(
            START,
            self._decide_start_point,
            {
                "handle_logical_feedback": "handle_logical_feedback", # when user does not confirm logical scenario and provides feedback on logical scenario
                "handle_detailed_feedback": "handle_detailed_feedback", # when user does not confirm detailed scenario and provides feedback on detailed scenario
                "proceed_to_details": "detail_enrichment", # when user confirm logical scenario
                "proceed_to_code": "header_generation", # when user confirm detailed scenario
                "start_new": "logical_interpreter"
            }
        )
        
        # Conditional routing after logical interpretation
        self.workflow.add_conditional_edges(
            "logical_interpreter",
            self._check_confirmation,
            {
                "wait": END,  
                "refine": "handle_logical_feedback",
                "confirm": "detail_enrichment"
            }
        )
        
        self.workflow.add_edge("handle_logical_feedback", "logical_interpreter")
        
        # Conditional routing after detail enrichment
        self.workflow.add_conditional_edges(
            "detail_enrichment",
            self._check_confirmation,
            {
                "wait": END,  
                "refine": "handle_detailed_feedback",
                "confirm": "header_generation"
            }
        )
        
        self.workflow.add_edge("handle_detailed_feedback", "detail_enrichment")
        self.workflow.add_edge("header_generation", "assemble_header")
        self.workflow.add_edge("assemble_header", "road_generation")
        self.workflow.add_edge("road_generation", "verify_code")
        
        self.workflow.add_conditional_edges(
            "verify_code",
            self._check_verification_result,
            {
                "assemble_road": "assemble_road",
                "assemble_ego": "assemble_ego",
                "assemble_adversarial": "assemble_adversarial",
                "assemble_behavior": "assemble_behavior",
                "refine": "refine_code"
            }
        )
        
        self.workflow.add_edge("refine_code", "verify_code")
        
        self.workflow.add_edge("assemble_road", "ego_vehicle_setup")
        self.workflow.add_edge("ego_vehicle_setup", "verify_code")
        self.workflow.add_edge("assemble_ego", "adversarial_objects_generation")
        self.workflow.add_edge("adversarial_objects_generation", "verify_code")
        self.workflow.add_edge("assemble_adversarial", "behavior_generation")
        self.workflow.add_edge("behavior_generation", "verify_code")
        self.workflow.add_edge("assemble_behavior", "validate")
        
        self.workflow.add_conditional_edges(
            "validate",
            self._check_validation_result,
            {
                "error_correction": "error_correction",
                "end": "set_completed_status"
            }
        )
        
        self.workflow.add_node("set_completed_status", self._set_completed_status_node)
        self.workflow.add_edge("set_completed_status", END)
        self.workflow.add_edge("error_correction", "validate")
        
        self.memory = MemorySaver()
        self.app = self.workflow.compile(checkpointer=self.memory)
        print("\n" + "="*50)
        print("Workflow Graph Structure:")
        print("="*50)
        print(self.app.get_graph().draw_ascii())
        print("="*50 + "\n")

    def _decide_start_point(self, state: WorkflowState) -> Literal["handle_logical_feedback", "handle_detailed_feedback", "proceed_to_details", "proceed_to_code", "start_new"]:
        confirmation_status = state.get("confirmation_status", "")
        user_feedback = state.get("user_feedback", "").strip().lower()

        if user_feedback and confirmation_status == "pending_logical":
            if user_feedback in ["yes", "ok"]:
                return "proceed_to_details"
            else:
                return "handle_logical_feedback"
        elif user_feedback and confirmation_status == "pending_detailed":
            if user_feedback in ["yes", "ok"]:
                return "proceed_to_code"
            else:
                return "handle_detailed_feedback"
        else:
            return "start_new"

    def _logical_interpret_node(self, state: WorkflowState) -> WorkflowState:
        existing_logical = state.get("logical_interpretation", "")
        user_feedback = state.get("user_feedback", "").strip().lower()
        confirmation_status = state.get("confirmation_status", "")
        
        # If we have a logical interpretation and no user feedback and we are waiting for logical confirmation, return the waiting logical confirmation state
        if existing_logical and not user_feedback and confirmation_status == "pending_logical":
            return {
                "workflow_status": "waiting_logical_confirmation"
            }
        
        user_query = state.get("user_query", "")
        
        result = self.logical_interpreter.process(user_query)
        logical_interpretation = result.get("logical_interpretation", "")
        
        new_state = {
            "logical_interpretation": logical_interpretation,
            "confirmation_status": "pending_logical",
            "workflow_status": "waiting_logical_confirmation",
            "user_feedback": "",
            "messages": state.get("messages", []) + [HumanMessage(content=user_query)]
        }
        
        if self.logger:
            formatted_prompt = self.logical_interpreter.get_last_formatted_prompt() or "No prompt available"
            response = self.logical_interpreter.get_last_response() or "No response available"
            self.logger.log_step("logical_interpreter", formatted_prompt, response)
        
        return new_state

    def _handle_logical_feedback_node(self, state: WorkflowState) -> WorkflowState:
        logical_interpretation = state.get("logical_interpretation", "")
        user_feedback = state.get("user_feedback", "")

        result = self.feedback_handler.process(logical_interpretation, user_feedback)
        new_logical_interpretation = result.get("new_scenario", "")
        
        new_state = {
            "logical_interpretation": new_logical_interpretation,
            "confirmation_status": "pending_logical",
            "workflow_status": "waiting_logical_confirmation",
            "user_feedback": ""
        }
        
        if self.logger:
            formatted_prompt = self.feedback_handler.get_last_formatted_prompt() or "No prompt available"
            response = self.feedback_handler.get_last_response() or "No response available"
            self.logger.log_step("handle_logical_feedback", formatted_prompt, response)
        
        return new_state

    def _detail_enrichment_node(self, state: WorkflowState) -> WorkflowState:
        existing_detailed = state.get("interpretation", "")
        user_feedback = state.get("user_feedback", "").strip().lower()
        confirmation_status = state.get("confirmation_status", "")
        
        if existing_detailed and not user_feedback and confirmation_status == "pending_detailed":
            return {
                "workflow_status": "waiting_detailed_confirmation"
            }
        
        logical_interpretation = state.get("logical_interpretation", "")
        
        result = self.detail_enricher.process(logical_interpretation)
        detailed_interpretation = result.get("detailed_interpretation", "")
        
        new_state = {
            "interpretation": detailed_interpretation,
            "confirmation_status": "pending_detailed",
            "workflow_status": "waiting_detailed_confirmation",
            "user_feedback": ""
        }
        
        if self.logger:
            formatted_prompt = self.detail_enricher.get_last_formatted_prompt() or "No prompt available"
            response = self.detail_enricher.get_last_response() or "No response available"
            self.logger.log_step("detail_enrichment", formatted_prompt, response)
        
        return new_state

    def _handle_detailed_feedback_node(self, state: WorkflowState) -> WorkflowState:
        detailed_interpretation = state.get("interpretation", "")
        user_feedback = state.get("user_feedback", "")
        
        result = self.feedback_handler.process(detailed_interpretation, user_feedback)
        new_detailed_interpretation = result.get("new_scenario", "")
        
        new_state = {
            "interpretation": new_detailed_interpretation,
            "confirmation_status": "pending_detailed",
            "workflow_status": "waiting_detailed_confirmation",
            "user_feedback": ""
        }
        
        if self.logger:
            formatted_prompt = self.feedback_handler.get_last_formatted_prompt() or "No prompt available"
            response = self.feedback_handler.get_last_response() or "No response available"
            self.logger.log_step("handle_detailed_feedback", formatted_prompt, response)
        
        return new_state

    def _check_confirmation(self, state: WorkflowState) -> Literal["wait", "refine", "confirm"]:
        user_feedback = state.get("user_feedback", "").strip().lower()
        if user_feedback:
            if user_feedback in ["yes", "ok"]:
                return "confirm"
            else:
                return "refine"
        else:
            return "wait"

    def _header_generation_node(self, state: WorkflowState) -> WorkflowState:
        header_code = self.header_generator.process("")
        
        new_state = {
            "header_code": header_code
        }
        
        if self.logger:
            formatted_prompt = self.header_generator.get_last_formatted_prompt() or "No prompt available"
            response = self.header_generator.get_last_response() or "No response available"
            self.logger.log_step("header_generation", formatted_prompt, response)
        
        return new_state

    def _assemble_header_node(self, state: WorkflowState) -> WorkflowState:
        header_code = state.get("header_code", "")
        previous_assembled = state.get("generated_code", "")
        
        assembled_code = self.code_assembler.process(
            previous_assembled_code=previous_assembled,
            new_component=header_code,
            component_type="header"
        )
        
        new_state = {
            "generated_code": assembled_code
        }
        
        if self.logger:
            formatted_prompt = self.code_assembler.get_last_formatted_prompt() or "No prompt available"
            response = self.code_assembler.get_last_response() or "No response available"
            self.logger.log_step("assemble_header", formatted_prompt, response)
        
        return new_state

    def _road_generation_node(self, state: WorkflowState) -> WorkflowState:
        interpretation = state.get("interpretation", "")
        previous_assembled = state.get("generated_code", "")

        road_code = self.road_generator.process(interpretation, previous_assembled)
        
        new_state = {
            "road_code": road_code,
            "current_component_type": "road"
        }
        
        if self.logger:
            formatted_prompt = self.road_generator.get_last_formatted_prompt() or "No prompt available"
            response = self.road_generator.get_last_response() or "No response available"
            self.logger.log_step("road_generation", formatted_prompt, response)
        
        return new_state

    def _assemble_road_node(self, state: WorkflowState) -> WorkflowState:
        road_code = state.get("road_code", "")
        previous_assembled = state.get("generated_code", "")
        
        assembled_code = self.code_assembler.process(
            previous_assembled_code=previous_assembled,
            new_component=road_code,
            component_type="road"
        )
        
        new_state = {
            "generated_code": assembled_code
        }
        
        if self.logger:
            formatted_prompt = self.code_assembler.get_last_formatted_prompt() or "No prompt available"
            response = self.code_assembler.get_last_response() or "No response available"
            self.logger.log_step("assemble_road", formatted_prompt, response)
        
        return new_state

    def _ego_vehicle_setup_node(self, state: WorkflowState) -> WorkflowState:
        interpretation = state.get("interpretation", "")
        previous_assembled = state.get("generated_code", "")
        
        ego_vehicle_code = self.ego_vehicle_setup.process(interpretation, previous_assembled)
        
        new_state = {
            "ego_vehicle_code": ego_vehicle_code,
            "current_component_type": "ego_vehicle"
        }
        
        if self.logger:
            formatted_prompt = self.ego_vehicle_setup.get_last_formatted_prompt() or "No prompt available"
            response = self.ego_vehicle_setup.get_last_response() or "No response available"
            self.logger.log_step("ego_vehicle_setup", formatted_prompt, response)
        return new_state

    def _assemble_ego_node(self, state: WorkflowState) -> WorkflowState:
        ego_vehicle_code = state.get("ego_vehicle_code", "")
        previous_assembled = state.get("generated_code", "")
        
        assembled_code = self.code_assembler.process(
            previous_assembled_code=previous_assembled,
            new_component=ego_vehicle_code,
            component_type="ego_vehicle"
        )
        
        new_state = {
            "generated_code": assembled_code
        }
        
        if self.logger:
            formatted_prompt = self.code_assembler.get_last_formatted_prompt() or "No prompt available"
            response = self.code_assembler.get_last_response() or "No response available"
            self.logger.log_step("assemble_ego", formatted_prompt, response)
        
        return new_state

    def _adversarial_objects_generation_node(self, state: WorkflowState) -> WorkflowState:
        interpretation = state.get("interpretation", "")
        previous_assembled = state.get("generated_code", "")
        
        adversarial_objects_code = self.adversarial_objects_generator.process(interpretation, previous_assembled)
        
        new_state = {
            "adversarial_objects_code": adversarial_objects_code,
            "current_component_type": "adversarial_objects"
        }
        
        if self.logger:
            formatted_prompt = self.adversarial_objects_generator.get_last_formatted_prompt() or "No prompt available"
            response = self.adversarial_objects_generator.get_last_response() or "No response available"
            self.logger.log_step("adversarial_objects_generation", formatted_prompt, response)
        
        return new_state

    def _assemble_adversarial_node(self, state: WorkflowState) -> WorkflowState:
        adversarial_objects_code = state.get("adversarial_objects_code", "")
        previous_assembled = state.get("generated_code", "")
        
        assembled_code = self.code_assembler.process(
            previous_assembled_code=previous_assembled,
            new_component=adversarial_objects_code,
            component_type="adversarial_objects"
        )
        
        new_state = {
            "generated_code": assembled_code
        }
        
        if self.logger:
            formatted_prompt = self.code_assembler.get_last_formatted_prompt() or "No prompt available"
            response = self.code_assembler.get_last_response() or "No response available"
            self.logger.log_step("assemble_adversarial", formatted_prompt, response)
        
        return new_state

    def _behavior_generation_node(self, state: WorkflowState) -> WorkflowState:
        interpretation = state.get("interpretation", "")
        previous_assembled = state.get("generated_code", "")
        
        behavior_code = self.behavior_generator.process(interpretation, previous_assembled)

        new_state = {
            "behavior_code": behavior_code,
            "current_component_type": "behavior"
        }
        
        if self.logger:
            formatted_prompt = self.behavior_generator.get_last_formatted_prompt() or "No prompt available"
            response = self.behavior_generator.get_last_response() or "No response available"
            self.logger.log_step("behavior_generation", formatted_prompt, response)
        
        return new_state

    def _verify_code_node(self, state: WorkflowState) -> WorkflowState:
        interpretation = state.get("interpretation", "")
        previous_assembled = state.get("generated_code", "")
        component_type = state.get("current_component_type", "")
        component_retry_count = state.get("component_retry_count", 0)
        
        code_map = {
            "road": "road_code",
            "ego_vehicle": "ego_vehicle_code",
            "adversarial_objects": "adversarial_objects_code",
            "behavior": "behavior_code"
        }
        
        code_key = code_map.get(component_type, "")
        code = state.get(code_key, "")
        
        
        try:
            verification = self.code_verifier.process(
                interpretation=interpretation,
                new_code=code,
                previous_code=previous_assembled,
                component_type=component_type
            )
            
            
            suggestions_text = verification.get("suggestions", "")
        except Exception as e:
            suggestions_text = ""
            verification = {"satisfied": False, "suggestions": ""}
        
        new_state = {
            "verification_satisfied": verification.get("satisfied", False),
            "verification_suggestions": suggestions_text
        }
        
        if verification.get("satisfied", False):
            new_state["component_retry_count"] = 0
        else:
            new_state["component_retry_count"] = component_retry_count + 1
        
        if self.logger:
            formatted_prompt = self.code_verifier.get_last_formatted_prompt() or "No prompt available"
            response = self.code_verifier.get_last_response() or "No response available"
            self.logger.log_step(f"verify_{component_type}", formatted_prompt, response)
        
        return new_state
    
    def _refine_code_node(self, state: WorkflowState) -> WorkflowState:
        interpretation = state.get("interpretation", "")
        previous_assembled = state.get("generated_code", "")
        component_type = state.get("current_component_type", "")
        suggestions = state.get("verification_suggestions", "")
        
        code_map = {
            "road": "road_code",
            "ego_vehicle": "ego_vehicle_code",
            "adversarial_objects": "adversarial_objects_code",
            "behavior": "behavior_code"
        }
        
        code_key = code_map.get(component_type, "")
        original_code = state.get(code_key, "")
        
        refined_code = self.code_refiner.process(
            original_code=original_code,
            suggestions=suggestions,
            interpretation=interpretation,
            previous_code=previous_assembled,
            component_type=component_type
        )
        
        new_state = {
            code_key: refined_code
        }
        
        if self.logger:
            formatted_prompt = self.code_refiner.get_last_formatted_prompt() or "No prompt available"
            response = self.code_refiner.get_last_response() or "No response available"
            self.logger.log_step(f"refine_{component_type}", formatted_prompt, response)
        
        return new_state
    
    def _check_verification_result(self, state: WorkflowState) -> str:
        satisfied = state.get("verification_satisfied", False)
        component_type = state.get("current_component_type", "")
        retry_count = state.get("component_retry_count", 0)
        max_retries = 3
        
        if satisfied:
            assemble_map = {
                "road": "assemble_road",
                "ego_vehicle": "assemble_ego",
                "adversarial_objects": "assemble_adversarial",
                "behavior": "assemble_behavior"
            }
            return assemble_map.get(component_type, "assemble_road")
        else:
            if retry_count >= max_retries:
                assemble_map = {
                    "road": "assemble_road",
                    "ego_vehicle": "assemble_ego",
                    "adversarial_objects": "assemble_adversarial",
                    "behavior": "assemble_behavior"
                }
                return assemble_map.get(component_type, "assemble_road")
            else:
                return "refine"

    def _assemble_behavior_node(self, state: WorkflowState) -> WorkflowState:
        behavior_code = state.get("behavior_code", "")
        previous_assembled = state.get("generated_code", "")
        
        assembled_code = self.code_assembler.process(
            previous_assembled_code=previous_assembled,
            new_component=behavior_code,
            component_type="behavior"
        )
        
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
        generated_code = state.get("generated_code", "")
        
        if not generated_code:
            validation_result = {
                "valid": False,
                "error": "No code generated",
                "code": ""
            }
            new_state = {
                "validation_result": validation_result
            }
            
            if self.logger:
                formatted_prompt = self.validator.get_last_formatted_prompt() or "No prompt available"
                response = self.validator.get_last_response() or "No response available"
                self.logger.log_step("validate", formatted_prompt, response)
                response_content = f"Validation Result: {validation_result['error']}"
            
            return new_state
        
        validation_result = self.validator.process(generated_code)
        new_state = {
            "validation_result": validation_result
        }
        
        if self.logger:
            formatted_prompt = self.validator.get_last_formatted_prompt() or "No prompt available"
            response = self.validator.get_last_response() or "No response available"
            self.logger.log_step("validate", formatted_prompt, response)
        
        return new_state

    def _error_correction_node(self, state: WorkflowState) -> WorkflowState:
        validation_result = state.get("validation_result", {})
        retry_count = state.get("retry_count", 0)
        
        dsl_code = validation_result.get("code", "")
        error_message = validation_result.get("error", "Unknown error")
        
        corrected_code = self.error_corrector.process(dsl_code, error_message)
        
        corrected_code_with_header = self.header_generator.process(corrected_code)
        
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

    def _set_completed_status_node(self, state: WorkflowState) -> WorkflowState:
        new_state = {
            "workflow_status": "completed"
        }
        return new_state

    def _check_validation_result(self, state: WorkflowState) -> Literal["error_correction", "end"]:
        validation_result = state.get("validation_result", {})
        retry_count = state.get("retry_count", 0)

        is_valid = validation_result.get("valid", False)
        
        if is_valid:
            if self.logger:
                formatted_prompt = self.validator.get_last_formatted_prompt() or "No prompt available"
                response = self.validator.get_last_response() or "No response available"
                self.logger.log_step("check_validation_result", formatted_prompt, response)
            return "end"
        
        if retry_count >= self.max_retries:
            return "end"
        
        if self.logger:
            formatted_prompt = self.validator.get_last_formatted_prompt() or "No prompt available"
            response = self.validator.get_last_response() or "No response available"
            self.logger.log_step("check_validation_result", formatted_prompt, response)

        return "error_correction"

    def run(self, user_input: str = "", user_feedback: str = "") -> dict:
        config = {"configurable": {"thread_id": self.thread_id}}
        
        current_state = self._get_current_state(config)
        
        if user_feedback:
            if current_state and current_state.get("user_query"):
                initial_state = {
                    **current_state,
                    "user_feedback": user_feedback
                }
            else:
                return {
                    "workflow_status": "error",
                    "message": "No active scenario to provide feedback on. Please start with a new scenario."
                }
        elif user_input:
            if not self.logger:
                self.logger = WorkflowLogger()
                workflow_dir = self.logger.create_workflow_folder(user_input)
            
            initial_state = {
                "messages": [],
                "user_query": user_input,
                "logical_interpretation": "",
                "interpretation": "",
                "user_feedback": "",
                "confirmation_status": "",
                "header_code": "",
                "road_code": "",
                "ego_vehicle_code": "",
                "adversarial_objects_code": "",
                "behavior_code": "",
                "generated_code": "",
                "validation_result": {},
                "retry_count": 0,
                "workflow_status": "",
                "current_component_type": "",
                "verification_satisfied": False,
                "verification_suggestions": "",
                "component_retry_count": 0
            }
        else:
            return {
                "workflow_status": "error",
                "message": "Either user_input or user_feedback must be provided"
            }
        
        try:
            output = self.app.invoke(initial_state, config)
        except Exception as e:
            import traceback
            error_trace = traceback.format_exc()
            return {
                "workflow_status": "error",
                "message": f"An error occurred: {str(e)}\n\nFull trace:\n{error_trace}"
            }
        
        workflow_status = output.get("workflow_status", "")
        confirmation_status = output.get("confirmation_status", "")
        
        result = {
            "workflow_status": workflow_status,
            "confirmation_status": confirmation_status
        }
        
        if workflow_status == "waiting_logical_confirmation":
            result["scenario"] = output.get("logical_interpretation", "")
            result["scenario_type"] = "logical"
            result["message"] = "Here is the logical scenario structure:"
        elif workflow_status == "waiting_detailed_confirmation":
            result["scenario"] = output.get("interpretation", "")
            result["scenario_type"] = "detailed"
            result["message"] = "Here is the enriched detailed scenario following the logical scenario structure:"
        elif workflow_status == "completed" or output.get("generated_code"):
            final_code = output.get("generated_code", "")
            validation_result = output.get("validation_result", {})
            
            result["workflow_status"] = "completed"
            result["code"] = final_code
            result["valid"] = validation_result.get("valid", False)
            result["message"] = "Code generation completed!"
            
            if self.logger:
                formatted_prompt = self.validator.get_last_formatted_prompt() or "No prompt available"
                response = self.validator.get_last_response() or "No response available"
                self.logger.log_step("final_result", formatted_prompt, response)
            
            self.logger = None
        
        return result

    def _get_current_state(self, config: dict) -> dict:
        try:
            snapshot = self.app.get_state(config)
            if snapshot and snapshot.values:
                return snapshot.values
        except Exception as e:
            print(f"⚠️ Could not retrieve state: {e}")
        
        return {
            "messages": [],
            "user_query": "",
            "logical_interpretation": "",
            "interpretation": "",
            "user_feedback": "",
            "confirmation_status": "",
            "header_code": "",
            "road_code": "",
            "ego_vehicle_code": "",
            "adversarial_objects_code": "",
            "behavior_code": "",
            "generated_code": "",
            "validation_result": {},
            "retry_count": 0,
            "workflow_status": "",
            "current_component_type": "",
            "verification_satisfied": False,
            "verification_suggestions": "",
            "component_retry_count": 0
        }


if __name__ == "__main__":
    workflow = AgentWorkflow()
    workflow.run("The ego vehicle is driving on a straight road when a pedestrian suddenly crosses from the right front and suddenly stops as the ego vehicle approaches.")