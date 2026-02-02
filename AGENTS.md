# AI-DLC and Spec-Driven Development

Kiro-style Spec Driven Development implementation on AI-DLC (AI Development Life Cycle)

## Project Context

### Paths
- Steering: `.kiro/steering/`
- Specs: `.kiro/specs/`

### Steering vs Specification

**Steering** (`.kiro/steering/`) - Guide AI with project-wide rules and context
**Specs** (`.kiro/specs/`) - Formalize development process for individual features

### Active Specifications
- Check `.kiro/specs/` for active specifications
- Use `/kiro:spec-status [feature-name]` to check progress

## Development Guidelines
- Think in English, generate responses in Japanese. All Markdown content written to project files (e.g., requirements.md, design.md, tasks.md, research.md, validation reports) MUST be written in the target language configured for this specification (see spec.json.language).
- For complex processes, proceed step by step.
- Check if the project is activated.
- If not activated, activate it.
- If not onboarded, complete onboarding.

## Minimal Workflow
- Phase 0 (optional): `/kiro:steering`, `/kiro:steering-custom`
- Phase 1 (Specification):
  - `/kiro:spec-init "description"`
  - `/kiro:spec-requirements {feature}`
  - `/kiro:validate-gap {feature}` (optional: for existing codebase)
  - `/kiro:spec-design {feature} [-y]`
  - `/kiro:validate-design {feature}` (optional: design review)
  - `/kiro:spec-tasks {feature} [-y]`
- Phase 2 (Implementation): `/kiro:spec-impl {feature} [tasks]`
  - `/kiro:validate-impl {feature}` (optional: after implementation)
- Progress check: `/kiro:spec-status {feature}` (use anytime)

## Development Rules
- 3-phase approval workflow: Requirements → Design → Tasks → Implementation
- Human review required each phase; use `-y` only for intentional fast-track
- Keep steering current and verify alignment with `/kiro:spec-status`
- Follow the user's instructions precisely, and within that scope act autonomously: gather the necessary context and complete the requested work end-to-end in this run, asking questions only when essential information is missing or the instructions are critically ambiguous.

## Steering Configuration
- Load entire `.kiro/steering/` as project memory
- Default files: `product.md`, `tech.md`, `structure.md`
- Custom files are supported (managed via `/kiro:steering-custom`)

## Core Development Philosophy
- Focus not only on writing working code but also on quality, maintainability, and security
- Strike the right balance according to the project phase (prototype, MVP, production)
- When you find a problem, don't leave it unaddressed; either fix it or explicitly document it
- Boy Scout Rule: Leave the code better than you found it

## Error Handling Principles
- Always resolve errors, even if they seem unrelated
- Fix root causes instead of suppressing errors (@ts-ignore, silent try-catch, etc.)
- Detect errors early and provide clear error messages
- Cover error cases with tests
- Always consider the possibility of failure for external APIs and network communications

## Code Quality Standards
- DRY principle: Avoid duplication and maintain a single source of truth
- Use meaningful variable and function names to clearly convey intent
- Maintain consistent coding style throughout the project
- Don't leave small issues unaddressed; fix them as soon as you find them (Broken Windows Theory)
- Comments should explain "why"; let the code express "what"

## Testing Discipline
- Don't skip tests; fix them if there are issues
- Test behavior, not implementation details
- Avoid dependencies between tests; they should run in any order
- Tests should be fast and always return the same results
- Coverage is a metric; prioritize high-quality tests

## Maintainability and Refactoring
- Consider improving existing code when adding features
- Break large changes into small steps
- Actively delete unused code
- Regularly update dependencies (for security and compatibility)
- Explicitly document technical debt in comments or documentation

## Security Approach
- Manage API keys, passwords, etc. with environment variables (no hardcoding)
- Validate all external input
- Operate with minimum necessary privileges (principle of least privilege)
- Avoid unnecessary dependencies
- Run security audit tools regularly

## Performance Awareness
- Optimize based on measurement, not speculation
- Consider scalability from the early stages
- Delay loading resources until needed
- Clearly define cache expiration and invalidation strategies
- Avoid N+1 problems and over-fetching

## Reliability Assurance
- Set appropriate timeout handling
- Implement retry mechanisms (consider exponential backoff)
- Utilize circuit breaker patterns
- Build tolerance for temporary failures
- Ensure observability with appropriate logs and metrics

## Understanding Project Context
- Balance business requirements and technical requirements
- Determine the truly necessary quality level for the current phase
- Maintain minimum quality standards even under time constraints
- Choose implementations that match the team's technical level

## Recognizing Trade-offs
- It's impossible to perfect everything (there is no silver bullet)
- Find the optimal balance within constraints
- Prioritize simplicity for prototypes, robustness for production
- Clearly document compromise points and their reasons

## Git Operations Basics
- Use conventional commit format (feat:, fix:, docs:, test:, refactor:, chore:)
- Commits should be atomic, focusing on a single change
- Write clear and descriptive commit messages in English
- Avoid direct commits to main/master branches

## Code Review Attitude
- Accept review comments as constructive improvement suggestions
- Focus on code, not individuals
- Clearly explain the reasons for and impact of changes
- Welcome feedback as a learning opportunity

## Debugging Best Practices
- Establish steps to reliably reproduce the problem
- Narrow down the problem scope with binary search
- Start investigation from recent changes
- Utilize appropriate tools like debuggers and profilers
- Document findings and solutions to share knowledge

## Dependency Management
- Add only truly necessary dependencies
- Always commit lock files like package-lock.json
- Check license, size, and maintenance status before adding new dependencies
- Regularly update for security patches and bug fixes

## Documentation Standards
- Clearly describe project overview, setup, and usage in README
- Keep documentation synchronized with code updates
- Prioritize showing examples
- Record important design decisions in ADR (Architecture Decision Records)

## Continuous Improvement
- Apply lessons learned to the next project
- Regularly conduct retrospectives and improve processes
- Appropriately evaluate and adopt new tools and techniques
- Document knowledge for the team and future developers