from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import START, END, StateGraph
from langgraph.graph.message import add_messages
from langchain_core.messages import HumanMessage, AIMessage
from typing import Literal, TypedDict, Annotated, Optional
from pymilvus import connections, Collection

from .agents.code2logical_agent import Code2LogicalAgent
from .agents.code_adapter_agent import CodeAdapterAgent
from .config import get_settings
from .embedding import EmbeddingModel

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


class SearchWorkflow:
    def __init__(self, thread_id: str = "search_thread"):
        self.thread_id = thread_id
        self.code2logical = Code2LogicalAgent()
        self.code_adapter = CodeAdapterAgent()
        self.embedding_model = EmbeddingModel()
        
        try:
            connections.connect(uri=settings.MILVUS_URI, token=settings.MILVUS_TOKEN)
            self.collection = Collection("scenario_components")
            self.collection.load()
        except Exception as e:
            print(f"Warning: Failed to connect to Milvus: {e}")
            self.collection = None
        
        self.workflow = StateGraph(state_schema=SearchWorkflowState)
        
        self.workflow.add_node("interpret_query", self._interpret_query_node)
        self.workflow.add_node("handle_feedback", self._handle_feedback_node)
        self.workflow.add_node("search_scenario", self._search_scenario_node)
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
                "reinterpret": "interpret_query"
            }
        )
        
        self.workflow.add_edge("search_scenario", "adapt_code")
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
        
        state["logical_interpretation"] = logical_interpretation
        state["workflow_status"] = "awaiting_confirmation"
        state["messages"].append(AIMessage(content=logical_interpretation))
        
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
        
        state["logical_interpretation"] = updated_interpretation
        state["workflow_status"] = "awaiting_confirmation"
        state["messages"].append(AIMessage(content=updated_interpretation))
        
        return state
    
    def _after_feedback(self, state: SearchWorkflowState) -> Literal["search", "reinterpret"]:
        if state.get("confirmation_status") == "confirmed":
            return "search"
        return "reinterpret"
    
    def _search_scenario_node(self, state: SearchWorkflowState):
        if not self.collection:
            state["workflow_status"] = "completed"
            state["messages"].append(AIMessage(content="Error: Milvus database not connected."))
            return state
        
        logical_interpretation = state["logical_interpretation"]
        
        lines = logical_interpretation.strip().split('\n')
        scenario_description = ""
        for line in lines:
            if line.strip().startswith("Scenario:"):
                scenario_description = line.replace("Scenario:", "").strip()
                break
        
        if not scenario_description:
            scenario_description = logical_interpretation
        
        query_embedding = self.embedding_model.embedding.embed_query(scenario_description)
        
        search_params = {
            "metric_type": "COSINE",
            "params": {"nprobe": 10}
        }
        
        try:
            results = self.collection.search(
                data=[query_embedding],
                anns_field="embedding",
                param=search_params,
                limit=1,
                expr='component_type == "Scenario"',
                output_fields=["scenario_id", "component_type", "description", "code"]
            )
            
            if results and len(results[0]) > 0:
                hit = results[0][0]
                entity = hit.entity
                code = entity.get("code", "")
                
                search_result = {
                    "scenario_id": entity.get("scenario_id"),
                    "component_type": entity.get("component_type"),
                    "description": entity.get("description"),
                    "code": code,
                    "score": float(hit.score)
                }
                
                state["selected_code"] = code
                state["search_results"] = [search_result]
                # Don't mark as completed yet, pass to adaptation node
            else:
                state["workflow_status"] = "completed"
                state["messages"].append(AIMessage(content="No matching scenario found."))
        except Exception as e:
            state["workflow_status"] = "completed"
            state["messages"].append(AIMessage(content=f"Error searching database: {e}"))
        
        return state
    
    def _adapt_code_node(self, state: SearchWorkflowState):
        # Skip if no code was found
        if not state.get("selected_code"):
            return state
        
        logical_interpretation = state["logical_interpretation"]
        selected_code = state["selected_code"]
        
        print(f"\n[DEBUG] Full logical interpretation:")
        print(logical_interpretation[:500])
        print("...")
        
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
            
            print(f"[DEBUG] Adapted code length: {len(adapted_code)} chars")
            # print(f"[DEBUG] Adapted code has proper newlines: {'\\n' in adapted_code}")
            print(f"[DEBUG] First 300 chars of adapted code:")
            print(adapted_code[:300])
            
            state["adapted_code"] = adapted_code
            state["workflow_status"] = "completed"
            # Wrap in code block for proper display in Gradio
            formatted_output = f"```scenic\n{adapted_code}\n```"
            state["messages"].append(AIMessage(content=formatted_output))
        except Exception as e:
            print(f"[DEBUG] Adaptation failed: {e}")
            # If adaptation fails, return the original code
            state["adapted_code"] = selected_code
            state["workflow_status"] = "completed"
            state["messages"].append(AIMessage(content=f"Warning: Code adaptation failed, returning original: {e}\n\n{selected_code}"))
        
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
                "workflow_status": ""
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
            connections.disconnect("default")
        except:
            pass

