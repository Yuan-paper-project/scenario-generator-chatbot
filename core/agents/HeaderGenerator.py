from typing import Optional


class HeaderGenerator:
    HEADER = """param map = localPath('../../assets/maps/CARLA/Town01.xodr')

model scenic.domains.driving.model"""

    def __init__(self, header: Optional[str] = None):
        self.header = header if header is not None else self.HEADER
    
    def process(self, code: str) -> str:
        if not code.strip():
            return self.header
        
        # Check if header already exists
        if self.header.strip() in code:
            return code
        
        # Prepend header with double newline separator
        return f"{self.header}\n\n{code}"

