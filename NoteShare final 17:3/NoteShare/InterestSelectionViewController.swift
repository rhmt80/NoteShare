import UIKit
import AudioToolbox
import CoreMotion

// Color palette for a more cohesive design
fileprivate struct ColorTheme {
    // Primary color for selected bubbles - AI-like vibrant blue
    static let primary = UIColor(red: 0.0, green: 0.48, blue: 0.98, alpha: 1.0)
    
    // Secondary accent color for borders and highlights - brighter tech blue
    static let accent = UIColor(red: 0.32, green: 0.64, blue: 1.0, alpha: 1.0)
    
    // Continue button with bright AI blue
    static let continueButton = UIColor(red: 0.0, green: 0.48, blue: 0.98, alpha: 1.0)
    static let continueButtonText = UIColor.white
    
    // Background color - clean white with subtle blue hint
    static let background = UIColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1.0)
    
    // Modern gradient colors - tech-oriented gradients
    static let backgroundGradientStart = UIColor(red: 0.96, green: 0.98, blue: 1.0, alpha: 1.0)
    static let backgroundGradientEnd = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    
    // Bubble colors - pure white with blue border
    static let unselectedBubble = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    static let unselectedBorder = UIColor(red: 0.75, green: 0.85, blue: 0.98, alpha: 0.6)
    
    // Text colors - AI-like tech blue
    static let unselectedText = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
    static let selectedText = UIColor(red: 0.0, green: 0.48, blue: 0.98, alpha: 1.0)
    
    // Sparkle colors - AI tech-like sparkles
    static let sparkle1 = UIColor(red: 0.32, green: 0.64, blue: 1.0, alpha: 1.0)
    static let sparkle2 = UIColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0)
}

protocol InterestSelectionViewControllerDelegate: AnyObject {
    func interestSelectionViewController(_ viewController: InterestSelectionViewController, didSelectInterests interests: [String])
}

class InterestSelectionViewController: UIViewController, InterestBubbleDelegate {
    
    // MARK: - Properties
    
    var allInterests: [String] = []
    var selectedInterests = Set<String>()
    weak var delegate: InterestSelectionViewControllerDelegate?
    
    private var bubbles: [InterestBubble] = []
    private var animator: UIDynamicAnimator?
    private var collision: UICollisionBehavior?
    private var snapBehaviors: [UISnapBehavior] = []
    private var snapToBubbleMap: [UISnapBehavior: InterestBubble] = [:]
    private var itemBehavior: UIDynamicItemBehavior?
    private var attraction: [UIFieldBehavior] = []
    private let selectedScaleFactor: CGFloat = 1.15 // Reference for collision handler
    
    // Track long press for 3D pop effect
    private var activeBubble: InterestBubble?
    private var attractionTimer: Timer?
    
    // For device motion effects
    private var motionManager: CMMotionManager?
    private var motionDisplayLink: CADisplayLink?
    private var initialAttitude: CMAttitude?
    
    private var gradientLayer: CAGradientLayer?
    private var gradientColorAnimation: CABasicAnimation?
    private let particleEmitter = CAEmitterLayer()
    
    // Performance optimization
    private var lastRenderTime: TimeInterval = 0
    private var frameRateDivisor: Int = 2  // Only process every Nth frame
    private var frameCount: Int = 0
    
    // Add a property to track recent collisions to prevent duplicates
    private var recentCollisions: Set<String> = []
    private let collisionTimeout: TimeInterval = 0.5  // Prevent duplicate collision animations
    
    // MARK: - UI Components
    
    private let backgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let backgroundPatternView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0.1
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose your interests"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Select the topics you're interested in"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let continueButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Continue", for: .normal)
        button.setTitleColor(ColorTheme.continueButtonText, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.layer.cornerRadius = 28
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = false
        button.alpha = 0.5
        
        // Create a clean, matte finish
        button.backgroundColor = ColorTheme.continueButton
        
        // Add subtle shadow for depth
        button.layer.shadowColor = UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0).cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowRadius = 8
        button.layer.shadowOpacity = 0.15
        
