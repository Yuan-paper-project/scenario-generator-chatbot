from langchain_core.messages import HumanMessage
from .base import BaseAgent
from core.prompts import load_prompt

class Code2LogicalAgent(BaseAgent):
    def __init__(self):
        prompt = load_prompt("code2logical")
        
        super().__init__(
            prompt_template=prompt,
            model_name="gemini-2.5-flash",
            model_provider="google_genai",
            use_rag=False
        )
    
    def process(self, user_query: str) -> str:
        response = self.invoke(context={"scenic_code": user_query})
        return response.strip()
    
    def adapt(self, original_query: str, current_interpretation: str, user_feedback: str) -> str:
        prompt = f"""Your task is to update the high-level logical structure of the scenario based on user feedback.

        Original query: {original_query}

        Current interpretation:
        {current_interpretation}

        User feedback: {user_feedback}

        Update the interpretation based on the user feedback. Output ONLY a valid JSON object with the following structure (NO markdown code blocks, NO additional text):

        {{
        "Scenario": "<one concise sentence describing the whole scenario>",
        "Ego Vehicle": "<vehicle type restricted to car, pedestrian>",
        "Adversarial Object": "<type of dynamic/obstacle entity interacting with ego, restricted to pedestrian, car, trash, debris, vending machine, bicycle, truck, etc.>",
        "Ego Behavior": "<Describe the behavior of the Ego in terms of high-level actions and direction (e.g., traveling forward, decelerates, crosses, stops, turns)>",
        "Adversarial Behavior": "<Describe the behavior of the adversarial object in terms of high-level actions and direction (e.g., traveling forward, decelerates, crosses, stops, turns)>",
        "Spatial Relation": "<Describe the spatial relation of the spatial component, the spawn position and the road type (straight road, highway, intersection)>",
        "Requirement and restrictions": "<Describe the requirement and restrictions of the scenario, for example, how the scenario should be terminated, what is the initial distance between the ego and the adversarial object, etc.>"
        }}

        Apply the user feedback to update the relevant fields. Output ONLY the JSON object:"""
                
        response = self.llm.invoke([HumanMessage(content=prompt)])
        return response.content.strip()

