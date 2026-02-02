import UIKit
import PencilKit
import AVFoundation

// MARK: - Enums & Protocols

enum MarkupTool: Int, CaseIterable {
    case pen, marker, eraser, text, arrow, rect, circle
}

// MARK: - Views (Internal)

class BaseAnnotationView: UIView {
    var id: UUID
    var isSelected: Bool = false { didSet { updateSelectionState() } }
    var onDelete: (() -> Void)?
    
    private let deleteButton = UIButton()
    
    init(id: UUID = UUID(), frame: CGRect) {
        self.id = id
        super.init(frame: frame)
        self.isUserInteractionEnabled = true
        setupView()
        setupDeleteButton()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func setupView() {}
    
    private func setupDeleteButton() {
        deleteButton.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        deleteButton.backgroundColor = .red
        deleteButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        deleteButton.tintColor = .white
        deleteButton.layer.cornerRadius = 12
        deleteButton.isHidden = true
        deleteButton.addAction(UIAction { [weak self] _ in self?.onDelete?() }, for: .touchUpInside)
        addSubview(deleteButton)
    }
    
    func updateSelectionState() {
        layer.borderColor = isSelected ? UIColor.green.cgColor : UIColor.clear.cgColor
        layer.borderWidth = isSelected ? 2 : 0
        deleteButton.isHidden = !isSelected
        
        // Ensure delete button stays on top and valid position
        bringSubviewToFront(deleteButton)
        
        // Simple positioning: Top-Right of bounds (offset)
        deleteButton.center = CGPoint(x: bounds.width, y: 0)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure delete button position updates nicely if bounds change
        if isSelected {
            deleteButton.center = CGPoint(x: bounds.width, y: 0)
            bringSubviewToFront(deleteButton)
        }
    }
    
    func hitsDeleteButton(_ point: CGPoint) -> Bool {
        return isSelected && !deleteButton.isHidden && deleteButton.frame.contains(point)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if hitsDeleteButton(point) { return true }
        return super.point(inside: point, with: event)
    }
}

class TextAnnotationView: BaseAnnotationView {
    var text: String { didSet { label.text = text; sizeToFit() } }
    var textColor: UIColor { didSet { label.textColor = textColor } }
    var fontSize: CGFloat { didSet { label.font = .systemFont(ofSize: fontSize, weight: .bold); sizeToFit() } }
    
    private let label = UILabel()
    private let bgView = UIView()
    
    init(id: UUID = UUID(), text: String, color: UIColor, fontSize: CGFloat) {
        self.text = text
        self.textColor = color
        self.fontSize = fontSize
        super.init(id: id, frame: .zero)
        sizeToFit()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func setupView() {
        addSubview(bgView)
        addSubview(label)
        
        label.numberOfLines = 0
        label.text = text // Fix: Ensure label text is set from property
        label.font = .systemFont(ofSize: fontSize, weight: .bold)
        label.textColor = textColor
        
        bgView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        bgView.layer.cornerRadius = 4
        bgView.isHidden = true // Only show when selected
    }
    
    override func sizeToFit() {
        let size = label.sizeThatFits(CGSize(width: 500, height: 1000))
        frame.size = CGSize(width: size.width + 20, height: size.height + 16)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        bgView.frame = bounds
        label.frame = bounds.insetBy(dx: 10, dy: 8)
    }
    
    override func updateSelectionState() {
        super.updateSelectionState() // Trigger Base delete button logic
        bgView.isHidden = !isSelected
        bgView.layer.borderColor = isSelected ? UIColor.green.cgColor : UIColor.clear.cgColor
        bgView.layer.borderWidth = isSelected ? 2 : 0
    }
}

class ArrowAnnotationView: BaseAnnotationView {
    var startPoint: CGPoint { didSet { setNeedsLayout() } }
    var endPoint: CGPoint { didSet { setNeedsLayout() } }
    var color: UIColor { didSet { shapeLayer.strokeColor = color.cgColor } }
    var lineWidth: CGFloat { didSet { shapeLayer.lineWidth = lineWidth } }
    var style: ArrowStyle { didSet { setNeedsLayout() } }
    
    private let shapeLayer = CAShapeLayer()
    private let startHandle = UIView()
    private let endHandle = UIView()
    