        return button
    }()
    
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: "chevron.left")
        button.setImage(image, for: .normal)
        button.setTitle("Back", for: .normal)
        button.tintColor = ColorTheme.primary
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.semanticContentAttribute = .forceLeftToRight
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0)
        return button
    }()
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup UI components
        setupView()
        setupInterests()
        
        // Wait for view to be properly laid out before setting up bubbles
        // We'll set up physics in viewDidLayoutSubviews instead
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Initialize animator here where containerView has valid dimensions
        if animator == nil && containerView.bounds.width > 0 {
            animator = UIDynamicAnimator(referenceView: containerView)
            setupBubbles()
            
            // Short delay before animating bubbles
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.animateBubblesIn()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startGradientAnimation()
        startMotionUpdates()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopGradientAnimation()
        stopMotionUpdates()
    }
    
    // MARK: - Setup Methods
    
    private func setupView() {
        // Set background color to match reference image
        view.backgroundColor = ColorTheme.background
        
        // Setup container view - this is where the bubbles will appear
        containerView.backgroundColor = .clear
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Set up title label
        titleLabel.text = "Choose your interests"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Set up subtitle label
        subtitleLabel.text = "Select at least one to continue"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = .darkGray
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)
        
        // Set up back button
        backButton.setTitle("Back", for: .normal)
        backButton.setTitleColor(.darkGray, for: .normal)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        view.addSubview(backButton)
        
        // Set up continue button
        setupContinueButton()
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        view.addSubview(continueButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            
            // Constrain the container view to fill the space between title and continue button
            containerView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -20),
            
            // Make the continue button wider (80% of screen width)
            continueButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            continueButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            continueButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    private func setupContinueButton() {
        // Configure continue button
        continueButton.setTitle("Continue", for: .normal)
        continueButton.setTitleColor(ColorTheme.continueButtonText, for: .normal)
        continueButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        
        // Fully rounded corners (half the height)
        continueButton.layer.cornerRadius = 30
        
        // Add subtle shadow for depth without being too heavy
        continueButton.layer.shadowColor = UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0).cgColor
        continueButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        continueButton.layer.shadowRadius = 6
        continueButton.layer.shadowOpacity = 0.15
        
        // Initially disabled
        updateContinueButton()
    }
    
    private func setupInterests() {
        if allInterests.isEmpty {
            allInterests = [
                "Core Cse",
                "Web & App Development",
                "AIML",
                "Core ECE",
                "Core Mechanical",
                "Core Civil",
                "Core Electrical",
                "Physics",
                "Maths"
            ]
        }
    }
    
    private func setupBubbles() {
        // Clear any existing bubbles
        bubbles.forEach { $0.removeFromSuperview() }
        bubbles = []
        
        // Reset physics behaviors
        animator?.removeAllBehaviors()
        
        // Configure collision behavior
        collision = UICollisionBehavior(items: [])
        collision?.translatesReferenceBoundsIntoBoundary = true
        collision?.collisionDelegate = self
        animator?.addBehavior(collision!)
        
        // Configure physics properties for a more fluid feel
        itemBehavior = UIDynamicItemBehavior(items: [])
        itemBehavior?.elasticity = 0.92 // More bounce for fluid feel
        itemBehavior?.friction = 0.25   // Less friction for smoother movement
        itemBehavior?.resistance = 0.45 // Moderate resistance
        itemBehavior?.density = 0.55    // Lighter feel for more responsive movement
        itemBehavior?.allowsRotation = false
        animator?.addBehavior(itemBehavior!)
        
        snapBehaviors = []
        snapToBubbleMap = [:]
        attraction = []
        
        // Check that container view has a valid size
        guard containerView.bounds.width > 0 && containerView.bounds.height > 0 else {
            print("Container view has invalid size: \(containerView.bounds)")
            return
        }
        
        // Calculate dimensions - use larger base size to fill screen better
        let containerSize = containerView.bounds.size
        let baseSize: CGFloat = min(containerSize.width, containerSize.height) * 0.22 // Larger bubbles
        
        // Calculate how many average-sized bubbles would fit in the container
        let averageBubbleSize = baseSize * 1.0
        let containerArea = containerSize.width * containerSize.height
        let approxBubbleArea = .pi * pow(averageBubbleSize/2, 2)
        let desiredScreenCoverage: CGFloat = 0.65 // Aim to fill 65% of the screen
        _ = max(allInterests.count, Int((containerArea * desiredScreenCoverage) / approxBubbleArea)) // Use _ to avoid unused variable warning
        
        // Scale factor to ensure proper screen coverage based on interest count
        let scaleFactor = allInterests.count < 5 ? 1.3 : (allInterests.count < 8 ? 1.2 : 1.0)
        
        // Create bubbles for each interest with varied sizes based on text length
        for (index, interest) in allInterests.enumerated() {
            // Vary bubble size based on text length and importance
            let textLengthFactor = min(max(CGFloat(interest.count) / 12.0, 0.85), 1.3) 
            let importanceFactor = selectedInterests.contains(interest) ? 1.15 : 1.0
            let sizeVariation = textLengthFactor * importanceFactor * scaleFactor
            let bubbleSize = baseSize * sizeVariation
            
            let bubble = InterestBubble(frame: CGRect(x: 0, y: 0, width: bubbleSize, height: bubbleSize))
            bubble.configure(with: interest)
            bubble.index = index
            bubble.delegate = self
            bubble.isSelected = selectedInterests.contains(interest)
            
            // Start all bubbles at the center of the screen
            let centerX = containerSize.width / 2
            let centerY = containerSize.height / 2
            bubble.center = CGPoint(x: centerX, y: centerY)
            
            // Calculate positions using a Fibonacci spiral for more natural distribution
            // This creates a more organic, nature-inspired pattern
            let goldenRatio: CGFloat = 1.618033988749895
            let theta = CGFloat(index) * CGFloat.pi * 2 / goldenRatio
            
            // Calculate distance from center that ensures better screen coverage
            // Bubbles will spread more evenly from center to edges
            let maxDistanceToEdge = min(containerSize.width, containerSize.height) * 0.47 // Go closer to edges
            let normalizedIndex = CGFloat(index) / CGFloat(max(allInterests.count - 1, 1))
            let spiralRadius = sqrt(normalizedIndex) * maxDistanceToEdge // Square root for more even distribution
            
            // Add small random offset for more natural appearance
            let randomAngleOffset = CGFloat.random(in: -0.1...0.1)
            let randomDistanceOffset = CGFloat.random(in: 0.95...1.05)
            
            // Calculate position using spiral formula with improved distribution
            let finalAngle = theta + randomAngleOffset
            let finalRadius = spiralRadius * randomDistanceOffset
            
            let targetX = centerX + finalRadius * cos(finalAngle)
            let targetY = centerY + finalRadius * sin(finalAngle)
            
            // Ensure bubble stays within bounds of container
            let safeX = min(max(targetX, bubbleSize/2), containerSize.width - bubbleSize/2)
            let safeY = min(max(targetY, bubbleSize/2), containerSize.height - bubbleSize/2)
            
            bubble.startingCenter = CGPoint(x: safeX, y: safeY)
            
            bubble.alpha = 0 // Start invisible for animation
            bubble.transform = CGAffineTransform(scaleX: 0.3, y: 0.3) // Start smaller
            
            // Add tap gesture
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBubbleTap(_:)))
            bubble.addGestureRecognizer(tapGesture)
            
            // Add pan gesture for dragging bubbles
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleBubblePan(_:)))
            bubble.addGestureRecognizer(panGesture)
            
            containerView.addSubview(bubble)
            bubbles.append(bubble)
        }
        
        // Create modern subtle background gradient
        updateBackgroundBasedOnSelection()
        
        // Update continue button state based on initial selection
        updateContinueButton()
    }
    
    private func animateBubblesIn() {
        // Add a subtle scale animation to the background before bubbles appear
        let backgroundScale = CABasicAnimation(keyPath: "transform.scale")
        backgroundScale.fromValue = 1.05
        backgroundScale.toValue = 1.0
        backgroundScale.duration = 0.8
        backgroundScale.timingFunction = CAMediaTimingFunction(name: .easeOut)
        view.layer.add(backgroundScale, forKey: "subtle-scale")

        // Animate bubbles spreading out from center with staggered timing
        for (index, bubble) in bubbles.enumerated() {
            // Set initial state
            bubble.alpha = 0
            bubble.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            
            // Determine final scale based on selection state
            let finalScale: CGFloat = bubble.isSelected ? selectedScaleFactor : 1.0
            
            // Calculate delay based on spiral distance with improved timing
            let distanceFromCenter = sqrt(
                pow(bubble.startingCenter.x - containerView.bounds.width/2, 2) +
                pow(bubble.startingCenter.y - containerView.bounds.height/2, 2)
            )
            let normalizedDistance = distanceFromCenter / (containerView.bounds.width/2)
            
            // Modern staggered animation timing
            let baseDelay = 0.05 // Shorter initial delay for faster appearance
            let orderDelay = Double(index) * 0.018 // Shorter delay between items for quicker sequence
            let distanceDelay = Double(normalizedDistance) * 0.06 // Shorter distance delay for faster appearance
            let delay = baseDelay + orderDelay + distanceDelay
            
            // Animate with spring effect - improved parameters for more modern fluidity
            UIView.animate(
                withDuration: 0.7, // Slightly longer for more dramatic spring
                delay: delay,
                usingSpringWithDamping: 0.68, // Less damping for more bounce
                initialSpringVelocity: 0.5, // Higher velocity for more modern feel
                options: [],
                animations: {
                    bubble.alpha = 1.0
                    bubble.center = bubble.startingCenter
                    bubble.transform = CGAffineTransform(scaleX: finalScale, y: finalScale)
                },
                completion: { _ in
                    // Add bubble to physics system with a small delay to prevent initial collisions
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05 * Double(index % 3)) {
                        self.addBubbleToPhysics(bubble: bubble)
                    }
                }
            )
            
            // Add a small random initial velocity to each bubble for more natural motion
            if let itemBehavior = self.itemBehavior {
                let randomAngle = CGFloat.random(in: 0...(2 * .pi))
                let randomVelocity = CGFloat.random(in: 8...18)
                let velocityX = cos(randomAngle) * randomVelocity
                let velocityY = sin(randomAngle) * randomVelocity
                
                // Apply the velocity after a delay, when the bubble is added to physics
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.65) {
                    if bubble.superview != nil {
                        itemBehavior.addLinearVelocity(CGPoint(x: velocityX, y: velocityY), for: bubble)
                    }
                }
            }
        }
        
        // Fade in UI elements with modern sequential animation
        [titleLabel, subtitleLabel, backButton, continueButton].forEach { $0?.alpha = 0 }
        
        // Animate title with a slight slide-down
        titleLabel.transform = CGAffineTransform(translationX: 0, y: -15)
        UIView.animate(withDuration: 0.5, delay: 0.3, options: [.curveEaseOut], animations: { [self] in
            titleLabel.alpha = 1.0
            titleLabel.transform = .identity
        }, completion: nil)
        
        // Animate subtitle with a slight delay after title
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: -10)
        UIView.animate(withDuration: 0.5, delay: 0.4, options: [.curveEaseOut], animations: { [self] in
            subtitleLabel.alpha = 1.0
            subtitleLabel.transform = .identity
        }, completion: nil)
        
        // Animate back button from left
        backButton.transform = CGAffineTransform(translationX: -15, y: 0)
        UIView.animate(withDuration: 0.4, delay: 0.35, options: [.curveEaseOut], animations: { [self] in
            backButton.alpha = 1.0
            backButton.transform = .identity
        }, completion: nil)
        
        // Animate continue button from bottom
        continueButton.transform = CGAffineTransform(translationX: 0, y: 15)
        UIView.animate(withDuration: 0.5, delay: 0.45, options: [.curveEaseOut], animations: { [self] in
            continueButton.alpha = hasSelectedInterests ? 1.0 : 0.6
            continueButton.transform = .identity
        }, completion: nil)
    }
    
    // Add a new method to update background based on selection
    private func updateBackgroundBasedOnSelection() {
        // Remove existing background gradient if any
        view.layer.sublayers?.forEach { layer in
            if layer is CAGradientLayer {
                layer.removeFromSuperlayer()
            }
        }
        
        let gradient = CAGradientLayer()
        gradient.frame = view.bounds
        
        // Create gradient effect that responds to selection state
        if selectedInterests.isEmpty {
            // Default subtle gradient for no selection - soft sky blue look
            gradient.colors = [
                ColorTheme.backgroundGradientStart.cgColor,
                ColorTheme.backgroundGradientEnd.cgColor
            ]
            gradient.locations = [0.0, 1.0]
            gradient.startPoint = CGPoint(x: 0.0, y: 0.0) 
            gradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        } else {
            // Create a more vibrant gradient based on selected interests
            // More selections = more vibrant background
            let intensity = min(0.2, 0.05 + (CGFloat(selectedInterests.count) * 0.03))
            
            // Soft blue gradient that gets more intense with selections
            let primaryColor = ColorTheme.primary.withAlphaComponent(intensity).cgColor
            let accentColor = ColorTheme.accent.withAlphaComponent(intensity * 0.9).cgColor
            let bgStart = ColorTheme.backgroundGradientStart.cgColor
            let bgEnd = ColorTheme.backgroundGradientEnd.cgColor
            
            // More modern gradient with multiple color stops and subtle blue tints
            gradient.colors = [bgStart, accentColor, primaryColor, bgEnd]
            gradient.locations = [0.0, 0.35, 0.65, 1.0]
            gradient.startPoint = CGPoint(x: 0.0, y: 0.0)
            gradient.endPoint = CGPoint(x: 1.0, y: 1.0)
            
            // Add subtle animation to the gradient for a more lively feel
            let animation = CABasicAnimation(keyPath: "locations")
            animation.fromValue = [0.0, 0.35, 0.65, 1.0]
            animation.toValue = [0.0, 0.4, 0.6, 1.0]
            animation.duration = 3.5
            animation.autoreverses = true
            animation.repeatCount = Float.infinity
            gradient.add(animation, forKey: "gradientAnimation")
        }
        
        // Add gradient behind other views
        view.layer.insertSublayer(gradient, at: 0)
    }
    
    // MARK: - Particle Effects
    
    func emitParticles(at position: CGPoint, color: UIColor, count: Int = 14, velocity: CGFloat = 70) {
        // Create particles for AI-themed sparkle effect
        for _ in 0..<count {
            // Use different particle styles for visual interest
            let particleStyle = Int.random(in: 0...4)
            let particleSize = CGFloat.random(in: 4.0...9.0) // Larger particles for more impact
            
            let particleView = UIView(frame: CGRect(x: 0, y: 0, width: particleSize, height: particleSize))
            
            // Use AI-themed color palette for particles
            let baseColor: UIColor
            let randomValue = Int.random(in: 0...10)
            if randomValue < 5 { // 50% chance of bright tech blue particles
                // Vibrant AI blue with varying opacity
                baseColor = ColorTheme.primary.withAlphaComponent(CGFloat.random(in: 0.8...1.0))
            } else if randomValue < 8 { // 30% chance of light blue
                // Light tech blue
                baseColor = ColorTheme.sparkle2
            } else { // 20% chance of white particles
                // Pure white for contrast
                baseColor = UIColor(white: 1.0, alpha: 1.0)
            }
            
            // Add a slight color variation for visual interest
            let hue = CGFloat.random(in: -0.05...0.05)
            let brightness = CGFloat.random(in: 0.0...0.15)
            let randomizedColor = baseColor.adjustHue(by: hue, brightness: brightness)
            particleView.backgroundColor = randomizedColor
            
            // Randomize particle shape - more varied for tech sparkle effect
            switch particleStyle {
            case 0: // Circle
                particleView.layer.cornerRadius = particleSize / 2
            case 1: // Square with rounded corners
                particleView.layer.cornerRadius = particleSize / 4
            case 2: // Star-like shape
                let maskLayer = CAShapeLayer()
                let path = starPath(in: CGRect(x: 0, y: 0, width: particleSize, height: particleSize))
                maskLayer.path = path.cgPath
                particleView.layer.mask = maskLayer
            case 3: // Diamond shape
                let maskLayer = CAShapeLayer()
                let path = UIBezierPath()
                path.move(to: CGPoint(x: particleSize/2, y: 0))
                path.addLine(to: CGPoint(x: particleSize, y: particleSize/2))
                path.addLine(to: CGPoint(x: particleSize/2, y: particleSize))
                path.addLine(to: CGPoint(x: 0, y: particleSize/2))
                path.close()
                maskLayer.path = path.cgPath
                particleView.layer.mask = maskLayer
            case 4: // Thin line for sparkle streaks
                particleView.frame = CGRect(x: 0, y: 0, width: particleSize * 2.0, height: particleSize / 3)
                particleView.layer.cornerRadius = particleSize / 6
                particleView.transform = CGAffineTransform(rotationAngle: CGFloat.random(in: 0...(2 * .pi)))
            default:
                particleView.layer.cornerRadius = particleSize / 2
            }
            
            // Add enhanced glow effect for more sparkle - AI-like glow
            particleView.layer.shadowColor = ColorTheme.primary.cgColor
            particleView.layer.shadowRadius = 3.0
            particleView.layer.shadowOpacity = 0.8
            particleView.layer.shadowOffset = .zero
            particleView.layer.masksToBounds = false
            
            particleView.center = position
            containerView.addSubview(particleView)
            
            // Random angle for particle movement
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let minDistance: CGFloat = 50
            let maxDistance = max(minDistance, velocity)
            let distance = CGFloat.random(in: minDistance...maxDistance)
            
            // Calculate end position
            let endX = position.x + distance * cos(angle)
            let endY = position.y + distance * sin(angle)
            
            // Randomize animation duration for more natural movement
            let duration = Double.random(in: 0.4...1.0)
            
            // Add a slight delay to some particles for a cascading effect
            let delay = Double.random(in: 0...0.1)
            
            // Animate the particle with tech-like motion
            UIView.animate(withDuration: duration, delay: delay, options: [.curveEaseOut], animations: {
                particleView.center = CGPoint(x: endX, y: endY)
                particleView.alpha = 0
                
                // Add rotation and variable scaling for sparkle effect
                let scale = CGFloat.random(in: 0.05...0.3)
                let rotation = CGFloat.random(in: -1.5...1.5) * .pi
                particleView.transform = CGAffineTransform(scaleX: scale, y: scale).rotated(by: rotation)
                
                // Pulse brightness with higher opacity during animation for more sparkle
                particleView.layer.shadowOpacity = Float(CGFloat.random(in: 0.0...0.7))
            }, completion: { _ in
                particleView.removeFromSuperview()
            })
        }
    }
    
    private func starPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let radius = min(rect.width, rect.height) / 2
        let points = 5
        
        for i in 0..<points * 2 {
            let angle = CGFloat(i) * .pi / CGFloat(points)
            let pointRadius = i % 2 == 0 ? radius : radius * 0.4
            let x = center.x + pointRadius * cos(angle)
            let y = center.y + pointRadius * sin(angle)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.close()
        return path
    }
    
    private func createComplementaryColor(for color: UIColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // Create a simple complementary color
        return UIColor(red: 1.0 - r, green: 1.0 - g, blue: 1.0 - b, alpha: a)
    }
    
    // MARK: - Actions
    
    @objc private func backButtonTapped() {
        animateOut {
            self.navigationController?.popViewController(animated: false)
        }
    }
    
    @objc private func continueButtonTapped() {
        delegate?.interestSelectionViewController(self, didSelectInterests: Array(selectedInterests))
        
        // Animate bubbles out before dismissing
        animateOut {
            self.navigationController?.popViewController(animated: false)
        }
    }
    
    private func animateOut(completion: @escaping () -> Void) {
        // Simple fade out animation
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [],
            animations: {
                [self.titleLabel, self.subtitleLabel, self.backButton, self.continueButton].forEach { $0?.alpha = 0 }
                self.bubbles.forEach { $0.alpha = 0 }
            },
            completion: { _ in
                completion()
            }
        )
    }
    
    private func updateContinueButton() {
        let hasSelectedInterests = !selectedInterests.isEmpty
        continueButton.isEnabled = hasSelectedInterests
        
        // Update button appearance with animation
        UIView.animate(withDuration: 0.3) { [self] in
            if hasSelectedInterests {
                // Enabled state - full color
                continueButton.backgroundColor = ColorTheme.continueButton
                continueButton.alpha = 1.0
                continueButton.layer.shadowOpacity = 0.15
            } else {
                // Disabled state - faded color
                continueButton.backgroundColor = ColorTheme.continueButton.withAlphaComponent(0.7)
                continueButton.alpha = 0.8
                continueButton.layer.shadowOpacity = 0.05
            }
        }
        
        // Apply a subtle pulse animation if enabled
        if hasSelectedInterests {
            addPulseAnimationToContinueButton()
        } else {
            removePulseAnimationFromContinueButton()
        }
    }
    
    private func addPulseAnimationToContinueButton() {
        // Remove any existing animation
        continueButton.layer.removeAnimation(forKey: "pulseAnimation")
        
        // Create a subtle pulse animation
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.03
        pulseAnimation.duration = 1.0
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = Float.infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        continueButton.layer.add(pulseAnimation, forKey: "pulseAnimation")
    }
    
    private func removePulseAnimationFromContinueButton() {
        continueButton.layer.removeAnimation(forKey: "pulseAnimation")
    }
    
    // MARK: - Motion Effects
    
    private func setupMotionEffects() {
        // Implementation of setupMotionEffects method
    }
    
    private func startMotionUpdates() {
        // Simple implementation that doesn't do anything yet
        // We're just implementing it to avoid errors
    }
    
    private func stopMotionUpdates() {
        // Simple implementation that doesn't do anything yet
        // We're just implementing it to avoid errors
    }
    
    @objc private func handleMotionUpdate() {
        // Implementation of handleMotionUpdate method
    }
    
    // MARK: - Animation Performance Optimizations
    
    private func throttle(block: @escaping () -> Void) {
        // Implementation of throttle method
    }
    
    // Add after viewDidAppear but before setupView method
    private func startGradientAnimation() {
        // Simple implementation - since we have a simplified UI now, this is just a placeholder
        // We could re-implement gradient effects here if needed later
    }
    
    private func stopGradientAnimation() {
        // Simple implementation - since we have a simplified UI now, this is just a placeholder
        // We could stop any gradient animations here if implemented later
    }
    
    // Add after animateOut method but before updateContinueButton method
    @objc private func handleBubbleTap(_ gesture: UITapGestureRecognizer) {
        guard let bubble = gesture.view as? InterestBubble else { return }
        bubble.handleTap()
    }
    
    // MARK: - Physics Behavior Methods
    
    private func addBubbleToPhysics(bubble: InterestBubble) {
        // Add collision and dynamic behaviors
        collision?.addItem(bubble)
        itemBehavior?.addItem(bubble)
        
        // Create and add snap behavior with random initial point
        let randomOffset = CGPoint(
            x: CGFloat.random(in: -20...20),
            y: CGFloat.random(in: -20...20)
        )
        
        let snapPoint = CGPoint(
            x: bubble.center.x + randomOffset.x,
            y: bubble.center.y + randomOffset.y
        )
        
        let snapBehavior = UISnapBehavior(item: bubble, snapTo: snapPoint)
        
        // Set damping based on whether bubble is selected
        if bubble.isSelected {
            snapBehavior.damping = 0.4  // More responsive for selected bubbles
        } else {
            snapBehavior.damping = 0.7  // More gentle floating for unselected bubbles
        }
        
        // Store the snap behavior for this bubble
        snapToBubbleMap[snapBehavior] = bubble
        
        // Add to animator
        animator?.addBehavior(snapBehavior)
    }
    
    @objc private func handleBubblePan(_ gesture: UIPanGestureRecognizer) {
        guard let bubble = gesture.view as? InterestBubble else { return }
        
        switch gesture.state {
        case .began:
            // Remove existing snap behavior for this bubble
            for (snap, mappedBubble) in snapToBubbleMap {
                if mappedBubble == bubble {
                    animator?.removeBehavior(snap)
                    snapToBubbleMap.removeValue(forKey: snap)
                    break
                }
            }
            
            // Temporarily disable collision during drag
            collision?.removeItem(bubble)
            
        case .changed:
            // Update bubble position
            let translation = gesture.translation(in: view)
            bubble.center = CGPoint(
                x: bubble.center.x + translation.x,
                y: bubble.center.y + translation.y
            )
            gesture.setTranslation(.zero, in: view)
            
        case .ended, .cancelled:
            // Re-enable collision
            collision?.addItem(bubble)
            
            // Create new snap behavior to current position
            let snapBehavior = UISnapBehavior(item: bubble, snapTo: bubble.center)
            
            // Set damping based on whether bubble is selected
            if bubble.isSelected {
                snapBehavior.damping = 0.4
            } else {
                snapBehavior.damping = 0.7
            }
            
            // Store and add the new snap behavior
            snapToBubbleMap[snapBehavior] = bubble
            animator?.addBehavior(snapBehavior)
            
            // Add some random velocity for more natural movement
            let push = UIPushBehavior(items: [bubble], mode: .instantaneous)
            push.magnitude = 0.5
            push.angle = CGFloat.random(in: 0...(2 * .pi))
            animator?.addBehavior(push)
            
            // Remove push behavior after it's applied
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.animator?.removeBehavior(push)
            }
            
        default:
            break
        }
    }
    
    // MARK: - InterestBubbleDelegate
    
    func interestBubbleDidToggle(_ bubble: InterestBubble, isSelected: Bool) {
        guard let index = bubbles.firstIndex(where: { $0 === bubble }),
              index < allInterests.count,
              let animator = self.animator else { return }
        
        let interest = allInterests[index]
        
        if isSelected {
            selectedInterests.insert(interest)
        } else {
            selectedInterests.remove(interest)
        }
        
        updateContinueButton()
        
        // Update snap behavior for toggled bubble
        for (snap, mappedBubble) in snapToBubbleMap {
            if mappedBubble == bubble {
                animator.removeBehavior(snap)
                snapToBubbleMap.removeValue(forKey: snap)
                
                let newSnap = UISnapBehavior(item: bubble, snapTo: bubble.center)
                
                // Adjust damping based on selection state
                if bubble.isSelected {
                    newSnap.damping = 0.4  // More responsive for selected bubbles
                } else {
                    newSnap.damping = 0.7  // More gentle floating for unselected
                }
                
                snapToBubbleMap[newSnap] = bubble
                animator.addBehavior(newSnap)
                break
            }
        }
    }
}

