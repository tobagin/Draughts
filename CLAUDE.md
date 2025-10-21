<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# Claude Code Context: GNOME Application Template Project

## Project Overview
This project creates a barebone GNOME application template that serves as a starting point for multiple GNOME applications. The template integrates core GNOME technologies (GTK4, LibAdwaita, ATK, Blueprint, Vala, Meson) and includes flatpak packaging configuration.

## Build Commands
- Production build: `./scripts/build.sh`
- Development build: `./scripts/build.sh --dev`

## Current Feature: 001-this-will-project
**Status**: Planning Phase - Implementation plan in progress
**Branch**: `001-this-will-project`
**Spec Location**: `/specs/001-this-will-project/spec.md`

## Technology Stack
- **Language**: Vala (compiles to C)
- **UI Framework**: GTK4 + LibAdwaita
- **UI Definition**: Blueprint (declarative UI syntax)
- **Build System**: Meson + Ninja
- **Packaging**: Flatpak (org.gnome.Platform//49)
- **Accessibility**: ATK integration
- **Testing**: Meson test framework

## Project Structure
```
app_template/
 specs/001-this-will-project/    # Current feature documentation
    spec.md                     # Feature specification
    plan.md                     # Implementation plan (in progress)
    research.md                 # Technology research (complete)
    data-model.md               # Data model design (complete)
    contracts/                  # API contracts (complete)
    quickstart.md               # Usage guide (complete)
 src/                            # Will contain template generation code
 templates/                      # Will contain application templates
 flatpak/                        # Will contain flatpak configuration
 tests/                          # Will contain template tests
```

## Key Functional Requirements
- FR-001: Provide minimal working GNOME application structure
- FR-002: Include flatpak packaging configuration
- FR-003: Integrate GTK4, LibAdwaita, ATK, Blueprint, Vala, Meson
- FR-004: Allow easy customization and extension
- FR-005: Include build system configuration
- FR-006: Provide comprehensive documentation
- FR-007: Support flatpak runtime version 49
- FR-008: Include application metadata and desktop integration

## Template Variables System
Templates use `{{VARIABLE_NAME}}` syntax for:
- `{{APP_NAME}}`: Human-readable application name
- `{{APP_ID}}`: Reverse DNS identifier
- `{{APP_DESCRIPTION}}`: Application description
- `{{AUTHOR_NAME}}`: Author name
- `{{AUTHOR_EMAIL}}`: Author email
- `{{LICENSE}}`: Software license
- `{{VERSION}}`: Application version

## CLI Interface Design
```bash
gnome-template create <app-name> [OPTIONS]
gnome-template validate <project-directory>
gnome-template list [--verbose]
```

## Generated Project Contract
Each generated project must:
- Build successfully with Meson
- Package as valid Flatpak
- Follow GNOME Human Interface Guidelines
- Include proper desktop integration files
- Pass accessibility requirements
- Include basic test framework

## Development Workflow
1.  Feature specification (complete)
2. = Implementation planning (in progress)
3. � Task generation (/tasks command)
4. � Implementation
5. � Testing and validation

## Recent Changes
- 001-implement-the-ruleset: Added Vala (compiles to C) with GTK4 and LibAdwaita + GTK4, LibAdwaita, GLib, GSettings, ATK (accessibility)
- 2025-09-20: Created feature specification with clarified requirements
- 2025-09-20: Completed research phase with technology decisions

## Notes for Development
- Template must be self-contained and work offline
- All generated code should be production-ready
- Follow GNOME coding standards and conventions
- Ensure accessibility features are demonstrated
- Templates should be extensible for different app types
