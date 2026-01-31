import UIKit

protocol MarkupToolbarDelegate: AnyObject {
    func didSelectTool(_ tool: MarkupTool)
    func didSelectColor(_ color: UIColor)
    func didSelectTextSize(_ size: CGFloat)
    func didSelectArrowStyle(_ style: ArrowStyle)
    func didSelectMarkerWidth(_ width: CGFloat)
}

class MarkupToolbar: UIView {
    weak var delegate: MarkupToolbarDelegate?
    private var selectedTool: MarkupTool = .pen
    private var selectedColor: UIColor = MarkupColors.red
    
    private var toolButtons: [MarkupTool: UIButton] = [:]
    private var colorButtons: [UIButton] = []
    
    // Mapping button to color for equality check
    private var buttonColors: [UIButton: UIColor] = [:]
    private var orderedTools: [MarkupTool] = []
    private var orderedColors: [UIColor] = []
    
    // Text Size
    private var selectedTextSize: CGFloat = 16 // Default: Small
    private var orderedTextSizes: [CGFloat] = [16, 24] // Small, Large
    private var textSizeButtons: [UIButton] = []
    
    // Arrow Style
    private var selectedArrowStyle: ArrowStyle = .oneWay
    private var orderedArrowStyles: [ArrowStyle] = [.oneWay, .twoWay, .line]
    private var arrowStyleButtons: [UIButton] = []
    
    // Marker Width
    private var selectedMarkerWidth: CGFloat = 20 // Default: Thin
    private var orderedMarkerWidths: [CGFloat] = [20, 40] // Thin, Thick
    private var markerWidthButtons: [UIButton] = []
    
    // Liquid Glass Indicators
    private let selectionIndicator = UIView()
    private weak var toolStackRef: UIStackView?
    
    private let colorSelectionIndicator = UIView()
    private weak var colorStackRef: UIStackView?
    
    private let textSizeSelectionIndicator = UIView()
    private weak var textSizeStackRef: UIStackView?
    
    private let arrowStyleSelectionIndicator = UIView()
    private weak var arrowStyleStackRef: UIStackView?
    
    private let markerWidthSelectionIndicator = UIView()
    private weak var markerWidthStackRef: UIStackView?
    
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
        
        // 0. Text Size Stack (Hidden by default, Top)
        let textSizeStack = UIStackView()
        textSizeStack.axis = .horizontal
        textSizeStack.spacing = 20
        textSizeStack.distribution = .fillEqually
        textSizeStack.isHidden = true // Default hidden
        textSizeStack.alpha = 0
        mainStack.addArrangedSubview(textSizeStack)
        self.textSizeStackRef = textSizeStack
        