    init(id: UUID = UUID(), start: CGPoint, end: CGPoint, color: UIColor, lineWidth: CGFloat, style: ArrowStyle = .oneWay) {
        self.startPoint = start
        self.endPoint = end
        self.color = color
        self.lineWidth = lineWidth
        self.style = style
        super.init(id: id, frame: .zero)
        
        // Frame will be calculated by layout
        updateFrame()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func setupView() {
        layer.addSublayer(shapeLayer)
        
        setupHandle(startHandle)
        setupHandle(endHandle)
        addSubview(startHandle)
        addSubview(endHandle)
        
        shapeLayer.lineWidth = lineWidth
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = color.cgColor
        
        shapeLayer.shadowColor = UIColor.black.cgColor
        shapeLayer.shadowOpacity = 0.3
        shapeLayer.shadowOffset = CGSize(width: 0, height: 2)
        shapeLayer.shadowRadius = 2
    }
    
    private func setupHandle(_ v: UIView) {
        v.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        v.backgroundColor = .white
        v.layer.cornerRadius = 12
        v.layer.borderWidth = 3
        v.layer.borderColor = UIColor.green.cgColor
        v.isHidden = true
    }
    
    override func updateSelectionState() {
        super.updateSelectionState()
        startHandle.isHidden = !isSelected
        endHandle.isHidden = !isSelected
        shapeLayer.shadowColor = isSelected ? UIColor.green.cgColor : UIColor.black.cgColor
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Local coordinates
        let localStart = convert(startPoint, from: superview)
        let localEnd = convert(endPoint, from: superview)
        
        let path = UIBezierPath()
        path.move(to: localStart)
        path.addLine(to: localEnd)
        
        // Arrow Head
        let arrowLen: CGFloat = 20
        let arrowAngle: CGFloat = .pi / 6
        
        // End Arrow (for .oneWay and .twoWay)
        if style == .oneWay || style == .twoWay {
            let angle = atan2(localEnd.y - localStart.y, localEnd.x - localStart.x)
            let p1 = CGPoint(x: localEnd.x - arrowLen * cos(angle - arrowAngle), y: localEnd.y - arrowLen * sin(angle - arrowAngle))
            let p2 = CGPoint(x: localEnd.x - arrowLen * cos(angle + arrowAngle), y: localEnd.y - arrowLen * sin(angle + arrowAngle))
            
            path.move(to: localEnd); path.addLine(to: p1)
            path.move(to: localEnd); path.addLine(to: p2)
        }
        
        // Start Arrow (for .twoWay only)
        if style == .twoWay {
            let angle = atan2(localStart.y - localEnd.y, localStart.x - localEnd.x)
            let p1 = CGPoint(x: localStart.x - arrowLen * cos(angle - arrowAngle), y: localStart.y - arrowLen * sin(angle - arrowAngle))
            let p2 = CGPoint(x: localStart.x - arrowLen * cos(angle + arrowAngle), y: localStart.y - arrowLen * sin(angle + arrowAngle))
            
            path.move(to: localStart); path.addLine(to: p1)
            path.move(to: localStart); path.addLine(to: p2)
        }
        
        shapeLayer.path = path.cgPath
        
        startHandle.center = localStart
        endHandle.center = localEnd
    }
    
    func updateFrame() {
        // Calculate enclosing rect
        let minX = min(startPoint.x, endPoint.x) - 40
        let minY = min(startPoint.y, endPoint.y) - 40
        let maxX = max(startPoint.x, endPoint.x) + 40
        let maxY = max(startPoint.y, endPoint.y) + 40
        self.frame = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    enum ArrowHandle { case start, end, none }
    
    func hitTestHandle(_ point: CGPoint) -> ArrowHandle {
        guard isSelected else { return .none }
        
        // Check handles with generous hit area
        let hitRadius: CGFloat = 30
        
        let localStart = convert(startPoint, from: superview)
        let localEnd = convert(endPoint, from: superview)
        
        if distSq(point, localStart) < hitRadius * hitRadius { return .start }
        if distSq(point, localEnd) < hitRadius * hitRadius { return .end }
        
        return .none
    }
    
    func containsPoint(_ point: CGPoint) -> Bool {
        // Check delete button first
        if hitsDeleteButton(point) { return true }
        
        // Point in local coords
        let localStart = convert(startPoint, from: superview)
        let localEnd = convert(endPoint, from: superview)
        
        if isSelected {
            if hitTestHandle(point) != .none { return true }
        }
        
        // Distance to segment
        let l2 = distSq(localStart, localEnd)
        if l2 == 0 { return distSq(point, localStart) < 400 }
        
        var t = ((point.x - localStart.x) * (localEnd.x - localStart.x) + (point.y - localStart.y) * (localEnd.y - localStart.y)) / l2
        t = max(0, min(1, t))
        
        let proj = CGPoint(x: localStart.x + t * (localEnd.x - localStart.x), y: localStart.y + t * (localEnd.y - localStart.y))
        return distSq(point, proj) < 400 // 20px radius squared
    }
    
    private func distSq(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return (p1.x - p2.x)*(p1.x - p2.x) + (p1.y - p2.y)*(p1.y - p2.y)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return containsPoint(point)
    }
}

class ShapeAnnotationView: BaseAnnotationView {
    var shapeType: MarkupTool // .rect or .circle
    var color: UIColor { didSet { shapeLayer.strokeColor = color.cgColor } }
    var lineWidth: CGFloat { didSet { shapeLayer.lineWidth = lineWidth } }
    
    private let shapeLayer = CAShapeLayer()
    
    // Handles
    private let tl = UIView() // Top Left
    private let tr = UIView() // Top Right
    private let bl = UIView() // Bottom Left
    private let br = UIView() // Bottom Right
    
    init(id: UUID = UUID(), frame: CGRect, shapeType: MarkupTool, color: UIColor, lineWidth: CGFloat) {
        self.shapeType = shapeType
        self.color = color
        self.lineWidth = lineWidth
        super.init(id: id, frame: frame)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func setupView() {
        layer.addSublayer(shapeLayer)
        
        setupHandle(tl)
        setupHandle(tr)
        setupHandle(bl)
        setupHandle(br)
        
        addSubview(tl)
        addSubview(tr)
        addSubview(bl)
        addSubview(br)
        
        shapeLayer.lineWidth = lineWidth
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = color.cgColor
        shapeLayer.shadowColor = UIColor.black.cgColor
        shapeLayer.shadowOpacity = 0.3
        shapeLayer.shadowOffset = CGSize(width: 0, height: 2)
        shapeLayer.shadowRadius = 2
    }
    
    private func setupHandle(_ v: UIView) {
        v.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        v.backgroundColor = .white
        v.layer.cornerRadius = 10
        v.layer.borderWidth = 2
        v.layer.borderColor = UIColor.green.cgColor
        v.isHidden = true
    }
    
    override func updateSelectionState() {
        super.updateSelectionState()
        tl.isHidden = !isSelected
        tr.isHidden = !isSelected
        bl.isHidden = !isSelected
        br.isHidden = !isSelected
        shapeLayer.shadowColor = isSelected ? UIColor.green.cgColor : UIColor.black.cgColor
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let inset: CGFloat = 0
        let rect = bounds.insetBy(dx: inset, dy: inset)
        
        let path: UIBezierPath
        if shapeType == .circle {
            path = UIBezierPath(ovalIn: rect)
        } else {
            path = UIBezierPath(rect: rect)
        }
        
        shapeLayer.path = path.cgPath
        shapeLayer.frame = bounds
        
        tl.center = CGPoint(x: 0, y: 0)
        tr.center = CGPoint(x: bounds.width, y: 0)
        bl.center = CGPoint(x: 0, y: bounds.height)
        br.center = CGPoint(x: bounds.width, y: bounds.height)
    }
    
    enum Corner { case tl, tr, bl, br, none }
    
    func hitTestHandle(_ point: CGPoint) -> Corner {
        guard isSelected else { return .none }
        let hitRadius: CGFloat = 30
        
        func dist(_ p: CGPoint, _ v: UIView) -> CGFloat {
            let c = v.center
            return (p.x - c.x)*(p.x - c.x) + (p.y - c.y)*(p.y - c.y)
        }
        
        if dist(point, tl) < hitRadius*hitRadius { return .tl }
        if dist(point, tr) < hitRadius*hitRadius { return .tr }
        if dist(point, bl) < hitRadius*hitRadius { return .bl }
        if dist(point, br) < hitRadius*hitRadius { return .br }
        
        return .none
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if hitsDeleteButton(point) { return true }
        if isSelected && hitTestHandle(point) != .none { return true }
        return bounds.insetBy(dx: -10, dy: -10).contains(point)
    }
    
    func containsPoint(_ point: CGPoint) -> Bool {
        return self.point(inside: point, with: nil)
    }
}
        


// MARK: - Controller

class MarkupOverlayView: UIView {
    var isEraserMode: Bool = false
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        // If in eraser mode and we touched the empty overlay (not a subview/annotation), 
        // return nil to let the touch pass through to the canvas (drawing layer).
        if isEraserMode && view == self {
            return nil
        }
        return view
    }
}


class MarkupViewController: UIViewController, UIScrollViewDelegate, PKToolPickerObserver, MarkupToolbarDelegate, UIGestureRecognizerDelegate {
    
    // Public API
    var image: UIImage?
    var initialDrawing: PKDrawing?
    var initialData: MarkupData?
    
    var onSave: ((PKDrawing, MarkupData, UIImage) -> Void)?
    var onCancel: (() -> Void)?
    var onDirtyChange: ((Bool) -> Void)?
    
    var isDirty: Bool = false {
        didSet {
             onDirtyChange?(isDirty)
        }
    }
    

    
    // UI
    let scrollView = UIScrollView()
    let contentView = UIView()
    let imageView = UIImageView()
    let canvasView = PKCanvasView()
    let overlayView = MarkupOverlayView() // Hosts BaseAnnotationView
    let toolbar = MarkupToolbar()
    
    // Logic
    private let toolPicker = PKToolPicker()
    private var currentTool: MarkupTool = .arrow
    private var currentColor: UIColor = .red
    private var currentFontSize: CGFloat = 16 // Default Small
    private var currentArrowStyle: ArrowStyle = .oneWay
    private var currentMarkerWidth: CGFloat = 10 // Default Thin
    private var currentPenWidth: CGFloat = 1 // Default Medium
    
    private var lastLayoutRect: CGRect = .zero
    private var isDataLoaded = false
    
    // Interaction
    private var selectedAnnotation: BaseAnnotationView? {
        didSet {
            oldValue?.isSelected = false
            selectedAnnotation?.isSelected = true
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        setupViews()
        setupCanvas()
        setupOverlayInteraction()
        
        // Track undo changes
        undoManager?.registerUndo(withTarget: self) { _ in self.isDirty = true }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if scrollView.zoomScale == 1.0 {
            updateContentFrame()
            
            // Toolbar Layout handled by Auto Layout in setupViews()
            view.bringSubviewToFront(toolbar)
            
            let rect = AVMakeRect(aspectRatio: image?.size ?? .zero, insideRect: imageView.bounds)
            if rect.width > 0 && !isDataLoaded {
                loadData(in: rect)
                lastLayoutRect = rect
                isDataLoaded = true
            }
        }
    }
    
    func updateContentFrame() {
        scrollView.frame = view.bounds
        contentView.frame = view.bounds
        imageView.frame = contentView.bounds
        canvasView.frame = contentView.bounds
        overlayView.frame = contentView.bounds
        scrollView.contentSize = view.bounds.size
    }
    
    // MARK: - Setup
    
    func setupViews() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(imageView)
        contentView.addSubview(canvasView)
        contentView.addSubview(overlayView)
        
        // Toolbar with Auto Layout
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        
        NSLayoutConstraint.activate([
            toolbar.widthAnchor.constraint(equalToConstant: 300),
            toolbar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
            // Height is determined by intrinsic content size
        ])
        
        toolbar.delegate = self
        
        imageView.contentMode = .scaleAspectFit
        imageView.image = image
        
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.bouncesZoom = true
        
        // Fix: Allow 1-finger drawing (Overlay/Canvas) but require 2 fingers for scrolling
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        scrollView.delaysContentTouches = false
    }
    
    func setupCanvas() {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        
        toolPicker.addObserver(self)
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        
        setTool(.arrow) // Default to arrow tool
    }
    
    func setupOverlayInteraction() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        overlayView.addGestureRecognizer(tap)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self // Allow concurrent recognition
        overlayView.addGestureRecognizer(pan)
    }
    
    // MARK: - Public Methods
    
    func setTool(_ tool: MarkupTool) {
        currentTool = tool
        selectedAnnotation = nil
        
        switch tool {
        case .pen:
            canvasView.tool = PKInkingTool(.monoline, color: currentColor, width: currentPenWidth)
            canvasView.isUserInteractionEnabled = true
            overlayView.isUserInteractionEnabled = false
            overlayView.isEraserMode = false
        case .marker:
            // Fix: User requested HALF opacity. Original is naturally translucent (~0.5?). 
            // Setting alpha 0.4 on top gives ~0.2 visual opacity? Let's try 0.3 to be "half".
            let markerColor = currentColor.withAlphaComponent(0.45)
            canvasView.tool = PKInkingTool(.marker, color: markerColor, width: currentMarkerWidth)
            canvasView.isUserInteractionEnabled = true
            overlayView.isUserInteractionEnabled = false
            overlayView.isEraserMode = false
        case .eraser:
            canvasView.tool = PKEraserTool(.bitmap)
            canvasView.isUserInteractionEnabled = true
            overlayView.isUserInteractionEnabled = true // Allow tap to delete
            overlayView.isEraserMode = true
        case .text, .arrow, .rect, .circle:
            canvasView.tool = PKInkingTool(.pen, color: .clear, width: 0)
            canvasView.isUserInteractionEnabled = false
            overlayView.isUserInteractionEnabled = true
            overlayView.isEraserMode = false
        }
    }
    
    func setColor(_ color: UIColor) {
        currentColor = color
        setTool(currentTool) // Refresh tool
    }
    
    func save() {
        guard let image = image else { return }
        
        // Calc rect
        let rect = (lastLayoutRect.width > 0) ? lastLayoutRect : AVMakeRect(aspectRatio: image.size, insideRect: imageView.bounds)
        let scale = rect.width / image.size.width
        
        // Drawing Transform
        var transform = CGAffineTransform.identity
        transform = transform.scaledBy(x: 1/scale, y: 1/scale)
        transform = transform.translatedBy(x: -rect.origin.x, y: -rect.origin.y)
        let savedDrawing = canvasView.drawing.transformed(using: transform)
        
        // Annotations
        var texts: [TextAnnotationModel] = []
        var arrows: [ArrowAnnotationModel] = []
        var shapes: [ShapeAnnotationModel] = []
        
        for view in overlayView.subviews {
            if let tv = view as? TextAnnotationView {
                let normX = (tv.frame.origin.x - rect.minX) / rect.width
                let normY = (tv.frame.origin.y - rect.minY) / rect.height
                let normW = tv.frame.width / rect.width
                let normH = tv.frame.height / rect.height
                
                texts.append(TextAnnotationModel(
                    text: tv.text,
                    fontSize: tv.fontSize / scale,
                    x: normX, y: normY, width: normW, height: normH,
                    colorHex: tv.textColor.toHex()
                ))
            } else if let av = view as? ArrowAnnotationView {
                let normStart = CGPoint(
                    x: (av.startPoint.x - rect.minX) / rect.width,
                    y: (av.startPoint.y - rect.minY) / rect.height
                )
                let normEnd = CGPoint(
                    x: (av.endPoint.x - rect.minX) / rect.width,
                    y: (av.endPoint.y - rect.minY) / rect.height
                )
                
                arrows.append(ArrowAnnotationModel(
                    startX: normStart.x, startY: normStart.y,
                    endX: normEnd.x, endY: normEnd.y,
                    colorHex: av.color.toHex(),
                    lineWidth: av.lineWidth,
                    style: av.style
                ))
            } else if let sv = view as? ShapeAnnotationView {
                let normX = (sv.frame.origin.x - rect.minX) / rect.width
                let normY = (sv.frame.origin.y - rect.minY) / rect.height
                let normW = sv.frame.width / rect.width
                let normH = sv.frame.height / rect.height
                
                shapes.append(ShapeAnnotationModel(
                    type: (sv.shapeType == .circle) ? "circle" : "rect",
                    x: normX, y: normY, width: normW, height: normH,
                    colorHex: sv.color.toHex(),
                    lineWidth: sv.lineWidth
                ))
            }
        }
        
        let data = MarkupData(texts: texts, arrows: arrows, shapes: shapes)
        
        // Render Image
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let overlayImage = renderer.image { ctx in
            // Render logic aligned with View implementation
            
            for t in texts {
                let x = t.x * image.size.width
                let y = t.y * image.size.height
                let w = t.width * image.size.width
                let h = t.height * image.size.height
                let fontSize = t.fontSize
                
                let rect = CGRect(x: x, y: y, width: w, height: h)
                let insetX = 10.0 / scale
                let insetY = 8.0 / scale
                
                let textRect = rect.insetBy(dx: insetX, dy: insetY)
                
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                    .foregroundColor: t.uicolor
                ]
                t.text.draw(in: textRect, withAttributes: attrs)
            }
            
            for a in arrows {
                let start = CGPoint(x: a.startX * image.size.width, y: a.startY * image.size.height)
                let end = CGPoint(x: a.endX * image.size.width, y: a.endY * image.size.height)
                
                let path = UIBezierPath()
                path.move(to: start)
                path.addLine(to: end)
                
                let arrowLen: CGFloat = 20.0 / scale
                let arrowAngle: CGFloat = .pi / 6
                
                // End Arrow
                if a.style == .oneWay || a.style == .twoWay {
                    let angle = atan2(end.y - start.y, end.x - start.x)
                    let p1 = CGPoint(
                        x: end.x - arrowLen * cos(angle - arrowAngle),
                        y: end.y - arrowLen * sin(angle - arrowAngle)
                    )
                    let p2 = CGPoint(
                        x: end.x - arrowLen * cos(angle + arrowAngle),
                        y: end.y - arrowLen * sin(angle + arrowAngle)
                    )
                    path.move(to: end); path.addLine(to: p1)
                    path.move(to: end); path.addLine(to: p2)
                }
                
                // Start Arrow
                if a.style == .twoWay {
                    let angle = atan2(start.y - end.y, start.x - end.x)
                    let p1 = CGPoint(
                        x: start.x - arrowLen * cos(angle - arrowAngle),
                        y: start.y - arrowLen * sin(angle - arrowAngle)
                    )
                    let p2 = CGPoint(
                        x: start.x - arrowLen * cos(angle + arrowAngle),
                        y: start.y - arrowLen * sin(angle + arrowAngle)
                    )
                    path.move(to: start); path.addLine(to: p1)
                    path.move(to: start); path.addLine(to: p2)
                }
                
                
                a.uicolor.setStroke()
                // Fix: Scale line width for image resolution
                // Removed 1.5x multiplier to match screen appearance exactly
                path.lineWidth = a.lineWidth * (1.0 / scale)
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            }
            
            for s in shapes {
                let x = s.x * image.size.width
                let y = s.y * image.size.height
                let w = s.width * image.size.width
                let h = s.height * image.size.height
                let rect = CGRect(x: x, y: y, width: w, height: h)
                
                let path: UIBezierPath
                if s.type == "circle" {
                    path = UIBezierPath(ovalIn: rect)
                } else {
                    path = UIBezierPath(rect: rect)
                }
                
                s.uicolor.setStroke()
                // Fix: Scale line width for image resolution
                path.lineWidth = s.lineWidth * (1.0 / scale)
                path.stroke()
            }
        }
        
        onSave?(savedDrawing, data, overlayImage)
    }
    