// MARK: - InterestBubble Protocol

protocol InterestBubbleDelegate: AnyObject {
    func interestBubbleDidToggle(_ bubble: InterestBubble, isSelected: Bool)
}

// MARK: - InterestBubble Class

class InterestBubble: UIView {
    
    // MARK: - Properties
    
    private let titleLabel = UILabel()
    private let innerCircleView = UIView()
    private let borderLayer = CAShapeLayer()
    private let glowLayer = CALayer()
    private let shineMaskLayer = CAShapeLayer() // New shine effect
    
    var startingCenter: CGPoint = .zero
    var isSelected: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    var delegate: InterestBubbleDelegate?
    var index: Int = 0
    private let selectedScaleFactor: CGFloat = 1.15 // Slightly reduced scale factor
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // Main bubble container view
        backgroundColor = .clear
        layer.cornerRadius = bounds.width / 2
        clipsToBounds = false
        
        // Add glow layer for selected state - more vibrant modern glow
        glowLayer.frame = bounds.insetBy(dx: -10, dy: -10)
        glowLayer.backgroundColor = ColorTheme.primary.withAlphaComponent(0.0).cgColor
        glowLayer.cornerRadius = glowLayer.frame.width / 2
        glowLayer.shadowColor = ColorTheme.primary.cgColor
        glowLayer.shadowOffset = .zero
        glowLayer.shadowOpacity = 0
        glowLayer.shadowRadius = 15 // Larger glow radius
        layer.insertSublayer(glowLayer, at: 0)
        
