from core.agents.base import BaseAgent
from core.prompts import load_prompt
from typing import Dict, Any
from utilities.parser import parse_scenic
    
class CodeValidator():
    
    def __init__(self):
        pass
    
    def process(self, code: str) -> Dict[str, Any]:
        try:
            parse_scenic(code)
            return {
                "valid": True,
                "error": None,
                "code": code
            }
        except Exception as e:
            return {
                "valid": False,
                "error": str(e),
                "code": code
            }
