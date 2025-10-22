# Draughts - Development TODO

**Last Updated:** 2025-10-22
**Based on:** Code Analysis Report v2.0

---

## 🔴 High Priority

### Refactoring

- [ ] **Extract AI Logic to Dedicated Service** (Effort: 2-3 days)
  - [ ] Create `src/services/draughts/AIEngine.vala`
  - [ ] Move all `select_*_move()` methods from `DraughtsBoardAdapter.vala`
  - [ ] Implement proper minimax with alpha-beta pruning
  - [ ] Add transposition table support
  - [ ] Create `tests/unit/test_ai_engine.vala`
  - **Files:** `DraughtsBoardAdapter.vala:1393-1750`
  - **Benefit:** Cleaner architecture, testable AI, 50-90% performance improvement

- [ ] **Implement Proper PositionEvaluator** (Effort: 1-2 days)
  - [ ] Material counting (pieces, kings)
  - [ ] King advancement evaluation
  - [ ] Center control scoring
  - [ ] Mobility evaluation
  - [ ] Piece safety assessment
  - **Files:** `src/services/draughts/PositionEvaluator.vala` (currently stub)
  - **Benefit:** Significantly stronger AI at higher difficulties

- [ ] **Split DraughtsBoardAdapter** (Effort: 3-4 days)
  - [ ] Create `BoardSynchronizer.vala` (state sync)
  - [ ] Create `MoveHandler.vala` (click handling, validation)
  - [ ] Create `AnimationController.vala` (piece animations)
  - [ ] Create `AIGameController.vala` (AI move execution)
  - [ ] Refactor `DraughtsBoardAdapter.vala` to orchestrate
  - **Files:** `DraughtsBoardAdapter.vala` (~1800 lines)
  - **Benefit:** Better maintainability, easier testing

### Features

- [ ] **Complete PDN Import** (Effort: 2-3 days)
  - [ ] Create `src/utils/PDNParser.vala`
  - [ ] Parse PDN headers ([Event], [Date], [White], [Black])
  - [ ] Parse move notation (algebraic)
  - [ ] Handle game metadata
  - [ ] Create `tests/unit/test_pdn_parser.vala`
  - [ ] Wire up to "Open PDN File" action
  - **Files:** `Window.vala:2123` (TODO comment)
  - **Benefit:** Load and replay games from external sources

- [ ] **Implement Opening Book** (Effort: 3-5 days)
  - [ ] Create `src/services/draughts/OpeningBook.vala`
  - [ ] Design SQLite schema for positions/moves
  - [ ] Extract openings from professional PDN games
  - [ ] Integrate with AI move selection
  - [ ] Add UI toggle for opening book usage
  - **Benefit:** Stronger early-game play, educational value

### Testing

- [ ] **Add AI Unit Tests** (Effort: 1-2 days)
  - [ ] Test all difficulty levels make legal moves
  - [ ] Test difficulty progression (Level 10 beats Level 1)
  - [ ] Test move selection determinism
  - [ ] Test timeout handling
  - **Files:** Create `tests/unit/test_ai_engine.vala`

- [ ] **Add Multiplayer Integration Tests** (Effort: 2-3 days)
  - [ ] Test room creation and joining
  - [ ] Test game synchronization
  - [ ] Test reconnection recovery
  - [ ] Test disconnect handling
  - **Files:** Create `tests/integration/test_multiplayer.vala`

---

## 🟡 Medium Priority

### Refactoring

- [ ] **Split Window.vala** (Effort: 3-4 days)
  - [ ] Create `WindowNetworkHandler.vala` (multiplayer UI logic)
  - [ ] Create `WindowGameControls.vala` (game setup, new game, reset)
  - [ ] Create `WindowUIState.vala` (UI state, overlays)
  - [ ] Refactor `Window.vala` to main orchestration
  - **Files:** `Window.vala` (~2000 lines)

- [ ] **Standardize Error Handling** (Effort: 1 day)
  - [ ] Create `BaseService` abstract class
  - [ ] Implement `handle_error()` helper method
  - [ ] Update all services to use consistent pattern
  - [ ] Ensure all errors emit signals appropriately
  - **Files:** Multiple throughout codebase

- [ ] **Remove Duplicate UI Files** (Effort: 1 hour)
  - [ ] Remove `data/ui/dialogs/game-preferences.ui`
  - [ ] Remove `data/ui/dialogs/variant-selector.ui`
  - [ ] Keep Blueprint `.blp` versions only
  - [ ] Update meson.build if needed
  - **Benefit:** Cleaner codebase, single source of truth

- [ ] **Define All Magic Numbers as Constants** (Effort: 2-3 hours)
  - [ ] `PONG_TIMEOUT_MULTIPLIER = 2` in `NetworkClient.vala:505`
  - [ ] Board edge constants in `DraughtsBoardAdapter.vala:1471`
  - [ ] Add to appropriate Constants files
  - **Benefit:** Better maintainability, clearer intent

### Features

