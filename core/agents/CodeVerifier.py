from core.agents.base import BaseAgent
from core.prompts import load_prompt
from typing import Dict, Any
import re


class CodeVerifier(BaseAgent):
    def __init__(self):
        prompt = load_prompt("code_verifier")
        super().__init__(prompt, use_rag=True) 
    
    def process(self, 
                interpretation: str,
                new_code: str,
                previous_code: str = "",
                component_type: str = "") -> Dict[str, Any]:
   
        response = self.invoke(context={
            "interpretation": interpretation,
            "new_code": new_code,
            "previous_code": previous_code or "No previous code",
            "component_type": component_type
        })
        
        status = self._extract_status(response)
        suggestions = self._extract_suggestions(response)
        
        return {
            "satisfied": status == "SATISFIED",
            "status": status,
            "response": response,
            "suggestions": suggestions,
            "component_type": component_type
        }
    
    def _extract_status(self, response: str) -> str:
        status_pattern = r'\*\*Status\*\*:\s*(SATISFIED|NOT_SATISFIED)'
        match = re.search(status_pattern, response, re.IGNORECASE)
        if match:
            return match.group(1).upper()
        if "NOT_SATISFIED" in response.upper() or "NOT SATISFIED" in response.upper():
            return "NOT_SATISFIED"
        return "SATISFIED"
    
    def _extract_suggestions(self, response: str) -> str:
        suggestions_pattern = r'[Ss]uggestions:\s*(.*?)$'
        match = re.search(suggestions_pattern, response, re.DOTALL | re.IGNORECASE)
        
        if match:
            return match.group(1).strip()
        
        return ""

