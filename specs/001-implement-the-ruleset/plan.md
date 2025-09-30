
# Implementation Plan: Implement the Ruleset for Each Type of Draughts Game

**Branch**: `001-implement-the-ruleset` | **Date**: 2025-09-23 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/home/tobagin/Projects/Dama/specs/001-implement-the-ruleset/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code or `AGENTS.md` for opencode).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Implement comprehensive ruleset engine supporting 16 draughts variants with AI opponents (7+ difficulty levels), timing controls (blitz/rapid/classical/Fischer), and basic undo functionality. System must enforce variant-specific rules for movement, capture, promotion, and draw conditions while maintaining GNOME native design principles.

## Technical Context
**Language/Version**: Vala (compiles to C) with GTK4 and LibAdwaita
**Primary Dependencies**: GTK4, LibAdwaita, GLib, GSettings, ATK (accessibility)
**Storage**: GSettings for user preferences, in-memory game state with optional game history persistence
**Testing**: Meson test framework with Vala unit tests
**Target Platform**: Linux (GNOME Platform runtime 49) via Flatpak packaging
**Project Type**: Single desktop application
**Performance Goals**: <100ms move calculation, 60fps UI rendering, real-time game state updates
**Constraints**: GNOME Human Interface Guidelines compliance, accessibility requirements, offline capability
**Scale/Scope**: 16 draughts variants, 7+ AI difficulty levels, tournament timing features

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### GNOME Native Design Compliance
- [x] Feature design follows GNOME Human Interface Guidelines (game board, timing controls, preferences)
- [x] LibAdwaita widgets are used where appropriate (AdwPreferencesWindow, AdwActionRow, adaptive layouts)
- [x] Accessibility requirements are considered from design phase (keyboard navigation, screen reader support)
- [x] Responsive/adaptive behavior is planned (board scaling, mobile-friendly controls)

### Game Logic Integrity
- [x] Game rules are mathematically correct for target draughts variant (all 16 variants research required)
- [x] Clear separation between game logic and UI presentation (Model-View separation)
- [x] Board state validation approach is defined (before/after move validation)

### Build-First Development
- [x] Changes will not break existing development/production builds (extends current structure)
- [x] Flatpak packaging compatibility maintained (no new external dependencies)
- [x] Dependencies are available in GNOME Platform runtime (GTK4/LibAdwaita included)

### Test-Driven Quality
- [x] Test strategy includes game logic validation (unit tests for each variant)
- [x] UI interaction testing approach defined (accessibility testing with Orca)
- [x] Accessibility testing plan included (keyboard navigation, contrast validation)

### Technical Standards Compliance
- [x] Vala coding conventions will be followed (4-space indentation, GNOME naming)
- [x] Performance requirements considered (100ms move calculation, 60fps UI)
- [x] GSettings schema changes properly planned (game preferences, AI settings)

## Project Structure

### Documentation (this feature)
```
specs/[###-feature]/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
# Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure]
```

**Structure Decision**: Option 1 (Single project) - Desktop GNOME application using existing Vala/GTK4 structure

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:
   ```
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: ✅ research.md complete - All technical decisions documented with rationale

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Generate contract tests** from contracts:
   - One test file per endpoint
   - Assert request/response schemas
   - Tests must fail (no implementation yet)

4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps

5. **Update agent file incrementally** (O(1) operation):
   - Run `.specify/scripts/bash/update-agent-context.sh claude`
     **IMPORTANT**: Execute it exactly as specified above. Do not add or remove any arguments.
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: ✅ Phase 1 Complete:
- data-model.md: Core entities with validation rules
- contracts/: Vala interfaces for game engine and UI components
- quickstart.md: Comprehensive testing and validation guide
- CLAUDE.md: Updated agent context with current feature

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Generate from contracts: Each interface → implementation task + tests
- Generate from data model: Each entity → Vala class implementation
- Generate from quickstart: Each validation test → automated test task
- Generate from variants: Each of 16 variants → rule engine implementation
- Generate AI tasks: 7+ difficulty levels → algorithm implementation
- Generate UI tasks: Board widget, controls, preferences integration

**Ordering Strategy**:
- Foundation first: Basic entities (Position, Move, GamePiece)
- Rule engines: Base engine → variant-specific implementations
- AI system: Evaluation → minimax → difficulty progression
- UI components: Board widget → controls → integration
- Testing: Unit tests → integration tests → accessibility tests
- Mark [P] for parallel execution (independent rule engines, UI components)

**Estimated Output**: 40-50 numbered, ordered tasks covering:
- 16 variant rule engines (parallel after base engine)
- 8+ AI difficulty implementations (parallel after base AI)
- 6+ UI components (parallel after contracts)
- 20+ test implementations (parallel after code)

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |


## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented (none required)

---
*Based on Constitution v1.0.0 - See `.specify/memory/constitution.md`*
