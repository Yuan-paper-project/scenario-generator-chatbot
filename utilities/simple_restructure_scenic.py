
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
1. DO NOT modify any code logic, syntax, or variable/function names.
2. DO NOT remove any code statements.
3. ONLY reorganize the code and add section headers.
4. Each adversarial object MUST have its OWN separate "Adversarial" section.
5. Each section MUST include ALL parameters/constants it uses (duplicates are OK and expected).

REQUIRED SECTION ORDER:

#################################
# Description                   #
#################################

#################################
# Header                        #
#################################

#################################
# Ego                           #
#################################

#################################
# Adversarial                   #
#################################
[Create SEPARATE section for EACH adversarial object]

#################################
# Spatial Relation              #
#################################

#################################
# Requirements and Restrictions #
#################################

PARAMETER PLACEMENT RULE (CRITICAL):
- ONLY include parameters/constants in sections where they are ACTUALLY USED
- Each parameter should appear in the section where it is referenced in the code
- If a parameter is used in multiple sections, include it in EACH section that uses it
- DO NOT include parameters that are not referenced in that section's code
- Examples:
  * If OPT_EGO_SPEED is only used in "ego = new Car with speed OPT_EGO_SPEED", it goes ONLY in Ego section
  * If OPT_LC_DIST is used in both adversarial behavior AND require statement, include it in BOTH sections
  * If OPT_GEO_Y_DIST is only used in spawn point calculation, it goes ONLY in Spatial Relation section
- Special rules (these stay ONLY in their designated sections):
  * EGO_MODEL, MODEL - only in Header section
  * Spawn points (egoSpawnPt, AdvSpawnPt, IntSpawnPt, etc.) - only in Spatial Relation
  * Lane/trajectory variables (egoLaneSec, advTrajectory, etc.) - only in Spatial Relation
  * Map/Town variables - only in Header section

SECTION CONTENT:

Description: 
- Convert triple-quoted descriptions to: description = "text"

Header: 
- param map = localPath(...)
- param carla_map = ... (or Town variable)
- model scenic.simulators.carla.model
- MODEL or EGO_MODEL constants

Ego:
- ONLY param/constants that are ACTUALLY USED in ego behavior or ego object definition
- Typically includes: OPT_EGO_SPEED, OPT_EGO_INIT_SPEED, OPT_EGO_THROTTLE, etc.
- Ego behavior definitions (behavior EgoBehavior(), etc.)
- ego object creation (ego = new Car ...)
- DO NOT include EGO_MODEL here (it stays in Header section only)
- DO NOT include parameters used only in other sections

Adversarial (CREATE MULTIPLE SECTIONS - ONE PER OBJECT):
- For EACH adversarial object, create a SEPARATE "Adversarial" section
- Each section includes ONLY:
  * Parameters/constants ACTUALLY USED in that specific adversarial's behavior or object definition
  * Typically: OPT_ADV_SPEED, OPT_LEADING_SPEED, OPT_BLOCKER_THROTTLE, PED_MIN_SPEED, etc.
  * Behavior definition for that adversarial (if any)
  * Object creation (AdvAgent = new Motorcycle ..., Blocker = new Car ..., LeadingAgent = ..., etc.)
- Add a comment to identify the object (e.g., # Blocker, # AdvAgent, # LeadingAgent)
- DO NOT include parameters used only in Spatial Relation or Requirements sections

Spatial Relation:
- ONLY param/constants ACTUALLY USED in this section's code
- Typically includes: OPT_GEO_ parameters, distance parameters for spawn calculations
- Lane/intersection selection code (for loops, filters, Uniform selections)
- Spawn point definitions (egoSpawnPt, IntSpawnPt, AdvSpawnPt, etc.)
- Trajectory definitions (egoTrajectory, advTrajectory, etc.)
- Lane section variables (egoLaneSec, adjLaneSec, etc.)
- DO NOT include parameters only used in behavior definitions or require statements

Requirements and Restrictions:
- ONLY param/constants ACTUALLY USED in require/terminate statements
- Typically includes: OPT_BRAKE_DIST, INIT_DIST, TERM_DIST, etc.
- ALL require statements
- ALL terminate statements
- DO NOT include parameters not referenced in this section

EXAMPLES OF CORRECT DUPLICATION:
- param OPT_EGO_SPEED appears in Ego section (used in behavior) AND Spatial Relation (if used in calculations)
- param OPT_LC_DIST appears in Ego section (used in behavior) AND Adversarial section (if used there too)
- OPT_MOTO_START_DIST appears in Adversarial section (defines moto behavior) AND Spatial Relation (used for spawn calc)

OUTPUT FORMAT:
- Return ONLY the restructured Scenic code
- NO explanations, NO markdown code fences, NO extra text
- Use exact section header format with #################################
- Keep ALL original code logic unchanged

Here is the Scenic code to restructure:
```scenic
{scenic_content}
```

Return ONLY the restructured code:
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
    
    print(f"[SUCCESS] Successfully saved to: {output_file}")


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
            print(f"[ERROR] Error processing {file_path.name}: {e}")
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
        print("[SUCCESS] Agent initialized successfully")
    except Exception as e:
        print(f"[ERROR] Error initializing agent: {e}")
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