    func undo() { canvasView.undoManager?.undo() }
    func redo() { canvasView.undoManager?.redo() }
    


    // MARK: - Interactions
    
    // Text Editing
    private var activeTextView: UITextView?
    private var activeTextAnnotation: TextAnnotationView?

    // MARK: - Interactions
    
    @objc func handleTap(_ g: UITapGestureRecognizer) {
        // If editing text, end it
        if activeTextView != nil {
            endEditingText()
            return
        }
        
        // Convert point to overlayView in case the gesture is attached elsewhere, 
        // essentially ensuring we work in overlay coordinates.
        let p = g.location(in: overlayView)
        
        // Hit Test (Reverse Z to find top-most)
        let hit = overlayView.subviews.reversed().compactMap { $0 as? BaseAnnotationView }.first { v in
            if let av = v as? ArrowAnnotationView {
                return av.containsPoint(overlayView.convert(p, to: av))
            }
            return v.frame.contains(p)
        }
        
        if let target = hit {
            if currentTool == .eraser {
                deleteAnnotation(target)
            } else {
                if target == selectedAnnotation, let tv = target as? TextAnnotationView {
                    // Start editing if already selected
                    startEditingText(for: tv)
                } else {
                    selectedAnnotation = target
                    updateToolbarForSelection(target)
                }
            }
            return
        }
        
        // Deselect if tapping empty space
        if selectedAnnotation != nil {
            selectedAnnotation = nil
        }
        
        // Create Text if tool is text
        if currentTool == .text {
            createText(at: p)
        }
    }
    
