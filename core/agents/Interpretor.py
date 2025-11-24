from core.agents.base import BaseAgent
from core.prompts import load_prompt
from typing import Dict, Any

class InterpretorAgent(BaseAgent):
    def __init__(self):
        prompt = load_prompt("interperator")
        super().__init__(prompt,use_rag=False, model_name = "gemini-2.5-flash")
    
    def process(self, query: str) -> Dict[str, Any]:
        """Analyze the query and extract key information."""
        response = self.invoke(context={"query": query})
        # For now, return a simple dict - can be enhanced with structured parsing
        return {
            "query": query,
            "interpretation": response,
            # "task_type": self._extract_task_type(query)
        }
    
    # def _extract_task_type(self, query: str) -> str:
    #     """Extract the type of task from the query."""
    #     query_lower = query.lower()
    #     if "create" in query_lower or "generate" in query_lower:
    #         return "generation"
    #     elif "modify" in query_lower or "update" in query_lower or "change" in query_lower:
    #         return "modification"
    #     elif "validate" in query_lower or "check" in query_lower:
    #         return "validation"
    #     else:
    #         return "general"

