from core.agents.base import BaseAgent
from core.prompts import load_prompt
from typing import Dict, Any


class CodeAssembler(BaseAgent):
    
    def __init__(self):
        prompt = load_prompt("code_assembler")
        super().__init__(prompt, use_rag=False, model_name = "gemini-2.5-flash")
    
    def process(self, 
                previous_assembled_code: str = "",
                new_component: str = "",
                component_type: str = "") -> str:
        if not previous_assembled_code and not new_component:
            return ""
        
        if not previous_assembled_code.strip():
            return new_component.strip()
        
        if not new_component.strip():
            return previous_assembled_code.strip()
        
        response = self.invoke(context={
            "previous_assembled_code": previous_assembled_code,
            "new_component": new_component,
            "component_type": component_type
        })
        
        assembled_code = self._extract_code_from_response(response)
        
        return assembled_code