    // MARK: - Pan Logic (Arrow & Drag)
    
    // MARK: - Pan Logic (Arrow, Shape & Drag)
    
    private enum DragMode {
        case create
        case move
        case resizeArrowStart, resizeArrowEnd
        case resizeTL, resizeTR, resizeBL, resizeBR
    }
    
    private var dragMode: DragMode = .create
    private var activeArrow: ArrowAnnotationView?
    private var activeShape: ShapeAnnotationView?
    private var activePanTarget: UIView?
    
    private var panStartCenter: CGPoint?
    private var panOffset: CGPoint = .zero
    
    // For arrow moving
    private var arrowStartOrigin: CGPoint = .zero
    private var arrowEndOrigin: CGPoint = .zero
    
    // For shape creation/resizing
    private var shapeStartFrame: CGRect = .zero
    private var dragStartPoint: CGPoint = .zero

    @objc func handlePan(_ g: UIPanGestureRecognizer) {
        if currentTool == .eraser { return }
        
        // Abort if scrolling/zooming or using multiple fingers (which implies zoom intent)
        if scrollView.isDragging || scrollView.isZooming || g.numberOfTouches > 1 {
            g.state = .cancelled
            return
        }
        
        let p = g.location(in: overlayView)
        
        switch g.state {
        case .began:
            dragMode = .create // Default
            dragStartPoint = p
            
            // Priority 1: Check handles of CURRENT selection
            if let arrow = selectedAnnotation as? ArrowAnnotationView {
                let localP = overlayView.convert(p, to: arrow)
                let handle = arrow.hitTestHandle(localP)
                
                if handle == .start {
                    dragMode = .resizeArrowStart
                    activeArrow = arrow
                    return
                } else if handle == .end {
                    dragMode = .resizeArrowEnd
                    activeArrow = arrow
                    return
                }
            } else if let shape = selectedAnnotation as? ShapeAnnotationView {
                let localP = overlayView.convert(p, to: shape)
                let handle = shape.hitTestHandle(localP)
                
                if handle != .none {
                    activeShape = shape
                    shapeStartFrame = shape.frame
                    switch handle {
                    case .tl: dragMode = .resizeTL
                    case .tr: dragMode = .resizeTR
                    case .bl: dragMode = .resizeBL
                    case .br: dragMode = .resizeBR
                    default: break
                    }
                    return
                }
            }
            
            // Priority 1.5: Hit Selected Body -> Move
            if let selected = selectedAnnotation {
                 var isHit = false
                 if let av = selected as? ArrowAnnotationView {
                     isHit = av.containsPoint(overlayView.convert(p, to: av))
                 } else if let sv = selected as? ShapeAnnotationView {
                     isHit = sv.containsPoint(overlayView.convert(p, to: sv))
                 } else {
                     isHit = selected.frame.contains(p)
                 }
                 
                 if isHit {
                     dragMode = .move
                     activePanTarget = selected
                     activeArrow = selected as? ArrowAnnotationView
                     activeShape = selected as? ShapeAnnotationView
                     
                     panStartCenter = selected.center
                     panOffset = p // Start point of drag for calculations
                     
                     if let av = activeArrow {
                         arrowStartOrigin = av.startPoint
                         arrowEndOrigin = av.endPoint
                     }
                     return
                 }
            }
            
            // Priority 2: Create new Item
            if currentTool == .arrow {
                dragMode = .create
                selectedAnnotation = nil
                let arrow = ArrowAnnotationView(start: p, end: p, color: currentColor, lineWidth: 1.5, style: currentArrowStyle)
                addAnnotation(arrow)
                activeArrow = arrow
                return
            } else if currentTool == .rect || currentTool == .circle {
                dragMode = .create
                selectedAnnotation = nil
                let shape = ShapeAnnotationView(frame: CGRect(origin: p, size: .zero), shapeType: currentTool, color: currentColor, lineWidth: 1.5)
                addAnnotation(shape)
                activeShape = shape
                dragStartPoint = p // Origin
                return
            }
            
            // Priority 3: Select & Move other items
             let hit = overlayView.subviews.reversed().compactMap { $0 as? BaseAnnotationView }.first { v in
                if let av = v as? ArrowAnnotationView {
                    return av.containsPoint(overlayView.convert(p, to: av))
                } else if let sv = v as? ShapeAnnotationView {
                    return sv.containsPoint(overlayView.convert(p, to: sv))
                }
                return v.frame.contains(p)
            }
            
            if let target = hit {
                selectedAnnotation = target
                dragMode = .move
                activePanTarget = target
                activeArrow = target as? ArrowAnnotationView
                activeShape = target as? ShapeAnnotationView
                
                panStartCenter = target.center
                panOffset = p
                
                if let av = activeArrow {
                    arrowStartOrigin = av.startPoint
                    arrowEndOrigin = av.endPoint
                }
            } else {
                selectedAnnotation = nil
            }
            
        case .changed:
            let deltaX = p.x - dragStartPoint.x
            let deltaY = p.y - dragStartPoint.y
            
            switch dragMode {
            case .create:
                if let arrow = activeArrow {
                    arrow.endPoint = p
                    arrow.updateFrame()
                } else if let shape = activeShape {
                    // Normalize rect from start point to current p
                    let x = min(dragStartPoint.x, p.x)
                    let y = min(dragStartPoint.y, p.y)
                    let w = abs(p.x - dragStartPoint.x)
                    let h = abs(p.y - dragStartPoint.y)
                    shape.frame = CGRect(x: x, y: y, width: w, height: h)
                }
                
            case .resizeArrowStart:
                activeArrow?.startPoint = p
                activeArrow?.updateFrame()
            case .resizeArrowEnd:
                activeArrow?.endPoint = p
                activeArrow?.updateFrame()
                
            case .resizeTL, .resizeTR, .resizeBL, .resizeBR:
                guard let shape = activeShape else { return }
                // Calculate new frame based on handle
                // This is a simple implementation; rigorous one handles flipping
                var newX = shapeStartFrame.minX
                var newY = shapeStartFrame.minY
                var newW = shapeStartFrame.width
                var newH = shapeStartFrame.height
                
                let dx = p.x - dragStartPoint.x
                let dy = p.y - dragStartPoint.y
                
                switch dragMode {
                case .resizeTL:
                    newX += dx; newY += dy; newW -= dx; newH -= dy
                case .resizeTR:
                    newY += dy; newW += dx; newH -= dy
                case .resizeBL:
                    newX += dx; newW -= dx; newH += dy
                case .resizeBR:
                    newW += dx; newH += dy
                default: break
                }
                
                if newW > 10 && newH > 10 { // Min size constraint
                    shape.frame = CGRect(x: newX, y: newY, width: newW, height: newH)
                }
                
            case .move:
                // Move logic
                let moveDx = p.x - panOffset.x
                let moveDy = p.y - panOffset.y
                
                if let arrow = activeArrow {
                    arrow.startPoint = CGPoint(x: arrowStartOrigin.x + moveDx, y: arrowStartOrigin.y + moveDy)
                    arrow.endPoint = CGPoint(x: arrowEndOrigin.x + moveDx, y: arrowEndOrigin.y + moveDy)
                    arrow.updateFrame()
                } else if let target = activePanTarget {
                    // Standard view move (Text, Shape)
                    // Note: panOffset for standard view was stored as 'center - touch', so we can just use that
                    // Actually, wait. My prev logic for text was:
                    // panOffset = center - p
                    // newCenter = p + panOffset
                    // But here I unified arrow logic.
                    // Let's check init logic.
                    // If Arrow: panOffset = p (start touch). moveDx = p - start. Add delta.
                    // If Target: panStartCenter = target.center.
                    // Let's use:
                    
                     let newCenter = CGPoint(x: panStartCenter!.x + (p.x - panOffset.x), y: panStartCenter!.y + (p.y - panOffset.y))
                     // Wait, if panOffset is P (start point), then delta is p - P.
                     // So center = startCenter + delta.
                     target.center = newCenter
                }
            }
            
        case .ended:
            activeArrow = nil
            activeShape = nil
            activePanTarget = nil
            
        default: break
        }
    }
    