- [ ] **Game Analysis Tool** (Effort: 4-5 days)
  - [ ] Create `src/services/draughts/GameAnalyzer.vala`
  - [ ] Analyze completed games move-by-move
  - [ ] Classify moves (Excellent/Good/Inaccuracy/Mistake/Blunder)
  - [ ] Show alternative better moves
  - [ ] Display in replay dialog
  - **Benefit:** Educational tool, improve player skills

- [ ] **Enhanced Statistics Dashboard** (Effort: 2-3 days)
  - [ ] Win/loss breakdown by variant
  - [ ] Performance graphs over time
  - [ ] Opening repertoire statistics
  - [ ] Average game length by variant
  - [ ] Create `src/dialogs/StatisticsDialog.vala`

- [ ] **AI Thinking Indicator** (Effort: 1-2 hours)
  - [ ] Add spinner widget during AI calculation
  - [ ] Show "AI is thinking..." message
  - [ ] Display estimated time remaining
  - [ ] Show in game controls area
  - **Benefit:** Better UX feedback

### Testing

- [ ] **Add Variant-Specific Rule Tests** (Effort: 2-3 days)
  - [ ] Test Italian: men cannot capture kings
  - [ ] Test Russian: flying kings
  - [ ] Test International: majority capture
  - [ ] Test all 16 variants systematically
  - **Files:** Create `tests/unit/test_variant_rules.vala`

---

## 🟢 Low Priority

### Optimization

- [ ] **Implement Alpha-Beta Pruning** (Effort: 2-3 days)
  - [ ] Proper minimax with pruning in `AIEngine.vala`
  - [ ] Move ordering for better pruning
  - [ ] Iterative deepening
  - [ ] Performance benchmarking
  - **Expected:** 50-90% reduction in nodes evaluated

- [ ] **Add Transposition Table** (Effort: 1-2 days)
  - [ ] Create `TranspositionTable` class
  - [ ] Implement board hashing
  - [ ] Cache position evaluations
  - [ ] Integrate with minimax search
  - **Expected:** 30-50% fewer evaluations

- [ ] **Optimize Move Generation** (Effort: 1-2 days)
  - [ ] Profile hot paths
  - [ ] Cache legal moves where possible
  - [ ] Optimize capture detection
  - [ ] Reduce memory allocations

### Features

- [ ] **Move Strength Indicator** (Effort: 2-3 days)
  - [ ] Show move quality in move history
  - [ ] Display percentage of best move
  - [ ] Color-code moves (green=good, yellow=inaccuracy, red=mistake)
  - [ ] Add annotations (!, !!, ?, ??)

- [ ] **Opening Name Display** (Effort: 2-3 days)
  - [ ] Detect known openings from book
  - [ ] Display opening name during game
  - [ ] Show opening description
  - [ ] Link to opening theory

- [ ] **Enhanced Multiplayer UI** (Effort: 3-4 days)
  - [ ] Connection quality indicator (ping display)
  - [ ] Opponent time pressure warning
  - [ ] Draw offer button
  - [ ] Takeback request button
  - [ ] Chat system

- [ ] **Puzzle Mode** (Effort: 1-2 weeks)
  - [ ] Create puzzle database schema
  - [ ] Import/create puzzle collection
  - [ ] Daily puzzle feature
  - [ ] Puzzle rating system
  - [ ] Track puzzle solving statistics

- [ ] **Tournament Mode** (Effort: 2-3 weeks)
  - [ ] Swiss-system pairing algorithm
  - [ ] Bracket management UI
  - [ ] Tournament standings
  - [ ] Multiple time control support
  - [ ] Result tracking and reporting

### Documentation

- [ ] **Generate API Documentation** (Effort: 2-3 hours)
  - [ ] Add Valadoc comments to public APIs
  - [ ] Run valadoc generator
  - [ ] Publish to docs/ directory
  - [ ] Add to CI/CD pipeline

- [ ] **Create Architecture Documentation** (Effort: 1 day)
  - [ ] Create `docs/ARCHITECTURE.md`
  - [ ] Explain MVC pattern
  - [ ] Document service layer
  - [ ] Network protocol specification
  - [ ] AI algorithm overview

- [ ] **Create Developer Guide** (Effort: 1 day)
  - [ ] Create `docs/DEVELOPMENT.md`
  - [ ] Build instructions
  - [ ] Testing guidelines
  - [ ] Coding standards
  - [ ] Contribution workflow

### Internationalization

- [ ] **Complete Portuguese Translation** (Effort: 2-3 hours)
  - [ ] Review `po/pt.po` and `po/pt_BR.po`
  - [ ] Translate missing strings
  - [ ] Test with Portuguese locale

- [ ] **Add Spanish Translation** (Effort: 4-6 hours)
  - [ ] Create `po/es.po`
  - [ ] Translate all strings
  - [ ] Test with Spanish locale

- [ ] **Add French Translation** (Effort: 4-6 hours)
  - [ ] Create `po/fr.po`
  - [ ] Translate all strings
  - [ ] Test with French locale

- [ ] **Add German Translation** (Effort: 4-6 hours)
  - [ ] Create `po/de.po`
  - [ ] Translate all strings
  - [ ] Test with German locale

