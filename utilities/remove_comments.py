"""
Script to remove standalone comment lines from Scenic files,
keeping section comments and inline comments.
"""
from pathlib import Path

def is_section_comment(line):
    stripped = line.strip()
    return stripped.startswith('#####')

def is_standalone_comment(line):
    stripped = line.strip()
    if not stripped or not stripped.startswith('#'):
        return False
    
    if is_section_comment(line):
        return False
    
    return True

def has_inline_comment(line):
    stripped = line.strip()
    if not stripped or stripped.startswith('#'):
        return False
    return '#' in stripped

def remove_standalone_comments(content):
    lines = content.split('\n')
    filtered_lines = []
    in_section_header = False
    
    for i, line in enumerate(lines):
        # Keep empty lines
        if not line.strip():
            filtered_lines.append(line)
            continue
        
        if is_section_comment(line):
            filtered_lines.append(line)
            in_section_header = not in_section_header  # Toggle section header mode
            continue
        
        if in_section_header:
            filtered_lines.append(line)
            continue
        
        if not is_standalone_comment(line):
            filtered_lines.append(line)
            continue
    return '\n'.join(filtered_lines)

def process_file(filepath):
    print(f"Processing {filepath}...")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    new_content = remove_standalone_comments(content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print(f"  ✓ Completed {filepath}")

def main():
    folder = Path(r'c:\Workspace\scenario-generation-chatbot\Scenic\examples\chatscene_labeled')
    
    # Process all .scenic files in the folder
    scenic_files = list(folder.glob('*.scenic'))
    
    print(f"Found {len(scenic_files)} .scenic files")
    print("="*60)
    
    for filepath in sorted(scenic_files):
        process_file(filepath)
    
    print("="*60)
    print(f"✓ All {len(scenic_files)} files processed successfully!")

if __name__ == '__main__':
    main()
