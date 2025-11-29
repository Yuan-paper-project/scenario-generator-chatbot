from langchain_core.messages import HumanMessage
from .base import BaseAgent
from core.prompts import load_prompt

class Code2LogicalAgent(BaseAgent):
    def __init__(self):
        prompt = load_prompt("code2logical")
        
        super().__init__(
            prompt_template=prompt,
            model_name="gemini-2.0-flash-exp",
            model_provider="google_genai",
            use_rag=False
        )
    
    def process(self, user_query: str) -> str:
        response = self.invoke(context={"scenic_code": user_query})
        return response.strip()
    
    def adapt(self, original_query: str, current_interpretation: str, user_feedback: str) -> str:
        prompt = f"""Original query: {original_query}

            Current interpretation:
            {current_interpretation}

            User feedback: {user_feedback}

            Update the interpretation based on the feedback. Output the same structured format:

            Scenario: <description>
            Ego Vehicle: <type>
            Adversarial Object: <type>
            Ego Behavior: <description>
            Adversarial Behavior: <description>
            Spatial Relation: <description>
            Requirement and restrictions: <description>"""
                
        response = self.llm.invoke([HumanMessage(content=prompt)])
        return response.content.strip()

