from core.agents.base import BaseAgent
from core.prompts import load_prompt
from typing import Dict, Any
import re
class ErrorCorrector(BaseAgent):
    """Agent for correcting errors in generated code."""
    
    def __init__(self):
        prompt = load_prompt("error_corrector")
        super().__init__(prompt, use_rag=True)
    
    def process(self, dsl_code: str, error_message: str) -> str:
        """Generate corrected code based on error."""
        response = self.invoke(context={
            "dsl_code": dsl_code,
            "error_message": error_message
        })
        return self._extract_code_from_response(response)
    
    def _extract_code_from_response(self, response: str) -> str:
        """Extract code from markdown code blocks."""
        code_block_pattern = r"```(?:scenic|python)?\n(.*?)```"
        matches = re.findall(code_block_pattern, response, re.DOTALL)
        if matches:
            return matches[0].strip()
        return response.strip()