        // Inner circle view (the actual bubble)
        innerCircleView.frame = bounds
        innerCircleView.backgroundColor = ColorTheme.unselectedBubble
        innerCircleView.layer.cornerRadius = bounds.width / 2
        innerCircleView.clipsToBounds = true
        
        // Add subtle gradient overlay to inner circle for more dimension
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds
        gradientLayer.colors = [
            UIColor.white.withAlphaComponent(0.5).cgColor,
            UIColor.white.withAlphaComponent(0.2).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        gradientLayer.cornerRadius = bounds.width / 2
        innerCircleView.layer.addSublayer(gradientLayer)
        
        addSubview(innerCircleView)
        
        // Add shine effect to bubble (subtle reflection)
        let shineLayer = CAGradientLayer()
        shineLayer.frame = bounds
        shineLayer.colors = [
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor.white.withAlphaComponent(0.4).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        shineLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        shineLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        shineLayer.locations = [0.0, 0.5, 1.0]
        
        // Mask shine layer to a quarter circle in top-left
        shineMaskLayer.frame = bounds
        let shinePath = UIBezierPath(arcCenter: CGPoint(x: bounds.width/2, y: bounds.height/2),
                                 radius: bounds.width/2,
                                 startAngle: .pi,
                                 endAngle: 1.75 * .pi,
                                 clockwise: true)
        shineMaskLayer.path = shinePath.cgPath
        shineMaskLayer.fillColor = UIColor.black.cgColor
        shineLayer.mask = shineMaskLayer
        innerCircleView.layer.addSublayer(shineLayer)
        
        // Add border with more modern appearance - thicker and more visible
        borderLayer.frame = bounds
        borderLayer.fillColor = nil
        borderLayer.strokeColor = ColorTheme.unselectedBorder.cgColor
        borderLayer.lineWidth = 2.0 // Thicker border
        borderLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 1.0, dy: 1.0)).cgPath
        innerCircleView.layer.addSublayer(borderLayer)
        
