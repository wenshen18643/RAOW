1. System Architecture & Boundaries
- **Orchestrator Agent**: Claude Code
- **Sub-Agent / Worker**: Antigravity CLI can be called using agy plugin.
- **Task Protocol**: Claude plans and reviews; `agy` executes high-throughput bulk code writing, heavy repository lookups, and test generation.

2. Delegation Hand-off Criteria
Route tasks programmatically based on token weight and operation types:
- **Delegate to `agy` immediately for:**
  - Writing code
  - Deep repository archaeology.
  - External documentation, API references, or active web searches.
  - Always use gemini 3.1 pro high fallback to gemini 3.5 flash high
  - always use gemini 3.5 flash for research
- **Retain in Claude for:**
  - Planning and reviewing
  - Ensuring work is production quality
  - small simple fixes in a singular file

3. Context & Execution Rules
- **Memory Footprint Limit**: `agy` must return file paths to claude to keep parent context window clean
- **Continuous States**: Use persistent sessions when executing multi-step tasks via `agy` to avoid resending the codebase context.
- **Error Trapping**: Set `AGY_ON_FAILURE=strict`. If an `agy` execution path crashes, fails a compilation check, or misses a dependency, halt the automation pipeline and flag Claude for an explicit manual strategy change.
