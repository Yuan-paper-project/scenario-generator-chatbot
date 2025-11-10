from core.agents.base import BaseAgent
from core.prompts import load_prompt
from typing import Dict, Any, Optional
from utilities.parser import parse_scenic
    
class CodeValidator():
    
    def __init__(self):
        self.last_formatted_prompt = None
        self.last_response = None
    
    def process(self, code: str) -> Dict[str, Any]:
        # Store for logging compatibility
        self.last_formatted_prompt = f"Code Validator (no prompt, direct validation):\n\nCode to validate:\n{code}"
        
        try:
            parse_scenic(code)
            result = {
                "valid": True,
                "error": None,
                "code": code
            }
            self.last_response = f"Validation Result:\nValid: True\nError: None"
            return result
        except Exception as e:
            error = str(e)
            result = {
                "valid": False,
                "error": error,
                "code": code
            }
            self.last_response = f"Validation Result:\nValid: False\nError: {error}"
            return result
    
    def get_last_formatted_prompt(self) -> Optional[str]:
        """Get the last formatted prompt used."""
        return self.last_formatted_prompt
    
    def get_last_response(self) -> Optional[str]:
        """Get the last response."""
        return self.last_response
