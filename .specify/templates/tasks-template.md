# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → If not found: ERROR "No implementation plan found"
   → Extract: tech stack, libraries, structure
2. Load optional design documents:
   → data-model.md: Extract entities → model tasks
   → contracts/: Each file → contract test task
   → research.md: Extract decisions → setup tasks
3. Generate tasks by category:
   → Setup: Vala project init, dependencies, build system
   → Tests: game logic tests, UI interaction tests, accessibility tests
   → Core: game models, board logic, rule implementations
   → UI: GTK4/LibAdwaita widgets, Blueprint definitions, responsive design
   → Integration: GSettings persistence, resource embedding, Flatpak packaging
   → Polish: unit tests, performance optimization, documentation
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001, T002...)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness:
   → All contracts have tests?
   → All entities have models?
   → All endpoints implemented?
9. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Single project**: `src/`, `tests/` at repository root
- **Web app**: `backend/src/`, `frontend/src/`
- **Mobile**: `api/src/`, `ios/src/` or `android/src/`
- Paths shown below assume single project - adjust based on plan.md structure

## Phase 3.1: Setup
- [ ] T001 Create Vala project structure per implementation plan
- [ ] T002 Initialize Meson build system with GTK4/LibAdwaita dependencies
- [ ] T003 [P] Configure Vala linting and Blueprint compilation

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**
- [ ] T004 [P] Game logic test for board initialization in tests/unit/test_board_init.vala
- [ ] T005 [P] Game logic test for move validation in tests/unit/test_move_validation.vala
- [ ] T006 [P] Integration test for UI board interaction in tests/integration/test_board_ui.vala
- [ ] T007 [P] Accessibility test for keyboard navigation in tests/accessibility/test_keyboard_nav.vala

## Phase 3.3: Core Implementation (ONLY after tests are failing)
- [ ] T008 [P] Board model in src/models/Board.vala
- [ ] T009 [P] Game rules engine in src/game/GameRules.vala
- [ ] T010 [P] Move validation logic in src/game/MoveValidator.vala
- [ ] T011 DraughtsBoard widget implementation
- [ ] T012 Game state management with GSettings
- [ ] T013 Input validation for moves
- [ ] T014 Error handling and user feedback

## Phase 3.4: Integration
- [ ] T015 Integrate game logic with UI widget
- [ ] T016 Connect settings persistence with GSettings
- [ ] T017 Add game event logging
- [ ] T018 Embed game assets with GResource

## Phase 3.5: Polish
- [ ] T019 [P] Unit tests for game utilities in tests/unit/test_game_utils.vala
- [ ] T020 Performance tests (<100ms move calculation)
- [ ] T021 [P] Update game documentation and help
- [ ] T022 Remove code duplication
- [ ] T023 Run accessibility validation and manual testing

## Dependencies
- Tests (T004-T007) before implementation (T008-T014)
- T008 blocks T011, T015
- T016 blocks T017
- Implementation before polish (T019-T023)

## Parallel Example
```
# Launch T004-T007 together:
Task: "Game logic test for board initialization in tests/unit/test_board_init.vala"
Task: "Game logic test for move validation in tests/unit/test_move_validation.vala"
Task: "Integration test for UI board interaction in tests/integration/test_board_ui.vala"
Task: "Accessibility test for keyboard navigation in tests/accessibility/test_keyboard_nav.vala"
```

## Notes
- [P] tasks = different files, no dependencies
- Verify tests fail before implementing
- Commit after each task
- Avoid: vague tasks, same file conflicts

## Task Generation Rules
*Applied during main() execution*

1. **From Game Requirements**:
   - Each game rule → validation test task [P]
   - Each UI interaction → widget implementation task

2. **From Data Model**:
   - Each game entity → model creation task [P]
   - Game state relationships → logic implementation tasks

3. **From User Stories**:
   - Each game scenario → integration test [P]
   - Accessibility requirements → accessibility validation tasks

4. **Ordering**:
   - Setup → Tests → Models → Game Logic → UI Widgets → Integration → Polish
   - Dependencies block parallel execution

## Validation Checklist
*GATE: Checked by main() before returning*

- [ ] All game rules have corresponding validation tests
- [ ] All game entities have model tasks
- [ ] All UI interactions have accessibility tests
- [ ] All tests come before implementation
- [ ] Parallel tasks truly independent
- [ ] Each task specifies exact file path
- [ ] No task modifies same file as another [P] task