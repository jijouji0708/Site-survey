import UIKit

protocol MarkupToolbarDelegate: AnyObject {
    func didSelectTool(_ tool: MarkupTool)
    func didSelectColor(_ color: UIColor)
}

class MarkupToolbar: UIView {
    weak var delegate: MarkupToolbarDelegate?
    private var selectedTool: MarkupTool = .pen
    private var selectedColor: UIColor = .red
    
    private var toolButtons: [MarkupTool: UIButton] = [:]
    private var colorButtons: [UIButton] = []
    
    // Mapping button to color for equality check
    // Liquid Glass Indicators
    private let selectionIndicator = UIView()
    private weak var toolStackRef: UIStackView?
    
    private let colorSelectionIndicator = UIView()
    private weak var colorStackRef: UIStackView?
    
    // Mapping button to color for equality check
    private var buttonColors: [UIButton: UIColor] = [:]
    private var orderedTools: [MarkupTool] = []
    private var orderedColors: [UIColor] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setup() {
        backgroundColor = UIColor.black.withAlphaComponent(0.8)
        layer.cornerRadius = 20
        
        // Main VStack
        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = 10
        mainStack.distribution = .fillProportionally
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15)
        ])
        
        // 1. Tool Stack (Top)
        let toolStack = UIStackView()
        toolStack.axis = .horizontal
        toolStack.spacing = 15
        toolStack.distribution = .fillEqually
        mainStack.addArrangedSubview(toolStack)
        self.toolStackRef = toolStack
        
        // Setup Tool Indicator
        selectionIndicator.backgroundColor = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0) // Accent Green
        selectionIndicator.layer.cornerRadius = 8
        toolStack.addSubview(selectionIndicator)
        toolStack.sendSubviewToBack(selectionIndicator)
        
        // Add Pan Gesture for Tool Swipe Selection
        let toolPan = UIPanGestureRecognizer(target: self, action: #selector(handleToolPan(_:)))
        toolStack.addGestureRecognizer(toolPan)
        
        let tools: [(MarkupTool, String)] = [
            (.pen, "pencil"),
            (.marker, "highlighter"),
            (.eraser, "eraser"),
            (.text, "textformat"),
            (.arrow, "arrow.up.right"),
            (.rect, "rectangle"),
            (.circle, "circle")
        ]
        
        for (tool, icon) in tools {
            orderedTools.append(tool)
            let btn = UIButton()
            btn.setImage(UIImage(systemName: icon), for: .normal)
            btn.tintColor = .white
            btn.addAction(UIAction { [weak self] _ in self?.selectTool(tool) }, for: .touchUpInside)
            toolStack.addArrangedSubview(btn)
            toolButtons[tool] = btn
        }
        
        // Separator
        let separator = UIView()
        separator.backgroundColor = .gray
        separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        mainStack.addArrangedSubview(separator)
        
        // 2. Color Stack (Bottom)
        let colorContainer = UIScrollView()
        colorContainer.showsHorizontalScrollIndicator = false
        mainStack.addArrangedSubview(colorContainer)
        colorContainer.heightAnchor.constraint(equalToConstant: 34).isActive = true // Fixed height for colors
        
        let colorStack = UIStackView()
        colorStack.axis = .horizontal
        colorStack.spacing = 12
        colorStack.alignment = .center
        colorStack.translatesAutoresizingMaskIntoConstraints = false
        colorContainer.addSubview(colorStack)
        self.colorStackRef = colorStack
        
        NSLayoutConstraint.activate([
            colorStack.topAnchor.constraint(equalTo: colorContainer.topAnchor),
            colorStack.bottomAnchor.constraint(equalTo: colorContainer.bottomAnchor),
            colorStack.leadingAnchor.constraint(equalTo: colorContainer.leadingAnchor),
            colorStack.trailingAnchor.constraint(equalTo: colorContainer.trailingAnchor),
            colorStack.heightAnchor.constraint(equalTo: colorContainer.heightAnchor)
        ])
        
        // Setup Color Indicator
        colorSelectionIndicator.backgroundColor = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0) // Accent Green
        colorSelectionIndicator.layer.cornerRadius = 16 // Slightly larger than button radius (12) + padding
        colorStack.addSubview(colorSelectionIndicator)
        colorStack.sendSubviewToBack(colorSelectionIndicator)
        
        // Add Pan Gesture for Color Swipe Selection
        let colorPan = UIPanGestureRecognizer(target: self, action: #selector(handleColorPan(_:)))
        colorStack.addGestureRecognizer(colorPan)
        
        for color in MarkupColors.all {
            orderedColors.append(color)
            let btn = UIButton()
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.widthAnchor.constraint(equalToConstant: 24).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 24).isActive = true
            btn.backgroundColor = color
            btn.layer.cornerRadius = 12
            btn.layer.borderWidth = 1
            btn.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
            
            // For white/black visibility
            if color == MarkupColors.black {
                btn.layer.borderColor = UIColor.darkGray.cgColor
            }
            
            btn.addAction(UIAction { [weak self] _ in self?.selectColor(color) }, for: .touchUpInside)
            colorStack.addArrangedSubview(btn)
            colorButtons.append(btn)
            buttonColors[btn] = color
        }
        
        // Initial UI update needs lay out first ideally, but we call it to set colors
        updateUI(animated: false)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Update indicator position on layout change without animation
        updateSelectionIndicatorPosition(animated: false)
        updateColorSelectionIndicatorPosition(animated: false)
    }
    
    @objc private func handleToolPan(_ gesture: UIPanGestureRecognizer) {
        guard let toolStack = gesture.view else { return }
        let location = gesture.location(in: toolStack)
        let width = toolStack.bounds.width
        let count = CGFloat(orderedTools.count)
        
        guard width > 0, count > 0 else { return }
        
        // Calculate index
        let segmentWidth = width / count
        let index = Int(floor(location.x / segmentWidth))
        
        // Clamp index
        let clampedIndex = max(0, min(orderedTools.count - 1, index))
        let tool = orderedTools[clampedIndex]
        
        if tool != selectedTool {
            selectTool(tool)
            // Optional: Light haptic feedback
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }
    
    @objc private func handleColorPan(_ gesture: UIPanGestureRecognizer) {
        guard let colorStack = gesture.view else { return }
        let location = gesture.location(in: colorStack)
        
        // Note: For colors in a scrollable view or spaced stack, "segmentWidth" isn't uniform if we consider spacing.
        // However, colorStack is an internal UIStackView inside the ScrollView, so its width grows.
        // We can just find which button frame contains the touch x.
        
        // Find button closest to touch X
        // Optimization: Assume roughly equal width distribution or iterate buttons
        
        // Simple hit test logic for scrubbing:
        // Identify which button's horizontal range [minX, maxX] covers location.x
        
        if let btn = colorButtons.first(where: { btn in
            // Hit test with some margin
            let f = btn.frame
            return location.x >= f.minX - 6 && location.x <= f.maxX + 6
        }), let color = buttonColors[btn] {
            if color != selectedColor {
                selectColor(color)
                let generator = UISelectionFeedbackGenerator()
                generator.selectionChanged()
            }
        }
    }
    
    func selectTool(_ tool: MarkupTool) {
        selectedTool = tool
        delegate?.didSelectTool(tool)
        updateUI(animated: true)
    }
    
    func selectColor(_ color: UIColor) {
        selectedColor = color
        delegate?.didSelectColor(color)
        updateUI(animated: true)
    }
    
    private func updateUI(animated: Bool = true) {
        // Update Buttons Color
        for (t, b) in toolButtons {
            // Unselected are semi-transparent white, Selected is opaque white
            b.tintColor = (t == selectedTool) ? .white : UIColor.white.withAlphaComponent(0.5)
            // Scale effect on icon? Maybe slight
            b.transform = (t == selectedTool) ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
        }
        
        updateSelectionIndicatorPosition(animated: animated)
        updateColorSelectionIndicatorPosition(animated: animated)
        
        // Color buttons update
        for btn in colorButtons {
            guard let color = buttonColors[btn] else { continue }
            let isSelected = color == selectedColor
            
            // Selected color button style:
            // Since we have a green indicator behind, maybe we don't need a border ring anymore?
            // Or maybe keep it simple. User said "same way".
            // Let's keep the button itself clean.
            
            if isSelected {
                btn.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                btn.layer.borderColor = UIColor.white.cgColor
                btn.layer.borderWidth = 2
            } else {
                btn.transform = .identity
                btn.layer.borderWidth = 1
                btn.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
                
                if color == MarkupColors.black {
                    btn.layer.borderColor = UIColor.darkGray.cgColor
                }
            }
        }
    }
    
    private func updateSelectionIndicatorPosition(animated: Bool) {
        guard let btn = toolButtons[selectedTool], let toolStack = toolStackRef else { return }
        
        let targetFrame = btn.frame.insetBy(dx: -4, dy: -4)
        if targetFrame.width == 0 || targetFrame.height == 0 { return }
        
        let updates = {
            self.selectionIndicator.frame = targetFrame
            self.selectionIndicator.layer.cornerRadius = min(targetFrame.width, targetFrame.height) / 2
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.beginFromCurrentState, .allowUserInteraction], animations: updates)
        } else {
            updates()
        }
    }
    
    private func updateColorSelectionIndicatorPosition(animated: Bool) {
        // Find button for selected color
        guard let btn = colorButtons.first(where: { buttonColors[$0] == selectedColor }), let _ = colorStackRef else { return }
        
        // Indicator frame: slightly larger than button
        // Button is 24x24. Let's make indicator 32x32?
        
        let buttonFrame = btn.frame
        if buttonFrame.width == 0 { return }
        
        let size: CGFloat = 34
        let targetFrame = CGRect(
            x: buttonFrame.midX - size/2,
            y: buttonFrame.midY - size/2,
            width: size,
            height: size
        )
        
        let updates = {
            self.colorSelectionIndicator.frame = targetFrame
            self.colorSelectionIndicator.layer.cornerRadius = size / 2
        }
        
        if animated {
             UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.beginFromCurrentState, .allowUserInteraction], animations: updates)
        } else {
            updates()
        }
    }
}
