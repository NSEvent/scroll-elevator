import AppKit

/// Per-app jump strategy. `.auto` tries the Accessibility scrollbar first and
/// falls back to a bundle-appropriate key ladder; explicit rules force keys.
enum JumpRule: String, CaseIterable, Identifiable {
    case auto
    case cmdArrows
    case homeEnd
    case cmdHomeEnd
    case ignore

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Automatic"
        case .cmdArrows: return "⌘↑ / ⌘↓"
        case .homeEnd: return "Home / End"
        case .cmdHomeEnd: return "⌘Home / ⌘End"
        case .ignore: return "Ignore app"
        }
    }
}

/// Optional modifier the user must hold while scrolling for the overlay to show.
enum ModifierGate: String, CaseIterable, Identifiable {
    case none
    case command
    case option
    case control
    case shift

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Off — show on any scroll"
        case .command: return "⌘ Command"
        case .option: return "⌥ Option"
        case .control: return "⌃ Control"
        case .shift: return "⇧ Shift"
        }
    }

    var flag: NSEvent.ModifierFlags? {
        switch self {
        case .none: return nil
        case .command: return .command
        case .option: return .option
        case .control: return .control
        case .shift: return .shift
        }
    }
}
