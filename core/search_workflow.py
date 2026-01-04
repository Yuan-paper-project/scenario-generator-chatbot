from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import START, END, StateGraph
from langgraph.graph.message import add_messages
from langchain_core.messages import HumanMessage, AIMessage
from typing import Literal, TypedDict, Annotated
import logging
import re
import time

from .agents.code2logical_agent import Code2LogicalAgent
from .agents.component_scoring_agent import ComponentScoringAgent
from .agents.component_assembler_agent import ComponentAssemblerAgent
from .agents.component_generator_agent import ComponentGeneratorAgent
from .agents.CodeValidator import CodeValidator
from .agents.ErrorCorrector import ErrorCorrector
from .agents.HeaderGenerator import HeaderGeneratorAgent
from .agents.settings_detector_agent import SettingsDetectorAgent
from .config import get_settings
from .scenario_milvus_client import ScenarioMilvusClient
from utilities.parser import parse_json_from_text
from utilities.AgentLogger import get_agent_logger

settings = get_settings()


class SearchWorkflowState(TypedDict):
    messages: Annotated[list, add_messages]
    user_query: str
    logical_interpretation: str
    user_feedback: str
    confirmation_status: str
    search_results: list
    selected_code: str
    adapted_code: str
    workflow_status: str
    scenario_score: dict
    component_scores: dict
    retrieved_components: dict
    original_components: dict
    component_replacements: dict
    processed_components: set
    validation_error: str
    retry_count: int
    selected_blueprint: str
    selected_map: str
    selected_weather: str
    auto_correction: bool
    generation_start_time: float
    component_sources: dict


