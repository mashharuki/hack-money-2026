import argparse
import os
import re
import sys

def to_kebab_case(s):
    return re.sub(r'([a-z0-9])([A-Z])', r'\1-\2', s).lower().replace(' ', '-').replace('_', '-')

def main():
    parser = argparse.ArgumentParser(description="Scaffold a new Agent Skill.")
    parser.add_argument("name", help="Name of the skill (kebab-case preferred, will be converted)")
    parser.add_argument("--desc", help="Description of the skill", default="No description provided.")
    parser.add_argument("--instr", help="Main instruction for the skill", default="Your main instruction here.")
    parser.add_argument("--level", type=int, choices=[1, 2, 3, 4, 5], default=1, help="Complexity level (1-5)")
    args = parser.parse_args()

    skill_name = to_kebab_case(args.name)
    cwd = os.getcwd()
    skill_dir = os.path.join(cwd, ".agent", "skills", skill_name)

    print(f"Creating skill '{skill_name}' at {skill_dir}")

    if os.path.exists(skill_dir):
        print(f"Error: Skill directory '{skill_dir}' already exists.")
        sys.exit(1)

    # Create directories
    os.makedirs(skill_dir)
    os.makedirs(os.path.join(skill_dir, "scripts"))
    os.makedirs(os.path.join(skill_dir, "resources"))
    if args.level >= 3:
        os.makedirs(os.path.join(skill_dir, "examples"))

    # Load template
    template_path = os.path.join(cwd, ".agent", "skills", "meta-skill-creator", "resources", "template_SKILL.md")
    
    template_content = ""
    if os.path.exists(template_path):
        with open(template_path, "r") as f:
            template_content = f.read()
    else:
        # Fallback template
        print("Warning: Template file not found. Using fallback template.")
        template_content = """---
name: {{skill_name}}
description: {{description}}
license: Apache-2.0
compatibility: "Designed for Claude Code or similar"
metadata:
  author: Agent-Scaffolder
  version: "0.1.0"
allowed-tools:
  - Bash
  - Read
---

# Instruction
{{instruction}}

## Step-by-Step
1. Understand the user goal.
2. Execute the skill logic.
"""

    # Replace placeholders
    filled_content = template_content.replace("{{skill_name}}", skill_name)\
                                     .replace("{{description}}", args.desc)\
                                     .replace("{{instruction}}", args.instr)\
                                     .replace("{{example_input}}", "Provide your input example here.")\
                                     .replace("{{example_output}}", "Provide your output example here.")

    # Write SKILL.md
    skill_md_path = os.path.join(skill_dir, "SKILL.md")
    with open(skill_md_path, "w") as f:
        f.write(filled_content)

    print(f"Successfully created skill '{skill_name}'.")
    print(f"Path: {skill_md_path}")
    print("Don't forget to fill in the instructions and logic.")

if __name__ == "__main__":
    main()
