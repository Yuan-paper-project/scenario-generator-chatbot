from core.agents.base import BaseAgent
from core.prompts import load_prompt
from typing import Dict, Any


class ErrorCorrector(BaseAgent):
    
    def __init__(self):
        prompt = load_prompt("error_corrector")
        super().__init__(prompt, model_name = "gemini-2.5-flash", model_provider="google_genai")
    
    def process(self, dsl_code: str, error_message: str) -> str:
        response = self.invoke(context={
            "dsl_code": dsl_code,
            "error_message": error_message
        })
        return self._extract_code_from_response(response)
