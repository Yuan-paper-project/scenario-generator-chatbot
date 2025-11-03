from typing import Optional


class HeaderGenerator:
    """Agent for adding hardcoded header to Scenic code."""
    
    # Hardcoded Scenic initialization header
    HEADER = """param map = localPath('../../assets/maps/CARLA/Town01.xodr')

                model scenic.domains.driving.model"""

    def __init__(self, header: Optional[str] = None):
        """
        Initialize HeaderGenerator.
        
        Args:
            header: Optional custom header. If None, uses default header.
        """
        self.header = header if header is not None else self.HEADER
    
    def process(self, code: str) -> str:
        """
        Add header to the generated code.
        
        Args:
            code: Generated Scenic code without header
            
        Returns:
            Code with header prepended
        """
        if not code.strip():
            return self.header
        
        # Check if header already exists
        if self.header.strip() in code:
            return code
        
        # Prepend header with double newline separator
        return f"{self.header}\n\n{code}"

