import Cocoa

class GradientLayerFactory {

    // MARK: - Gradient Layer Creation

    static func createGradientLayer(
        color: NSColor,
        opacity: CGFloat,
        frame: CGRect
    ) -> CAGradientLayer {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = frame
        gradientLayer.colors = [
            color.cgColor,
            color.withAlphaComponent(0.5).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.opacity = Float(opacity)
        return gradientLayer
    }
}
