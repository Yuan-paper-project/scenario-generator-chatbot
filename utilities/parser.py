from scenic.syntax.parser import parse_string

def parse_scenic(scenic_code: str):

    """Parse Scenic code from a string and return the parse tree."""
    return parse_string(scenic_code,'exec')