        // Add shadow for modern depth - softer, more spread out shadow
        layer.shadowColor = UIColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.15).cgColor
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.4
        layer.masksToBounds = false
        
        // Title label with modern typography
        titleLabel.frame = bounds
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold) // More bold font weight
        titleLabel.textColor = ColorTheme.unselectedText
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        titleLabel.numberOfLines = 2
        innerCircleView.addSubview(titleLabel)
        
        // Center the label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: innerCircleView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: innerCircleView.centerYAnchor),
            titleLabel.widthAnchor.constraint(equalTo: innerCircleView.widthAnchor, multiplier: 0.85),
            titleLabel.heightAnchor.constraint(equalTo: innerCircleView.heightAnchor, multiplier: 0.85)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        innerCircleView.frame = bounds
        innerCircleView.layer.cornerRadius = bounds.width / 2
        
        glowLayer.frame = bounds.insetBy(dx: -10, dy: -10)
        glowLayer.cornerRadius = glowLayer.frame.width / 2
        
        borderLayer.frame = bounds
        borderLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 1.0, dy: 1.0)).cgPath
    }
    
    func configure(with title: String) {
        titleLabel.text = title
    }
    
    func handleTap() {
        // Toggle selection state
        isSelected.toggle()
        
        // Create ripple effect with improved visuals
        createRippleEffect()
        
        // Main animation for selection state change - more modern animation
        let duration = 0.4
        let scaleTransform = isSelected ? CGAffineTransform(scaleX: selectedScaleFactor, y: selectedScaleFactor) : .identity
        
        // First quick "punch" animation with modern values
        UIView.animate(withDuration: 0.12, // Faster for more responsive feel
                      animations: { [self] in
            transform = isSelected ? 
                CGAffineTransform(scaleX: selectedScaleFactor * 1.12, y: selectedScaleFactor * 1.12) : // More exaggerated initial scale
                CGAffineTransform(scaleX: 0.9, y: 0.9) // Slightly more pronounced for feedback
        }) { _ in
            // Then animate to final state with spring effect - modern elastic feeling
            UIView.animate(withDuration: duration, 
                           delay: 0, 
                           usingSpringWithDamping: 0.65,  // Less damping for more bounce
                           initialSpringVelocity: 0.4,   // Higher velocity for more snap
                           options: [.allowUserInteraction, .curveEaseOut], 
                           animations: { [self] in
                transform = scaleTransform
                updateAppearance()
            })
        }
        
        // Provide haptic feedback - stronger for better physical feel
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = 
            isSelected ? .medium : .light // Different feedback based on state
        let feedbackGenerator = UIImpactFeedbackGenerator(style: feedbackStyle)
        feedbackGenerator.prepare()
        feedbackGenerator.impactOccurred()
        
        // Emit particles for visual feedback
        if let superview = self.superview {
            let emitPosition = convert(center, to: superview)
            let color = isSelected ? ColorTheme.primary : ColorTheme.unselectedBorder
            
            if let selectionVC = delegate as? InterestSelectionViewController {
                selectionVC.emitParticles(at: emitPosition, 
                                         color: color, 
                                         count: isSelected ? 8 : 4, // More particles when selecting
                                         velocity: isSelected ? 40 : 25) // Faster particles when selecting
            }
        }
        
        // Notify delegate
        delegate?.interestBubbleDidToggle(self, isSelected: isSelected)
    }
    
    private func createRippleEffect() {
        // Create a ripple layer
        let rippleLayer = CAShapeLayer()
        rippleLayer.frame = bounds
        rippleLayer.path = UIBezierPath(ovalIn: bounds).cgPath
        rippleLayer.fillColor = nil
        rippleLayer.strokeColor = isSelected ? ColorTheme.primary.cgColor : ColorTheme.accent.cgColor
        rippleLayer.lineWidth = 2
        rippleLayer.opacity = 0.8
        
        // Add to our view
        layer.addSublayer(rippleLayer)
        
        // Create animations
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 1.5
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.8
        opacityAnimation.toValue = 0
        
        // Combine animations
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [scaleAnimation, opacityAnimation]
        animationGroup.duration = 0.6
        animationGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animationGroup.isRemovedOnCompletion = true
        
        // Add animation and remove layer when done
        rippleLayer.add(animationGroup, forKey: "rippleEffect")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            rippleLayer.removeFromSuperlayer()
        }
    }
    
    private func updateAppearance() {
        if isSelected {
            // Selected state - AI theme with transparent background and vibrant elements
            innerCircleView.backgroundColor = UIColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 0.75) // More transparent for AI look
            
            // Text in bright AI blue
            titleLabel.textColor = ColorTheme.primary
            titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            
            // Animate to a thicker, more vibrant AI blue border
            let borderColorAnimation = CABasicAnimation(keyPath: "strokeColor")
            borderColorAnimation.fromValue = borderLayer.strokeColor
            borderColorAnimation.toValue = ColorTheme.primary.cgColor
            borderColorAnimation.duration = 0.3
            borderLayer.add(borderColorAnimation, forKey: "borderColor")
            borderLayer.strokeColor = ColorTheme.primary.cgColor
            borderLayer.lineWidth = 3.5 // Thicker for AI tech look
            
            // Enhanced tech glow effect with animation
            let glowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
            glowAnimation.fromValue = glowLayer.shadowOpacity
            glowAnimation.toValue = 0.85 // Increased opacity for more visible AI glow
            glowAnimation.duration = 0.3
            glowLayer.add(glowAnimation, forKey: "shadowOpacity")
            glowLayer.shadowOpacity = 0.85
            glowLayer.shadowRadius = 15
            glowLayer.shadowColor = ColorTheme.primary.cgColor
            
            // Tech-like shadow for more dramatic depth
            layer.shadowColor = ColorTheme.primary.withAlphaComponent(0.6).cgColor
            layer.shadowOpacity = 0.55
            layer.shadowRadius = 12
            layer.shadowOffset = CGSize(width: 0, height: 5)
            
            // Apply scale transform with smoother animation for tech feel
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.4, options: .curveEaseOut, animations: {
                self.transform = CGAffineTransform(scaleX: self.selectedScaleFactor, y: self.selectedScaleFactor)
            })
        } else {
            // Unselected state - clean white bubble for AI theme contrast
            innerCircleView.backgroundColor = ColorTheme.unselectedBubble
            
            // AI-themed text color
            titleLabel.textColor = ColorTheme.unselectedText
            titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            
            // Animate to AI-styled subtle border
            let borderColorAnimation = CABasicAnimation(keyPath: "strokeColor")
            borderColorAnimation.fromValue = borderLayer.strokeColor
            borderColorAnimation.toValue = ColorTheme.unselectedBorder.cgColor
            borderColorAnimation.duration = 0.3
            borderLayer.add(borderColorAnimation, forKey: "borderColor")
            borderLayer.strokeColor = ColorTheme.unselectedBorder.cgColor
            borderLayer.lineWidth = 1.5
            
            // Remove glow with animation
            let glowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
            glowAnimation.fromValue = glowLayer.shadowOpacity
            glowAnimation.toValue = 0
            glowAnimation.duration = 0.3
            glowLayer.add(glowAnimation, forKey: "shadowOpacity")
            glowLayer.shadowOpacity = 0
            
            // Subtle tech shadow
            layer.shadowColor = UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 0.15).cgColor
            layer.shadowOpacity = 0.25
            layer.shadowRadius = 6
            layer.shadowOffset = CGSize(width: 0, height: 2)
            
            // Animate back to normal size with tech spring effect
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3, options: .curveEaseOut, animations: {
                self.transform = CGAffineTransform.identity
            })
        }
    }
    
    // Public methods for compatibility
    func startAnimation() {
        // Now handled by physics system, no longer needed
    }
    
    func stopAnimation() {
        // Now handled by physics system, no longer needed
    }
}

