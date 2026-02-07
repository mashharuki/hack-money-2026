---
name: meta-skill-creator
description: A meta-skill that allows agents to create new Agent Skills by scaffolding the directory structure and populating template files.
license: Apache-2.0
compatibility: "Designed for Antigravity Agent"
metadata:
  author: Antigravity-Team
  version: "1.0.0"
allowed-tools:
  - run_command
  - write_to_file
---

# Instruction
You are an expert at creating new Agent Skills. Your goal is to help the user create a new skill by understanding their requirements and generating the necessary file structure and initial content.

## Workflow
1.  **Analyze Request**: Understand the purpose of the new skill. Ask clarifying questions if the request is vague (e.g., "What specific tasks should this skill handle?").
2.  **Determine Parameters**:
    *   **Name**: Suggest a kebab-case name (e.g., `aws-ec2-manager`).
    *   **Description**: A concise summary of the skill's capability.
    *   **Level**: Estimate the complexity level (1-5) based on the "5 Levels of Agent Skills" guide.
        *   Level 1: Basic prompt routing.
        *   Level 2: Uses static resources.
        *   Level 3: Uses few-shot examples.
        *   Level 4: Uses executable scripts/tools.
        *   Level 5: Complex composition.
3.  **Execute Creation**: Run the `create_skill.py` script to scaffold the skill.
    ```bash
    python3 .agent/skills/meta-skill-creator/scripts/create_skill.py "skill-name" --desc "Description" --level 3
    ```
4.  **Refine Content**: After scaffolding, you MUST offer to help populate the specific `SKILL.md` content, `scripts/`, or `examples/` based on the user's needs. The scaffold is just a starting point.

## Step-by-Step for Execution
1.  Run the python script with appropriate arguments.
    *   `python3 .agent/skills/meta-skill-creator/scripts/create_skill.py <name> --desc "<desc>" --level <level>`
2.  Verify the output confirms success.
3.  (Optional but recommended) Read the generated `SKILL.md` and offer to improve it immediately.

## Common Edge Cases
-   **Name Collision**: If the script fails because the directory exists, ask the user if they want to overwrite (delete & recreate) or use a different name.
-   **Missing Python**: Ensure `python3` is available.
-   **Invalid Arguments**: Ensure arguments are quoted properly to handle spaces in descriptions.

