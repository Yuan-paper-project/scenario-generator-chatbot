
import os
import sys
from pathlib import Path
from core.agents.base import BaseAgent
from core.config import get_settings

# Load settings
settings = get_settings()


def create_restructure_prompt_template() -> str:
    """Create the prompt template for restructuring."""
    return """Restructure the following Scenic code by reorganizing it into clearly labeled sections.

CRITICAL RULES:

DO NOT modify any code logic, syntax, or descriptions.

DO NOT remove any code statements.

ONLY reorganize the code and update section headers.

Group related parameters/constants with the sections where they are used.

SECTION STRUCTURE (use EXACT format and order — titles must match these section headers exactly):
Description
Header (map parameters, model imports, shared constants like MODEL)
Ego Behavior
Adversarial Behavior
Spatial Relation
Ego object
Adversarial object
Requirements and Restrictions

Notes:

Preserve every line of the original Scenic file; do not add, delete, or change code or comments — only move lines between the specified sections and add or update section header comments.

When grouping parameters/constants, place each parameter near the behaviors or objects that use it (but do not change parameter values).

Keep any top-of-file metadata (e.g., imports, model declarations) within the Header section unless they clearly belong to one of the other specified sections.

If the original file already contains section-like comment blocks, you may replace those comment blocks with the exact headers above and move content under the correct headers.

Maintain the original ordering of code where possible within each new section to avoid changing behavior.

Input:

The Scenic source will be supplied in place of the placeholder {{scenic_content}}.

Example usage: the tool invoking this prompt should substitute the complete Scenic file text for {{scenic_content}} before sending it to the LLM.

Output requirements:

Return ONLY the restructured Scenic code. Do not include explanations, Markdown code fences, or any additional text. Output the raw Scenic file content only.

Use the exact section header titles and order listed above, each formatted as a visible comment block (e.g., ################################# style or similar), so they are clearly identifiable in the output.

Here is the Scenic code to restructure:
```scenic
{scenic_content}
```
Return ONLY the restructured Scenic code.

"""


class ScenicRestructureAgent(BaseAgent):
    
    def __init__(self):
        prompt_template = create_restructure_prompt_template()
        super().__init__(
            prompt_template=prompt_template,
            model_name="gemini-2.5-flash",
            model_provider="google_genai",
            use_rag=False
        )
    
    def process(self, scenic_content: str) -> str:
        response = self.invoke(context={"scenic_content": scenic_content})
        return self._extract_code_from_response(response)


def restructure_scenic_file(agent: ScenicRestructureAgent, scenic_content: str) -> str:
    print("Calling LLM to restructure file...")
    result = agent.process(scenic_content)
    return result.strip()


def process_file(agent: ScenicRestructureAgent, input_path: str, output_path: str = None, dry_run: bool = False, output_dir: str = None):
    print(f"\nProcessing: {input_path}")
    
    with open(input_path, 'r', encoding='utf-8') as f:
        original_content = f.read()
    
    restructured_content = restructure_scenic_file(agent, original_content)

    print(f"Processing content is : {original_content}")
    print(f"Restructured content is : {restructured_content}")
    if dry_run:
        print("\n" + "="*80)
        print("RESTRUCTURED OUTPUT:")
        print("="*80)
        print(restructured_content)
        print("="*80)
        return
    
    if output_path:
        output_file = output_path
    elif output_dir:
        input_file = Path(input_path)
        output_file = Path(output_dir) / input_file.name
    else:
        output_file = input_path
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(restructured_content)
    
    print(f"✓ Successfully saved to: {output_file}")


def process_directory(agent: ScenicRestructureAgent, directory_path: str, output_dir: str = "Scenic\examples\Scenic3.1-Edit", backup: bool = True):
    """Process all Scenic files in a directory."""
    path = Path(directory_path)
    scenic_files = sorted(path.glob("*.scenic"))
    
    if not scenic_files:
        print(f"No .scenic files found in {directory_path}")
        return
    
    print(f"Found {len(scenic_files)} files to process")
    
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)
    print(f"Output will be saved to: {output_path.absolute()}")
    
    if backup:
        backup_dir = path / "backup"
        backup_dir.mkdir(exist_ok=True)
        print(f"Backups will be saved to: {backup_dir}")
    
    for i, file_path in enumerate(scenic_files, 1):
        print(f"\n[{i}/{len(scenic_files)}]", end=" ")
        
        try:
            if backup:
                backup_path = backup_dir / file_path.name
                with open(file_path, 'r', encoding='utf-8') as f:
                    backup_content = f.read()
                with open(backup_path, 'w', encoding='utf-8') as f:
                    f.write(backup_content)
            
            process_file(agent, str(file_path), output_dir=str(output_path))
            
        except Exception as e:
            print(f"✗ Error processing {file_path.name}: {e}")
            continue
    
    print(f"\nProcessing complete! Processed {len(scenic_files)} files.")
    print(f"All restructured files saved to: {output_path.absolute()}")


def main():
    """Main function."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Restructure Scenic files using existing LLM setup")
    parser.add_argument("path", help="Path to a Scenic file or directory")
    parser.add_argument("-o", "--output", help="Output file (for single file only)")
    parser.add_argument("--output-dir", default="ScenicSource", help="Output directory for restructured files (default: ScenicSource)")
    parser.add_argument("-d", "--dry-run", action="store_true", help="Preview without writing")
    parser.add_argument("--no-backup", action="store_true", help="Don't create backups")
    
    args = parser.parse_args()
    
    path = Path(args.path)
    if not path.exists():
        print(f"Error: Path '{args.path}' does not exist")
        sys.exit(1)
    
    print("="*80)
    print("Scenic File Restructuring Tool")
    print("="*80)
    print("Initializing Scenic Restructure Agent...")
    
    try:
        agent = ScenicRestructureAgent()
        print("✓ Agent initialized successfully")
    except Exception as e:
        print(f"✗ Error initializing agent: {e}")
        print("\nMake sure your .env file is configured with:")
        print("  - GOOGLE_API_KEY=your-api-key-here")
        print("\nOr set the environment variable:")
        print("  export GOOGLE_API_KEY='your-api-key-here'")
        sys.exit(1)
    
    if path.is_file():
        if args.output:
            process_file(agent, str(path), output_path=args.output, dry_run=args.dry_run)
        else:
            output_path = Path(args.output_dir)
            output_path.mkdir(exist_ok=True)
            process_file(agent, str(path), dry_run=args.dry_run, output_dir=args.output_dir)
    elif path.is_dir():
        if args.dry_run:
            print("Error: --dry-run not supported for directory processing")
            sys.exit(1)
        if args.output:
            print("Warning: --output flag ignored for directory processing")
        

        print(f"\nFiles will be saved to: {Path(args.output_dir).absolute()}")
        
        response = input(f"This will restructure ALL .scenic files in '{args.path}'.\nContinue? [y/N]: ")
        if response.lower() != 'y':
            print("Cancelled.")
            return
        
        process_directory(agent, str(path), output_dir=args.output_dir, backup=not args.no_backup)
    else:
        print(f"Error: '{args.path}' is neither a file nor directory")
        sys.exit(1)


if __name__ == "__main__":
    main()

