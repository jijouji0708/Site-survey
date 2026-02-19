import UIKit

protocol MarkupToolbarDelegate: AnyObject {
    func didSelectTool(_ tool: MarkupTool)
    func didSelectColor(_ color: UIColor)
    func didSelectTextSize(_ size: CGFloat)
    func didSelectArrowStyle(_ style: ArrowStyle)
    func didSelectMarkerWidth(_ width: CGFloat)
    func didSelectPenWidth(_ width: CGFloat)
    func didSelectStamp(_ stamp: StampType)
    func didSelectStampScale(_ scale: CGFloat)
    func didSelectNumberShape(_ shape: NumberShape)
    func didSelectNumberScale(_ scale: CGFloat)
    func didSelectNumberVisibility(_ isVisible: Bool)
    func didSelectNumberFillOpacity(_ opacity: CGFloat)
    func didSelectNumberRotation(_ rotation: CGFloat)
    func didSelectShapeFillOpacity(_ opacity: CGFloat)
}

class MarkupToolbar: UIView {
    weak var delegate: MarkupToolbarDelegate?
    private var selectedTool: MarkupTool = .arrow
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
    private var selectedMarkerWidth: CGFloat = 10 // Default: Thin
    private var orderedMarkerWidths: [CGFloat] = [10, 30] // Thin, Thick
    private var markerWidthButtons: [UIButton] = []
    
    // Pen Width
    private var selectedPenWidth: CGFloat = 0.5 // Default: Smallest
    private var orderedPenWidths: [CGFloat] = [0.5, 1, 2] // Thin, Medium, Thick
    private var penWidthButtons: [UIButton] = []
    
    // Liquid Glass Indicators
    private let selectionIndicator = UIView()
    private weak var toolStackRef: UIStackView?
    
    private let colorSelectionIndicator = UIView()
    private weak var colorStackRef: UIStackView?
    private weak var colorContainerRef: UIView?
    
    private let textSizeSelectionIndicator = UIView()
    private weak var textSizeStackRef: UIStackView?
    
    private let arrowStyleSelectionIndicator = UIView()
    private weak var arrowStyleStackRef: UIStackView?
    
    private let markerWidthSelectionIndicator = UIView()
    private weak var markerWidthStackRef: UIStackView?
    
    private let penWidthSelectionIndicator = UIView()
    private weak var penWidthStackRef: UIStackView?

    // Shape Fill Options（丸/四角）
    private var selectedShapeFillOpacity: CGFloat = 0.0
    private weak var shapeContainerRef: UIView?
    private weak var shapeOpacityStackRef: UIStackView?
    private weak var shapeOpacitySliderRef: UISlider?
    private weak var shapeOpacityLabelRef: UILabel?
    
    // Stamp Selection
    private var selectedStamp: StampType = .check
    private weak var stampContainerRef: UIView?
    private var stampButtons: [StampType: UIButton] = [:]
    private weak var stampGridRef: UIStackView?
    private var orderedStampButtons: [UIButton] = []
    
    // Stamp Size
    private var selectedStampScale: CGFloat = 0.5 // Default Small
    private var orderedStampScales: [CGFloat] = [0.5, 1.0] // Small, Large
    private var stampScaleButtons: [UIButton] = []
    private weak var stampScaleStackRef: UIStackView?
    
    // Stamp Panel Collapse
    private var isStampPanelExpanded = true  // Default: expanded
    private weak var stampExpandedContentRef: UIStackView?
    private weak var stampToggleButtonRef: UIButton?
    private var stampContainerHeightConstraint: NSLayoutConstraint?
    
    // Number Stamp（数字スタンプ）
    private var selectedNumberShape: NumberShape = .circle
    private var orderedNumberShapes: [NumberShape] = []
    private var numberShapeButtons: [NumberShape: UIButton] = [:]
    private weak var numberContainerRef: UIView?
    private var isNumberPanelExpanded = true
    private weak var numberExpandedContentRef: UIStackView?
    private weak var numberToggleButtonRef: UIButton?
    private weak var numberShapeStackRef: UIStackView?
    private var selectedNumberScale: CGFloat = 0.25
    private var orderedNumberScales: [CGFloat] = [0.25, 0.5] // S, L（Lは旧S）
    private var selectedNumberVisibility: Bool = true
    private var selectedNumberFillOpacity: CGFloat = 1.0
    private weak var numberVisibilityStackRef: UIStackView?
    private weak var numberVisibilityButtonRef: UIButton?
    private weak var numberOpacityStackRef: UIStackView?
    private weak var numberOpacitySliderRef: UISlider?
    private weak var numberOpacityLabelRef: UILabel?
    private weak var numberScaleStackRef: UIStackView?
    private var numberScaleButtons: [UIButton] = []
    private var selectedNumberRotation: CGFloat = 0
    private weak var numberRotationStackRef: UIStackView?
    private weak var numberRotationLabelRef: UILabel?
    private weak var numberRotationSliderRef: UISlider?
    
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
        mainStack.distribution = .fill
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
        textSizeStack.heightAnchor.constraint(equalToConstant: 36).isActive = true
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
        arrowStyleStack.heightAnchor.constraint(equalToConstant: 36).isActive = true
        self.arrowStyleStackRef = arrowStyleStack
        
        // Arrow Indicator
        arrowStyleSelectionIndicator.backgroundColor = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        arrowStyleSelectionIndicator.layer.cornerRadius = 8
        arrowStyleStack.addSubview(arrowStyleSelectionIndicator)
        arrowStyleStack.sendSubviewToBack(arrowStyleSelectionIndicator)
        
