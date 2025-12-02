from typing import Dict
from .base import BaseAgent
from core.prompts import load_prompt


class ComponentAssemblerAgent(BaseAgent):
    def __init__(self):
        prompt = load_prompt("component_assembler")
        super().__init__(
            prompt_template=prompt,
            model_name="gemini-2.5-flash",
            model_provider="google_genai",
            use_rag=False
        )
    
    def process(self, original_code: str, replacements: Dict[str, str]) -> str:
        return self.assemble_code(original_code, replacements)
    
    def assemble_code(
        self,
        original_code: str,
        replacements: Dict[str, Dict[str, str]]
    ) -> str:
        if not replacements:
            return original_code
        
        assembled_code = original_code
        
        for component_type, replacement_info in replacements.items():
            original_component_code = replacement_info.get("original_code", "")
            replacement_code = replacement_info.get("replacement_code", "")
            source_context = replacement_info.get("source_context", "")
            
            response = self.invoke(context={
                "original_code": assembled_code,
                "component_type": component_type,
                "original_component_code": original_component_code,
                "replacement_code": replacement_code,
                "source_context": source_context
            })
            
            assembled_code = self._extract_code_from_response(response.strip())
        
        return assembled_code