    // MARK: - Text Editing Logic
    
    func createText(at p: CGPoint) {
        let t = TextAnnotationView(text: "", color: currentColor, fontSize: currentFontSize)
        t.center = p
        // Minimal size for empty
        t.frame.size = CGSize(width: 50, height: 40)
        
        addAnnotation(t)
        selectedAnnotation = t
        startEditingText(for: t)
    }
    
    func startEditingText(for view: TextAnnotationView) {
        // Prevent double edit
        if activeTextView != nil { endEditingText() }
        
        activeTextAnnotation = view
        view.isHidden = true // Hide original view
        
        let tv = UITextView()
        tv.text = view.text
        tv.textColor = view.textColor
        tv.backgroundColor = .clear // Transparent
        tv.delegate = self
        tv.isScrollEnabled = false
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10) // Match padding
        tv.textContainer.lineFragmentPadding = 0
        
        // Input Accessory View (Done Button)
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "完了", style: .done, target: self, action: #selector(dismissKeyboard))
        done.tintColor = .green
        toolbar.items = [flex, done]
        tv.inputAccessoryView = toolbar
        
        // Calculate Frame in self.view coordinates (to handle Zoom)
        updateActiveTextViewFrame(tv, for: view)
        
        self.view.addSubview(tv)
        tv.becomeFirstResponder()
        activeTextView = tv
        
