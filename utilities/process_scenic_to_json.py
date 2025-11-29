"""
Agent to process Scenic code files and extract structured logical information into JSON format.
Uses the code2logical.txt prompt template to extract:
- Scenario description
- Ego vehicle information
- Adversarial object information
- Ego behavior
- Adversarial behavior
- Spatial relations
- Requirements and restrictions
"""

import os
import json
import sys
from pathlib import Path
from typing import Dict, Any
from datetime import datetime
from core.agents.base import BaseAgent
from core.config import get_settings

# Load settings
settings = get_settings()


class ScenicToLogicalAgent(BaseAgent):
    
    def __init__(self):
        with open("core/prompts/code2logical.txt", 'r', encoding='utf-8') as f:
            prompt_template = f.read()
        
        super().__init__(
            prompt_template=prompt_template,
            model_name="gemini-2.5-flash",
            model_provider="google_genai",
            use_rag=False
        )
    
    def process(self, scenic_content: str) -> str:
        response = self.invoke(context={"scenic_code": scenic_content})
        return response.strip()


def parse_logical_structure(llm_response: str, scenic_code: str) -> Dict[str, Any]:

    result = {
        "Scenario": {
            "description": "",
            "code": scenic_code
        },
        "Ego Vehicle": {
            "description": "",
            "code": ""
        },
        "Adversarial Object": {
            "description": "",
            "code": ""
        },
        "Ego Behavior": {
            "description": "",
            "code": ""
        },
        "Adversarial Behavior": {
            "description": "",
            "code": ""
        },
        "Spatial Relation": {
            "description": "",
            "code": ""
        },
        "Requirement and restrictions": {
            "description": "",
            "code": ""
        }
    }
    
    lines = llm_response.strip().split('\n')
    current_section = None
    current_content = []
    
    for line in lines:
        line_stripped = line.strip()
        
        if line_stripped.startswith("Scenario:"):
            if current_section and current_content:
                result[current_section]["description"] = ' '.join(current_content).strip()
            current_section = "Scenario"
            current_content = [line_stripped.replace("Scenario:", "").strip()]
        elif line_stripped.startswith("Ego Vehicle:"):
            if current_section and current_content:
                result[current_section]["description"] = ' '.join(current_content).strip()
            current_section = "Ego Vehicle"
            current_content = [line_stripped.replace("Ego Vehicle:", "").strip()]
        elif line_stripped.startswith("Adversarial Object:"):
            if current_section and current_content:
                result[current_section]["description"] = ' '.join(current_content).strip()
            current_section = "Adversarial Object"
            current_content = [line_stripped.replace("Adversarial Object:", "").strip()]
        elif line_stripped.startswith("Ego Behavior:"):
            if current_section and current_content:
                result[current_section]["description"] = ' '.join(current_content).strip()
            current_section = "Ego Behavior"
            current_content = [line_stripped.replace("Ego Behavior:", "").strip()]
        elif line_stripped.startswith("Adversarial Behavior:"):
            if current_section and current_content:
                result[current_section]["description"] = ' '.join(current_content).strip()
            current_section = "Adversarial Behavior"
            current_content = [line_stripped.replace("Adversarial Behavior:", "").strip()]
        elif line_stripped.startswith("Spatial Relation:"):
            if current_section and current_content:
                result[current_section]["description"] = ' '.join(current_content).strip()
            current_section = "Spatial Relation"
            current_content = [line_stripped.replace("Spatial Relation:", "").strip()]
        elif line_stripped.startswith("Requirement and restrictions:") or line_stripped.startswith("Requirements and restrictions:"):
            if current_section and current_content:
                result[current_section]["description"] = ' '.join(current_content).strip()
            current_section = "Requirement and restrictions"
            content = line_stripped.replace("Requirement and restrictions:", "").replace("Requirements and restrictions:", "").strip()
            current_content = [content] if content else []
        elif line_stripped and current_section:
            current_content.append(line_stripped)
    
    if current_section and current_content:
        result[current_section]["description"] = ' '.join(current_content).strip()
    
    code_lines = scenic_code.split('\n')
    
    ego_code = extract_section_code(code_lines, "Ego object")
    result["Ego Vehicle"]["code"] = ego_code
    
    adv_code = extract_section_code(code_lines, "Adversarial object")
    result["Adversarial Object"]["code"] = adv_code
    
    ego_behavior_code = extract_section_code(code_lines, "Ego Behavior")
    result["Ego Behavior"]["code"] = ego_behavior_code
    
    adv_behavior_code = extract_section_code(code_lines, "Adversarial Behavior")
    result["Adversarial Behavior"]["code"] = adv_behavior_code
    
    spatial_code = extract_section_code(code_lines, "Spatial Relation")
    result["Spatial Relation"]["code"] = spatial_code
    
    req_code = extract_section_code(code_lines, "Requirements and Restrictions")
    result["Requirement and restrictions"]["code"] = req_code
    
    return result


