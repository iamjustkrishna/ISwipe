import UIKit

public class SwipeView: UIView {
    
    private let trailLayer = CAShapeLayer()
    private var rawPoints = [CGPoint]()
    private var smoothedPoints = [CGPoint]()
    private var fadeTimer: Timer?
    
    public var trailColor: UIColor = ThemeManager.shared.accentColor {
        didSet {
            trailLayer.strokeColor = trailColor.cgColor
        }
    }
    
    public var trailWidth: CGFloat = 6.0 {
        didSet {
            trailLayer.lineWidth = trailWidth
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private func setupLayer() {
        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear
        
        trailLayer.fillColor = UIColor.clear.cgColor
        trailLayer.strokeColor = trailColor.cgColor
        trailLayer.lineWidth = trailWidth
        trailLayer.lineCap = .round
        trailLayer.lineJoin = .round
        
        // Add a subtle shadow to make the trail pop
        trailLayer.shadowColor = trailColor.cgColor
        trailLayer.shadowRadius = 4.0
        trailLayer.shadowOpacity = 0.5
        trailLayer.shadowOffset = .zero
        
        self.layer.addSublayer(trailLayer)
    }
    
    public func addPoint(_ point: CGPoint) {
        fadeTimer?.invalidate()
        self.layer.opacity = 1.0
        
        rawPoints.append(point)
        
        if rawPoints.count > KeyboardConstants.TRAIL_MAX_POINTS {
            rawPoints.removeFirst()
        }
        
        updateTrail()
    }
    
    public func clearTrail() {
        // Start fade out animation
        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: KeyboardConstants.TRAIL_FADE_DELAY_MS, repeats: false) { [weak self] _ in
            self?.fadeOut()
        }
    }
    
    private func fadeOut() {
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            self.rawPoints.removeAll()
            self.trailLayer.path = nil
            self.layer.opacity = 1.0 // Reset for next swipe
        }
        
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.0
        animation.duration = KeyboardConstants.TRAIL_FADE_DURATION_MS
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        self.layer.opacity = 0.0
        self.layer.add(animation, forKey: "fadeOut")
        
        CATransaction.commit()
    }
    
    private func updateTrail() {
        guard rawPoints.count > 1 else { return }
        
        let path = UIBezierPath()
        
        if KeyboardConstants.TRAIL_SMOOTHING_ENABLED {
            // Chaikin's Corner Cutting Algorithm for smoothing
            smoothedPoints = smoothPoints(rawPoints, iterations: 2)
            
            path.move(to: smoothedPoints.first!)
            for i in 1..<smoothedPoints.count {
                path.addLine(to: smoothedPoints[i])
            }
        } else {
            path.move(to: rawPoints.first!)
            for i in 1..<rawPoints.count {
                path.addLine(to: rawPoints[i])
            }
        }
        
        trailLayer.path = path.cgPath
    }
    
    private func smoothPoints(_ points: [CGPoint], iterations: Int) -> [CGPoint] {
        if points.count < 3 || iterations == 0 { return points }
        
        var newPoints = [CGPoint]()
        newPoints.append(points.first!)
        
        for i in 0..<(points.count - 1) {
            let p0 = points[i]
            let p1 = points[i+1]
            
            let q = CGPoint(x: 0.75 * p0.x + 0.25 * p1.x, y: 0.75 * p0.y + 0.25 * p1.y)
            let r = CGPoint(x: 0.25 * p0.x + 0.75 * p1.x, y: 0.25 * p0.y + 0.75 * p1.y)
            
            newPoints.append(q)
            newPoints.append(r)
        }
        newPoints.append(points.last!)
        
        return smoothPoints(newPoints, iterations: iterations - 1)
    }
}
