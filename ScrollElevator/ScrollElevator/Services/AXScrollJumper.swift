import AppKit
import ApplicationServices

/// Jumps via the Accessibility scrollbar of the scroll area under the pointer:
/// no keystrokes, no caret movement, and background windows scroll without
/// being activated. Not every app exposes a scrollbar — callers fall back to
/// a key ladder when this fails.
enum AXScrollJumper {
    /// Set the vertical scrollbar of the scroll area under `point` to min/max.
    static func jump(_ direction: JumpDirection, atCocoaPoint point: NSPoint) -> Bool {
        guard let bar = verticalScrollBar(atCocoaPoint: point) else { return false }
        let value = direction == .top ? 0.0 : 1.0
        return AXUIElementSetAttributeValue(
            bar, kAXValueAttribute as CFString, value as CFNumber
        ) == .success
    }

    /// Current scroll position (0 = top, 1 = bottom) of the scroll area under
    /// `point`, or nil when no scrollbar is exposed.
    static func scrollPosition(atCocoaPoint point: NSPoint) -> Double? {
        guard let bar = verticalScrollBar(atCocoaPoint: point) else { return nil }
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(bar, kAXValueAttribute as CFString, &ref) == .success,
              let number = ref as? NSNumber else { return nil }
        return number.doubleValue
    }

    /// Height in points of the scroll area under `point` — used to size a
    /// "page" for the long-press page action.
    static func scrollAreaHeight(atCocoaPoint point: NSPoint) -> CGFloat? {
        guard let area = climb(fromCocoaPoint: point, until: { element in
            role(of: element) == kAXScrollAreaRole as String
        }) else { return nil }
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(area, kAXSizeAttribute as CFString, &ref) == .success,
              let ref, CFGetTypeID(ref) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue((ref as! AXValue), .cgSize, &size) else { return nil }
        return size.height
    }

    // MARK: - Element lookup

    private static func verticalScrollBar(atCocoaPoint point: NSPoint) -> AXUIElement? {
        // Climb to the nearest enclosing scroll area that exposes a vertical
        // scrollbar. Nested scroll views resolve to the innermost one — which
        // is the one the user was actually scrolling.
        var bar: AXUIElement?
        _ = climb(fromCocoaPoint: point, until: { element in
            guard role(of: element) == kAXScrollAreaRole as String else { return false }
            bar = elementAttribute(element, kAXVerticalScrollBarAttribute as CFString)
            return bar != nil
        })
        return bar
    }

    /// Walk up the AX ancestry from the element under `point` until the
    /// predicate matches; returns the matching element.
    private static func climb(
        fromCocoaPoint point: NSPoint,
        until predicate: (AXUIElement) -> Bool
    ) -> AXUIElement? {
        guard let primary = NSScreen.screens.first else { return nil }
        // AX positions use top-left-origin global coordinates.
        let cgPoint = CGPoint(x: point.x, y: primary.frame.maxY - point.y)

        let systemWide = AXUIElementCreateSystemWide()
        var elementRef: AXUIElement?
        guard AXUIElementCopyElementAtPosition(
            systemWide, Float(cgPoint.x), Float(cgPoint.y), &elementRef
        ) == .success, var element = elementRef else { return nil }

        for _ in 0..<24 {
            if predicate(element) { return element }
            guard let parent = elementAttribute(element, kAXParentAttribute as CFString) else {
                return nil
            }
            element = parent
        }
        return nil
    }

    private static func role(of element: AXUIElement) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &ref) == .success else {
            return nil
        }
        return ref as? String
    }

    private static func elementAttribute(_ element: AXUIElement, _ attribute: CFString) -> AXUIElement? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &ref) == .success,
              let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
        return (ref as! AXUIElement)
    }
}
