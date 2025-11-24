from core.agents.base import BaseAgent
from core.prompts import load_prompt
from typing import Dict, Any


class CodeGenerator(BaseAgent):
    
    def __init__(self):
        prompt = load_prompt("code_generator")
        super().__init__(prompt, use_rag=True)
    
    def process(self, query: str) -> str:

        response = self.invoke(context={
            "question": query
        })
        return self._extract_code_from_response(response)
    
    
# if __name__ == "__main__":
#     agent = CodeGenerator()
#     sample_query = "Create a Scenic scenario where a car follows a pedestrian crossing the street."
#     generated_code = agent.process(sample_query)
#     print("Generated Scenic Code:\n", generated_code)