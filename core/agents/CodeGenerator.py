from core.agents.base import BaseAgent
from core.prompts import load_prompt
from typing import Dict, Any
import re

class CodeGenerator(BaseAgent):
    
    def __init__(self):
        prompt = load_prompt("code_generator")
        super().__init__(prompt, use_rag=True)
    
    def process(self, query: str) -> str:

        response = self.invoke(context={
            "question": query
        })
        return self._extract_code_from_response(response)
    
    def _extract_code_from_response(self, response: str) -> str:
        """Extract code from markdown code blocks."""
        code_block_pattern = r"```(?:scenic|python)?\n(.*?)```"
        matches = re.findall(code_block_pattern, response, re.DOTALL)
        if matches:
            return matches[0].strip()
        return response.strip()
    
    
# if __name__ == "__main__":
#     agent = CodeGenerator()
#     sample_query = "Create a Scenic scenario where a car follows a pedestrian crossing the street."
#     generated_code = agent.process(sample_query)
#     print("Generated Scenic Code:\n", generated_code)