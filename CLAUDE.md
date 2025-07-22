# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## AI Agent Guidelines

### Core Constraints
- NEVER create new architectural patterns - follow existing conventions in taskchampShared/
- ALWAYS reference existing code patterns before implementing new features
- USE the migration status below to understand what services to modify vs avoid
- FOCUS on SwiftUI + Combine patterns found in existing views
- FOLLOW the established service layer architecture (see Key Services section)
- Stop telling me you've completed something when you've "laid the ground work" or "When you're ready to fully enable...". Write the code or state the problem you're facing

## Development Setup

This is an iOS SwiftUI app built with Tuist and mise. Before working on the project:

1. Install dependencies:
   ```bash
   brew install swiftlint swiftformat mise
   curl https://sh.rustup.rs -sSf | sh -s -- -y
   ```

2. Setup project:
   ```bash
   mise install
   make up
   ```

## Common Commands

### Build and Development
- `make install` - Install dependencies via Tuist
- `make generate` - Generate Xcode project files
- `make build` - Build the project
- `make up` - Full setup: build taskchampion, install dependencies, generate project
- `make clean` - Clean build artifacts

### Code Quality
- `make lint` - Run SwiftLint on all source directories
- `make format` - Format code using SwiftFormat
- `make test` - Run tests (currently no tests exist but framework is there)

### External Dependencies
- `make clone_taskchampion` - Clone the taskchampion-swift dependency
- `make build_taskchampion` - Build the Rust taskchampion binary
- `make build_taskchampion_ci` - Build taskchampion for CI (skips simulator)

## Architecture

### Project Structure
- **taskchamp/**: Main iOS app target with SwiftUI views and app entry point
- **taskchampShared/**: Shared framework containing business logic, models, and services
- **taskchampWidget/**: iOS widget extension for displaying tasks

### Key Services (taskchampShared/)
- **DBServiceDEPRECATED**: Legacy SQLite-based database service (being phased out) - DO NOT MODIFY
- **TaskchampionService**: New service using taskchampion-swift Rust library (incomplete migration) - PREFERRED FOR NEW FEATURES
- **NotificationService**: Handles local notifications - STABLE, CAN MODIFY
- **NLPService**: Natural language processing for task parsing - STABLE, CAN MODIFY
- **FileService**: iCloud Drive file operations - STABLE, CAN MODIFY

### Code Reference Patterns
When working with this codebase, ALWAYS:
1. Check taskchampShared/Models/ for existing data structures before creating new ones
2. Reference taskchampShared/Services/ patterns for dependency injection and service architecture
3. Follow SwiftUI view patterns in taskchamp/Views/ for UI consistency
4. Use existing TCTask and TCFilter models rather than creating alternatives

### Models
- **TCTask**: Core task model with support for projects, priorities, due dates, and Obsidian notes
- **TCFilter**: Task filtering and search functionality

### Current Migration
The project is migrating from a custom SQLite implementation to the upstream taskchampion-swift library. Database-related contributions should be made to the [taskchampion-swift repository](https://github.com/LostLaplace/taskchampion-swift) instead of modifying DBService.swift.

## Development Workflow

1. All work should be done on the `dev` branch
2. PRs must target `dev` branch (not main)
3. Code must pass linting (`make lint`) before submission
4. Beta testing happens via TestFlight before App Store release

### AI-Assisted Development Process
1. **Exploration Phase**: Use existing file structure to understand patterns before coding
2. **Implementation Phase**: Reference similar existing implementations, don't create from scratch
3. **Validation Phase**: Run `make lint` and `make build` to ensure code quality
4. **Integration Phase**: Test changes fit within existing service architecture

### Common Pitfalls to Avoid
- Creating new service classes when existing ones can be extended
- Ignoring the migration status (avoid touching DBServiceDEPRECATED)
- Implementing UI patterns inconsistent with existing SwiftUI views
- Adding dependencies without checking if functionality already exists

## External Integration

The app integrates with:
- **Taskwarrior**: Command-line task management (v3.0.0+)
- **iCloud Drive**: For task database syncing
- **Obsidian**: For task note-taking via URL schemes

## Dependencies
- **Tuist**: Project generation and build tooling
- **SQLite.swift**: Database access (legacy)
- **SoulverCore**: Natural language calculation
- **Taskchampion**: Rust-based task management library (future)

## Troubleshooting Build Issues

### Getting Build Error Logs
When Xcode builds fail, export build logs: Press ⌘+9 to open Reports navigator, click on a build, then click "Export" to save the build log file.

### Common Build Issues

**Rust Bridge Types Missing (`RustStr`, `__private__FfiSlice` not found)**
- **Cause**: TaskChampion Rust library not properly built or linked
- **Fix**: 
  ```bash
  make clean
  make build_taskchampion  # Rebuild Rust library
  make generate           # Regenerate project
  ```

**iOS Version Availability Errors (`PassthroughSubject` only available in iOS 13.0+)**
- **Cause**: Minimum deployment target too low for Combine framework
- **Fix**: Update deployment target to iOS 13.0+ in Tuist project configuration

**SQLite Compilation Errors**
- **Cause**: Version incompatibility with current Xcode/Swift
- **Fix**: Clean build and regenerate:
  ```bash
  make clean
  make up
  ```