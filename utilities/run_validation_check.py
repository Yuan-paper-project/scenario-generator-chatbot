import os
import logging
from core.agents.CodeValidator import CodeValidator

# Configure logging to show info
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Paths provided
invalid_code_path = r"C:\Workspace\scenario-generation-chatbot\Scenic\examples\test\54.scenic"
valid_code_path = r"C:\Workspace\scenario-generation-chatbot\Scenic\examples\test\56.scenic"

def read_file(path):
    with open(path, 'r') as f:
        return f.read()

def main():
    validator = CodeValidator()
    # print("\n" + "="*50)
    # print(f"Testing INVALID code path: {invalid_code_path}")
    # print("="*50)
    # if os.path.exists(invalid_code_path):
    #     invalid_code = read_file(invalid_code_path)
    #     print("Code content loaded.")
    #     result = validator.process(invalid_code)
    #     print("\n--- Validation Result ---")
    #     print(f"Valid: {result['valid']}")
    #     print(f"Error: {result['error']}")
    #     # print(f"Processed Code:\n{result['code']}") 
    # else:
    #     print(f"File not found: {invalid_code_path}")

    print("\n" + "="*50)
    print(f"Testing VALID code path: {valid_code_path}")
    print("="*50)
    if os.path.exists(valid_code_path):
        valid_code = read_file(valid_code_path)
        print("Code content loaded.")
        result = validator.process(valid_code)
        print("\n--- Validation Result ---")
        print(f"Valid: {result['valid']}")
        print(f"Error: {result['error']}")
        # print(f"Processed Code:\n{result['code']}")
    else:
        print(f"File not found: {valid_code_path}")

if __name__ == "__main__":
    main()
