from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import START, END, StateGraph
from langgraph.graph.message import add_messages
from langchain_core.messages import HumanMessage, AIMessage
from typing import Literal, TypedDict, Annotated, Optional

from .agents.code2logical_agent import Code2LogicalAgent
from .agents.code_adapter_agent import CodeAdapterAgent
from .agents.component_scoring_agent import ComponentScoringAgent
from .agents.component_assembler_agent import ComponentAssemblerAgent
from .agents.component_generator_agent import ComponentGeneratorAgent
from .agents.CodeValidator import CodeValidator
from .config import get_settings
from .scenario_milvus_client import ScenarioMilvusClient
from utilities.parser import parse_json_from_text

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


class SearchWorkflow:
    def __init__(self, thread_id: str = "search_thread"):
        self.thread_id = thread_id
        self.code2logical = Code2LogicalAgent()
        self.code_adapter = CodeAdapterAgent()
        self.scoring_agent = ComponentScoringAgent()
        self.assembler_agent = ComponentAssemblerAgent()
        self.generator_agent = ComponentGeneratorAgent() 
        self.code_validator = CodeValidator()
        self.generation_threshold = 50
        
        try:
            self.milvus_client = ScenarioMilvusClient(collection_name="scenario_components_with_subject")
        except Exception as e:
            print(f"[ERROR] Failed to initialize ScenarioMilvusClient: {e}")
            self.milvus_client = None
        
        self.workflow = StateGraph(state_schema=SearchWorkflowState)
        
        self.workflow.add_node("interpret_query", self._interpret_query_node)
        self.workflow.add_node("handle_feedback", self._handle_feedback_node)
        self.workflow.add_node("search_scenario", self._search_scenario_node)
        self.workflow.add_node("score_components", self._score_components_node)
        self.workflow.add_node("search_snippets", self._search_snippets_node)
        self.workflow.add_node("assemble_code", self._assemble_code_node)
        self.workflow.add_node("adapt_code", self._adapt_code_node)
        self.workflow.add_node("validate_code", self._validate_code_node)
        
        self.workflow.add_conditional_edges(
            START,
            self._decide_start_point,
            {
                "interpret": "interpret_query",
                "feedback": "handle_feedback",
                "search": "search_scenario"
            }
        )
        
        self.workflow.add_conditional_edges(
            "interpret_query",
            self._check_confirmation,
            {
                "confirmed": "search_scenario",
                "needs_feedback": END
            }
        )
        
        self.workflow.add_conditional_edges(
            "handle_feedback",
            self._after_feedback,
            {
                "search": "search_scenario",
                "needs_feedback": END
            }
        )
        
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
        self.workflow.add_edge("assemble_code", "adapt_code")
        self.workflow.add_edge("adapt_code", "validate_code")
        self.workflow.add_edge("validate_code", END)
        
        self.memory = MemorySaver()
        self.app = self.workflow.compile(checkpointer=self.memory)
       
    def _decide_start_point(self, state: SearchWorkflowState) -> Literal["interpret", "feedback", "search"]:
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
            print(f"[ERROR] Failed to retrieve components for {scenario_id}: {e}")
            return {}
    
    def _interpret_query_node(self, state: SearchWorkflowState):
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
        return state
    
    def _handle_feedback_node(self, state: SearchWorkflowState):
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
        return state
    
    def _score_components_node(self, state: SearchWorkflowState):
        if not state.get("search_results"):
            return state
        
        scenario_id = state["search_results"][0].get("scenario_id")
        
        print(f"\n[INFO] Scoring components")
        
        if not state.get("retrieved_components"):
            retrieved_components = self._retrieve_components_by_scenario_id(scenario_id)
            state["retrieved_components"] = retrieved_components
            state["original_components"] = {k: v.copy() for k, v in retrieved_components.items()}
        else:
            retrieved_components = state["retrieved_components"]
        
        if not retrieved_components:
            return state
        
        logical_interpretation = state["logical_interpretation"]
        user_criteria_dict = parse_json_from_text(logical_interpretation)
        
        ## remove components not in user criteria
        components_to_remove = [
            comp for comp in list(retrieved_components.keys())
            if comp not in ["Scenario"] and comp not in user_criteria_dict
        ]
        
        for component_type in components_to_remove:
            del retrieved_components[component_type]
            if component_type in state.get("original_components", {}):
                del state["original_components"][component_type]

        component_scores = self._score_all_components(
            user_criteria_dict, 
            retrieved_components
        )
        
        if component_scores:
            state["component_scores"] = component_scores
            satisfied_count = sum(1 for r in component_scores.values() if r['is_satisfied'])
            print(f"[INFO] Component Scoring: {satisfied_count}/{len(component_scores)} satisfied")
        
        return state
    
    def _score_all_components(self, user_criteria_dict: dict, retrieved_components: dict) -> dict:
        component_scores = {}
        components_to_score = {}
        
        for component_type in user_criteria_dict.keys():
            if component_type in ["Scenario", "Requirement and restrictions", "Egos", "Adversarials"]:
                continue

            if component_type in retrieved_components:
                components_to_score[component_type] = {
                    "user_criteria": user_criteria_dict[component_type],
                    "retrieved_description": retrieved_components[component_type]["description"]
                }
            else:
                component_scores[component_type] = {
                    "score": 0,
                    "is_satisfied": False,
                    "differences": f"User Criteria: {user_criteria_dict[component_type]}\nRetrieved: NOT FOUND",
                    "user_criteria": user_criteria_dict[component_type],
                    "retrieved_description": "NOT FOUND"
                }
        
        if components_to_score:
            scoring_results = self.scoring_agent.score_multiple_components(components_to_score)
            component_scores.update(scoring_results)
        
        if "Egos" in user_criteria_dict:
            egos_list = retrieved_components.get("Egos", [])
            component_scores["Egos"] = self._score_list_component(
                "Ego", user_criteria_dict["Egos"], egos_list
            )
            retrieved_components["Egos"] = egos_list
        
        if "Adversarials" in user_criteria_dict:
            advs_list = retrieved_components.get("Adversarials", [])
            component_scores["Adversarials"] = self._score_list_component(
                "Adversarial", user_criteria_dict["Adversarials"], advs_list
            )
            retrieved_components["Adversarials"] = advs_list
        
        components_unsatisfied = any(
            not component_scores.get(comp, {}).get('is_satisfied')
            for comp in ["Egos", "Adversarials"]
            if comp in component_scores
        )
        
        if components_unsatisfied and "Requirement and restrictions" in user_criteria_dict:
            if "Requirement and restrictions" in retrieved_components:
                req_result = self.scoring_agent.score_component(
                    component_type="Requirement and restrictions",
                    user_criteria=user_criteria_dict["Requirement and restrictions"],
                    retrieved_description=retrieved_components["Requirement and restrictions"]["description"]
                )
                component_scores["Requirement and restrictions"] = req_result
        
        return component_scores
    
    def _score_list_component(self, component_name: str, user_list: list, retrieved_list: list) -> dict:
        individual_scores = []
        num_needed = len(user_list)
        num_retrieved = len(retrieved_list)
        
        print(f"[INFO] Scoring {component_name}s: need {num_needed}, retrieved {num_retrieved}")
        
        if num_retrieved > num_needed:
            print(f"[INFO]   Retrieved has {num_retrieved - num_needed} extra item(s), evaluating best matches...")
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
                        retrieved_description=retrieved_item["description"]
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
            print(f"[INFO]   Missing {num_needed - num_retrieved} item(s), will need to search/generate...")
            for i, user_criteria in enumerate(user_list):
                if i < num_retrieved:
                    score = self.scoring_agent.score_component(
                        component_type=f"{component_name}_{i}",
                        user_criteria=user_criteria,
                        retrieved_description=retrieved_list[i]["description"]
                    )
                else:
                    score = {
                        "score": 0,
                        "is_satisfied": False,
                        "differences": f"User Criteria: {user_criteria}\nRetrieved: NOT FOUND",
                        "user_criteria": user_criteria,
                        "retrieved_description": "NOT FOUND"
                    }
                individual_scores.append(score)
        else:
            for i, user_criteria in enumerate(user_list):
                score = self.scoring_agent.score_component(
                    component_type=f"{component_name}_{i}",
                    user_criteria=user_criteria,
                    retrieved_description=retrieved_list[i]["description"]
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
            print("[INFO] All components satisfied")
            return "all_satisfied"
        
        unsatisfied = [comp for comp, result in component_scores.items() if not result['is_satisfied']]
        print(f"[INFO] Searching better matches for {len(unsatisfied)} components: {unsatisfied}")
        return "needs_refinement"
    
    def _search_snippets_node(self, state: SearchWorkflowState):
        component_scores = state.get("component_scores", {})
        retrieved_components = state.get("retrieved_components", {})
        
        if not component_scores or not retrieved_components:
            return state
        
        unsatisfied_components = [
            comp for comp, result in component_scores.items()
            if not result['is_satisfied']
        ]
        
        if not unsatisfied_components:
            return state
        
        component_type = unsatisfied_components[0]
        score_result = component_scores[component_type]
        
        print(f"\n[INFO] Processing component: {component_type}")
        
        if component_type == "Egos":
            self._process_list_component(
                "Ego", "Egos", score_result, retrieved_components, component_scores
            )
        elif component_type == "Adversarials":
            self._process_list_component(
                "Adversarial", "Adversarials", score_result, retrieved_components, component_scores
            )
        else:
            self._process_single_component(
                component_type, score_result, retrieved_components, component_scores
            )
        
        state["retrieved_components"] = retrieved_components
        state["component_scores"] = component_scores
        
        return state
    
    def _after_search_or_generate(self, state: SearchWorkflowState) -> Literal["continue_refinement", "done"]:
        component_scores = state.get("component_scores", {})
        
        if not component_scores:
            return "done"
        
        unsatisfied_components = [
            comp for comp, result in component_scores.items()
            if not result['is_satisfied']
        ]
        
        if unsatisfied_components:
            print(f"[INFO] {len(unsatisfied_components)} components remaining: {unsatisfied_components}")
            return "continue_refinement"
        
        print("[INFO] All components processed")
        return "done"
    
    def _process_list_component(self, component_name: str, component_type: str, 
                               score_result: dict, retrieved_components: dict, component_scores: dict):
        print(f"\n[INFO] Processing {component_type}...")
        individual_scores = score_result.get('individual_scores', [])
        user_criteria_list = score_result.get('user_criteria', [])
        current_list = retrieved_components.get(component_type, [])
        
        for i, (ind_score, user_criteria) in enumerate(zip(individual_scores, user_criteria_list)):
            if ind_score.get('is_satisfied'):
                continue
            
            print(f"[INFO]   Searching for better {component_name} {i+1}...")
            best_candidate, best_score = self._search_component_candidates(
                user_criteria, component_name, i
            )
            
            if best_score['score'] >= self.generation_threshold and best_score['is_satisfied']:
                print(f"[INFO]   Found satisfactory match (score: {best_score['score']})")
                if i < len(current_list):
                    current_list[i] = best_candidate
                else:
                    current_list.append(best_candidate)
                individual_scores[i] = best_score
            elif best_score['score'] > ind_score['score']:
                print(f"[INFO]   Found better match (score: {best_score['score']}), but not satisfactory")
                if i < len(current_list):
                    current_list[i] = best_candidate
                else:
                    current_list.append(best_candidate)
                individual_scores[i] = best_score
                
                print(f"[INFO]   Generating new {component_name} {i+1}...")
                generated = self._generate_component(
                    component_name, user_criteria, retrieved_components
                )
                
                if generated and generated['score'] > best_score['score']:
                    print(f"[INFO]   Generated component is better (score: {generated['score']})")
                    if i < len(current_list):
                        current_list[i] = generated['component']
                    else:
                        current_list.append(generated['component'])
                    individual_scores[i] = generated['score_result']
            else:
                print(f"[INFO]   No better match found, generating new {component_name} {i+1}...")
                generated = self._generate_component(
                    component_name, user_criteria, retrieved_components
                )
                
                if generated:
                    if i < len(current_list):
                        current_list[i] = generated['component']
                    else:
                        current_list.append(generated['component'])
                    individual_scores[i] = generated['score_result']
        
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
                                  retrieved_components: dict, component_scores: dict):
        print(f"\n[INFO] Processing {component_type}...")
        user_criteria = score_result.get('user_criteria', '')
        current_score = score_result['score']
        
        try:
            print(f"[INFO]   Searching for better {component_type}...")
            results = self.milvus_client.search_components_by_type(
                query=user_criteria, component_type=component_type, limit=5
            )
            
            if results:
                best_candidate, best_score = self._evaluate_candidates(
                    results, component_type, user_criteria
                )
                
                if best_score['score'] >= self.generation_threshold and best_score['is_satisfied']:
                    print(f"[INFO]   Found satisfactory match (score: {best_score['score']})")
                    retrieved_components[component_type] = best_candidate
                    component_scores[component_type] = best_score
                    return
                elif best_score['score'] > current_score:
                    print(f"[INFO]   Found better match (score: {best_score['score']}), but not satisfactory")
                    retrieved_components[component_type] = best_candidate
                    component_scores[component_type] = best_score
            
            print(f"[INFO]   Generating new {component_type}...")
            generated = self._generate_component(
                component_type, user_criteria, retrieved_components
            )
            
            if generated:
                current_best_score = component_scores.get(component_type, {}).get('score', 0)
                if generated['score'] > current_best_score:
                    print(f"[INFO]   Generated component is better (score: {generated['score']})")
                    retrieved_components[component_type] = generated['component']
                    component_scores[component_type] = generated['score_result']
        except Exception as e:
            print(f"[ERROR] Failed to process {component_type}: {e}")
    
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
                    retrieved_description=entity.get("description", "")
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
            print(f"[ERROR] Search failed: {e}")
            return None, {"score": 0, "is_satisfied": False}
    
    def _evaluate_candidates(self, results: list, component_type: str, user_criteria: str):
        best_candidate = None
        best_score = {"score": 0, "is_satisfied": False}
        
        for idx, hit in enumerate(results, 1):
            entity = hit.entity
            candidate_score = self.scoring_agent.score_component(
                component_type=component_type,
                user_criteria=user_criteria,
                retrieved_description=entity.get("description", "")
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
    
    def _generate_component(self, component_type: str, user_criteria: str, retrieved_components: dict):
        scenario_component = retrieved_components.get("Scenario", {})
        assembled_code = scenario_component.get("code", "")
        
        generated_component = self.generator_agent.generate_component(
            component_type=component_type,
            user_criteria=user_criteria,
            assembled_code=assembled_code
        )
        
        if not generated_component.get("code"):
            return None
        
        generated_score = self.scoring_agent.score_component(
            component_type=component_type,
            user_criteria=user_criteria,
            retrieved_description=generated_component["description"]
        )
        
        print(f"[INFO]   Generated component score: {generated_score['score']}")
        
        return {
            "component": generated_component,
            "score": generated_score['score'],
            "score_result": generated_score
        }
    
    def _assemble_code_node(self, state: SearchWorkflowState):
        retrieved_components = state.get("retrieved_components", {})
        original_components = state.get("original_components", {})
        
        if not retrieved_components:
            return state
        
        search_results = state.get("search_results", [])
        if not search_results:
            state["workflow_status"] = "completed"
            state["messages"].append(AIMessage(content="Error: No search results found."))
            return state
        
        base_scenario_id = search_results[0].get("scenario_id", "Unknown")
        logical_interpretation = state.get("logical_interpretation", "")
        user_criteria_dict = parse_json_from_text(logical_interpretation)
        
        print(f"\n[INFO] Assembling scenario from base: {base_scenario_id}")
        
        scenario_component = retrieved_components.get("Scenario", {})
        base_code = scenario_component.get("code", "")
        
        if not base_code:
            return state
        
        component_scores = state.get("component_scores", {})
        replacements = self._build_replacements(
            component_scores, retrieved_components, original_components
        )
        
        if replacements:
            print(f"[INFO] Applying {len(replacements)} component replacement(s)...")
            final_code = self.assembler_agent.assemble_code(base_code, replacements)
        else:
            final_code = base_code
        
        state["selected_code"] = final_code
        return state
    
    def _build_replacements(self, component_scores: dict, retrieved_components: dict, 
                           original_components: dict) -> dict:
        replacements = {}
        
        for component_type, score_result in component_scores.items():
            if component_type in ["Scenario", "Requirement and restrictions"]:
                continue
            
            if component_type == "Egos":
                original_egos = original_components.get("Egos", [])
                current_egos = retrieved_components.get("Egos", [])
                original_combined = "\n\n".join([ego.get("code", "") for ego in original_egos if ego.get("code")])
                current_combined = "\n\n".join([ego.get("code", "") for ego in current_egos if ego.get("code")])
                
                if original_combined != current_combined:
                    replacements["Egos"] = {
                        "original_code": original_combined,
                        "replacement_code": current_combined,
                        "source_context": ""
                    }
                continue
            
            if component_type == "Adversarials":
                original_adversarials = original_components.get("Adversarials", [])
                current_adversarials = retrieved_components.get("Adversarials", [])
                original_combined = "\n\n".join([adv.get("code", "") for adv in original_adversarials if adv.get("code")])
                current_combined = "\n\n".join([adv.get("code", "") for adv in current_adversarials if adv.get("code")])
                
                if original_combined != current_combined:
                    replacements["Adversarials"] = {
                        "original_code": original_combined,
                        "replacement_code": current_combined,
                        "source_context": ""
                    }
                continue
            
            original_component = original_components.get(component_type, {})
            current_component = retrieved_components.get(component_type, {})
            original_code = original_component.get("code", "")
            current_code = current_component.get("code", "")
            
            should_replace = (
                (not original_code and current_code) or
                (original_code and current_code and original_code != current_code) or
                (not score_result.get('is_satisfied') and current_code)
            )
            
            if should_replace:
                source_scenario_id = current_component.get("scenario_id", "")
                source_context = ""
                
                if source_scenario_id and source_scenario_id != "GENERATED":
                    source_components = self._retrieve_components_by_scenario_id(source_scenario_id)
                    if source_components:
                        source_context = source_components.get("Scenario", {}).get("code", "")
                
                replacements[component_type] = {
                    "original_code": original_code,
                    "replacement_code": current_code,
                    "source_context": source_context
                }
        
        return replacements
    
    def _search_scenario_node(self, state: SearchWorkflowState):
        if not self.milvus_client:
            state["workflow_status"] = "completed"
            state["messages"].append(AIMessage(content="Error: Milvus database not connected."))
            return state
        
        logical_interpretation = parse_json_from_text(state["logical_interpretation"])
        scenario_description = logical_interpretation.get("Scenario", "")
        
        print(f"\n[INFO] Searching for scenarios...")
        
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
            
            print(f"[INFO] Selected scenario: {search_result['scenario_id']}")
            
            state["selected_code"] = search_result["code"]
            state["search_results"] = [search_result]
        except Exception as e:
            print(f"[ERROR] Search failed: {e}")
            state["workflow_status"] = "completed"
            state["messages"].append(AIMessage(content=f"Error searching database: {e}"))
        return state
    
    def _adapt_code_node(self, state: SearchWorkflowState):
        if not state.get("selected_code"):
            return state
        
        logical_interpretation = state["logical_interpretation"]
        selected_code = state["selected_code"]
        
        lines = logical_interpretation.strip().split('\n')
        scenario_description = ""
        for line in lines:
            if line.strip().startswith("Scenario:"):
                scenario_description = line.replace("Scenario:", "").strip()
                break
        
        if not scenario_description:
            scenario_description = state.get("user_query", logical_interpretation)
        
        try:
            adapted_code = self.code_adapter.process(
                user_description=scenario_description,
                retrieved_code=selected_code
            )
            state["adapted_code"] = adapted_code
        except Exception as e:
            print(f"[ERROR] Adaptation failed: {e}")
            state["adapted_code"] = selected_code
        
        state["workflow_status"] = "in_progress"
        return state

    def _validate_code_node(self, state: SearchWorkflowState):
        adapted_code = state.get("adapted_code", "")
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
        else:
            error_message = validation_result["error"]
            formatted_output = (
                f"⚠️ **Workflow completed with validation errors!**\n\n"
                f"```scenic\n{adapted_code}\n```\n\n"
                f"**Error:**\n```{error_message}```\n"
            )
            state["messages"].append(AIMessage(content=formatted_output))
        
        state["workflow_status"] = "completed"
        return state
    
    def run(self, user_input: str = "", user_feedback: str = ""):
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
                "component_replacements": {}
            }
        
        if user_feedback:
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
            print(f"[ERROR] Error closing MilvusClient: {e}")
        
        try:
            if self.generator_agent:
                self.generator_agent.close()
        except Exception as e:
            print(f"[ERROR] Error closing ComponentGeneratorAgent: {e}")

