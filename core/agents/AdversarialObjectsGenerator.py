from core.agents.base import BaseAgent
from core.prompts import load_prompt
from typing import Dict, Any


class AdversarialObjectsGenerator(BaseAgent):
    def __init__(self):
        prompt = load_prompt("adversarial_objects_generator")
        super().__init__(prompt, use_rag=True)
    
    def process(self, interpretation: str, previous_assembled_code: str = "") -> str:
        context = {
            "interpretation": interpretation,
            "previous_assembled_code": previous_assembled_code or "No previous code"
        }
        response = self.invoke(context=context)
        return self._extract_code_from_response(response)

