---
name: {{skill_name}}
description: {{description}}
license: Apache-2.0
compatibility: "Designed for Claude Code or similar"
metadata:
  author: AI-Assistant
  version: "0.1.0"
allowed-tools:
  - Bash
  - Read
---

# Instruction
{{instruction}}

## Step-by-Step
1. Validate the user request.
2. ...

## Examples
### Input
{{example_input}}

### Output
{{example_output}}

## Common Edge Cases
- Ensure directory exists before writing files.
- Handle user input when no arguments are provided.