- [ ] **Set Up Weblate/Crowdin** (Effort: 2-3 hours)
  - [ ] Configure translation platform
  - [ ] Invite community translators
  - [ ] Automate translation updates

### CI/CD

- [ ] **Add Automated Testing to CI** (Effort: 2-3 hours)
  - [ ] Create `.github/workflows/test.yml`
  - [ ] Run tests on push/PR
  - [ ] Fail build on test failures

- [ ] **Add Code Coverage** (Effort: 1-2 hours)
  - [ ] Configure coverage in meson
  - [ ] Upload to Codecov
  - [ ] Add coverage badge to README

- [ ] **Add Linting** (Effort: 1 hour)
  - [ ] Add vala-lint to CI
  - [ ] Configure coding standards
  - [ ] Auto-format on commit (optional)

---

## 🔵 Future Ideas / Research

### Advanced Features

- [ ] **Machine Learning AI** (Effort: 4-8 weeks)
  - [ ] Research TensorFlow Lite integration with Vala
  - [ ] Collect/generate training data
  - [ ] Train neural network on positions
  - [ ] Evaluate vs traditional minimax
  - **Note:** Experimental, may not be feasible

- [ ] **Endgame Tablebases** (Effort: 2-3 weeks)
  - [ ] Generate 3-piece perfect play database
  - [ ] Generate 4-piece perfect play database
  - [ ] Integrate with AI search
  - [ ] Add UI indicator for tablebase positions

- [ ] **Online Puzzle Database** (Effort: 3-4 weeks)
  - [ ] Design backend API
  - [ ] Community puzzle submission
  - [ ] Rating system for puzzles
  - [ ] Leaderboards
  - [ ] Daily challenges

- [ ] **Live Streaming/Spectating** (Effort: 4-6 weeks)
  - [ ] Spectator mode for games
  - [ ] Tournament broadcasts
  - [ ] Commentary integration
  - [ ] Game analysis overlay

### Distribution

- [ ] **Debian Package** (Effort: 1-2 days)
  - [ ] Create debian/ directory
  - [ ] Write control files
  - [ ] Test on Debian/Ubuntu
  - [ ] Submit to repositories

- [ ] **RPM Package** (Effort: 1-2 days)
  - [ ] Create .spec file
  - [ ] Test on Fedora/RHEL
  - [ ] Submit to repositories

- [ ] **AUR Package** (Effort: 1 day)
  - [ ] Create PKGBUILD
  - [ ] Test on Arch Linux
  - [ ] Submit to AUR

---

## 📋 Completed Tasks

- [x] Comprehensive code analysis
- [x] AI implementation (10 difficulty levels)
- [x] 16 international variants
- [x] WebSocket multiplayer with reconnection
- [x] GTK4 + LibAdwaita migration
- [x] Blueprint UI migration (partial)
- [x] Russian translation
- [x] Portuguese translation
- [x] PDN export
- [x] Game history and replay
- [x] Timer system (Countdown, Fischer, Bronstein)
- [x] Sound effects and audio
- [x] Accessibility features (screen reader, keyboard navigation)
- [x] High-resolution SVG icon
- [x] GNOME Help integration
- [x] Automated Flathub releases

---

## 🗓️ Release Planning

### Version 2.1.0 (Target: 4-6 weeks)
**Focus: Code Quality & AI Improvements**
- Extract AI logic to dedicated service
- Implement proper PositionEvaluator
- Add AI unit tests
- Complete PDN import
- Remove duplicate UI files

### Version 2.2.0 (Target: 8-12 weeks)
**Focus: Features & Polish**
- Opening book implementation
- Game analysis tool
- Enhanced statistics dashboard
- Split large classes (Window, DraughtsBoardAdapter)
- Multiplayer integration tests

### Version 2.3.0 (Target: 16-20 weeks)
**Focus: Optimization & Advanced Features**
- Alpha-beta pruning optimization
- Transposition tables
- Puzzle mode
- Move strength indicators
- Enhanced multiplayer UI

### Version 3.0.0 (Target: 6-12 months)
**Focus: Major Features**
- Tournament mode
- Machine learning AI (if feasible)
- Endgame tablebases
- Live streaming/spectating

---

## 📊 Priority Guidelines

**🔴 High Priority:** Core improvements, bug fixes, important missing features
**🟡 Medium Priority:** Quality of life, nice-to-have features, optimizations
**🟢 Low Priority:** Polish, documentation, future-looking features
**🔵 Future Ideas:** Experimental, research needed, long-term goals

---

## 🤝 Contributing

To pick up a task:
1. Check if it's already assigned in GitHub Issues
2. Comment on the issue or create one if needed
3. Fork the repository
4. Create a feature branch
5. Implement the task following the coding standards
6. Add tests if applicable
7. Submit a pull request

For questions or discussions, open a GitHub issue or discussion thread.

---

**Note:** This TODO list is a living document. Update it as tasks are completed or priorities change. Use GitHub Issues/Projects for detailed tracking.
