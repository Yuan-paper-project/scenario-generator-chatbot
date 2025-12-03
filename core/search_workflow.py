from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import START, END, StateGraph
from langgraph.graph.message import add_messages
from langchain_core.messages import HumanMessage, AIMessage
from typing import Literal, TypedDict, Annotated, Optional

from .agents.code2logical_agent import Code2LogicalAgent
from .agents.code_adapter_agent import CodeAdapterAgent
from .agents.component_scoring_agent import ComponentScoringAgent
from .agents.component_assembler_agent import ComponentAssemblerAgent
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
    scenario_score: dict  # Stores overall scenario scoring result
    component_scores: dict  # Stores scoring results for each component
    retrieved_components: dict  # Stores all retrieved components
    original_components: dict  # Stores original component codes before replacement
    component_replacements: dict  # Stores component snippets to replace
    refinement_iteration: int  # Tracks number of refinement iterations


class SearchWorkflow:
    def __init__(self, thread_id: str = "search_thread"):
        self.thread_id = thread_id
        self.code2logical = Code2LogicalAgent()
        self.code_adapter = CodeAdapterAgent()
        self.scoring_agent = ComponentScoringAgent()
        self.assembler_agent = ComponentAssemblerAgent()
        self.max_refinement_iterations = 2  # Maximum number of refinement iterations
        
        try:
            self.milvus_client = ScenarioMilvusClient(collection_name="scenario_components_with_subject")
            print("[INFO] Successfully initialized ScenarioMilvusClient")
        except Exception as e:
            print(f"[WARNING] Failed to initialize ScenarioMilvusClient: {e}")
            self.milvus_client = None
        
        self.workflow = StateGraph(state_schema=SearchWorkflowState)
        
        self.workflow.add_node("interpret_query", self._interpret_query_node)
        self.workflow.add_node("handle_feedback", self._handle_feedback_node)
        self.workflow.add_node("search_scenario", self._search_scenario_node)
        self.workflow.add_node("score_components", self._score_components_node)
        self.workflow.add_node("search_snippets", self._search_snippets_node)
        self.workflow.add_node("assemble_code", self._assemble_code_node)
        self.workflow.add_node("adapt_code", self._adapt_code_node)
        
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
        
        # After searching scenario, go directly to component scoring
        self.workflow.add_edge("search_scenario", "score_components")
        
        self.workflow.add_conditional_edges(
            "score_components",
            self._check_components_satisfied,
            {
                "all_satisfied": "assemble_code",
                "needs_refinement": "search_snippets",
                "max_iterations": "assemble_code"
            }
        )
        
        self.workflow.add_edge("search_snippets", "score_components")
        self.workflow.add_edge("assemble_code", "adapt_code")
        self.workflow.add_edge("adapt_code", END)
        
        self.memory = MemorySaver()
        self.app = self.workflow.compile(checkpointer=self.memory)
    
    def _decide_start_point(self, state: SearchWorkflowState) -> Literal["interpret", "feedback", "search"]:
        if state.get("confirmation_status") == "rejected":
            return "feedback"
        elif state.get("logical_interpretation"):
            return "search"
        else:
            return "interpret"
    
    def _interpret_query_node(self, state: SearchWorkflowState):
        user_query = state["user_query"]
        
        logical_interpretation = self.code2logical.process(user_query)
        
        formatted_response = (
            f"**Logical Scenario Structure:**\n"
            f"{logical_interpretation}\n\n"
            f"**Next steps:**\n"
            f"- To proceed, reply with 'yes' or 'ok'.\n"
            f"- If you need changes, reply with specific feedback."
        )
        
        state["logical_interpretation"] = logical_interpretation
        state["workflow_status"] = "awaiting_confirmation"
        state["messages"].append(AIMessage(content=formatted_response))
        
        return state
    
    def _check_confirmation(self, state: SearchWorkflowState) -> Literal["confirmed", "needs_feedback"]:
        if state.get("confirmation_status") == "confirmed":
            return "confirmed"
        return "needs_feedback"
    
    def _handle_feedback_node(self, state: SearchWorkflowState):
        user_feedback = state.get("user_feedback", "")
        current_interpretation = state.get("logical_interpretation", "")
        original_query = state.get("user_query", "")
        
        updated_interpretation = self.code2logical.adapt(original_query, current_interpretation, user_feedback)
        
        formatted_response = (
            f"**Updated Logical Scenario Structure:**\n"
            f"{updated_interpretation}\n\n"
            f"**Next steps:**\n"
            f"- To proceed, reply with 'yes' or 'ok'.\n"
            f"- If you need changes, reply with specific feedback."
        )
        
        state["logical_interpretation"] = updated_interpretation
        state["workflow_status"] = "awaiting_confirmation"
        state["messages"].append(AIMessage(content=formatted_response))
        
        return state
    
    def _after_feedback(self, state: SearchWorkflowState) -> Literal["search", "needs_feedback"]:
        if state.get("confirmation_status") == "confirmed":
            return "search"
        return "needs_feedback"
    
    def _retrieve_components_by_scenario_id(self, scenario_id: str) -> dict:
        """Retrieve all components for a given scenario_id using ScenarioMilvusClient."""
        if not self.milvus_client:
            return {}
        
        try:
            components = self.milvus_client.get_all_components_by_scenario_id(scenario_id)
            print(f"[INFO] Retrieved {len(components)} components for scenario {scenario_id}")
            return components
        except Exception as e:
            print(f"[ERROR] Failed to retrieve components for scenario {scenario_id}: {e}")
            return {}
    
    
    def _score_components_node(self, state: SearchWorkflowState):
  
        if not state.get("search_results") or len(state["search_results"]) == 0:
            return state
        
        scenario_id = state["search_results"][0].get("scenario_id")
        if not scenario_id:
            print("[WARNING] No scenario_id found in search results")
            return state
        
        if "refinement_iteration" not in state or state["refinement_iteration"] is None:
            state["refinement_iteration"] = 0
        
        print(f"\n[INFO] Scoring components for scenario: {scenario_id} (Iteration: {state['refinement_iteration']})")
        
        if not state.get("retrieved_components"):
            retrieved_components = self._retrieve_components_by_scenario_id(scenario_id)
            state["retrieved_components"] = retrieved_components
            state["original_components"] = {k: v.copy() for k, v in retrieved_components.items()}
            print(f"[DEBUG] Retrieved components from DB: {list(retrieved_components.keys())}")
        else:
            retrieved_components = state["retrieved_components"]
            print(f"[DEBUG] Using cached retrieved components: {list(retrieved_components.keys())}")
        
        if not retrieved_components:
            print("[WARNING] No components retrieved for scoring")
            return state
        
        logical_interpretation = state["logical_interpretation"]
        user_criteria_dict = parse_json_from_text(logical_interpretation) # parse the logical interpretation into a dictionary of user criteria
        
        print(f"[INFO] Parsed {len(user_criteria_dict)} user criteria components")
        if user_criteria_dict:
            print(f"[DEBUG] Parsed components: {list(user_criteria_dict.keys())}")
        else:
            print(f"[DEBUG] Failed to parse any components from logical interpretation")

        if state.get("refinement_iteration", 0) > 0:
            if state.get("component_scores"):
                component_scores = state["component_scores"].copy()
                print(f"[INFO] Refinement iteration {state['refinement_iteration']} - reusing all scores from snippet search (no re-scoring)")
                print(f"[DEBUG] Current scores: {[(k, v['score'], v['is_satisfied']) for k, v in component_scores.items()]}")
            else:
                component_scores = {}
        else:
            components_to_score = {}
            component_scores = {}
            
            for component_type in user_criteria_dict.keys():
                if component_type == "Scenario" or component_type == "Requirement and restrictions":
                    continue

                if component_type in retrieved_components:
                    components_to_score[component_type] = {
                        "user_criteria": user_criteria_dict[component_type],
                        "retrieved_description": retrieved_components[component_type]["description"]
                    }
                else:
                    print(f"[WARNING] Component '{component_type}' from user criteria not found in retrieved components - marking as not satisfied")
                    component_scores[component_type] = {
                        "score": 0,
                        "is_satisfied": False,
                        "differences": f"Component '{component_type}' is missing from the retrieved scenario",
                        "user_criteria": user_criteria_dict[component_type],
                        "retrieved_description": "NOT FOUND"
                    }
            
            if components_to_score:
                print(f"[INFO] Scoring {len(components_to_score)} components...")
                scoring_results = self.scoring_agent.score_multiple_components(components_to_score)
                component_scores.update(scoring_results)
        
        if state.get("refinement_iteration", 0) == 0:
            behavior_unsatisfied = False
            for behavior_type in ["Ego Behavior", "Adversarial Behavior"]:
                if behavior_type in component_scores:
                    is_satisfied = component_scores[behavior_type].get('is_satisfied')
                    print(f"[DEBUG] {behavior_type}: satisfied={is_satisfied}")
                    if not is_satisfied:
                        behavior_unsatisfied = True
                        print(f"[INFO] {behavior_type} is unsatisfied - will also score Requirement and restrictions")
                        break
                else:
                    print(f"[DEBUG] {behavior_type} not in component_scores")
            
            print(f"[DEBUG] behavior_unsatisfied={behavior_unsatisfied}, 'Requirement and restrictions' in user_criteria_dict={'Requirement and restrictions' in user_criteria_dict}")
            
            if behavior_unsatisfied and "Requirement and restrictions" in user_criteria_dict:
                if "Requirement and restrictions" in retrieved_components:
                    print(f"[INFO] Scoring 'Requirement and restrictions' due to unsatisfied behaviors...")
                    req_result = self.scoring_agent.score_component(
                        component_type="Requirement and restrictions",
                        user_criteria=user_criteria_dict["Requirement and restrictions"],
                        retrieved_description=retrieved_components["Requirement and restrictions"]["description"]
                    )
                    component_scores["Requirement and restrictions"] = req_result
                else:
                    print(f"[WARNING] 'Requirement and restrictions' not found in retrieved components")
                    component_scores["Requirement and restrictions"] = {
                        "score": 0,
                        "is_satisfied": False,
                        "differences": "Component 'Requirement and restrictions' is missing from the retrieved scenario",
                        "user_criteria": user_criteria_dict["Requirement and restrictions"],
                        "retrieved_description": "NOT FOUND"
                    }
            else:
                print(f"[INFO] Behaviors satisfied - skipping 'Requirement and restrictions' scoring")
        
        if component_scores:
            state["component_scores"] = component_scores

            # printthe scoring results
            print(f"[INFO] Scoring results: {component_scores}")
            
            satisfied_count = sum(1 for r in component_scores.values() if r['is_satisfied'])
            unsatisfied_count = len(component_scores) - satisfied_count
            
            # Print summary
            print("\n[INFO] ===== Component Scoring Summary =====")
            print(f"[INFO] Satisfied: {satisfied_count}/{len(component_scores)}, Unsatisfied: {unsatisfied_count}")
            for component_type, result in component_scores.items():
                satisfied_str = "✓ SATISFIED" if result['is_satisfied'] else "✗ NOT SATISFIED"
                print(f"[INFO] {component_type}: {result['score']}/100 - {satisfied_str}")
                if not result['is_satisfied']:
                    print(f"[INFO]   Differences: {result.get('differences', '')}")
                print()
            print("[INFO] ======================================\n")
        else:
            print("[WARNING] No components to score")
            state["component_scores"] = {}
        
        return state
    
    def _check_components_satisfied(self, state: SearchWorkflowState) -> Literal["all_satisfied", "needs_refinement", "max_iterations"]:
        component_scores = state.get("component_scores", {})
        
        if not component_scores:
            return "all_satisfied"
        
        iteration = state.get("refinement_iteration", 0)
        if iteration >= self.max_refinement_iterations:
            print(f"[INFO] Max refinement iterations ({self.max_refinement_iterations}) reached")
            return "max_iterations"
        
        all_satisfied = all(result['is_satisfied'] for result in component_scores.values())
        
        if all_satisfied:
            print("[INFO] All components satisfied!")
            return "all_satisfied"
        else:
            unsatisfied = [comp for comp, result in component_scores.items() if not result['is_satisfied']]
            print(f"[INFO] {len(unsatisfied)} component(s) need refinement: {unsatisfied}")
            return "needs_refinement"
    
    def _search_snippets_node(self, state: SearchWorkflowState):
        component_scores = state.get("component_scores", {})
        retrieved_components = state.get("retrieved_components", {})
        
        if not component_scores or not retrieved_components:
            return state
        
        print("\n[INFO] ===== Searching for Better Snippets =====")
        
        unsatisfied_components = {
            comp_type: result 
            for comp_type, result in component_scores.items() 
            if not result['is_satisfied']
        }
        
        if not unsatisfied_components:
            return state
        
        for component_type, score_result in unsatisfied_components.items():
            print(f"\n[INFO] Searching for better {component_type}...")
            
            user_criteria = score_result.get('user_criteria', '')
            
            try:
                results = self.milvus_client.search_components_by_type(
                    query=user_criteria,
                    component_type=component_type,
                    limit=5
                )
                
                if results:
                    best_candidate = None
                    best_candidate_score = score_result
                    current_score_value = score_result['score']
                    excellent_threshold = 85  # Stop early if we find a score >= 85
                    
                    for idx, hit in enumerate(results, 1):
                        entity = hit.entity
                        candidate_desc = entity.get("description", "")
                        candidate_code = entity.get("code", "")
                        candidate_id = entity.get("scenario_id", "")
                        
                        candidate_score = self.scoring_agent.score_component(
                            component_type=component_type,
                            user_criteria=user_criteria,
                            retrieved_description=candidate_desc
                        )
                        
                        print(f"[INFO]   Candidate {idx}/5 score: {candidate_score['score']}/100, Scenario ID: {candidate_id}")
                        
                        if candidate_score['score'] > best_candidate_score['score']:
                            best_candidate = {
                                "description": candidate_desc,
                                "code": candidate_code,
                                "scenario_id": candidate_id
                            }
                            best_candidate_score = candidate_score
                        
                        if candidate_score['score'] >= excellent_threshold:
                            print(f"[INFO]   🎯 Excellent match found (score: {candidate_score['score']}) - stopping search early")
                            break
                    
                    if best_candidate_score['score'] > current_score_value:
                        print(f"[INFO]   ✓ Found better match for {component_type} (score improved from {current_score_value} to {best_candidate_score['score']})")
                        retrieved_components[component_type] = best_candidate
                        component_scores[component_type] = best_candidate_score
                    else:
                        print(f"[INFO]   No better match found for {component_type} (best candidate score: {best_candidate_score['score']}, current: {current_score_value})")
                        
            except Exception as e:
                print(f"[ERROR] Failed to search snippets for {component_type}: {e}")
        
        # Update state
        state["retrieved_components"] = retrieved_components
        state["component_scores"] = component_scores
        state["refinement_iteration"] = state.get("refinement_iteration", 0) + 1
        
        print("[INFO] ==========================================\n")
        
        return state
    
    def _assemble_code_node(self, state: SearchWorkflowState):
        retrieved_components = state.get("retrieved_components", {})
        original_components = state.get("original_components", {})
        
        if not retrieved_components:
            print("[WARNING] No components to assemble")
            return state
        
        # Print summary of base scenario and component replacements
        base_scenario_id = state.get("search_results", [{}])[0].get("scenario_id", "Unknown")
        print("\n" + "="*70)
        print("[INFO] 📋 SCENARIO COMPOSITION SUMMARY")
        print("="*70)
        print(f"[INFO] Base Scenario ID: {base_scenario_id}")
        
        # Check which components have been replaced
        replaced_components = []
        for component_type, component_data in retrieved_components.items():
            if component_type == "Scenario":
                continue
            if component_type == "Requirement and restrictions":
                continue
                
            original_data = original_components.get(component_type, {})
            original_code = original_data.get("code", "")
            current_code = component_data.get("code", "")
            current_scenario_id = component_data.get("scenario_id", "")
            
            if current_code and (not original_code or original_code != current_code):
                if current_scenario_id and current_scenario_id != base_scenario_id:
                    replaced_components.append({
                        "type": component_type,
                        "from_scenario": current_scenario_id
                    })
        
        if replaced_components:
            print(f"[INFO] Replaced Components: {len(replaced_components)}")
            for comp in replaced_components:
                print(f"[INFO]   - {comp['type']}: from Scenario {comp['from_scenario']}")
        else:
            print("[INFO] No components were replaced (using all original components)")
        print("="*70 + "\n")
        
        print("\n[INFO] Assembling final code from components...")
        
        scenario_component = retrieved_components.get("Scenario", {})
        base_code = scenario_component.get("code", "")
        
        if not base_code:
            print("[WARNING] No base scenario code found")
            return state
        
        component_scores = state.get("component_scores", {})
        replacements = {}
        
        for component_type, score_result in component_scores.items():
            if component_type == "Scenario":
                continue  # Skip scenario itself
            
            if component_type == "Requirement and restrictions":
                continue  # Skip description component
            
            original_component_data = original_components.get(component_type, {})
            original_component_code = original_component_data.get("code", "")
            
            current_component_data = retrieved_components.get(component_type, {})
            current_component_code = current_component_data.get("code", "")
            

            should_assemble = False
            
            if not original_component_code and current_component_code:
                should_assemble = True
                print(f"[DEBUG] {component_type} was missing, now found - will assemble")
            
            elif original_component_code and current_component_code and original_component_code != current_component_code:
                should_assemble = True
                print(f"[DEBUG] {component_type} code changed - will assemble")
            
            elif not score_result.get('is_satisfied') and current_component_code:
                should_assemble = True
                print(f"[DEBUG] {component_type} is unsatisfied but has replacement - will assemble")
            
            if should_assemble:
                source_scenario_id = current_component_data.get("scenario_id", "")
                source_context = ""
                
                if source_scenario_id and source_scenario_id != state.get("search_results", [{}])[0].get("scenario_id", ""):
                    print(f"[DEBUG] Fetching source context from scenario {source_scenario_id} for {component_type}")
                    source_components = self._retrieve_components_by_scenario_id(source_scenario_id)
                    if source_components:
                        # Get the full scenario code as context
                        source_context = source_components.get("Scenario", {}).get("code", "")
                
                replacements[component_type] = {
                    "original_code": original_component_code,
                    "replacement_code": current_component_code,
                    "source_context": source_context
                }
                print(f"[DEBUG] Will replace {component_type}: original={'EXISTS' if original_component_code else 'MISSING'}, replacement={'EXISTS' if current_component_code else 'MISSING'}, source_context={'EXISTS' if source_context else 'NOT_NEEDED'}")
        
        if replacements:
            print(f"[INFO] Assembling code with {len(replacements)} component replacement(s)...")
            final_code = self.assembler_agent.assemble_code(base_code, replacements)
        else:
            print("[INFO] No replacements needed, using base scenario code")
            final_code = base_code
        
        state["selected_code"] = final_code
        
        return state
    
    def _search_scenario_node(self, state: SearchWorkflowState):
        # Search for top 5 scenarios, score them, and select the best one (>85 preferred).
        if not self.milvus_client:
            state["workflow_status"] = "completed"
            state["messages"].append(AIMessage(content="Error: Milvus database not connected."))
            return state
        
        logical_interpretation = parse_json_from_text(state["logical_interpretation"])
        scenario_description = logical_interpretation.get("Scenario", "")
        
        if not scenario_description:
            state["workflow_status"] = "completed"
            state["messages"].append(AIMessage(content="Error: No scenario description found."))
            return state
        
        print(f"\n[INFO] ===== Searching for Scenarios =====")
        print(f"[INFO] User query: {scenario_description[:100]}...")
        
        try:
            # Search for top 5 candidate scenarios
            results = self.milvus_client.search_scenario(
                query=scenario_description,
                limit=5
            )
            
            if not results:
                state["workflow_status"] = "completed"
                state["messages"].append(AIMessage(content="No matching scenario found."))
                return state
            
            print(f"[INFO] Found {len(results)} candidate scenarios")
            
            # Print all candidates and select the one with highest vector score (first result)
            for idx, hit in enumerate(results, 1):
                hit_entity = hit.entity
                hit_id = hit_entity.get("scenario_id", "")
                hit_score = float(hit.score)
                hit_desc = hit_entity.get("description", "")
                print(f"[INFO] Candidate {idx}: Scenario ID: {hit_id}, Vector Score: {hit_score:.4f}")
                print(f"       Description: {hit_desc[:80]}...")
            
            # Use the scenario with highest vector score (first result)
            best_hit = results[0]
            entity = best_hit.entity
            candidate_id = entity.get("scenario_id", "")
            vector_score = float(best_hit.score)
            code = entity.get("code", "")
            
            search_result = {
                "scenario_id": candidate_id,
                "component_type": entity.get("component_type"),
                "description": entity.get("description"),
                "code": code,
                "score": vector_score
            }
            
            print(f"\n[INFO] ✅ Selected Scenario: {search_result['scenario_id']}")
            print(f"[INFO]   Vector Score: {vector_score:.4f}")
            print(f"[INFO]   Will proceed to component-level scoring and refinement.")
            
            state["selected_code"] = code
            state["search_results"] = [search_result]
                
        except Exception as e:
            print(f"[ERROR] Error searching database: {e}")
            import traceback
            traceback.print_exc()
            state["workflow_status"] = "completed"
            state["messages"].append(AIMessage(content=f"Error searching database: {e}"))
        
        return state
    
    def _adapt_code_node(self, state: SearchWorkflowState):
        # Skip if no code was found
        if not state.get("selected_code"):
            return state
        
        logical_interpretation = state["logical_interpretation"]
        selected_code = state["selected_code"]
        
        # Extract just the scenario description from the logical interpretation
        lines = logical_interpretation.strip().split('\n')
        scenario_description = ""
        for line in lines:
            if line.strip().startswith("Scenario:"):
                scenario_description = line.replace("Scenario:", "").strip()
                break
        
        if not scenario_description:
            # Fallback: use the user's original query instead
            scenario_description = state.get("user_query", logical_interpretation)
        
        print(f"\n[DEBUG] Adapting code...")
        print(f"[DEBUG] User description: {scenario_description[:100]}...")
        print(f"[DEBUG] Retrieved code length: {len(selected_code)} chars")
        # print(f"[DEBUG] Retrieved code has proper newlines: {'\\n' in selected_code}")
        print(f"[DEBUG] First 300 chars of retrieved code:")
        print(selected_code[:300])
        
        try:
            # Adapt the retrieved code to match the user's description
            adapted_code = self.code_adapter.process(
                user_description=scenario_description,
                retrieved_code=selected_code
            )
            
            
            state["adapted_code"] = adapted_code
            state["workflow_status"] = "completed"
            # Wrap in code block for proper display in Gradio
            formatted_output = f"```scenic\n{adapted_code}\n```\n\n✅ **Workflow completed!** The scenario code has been successfully generated.\n\n💡 You can start a new query anytime by typing your next scenario description."
            state["messages"].append(AIMessage(content=formatted_output))
        except Exception as e:
            print(f"[DEBUG] Adaptation failed: {e}")
            # If adaptation fails, return the original code
            state["adapted_code"] = selected_code
            state["workflow_status"] = "completed"
            formatted_output = f"⚠️ Warning: Code adaptation failed, returning original: {e}\n\n```scenic\n{selected_code}\n```\n\n✅ **Workflow completed!** You can start a new query anytime by typing your next scenario description."
            state["messages"].append(AIMessage(content=formatted_output))
        
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
                "component_replacements": {},
                "refinement_iteration": 0
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
        """Clean up resources."""
        try:
            if self.milvus_client:
                self.milvus_client.close()
                print("[INFO] MilvusClient closed successfully")
        except Exception as e:
            print(f"[WARNING] Error closing MilvusClient: {e}")

