# Max - macOS Dock Customization Utility

A lightweight macOS menu bar application that overlays a customizable visual effect on the Dock region, enabling full control over colors, materials, and visual effects.

## Features

### Visual Customization
- **Adjustable Height** - Control overlay height from 20-300px with live preview
- **Custom Colors & Gradients** - Apply solid colors or vertical gradients to the Dock background
- **Material Effects** - Choose from 10 macOS visual effect materials (blur styles)
- **Blending Modes** - Behind Window or Within Window blending
- **Dual Opacity Controls** - Separate opacity for effect layer and background layer
- **Smooth Animations** - Optional animated transitions for all visual changes

### User Experience
- **Menu Bar Integration** - Quick toggle and settings access from the menu bar
- **Launch at Login** - Automatically start Max when you log in (macOS 13+)
- **Multi-Display Support** - Automatically adapts to screen configuration changes
- **Universal Spaces** - Overlay persists across all virtual desktops
- **Non-Intrusive** - Overlay ignores all mouse events, won't interfere with Dock interaction

### Settings Management
- **Live Preview** - All changes apply immediately with visual feedback
- **Persistent Configuration** - Settings automatically saved using UserDefaults
- **Reset to Defaults** - One-click restoration of default settings

## Architecture

Max features a modern, reactive architecture built with Swift and Combine:

```
Max/
├── main.swift                          # Application entry point
├── AppDelegate.swift                   # Application lifecycle coordinator
├── Services/
│   └── ConfigurationService.swift      # Centralized state management with Combine
├── Windows/
│   ├── OverlayWindowController.swift   # Dock overlay rendering and positioning
│   └── SettingsWindowController.swift  # Settings UI and user interactions
├── Managers/
│   ├── PersistenceManager.swift        # UserDefaults persistence layer
│   ├── MenuBarManager.swift            # NSStatusBar menu integration
│   └── LaunchAtLoginManager.swift      # Login item management (macOS 13+)
├── Models/
│   └── OverlayConfiguration.swift      # Configuration model with validation
└── Utilities/
    └── GradientLayerFactory.swift      # CAGradientLayer creation helper
```

### Key Design Patterns

**Reactive State Management**
- Single source of truth via `ConfigurationService`
- Automatic UI updates through Combine publishers
- Debounced auto-save (100ms) for smooth user experience
- No manual state synchronization required

**Separation of Concerns**
- Services handle business logic and state
- Controllers manage UI and user interactions
- Managers encapsulate system integrations
- Models define data structures and validation

**Memory Safety**
- All Combine subscriptions use `[weak self]` to prevent retain cycles
- Proper cleanup in `deinit` for NotificationCenter observers
- No force unwrapping in production code paths

## Technical Implementation

### Overlay Window Positioning
The overlay uses `NSScreen.main.visibleFrame` to calculate Dock position, accounting for both full screen height and visible frame to handle auto-hiding Dock configurations.

### Visual Effect Composition
Layered rendering approach:
1. **Background View** - Custom color/gradient or system color layer
2. **Effect View** - NSVisualEffectView with configurable material and blending
3. **Container View** - Manages subview hierarchy and frame updates

### Configuration Persistence
Uses `NSKeyedArchiver` with secure coding for NSColor serialization, with graceful fallback to legacy decoding for backward compatibility.

### Screen Change Handling
Observes `NSApplication.didChangeScreenParametersNotification` to automatically reposition overlay when display configuration changes (resolution, arrangement, etc.).

## Requirements

- **macOS**: 11.0+ (Big Sur or later)
- **Launch at Login**: Requires macOS 13.0+ (Ventura or later)
- **Xcode**: 14.0+ for building
- **Framework**: AppKit + Combine

## Building & Running

1. Clone the repository
2. Open `Max.xcodeproj` in Xcode
3. Build and run (⌘R)
4. Grant any required permissions if prompted

The app will appear in your menu bar as "M".

## Usage

1. **Access Settings** - Click "M" in menu bar → Settings...
2. **Configure Appearance** - Adjust height, colors, materials, and opacity to your preference
3. **Toggle Overlay** - Menu bar → Toggle Overlay or press ⌘T
4. **Enable Overlay** - Check "Enable Overlay" in settings to activate

### Recommended Settings for Best Dock Coverage

For optimal Dock coverage, try these settings:
- **Material**: Under Window Background (Best)
- **Background Opacity**: 85-95%
- **Effect Opacity**: 90-100%
- **Height**: Adjust to match your Dock size

## License

MIT License - see LICENSE file for details

## Author

Jason Schulke

## Version

1.0.0
