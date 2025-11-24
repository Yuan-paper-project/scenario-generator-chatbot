from typing import Optional


class HeaderGenerator:
    HEADER = """
    param map = localPath('../../assets/maps/CARLA/Town05.xodr')
    param carla_map = 'Town05'
    model scenic.domains.driving.model
    MODEL = 'vehicle.mini.cooper_s_2021'
    """

    def __init__(self, header: Optional[str] = None):
        self.header = header if header is not None else self.HEADER
        self.last_formatted_prompt = None
        self.last_response = None
    
    def process(self, code: str) -> str:
        self.last_formatted_prompt = "Header Generator (hardcoded header, no prompt)"
        self.last_response = self.header
        
        if not code.strip():
            return self.header
        
        if self.header.strip() in code:
            return code
        
        return f"{self.header}\n\n{code}"
    
    def get_last_formatted_prompt(self) -> Optional[str]:
        return self.last_formatted_prompt
    
    def get_last_response(self) -> Optional[str]:
        return self.last_response