        // Register Keyboard Notifications
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    func updateActiveTextViewFrame(_ tv: UITextView, for view: TextAnnotationView) {
        let zoom = scrollView.zoomScale
        let scaledFontSize = view.fontSize * zoom
        tv.font = .systemFont(ofSize: scaledFontSize, weight: .bold)
        
        // Position calculation
        // View frame is in overlayView (zoomed content)
        // We want frame in self.view (window coords)
        let frameInView = overlayView.convert(view.frame, to: self.view)
        tv.frame = frameInView
    }
    
    @objc func dismissKeyboard() {
        endEditingText()
    }
    
    func endEditingText() {
        guard let tv = activeTextView, let annotationView = activeTextAnnotation else { return }
        
        // Remove observers
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        
        let newText = tv.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle changes
        if newText.isEmpty {
            deleteAnnotation(annotationView)
        } else {
            let oldText = annotationView.text
            if oldText != newText {
                 undoManager?.registerUndo(withTarget: self, handler: { target in
                    // Undo Action
                    annotationView.text = oldText
                    // Size update handled by text didSet
                 })
            }
            
            annotationView.text = newText
            annotationView.isHidden = false
        }
        
        tv.resignFirstResponder()
        tv.removeFromSuperview()
        activeTextView = nil
        activeTextAnnotation = nil
        
        // Reset Insets
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }

