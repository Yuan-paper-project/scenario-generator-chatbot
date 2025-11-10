from core.agents.base import BaseAgent
from core.prompts import load_prompt
import re


class CodeRefiner(BaseAgent):
    def __init__(self):
        prompt = load_prompt("code_refiner")
        super().__init__(prompt, use_rag=True)
    
    def process(self, 
                original_code: str,
                suggestions: str,
                interpretation: str = "",
                previous_code: str = "",
                component_type: str = "") -> str:
        context = {
            "original_code": original_code,
            "suggestions": suggestions,
            "interpretation": interpretation or "No interpretation provided",
            "previous_code": previous_code or "No previous code",
            "component_type": component_type or "unknown"
        }
        
        response = self.invoke(context=context)
        return self._extract_code_from_response(response)
    
    def _extract_code_from_response(self, response: str) -> str:
        code_block_pattern = r"```(?:scenic|python)?\n(.*?)```"
        matches = re.findall(code_block_pattern, response, re.DOTALL)
        if matches:
            return matches[0].strip()
        return response.strip()