def extract_section_code(code_lines: list, section_header: str) -> str:
    in_section = False
    section_code = []
    found_section = False
    skip_header_box = False
    
    for i, line in enumerate(code_lines):
        if section_header in line and not in_section:
            in_section = True
            found_section = True
            skip_header_box = True
            continue
        
        if in_section:
            if skip_header_box and line.strip().startswith("#####") and line.strip().endswith("#####"):
                skip_header_box = False
                continue
                
            stripped = line.strip()
            if stripped.startswith("#") and not stripped == "#" and len(stripped) > 10:
                inner_text = stripped.replace("#", "").strip()
                if inner_text:
                    break
            
            if not section_code and not line.strip():
                continue
                
            section_code.append(line)
    
    if not found_section:
        return ""
    
    while section_code:
        last_line = section_code[-1].strip()
        if not last_line or (last_line.startswith("#####") and last_line.endswith("#####")):
            section_code.pop()
        else:
            break
    
    code = '\n'.join(section_code).strip()
    return code


def process_scenic_file(agent: ScenicToLogicalAgent, input_path: str, output_dir: str = "results/logical_structures"):
    print(f"Processing: {input_path}")
    
    with open(input_path, 'r', encoding='utf-8') as f:
        scenic_content = f.read()
    
    llm_response = agent.process(scenic_content)
    
    structured_data = parse_logical_structure(llm_response, scenic_content)
    
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    input_file = Path(input_path)
    output_filename = input_file.stem + ".json"
    output_file = output_path / output_filename
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(structured_data, f, indent=2, ensure_ascii=False)
    
    return output_file


def process_directory(agent: ScenicToLogicalAgent, directory_path: str, output_dir: str = "data/json"):
    path = Path(directory_path)
    scenic_files = sorted(path.glob("*.scenic"))
    
    if not scenic_files:
        return
    
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    successful = 0
    failed = 0
    
    for i, file_path in enumerate(scenic_files, 1):
        try:
            process_scenic_file(agent, str(file_path), output_dir=str(output_path))
            successful += 1
        except Exception as e:
            failed += 1
            continue


def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Extract logical structure from Scenic files and save as JSON"
    )
    parser.add_argument(
        "path", 
        help="Path to a Scenic file or directory"
    )
    parser.add_argument(
        "-o", "--output-dir", 
        default="data/json",
        help="Output directory for JSON files (default: results/logical_structures)"
    )
    
    args = parser.parse_args()
    
    # Check path exists
    path = Path(args.path)
    if not path.exists():
        sys.exit(1)
    
    try:
        agent = ScenicToLogicalAgent()
    except Exception as e:
        sys.exit(1)
    
    # Process file or directory
    if path.is_file():
        process_scenic_file(agent, str(path), output_dir=args.output_dir)
    elif path.is_dir():
        process_directory(agent, str(path), output_dir=args.output_dir)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()