        // Setup Text Size Indicator
        textSizeSelectionIndicator.backgroundColor = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0) // Accent Green
        textSizeSelectionIndicator.layer.cornerRadius = 8
        textSizeStack.addSubview(textSizeSelectionIndicator)
        textSizeStack.sendSubviewToBack(textSizeSelectionIndicator)
        
        // Add Pan Gesture for Text Size
        let sizePan = UIPanGestureRecognizer(target: self, action: #selector(handleTextSizePan(_:)))
        textSizeStack.addGestureRecognizer(sizePan)
        
        let sizes: [(CGFloat, String)] = [ (16, "textformat.size.smaller"), (24, "textformat.size.larger") ]
        for (size, iconName) in sizes {
            let btn = UIButton()
            btn.setImage(UIImage(systemName: iconName), for: .normal)
            btn.tintColor = .white
            btn.addAction(UIAction { [weak self] _ in self?.selectTextSize(size) }, for: .touchUpInside)
            textSizeStack.addArrangedSubview(btn)
            textSizeButtons.append(btn)
        }
        
        
        // 0.5. Arrow Style Stack (Hidden by default, Top, sibling to TextSize)
        let arrowStyleStack = UIStackView()
        arrowStyleStack.axis = .horizontal
        arrowStyleStack.spacing = 20
        arrowStyleStack.distribution = .fillEqually
        arrowStyleStack.isHidden = true
        arrowStyleStack.alpha = 0
        mainStack.addArrangedSubview(arrowStyleStack)
        self.arrowStyleStackRef = arrowStyleStack
        
        // Arrow Indicator
        arrowStyleSelectionIndicator.backgroundColor = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        arrowStyleSelectionIndicator.layer.cornerRadius = 8
        arrowStyleStack.addSubview(arrowStyleSelectionIndicator)
        arrowStyleStack.sendSubviewToBack(arrowStyleSelectionIndicator)
        
        // Marker Width Stack
        let markerWidthStack = UIStackView()
        markerWidthStack.axis = .horizontal
        markerWidthStack.spacing = 20
        markerWidthStack.distribution = .fillEqually
        markerWidthStack.isHidden = true // Initially hidden
        markerWidthStack.alpha = 0
        mainStack.addArrangedSubview(markerWidthStack)
        self.markerWidthStackRef = markerWidthStack
        
        // Setup Marker Width Indicator
        markerWidthSelectionIndicator.backgroundColor = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        markerWidthSelectionIndicator.layer.cornerRadius = 8
        markerWidthStack.addSubview(markerWidthSelectionIndicator)
        markerWidthStack.sendSubviewToBack(markerWidthSelectionIndicator)
        
        // Pan Gesture
        let markerPan = UIPanGestureRecognizer(target: self, action: #selector(handleMarkerWidthPan(_:)))
        markerWidthStack.addGestureRecognizer(markerPan)
        
        for width in orderedMarkerWidths {
            let btn = UIButton()
            // Visuals: Use circle size to represent width.
            let config = UIImage.SymbolConfiguration(pointSize: width == 20 ? 12 : 20)
            btn.setImage(UIImage(systemName: "circle.fill", withConfiguration: config), for: .normal)
            btn.tintColor = .white
            btn.addAction(UIAction { [weak self] _ in self?.selectMarkerWidth(width) }, for: .touchUpInside)
            markerWidthStack.addArrangedSubview(btn)
            markerWidthButtons.append(btn)
        }
        
        // arrowStyleStack implementation follows...

        
        // Option 1: One-Way (arrow.right)
        // Option 2: Two-Way (arrow.left.and.right)
        // Option 3: Line (line.diagonal)
        // Note: SF Symbols might vary. "line.diagonal" or just a drawn line.
        let arrowStyles: [(ArrowStyle, String)] = [
            (.oneWay, "arrow.right"),
            (.twoWay, "arrow.left.and.right"),
            (.line, "line.diagonal")
        ]
        
        for (style, icon) in arrowStyles {
            let btn = UIButton()
            btn.setImage(UIImage(systemName: icon), for: .normal)
            btn.tintColor = .white
            btn.addAction(UIAction { [weak self] _ in self?.selectArrowStyle(style) }, for: .touchUpInside)
            arrowStyleStack.addArrangedSubview(btn)
            arrowStyleButtons.append(btn)
        }
        
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
    

    
    private var lastBounds: CGRect = .zero
    private var hasInitialLayout = false
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 1. Handle Initial Layout
        // Use async to ensure layout pass is FULLY complete before updating UI
        if !hasInitialLayout {
            hasInitialLayout = true
            DispatchQueue.main.async { [weak self] in
                self?.updateUI(animated: false)
            }
        }
        
        // 2. Handle Resizing (Rotation, etc.)
        // Prevent infinite loop by checking if bounds actually changed
        if bounds != lastBounds {
            lastBounds = bounds
            // For resizing, we want immediate update if possible, but async is safer to prevent conflict
            // However, usually sync is fine here if bounds changed.
            // Let's stick to the previous safe logic for resizing, but without the guard blocking the initial one.
            if !hasInitialLayout { return } // Wait for initial async to fire first? No, immediate is fine for resize.
            
            updateUI(animated: false)
        }
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
    
    @objc private func handleTextSizePan(_ gesture: UIPanGestureRecognizer) {
        guard let sizeStack = gesture.view else { return }
        let location = gesture.location(in: sizeStack)
        let width = sizeStack.bounds.width
        let count = CGFloat(orderedTextSizes.count)
        
        guard width > 0, count > 0 else { return }
        
        let segmentWidth = width / count
        let index = Int(floor(location.x / segmentWidth))
        let clampedIndex = max(0, min(orderedTextSizes.count - 1, index))
        let size = orderedTextSizes[clampedIndex]
        
        if size != selectedTextSize {
            selectTextSize(size)
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }
    
    @objc private func handleArrowStylePan(_ gesture: UIPanGestureRecognizer) {
        guard let stack = gesture.view else { return }
        let location = gesture.location(in: stack)
        let width = stack.bounds.width
        let count = CGFloat(orderedArrowStyles.count)
        
        guard width > 0, count > 0 else { return }
        
        let segmentWidth = width / count
        let index = Int(floor(location.x / segmentWidth))
        let clampedIndex = max(0, min(orderedArrowStyles.count - 1, index))
        let style = orderedArrowStyles[clampedIndex]
        
        if style != selectedArrowStyle {
            selectArrowStyle(style)
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
    
    func selectTool(_ tool: MarkupTool, notifyDelegate: Bool = true) {
        selectedTool = tool
        if notifyDelegate {
            delegate?.didSelectTool(tool)
        }
        
        // Toggle Option Stacks visibility
        let isText = (tool == .text)
        let isArrow = (tool == .arrow)
        let isMarker = (tool == .marker)
        
        // Step 1: Set hidden state IMMEDIATELY (no animation)
        textSizeStackRef?.isHidden = !isText
        arrowStyleStackRef?.isHidden = !isArrow
        markerWidthStackRef?.isHidden = !isMarker
        
        // Step 2: Force layout update BEFORE reading frame values
        setNeedsLayout()
        layoutIfNeeded()
        
        // Step 3: Update indicator position with correct frame values
        updateUI(animated: true)
        
        // Step 4: Animate alpha for visual smoothness
        UIView.animate(withDuration: 0.2) {
            self.textSizeStackRef?.alpha = isText ? 1.0 : 0.0
            self.arrowStyleStackRef?.alpha = isArrow ? 1.0 : 0.0
            self.markerWidthStackRef?.alpha = isMarker ? 1.0 : 0.0
        }
    }
    
    func selectTextSize(_ size: CGFloat, notifyDelegate: Bool = true) {
        selectedTextSize = size
        if notifyDelegate {
            delegate?.didSelectTextSize(size)
        }
        updateUI(animated: true)
    }
    
    func selectArrowStyle(_ style: ArrowStyle, notifyDelegate: Bool = true) {
        selectedArrowStyle = style
        if notifyDelegate {
            delegate?.didSelectArrowStyle(style)
        }
        updateUI(animated: true)
    }
    
    func selectMarkerWidth(_ width: CGFloat, notifyDelegate: Bool = true) {
        selectedMarkerWidth = width
        if notifyDelegate {
            delegate?.didSelectMarkerWidth(width)
        }
        updateUI(animated: true)
    }
    
    @objc private func handleMarkerWidthPan(_ gesture: UIPanGestureRecognizer) {
        guard let stack = gesture.view else { return }
        let location = gesture.location(in: stack)
        let width = stack.bounds.width
        let count = CGFloat(orderedMarkerWidths.count)
        guard width > 0, count > 0 else { return }
        
        let segmentWidth = width / count
        let index = Int(floor(location.x / segmentWidth))
        let clampedIndex = max(0, min(orderedMarkerWidths.count - 1, index))
        let w = orderedMarkerWidths[clampedIndex]
        
        if w != selectedMarkerWidth {
            selectMarkerWidth(w)
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }
    
    func selectColor(_ color: UIColor, notifyDelegate: Bool = true) {
        selectedColor = color
        if notifyDelegate {
            delegate?.didSelectColor(color)
        }
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
        
        // Update Text Size Buttons
        for (i, b) in textSizeButtons.enumerated() {
            guard i < orderedTextSizes.count else { continue }
            let size = orderedTextSizes[i]
            let isSelected = (size == selectedTextSize)
            b.tintColor = isSelected ? .white : UIColor.white.withAlphaComponent(0.5)
            b.transform = isSelected ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
        }
        
        // Update Arrow Style Buttons
        for (i, b) in arrowStyleButtons.enumerated() {
            guard i < orderedArrowStyles.count else { continue }
            let style = orderedArrowStyles[i]
            let isSelected = (style == selectedArrowStyle)
            b.tintColor = isSelected ? .white : UIColor.white.withAlphaComponent(0.5)
            b.transform = isSelected ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
        }
        
        // Update Marker Width Buttons
        for (i, b) in markerWidthButtons.enumerated() {
            guard i < orderedMarkerWidths.count else { continue }
            let width = orderedMarkerWidths[i]
            let isSelected = (width == selectedMarkerWidth)
            b.tintColor = isSelected ? .white : UIColor.white.withAlphaComponent(0.5)
            b.transform = isSelected ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
        }
        
        updateSelectionIndicatorPosition(animated: animated)
        updateColorSelectionIndicatorPosition(animated: animated)
        updateTextSizeIndicatorPosition(animated: animated)
        updateArrowStyleIndicatorPosition(animated: animated)
        updateMarkerWidthIndicatorPosition(animated: animated)
        
        // Color buttons update
        for btn in colorButtons {
            // ... (rest of method is same)
            guard let color = buttonColors[btn] else { continue }
            let isSelected = (color.toHex() == selectedColor.toHex())
            
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
        // Find button for selected color using Hex comparison for tolerance
        guard let btn = colorButtons.first(where: { buttonColors[$0]?.toHex() == selectedColor.toHex() }), let _ = colorStackRef else { return }
        
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
    
    private func updateTextSizeIndicatorPosition(animated: Bool) {
        guard let stack = textSizeStackRef, !stack.isHidden else { return }
        
        // Find index of selected size
        guard let index = orderedTextSizes.firstIndex(of: selectedTextSize),
              index < textSizeButtons.count else { return }
        
        let btn = textSizeButtons[index]
        let targetFrame = btn.frame.insetBy(dx: -4, dy: -4)
        if targetFrame.width == 0 || targetFrame.height == 0 { return }
        
        let updates = {
            self.textSizeSelectionIndicator.frame = targetFrame
            self.textSizeSelectionIndicator.layer.cornerRadius = min(targetFrame.width, targetFrame.height) / 2
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.beginFromCurrentState, .allowUserInteraction], animations: updates)
        } else {
            updates()
        }
    }
    
    private func updateArrowStyleIndicatorPosition(animated: Bool) {
        guard let stack = arrowStyleStackRef, !stack.isHidden else { return }
        guard let index = orderedArrowStyles.firstIndex(of: selectedArrowStyle), index < arrowStyleButtons.count else { return }
        
        let btn = arrowStyleButtons[index]
        let targetFrame = btn.frame.insetBy(dx: -4, dy: -4)
        if targetFrame.width == 0 || targetFrame.height == 0 { return }
        
        let updates = {
            self.arrowStyleSelectionIndicator.frame = targetFrame
            self.arrowStyleSelectionIndicator.layer.cornerRadius = min(targetFrame.width, targetFrame.height) / 2
        }
        
        if animated {
             UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.beginFromCurrentState, .allowUserInteraction], animations: updates)
        } else {
            updates()
        }
    }
    

    private func updateMarkerWidthIndicatorPosition(animated: Bool) {
        guard let stack = markerWidthStackRef, !stack.isHidden else { return }
        guard let index = orderedMarkerWidths.firstIndex(of: selectedMarkerWidth), index < markerWidthButtons.count else { return }
        
        let btn = markerWidthButtons[index]
        let targetFrame = btn.frame.insetBy(dx: -4, dy: -4)
        if targetFrame.width == 0 || targetFrame.height == 0 { return }
        
        let updates = {
            self.markerWidthSelectionIndicator.frame = targetFrame
            self.markerWidthSelectionIndicator.layer.cornerRadius = min(targetFrame.width, targetFrame.height) / 2
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.beginFromCurrentState, .allowUserInteraction], animations: updates)
        } else {
            updates()
        }
    }
}
