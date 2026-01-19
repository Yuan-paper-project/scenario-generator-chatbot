import os
import re
from pathlib import Path

def add_rolename_to_scenic(file_path):
    """Adds 'with rolename "hero",' after the ego definition if not present."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return False

    new_lines = []
    modified = False

    ego_pattern = re.compile(r'^\s*ego\s*=\s*(?:new\s+)?Car')
    rolename_pattern = re.compile(r'rolename\s*["\']hero["\']')

    i = 0
    while i < len(lines):
        line = lines[i]
        new_lines.append(line)
        
        if ego_pattern.search(line):
            if rolename_pattern.search(line):
                i += 1
                continue
            
            # Check if following 'with' lines already have it
            already_has = False
            j = i + 1
            while j < len(lines):
                stripped = lines[j].strip()
                if not stripped or stripped.startswith('#'):
                    j += 1
                    continue
                if stripped.startswith('with'):
                    if rolename_pattern.search(lines[j]):
                        already_has = True
                        break
                    j += 1
                else:
                    break
            
            if not already_has:
                # Determine indentation: use the same indentation as the next line if it's a 'with'
                # or default to 4 spaces
                indent = "    "
                if i + 1 < len(lines):
                    with_match = re.match(r'^(\s*)with', lines[i+1])
                    if with_match:
                        indent = with_match.group(1)
                
                new_lines.append(f"{indent}with rolename 'hero',\n")
                modified = True
                print(f"  Added hero rolename to {file_path}")
        
        i += 1

    if modified:
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
            return True
        except Exception as e:
            print(f"Error writing to {file_path}: {e}")
            return False
    return False

def process_path(target_path):
    """Processes a file or recursively processes all .scenic files in a directory."""
    path = Path(target_path)
    if not path.exists():
        print(f"Error: Path '{target_path}' does not exist")
        return

    if path.is_file():
        if path.suffix == ".scenic":
            add_rolename_to_scenic(str(path))
        else:
            print(f"Skipping {target_path} (not a .scenic file)")
    else:
        count = 0
        for root, _, files in os.walk(target_path):
            for file in files:
                if file.endswith(".scenic"):
                    file_path = os.path.join(root, file)
                    if add_rolename_to_scenic(file_path):
                        count += 1
        print(f"\nFinished! Updated {count} files.")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Add rolename 'hero' to ego vehicle in Scenic files")
    parser.add_argument("path", help="Path to a .scenic file or a directory containing them")
    args = parser.parse_args()
    
    process_path(args.path)

