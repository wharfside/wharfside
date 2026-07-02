# Container Desktop

A native macOS desktop application providing a user-friendly graphical interface for managing containers using Apple's [`apple/container`](https://github.com/apple/container) project.

## Overview

**Container Desktop** is a professional container management tool for macOS, similar to Docker Desktop but optimized for Apple's lightweight container runtime. Built with SwiftUI, it offers real-time monitoring, intuitive container operations, and intelligent AI-powered recommendations using Apple's Foundation Models.

## Key Features

🐳 **Container Management** - Create, start, stop, delete, and inspect containers with ease  
📦 **Image Management** - Pull, build, tag, and manage container images  
💾 **Volume Management** - Create and manage persistent data volumes  
🖥️ **Machine Management** - Create and manage persistent container machines  
📊 **Real-Time Monitoring** - Dashboard with CPU, memory, and resource tracking  
🤖 **AI-Powered Insights** - Smart recommendations and anomaly detection using Foundation Models  
🔍 **Advanced Tools** - Built-in logs viewer, terminal access, and detailed inspection panels  
⚡ **Performance** - Lightweight (~30 MB), fast startup (<1 second), minimal resource usage  

## Requirements

- **macOS**: 15+ (Apple silicon)
- **Dependencies**: apple/container v0.3.0+
- **Development**: Xcode 15+, Swift 5.9+

## Getting Started

```bash
# Clone the repository
git clone https://github.com/akserg/container-desktop.git
cd container-desktop

# Build the project
xcodebuild -scheme ContainerDesktop -configuration Release build

# Run the application
open build/Release/ContainerDesktop.app
```

## Architecture

**MVVM Design Pattern** with clean separation of concerns:
- **Views** - SwiftUI components for UI rendering
- **ViewModels** - Business logic and state management
- **Services** - API communication layer
- **Models** - Data structures and domain models

**API Communication** via XPC (Inter-Process Communication) to the container-apiserver background daemon.

**AI Integration** using Apple Foundation Models:
- Natural Language Processing for log analysis
- Anomaly detection for unusual container behavior
- Smart resource optimization recommendations

## Project Structure

```
container-desktop/
├── Sources/
│   └── ContainerDesktop/
│       ├── App/          - Application entry points
│       ├── Views/        - SwiftUI views and components
│       ├── ViewModels/   - State management and logic
│       ├── Services/     - API and service layer
│       ├── Models/       - Data structures
│       └── Utilities/    - Helper functions and extensions
├── Tests/                - Unit and UI tests
├── SPECIFICATION.md      - Detailed product specification
└── Package.swift         - Swift package configuration
```

## Development Phases

**Phase 1 (MVP)** - 6-8 weeks
- Core container operations (6 main views)
- Basic monitoring dashboard
- Service layer integration

**Phase 2 (Advanced)** - 4-6 weeks
- Real-time logs and terminal
- Resource monitoring with charts
- AI recommendations and notifications

**Phase 3 (Release)** - 2-3 weeks
- Testing, polishing, and distribution
- Code signing and notarization
- GitHub/Homebrew deployment

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

Apache License 2.0 - See [LICENSE](LICENSE) for details.

## Documentation

- [**SPECIFICATION.md**](SPECIFICATION.md) - Complete product specification and technical details
- [**Architecture Overview**](SPECIFICATION.md#2-architecture-overview) - System design and patterns
- [**API Documentation**](https://apple.github.io/container/documentation/) - apple/container API reference

## Related Projects

- [apple/container](https://github.com/apple/container) - The container runtime this GUI manages
- [apple/containerization](https://github.com/apple/containerization) - Low-level containerization framework

## Status

🚀 **In Active Development** - Core architecture and specification complete. Ready for implementation.

---

**Version**: 1.0  
**Platform**: macOS 15+ (Apple silicon)  
**Language**: Swift + SwiftUI  
**Latest Update**: 2026-07-02
