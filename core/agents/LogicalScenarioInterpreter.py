from core.agents.base import BaseAgent
from core.prompts import load_prompt
from typing import Dict, Any

class LogicalScenarioInterpreter(BaseAgent):
    def __init__(self):
        prompt = load_prompt("logical_scenario_interpreter")
        super().__init__(prompt, use_rag=False)
    
    def process(self, query: str) -> Dict[str, Any]:
        response = self.invoke(context={"query": query})
        return {
            "query": query,
            "logical_interpretation": response,
        }

