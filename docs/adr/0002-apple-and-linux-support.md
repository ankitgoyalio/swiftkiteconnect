# Support Apple applications and server-side Swift on Linux

Apple applications and server-side Swift on Linux are first-release targets. The core will remain independent of UI frameworks so the SDK can serve both application and backend use cases, including the authentication boundary required for publicly distributed applications.

The first release will support iOS 18+, macOS 15+, and Linux, retaining the scaffold's Swift 6.4 compiler minimum. tvOS, watchOS, and visionOS are deferred. Automated platform checks will cover macOS, iOS Simulator, and Ubuntu 24.04; Linux transport support must be validated in that environment before its implementation is selected.