// MARK: - UICollisionBehaviorDelegate

extension InterestSelectionViewController: UICollisionBehaviorDelegate {
    func collisionBehavior(_ behavior: UICollisionBehavior, beganContactFor item1: UIDynamicItem, with item2: UIDynamicItem, at p: CGPoint) {
        guard let bubble1 = item1 as? InterestBubble,
              let bubble2 = item2 as? InterestBubble else { return }
        
        // Create a collision ID to track recent collisions
        let id1 = ObjectIdentifier(bubble1).hashValue
        let id2 = ObjectIdentifier(bubble2).hashValue
        let collisionId = "\(min(id1, id2))-\(max(id1, id2))"
        
        // Skip if this collision was recently processed
        if recentCollisions.contains(collisionId) {
            return
        }
        
        // Add to recent collisions and schedule removal
        recentCollisions.insert(collisionId)
        DispatchQueue.main.asyncAfter(deadline: .now() + collisionTimeout) { [weak self] in
            self?.recentCollisions.remove(collisionId)
        }
        
        // Create a more interesting collision effect with AI-themed particles
        let color1 = bubble1.isSelected ? ColorTheme.primary : UIColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 0.95)
        let color2 = bubble2.isSelected ? ColorTheme.primary : UIColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 0.95)
        
        // Blend the colors for particles
        let blendedColor = blendColors(color1, color2, ratio: 0.5)
        
        // More dynamic particle effect - increase count for AI theme
        let particleCount = bubble1.isSelected || bubble2.isSelected ? 12 : 8
        let velocity = bubble1.isSelected || bubble2.isSelected ? 45.0 : 35.0
        emitParticles(at: p, color: blendedColor, count: particleCount, velocity: velocity)
        
        // Enhanced haptic feedback for collision
        if bubble1.isSelected || bubble2.isSelected {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred(intensity: 0.6) // Stronger feedback for AI theme
        }
        
        // More dynamic animation with AI-themed pulsing
        UIView.animate(withDuration: 0.1, 
                      delay: 0, 
                      options: [.allowUserInteraction, .curveEaseOut], 
                      animations: {
            // Pulse effect - slightly larger for AI theme
            let scale: CGFloat = bubble1.isSelected || bubble2.isSelected ? 1.08 : 1.05
            bubble1.transform = bubble1.transform.scaledBy(x: scale, y: scale)
            bubble2.transform = bubble2.transform.scaledBy(x: scale, y: scale)
        }) { _ in
            UIView.animate(withDuration: 0.3, 
                          delay: 0,
                          usingSpringWithDamping: 0.6, 
                          initialSpringVelocity: 0.3, // Higher velocity for snappier AI feel
                          options: [.allowUserInteraction, .curveEaseOut], 
                          animations: {
                // Return to original size with spring effect
                if bubble1.isSelected {
                    bubble1.transform = CGAffineTransform(scaleX: self.selectedScaleFactor, y: self.selectedScaleFactor)
                } else {
                    bubble1.transform = .identity
                }
                
                if bubble2.isSelected {
                    bubble2.transform = CGAffineTransform(scaleX: self.selectedScaleFactor, y: self.selectedScaleFactor)
                } else {
                    bubble2.transform = .identity
                }
            }, completion: nil)
        }
    }
    
    // Helper method to blend two colors
    private func blendColors(_ color1: UIColor, _ color2: UIColor, ratio: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = r1 * (1 - ratio) + r2 * ratio
        let g = g1 * (1 - ratio) + g2 * ratio
        let b = b1 * (1 - ratio) + b2 * ratio
        let a = a1 * (1 - ratio) + a2 * ratio
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - UIColor Extension

extension UIColor {
    func adjustHue(by hueDelta: CGFloat, brightness: CGFloat = 0) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }
        
        // Adjust hue, keeping it in the 0...1 range
        hue = (hue + hueDelta).truncatingRemainder(dividingBy: 1.0)
        if hue < 0 { hue += 1 }
        
        // Adjust brightness, clamping to 0...1 range
        brightness = max(0, min(1, brightness + brightness))
        
        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    }
}

// Fix the hasSelectedInterests property to be in the correct scope
extension InterestSelectionViewController {
    // Computed property for cleaner code
    private var hasSelectedInterests: Bool {
        return !selectedInterests.isEmpty
    }
}   

#Preview(){
    InterestSelectionViewController()
}
