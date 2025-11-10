from core.agents.base import BaseAgent
from core.prompts import load_prompt
from typing import Dict, Any
import re


class RoadGenerator(BaseAgent):
    def __init__(self):
        prompt = load_prompt("road_generator")
        super().__init__(prompt, use_rag=True)
    
    def process(self, interpretation: str, previous_assembled_code: str = "") -> str:
        context = {
            "interpretation": interpretation,
            "previous_assembled_code": previous_assembled_code or "No previous code"
        }
        response = self.invoke(context=context)
        return self._extract_code_from_response(response)
    
    def _extract_code_from_response(self, response: str) -> str:
        code_block_pattern = r"```(?:scenic|python)?\n(.*?)```"
        matches = re.findall(code_block_pattern, response, re.DOTALL)
        if matches:
            return matches[0].strip()
        return response.strip()

