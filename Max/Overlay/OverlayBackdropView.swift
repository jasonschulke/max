import AppKit

/// Draws the bar: Liquid Glass or a blur material, plus an optional tint.
final class OverlayBackdropView: NSView {
    private let glassView = NSGlassEffectView()
    private let blurView = NSVisualEffectView()
    private let tintView = TintView()
    private var maskRadius: CGFloat = -1

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        for view in [glassView, blurView] as [NSView] {
            view.frame = bounds
            view.autoresizingMask = [.width, .height]
            addSubview(view)
        }
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        tintView.autoresizingMask = [.width, .height]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    func apply(_ configuration: OverlayConfiguration, orientation: DockOrientation) {
        let radius = CGFloat(configuration.cornerRadius)
        let tint = configuration.tint
        tintView.apply(tint, orientation: orientation)
        // The material overhangs the screen edge and the window clips it; autoresizing keeps the overhang as the bar resizes.
        let materialFrame = DockGeometry.materialFrame(in: bounds, cornerRadius: configuration.cornerRadius, orientation: orientation)
        glassView.frame = materialFrame
        blurView.frame = materialFrame

        switch configuration.style {
        case .glass, .clearGlass:
            blurView.isHidden = true
            tintView.removeFromSuperview()
            glassView.isHidden = false
            glassView.style = configuration.style == .clearGlass ? .clear : .regular
            glassView.cornerRadius = radius
            // A flat tint is part of the glass itself; a fading tint is content drawn on it.
            if tint.isEnabled, !tint.fadesUpward {
                glassView.tintColor = tint.color.withAlpha(tint.strength).nsColor
            } else {
                glassView.tintColor = nil
            }
            if tint.isEnabled, tint.fadesUpward {
                tintView.frame = glassView.bounds
                glassView.contentView = tintView
            } else {
                glassView.contentView = nil
            }

        case .blur:
            glassView.isHidden = true
            glassView.contentView = nil
            blurView.isHidden = false
            blurView.material = configuration.blurMaterial.material
            if radius != maskRadius {
                blurView.maskImage = radius > 0 ? Self.roundedMask(radius: radius) : nil
                maskRadius = radius
            }
            if tint.isEnabled {
                if tintView.superview !== blurView {
                    tintView.removeFromSuperview()
                    tintView.frame = blurView.bounds
                    blurView.addSubview(tintView)
                }
            } else {
                tintView.removeFromSuperview()
            }
        }
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// A flat or fading color wash. Its backing layer is the gradient, so it resizes with the view.
private final class TintView: NSView {

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override func makeBackingLayer() -> CALayer {
        CAGradientLayer()
    }

    func apply(_ tint: OverlayConfiguration.Tint, orientation: DockOrientation) {
        guard let gradient = layer as? CAGradientLayer else { return }
        let solid = tint.color.withAlpha(tint.strength).nsColor.cgColor
        let clear = tint.color.withAlpha(0).nsColor.cgColor
        gradient.colors = tint.fadesUpward ? [solid, clear] : [solid, solid]
        // Layer coordinates are not flipped: y = 0 is the bottom. Fade from the screen edge inward.
        switch orientation {
        case .bottom:
            gradient.startPoint = CGPoint(x: 0.5, y: 0)
            gradient.endPoint = CGPoint(x: 0.5, y: 1)
        case .left:
            gradient.startPoint = CGPoint(x: 0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)
        case .right:
            gradient.startPoint = CGPoint(x: 1, y: 0.5)
            gradient.endPoint = CGPoint(x: 0, y: 0.5)
        }
    }
}