        // Add Pan Gesture for Arrow Style
        let arrowPan = UIPanGestureRecognizer(target: self, action: #selector(handleArrowStylePan(_:)))
        arrowStyleStack.addGestureRecognizer(arrowPan)
        
        // Marker Width Stack
        let markerWidthStack = UIStackView()
        markerWidthStack.axis = .horizontal
        markerWidthStack.spacing = 20
        markerWidthStack.distribution = .fillEqually
        markerWidthStack.isHidden = true // Initially hidden
        markerWidthStack.alpha = 0
        mainStack.addArrangedSubview(markerWidthStack)
        markerWidthStack.heightAnchor.constraint(equalToConstant: 36).isActive = true
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
        
        // Pen Width Stack
        let penWidthStack = UIStackView()
        penWidthStack.axis = .horizontal
        penWidthStack.spacing = 20
        penWidthStack.distribution = .fillEqually
        penWidthStack.isHidden = true // Initially hidden
        penWidthStack.alpha = 0
        mainStack.addArrangedSubview(penWidthStack)
        penWidthStack.heightAnchor.constraint(equalToConstant: 36).isActive = true
        self.penWidthStackRef = penWidthStack
        
        // Setup Pen Width Indicator
        penWidthSelectionIndicator.backgroundColor = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        penWidthSelectionIndicator.layer.cornerRadius = 8
        penWidthStack.addSubview(penWidthSelectionIndicator)
        penWidthStack.sendSubviewToBack(penWidthSelectionIndicator)
        
        // Pan Gesture for Pen Width
        let penPan = UIPanGestureRecognizer(target: self, action: #selector(handlePenWidthPan(_:)))
        penWidthStack.addGestureRecognizer(penPan)
        
        // Pen Width Buttons: 0.5 (thin), 1 (medium), 2 (thick)
        let penWidthConfigs: [(CGFloat, CGFloat)] = [(0.5, 8), (1, 12), (2, 18)] // (width, icon size)
        for (width, iconSize) in penWidthConfigs {
            let btn = UIButton()
            let config = UIImage.SymbolConfiguration(pointSize: iconSize)
            btn.setImage(UIImage(systemName: "circle.fill", withConfiguration: config), for: .normal)
            btn.tintColor = .white
            btn.addAction(UIAction { [weak self] _ in self?.selectPenWidth(width) }, for: .touchUpInside)
            penWidthStack.addArrangedSubview(btn)
            penWidthButtons.append(btn)
        }

        // Shape Fill Container（丸/四角専用）
        let shapeContainer = UIView()
        shapeContainer.isHidden = true
        shapeContainer.alpha = 0
        mainStack.addArrangedSubview(shapeContainer)
        self.shapeContainerRef = shapeContainer

        let shapeOuterStack = UIStackView()
        shapeOuterStack.axis = .vertical
        shapeOuterStack.spacing = 8
        shapeOuterStack.distribution = .fill
        shapeOuterStack.translatesAutoresizingMaskIntoConstraints = false
        shapeContainer.addSubview(shapeOuterStack)
        NSLayoutConstraint.activate([
            shapeOuterStack.leadingAnchor.constraint(equalTo: shapeContainer.leadingAnchor),
            shapeOuterStack.trailingAnchor.constraint(equalTo: shapeContainer.trailingAnchor),
            shapeOuterStack.topAnchor.constraint(equalTo: shapeContainer.topAnchor),
            shapeOuterStack.bottomAnchor.constraint(equalTo: shapeContainer.bottomAnchor)
        ])

        let shapeOpacityStack = UIStackView()
        shapeOpacityStack.axis = .horizontal
        shapeOpacityStack.spacing = 8
        shapeOpacityStack.alignment = .center
        shapeOpacityStack.distribution = .fill
        shapeOpacityStack.heightAnchor.constraint(equalToConstant: 32).isActive = true
        shapeOuterStack.addArrangedSubview(shapeOpacityStack)
        self.shapeOpacityStackRef = shapeOpacityStack

        let shapeOpacityIcon = UIImageView(image: UIImage(systemName: "drop.fill"))
        shapeOpacityIcon.tintColor = UIColor.white.withAlphaComponent(0.9)
        shapeOpacityIcon.contentMode = .scaleAspectFit
        shapeOpacityIcon.setContentHuggingPriority(.required, for: .horizontal)
        shapeOpacityIcon.translatesAutoresizingMaskIntoConstraints = false
        shapeOpacityStack.addArrangedSubview(shapeOpacityIcon)
        NSLayoutConstraint.activate([
            shapeOpacityIcon.widthAnchor.constraint(equalToConstant: 14),
            shapeOpacityIcon.heightAnchor.constraint(equalToConstant: 14)
        ])

        let shapeOpacitySlider = UISlider()
        shapeOpacitySlider.minimumValue = 0
        shapeOpacitySlider.maximumValue = 1
        shapeOpacitySlider.value = Float(selectedShapeFillOpacity)
        shapeOpacitySlider.minimumTrackTintColor = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        shapeOpacitySlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.25)
        shapeOpacitySlider.addTarget(self, action: #selector(handleShapeOpacitySliderChanged(_:)), for: .valueChanged)
        shapeOpacityStack.addArrangedSubview(shapeOpacitySlider)
        self.shapeOpacitySliderRef = shapeOpacitySlider

        let shapeOpacityLabel = UILabel()
        shapeOpacityLabel.textColor = .white
        shapeOpacityLabel.font = .systemFont(ofSize: 12, weight: .bold)
        shapeOpacityLabel.textAlignment = .right
        shapeOpacityLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
        shapeOpacityStack.addArrangedSubview(shapeOpacityLabel)
        self.shapeOpacityLabelRef = shapeOpacityLabel

        updateShapeFillOpacityUI()
        
        // Number Stamp Container（折りたたみ対応）
        let numberContainer = UIView()
        numberContainer.isHidden = true
        numberContainer.alpha = 0
        mainStack.addArrangedSubview(numberContainer)
        self.numberContainerRef = numberContainer

        let numberOuterStack = UIStackView()
        numberOuterStack.axis = .vertical
        numberOuterStack.spacing = 6
        numberOuterStack.distribution = .fill
        numberOuterStack.translatesAutoresizingMaskIntoConstraints = false
        numberContainer.addSubview(numberOuterStack)
        NSLayoutConstraint.activate([
            numberOuterStack.leadingAnchor.constraint(equalTo: numberContainer.leadingAnchor),
            numberOuterStack.trailingAnchor.constraint(equalTo: numberContainer.trailingAnchor),
            numberOuterStack.topAnchor.constraint(equalTo: numberContainer.topAnchor),
            numberOuterStack.bottomAnchor.constraint(equalTo: numberContainer.bottomAnchor)
        ])

        let numberToggleRow = UIStackView()
        numberToggleRow.axis = .horizontal
        numberToggleRow.distribution = .fill
        numberToggleRow.alignment = .center
        numberToggleRow.heightAnchor.constraint(equalToConstant: 20).isActive = true
        numberOuterStack.addArrangedSubview(numberToggleRow)

        let numberPanelTitle = UILabel()
        numberPanelTitle.text = "数字スタンプ"
        numberPanelTitle.textColor = UIColor.white.withAlphaComponent(0.85)
        numberPanelTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        numberToggleRow.addArrangedSubview(numberPanelTitle)

        let numberToggleSpacer = UIView()
        numberToggleRow.addArrangedSubview(numberToggleSpacer)

        let numberToggleButton = UIButton(type: .system)
        numberToggleButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        numberToggleButton.tintColor = UIColor.white.withAlphaComponent(0.6)
        numberToggleButton.contentHorizontalAlignment = .right
        numberToggleButton.widthAnchor.constraint(equalToConstant: 40).isActive = true
        numberToggleButton.addAction(UIAction { [weak self] _ in self?.toggleNumberPanel() }, for: .touchUpInside)
        numberToggleRow.addArrangedSubview(numberToggleButton)
        self.numberToggleButtonRef = numberToggleButton

        let numberExpandedContent = UIStackView()
        numberExpandedContent.axis = .vertical
        numberExpandedContent.spacing = 8
        numberExpandedContent.distribution = .fill
        numberOuterStack.addArrangedSubview(numberExpandedContent)
        self.numberExpandedContentRef = numberExpandedContent

        // Number Shape Stack
        let numberShapeStack = UIStackView()
        numberShapeStack.axis = .horizontal
        numberShapeStack.spacing = 8
        numberShapeStack.distribution = .fillEqually
        numberExpandedContent.addArrangedSubview(numberShapeStack)
        numberShapeStack.heightAnchor.constraint(equalToConstant: 38).isActive = true
        self.numberShapeStackRef = numberShapeStack

        let numberShapePan = UIPanGestureRecognizer(target: self, action: #selector(handleNumberShapePan(_:)))
        numberShapeStack.addGestureRecognizer(numberShapePan)

        let shapes: [(NumberShape, String)] = [
            (.circle, "circle.fill"),
            (.square, "square.fill"),
            (.rectangle, "rectangle.fill"),
            (.diamond, "diamond.fill"),
            (.triangle, "triangle.fill")
        ]

        for (shape, icon) in shapes {
            let btn = UIButton()
            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
            btn.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
            btn.tintColor = .white
            btn.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            btn.layer.cornerRadius = 8
            btn.addAction(UIAction { [weak self] _ in self?.selectNumberShape(shape) }, for: .touchUpInside)
            numberShapeStack.addArrangedSubview(btn)
            numberShapeButtons[shape] = btn
            orderedNumberShapes.append(shape)
        }
        updateNumberShapeUI()

        // Compact row 1: Number visibility + Number size
        let numberCompactTopRow = UIStackView()
        numberCompactTopRow.axis = .horizontal
        numberCompactTopRow.spacing = 12
        numberCompactTopRow.distribution = .fill
        numberExpandedContent.addArrangedSubview(numberCompactTopRow)
        numberCompactTopRow.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let numberVisibilityContainer = UIView()
        numberVisibilityContainer.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        numberVisibilityContainer.layer.cornerRadius = 10
        numberCompactTopRow.addArrangedSubview(numberVisibilityContainer)

        let numberScaleContainer = UIView()
        numberScaleContainer.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        numberScaleContainer.layer.cornerRadius = 10
        numberCompactTopRow.addArrangedSubview(numberScaleContainer)
        numberVisibilityContainer.widthAnchor.constraint(equalTo: numberScaleContainer.widthAnchor).isActive = true

        // Number visibility (ON/OFF)
        let numberVisibilityStack = UIStackView()
        numberVisibilityStack.axis = .horizontal
        numberVisibilityStack.spacing = 6
        numberVisibilityStack.alignment = .center
        numberVisibilityStack.distribution = .fill
        numberVisibilityStack.translatesAutoresizingMaskIntoConstraints = false
        numberVisibilityContainer.addSubview(numberVisibilityStack)
        NSLayoutConstraint.activate([
            numberVisibilityStack.leadingAnchor.constraint(equalTo: numberVisibilityContainer.leadingAnchor, constant: 8),
            numberVisibilityStack.trailingAnchor.constraint(equalTo: numberVisibilityContainer.trailingAnchor, constant: -8),
            numberVisibilityStack.topAnchor.constraint(equalTo: numberVisibilityContainer.topAnchor),
            numberVisibilityStack.bottomAnchor.constraint(equalTo: numberVisibilityContainer.bottomAnchor)
        ])
        self.numberVisibilityStackRef = numberVisibilityStack

        let numberVisibilityIcon = UIImageView(image: UIImage(systemName: "textformat.123"))
        numberVisibilityIcon.tintColor = UIColor.white.withAlphaComponent(0.9)
        numberVisibilityIcon.contentMode = .scaleAspectFit
        numberVisibilityIcon.translatesAutoresizingMaskIntoConstraints = false
        numberVisibilityIcon.setContentHuggingPriority(.required, for: .horizontal)
        numberVisibilityStack.addArrangedSubview(numberVisibilityIcon)
        NSLayoutConstraint.activate([
            numberVisibilityIcon.widthAnchor.constraint(equalToConstant: 14),
            numberVisibilityIcon.heightAnchor.constraint(equalToConstant: 14)
        ])

        let numberVisibilitySpacer = UIView()
        numberVisibilityStack.addArrangedSubview(numberVisibilitySpacer)

        let numberVisibilityButton = UIButton(type: .system)
        numberVisibilityButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        numberVisibilityButton.layer.cornerRadius = 10
        numberVisibilityButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
        numberVisibilityButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        numberVisibilityButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.selectNumberVisibility(!self.selectedNumberVisibility)
        }, for: .touchUpInside)
        numberVisibilityStack.addArrangedSubview(numberVisibilityButton)
        self.numberVisibilityButtonRef = numberVisibilityButton

        // Number size selection (S/L)
        let numberScaleStack = UIStackView()
        numberScaleStack.axis = .horizontal
        numberScaleStack.spacing = 6
        numberScaleStack.alignment = .center
        numberScaleStack.distribution = .fill
        numberScaleStack.translatesAutoresizingMaskIntoConstraints = false
        numberScaleContainer.addSubview(numberScaleStack)
        NSLayoutConstraint.activate([
            numberScaleStack.leadingAnchor.constraint(equalTo: numberScaleContainer.leadingAnchor, constant: 8),
            numberScaleStack.trailingAnchor.constraint(equalTo: numberScaleContainer.trailingAnchor, constant: -8),
            numberScaleStack.topAnchor.constraint(equalTo: numberScaleContainer.topAnchor),
            numberScaleStack.bottomAnchor.constraint(equalTo: numberScaleContainer.bottomAnchor)
        ])
        self.numberScaleStackRef = numberScaleStack

        let numberScaleIcon = UIImageView(image: UIImage(systemName: "textformat.size"))
        numberScaleIcon.tintColor = UIColor.white.withAlphaComponent(0.9)
        numberScaleIcon.contentMode = .scaleAspectFit
        numberScaleIcon.translatesAutoresizingMaskIntoConstraints = false
        numberScaleIcon.setContentHuggingPriority(.required, for: .horizontal)
        numberScaleStack.addArrangedSubview(numberScaleIcon)
        NSLayoutConstraint.activate([
            numberScaleIcon.widthAnchor.constraint(equalToConstant: 14),
            numberScaleIcon.heightAnchor.constraint(equalToConstant: 14)
        ])

        let numberScaleButtonRow = UIStackView()
        numberScaleButtonRow.axis = .horizontal
        numberScaleButtonRow.spacing = 6
        numberScaleButtonRow.distribution = .fillEqually
        numberScaleStack.addArrangedSubview(numberScaleButtonRow)

        let numberScaleConfigs: [(CGFloat, String)] = [
            (orderedNumberScales[0], "S"),
            (orderedNumberScales[1], "L")
        ]
        for (scale, label) in numberScaleConfigs {
            let btn = UIButton(type: .system)
            btn.setTitle(label, for: .normal)
            btn.setTitleColor(.white, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
            btn.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            btn.layer.cornerRadius = 10
            btn.heightAnchor.constraint(equalToConstant: 28).isActive = true
            btn.addAction(UIAction { [weak self] _ in self?.selectNumberScale(scale) }, for: .touchUpInside)
            numberScaleButtonRow.addArrangedSubview(btn)
            numberScaleButtons.append(btn)
        }
        updateNumberStampScaleUI()
        updateNumberVisibilityUI()

        // Compact row 2: Number fill opacity + Number rotation
        let numberCompactSliderRow = UIStackView()
        numberCompactSliderRow.axis = .horizontal
        numberCompactSliderRow.spacing = 8
        numberCompactSliderRow.distribution = .fillEqually
        numberExpandedContent.addArrangedSubview(numberCompactSliderRow)
        numberCompactSliderRow.heightAnchor.constraint(equalToConstant: 32).isActive = true

        // Number fill opacity slider (10% step)
        let numberOpacityStack = UIStackView()
        numberOpacityStack.axis = .horizontal
        numberOpacityStack.spacing = 6
        numberOpacityStack.alignment = .center
        numberOpacityStack.distribution = .fill
        numberCompactSliderRow.addArrangedSubview(numberOpacityStack)
        self.numberOpacityStackRef = numberOpacityStack

        let numberOpacityIcon = UIImageView(image: UIImage(systemName: "drop.fill"))
        numberOpacityIcon.tintColor = UIColor.white.withAlphaComponent(0.9)
        numberOpacityIcon.contentMode = .scaleAspectFit
        numberOpacityIcon.translatesAutoresizingMaskIntoConstraints = false
        numberOpacityIcon.setContentHuggingPriority(.required, for: .horizontal)
        numberOpacityStack.addArrangedSubview(numberOpacityIcon)
        NSLayoutConstraint.activate([
            numberOpacityIcon.widthAnchor.constraint(equalToConstant: 14),
            numberOpacityIcon.heightAnchor.constraint(equalToConstant: 14)
        ])

        let numberOpacitySlider = UISlider()
        numberOpacitySlider.minimumValue = 0.0
        numberOpacitySlider.maximumValue = 1.0
        numberOpacitySlider.value = Float(selectedNumberFillOpacity)
        numberOpacitySlider.minimumTrackTintColor = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        numberOpacitySlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.25)
        numberOpacitySlider.addTarget(self, action: #selector(handleNumberOpacitySliderChanged(_:)), for: .valueChanged)
        numberOpacityStack.addArrangedSubview(numberOpacitySlider)
        self.numberOpacitySliderRef = numberOpacitySlider

        let numberOpacityLabel = UILabel()
        numberOpacityLabel.textColor = .white
        numberOpacityLabel.font = .systemFont(ofSize: 11, weight: .bold)
        numberOpacityLabel.textAlignment = .right
        numberOpacityLabel.widthAnchor.constraint(equalToConstant: 38).isActive = true
        numberOpacityStack.addArrangedSubview(numberOpacityLabel)
        self.numberOpacityLabelRef = numberOpacityLabel

        // Number rotation controls (0...90, 15-step slider)
        let numberRotationStack = UIStackView()
        numberRotationStack.axis = .horizontal
        numberRotationStack.spacing = 6
        numberRotationStack.alignment = .center
        numberRotationStack.distribution = .fill
        numberCompactSliderRow.addArrangedSubview(numberRotationStack)
        self.numberRotationStackRef = numberRotationStack

        let numberRotationIcon = UIImageView(image: UIImage(systemName: "rotate.right.fill"))
        numberRotationIcon.tintColor = UIColor.white.withAlphaComponent(0.9)
        numberRotationIcon.contentMode = .scaleAspectFit
        numberRotationIcon.translatesAutoresizingMaskIntoConstraints = false
        numberRotationIcon.setContentHuggingPriority(.required, for: .horizontal)
        numberRotationStack.addArrangedSubview(numberRotationIcon)
        NSLayoutConstraint.activate([
            numberRotationIcon.widthAnchor.constraint(equalToConstant: 14),
            numberRotationIcon.heightAnchor.constraint(equalToConstant: 14)
        ])

        let numberRotationSlider = UISlider()
        numberRotationSlider.minimumValue = 0
        numberRotationSlider.maximumValue = 90
        numberRotationSlider.value = 0
        numberRotationSlider.minimumTrackTintColor = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        numberRotationSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.25)
        numberRotationSlider.addTarget(self, action: #selector(handleNumberRotationSliderChanged(_:)), for: .valueChanged)
        numberRotationStack.addArrangedSubview(numberRotationSlider)
        self.numberRotationSliderRef = numberRotationSlider

        let numberRotationLabel = UILabel()
        numberRotationLabel.textColor = .white
        numberRotationLabel.font = .systemFont(ofSize: 11, weight: .bold)
        numberRotationLabel.textAlignment = .right
        numberRotationLabel.widthAnchor.constraint(equalToConstant: 38).isActive = true
        numberRotationStack.addArrangedSubview(numberRotationLabel)
        self.numberRotationLabelRef = numberRotationLabel

        updateNumberFillOpacityUI()
        updateNumberRotationUI()
        
        let stampContainer = UIView()
        stampContainer.isHidden = true
        stampContainer.alpha = 0
        mainStack.addArrangedSubview(stampContainer)
        let heightConstraint = stampContainer.heightAnchor.constraint(equalToConstant: 170) // Expanded height
        heightConstraint.isActive = true
        self.stampContainerHeightConstraint = heightConstraint
        self.stampContainerRef = stampContainer
        
        // Outer stack: toggle button row + grid + size buttons
        let outerStack = UIStackView()
        outerStack.axis = .vertical
        outerStack.spacing = 4
        outerStack.distribution = .fill
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        stampContainer.addSubview(outerStack)
        
        NSLayoutConstraint.activate([
            outerStack.leadingAnchor.constraint(equalTo: stampContainer.leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: stampContainer.trailingAnchor),
            outerStack.topAnchor.constraint(equalTo: stampContainer.topAnchor),
            outerStack.bottomAnchor.constraint(equalTo: stampContainer.bottomAnchor)
        ])
        
        // Toggle button row (small, right-aligned)
        let toggleRow = UIStackView()
        toggleRow.axis = .horizontal
        toggleRow.distribution = .fill
        toggleRow.heightAnchor.constraint(equalToConstant: 20).isActive = true
        outerStack.addArrangedSubview(toggleRow)
        
        let toggleSpacer = UIView()
        toggleRow.addArrangedSubview(toggleSpacer)
        
        let toggleBtn = UIButton()
        toggleBtn.setImage(UIImage(systemName: "chevron.down"), for: .normal)  // Down = collapse direction
        toggleBtn.tintColor = UIColor.white.withAlphaComponent(0.6)
        toggleBtn.contentHorizontalAlignment = .right
        toggleBtn.addAction(UIAction { [weak self] _ in self?.toggleStampPanel() }, for: .touchUpInside)
        toggleBtn.widthAnchor.constraint(equalToConstant: 40).isActive = true
        toggleRow.addArrangedSubview(toggleBtn)
        self.stampToggleButtonRef = toggleBtn
        
        // Expandable content stack (grid + separator + size)
        let expandedContent = UIStackView()
        expandedContent.axis = .vertical
        expandedContent.spacing = 4
        expandedContent.distribution = .fill
        expandedContent.isHidden = false // Default: expanded
        outerStack.addArrangedSubview(expandedContent)
        self.stampExpandedContentRef = expandedContent
        
        // Grid container for stamps (categorized rows)
        let gridStack = UIStackView()
        gridStack.axis = .vertical
        gridStack.spacing = 4
        gridStack.distribution = .fillEqually
        expandedContent.addArrangedSubview(gridStack)
        self.stampGridRef = gridStack
        
        // Group stamps by category
        let allStamps = StampType.allCases
        let symbolStamps = allStamps.filter { $0.category == "記号" }  // 10 items -> 2 rows
        let textStamps = allStamps.filter { $0.category == "テキスト" }  // 5 items -> 1 row
        let emojiStamps = allStamps.filter { $0.category == "絵文字" }  // 4 items -> 1 row
        
        // Helper to create a row of stamps
        func createStampRow(stamps: [StampType], maxPerRow: Int) -> UIStackView {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 4
            rowStack.distribution = .fillEqually
            
            for stamp in stamps {
                let btn = UIButton()
                btn.setTitle(stamp.displayText, for: .normal)
                btn.titleLabel?.font = .systemFont(ofSize: 14)
                btn.titleLabel?.adjustsFontSizeToFitWidth = true
                btn.titleLabel?.minimumScaleFactor = 0.5
                btn.titleLabel?.lineBreakMode = .byClipping
                btn.backgroundColor = UIColor.white.withAlphaComponent(0.1)
                btn.layer.cornerRadius = 4
                btn.clipsToBounds = true
                btn.addAction(UIAction { [weak self] _ in self?.selectStamp(stamp) }, for: .touchUpInside)
                rowStack.addArrangedSubview(btn)
                stampButtons[stamp] = btn
                orderedStampButtons.append(btn)
            }
            
            // Fill remaining with spacers
            let remaining = maxPerRow - stamps.count
            if remaining > 0 {
                for _ in 0..<remaining {
                    let spacer = UIView()
                    spacer.backgroundColor = .clear
                    rowStack.addArrangedSubview(spacer)
                }
            }
            
            return rowStack
        }
        
        // Row 1: Symbols (first 5)
        gridStack.addArrangedSubview(createStampRow(stamps: Array(symbolStamps.prefix(5)), maxPerRow: 5))
        // Row 2: Symbols (next 5)
        gridStack.addArrangedSubview(createStampRow(stamps: Array(symbolStamps.suffix(5)), maxPerRow: 5))
        // Row 3: Text
        gridStack.addArrangedSubview(createStampRow(stamps: textStamps, maxPerRow: 5))
        // Row 4: Emoji
        gridStack.addArrangedSubview(createStampRow(stamps: emojiStamps, maxPerRow: 5))
        
        // Add pan gesture for swipe selection
        let stampPan = UIPanGestureRecognizer(target: self, action: #selector(handleStampPan(_:)))
        stampContainer.addGestureRecognizer(stampPan)
        
        // Separator line
        let stampSeparator = UIView()
        stampSeparator.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        stampSeparator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        expandedContent.addArrangedSubview(stampSeparator)
        
        // Stamp Size Selection Stack (S/L only)
        let stampScaleStack = UIStackView()
        stampScaleStack.axis = .horizontal
        stampScaleStack.spacing = 8
        stampScaleStack.distribution = .fillEqually
        stampScaleStack.heightAnchor.constraint(equalToConstant: 28).isActive = true
        stampScaleStack.isUserInteractionEnabled = true
        expandedContent.addArrangedSubview(stampScaleStack)
        self.stampScaleStackRef = stampScaleStack
        
        // Add pan gesture for swipe scale selection
        let scalePan = UIPanGestureRecognizer(target: self, action: #selector(handleStampScalePan(_:)))
        stampScaleStack.addGestureRecognizer(scalePan)
        
        let scaleConfigs: [(CGFloat, String)] = [
            (0.5, "S"),
            (1.0, "L")
        ]
        
        for (scale, label) in scaleConfigs {
            let btn = UIButton()
            btn.setTitle(label, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
            btn.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            btn.layer.cornerRadius = 4
            btn.addAction(UIAction { [weak self] _ in self?.selectStampScale(scale) }, for: .touchUpInside)
            stampScaleStack.addArrangedSubview(btn)
            stampScaleButtons.append(btn)
        }
        
        // Set initial: expanded
        isStampPanelExpanded = true
        
        // Set initial selection highlight
        updateStampSelectionUI()
        updateStampScaleUI()
        
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
        toolStack.spacing = 8
        toolStack.distribution = .fillEqually
        mainStack.addArrangedSubview(toolStack)
        toolStack.heightAnchor.constraint(equalToConstant: 40).isActive = true
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
            (.circle, "circle"),
            (.stamp, "seal"),
            (.numberStamp, "number.circle")
        ]
        
        for (tool, icon) in tools {
            orderedTools.append(tool)
            let btn = UIButton()
            let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            btn.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
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
        let colorContainer = UIView()
        colorContainer.clipsToBounds = true
        mainStack.addArrangedSubview(colorContainer)
        colorContainer.heightAnchor.constraint(equalToConstant: 34).isActive = true // Fixed height for colors
        self.colorContainerRef = colorContainer
        
        let colorStack = UIStackView()
        colorStack.axis = .horizontal
        colorStack.spacing = 4
        colorStack.distribution = .equalSpacing
        colorStack.alignment = .center
        colorStack.translatesAutoresizingMaskIntoConstraints = false
        colorContainer.addSubview(colorStack)
        self.colorStackRef = colorStack
        
        NSLayoutConstraint.activate([
            colorStack.topAnchor.constraint(equalTo: colorContainer.topAnchor),
            colorStack.bottomAnchor.constraint(equalTo: colorContainer.bottomAnchor),
            colorStack.leadingAnchor.constraint(equalTo: colorContainer.leadingAnchor),
            colorStack.trailingAnchor.constraint(equalTo: colorContainer.trailingAnchor)
        ])
        
        // Setup Color Indicator
        colorSelectionIndicator.backgroundColor = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0) // Accent Green
        colorSelectionIndicator.layer.cornerRadius = 13
        colorStack.addSubview(colorSelectionIndicator)
        colorStack.sendSubviewToBack(colorSelectionIndicator)
        
        // Add Pan Gesture for Color Swipe Selection
        let colorPan = UIPanGestureRecognizer(target: self, action: #selector(handleColorPan(_:)))
        colorPan.cancelsTouchesInView = false
        colorContainer.addGestureRecognizer(colorPan)
        
        for color in MarkupColors.all {
            orderedColors.append(color)
            let btn = UIButton()
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.widthAnchor.constraint(equalToConstant: 18).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 18).isActive = true
            btn.backgroundColor = color
            btn.layer.cornerRadius = 9
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
        guard gesture.state == .began || gesture.state == .changed,
              let colorStack = colorStackRef else { return }
        let location = gesture.location(in: colorStack)

        if let btn = colorButtons.min(by: { abs($0.center.x - location.x) < abs($1.center.x - location.x) }),
           let color = buttonColors[btn] {
            if color != selectedColor {
                selectColor(color)
                let generator = UISelectionFeedbackGenerator()
                generator.selectionChanged()
            }
        }
    }

    @objc private func handleNumberShapePan(_ gesture: UIPanGestureRecognizer) {
        guard let stack = numberShapeStackRef else { return }
        let location = gesture.location(in: stack)
        let width = stack.bounds.width
        let count = CGFloat(orderedNumberShapes.count)
        guard width > 0, count > 0 else { return }

        let segmentWidth = width / count
        let index = Int(floor(location.x / segmentWidth))
        let clampedIndex = max(0, min(orderedNumberShapes.count - 1, index))
        let shape = orderedNumberShapes[clampedIndex]

        if shape != selectedNumberShape {
            selectNumberShape(shape)
            UISelectionFeedbackGenerator().selectionChanged()
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
        let isPen = (tool == .pen)
        let isShape = (tool == .rect || tool == .circle)
        let isStamp = (tool == .stamp)
        let isNumberStamp = (tool == .numberStamp)
        
        // Step 1: Set hidden state IMMEDIATELY (no animation)
        textSizeStackRef?.isHidden = !isText
        arrowStyleStackRef?.isHidden = !isArrow
        markerWidthStackRef?.isHidden = !isMarker
        penWidthStackRef?.isHidden = !isPen
        shapeContainerRef?.isHidden = !isShape
        stampContainerRef?.isHidden = !isStamp
        numberContainerRef?.isHidden = !isNumberStamp
        numberExpandedContentRef?.isHidden = !isNumberStamp || !isNumberPanelExpanded
        
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
            self.penWidthStackRef?.alpha = isPen ? 1.0 : 0.0
            self.shapeContainerRef?.alpha = isShape ? 1.0 : 0.0
            self.stampContainerRef?.alpha = isStamp ? 1.0 : 0.0
            self.numberContainerRef?.alpha = isNumberStamp ? 1.0 : 0.0
            self.numberExpandedContentRef?.alpha = (isNumberStamp && self.isNumberPanelExpanded) ? 1.0 : 0.0
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
    
    func selectPenWidth(_ width: CGFloat, notifyDelegate: Bool = true) {
        selectedPenWidth = width
        if notifyDelegate {
            delegate?.didSelectPenWidth(width)
        }
        updateUI(animated: true)
    }

    func selectShapeFillOpacity(_ opacity: CGFloat, notifyDelegate: Bool = true) {
        let clamped = max(0.0, min(1.0, opacity))
        let stepped = round(clamped * 10) / 10
        selectedShapeFillOpacity = stepped
        if notifyDelegate {
            delegate?.didSelectShapeFillOpacity(stepped)
        }
        updateShapeFillOpacityUI()
    }
    
    func selectNumberShape(_ shape: NumberShape, notifyDelegate: Bool = true) {
        selectedNumberShape = shape
        if notifyDelegate {
            delegate?.didSelectNumberShape(shape)
        }
        updateNumberShapeUI()
    }

    func selectNumberScale(_ scale: CGFloat, notifyDelegate: Bool = true) {
        let snapped = orderedNumberScales.min(by: { abs($0 - scale) < abs($1 - scale) }) ?? scale
        selectedNumberScale = snapped
        if notifyDelegate {
            delegate?.didSelectNumberScale(snapped)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        updateNumberStampScaleUI()
    }
    
    func selectNumberVisibility(_ isVisible: Bool, notifyDelegate: Bool = true) {
        selectedNumberVisibility = isVisible
        if notifyDelegate {
            delegate?.didSelectNumberVisibility(isVisible)
        }
        updateNumberVisibilityUI()
    }
    
    func selectNumberFillOpacity(_ opacity: CGFloat, notifyDelegate: Bool = true) {
        let clamped = max(0.0, min(1.0, opacity))
        let stepped = round(clamped * 10) / 10
        selectedNumberFillOpacity = stepped
        if notifyDelegate {
            delegate?.didSelectNumberFillOpacity(stepped)
        }
        updateNumberFillOpacityUI()
    }

    func selectNumberRotation(_ rotation: CGFloat, notifyDelegate: Bool = true) {
        selectedNumberRotation = normalizedNumberRotation(rotation)
        if notifyDelegate {
            delegate?.didSelectNumberRotation(selectedNumberRotation)
        }
        updateNumberRotationUI()
    }
    
    private func updateNumberShapeUI() {
        for (shape, btn) in numberShapeButtons {
            let isSelected = (shape == selectedNumberShape)
            btn.tintColor = isSelected ? .white : UIColor.white.withAlphaComponent(0.5)
            btn.backgroundColor = isSelected ? UIColor.white.withAlphaComponent(0.3) : UIColor.white.withAlphaComponent(0.1)
            btn.transform = isSelected ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
        }
    }

    private func updateShapeFillOpacityUI() {
        shapeOpacitySliderRef?.setValue(Float(selectedShapeFillOpacity), animated: false)
        let percent = Int((selectedShapeFillOpacity * 100).rounded())
        shapeOpacityLabelRef?.text = "\(percent)%"
    }
    
    private func updateNumberVisibilityUI() {
        guard let button = numberVisibilityButtonRef else { return }
        let accent = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        button.setTitle(selectedNumberVisibility ? "ON" : "OFF", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = selectedNumberVisibility ? accent : UIColor.white.withAlphaComponent(0.2)
    }
    
    private func updateNumberFillOpacityUI() {
        numberOpacitySliderRef?.setValue(Float(selectedNumberFillOpacity), animated: false)
        let percent = Int((selectedNumberFillOpacity * 100).rounded())
        numberOpacityLabelRef?.text = "\(percent)%"
    }

    private func updateNumberRotationUI() {
        let normalized = normalizedNumberRotation(selectedNumberRotation)
        selectedNumberRotation = normalized
        let degree = Int((normalized * 180.0 / .pi).rounded())
        numberRotationSliderRef?.setValue(Float(degree), animated: false)
        numberRotationLabelRef?.text = "\(degree)°"
    }

    private func normalizedNumberRotation(_ angle: CGFloat) -> CGFloat {
        let step = CGFloat.pi / 12.0
        let snapped = round(angle / step) * step
        return max(0, min(.pi / 2.0, snapped))
    }
    
    @objc private func handleNumberOpacitySliderChanged(_ sender: UISlider) {
        let stepped = CGFloat(round(sender.value * 10) / 10)
        selectNumberFillOpacity(stepped)
    }

    @objc private func handleShapeOpacitySliderChanged(_ sender: UISlider) {
        let stepped = CGFloat(round(sender.value * 10) / 10)
        selectShapeFillOpacity(stepped)
    }

    @objc private func handleNumberRotationSliderChanged(_ sender: UISlider) {
        let steppedDegree = CGFloat(round(sender.value / 15) * 15)
        let radians = steppedDegree * .pi / 180.0
        selectNumberRotation(radians)
    }
    
    func selectStamp(_ stamp: StampType) {
        selectedStamp = stamp
        delegate?.didSelectStamp(stamp)
        updateStampSelectionUI()
        updateStampHeaderLabel()
        // ハプティックフィードバック
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func toggleNumberPanel() {
        isNumberPanelExpanded.toggle()
        self.layoutIfNeeded()

        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
            self.numberExpandedContentRef?.alpha = self.isNumberPanelExpanded ? 1.0 : 0.0
            self.numberExpandedContentRef?.isHidden = !self.isNumberPanelExpanded
            let angle: CGFloat = self.isNumberPanelExpanded ? 0 : .pi
            self.numberToggleButtonRef?.transform = CGAffineTransform(rotationAngle: angle)
            self.layoutIfNeeded()
            self.superview?.layoutIfNeeded()
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func toggleStampPanel() {
        isStampPanelExpanded.toggle()
        
        // まずlayoutIfNeededを呼び出してからアニメーション
        self.layoutIfNeeded()
        
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
            // コンテンツの表示/非表示（alphaで制御）
            self.stampExpandedContentRef?.alpha = self.isStampPanelExpanded ? 1.0 : 0.0
            self.stampExpandedContentRef?.isHidden = !self.isStampPanelExpanded
            
            // 高さ制約を更新（折りたたみ時は28に増やす）
            self.stampContainerHeightConstraint?.constant = self.isStampPanelExpanded ? 170 : 28
            
            // Rotate toggle button (down when expanded = collapse, up when collapsed = expand)
            let angle: CGFloat = self.isStampPanelExpanded ? 0 : .pi
            self.stampToggleButtonRef?.transform = CGAffineTransform(rotationAngle: angle)
            
            self.layoutIfNeeded()
            self.superview?.layoutIfNeeded()
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func updateStampHeaderLabel() {
        // Find and update the header label
        if let container = stampContainerRef,
           let outerStack = container.subviews.first as? UIStackView,
           let headerStack = outerStack.arrangedSubviews.first as? UIStackView,
           let label = headerStack.arrangedSubviews.first as? UILabel {
            label.text = "スタンプ: \(selectedStamp.displayText)"
        }
    }
    
    private func updateStampSelectionUI() {
        let accentGreen = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        
        UIView.animate(withDuration: 0.15) {
            for (stamp, btn) in self.stampButtons {
                if stamp == self.selectedStamp {
                    btn.backgroundColor = accentGreen
                    btn.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                } else {
                    btn.backgroundColor = UIColor.white.withAlphaComponent(0.1)
                    btn.transform = .identity
                }
            }
        }
    }
    
    func selectStampScale(_ scale: CGFloat, notifyDelegate: Bool = true) {
        selectedStampScale = scale
        if notifyDelegate {
            delegate?.didSelectStampScale(scale)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        updateStampScaleUI()
    }
    
    private func updateStampScaleUI() {
        let accentGreen = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        
        UIView.animate(withDuration: 0.15) {
            for (index, btn) in self.stampScaleButtons.enumerated() {
                let scale = self.orderedStampScales[index]
                if scale == self.selectedStampScale {
                    btn.backgroundColor = accentGreen
                } else {
                    btn.backgroundColor = UIColor.white.withAlphaComponent(0.1)
                }
            }
        }
    }

    private func updateNumberStampScaleUI() {
        let accentGreen = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        for (index, btn) in numberScaleButtons.enumerated() {
            guard index < orderedNumberScales.count else { continue }
            let scale = orderedNumberScales[index]
            let isSelected = (scale == selectedNumberScale)
            btn.backgroundColor = isSelected ? accentGreen : UIColor.white.withAlphaComponent(0.1)
            btn.tintColor = isSelected ? .white : UIColor.white.withAlphaComponent(0.7)
        }
    }
    
    @objc private func handleStampPan(_ gesture: UIPanGestureRecognizer) {
        guard let container = stampContainerRef else { return }
        let location = gesture.location(in: container)
        
        // Find stamp button under finger
        let allStamps = StampType.allCases
        for (index, btn) in orderedStampButtons.enumerated() {
            let btnFrame = btn.convert(btn.bounds, to: container)
            if btnFrame.contains(location) {
                let stamp = allStamps[index]
                if stamp != selectedStamp {
                    selectedStamp = stamp
                    updateStampSelectionUI()
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                break
            }
        }
        
        // On gesture end, notify delegate
        if gesture.state == .ended || gesture.state == .cancelled {
            delegate?.didSelectStamp(selectedStamp)
        }
    }
    
    @objc private func handleStampScalePan(_ gesture: UIPanGestureRecognizer) {
        guard let stack = stampScaleStackRef else { return }
        let location = gesture.location(in: stack)
        
        // Find which scale button is under finger
        for (index, btn) in stampScaleButtons.enumerated() {
            let btnFrame = btn.frame
            if btnFrame.contains(location) {
                let scale = orderedStampScales[index]
                if scale != selectedStampScale {
                    selectedStampScale = scale
                    updateStampScaleUI()
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                break
            }
        }
        
        // On gesture end, notify delegate
        if gesture.state == .ended || gesture.state == .cancelled {
            delegate?.didSelectStampScale(selectedStampScale)
        }
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
    
    @objc private func handlePenWidthPan(_ gesture: UIPanGestureRecognizer) {
        guard let stack = gesture.view else { return }
        let location = gesture.location(in: stack)
        let width = stack.bounds.width
        let count = CGFloat(orderedPenWidths.count)
        guard width > 0, count > 0 else { return }
        
        let segmentWidth = width / count
        let index = Int(floor(location.x / segmentWidth))
        let clampedIndex = max(0, min(orderedPenWidths.count - 1, index))
        let w = orderedPenWidths[clampedIndex]
        
        if w != selectedPenWidth {
            selectPenWidth(w)
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
        
        // Update Pen Width Buttons
        for (i, b) in penWidthButtons.enumerated() {
            guard i < orderedPenWidths.count else { continue }
            let width = orderedPenWidths[i]
            let isSelected = (width == selectedPenWidth)
            b.tintColor = isSelected ? .white : UIColor.white.withAlphaComponent(0.5)
            b.transform = isSelected ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
        }
        
        updateSelectionIndicatorPosition(animated: animated)
        updateColorSelectionIndicatorPosition(animated: animated)
        updateTextSizeIndicatorPosition(animated: animated)
        updateArrowStyleIndicatorPosition(animated: animated)
        updateMarkerWidthIndicatorPosition(animated: animated)
        updatePenWidthIndicatorPosition(animated: animated)
        updateShapeFillOpacityUI()
        updateNumberVisibilityUI()
        updateNumberFillOpacityUI()
        updateNumberStampScaleUI()
        updateNumberRotationUI()
        
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
        guard let btn = toolButtons[selectedTool], toolStackRef != nil else { return }
        
        let targetFrame = btn.frame.insetBy(dx: -2, dy: -2)
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
        
        let size: CGFloat = 26
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
    
    private func updatePenWidthIndicatorPosition(animated: Bool) {
        guard let stack = penWidthStackRef, !stack.isHidden else { return }
        guard let index = orderedPenWidths.firstIndex(of: selectedPenWidth), index < penWidthButtons.count else { return }
        
        let btn = penWidthButtons[index]
        let targetFrame = btn.frame.insetBy(dx: -4, dy: -4)
        if targetFrame.width == 0 || targetFrame.height == 0 { return }
        
        let updates = {
            self.penWidthSelectionIndicator.frame = targetFrame
            self.penWidthSelectionIndicator.layer.cornerRadius = min(targetFrame.width, targetFrame.height) / 2
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.beginFromCurrentState, .allowUserInteraction], animations: updates)
        } else {
            updates()
        }
    }
}