    // MARK: - Keyboard Handling
    
    @objc func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let tv = activeTextView else { return }
        
        // Convert keyboard frame to view coordinates
        let keyboardFrameInView = view.convert(keyboardFrame, from: nil)
        
        // Calculate overlap
        let intersection = keyboardFrameInView.intersection(view.bounds)
        let keyboardHeight = intersection.height
        
        // Adjust scroll view inset so we can scroll content up
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight, right: 0)
        scrollView.scrollIndicatorInsets = scrollView.contentInset
        
        // Check if text view is covered
        let tvFrame = tv.frame
        if tvFrame.intersects(keyboardFrameInView) {
             // We need to scroll the content so that the text view moves up.
             // But the text view is on self.view. It won't move automatically.
             // However, scrollViewDidScroll updates the text view frame.
             // So if we scroll the scrollView, the text view SHOULD move.
             
             // Calculate how much to scroll
             let visibleHeight = view.bounds.height - keyboardHeight
             let targetY = tvFrame.maxY + 20 // 20px padding
             
             if targetY > visibleHeight {
                 let scrollAmount = targetY - visibleHeight
                 var offset = scrollView.contentOffset
                 offset.y += scrollAmount
                 // Clamp
                 let maxOffset = scrollView.contentSize.height - scrollView.bounds.height + keyboardHeight
                 offset.y = min(offset.y, maxOffset)
                 
                 scrollView.setContentOffset(offset, animated: true)
             }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }
    
    // MARK: - Helpers
    
    func addAnnotation(_ v: BaseAnnotationView) {
        overlayView.addSubview(v)
        isDirty = true
        
        // Wire up delete
        v.onDelete = { [weak self] in
            self?.deleteAnnotation(v)
            self?.selectedAnnotation = nil
        }
        
        undoManager?.registerUndo(withTarget: self, handler: { target in
            target.deleteAnnotation(v)
        })
    }
    
    func deleteAnnotation(_ v: BaseAnnotationView) {
        v.removeFromSuperview()
        isDirty = true
        undoManager?.registerUndo(withTarget: self, handler: { target in
            target.addAnnotation(v)
        })
    }
    
