<!--
Sync Impact Report:
Version change: [NEW] → 1.0.0
Modified principles: [NEW PROJECT CONSTITUTION]
Added sections: All sections (new constitution)
Removed sections: None (new constitution)
Templates requiring updates:
✅ .specify/templates/plan-template.md - Constitution Check section references updated
✅ .specify/templates/spec-template.md - Requirement alignment maintained
✅ .specify/templates/tasks-template.md - Task categorization aligned with new principles
⚠ Command files in .claude/commands/ - Need review for Claude-specific references
Follow-up TODOs: None
-->

# Draughts Game Constitution

## Core Principles

### I. GNOME Native Design
The application MUST adhere to GNOME Human Interface Guidelines and platform conventions. All UI components MUST use LibAdwaita widgets where available, follow GNOME design patterns, and provide proper accessibility support through ATK integration. The game interface MUST be adaptive and responsive across different screen sizes.

**Rationale**: Users expect native GNOME applications to feel consistent with their desktop environment and provide accessible, adaptive experiences.

### II. Game Logic Integrity
Game mechanics MUST be mathematically correct and rules MUST be properly implemented for each supported draughts variant. Board state MUST be validated before and after every move, with clear separation between game logic and UI presentation. All rule variations MUST be thoroughly tested against established draughts standards.

**Rationale**: A game's credibility depends entirely on correct rule implementation. Incorrect game logic destroys user trust and makes the application unusable for serious play.

### III. Build-First Development
All code MUST build successfully with both development and production profiles before being committed. The Flatpak packaging MUST remain functional and deployable at all times. Breaking the build blocks all other development work and is non-negotiable.

**Rationale**: Broken builds waste team time and prevent testing. Flatpak deployment integrity ensures users can always install and run the application.

### IV. Test-Driven Quality
New game features MUST have corresponding tests written before implementation. Board state validation, move generation, and rule enforcement MUST be covered by automated tests. Manual testing scenarios MUST be documented for UI interactions and accessibility features.

**Rationale**: Game logic complexity requires systematic testing to prevent regressions. User experience quality depends on reliable, tested functionality.

### V. Accessibility First
All interactive elements MUST be keyboard navigable and screen reader compatible. Game state changes MUST be announced appropriately to assistive technologies. Visual elements MUST provide sufficient contrast and support user theme preferences (light/dark mode).

**Rationale**: Games should be enjoyable by all users regardless of ability. GNOME accessibility standards are non-negotiable requirements.

## Technical Standards

### Vala Code Quality
- All public methods MUST have clear parameter validation
- Error handling MUST use appropriate Vala error types, not generic exceptions
- Memory management MUST follow Vala ownership conventions
- Code style MUST follow GNOME Vala conventions (4-space indentation, descriptive names)

### GTK4/LibAdwaita Integration
- UI definition MUST use Blueprint declarative syntax where possible
- Custom widgets MUST inherit from appropriate GTK4 base classes
- State management MUST use GSettings for persistence with proper schema validation
- Resource loading MUST use GResource embedding for assets

### Performance Requirements
- Game move calculation MUST complete within 100ms for standard gameplay
- UI responsiveness MUST maintain 60fps during animations and transitions
- Memory usage MUST remain stable during extended gameplay sessions
- Board rendering MUST scale appropriately for different window sizes

## Development Workflow

### Feature Development Process
1. **Specification**: New features MUST be documented in `/specs/` with clear requirements
2. **Planning**: Technical approach MUST be planned before implementation begins
3. **Implementation**: Code MUST follow TDD principles with tests written first
4. **Testing**: Both automated tests and manual accessibility testing MUST pass
5. **Integration**: Features MUST integrate cleanly with existing game systems

### Code Review Standards
- All changes MUST be tested on both development and production builds
- Game logic changes MUST include test cases for edge conditions
- UI changes MUST be tested with screen readers and keyboard navigation
- Performance impact MUST be evaluated for any changes to core game loops

### Quality Gates
- Build MUST pass on clean checkout before any commit
- All tests MUST pass before code integration
- Accessibility validation MUST be performed for UI changes
- Game rule compliance MUST be verified for any logic modifications

## Governance

### Amendment Process
This constitution can be amended when project needs evolve, but changes require:
1. Documentation of the specific problem current principles don't address
2. Justification that the proposed change aligns with GNOME platform standards
3. Verification that existing code remains compliant with amended principles
4. Update of all related templates and documentation

### Compliance Review
- All development decisions MUST be evaluated against these principles
- Deviations MUST be justified with specific technical rationale
- Complex solutions MUST demonstrate that simpler alternatives were considered
- Architecture decisions MUST prioritize maintainability and user experience

### Version Control
Changes to this constitution MUST be versioned using semantic versioning, with clear change logs documenting the evolution of project governance.

**Version**: 1.0.0 | **Ratified**: 2025-01-24 | **Last Amended**: 2025-01-24