class SearchWorkflow:
    def __init__(self, thread_id: str = "search_thread"):
        self.thread_id = thread_id
        self.code2logical = Code2LogicalAgent()
        self.scoring_agent = ComponentScoringAgent()
        self.assembler_agent = ComponentAssemblerAgent()
        self.generator_agent = ComponentGeneratorAgent() 
        self.code_validator = CodeValidator()
        self.error_corrector = ErrorCorrector()
        self.header_generator = HeaderGeneratorAgent()
        self.settings_detector = SettingsDetectorAgent()
        self.generation_threshold = 50
        
        try:
            self.milvus_client = ScenarioMilvusClient(collection_name="scenario_components_with_subject")
        except Exception as e:
            self.milvus_client = None
        
        self.workflow = StateGraph(state_schema=SearchWorkflowState)
        
        self.workflow.add_node("interpret_query", self._interpret_query_node)
        self.workflow.add_node("handle_feedback", self._handle_feedback_node)
        self.workflow.add_node("detect_settings", self._detect_settings_node)
        self.workflow.add_node("generate_header", self._generate_header_node)
        self.workflow.add_node("search_scenario", self._search_scenario_node)
        self.workflow.add_node("score_components", self._score_components_node)
        self.workflow.add_node("search_snippets", self._search_snippets_node)
        self.workflow.add_node("assemble_code", self._assemble_code_node)
        self.workflow.add_node("validate_code", self._validate_code_node)
        self.workflow.add_node("correct_error", self._correct_error_node)
        
        self.workflow.add_conditional_edges(
            START,
            self._decide_start_point,
            {
                "interpret": "interpret_query",
                "feedback": "handle_feedback",
                "search": "detect_settings",
                "validate": "validate_code"
            }
        )
        
        self.workflow.add_conditional_edges(
            "interpret_query",
            self._check_confirmation,
            {
                "confirmed": "detect_settings",
                "needs_feedback": END
            }
        )
        
        self.workflow.add_conditional_edges(
            "handle_feedback",
            self._after_feedback,
            {
                "search": "detect_settings",
                "needs_feedback": END
            }
        )
        
        self.workflow.add_edge("detect_settings", "generate_header")
        self.workflow.add_edge("generate_header", "search_scenario")
        self.workflow.add_edge("search_scenario", "score_components")
        
        self.workflow.add_conditional_edges(
            "score_components",
            self._check_components_satisfied,
            {
                "all_satisfied": "assemble_code",
                "needs_refinement": "search_snippets"
            }
        )
        
        self.workflow.add_conditional_edges(
            "search_snippets",
            self._after_search_or_generate,
            {
                "continue_refinement": "search_snippets",
                "done": "assemble_code"
            }
        )
        # self.workflow.add_edge("assemble_code", "adapt_code")
        # self.workflow.add_edge("adapt_code", "apply_user_selections")
        self.workflow.add_edge("assemble_code", END)
        
        self.workflow.add_conditional_edges(
            "validate_code",
            self._check_validation_status,
            {
                "success": END,
                "retry": "correct_error",
                "failed": END
            }
        )
        self.workflow.add_edge("correct_error", "validate_code")
        
        self.memory = MemorySaver()
        self.app = self.workflow.compile(checkpointer=self.memory)
       
    def _decide_start_point(self, state: SearchWorkflowState) -> Literal["interpret", "feedback", "search", "validate"]:
        if state.get("workflow_status") == "validation_requested":
            return "validate"
        if state.get("confirmation_status") == "rejected":
            return "feedback"
        elif state.get("logical_interpretation"):
            return "search"
        return "interpret"
    
    def _check_confirmation(self, state: SearchWorkflowState) -> Literal["confirmed", "needs_feedback"]:
        return "confirmed" if state.get("confirmation_status") == "confirmed" else "needs_feedback"
    
    def _after_feedback(self, state: SearchWorkflowState) -> Literal["search", "needs_feedback"]:
        return "search" if state.get("confirmation_status") == "confirmed" else "needs_feedback"
    
    def _retrieve_components_by_scenario_id(self, scenario_id: str) -> dict:
        if not self.milvus_client:
            return {}
        try:
            return self.milvus_client.get_all_components_by_scenario_id(scenario_id)
        except Exception as e:
            logging.error(f"❌ Failed to retrieve components for {scenario_id}: {e}")
            return {}
    
    def _interpret_query_node(self, state: SearchWorkflowState):
        agent_logger = get_agent_logger()
        if agent_logger:
            agent_logger.log_workflow_event("node_entry", {
                "node": "interpret_query",
                "user_query": state.get("user_query", "")
            })
        
        logical_interpretation = self.code2logical.process(state["user_query"])
        
        formatted_response = (
            f"**Logical Scenario Structure:**\n{logical_interpretation}\n\n"
            f"**Next steps:**\n"
            f"- To proceed, reply with 'yes' or 'ok'.\n"
            f"- If you need changes, reply with specific feedback."
        )
        state["logical_interpretation"] = logical_interpretation
        state["workflow_status"] = "awaiting_confirmation"
        state["messages"].append(AIMessage(content=formatted_response))
        
        if agent_logger:
            agent_logger.log_workflow_event("node_exit", {
                "node": "interpret_query",
                "logical_interpretation": logical_interpretation,
                "workflow_status": state["workflow_status"]
            })
        
        return state
    
    def _handle_feedback_node(self, state: SearchWorkflowState):
        agent_logger = get_agent_logger()
        if agent_logger:
            agent_logger.log_workflow_event("node_entry", {
                "node": "handle_feedback",
                "user_feedback": state.get("user_feedback", "")
            })
        
        updated_interpretation = self.code2logical.adapt(
            state.get("user_query", ""),
            state.get("logical_interpretation", ""),
            state.get("user_feedback", "")
        )
        
        formatted_response = (
            f"**Updated Logical Scenario Structure:**\n{updated_interpretation}\n\n"
            f"**Next steps:**\n"
            f"- To proceed, reply with 'yes' or 'ok'.\n"
            f"- If you need changes, reply with specific feedback."
        )
        
        state["logical_interpretation"] = updated_interpretation
        state["workflow_status"] = "awaiting_confirmation"
        state["messages"].append(AIMessage(content=formatted_response))
        
        if agent_logger:
            agent_logger.log_workflow_event("node_exit", {
                "node": "handle_feedback",
                "updated_interpretation": updated_interpretation
            })
        
        return state
    
    def _score_components_node(self, state: SearchWorkflowState):
        agent_logger = get_agent_logger()
        if agent_logger:
            agent_logger.log_workflow_event("node_entry", {
                "node": "score_components",
                "scenario_id": state.get("search_results", [{}])[0].get("scenario_id", "")
            })
        
        if not state.get("search_results"):
            return state
        
        scenario_id = state["search_results"][0].get("scenario_id")
        
        logging.info(f"📝 Preparing to generate components based on user requirements")
        
        logical_interpretation = state["logical_interpretation"]
        user_criteria_dict = parse_json_from_text(logical_interpretation)
        
        # Initialize component_scores with all components marked as unsatisfied
        # This will force generation of all components
        component_scores = {}
        retrieved_components = state.get("retrieved_components", {})
        
        for component_type, user_criteria in user_criteria_dict.items():
            if component_type in ["Scenario", "Header"]:
                continue
            
            if component_type == "Adversarials":
                # For adversarials, create individual scores for each
                if isinstance(user_criteria, list):
                    individual_scores = []
                    for i, criteria in enumerate(user_criteria):
                        individual_scores.append({
                            "score": 0,
                            "is_satisfied": False,
                            "differences": "Component needs to be generated",
                            "user_criteria": criteria,
                            "retrieved_description": "NOT FOUND"
                        })
                    component_scores["Adversarials"] = {
                        "score": 0,
                        "is_satisfied": False,
                        "differences": "All adversarial components need to be generated",
                        "individual_scores": individual_scores,
                        "user_criteria": user_criteria,
                        "retrieved_description": []
                    }
            else:
                # For single components
                component_scores[component_type] = {
                    "score": 0,
                    "is_satisfied": False,
                    "differences": "Component needs to be generated",
                    "user_criteria": user_criteria,
                    "retrieved_description": "NOT FOUND"
                }
                logging.info(f"📝 Component Type: {component_type} - will be generated")
        
        state["component_scores"] = component_scores
        state["retrieved_components"] = retrieved_components
        
        logging.info(f"📝 All {len(component_scores)} components will be generated from scratch")
        
        if agent_logger:
            agent_logger.log_workflow_event("node_exit", {
                "node": "score_components",
                "satisfied_count": 0,
                "total_components": len(component_scores),
                "component_scores_summary": {k: v['score'] for k, v in component_scores.items()}
            })
        
        return state
    
    def _score_all_components(self, user_criteria_dict: dict, retrieved_components: dict, scenario_id: str) -> dict:
        component_scores = {}
        components_to_score = {}
        
        for component_type in user_criteria_dict.keys():
            if component_type in ["Scenario", "Header", "Requirement and restrictions", "Adversarials"]:
                continue

            if component_type in retrieved_components:
                components_to_score[component_type] = {
                    "user_criteria": user_criteria_dict[component_type],
                    "retrieved_description": retrieved_components[component_type]["description"],
                    "component_code": retrieved_components[component_type].get("code", "")
                }
            else:
                component_scores[component_type] = {
                    "score": 0,
                    "is_satisfied": False,
                    "differences": f"User Criteria: {user_criteria_dict[component_type]}\nRetrieved: NOT FOUND",
                    "user_criteria": user_criteria_dict[component_type],
                    "retrieved_description": "NOT FOUND"
                }
                logging.info(f"📝Component Type: {component_type}, Score: 0, Scenario Id: {scenario_id}")
        
        if components_to_score:
            scoring_results = self.scoring_agent.score_multiple_components(components_to_score, scenario_id)
            component_scores.update(scoring_results)
        
        if "Adversarials" in user_criteria_dict:
            advs_list = retrieved_components.get("Adversarials", [])
            component_scores["Adversarials"] = self._score_list_component(
                "Adversarial", user_criteria_dict["Adversarials"], advs_list, scenario_id
            )
            retrieved_components["Adversarials"] = advs_list
        
        components_unsatisfied = any(
            not component_scores.get(comp, {}).get('is_satisfied')
            for comp in ["Adversarials"]
            if comp in component_scores
        )
        
        if components_unsatisfied and "Requirement and restrictions" in user_criteria_dict:
            if "Requirement and restrictions" in retrieved_components:
                req_result = self.scoring_agent.score_component(
                    component_type="Requirement and restrictions",
                    user_criteria=user_criteria_dict["Requirement and restrictions"],
                    retrieved_description=retrieved_components["Requirement and restrictions"]["description"],
                    scenario_id=scenario_id,
                    component_code=retrieved_components["Requirement and restrictions"].get("code", "")
                )
                component_scores["Requirement and restrictions"] = req_result
        
        return component_scores
    
    def _score_list_component(self, component_name: str, user_list: list, retrieved_list: list, scenario_id: str) -> dict:
        individual_scores = []
        num_needed = len(user_list)
        num_retrieved = len(retrieved_list)
        
        
        if num_retrieved > num_needed:
            scored_candidates = []
            for i, user_criteria in enumerate(user_list):
                best_match_idx = None
                best_score = {"score": 0, "is_satisfied": False}
                
                for j, retrieved_item in enumerate(retrieved_list):
                    if j in [sc['retrieved_idx'] for sc in scored_candidates]:
                        continue
                    
                    score = self.scoring_agent.score_component(
                        component_type=f"{component_name}_{i}",
                        user_criteria=user_criteria,
                        retrieved_description=retrieved_item["description"],
                        scenario_id=scenario_id,
                        component_code=retrieved_item.get("code", "")
                    )
                    
                    if score['score'] > best_score['score']:
                        best_match_idx = j
                        best_score = score
                
                scored_candidates.append({
                    'user_idx': i,
                    'retrieved_idx': best_match_idx,
                    'score': best_score
                })
                individual_scores.append(best_score)
            
            filtered_list = [retrieved_list[sc['retrieved_idx']] for sc in scored_candidates if sc['retrieved_idx'] is not None]
            retrieved_list.clear()
            retrieved_list.extend(filtered_list)
            
        elif num_retrieved < num_needed:
     
            for i, user_criteria in enumerate(user_list):
                if i < num_retrieved:
                    score = self.scoring_agent.score_component(
                        component_type=f"{component_name}_{i}",
                        user_criteria=user_criteria,
                        retrieved_description=retrieved_list[i]["description"],
                        scenario_id=scenario_id,
                        component_code=retrieved_list[i].get("code", "")
                    )
                else:
                    score = {
                        "score": 0,
                        "is_satisfied": False,
                        "differences": f"User Criteria: {user_criteria}\nRetrieved: NOT FOUND",
                        "user_criteria": user_criteria,
                        "retrieved_description": "NOT FOUND"
                    }
                    logging.info(f"📝Component Type: {component_name}_{i}, Score: 0, Scenario Id: {scenario_id}")
                individual_scores.append(score)
        else:
            for i, user_criteria in enumerate(user_list):
                score = self.scoring_agent.score_component(
                    component_type=f"{component_name}_{i}",
                    user_criteria=user_criteria,
                    retrieved_description=retrieved_list[i]["description"],
                    scenario_id=scenario_id,
                    component_code=retrieved_list[i].get("code", "")
                )
                individual_scores.append(score)
        
        avg_score = sum(s["score"] for s in individual_scores) / len(individual_scores) if individual_scores else 0
        all_satisfied = all(s["is_satisfied"] for s in individual_scores)
        
        return {
            "score": avg_score,
            "is_satisfied": all_satisfied,
            "differences": "; ".join([s.get("differences", "") for s in individual_scores if not s["is_satisfied"]]),
            "individual_scores": individual_scores,
            "user_criteria": user_list,
            "retrieved_description": [item.get("description", "") for item in retrieved_list]
        }
    
    def _check_components_satisfied(self, state: SearchWorkflowState) -> Literal["all_satisfied", "needs_refinement"]:
        component_scores = state.get("component_scores", {})
        
        if not component_scores:
            return "all_satisfied"
        
        all_satisfied = all(result['is_satisfied'] for result in component_scores.values())
        
        if all_satisfied:
            logging.info("✅ All components satisfied")
            return "all_satisfied"
        
        unsatisfied = [comp for comp, result in component_scores.items() if not result['is_satisfied']]
        logging.info(f"🔍 Searching better matches for {len(unsatisfied)} components: {unsatisfied}")
        return "needs_refinement"
    
    def _search_snippets_node(self, state: SearchWorkflowState):
        component_scores = state.get("component_scores", {})
        retrieved_components = state.get("retrieved_components", {})
        processed_components = state.get("processed_components", set())
        
        if not component_scores:
            return state
        
        processing_order = ["Spatial Relation", "Ego", "Adversarials", "Requirement and restrictions"]
        
        unsatisfied_components = [
            comp for comp in processing_order
            if comp in component_scores and not component_scores[comp]['is_satisfied']
        ]
        
        if not unsatisfied_components:
            return state
        
        component_sources = state.get("component_sources", {})
        
        for component_type in unsatisfied_components:
            if component_type == "Adversarials":
                if component_type in processed_components:
                    continue
                score_result = component_scores[component_type]
                logging.info(f" 🛠️ Processing component: {component_type}")
                self._process_list_component(
                    "Adversarial", "Adversarials", score_result, retrieved_components, component_scores, processed_components, component_sources
                )
            else:
                if component_type in processed_components:
                    continue
                score_result = component_scores[component_type]
                logging.info(f" 🛠️ Processing component: {component_type}")
                self._process_single_component(
                    component_type, score_result, retrieved_components, component_scores, processed_components, component_sources
                )
        
        state["retrieved_components"] = retrieved_components
        state["component_scores"] = component_scores
        state["processed_components"] = processed_components
        state["component_sources"] = component_sources
        
        return state
    
    def _after_search_or_generate(self, state: SearchWorkflowState) -> Literal["continue_refinement", "done"]:
        component_scores = state.get("component_scores", {})
        processed_components = state.get("processed_components", set())
        
        if not component_scores:
            return "done"
        
        processing_order = ["Spatial Relation", "Ego", "Adversarials", "Requirement and restrictions"]
        
        for comp in processing_order:
            if comp not in component_scores:
                continue
                
            if comp == "Adversarials":
                score_result = component_scores[comp]
                individual_scores = score_result.get('individual_scores', [])
                
                for i, ind_score in enumerate(individual_scores):
                    item_key = f"{comp}_{i}"
                    if item_key not in processed_components:
                        logging.info(f"🔄 Component {item_key} not yet processed. Continuing refinement.")
                        return "continue_refinement"
            else:
                if comp not in processed_components:
                    logging.info(f"🔄 Component {comp} not yet processed. Continuing refinement.")
                    return "continue_refinement"
        
        logging.info("✅ All components processed")
        return "done"
    
    def _process_list_component(self, component_name: str, component_type: str, 
                               score_result: dict, retrieved_components: dict, component_scores: dict, processed_components: set,
                               component_sources: dict = None):
        if component_sources is None:
            component_sources = {}
        
        individual_scores = score_result.get('individual_scores', [])
        user_criteria_list = score_result.get('user_criteria', [])
        current_list = retrieved_components.get(component_type, [])
        
        for i, (ind_score, user_criteria) in enumerate(zip(individual_scores, user_criteria_list)):
            item_key = f"{component_type}_{i}"
            
            if ind_score.get('is_satisfied') or item_key in processed_components:
                continue
            
            processed_components.add(item_key)
            
            # Always generate new component
            logging.info(f"🛠️ Generating new {component_name} {i+1}")
            generated = self._generate_component(
                component_name, user_criteria, retrieved_components, component_scores
            )
            
            if generated:
                if i < len(current_list):
                    current_list[i] = generated['component']
                else:
                    current_list.append(generated['component'])
                individual_scores[i] = generated['score_result']
                component_sources[item_key] = "GENERATED"
                logging.info(f"✅ Generated {component_name} {i+1}")
        
        retrieved_components[component_type] = current_list
        avg_score = sum(s["score"] for s in individual_scores) / len(individual_scores) if individual_scores else 0
        all_satisfied = all(s["is_satisfied"] for s in individual_scores)
        
        component_scores[component_type] = {
            "score": avg_score,
            "is_satisfied": all_satisfied,
            "differences": "; ".join([s.get("differences", "") for s in individual_scores if not s["is_satisfied"]]),
            "individual_scores": individual_scores,
            "user_criteria": user_criteria_list,
            "retrieved_description": [item.get("description", "") for item in current_list]
        }
    
    def _process_single_component(self, component_type: str, score_result: dict,
                                  retrieved_components: dict, component_scores: dict, processed_components: set,
                                  component_sources: dict = None):
        
        if component_type in processed_components:
            return

        processed_components.add(component_type)
        
        if component_sources is None:
            component_sources = {}
        
        logging.info(f"🛠️ Processing {component_type}")
        user_criteria = score_result.get('user_criteria', '')
        
        try:
            # Always generate new component
            logging.info(f"🛠️ Generating new {component_type}")
            generated = self._generate_component(
                component_type, user_criteria, retrieved_components, component_scores
            )
            
            if generated:
                logging.info(f"✅ Generated {component_type}")
                retrieved_components[component_type] = generated['component']
                component_scores[component_type] = generated['score_result']
                component_sources[component_type] = "GENERATED"
        except Exception as e:
            logging.error(f"❌ Failed to process {component_type}: {e}")
    
    def _search_component_candidates(self, user_criteria: str, component_type: str, index: int = None):
        component_name = f"{component_type}_{index}" if index is not None else component_type
        
        try:
            results = self.milvus_client.search_components_by_type(
                query=user_criteria, component_type=component_type.capitalize(), limit=5
            )
            
            if not results:
                return None, {"score": 0, "is_satisfied": False}
            
            best_candidate = None
            best_score = {"score": 0, "is_satisfied": False}
            
            for idx, hit in enumerate(results, 1):
                entity = hit.entity
                candidate_score = self.scoring_agent.score_component(
                    component_type=component_name,
                    user_criteria=user_criteria,
                    retrieved_description=entity.get("description", ""),
                    component_code=entity.get("code", "")
                )
                
                if candidate_score['score'] > best_score['score']:
                    best_candidate = {
                        "description": entity.get("description", ""),
                        "code": entity.get("code", ""),
                        "scenario_id": entity.get("scenario_id", "")
                    }
                    best_score = candidate_score
                
                if candidate_score['score'] >= 85:
                    break
            
            return best_candidate, best_score
        except Exception as e:
            logging.error(f"❌ Search failed: {e}")
            return None, {"score": 0, "is_satisfied": False}
    
    def _evaluate_candidates(self, results: list, component_type: str, user_criteria: str):
        best_candidate = None
        best_score = {"score": 0, "is_satisfied": False}
        
        for idx, hit in enumerate(results, 1):
            entity = hit.entity
            candidate_score = self.scoring_agent.score_component(
                component_type=component_type,
                user_criteria=user_criteria,
                retrieved_description=entity.get("description", ""),
                component_code=entity.get("code", "")
            )
            
            if candidate_score['score'] > best_score['score']:
                best_candidate = {
                    "description": entity.get("description", ""),
                    "code": entity.get("code", ""),
                    "scenario_id": entity.get("scenario_id", "")
                }
                best_score = candidate_score
            
            if candidate_score['score'] >= 85:
                break
        
        return best_candidate, best_score
    
    def _build_ready_components(self, retrieved_components: dict, component_scores: dict, current_component: str) -> dict:
        processing_order = ["Header", "Spatial Relation", "Ego", "Adversarials", "Requirement and restrictions"]
        ready_components = {}
        
        for comp_type in processing_order:
            if comp_type == current_component:
                break
            
            if comp_type not in retrieved_components:
                continue
            
            comp_data = retrieved_components.get(comp_type, {})
            
            if comp_type == "Adversarials":
                if isinstance(comp_data, list):
                    adv_codes = [adv.get("code", "") for adv in comp_data if adv.get("code")]
                    if adv_codes:
                        ready_components[comp_type] = adv_codes
            else:
                if isinstance(comp_data, dict) and comp_data.get("code"):
                    ready_components[comp_type] = comp_data.get("code", "")
        
        return ready_components
    
    def _generate_component(self, component_type: str, user_criteria: str, retrieved_components: dict, component_scores: dict = None):
        if component_scores is None:
            component_scores = {}
        
        ready_components = self._build_ready_components(retrieved_components, component_scores, component_type)
        
        generated_component = self.generator_agent.generate_component(
            component_type=component_type,
            user_criteria=user_criteria,
            ready_components=ready_components
        )
        
        if not generated_component.get("code"):
            return None
        
        logging.info(f"✅ Generated new component: {component_type}")
        
        generated_score = {
            "score": 100,
            "is_satisfied": True,
            "differences": "Generated component (not scored)",
            "user_criteria": user_criteria,
            "retrieved_description": generated_component["description"]
        }
        
        return {
            "component": generated_component,
            "score": 100,
            "score_result": generated_score
        }
    
    def _assemble_code_node(self, state: SearchWorkflowState):
        retrieved_components = state.get("retrieved_components", {})
        
        if not retrieved_components:
            return state
        
        logging.info(f"🧩 Assembling scenario by concatenating components")
        logging.info(f"🔍 Available components: {list(retrieved_components.keys())}")
        
        component_order = ["Header", "Spatial Relation", "Ego", "Adversarials", "Requirement and restrictions"]
        code_parts = []
        
        for component_type in component_order:
            if component_type not in retrieved_components:
                logging.info(f"⚠️ Component {component_type} not found in retrieved_components")
                continue
            
            comp_data = retrieved_components.get(component_type, {})
            
            if component_type == "Adversarials":
                if isinstance(comp_data, list):
                    for adv in comp_data:
                        if isinstance(adv, dict) and adv.get("code"):
                            code_parts.append(adv.get("code", ""))
                            logging.info(f"✅ Added {component_type} code")
            else:
                if isinstance(comp_data, dict) and comp_data.get("code"):
                    code_parts.append(comp_data.get("code", ""))
                    logging.info(f"✅ Added {component_type} code")
                else:
                    logging.info(f"⚠️ Component {component_type} has no code. Type: {type(comp_data)}, Keys: {comp_data.keys() if isinstance(comp_data, dict) else 'N/A'}")
        
        final_code = "\n\n".join(code_parts)
        
        state["selected_code"] = final_code
        state["adapted_code"] = final_code
        
        start_time = state.get("generation_start_time", time.time())
        end_time = time.time()
        duration = end_time - start_time
        minutes = int(duration // 60)
        seconds = duration % 60
        time_str = f"{minutes}m {seconds:.2f}s" if minutes > 0 else f"{seconds:.2f}s"
        
        component_sources = state.get("component_sources", {})
        logging.info("=" * 30)
        logging.info("SCENARIO GENERATION SUMMARY")
        logging.info("=" * 30)
        logging.info(f"Total Generation Time: {time_str}")
        logging.info("")
        logging.info("Component Sources:")
        logging.info("-" * 30)
        for comp_type in ["Header", "Ego", "Adversarials", "Spatial Relation", "Requirement and restrictions"]:
            if comp_type in component_sources:
                logging.info(f"  {comp_type:30s} -> {component_sources[comp_type]}")
            elif comp_type == "Adversarials":
                adv_components = {k: v for k, v in component_sources.items() if k.startswith("Adversarials_")}
                for adv_name, adv_source in sorted(adv_components.items()):
                    display_name = adv_name.replace("_", " ").title()
                    logging.info(f"  {display_name:30s} -> {adv_source}")
        logging.info("=" * 30)
        
        return state
    
    
    def _detect_settings_node(self, state: SearchWorkflowState):
        if "generation_start_time" not in state:
            state["generation_start_time"] = time.time()
        
        if "component_sources" not in state:
            state["component_sources"] = {}
        
        if "retrieved_components" not in state:
            state["retrieved_components"] = {}
        
        if "Header" not in state["retrieved_components"]:
            state["retrieved_components"]["Header"] = {}
        
        user_query = state.get("user_query", "")
        selected_map = state.get("selected_map")
        selected_blueprint = state.get("selected_blueprint")
        selected_weather = state.get("selected_weather")
        
        if not selected_map or not selected_weather or not selected_blueprint:
            logging.info(f"🔍 Auto-detecting settings from user query...")
            detected_settings = self.settings_detector.detect_settings(user_query)
            
            if detected_settings["confidence"] >= 0.6:
                if not selected_weather and detected_settings["weather"]:
                    selected_weather = detected_settings["weather"]
                    logging.info(f"🌤️ Auto-detected weather: {selected_weather} (confidence: {detected_settings['confidence']:.2f})")
                    logging.info(f"   Reasoning: {detected_settings['reasoning']}")
                
                if not selected_map and detected_settings["suggested_map"]:
                    selected_map = detected_settings["suggested_map"]
                    logging.info(f"🗺️ Auto-detected map: {selected_map} (confidence: {detected_settings['confidence']:.2f})")
                    logging.info(f"   Reasoning: {detected_settings['reasoning']}")

                if not selected_blueprint and detected_settings["blueprint"]:
                    selected_blueprint = detected_settings["blueprint"]
                    logging.info(f"🚗 Auto-detected blueprint: {selected_blueprint} (confidence: {detected_settings['confidence']:.2f})")
                    logging.info(f"   Reasoning: {detected_settings['reasoning']}")
            else:
                logging.info(f"⚠️ Low confidence ({detected_settings['confidence']:.2f}) in auto-detection, using defaults")
        
        if not selected_map:
            selected_map = "Town05"
            logging.info(f"🗺️ Using default map: {selected_map}")
        if not selected_weather:
            selected_weather = "ClearNoon"
            logging.info(f"🌤️ Using default weather: {selected_weather}")
        if not selected_blueprint:
            selected_blueprint = "vehicle.lincoln.mkz_2017"
            logging.info(f"🚗 Using default blueprint: {selected_blueprint}")
        
        state["selected_map"] = selected_map
        state["selected_blueprint"] = selected_blueprint
        state["selected_weather"] = selected_weather
        
        return state
    
    def _generate_header_node(self, state: SearchWorkflowState):
        
        agent_logger = get_agent_logger()
        if agent_logger:
            agent_logger.log_workflow_event("node_entry", {
                "node": "generate_header"
            })
        
        user_query = state.get("user_query", "")
        selected_map = state.get("selected_map", "Town05")
        selected_blueprint = state.get("selected_blueprint", "vehicle.lincoln.mkz_2017")
        selected_weather = state.get("selected_weather", "ClearNoon")
        
        logging.info(f"🎨 Generating Header component")
        header_component = self.header_generator.generate_header(
            user_query=user_query,
            carla_map=selected_map,
            blueprint=selected_blueprint,
            weather=selected_weather
        )
        
        state["retrieved_components"]["Header"] = header_component
        state["component_sources"]["Header"] = "GENERATED"
        
        return state
    
    def _search_scenario_node(self, state: SearchWorkflowState):
        
        agent_logger = get_agent_logger()
        if agent_logger:
            agent_logger.log_workflow_event("node_entry", {
                "node": "search_scenario",
                "logical_interpretation": state.get("logical_interpretation", "")
            })
        
        if not self.milvus_client:
            state["workflow_status"] = "completed"
            state["messages"].append(AIMessage(content="Error: Milvus database not connected."))
            return state
        
        logical_interpretation = parse_json_from_text(state["logical_interpretation"])
        scenario_description = logical_interpretation.get("Scenario", "")
        
        logging.info(f"🔍 Searching for scenarios")
        
        try:
            results = self.milvus_client.search_scenario(query=scenario_description, limit=5)
            
            if not results:
                state["workflow_status"] = "completed"
                state["messages"].append(AIMessage(content="No matching scenario found."))
                return state
            
            best_hit = results[0]
            entity = best_hit.entity
            search_result = {
                "scenario_id": entity.get("scenario_id", ""),
                "component_type": entity.get("component_type"),
                "description": entity.get("description"),
                "code": entity.get("code", ""),
                "score": float(best_hit.score)
            }
            
            logging.info(f"✅ Selected scenario: {search_result['scenario_id']}")
            
            state["selected_code"] = search_result["code"]
            state["search_results"] = [search_result]
            
            if agent_logger:
                agent_logger.log_workflow_event("node_exit", {
                    "node": "search_scenario",
                    "scenario_id": search_result['scenario_id'],
                    "search_score": search_result['score']
                })
        except Exception as e:
            logging.error(f"❌ Search failed: {e}")
            state["workflow_status"] = "completed"
            state["messages"].append(AIMessage(content=f"Error searching database: {e}"))
        return state
    

    def _validate_code_node(self, state: SearchWorkflowState):
        agent_logger = get_agent_logger()
        if agent_logger:
            agent_logger.log_workflow_event("node_entry", {
                "node": "validate_code",
                "retry_count": state.get("retry_count", 0)
            })
        
        adapted_code = state.get("adapted_code", "")
        retry_count = state.get("retry_count", 0)
        auto_correction = state.get("auto_correction", True)

        if not adapted_code:
            state["workflow_status"] = "completed"
            state["messages"].append(AIMessage(content="🛑 Workflow failed: No code to validate."))
            return state

        validation_result = self.code_validator.process(adapted_code)

        if validation_result["valid"]:
            formatted_output = (
                f"```scenic\n{adapted_code}\n```\n\n"
                f"✅ **Workflow completed!** The scenario code has been successfully generated and validated.\n\n"
                f"💡 You can start a new query anytime by typing your next scenario description."
            )
            state["messages"].append(AIMessage(content=formatted_output))
            state["workflow_status"] = "completed"
            state["validation_error"] = None
            
            if agent_logger:
                agent_logger.log_workflow_event("node_exit", {
                    "node": "validate_code",
                    "validation_status": "valid"
                })
        else:
            state["validation_error"] = validation_result["error"]
            if auto_correction and retry_count < 3:
                state["workflow_status"] = "correction_in_progress"
                logging.info(f"⚠️ Validation failed (attempt {retry_count + 1}/3). Retrying...")
                state["messages"].append(AIMessage(content=f"⚠️ Validation failed. Attempting to correct... (Attempt {retry_count + 1}/3)\nError: {validation_result['error']}"))
            else:
                error_message = validation_result["error"]
                formatted_output = (
                    f"⚠️ **Workflow completed with validation errors!**\n\n"
                    f"```scenic\n{adapted_code}\n```\n\n"
                    f"**Error:**\n```{error_message}```\n"
                )
                state["messages"].append(AIMessage(content=formatted_output))
                state["workflow_status"] = "completed"
            
            if agent_logger:
                agent_logger.log_workflow_event("node_exit", {
                    "node": "validate_code",
                    "validation_status": "invalid",
                    "error": validation_result["error"]
                })
        
        return state

    def _check_validation_status(self, state: SearchWorkflowState) -> Literal["success", "retry", "failed"]:
        if state.get("workflow_status") == "completed":
             if state.get("validation_error"):
                 return "failed"
             return "success"
        return "retry"

    def _correct_error_node(self, state: SearchWorkflowState):
        error = state.get("validation_error")
        code = state.get("adapted_code")
        
        if not error or not code:
            return state
            
        logging.info("⚙️ Starting error correction")
        new_code = self.error_corrector.process(code, error)
        
        state["adapted_code"] = new_code
        state["retry_count"] = state.get("retry_count", 0) + 1
        
        return state
    
    def _prepare_state(self, user_input, user_feedback, validate_only, code_to_validate, selected_blueprint, selected_map, selected_weather, auto_correction):
        config = {"configurable": {"thread_id": self.thread_id}}
        
        current_state = self.app.get_state(config)
        
        if current_state.values:
            state = dict(current_state.values)
        else:
            state = {
                "messages": [],
                "user_query": "",
                "logical_interpretation": "",
                "user_feedback": "",
                "confirmation_status": "",
                "search_results": [],
                "selected_code": "",
                "adapted_code": "",
                "workflow_status": "",
                "component_scores": {},
                "retrieved_components": {},
                "component_replacements": {},
                "processed_components": set(),
                "validation_error": None,
                "retry_count": 0,
                "selected_blueprint": None,
                "selected_map": None,
                "selected_weather": None
            }
        
        if selected_blueprint: state["selected_blueprint"] = selected_blueprint
        if selected_map: state["selected_map"] = selected_map
        if selected_weather: state["selected_weather"] = selected_weather
        
        state["auto_correction"] = auto_correction

        if validate_only:
             state["workflow_status"] = "validation_requested"
             if code_to_validate:
                 state["adapted_code"] = code_to_validate
        
             state["retry_count"] = 0
             
        elif user_feedback:
            user_feedback_lower = user_feedback.strip().lower()
            if user_feedback_lower in ["yes", "ok", "y", "confirm"]:
                state["confirmation_status"] = "confirmed"
                state["user_feedback"] = ""
            else:
                state["confirmation_status"] = "rejected"
                state["user_feedback"] = user_feedback
            state["messages"].append(HumanMessage(content=user_feedback))
        elif user_input:
            state["user_query"] = user_input
            state["messages"].append(HumanMessage(content=user_input))
            
        return state, config

    def run(self, user_input: str = "", user_feedback: str = "", validate_only: bool = False, code_to_validate: str = "", selected_blueprint: str = None, selected_map: str = None, selected_weather: str = None, auto_correction: bool = True):
        state, config = self._prepare_state(user_input, user_feedback, validate_only, code_to_validate, selected_blueprint, selected_map, selected_weather, auto_correction)
        result = self.app.invoke(state, config)
        return result
    
    def get_conversation_history(self):
        config = {"configurable": {"thread_id": self.thread_id}}
        current_state = self.app.get_state(config)
        
        if current_state.values:
            return current_state.values.get("messages", [])
        return []
    
    def close(self):
        try:
            if self.milvus_client:
                self.milvus_client.close()
        except Exception as e:
            logging.warning(f"Warning during MilvusClient cleanup: {e}")
        
        try:
            if self.generator_agent:
                self.generator_agent.close()
        except Exception as e:
            logging.warning(f"Warning during ComponentGeneratorAgent cleanup: {e}")