# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
- **DBServiceDEPRECATED**: Legacy SQLite-based database service (being phased out)
- **TaskchampionService**: New service using taskchampion-swift Rust library (incomplete migration)
- **NotificationService**: Handles local notifications
- **NLPService**: Natural language processing for task parsing
- **FileService**: iCloud Drive file operations

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