    func loadData(in rect: CGRect) {
        guard let data = initialData else { return }
        
        if let drawing = initialDrawing {
            let scale = rect.width / (image?.size.width ?? 1)
            var t = CGAffineTransform.identity
            t = t.translatedBy(x: rect.minX, y: rect.minY)
            t = t.scaledBy(x: scale, y: scale)
            canvasView.drawing = drawing.transformed(using: t)
        }
        
        for t in data.texts {
            let x = t.x * rect.width + rect.minX
            let y = t.y * rect.height + rect.minY
            let v = TextAnnotationView(text: t.text, color: t.uicolor, fontSize: t.fontSize * (rect.width / (image?.size.width ?? 1)))
            v.frame.origin = CGPoint(x: x, y: y)
            
            v.onDelete = { [weak self] in
                self?.deleteAnnotation(v)
                self?.selectedAnnotation = nil
            }
            
            overlayView.addSubview(v)
        }
        
        for a in data.arrows {
            let s = CGPoint(x: a.startX * rect.width + rect.minX, y: a.startY * rect.height + rect.minY)
            let e = CGPoint(x: a.endX * rect.width + rect.minX, y: a.endY * rect.height + rect.minY)
            let v = ArrowAnnotationView(start: s, end: e, color: a.uicolor, lineWidth: a.lineWidth, style: a.style)
            
            v.onDelete = { [weak self] in
                self?.deleteAnnotation(v)
                self?.selectedAnnotation = nil
            }
            
            overlayView.addSubview(v)
        }
        
        for s in data.shapes {
            let x = s.x * rect.width + rect.minX
            let y = s.y * rect.height + rect.minY
            let w = s.width * rect.width
            let h = s.height * rect.height
            
            let frame = CGRect(x: x, y: y, width: w, height: h)
            let type: MarkupTool = (s.type == "circle") ? .circle : .rect
            
            let v = ShapeAnnotationView(frame: frame, shapeType: type, color: s.uicolor, lineWidth: s.lineWidth)
            
            v.onDelete = { [weak self] in
                self?.deleteAnnotation(v)
                self?.selectedAnnotation = nil
            }
            
            overlayView.addSubview(v)
        }
    }
    
    func didSelectTool(_ tool: MarkupTool) {
        // If editing text, end it when switching tools
        if activeTextView != nil { endEditingText() }
        setTool(tool)
        
        // Animate layout changes if toolbar resizes
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    func didSelectColor(_ color: UIColor) {
        // Capture selection because setColor() calls setTool() which clears selectedAnnotation
        let previouslySelected = selectedAnnotation
        
        setColor(color)
        
        // Restore selection and update color
        if let selected = previouslySelected {
            selectedAnnotation = selected
            
            if let tv = selected as? TextAnnotationView {
                tv.textColor = color
            } else if let av = selected as? ArrowAnnotationView {
                av.color = color
            } else if let sv = selected as? ShapeAnnotationView {
                sv.color = color
            }
        }
    }
    
    func didSelectTextSize(_ size: CGFloat) {
        currentFontSize = size
        if let tv = selectedAnnotation as? TextAnnotationView {
            tv.fontSize = size
            // If currently editing, might need to update the TextView font too?
            // The TextAnnotationView updates label font. 
            // If activeTextView is present, we should update it.
            if let activeTV = activeTextView, activeTextAnnotation == tv {
                activeTV.font = .systemFont(ofSize: size * scrollView.zoomScale, weight: .bold)
                updateActiveTextViewFrame(activeTV, for: tv)
            }
        }
    }
    
    // MARK: - Toolbar Synchronization
    
    func updateToolbarForSelection(_ selection: BaseAnnotationView?) {
        guard let selection = selection else { return }
        
        // 1. Determine Tool & Properties
        if let tv = selection as? TextAnnotationView {
            currentTool = .text
            currentColor = tv.textColor
            currentFontSize = tv.fontSize
            
            toolbar.selectTool(.text, notifyDelegate: false)
            toolbar.selectColor(currentColor, notifyDelegate: false)
            toolbar.selectTextSize(currentFontSize, notifyDelegate: false)
            
        } else if let av = selection as? ArrowAnnotationView {
            currentTool = .arrow
            currentColor = av.color
            currentArrowStyle = av.style
            
            toolbar.selectTool(.arrow, notifyDelegate: false)
            toolbar.selectColor(currentColor, notifyDelegate: false)
            toolbar.selectArrowStyle(currentArrowStyle, notifyDelegate: false)
            
        } else if let sv = selection as? ShapeAnnotationView {
            currentTool = sv.shapeType
            currentColor = sv.color
            
            toolbar.selectTool(sv.shapeType, notifyDelegate: false)
            toolbar.selectColor(currentColor, notifyDelegate: false)
        }
        
        // Force layout update because disabling notifyDelegate skips the delegate's layout call
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    func didSelectArrowStyle(_ style: ArrowStyle) {
        currentArrowStyle = style
        if let av = selectedAnnotation as? ArrowAnnotationView {
            av.style = style
        }
    }
    
    func didSelectMarkerWidth(_ width: CGFloat) {
        currentMarkerWidth = width
        if currentTool == .marker {
             // Apply opacity fix here too
            let markerColor = currentColor.withAlphaComponent(0.45)
            canvasView.tool = PKInkingTool(.marker, color: markerColor, width: currentMarkerWidth)
        }
    }
    
    func didSelectPenWidth(_ width: CGFloat) {
        currentPenWidth = width
        if currentTool == .pen {
            canvasView.tool = PKInkingTool(.monoline, color: currentColor, width: currentPenWidth)
        }
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if let tv = activeTextView, let av = activeTextAnnotation {
            updateActiveTextViewFrame(tv, for: av)
        }
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return contentView
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let tv = activeTextView, let av = activeTextAnnotation {
            updateActiveTextViewFrame(tv, for: av)
        }
    }
    // MARK: - UIGestureRecognizerDelegate
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow Overlay Pan to coexist with ScrollView Pan/Pinch
        // (ScrollView pan requires 2 fingers, Overlay Pan max 1 finger - but we allow them to negotiate)
        if gestureRecognizer.view == overlayView {
            return true
        }
        return false
    }

}

extension MarkupViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        guard let view = activeTextAnnotation else { return }
        
        // Update the model (TextAnnotationView)
        // We set the text on the hidden view to trigger sizeToFit
        view.text = textView.text
        isDirty = true // Track text change
        
        // Now update the activeTextView frame to match the new size of the view
        updateActiveTextViewFrame(textView, for: view)
    }
}

extension MarkupViewController: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        isDirty = true
    }
}

