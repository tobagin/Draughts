# Tasks: Implement the Ruleset for Each Type of Draughts Game

**Input**: Design documents from `/home/tobagin/Projects/Dama/specs/001-implement-the-ruleset/`
**Prerequisites**: plan.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

## Execution Flow (main)
```
1. Load plan.md from feature directory ✅
   → Tech stack: Vala, GTK4, LibAdwaita, GSettings, Meson
   → Structure: Single desktop application
2. Load design documents ✅:
   → data-model.md: 8 core entities → model tasks
   → contracts/: 2 interface files → implementation + test tasks
   → research.md: 16 draughts variants + AI system → specialized tasks
3. Generate tasks by category:
   → Setup: Vala project structure, dependencies, build configuration
   → Tests: 16 variant tests, AI tests, UI tests, accessibility tests
   → Core: entities, rule engines, AI system, timing controls
   → UI: board widget, controls, preferences, accessibility
   → Integration: GSettings, game flow, timer integration
   → Polish: performance optimization, documentation, validation
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001-T050)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness: SUCCESS ✅
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Single project**: `src/`, `tests/` at repository root
- Paths assume existing Vala/GTK4 project structure

---

## Phase 3.1: Setup & Infrastructure

- [x] **T001** Create draughts game module structure in `src/models/draughts/` directory
- [x] **T002** [P] Configure GSettings schema in `data/io.github.tobagin.Draughts.gschema.xml.in` for game preferences
- [x] **T003** [P] Add draughts game dependencies to `src/meson.build` (no external deps required)
- [x] **T004** [P] Create game constants and enums in `src/models/draughts/DraughtsConstants.vala`

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3

**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

### Core Entity Tests
- [x] **T005** [P] Position validation test in `tests/unit/test_position.vala`
- [x] **T006** [P] GamePiece model test in `tests/unit/test_game_piece.vala`
- [x] **T007** [P] Move validation test in `tests/unit/test_move.vala`
- [x] **T008** [P] GameState test in `tests/unit/test_game_state.vala`

### Rule Engine Contract Tests
- [x] **T009** [P] IRuleEngine interface test in `tests/contract/test_rule_engine_interface.vala`
- [x] **T010** [P] Base rule engine test in `tests/unit/test_base_rule_engine.vala`
- [x] **T011** [P] Move generation test in `tests/unit/test_move_generation.vala`
- [x] **T012** [P] Win condition detection test in `tests/unit/test_win_conditions.vala`

### Variant-Specific Rule Tests (16 variants)
- [x] **T013** [P] American Checkers rules test in `tests/unit/variants/test_american_rules.vala`
- [x] **T014** [P] International Draughts rules test in `tests/unit/variants/test_international_rules.vala`
- [x] **T015** [P] Russian Draughts rules test in `tests/unit/variants/test_russian_rules.vala`
- [x] **T016** [P] Brazilian Draughts rules test in `tests/unit/variants/test_brazilian_rules.vala`
- [x] **T017** [P] Italian Draughts rules test in `tests/unit/variants/test_italian_rules.vala`
- [x] **T018** [P] Spanish Draughts rules test in `tests/unit/variants/test_spanish_rules.vala`
- [x] **T019** [P] Czech Draughts rules test in `tests/unit/variants/test_czech_rules.vala`
- [x] **T020** [P] Thai Draughts rules test in `tests/unit/variants/test_thai_rules.vala`
- [x] **T021** [P] German Draughts rules test in `tests/unit/variants/test_german_rules.vala`
- [x] **T022** [P] Swedish Draughts rules test in `tests/unit/variants/test_swedish_rules.vala`
- [x] **T023** [P] Pool Checkers rules test in `tests/unit/variants/test_pool_rules.vala`
- [x] **T024** [P] Turkish Draughts rules test in `tests/unit/variants/test_turkish_rules.vala`
- [x] **T025** [P] Armenian Draughts rules test in `tests/unit/variants/test_armenian_rules.vala`
- [x] **T026** [P] Gothic Draughts rules test in `tests/unit/variants/test_gothic_rules.vala`
- [x] **T027** [P] Frisian Draughts rules test in `tests/unit/variants/test_frisian_rules.vala`
- [x] **T028** [P] Canadian Draughts rules test in `tests/unit/variants/test_canadian_rules.vala`

### AI System Tests
- [x] **T029** [P] AI evaluation function test in `tests/unit/test_ai_evaluation.vala`
- [x] **T030** [P] Minimax algorithm test in `tests/unit/test_minimax.vala`
- [x] **T031** [P] AI difficulty progression test in `tests/integration/test_ai_difficulty.vala`

### UI Component Tests
- [x] **T032** [P] DraughtsBoard widget test in `tests/ui/test_draughts_board.vala`
- [x] **T033** [P] Game controls test in `tests/ui/test_game_controls.vala`
- [x] **T034** [P] Timer widget test in `tests/ui/test_timer_widget.vala`
- [x] **T035** [P] Accessibility keyboard navigation test in `tests/accessibility/test_keyboard_nav.vala`

### Integration Tests
- [x] **T036** [P] Complete game flow test in `tests/integration/test_game_flow.vala`
- [x] **T037** [P] Timer integration test in `tests/integration/test_timer_integration.vala`
- [x] **T038** [P] Settings persistence test in `tests/integration/test_settings_persistence.vala`

## Phase 3.3: Core Implementation (ONLY after tests are failing)

### Core Entity Models
- [x] **T039** [P] Position model in `src/models/draughts/BoardPosition.vala`
- [x] **T040** [P] GamePiece model in `src/models/draughts/GamePiece.vala`
- [x] **T041** [P] Move model in `src/models/draughts/DraughtsMove.vala`
- [x] **T042** [P] GameState model in `src/models/draughts/DraughtsGameState.vala`
- [x] **T043** [P] GameVariant model in `src/models/draughts/GameVariant.vala`
- [x] **T044** [P] Player model in `src/models/draughts/GamePlayer.vala`
- [x] **T045** [P] Timer model in `src/models/draughts/Timer.vala`
- [x] **T046** [P] Game model in `src/models/draughts/Game.vala`

### Rule Engine System
- [x] **T047** IRuleEngine interface implementation in `src/services/draughts/IRuleEngine.vala`
- [x] **T048** Base rule engine in `src/services/draughts/BaseRuleEngine.vala`
- [x] **T049** Board validator in `src/services/draughts/BoardValidator.vala`
- [x] **T050** Move generator in `src/services/draughts/MoveGenerator.vala`

### Variant-Specific Rule Engines (depends on T048)
- [x] **T051** [P] American Checkers engine in `src/services/draughts/variants/AmericanRuleEngine.vala`
- [x] **T052** [P] International Draughts engine in `src/services/draughts/variants/InternationalRuleEngine.vala`
- [x] **T053** [P] Russian Draughts engine in `src/services/draughts/variants/RussianRuleEngine.vala`
- [x] **T054** [P] Brazilian Draughts engine in `src/services/draughts/variants/BrazilianRuleEngine.vala`
- [x] **T055** [P] Italian Draughts engine in `src/services/draughts/variants/ItalianRuleEngine.vala`
- [x] **T056** [P] Spanish Draughts engine in `src/services/draughts/variants/SpanishRuleEngine.vala`
- [x] **T057** [P] Czech Draughts engine in `src/services/draughts/variants/CzechRuleEngine.vala`
- [x] **T058** [P] Thai Draughts engine in `src/services/draughts/variants/ThaiRuleEngine.vala`
- [x] **T059** [P] German Draughts engine in `src/services/draughts/variants/GermanRuleEngine.vala`
- [x] **T060** [P] Swedish Draughts engine in `src/services/draughts/variants/SwedishRuleEngine.vala`
- [x] **T061** [P] Pool Checkers engine in `src/services/draughts/variants/PoolRuleEngine.vala`
- [x] **T062** [P] Turkish Draughts engine in `src/services/draughts/variants/TurkishRuleEngine.vala`
- [x] **T063** [P] Armenian Draughts engine in `src/services/draughts/variants/ArmenianRuleEngine.vala`
- [x] **T064** [P] Gothic Draughts engine in `src/services/draughts/variants/GothicRuleEngine.vala`
- [x] **T065** [P] Frisian Draughts engine in `src/services/draughts/variants/FrisianRuleEngine.vala`
- [x] **T066** [P] Canadian Draughts engine in `src/services/draughts/variants/CanadianRuleEngine.vala`

### AI System Implementation
- [x] **T067** IAIPlayer interface in `src/services/draughts/IAIPlayer.vala`
- [x] **T068** Position evaluation system in `src/services/draughts/PositionEvaluator.vala`
- [x] **T069** Minimax algorithm with alpha-beta pruning in `src/services/draughts/MinimaxAI.vala`
- [x] **T070** AI difficulty configuration in `src/services/draughts/AIDifficultyManager.vala`

### Game Controller System
- [x] **T071** IGameController interface in `src/services/draughts/IGameController.vala`
- [x] **T072** Main game controller in `src/services/draughts/GameController.vala`
- [x] **T073** Timer controller in `src/services/draughts/TimerController.vala`

## Phase 3.4: UI Implementation

### Custom Game Board Widget
- [x] **T074** DraughtsBoardAdapter widget integration in `src/widgets/DraughtsBoardAdapter.vala`
- [x] **T075** Board rendering and piece drawing in `src/widgets/BoardRenderer.vala`
- [x] **T076** Mouse and touch interaction handling in `src/widgets/BoardInteractionHandler.vala`

### Game Control Widgets
- [x] **T077** [P] Game control panel in `src/widgets/GameControls.vala`
- [x] **T078** [P] Timer display widget in `src/widgets/TimerDisplay.vala`
- [x] **T079** [P] Move history widget in `src/widgets/MoveHistory.vala`
- [x] **T080** [P] Variant selector dialog in `src/dialogs/VariantSelector.vala`

### Preferences and Settings
- [x] **T081** Game preferences dialog in `src/dialogs/GamePreferences.vala`
- [ ] **T082** AI settings configuration in `src/dialogs/AISettings.vala`
- [ ] **T083** Timer setup dialog in `src/dialogs/TimerSetup.vala`

### Accessibility Implementation
- [x] **T084** Keyboard navigation handler in `src/utils/KeyboardNavigationHandler.vala`
- [x] **T085** Screen reader announcements in `src/utils/AccessibilityAnnouncer.vala`
- [ ] **T086** High contrast mode support in `src/utils/ThemeManager.vala`

## Phase 3.5: Integration & Services

### Game Flow Integration
- [ ] **T087** Game session manager in `src/managers/GameSessionManager.vala`
- [ ] **T088** Settings manager with GSettings in `src/managers/SettingsManager.vala`
- [ ] **T089** Resource manager for game assets in `src/managers/ResourceManager.vala`

### Window and Application Integration
- [x] **T090** Integrate draughts board into main window in `src/Window.vala`
- [x] **T091** Add game menu items and shortcuts in `src/Window.vala`
- [ ] **T092** Connect preferences dialogs to application in `src/Application.vala`

## Phase 3.6: Polish & Performance

### Unit Tests for Core Utils
- [ ] **T093** [P] Game utilities test in `tests/unit/test_game_utils.vala`
- [ ] **T094** [P] Board utilities test in `tests/unit/test_board_utils.vala`
- [ ] **T095** [P] Settings manager test in `tests/unit/test_settings_manager.vala`

### Performance Optimization
- [ ] **T096** Performance benchmark for AI calculation (<100ms) in `tests/performance/test_ai_performance.vala`
- [ ] **T097** Memory usage optimization and testing in `tests/performance/test_memory_usage.vala`
- [ ] **T098** UI rendering performance (60fps) validation in `tests/performance/test_ui_performance.vala`

### Documentation and Validation
- [ ] **T099** [P] Update user documentation for draughts features in `docs/draughts-guide.md`
- [ ] **T100** Final accessibility validation with quickstart guide testing
- [ ] **T101** Integration with main application help system

---

## Dependencies

**Critical Path**:
1. **Setup (T001-T004)** before everything
2. **All Tests (T005-T038)** before implementation
3. **Core Models (T039-T046)** before rule engines
4. **Base Rule Engine (T047-T050)** before variant engines (T051-T066)
5. **AI System (T067-T070)** can be parallel with rule engines
6. **Game Controller (T071-T073)** depends on models and rule engines
7. **UI Implementation (T074-T086)** can be parallel with backend after models
8. **Integration (T087-T092)** requires completed backend and UI
9. **Polish (T093-T101)** after everything else

**Blocking Dependencies**:
- T048 (BaseRuleEngine) blocks T051-T066 (all variant engines)
- T039-T046 (models) block T047-T073 (all services)
- T074 (DraughtsBoard) blocks T090 (window integration)
- T088 (SettingsManager) blocks T091 (preferences integration)

## Parallel Execution Examples

### Phase 1: Setup (can run together)
```bash
# Launch T001-T004 in parallel:
Task: "Create draughts game module structure in src/models/draughts/ directory"
Task: "Configure GSettings schema in data/io.github.tobagin.Draughts.gschema.xml.in"
Task: "Add draughts game dependencies to src/meson.build"
Task: "Create game constants and enums in src/models/draughts/DraughtsConstants.vala"
```

### Phase 2: Entity Tests (largest parallel batch)
```bash
# Launch T005-T028 in parallel (24 tests):
Task: "Position validation test in tests/unit/test_position.vala"
Task: "GamePiece model test in tests/unit/test_game_piece.vala"
# ... all variant rule tests ...
Task: "Canadian Draughts rules test in tests/unit/variants/test_canadian_rules.vala"
```

### Phase 3: Core Models (can run together after tests fail)
```bash
# Launch T039-T046 in parallel:
Task: "Position model in src/models/draughts/Position.vala"
Task: "GamePiece model in src/models/draughts/GamePiece.vala"
# ... all 8 core models ...
Task: "Game model in src/models/draughts/Game.vala"
```

### Phase 4: Variant Engines (after base engine T048)
```bash
# Launch T051-T066 in parallel:
Task: "American Checkers engine in src/services/draughts/variants/AmericanRuleEngine.vala"
Task: "International Draughts engine in src/services/draughts/variants/InternationalRuleEngine.vala"
# ... all 16 variant engines ...
Task: "Canadian Draughts engine in src/services/draughts/variants/CanadianRuleEngine.vala"
```

## Validation Checklist
*GATE: Checked before execution*

- [x] All 16 draughts variants have corresponding rule engine implementation tasks
- [x] All 16 variants have corresponding test tasks
- [x] All 8 core entities have model tasks
- [x] All UI interactions have accessibility tests
- [x] All tests come before implementation (T005-T038 before T039+)
- [x] Parallel tasks truly independent (different files)
- [x] Each task specifies exact file path
- [x] No task modifies same file as another [P] task
- [x] Game controller interfaces (IRuleEngine, IAIPlayer, IGameController) implemented
- [x] Performance requirements covered (AI <100ms, UI 60fps)
- [x] Accessibility requirements fully covered
- [x] GSettings integration for persistence
- [x] 8+ AI difficulty levels implementation planned

## Notes
- **101 total tasks** covering complete draughts game implementation
- **Critical: Tests must fail before implementation begins**
- **16 rule engines** for complete variant coverage
- **7+ AI difficulty levels** with performance constraints
- **Full accessibility support** with keyboard navigation and screen reader
- **GNOME compliance** with LibAdwaita widgets and patterns
- **[P] tasks** can run in parallel when dependencies are met
- **Commit after each task** for proper version control
- **Performance targets**: <100ms AI, 60fps UI, <100MB memory