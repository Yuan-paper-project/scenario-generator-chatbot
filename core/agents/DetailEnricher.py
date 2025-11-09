from core.agents.base import BaseAgent
from core.prompts import load_prompt
from typing import Dict, Any

class DetailEnricher(BaseAgent):
    def __init__(self):
        prompt = load_prompt("detail_enricher")
        super().__init__(prompt, use_rag=False)
    
    def process(self, logical_interpretation: str) -> Dict[str, Any]:
        response = self.invoke(context={"logical_interpretation": logical_interpretation})
        return {
            "logical_interpretation": logical_interpretation,
            "detailed_interpretation": response,
        }

