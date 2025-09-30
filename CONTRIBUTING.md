# Contributing to Draughts

Thank you for your interest in contributing to Draughts! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Coding Standards](#coding-standards)
- [Submitting Changes](#submitting-changes)
- [Reporting Bugs](#reporting-bugs)
- [Feature Requests](#feature-requests)

## Code of Conduct

This project adheres to professional and respectful collaboration standards. Please:

- Be respectful and constructive in discussions
- Focus on the technical merits of contributions
- Help maintain a welcoming environment for all contributors

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/Draughts.git
   cd Draughts
   ```
3. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Prerequisites

- **Vala Compiler** >= 0.56.0
- **Meson** >= 1.9.0
- **GTK4** >= 4.20
- **LibAdwaita** >= 1.8
- **GLib** >= 2.86
- **GStreamer** 1.0 (for sound)
- **Blueprint Compiler** (for UI files)
- **Flatpak** (for packaging)

### Building the Application

**Development build:**
```bash
./scripts/build.sh --dev
```

**Production build:**
```bash
./scripts/build.sh
```

**Running the development version:**
```bash
flatpak run io.github.tobagin.Draughts.Devel
```

## Project Structure

```
Draughts/
├── data/                      # Application resources
│   ├── ui/                   # Blueprint UI definitions
│   │   ├── dialogs/         # Dialog windows
│   │   └── widgets/         # Custom widgets
│   ├── sounds/              # Sound effects (OGG format)
│   ├── icons/               # Application icons
│   └── *.xml.in             # Metadata files
├── src/                      # Vala source code
│   ├── dialogs/             # Dialog implementations
│   ├── managers/            # Manager classes
│   ├── models/              # Data models
│   │   └── draughts/       # Game-specific models
│   ├── services/            # Service classes
│   │   └── draughts/       # Game logic services
│   ├── utils/               # Utility classes
│   ├── widgets/             # Custom widgets
│   ├── Application.vala     # Application entry point
│   └── Window.vala          # Main window
├── packaging/               # Flatpak manifests
├── scripts/                 # Build scripts
└── tests/                   # Test suite
```

## Coding Standards

### Vala Style Guidelines

1. **Indentation**: Use 4 spaces (no tabs)
2. **Braces**: Opening brace on same line
   ```vala
   public void method() {
       // code here
   }
   ```
3. **Naming Conventions**:
   - Classes: `PascalCase`
   - Methods: `snake_case`
   - Private fields: `snake_case`
   - Constants: `UPPER_SNAKE_CASE`
4. **Documentation**: Use doc comments for public APIs
   ```vala
   /**
    * Brief description
    *
    * Detailed description if needed
    */
   public void method_name() {
   ```

### Blueprint UI Guidelines

1. Use **Blueprint** syntax for all new UI files
2. Keep UI logic separate from business logic
3. Use proper GTK4/LibAdwaita widgets
4. Follow GNOME HIG (Human Interface Guidelines)

### Git Commit Messages

Write clear, descriptive commit messages:

```
Short summary (50 chars or less)

More detailed explanation if needed. Wrap at 72 characters.

- Bullet points are okay
- Use present tense: "Add feature" not "Added feature"
- Reference issues: "Fixes #123"
```

## Submitting Changes

### Pull Request Process

1. **Update your branch** with latest main:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Test your changes**:
   - Build successfully with `./scripts/build.sh --dev`
   - Test all affected functionality
   - Verify no regressions in existing features

3. **Commit your changes**:
   ```bash
   git add .
   git commit -m "Your descriptive commit message"
   ```

4. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

5. **Create Pull Request** on GitHub:
   - Provide clear description of changes
   - Reference related issues
   - Include screenshots for UI changes
   - List testing performed

### Pull Request Checklist

- [ ] Code follows project style guidelines
- [ ] All tests pass
- [ ] New features include appropriate documentation
- [ ] UI changes follow GNOME HIG
- [ ] Commit messages are clear and descriptive
- [ ] No unnecessary dependencies added
- [ ] Translations are preserved (don't remove _() markers)

## Reporting Bugs

### Before Submitting

- Check if bug already reported in GitHub Issues
- Test with latest development version
- Gather relevant information:
  - Operating system and version
  - Flatpak runtime version
  - Steps to reproduce
  - Expected vs actual behavior
  - Error messages or logs

### Bug Report Template

```markdown
**Describe the bug**
Clear description of what the bug is.

**To Reproduce**
Steps to reproduce:
1. Go to '...'
2. Click on '...'
3. See error

**Expected behavior**
What you expected to happen.

**Screenshots**
If applicable, add screenshots.

**Environment:**
- OS: [e.g. Fedora 40]
- Flatpak Runtime: [e.g. org.gnome.Platform 49]
- Version: [e.g. 1.0.0]

**Additional context**
Any other relevant information.
```

## Feature Requests

We welcome feature suggestions! When proposing a feature:

1. **Check existing issues** to avoid duplicates
2. **Describe the feature** clearly:
   - What problem does it solve?
   - Who would benefit?
   - How should it work?
3. **Consider scope**: Is it appropriate for this application?
4. **Be patient**: Not all features may be accepted

### Priority Areas

Current focus areas for contributions:

- **Game Variants**: Additional draughts variants
- **AI Improvements**: Better evaluation functions, opening books
- **Accessibility**: Screen reader support, keyboard navigation
- **Performance**: Optimization of game logic and rendering
- **Internationalization**: Translations to new languages
- **Documentation**: User guides, tutorials, examples

## Areas to Contribute

### Easy Issues (Good First Issues)

- UI polish and refinements
- Documentation improvements
- Translation updates
- Bug fixes in existing features

### Medium Complexity

- New board themes or piece styles
- Sound effect improvements
- Accessibility enhancements
- Test coverage expansion

### Advanced

- AI algorithm improvements
- New game variants
- Animation system enhancements
- Performance optimizations
- PDN import/export features

## Development Tips

### Debugging

- Use the development build for debug logging
- Check logs: `journalctl -f | grep draughts`
- Use `logger.debug()` for diagnostic output
- Test with different variants and board sizes

### Testing

- Test all 16 game variants
- Try different AI difficulty levels
- Test keyboard navigation
- Verify accessibility features
- Check different board themes and piece styles

### Resources

- [Vala Documentation](https://wiki.gnome.org/Projects/Vala)
- [GTK4 Documentation](https://docs.gtk.org/gtk4/)
- [LibAdwaita Documentation](https://gnome.pages.gitlab.gnome.org/libadwaita/)
- [GNOME HIG](https://developer.gnome.org/hig/)
- [Blueprint](https://jwestman.pages.gitlab.gnome.org/blueprint-compiler/)

## Questions?

If you have questions about contributing:

- Open a GitHub Discussion
- Comment on relevant issues
- Check existing documentation

## License

By contributing, you agree that your contributions will be licensed under the same GPL-3.0+ license that covers this project.

---

Thank you for contributing to Draughts! Your efforts help make this a better game for everyone.
