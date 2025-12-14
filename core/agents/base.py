from abc import ABC, abstractmethod
from langchain_core.messages import HumanMessage, AIMessage
from langchain_core.prompts import ChatPromptTemplate
from langchain.chat_models import init_chat_model
from typing import Any, Dict
from typing import Optional
import re

from core.config import get_settings
from core.prompts import load_prompt
from core.milvus_client import MilvusClient

settings = get_settings()


class BaseAgent(ABC):
    
    def __init__(self, prompt_template: str, model_name: str = None, model_provider: str = None, use_rag: bool = False, think_mode: bool = False):
        self.prompt_template = ChatPromptTemplate.from_template(prompt_template)
        self.model_name = model_name or settings.LLM_MODEL_NAME
        self.model_provider = model_provider or settings.LLM_PROVIDER
        
        if self.model_provider == "ollama":
            self.llm = init_chat_model(
                self.model_name, 
                model_provider=self.model_provider, 
                base_url=settings.OLLAMA_URL
            )
        else:
            self.llm = init_chat_model(self.model_name, model_provider=self.model_provider, include_thoughts=think_mode)
    
        self.vector_store = MilvusClient() if use_rag else None
        self.last_formatted_prompt: Optional[str] = None  # Store last formatted prompt for logging
        self.last_response: Optional[str] = None  # Store last response for logging

    @abstractmethod
    def process(self, **kwargs) -> Any:
        pass
    
    def invoke(self, context: Dict = None) -> str:
        formatted_prompt = self.prompt_template.format(**context) 

        retrieved_context = self.retrieve_context(formatted_prompt)

        if retrieved_context:
            formatted_prompt += f"\n\nRelevant Context:\n{retrieved_context}"
        
        self.last_formatted_prompt = formatted_prompt
        
        response = self.llm.invoke([HumanMessage(content=formatted_prompt)])
        response_content = response.content
        
        # Handle Gemini thinking mode response (list with thinking + response parts)
        if isinstance(response_content, list):
            # Extract only the text content from each part
            text_parts = []
            for part in response_content:
                if hasattr(part, 'text'):
                    text_parts.append(part.text)
                elif isinstance(part, str):
                    text_parts.append(part)
                elif hasattr(part, 'content'):
                    text_parts.append(part.content)
            response_content = " ".join(text_parts)
        
        self.last_response = response_content
        
        return response_content
    
    def get_last_formatted_prompt(self) -> Optional[str]:
        return self.last_formatted_prompt
    
    def get_last_response(self) -> Optional[str]:
        return self.last_response

    def retrieve_context(self, query: str) -> Optional[str]:
        if not self.vector_store:
            return None
        results = self.vector_store.search(query)
        return "\n".join([doc.page_content for doc in results]) if results else None

    def _extract_code_from_response(self, response: str) -> str:
        code_block_pattern = r"```(?:scenic|python)?\n(.*?)```"
        matches = re.findall(code_block_pattern, response, re.DOTALL)
        if matches:
            return matches[0].strip()
        return response.strip()


