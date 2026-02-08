import UIKit
import PencilKit
import AVFoundation

// MARK: - Enums & Protocols

enum MarkupTool: Int, CaseIterable {
    case pen, marker, eraser, text, arrow, rect, circle, stamp, numberStamp
}

// 数字スタンプの図形タイプ
enum NumberShape: String, Codable, CaseIterable {
    case circle = "circle"      // 丸 ○
    case square = "square"      // 正方形 □
    case rectangle = "rectangle" // 横長長方形 ▭
    case diamond = "diamond"    // ひし形 ◇
    case triangle = "triangle"  // 三角 △
    
    var displayIcon: String {
        switch self {
        case .circle: return "○"
        case .square: return "□"
        case .rectangle: return "▭"
        case .diamond: return "◇"
        case .triangle: return "△"
        }
    }
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

class StampAnnotationView: BaseAnnotationView {
    var stampType: StampType { didSet { updateLabelText(); sizeToFit() } }
    var stampColor: UIColor { didSet { label.textColor = stampColor } }
    var scale: CGFloat { didSet { updateFontSize(); sizeToFit() } }
    var numberValue: Int? { didSet { updateLabelText(); sizeToFit() } }
    
    private let label = UILabel()
    private let bgView = UIView()
    private let baseSize: CGFloat = 32
    
    init(id: UUID = UUID(), stampType: StampType, color: UIColor, scale: CGFloat = 1.0, numberValue: Int? = nil) {
        self.stampType = stampType
        self.stampColor = color
        self.scale = scale
        self.numberValue = numberValue
        super.init(id: id, frame: .zero)
        sizeToFit()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func setupView() {
        addSubview(bgView)
        addSubview(label)
        
        label.textAlignment = .center
        updateLabelText()
        updateFontSize()
        label.textColor = stampColor
        
        bgView.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        bgView.layer.cornerRadius = 6
        bgView.isHidden = true
    }
    
    private func updateLabelText() {
        if stampType.isNumbered, let num = numberValue {
            label.text = circledNumber(num)
        } else {
            label.text = stampType.displayText
        }
    }
    
    private func circledNumber(_ num: Int) -> String {
        // ①-⑳ (1-20) と ㉑-㊿ (21-50) に対応
        let circledNumbers1to20 = ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩",
                                   "⑪", "⑫", "⑬", "⑭", "⑮", "⑯", "⑰", "⑱", "⑲", "⑳"]
        let circledNumbers21to50 = ["㉑", "㉒", "㉓", "㉔", "㉕", "㉖", "㉗", "㉘", "㉙", "㉚",
                                    "㉛", "㉜", "㉝", "㉞", "㉟", "㊱", "㊲", "㊳", "㊴", "㊵",
                                    "㊶", "㊷", "㊸", "㊹", "㊺", "㊻", "㊼", "㊽", "㊾", "㊿"]
        if num >= 1 && num <= 20 {
            return circledNumbers1to20[num - 1]
        } else if num >= 21 && num <= 50 {
            return circledNumbers21to50[num - 21]
        } else {
            return "(\(num))"
        }
    }
    
    private func updateFontSize() {
        label.font = .systemFont(ofSize: baseSize * scale, weight: .bold)
    }
    
    override func sizeToFit() {
        let size = label.sizeThatFits(CGSize(width: 500, height: 500))
        frame.size = CGSize(width: size.width + 16, height: size.height + 12)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        bgView.frame = bounds
        label.frame = bounds.insetBy(dx: 8, dy: 6)
    }
    
    override func updateSelectionState() {
        super.updateSelectionState()
        bgView.isHidden = !isSelected
        bgView.layer.borderColor = isSelected ? UIColor.green.cgColor : UIColor.clear.cgColor
        bgView.layer.borderWidth = isSelected ? 2 : 0
    }
}

// MARK: - 数字スタンプビュー（図形付き）

class NumberStampAnnotationView: BaseAnnotationView {
    var numberShape: NumberShape { didSet { setNeedsDisplay(); sizeToFit() } }
    var stampColor: UIColor { didSet { setNeedsDisplay() } }
    var scale: CGFloat { didSet { sizeToFit(); setNeedsDisplay() } }
    var numberValue: Int { didSet { label.text = "\(numberValue)"; sizeToFit() } }
    var showsNumber: Bool { didSet { label.isHidden = !showsNumber } }
    var fillOpacity: CGFloat { didSet { setNeedsDisplay() } }
    var rotationAngle: CGFloat { didSet { applyRotationState(); setNeedsDisplay() } }
    
    private let label = UILabel()
    private let bgView = UIView()
    private let baseSize: CGFloat = 28
    
    init(
        id: UUID = UUID(),
        shape: NumberShape,
        color: UIColor,
        scale: CGFloat = 1.0,
        number: Int,
        showsNumber: Bool = true,
        fillOpacity: CGFloat = 1.0,
        rotationAngle: CGFloat = 0
    ) {
        self.numberShape = shape
        self.stampColor = color
        self.scale = scale
        self.numberValue = number
        self.showsNumber = showsNumber
        self.fillOpacity = max(0.0, min(1.0, fillOpacity))
        self.rotationAngle = rotationAngle
        super.init(id: id, frame: .zero)
        sizeToFit()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func setupView() {
        backgroundColor = .clear
        addSubview(bgView)
        addSubview(label)
        
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.text = "\(numberValue)"
        label.font = .systemFont(ofSize: resolvedFontSize(), weight: .bold)
        label.textColor = .white
        label.isHidden = !showsNumber
        
        bgView.backgroundColor = .clear
        bgView.isHidden = true
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        
        let inset: CGFloat = 2
        let drawRect = CGRect(
            x: -rect.width / 2 + inset,
            y: -rect.height / 2 + inset,
            width: rect.width - inset * 2,
            height: rect.height - inset * 2
        )

        ctx.saveGState()
        ctx.translateBy(x: rect.midX, y: rect.midY)
        ctx.rotate(by: rotationAngle)
        
        // 図形を描画
        ctx.setFillColor(stampColor.withAlphaComponent(fillOpacity).cgColor)
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(2)
        
        switch numberShape {
        case .circle:
            let diameter = min(drawRect.width, drawRect.height)
            let circleRect = CGRect(
                x: -diameter / 2,
                y: -diameter / 2,
                width: diameter,
                height: diameter
            )
            ctx.fillEllipse(in: circleRect)
            ctx.strokeEllipse(in: circleRect)
        case .square:
            let side = min(drawRect.width, drawRect.height)
            let squareRect = CGRect(
                x: -side / 2,
                y: -side / 2,
                width: side,
                height: side
            )
            ctx.fill(squareRect)
            ctx.stroke(squareRect)
        case .rectangle:
            let horizontalRect = CGRect(
                x: drawRect.minX,
                y: drawRect.midY - (drawRect.height * 0.35),
                width: drawRect.width,
                height: drawRect.height * 0.7
            )
            ctx.fill(horizontalRect)
            ctx.stroke(horizontalRect)
        case .diamond:
            let center = CGPoint.zero
            let halfW = drawRect.width / 2
            let halfH = drawRect.height / 2
            ctx.beginPath()
            ctx.move(to: CGPoint(x: center.x, y: center.y - halfH))
            ctx.addLine(to: CGPoint(x: center.x + halfW, y: center.y))
            ctx.addLine(to: CGPoint(x: center.x, y: center.y + halfH))
            ctx.addLine(to: CGPoint(x: center.x - halfW, y: center.y))
            ctx.closePath()
            ctx.drawPath(using: .fillStroke)
        case .triangle:
            ctx.beginPath()
            ctx.move(to: CGPoint(x: drawRect.midX, y: drawRect.minY))
            ctx.addLine(to: CGPoint(x: drawRect.maxX, y: drawRect.maxY))
            ctx.addLine(to: CGPoint(x: drawRect.minX, y: drawRect.maxY))
            ctx.closePath()
            ctx.drawPath(using: .fillStroke)
        }

        ctx.restoreGState()
    }
    
    override func sizeToFit() {
        label.font = .systemFont(ofSize: resolvedFontSize(), weight: .bold)
        let size = label.sizeThatFits(CGSize(width: 500, height: 500))
        let currentCenter = center
        let isAttached = (superview != nil)
        
        switch numberShape {
        case .circle, .square, .diamond:
            let dimension = max(size.width, size.height) + 12
            bounds.size = CGSize(width: dimension, height: dimension)
        case .triangle:
            let dimension = max(size.width, size.height) + 16
            bounds.size = CGSize(width: dimension, height: dimension)
        case .rectangle:
            let h = size.height + 12
            let w = max(size.width + 24, h * 1.6)
            bounds.size = CGSize(width: w, height: h)
        }

        if isAttached {
            center = currentCenter
        }
        setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        bgView.frame = bounds
        var labelFrame = bounds
        if numberShape == .triangle {
            let yOffset = bounds.height * 0.08
            labelFrame.origin.y += yOffset
            labelFrame.size.height -= yOffset
        }
        label.frame = labelFrame
        applyRotationState()
    }
    
    override func updateSelectionState() {
        super.updateSelectionState()
        bgView.isHidden = !isSelected
        bgView.layer.borderColor = isSelected ? UIColor.green.cgColor : UIColor.clear.cgColor
        bgView.layer.borderWidth = isSelected ? 2 : 0
        bgView.layer.cornerRadius = numberShape == .circle ? bounds.width / 2 : 0
    }

    private func applyRotationState() {
        label.transform = CGAffineTransform(rotationAngle: rotationAngle)
    }

    private func resolvedFontSize() -> CGFloat {
        max(baseSize * scale, 9)
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
    
    // Toast Notification
    private let toastContainer = UIView()
    private let toastIconView = UIImageView()
    private let toastLabel = UILabel()
    private let toastColorView = UIView()
    private var toastHideTimer: Timer?
    
    // Logic
    private let toolPicker = PKToolPicker()
    private var currentTool: MarkupTool = .arrow
    private var currentColor: UIColor = .red
    private var currentFontSize: CGFloat = 16 // Default Small
    private var currentArrowStyle: ArrowStyle = .oneWay
    private var currentMarkerWidth: CGFloat = 10 // Default Thin
    private var currentPenWidth: CGFloat = 1 // Default Medium
    private var currentStamp: StampType = .check
    private var currentStampScale: CGFloat = 0.5 // Default Small
    private var currentNumberShape: NumberShape = .circle // Default Number Shape
    private var currentNumberStampScale: CGFloat = 0.5 // Number stamp L (old S size)
    private var currentNumberVisible: Bool = true
    private var currentNumberFillOpacity: CGFloat = 1.0
    private var currentNumberRotation: CGFloat = 0
    private var rotationGestureStartAngle: CGFloat = 0
    
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
        
        let isCompactPhoneWidth = UIScreen.main.bounds.width <= 320
        let widthMultiplier: CGFloat = isCompactPhoneWidth ? 0.98 : 0.92
        let horizontalInset: CGFloat = isCompactPhoneWidth ? 6 : 12
        let maxToolbarWidth: CGFloat = isCompactPhoneWidth ? 360 : 420
        let bottomInset: CGFloat = isCompactPhoneWidth ? -8 : -20
        
        let widthConstraint = toolbar.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: widthMultiplier)
        widthConstraint.priority = .defaultHigh
        
        NSLayoutConstraint.activate([
            widthConstraint,
            toolbar.widthAnchor.constraint(lessThanOrEqualToConstant: maxToolbarWidth),
            toolbar.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: horizontalInset),
            toolbar.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -horizontalInset),
            toolbar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: bottomInset)
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
        
        // Setup Toast Notification
        setupToast()
    }
    
    func setupCanvas() {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        
        // ダークモードでの白黒反転を防止
        canvasView.overrideUserInterfaceStyle = .light
        
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
    
    // MARK: - Toast Notification
    
    private func setupToast() {
        // Container - Fixed width to prevent layout shift
        toastContainer.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        toastContainer.layer.cornerRadius = 16
        toastContainer.alpha = 0
        toastContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toastContainer)
        
        // Icon (left side)
        toastIconView.tintColor = .white
        toastIconView.contentMode = .scaleAspectFit
        toastIconView.translatesAutoresizingMaskIntoConstraints = false
        toastContainer.addSubview(toastIconView)
        
        // Label (center, for tool name)
        toastLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        toastLabel.textColor = .white
        toastLabel.textAlignment = .center
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        toastContainer.addSubview(toastLabel)
        
        // Color indicator (right side, fixed position)
        toastColorView.layer.cornerRadius = 10
        toastColorView.layer.borderWidth = 1.5
        toastColorView.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        toastColorView.translatesAutoresizingMaskIntoConstraints = false
        toastContainer.addSubview(toastColorView)
        
        NSLayoutConstraint.activate([
            toastContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            toastContainer.heightAnchor.constraint(equalToConstant: 44),
            toastContainer.widthAnchor.constraint(equalToConstant: 160), // Wider for icon
            
            // Icon at left
            toastIconView.leadingAnchor.constraint(equalTo: toastContainer.leadingAnchor, constant: 12),
            toastIconView.centerYAnchor.constraint(equalTo: toastContainer.centerYAnchor),
            toastIconView.widthAnchor.constraint(equalToConstant: 20),
            toastIconView.heightAnchor.constraint(equalToConstant: 20),
            
            // Label center
            toastLabel.leadingAnchor.constraint(equalTo: toastIconView.trailingAnchor, constant: 8),
            toastLabel.trailingAnchor.constraint(equalTo: toastColorView.leadingAnchor, constant: -8),
            toastLabel.centerYAnchor.constraint(equalTo: toastContainer.centerYAnchor),
            
            // Color indicator at fixed right position
            toastColorView.trailingAnchor.constraint(equalTo: toastContainer.trailingAnchor, constant: -12),
            toastColorView.centerYAnchor.constraint(equalTo: toastContainer.centerYAnchor),
            toastColorView.widthAnchor.constraint(equalToConstant: 20),
            toastColorView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    private func showToast(tool: MarkupTool, color: UIColor) {
        // Cancel previous timer
        toastHideTimer?.invalidate()
        
        // Tool name and icon
        let toolName: String
        let iconName: String
        switch tool {
        case .pen: toolName = "ペン"; iconName = "pencil"
        case .marker: toolName = "マーカー"; iconName = "highlighter"
        case .eraser: toolName = "消しゴム"; iconName = "eraser"
        case .text: toolName = "テキスト"; iconName = "textformat"
        case .arrow: toolName = "矢印"; iconName = "arrow.up.right"
        case .rect: toolName = "四角形"; iconName = "rectangle"
        case .circle: toolName = "円"; iconName = "circle"
        case .stamp: toolName = "スタンプ"; iconName = "seal"
        case .numberStamp: toolName = "番号"; iconName = "number.circle"
        }
        
        // Set icon and tool name
        toastIconView.image = UIImage(systemName: iconName)
        toastLabel.text = toolName
        
        // Hide color indicator for eraser (no color needed)
        let showColor = (tool != .eraser)
        toastColorView.isHidden = !showColor
        
        if showColor {
            toastColorView.backgroundColor = color
            
            // Special border for white/black
            if color == MarkupColors.white {
                toastColorView.layer.borderColor = UIColor.gray.cgColor
            } else if color == MarkupColors.black {
                toastColorView.layer.borderColor = UIColor.darkGray.cgColor
            } else {
                toastColorView.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
            }
        }
        
        // Bring to front
        view.bringSubviewToFront(toastContainer)
        
        // Animate in
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
            self.toastContainer.alpha = 1
            self.toastContainer.transform = .identity
        }
        
        // Schedule hide
        toastHideTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.hideToast()
        }
    }
    
    private func hideToast() {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn, .beginFromCurrentState]) {
            self.toastContainer.alpha = 0
        }
    }
    
    private func getColorName(_ color: UIColor) -> String {
        switch color.toHex() {
        case MarkupColors.white.toHex(): return "白"
        case MarkupColors.black.toHex(): return "黒"
        case MarkupColors.gray.toHex(): return "グレー"
        case MarkupColors.red.toHex(): return "赤"
        case MarkupColors.orange.toHex(): return "オレンジ"
        case MarkupColors.pink.toHex(): return "ピンク"
        case MarkupColors.purple.toHex(): return "紫"
        case MarkupColors.blue.toHex(): return "青"
        case MarkupColors.yellow.toHex(): return "黄"
        case MarkupColors.green.toHex(): return "緑"
        default: return "カスタム"
        }
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
        case .text, .arrow, .rect, .circle, .stamp, .numberStamp:
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
        var stamps: [StampAnnotationModel] = []
        
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
            } else if let stamp = view as? StampAnnotationView {
                let normX = (stamp.center.x - rect.minX) / rect.width
                let normY = (stamp.center.y - rect.minY) / rect.height
                
                stamps.append(StampAnnotationModel(
                    id: stamp.id,
                    stampType: stamp.stampType,
                    x: normX, y: normY,
                    colorHex: stamp.stampColor.toHex(),
                    scale: stamp.scale,
                    numberValue: stamp.numberValue
                ))
            } else if let ns = view as? NumberStampAnnotationView {
                let normX = (ns.center.x - rect.minX) / rect.width
                let normY = (ns.center.y - rect.minY) / rect.height
                
                stamps.append(StampAnnotationModel(
                    id: ns.id,
                    stampType: .numberedCircle, // 互換性のため旧番号スタンプ型を保存に流用
                    x: normX, y: normY,
                    colorHex: ns.stampColor.toHex(),
                    scale: ns.scale,
                    numberValue: ns.numberValue,
                    numberShape: ns.numberShape.rawValue,
                    numberVisible: ns.showsNumber,
                    numberFillOpacity: ns.fillOpacity,
                    numberRotation: ns.rotationAngle
                ))
            }
        }
        
        let data = MarkupData(texts: texts, arrows: arrows, shapes: shapes, stamps: stamps)
        
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
            
            for stamp in stamps {
                let centerX = stamp.x * image.size.width
                let centerY = stamp.y * image.size.height
                
                // 番号スタンプ（新形式 + 旧形式の互換読み込み）
                if let num = stamp.numberValue,
                   stamp.numberShape != nil || stamp.stampType == .numberedCircle {
                    let shape = NumberShape(rawValue: stamp.numberShape ?? "") ?? .circle
                    let isNumberVisible = stamp.numberVisible ?? true
                    let fillOpacity = max(0.0, min(1.0, stamp.numberFillOpacity ?? 1.0))
                    let rotation = normalizedNumberRotation(stamp.numberRotation ?? 0)
                    let baseSize: CGFloat = 28 * stamp.scale / scale
                    let fontSize = max(baseSize, 9 * (1.0 / scale))
                    
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                        .foregroundColor: UIColor.white
                    ]
                    let text = "\(num)"
                    let textSize = text.size(withAttributes: attrs)
                    
                    let unit = fontSize / 28.0
                    let dimension = max(textSize.width, textSize.height) + 12 * unit
                    var bgRect = CGRect(
                        x: -dimension / 2,
                        y: -dimension / 2,
                        width: dimension,
                        height: dimension
                    )
                    if shape == .triangle {
                        bgRect = bgRect.insetBy(dx: 0, dy: -2 * unit)
                    } else if shape == .rectangle {
                        let h = textSize.height + 12 * unit
                        let w = max(textSize.width + 24 * unit, h * 1.6)
                        bgRect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
                    }

                    ctx.cgContext.saveGState()
                    ctx.cgContext.translateBy(x: centerX, y: centerY)
                    ctx.cgContext.rotate(by: rotation)
                    
                    ctx.cgContext.setFillColor(stamp.uicolor.withAlphaComponent(fillOpacity).cgColor)
                    ctx.cgContext.setStrokeColor(UIColor.white.cgColor)
                    ctx.cgContext.setLineWidth(2 * (1.0 / scale))
                    
                    switch shape {
                    case .circle:
                        ctx.cgContext.fillEllipse(in: bgRect)
                        ctx.cgContext.strokeEllipse(in: bgRect)
                    case .square, .rectangle:
                        ctx.cgContext.fill(bgRect)
                        ctx.cgContext.stroke(bgRect)
                    case .diamond:
                        ctx.cgContext.beginPath()
                        ctx.cgContext.move(to: CGPoint(x: bgRect.midX, y: bgRect.minY))
                        ctx.cgContext.addLine(to: CGPoint(x: bgRect.maxX, y: bgRect.midY))
                        ctx.cgContext.addLine(to: CGPoint(x: bgRect.midX, y: bgRect.maxY))
                        ctx.cgContext.addLine(to: CGPoint(x: bgRect.minX, y: bgRect.midY))
                        ctx.cgContext.closePath()
                        ctx.cgContext.drawPath(using: .fillStroke)
                    case .triangle:
                        ctx.cgContext.beginPath()
                        ctx.cgContext.move(to: CGPoint(x: bgRect.midX, y: bgRect.minY))
                        ctx.cgContext.addLine(to: CGPoint(x: bgRect.maxX, y: bgRect.maxY))
                        ctx.cgContext.addLine(to: CGPoint(x: bgRect.minX, y: bgRect.maxY))
                        ctx.cgContext.closePath()
                        ctx.cgContext.drawPath(using: .fillStroke)
                    }
                    
                    if isNumberVisible {
                        let yOffset = shape == .triangle ? bgRect.height * 0.08 : 0
                        let origin = CGPoint(
                            x: -textSize.width / 2,
                            y: -textSize.height / 2 + yOffset
                        )
                        text.draw(at: origin, withAttributes: attrs)
                    }
                    ctx.cgContext.restoreGState()
                    
                } else {
                    let fontSize = 32 * stamp.scale / scale
                    
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                        .foregroundColor: stamp.uicolor
                    ]
                    
                    let text = stamp.displayText  // numberValueを考慮した表示テキスト
                    let size = text.size(withAttributes: attrs)
                    let origin = CGPoint(x: centerX - size.width / 2, y: centerY - size.height / 2)
                    text.draw(at: origin, withAttributes: attrs)
                }
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
        
        // Create Stamp if tool is stamp
        if currentTool == .stamp {
            createStamp(at: p)
        } else if currentTool == .numberStamp {
            createNumberStamp(at: p)
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
    
    func createStamp(at p: CGPoint) {
        // 旧番号スタンプは新規作成しない
        let safeStamp: StampType = (currentStamp == .numberedCircle) ? .check : currentStamp
        currentStamp = safeStamp
        let s = StampAnnotationView(stampType: safeStamp, color: currentColor, scale: currentStampScale, numberValue: nil)
        s.center = p
        addAnnotation(s)
        selectedAnnotation = s
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
        let done = UIBarButtonItem(title: "完了", style: .plain, target: self, action: #selector(dismissKeyboard))
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
    
    private func saveState() {
        isDirty = true
    }
    
    func addAnnotation(_ v: BaseAnnotationView) {
        if let numberStamp = v as? NumberStampAnnotationView {
            configureNumberStampInteractions(numberStamp)
        }
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
        // 番号スタンプ（新ツール）チェック
        var wasNumberStamp = false
        var deletedNumberShape: NumberShape?
        var deletedColor: UIColor?
        
        if let ns = v as? NumberStampAnnotationView {
            wasNumberStamp = true
            deletedNumberShape = ns.numberShape
            deletedColor = ns.stampColor
        }
        
        v.removeFromSuperview()
        isDirty = true
        undoManager?.registerUndo(withTarget: self, handler: { target in
            target.addAnnotation(v)
            if wasNumberStamp, let shape = deletedNumberShape, let color = deletedColor {
                target.renumberNumberStamps(shape: shape, color: color)
            }
        })
        
        // 番号スタンプの場合、残りを再連番
        if wasNumberStamp, let shape = deletedNumberShape, let color = deletedColor {
            renumberNumberStamps(shape: shape, color: color)
        }
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
        
        for stamp in data.stamps {
            let centerX = stamp.x * rect.width + rect.minX
            let centerY = stamp.y * rect.height + rect.minY
            
            // 番号スタンプ（新形式 + 旧形式）
            if let num = stamp.numberValue,
               stamp.numberShape != nil || stamp.stampType == .numberedCircle {
                let shape = NumberShape(rawValue: stamp.numberShape ?? "") ?? .circle
                let v = NumberStampAnnotationView(
                    id: stamp.id,
                    shape: shape,
                    color: stamp.uicolor,
                    scale: stamp.scale,
                    number: num,
                    showsNumber: stamp.numberVisible ?? true,
                    fillOpacity: stamp.numberFillOpacity ?? 1.0,
                    rotationAngle: normalizedNumberRotation(stamp.numberRotation ?? 0)
                )
                v.center = CGPoint(x: centerX, y: centerY)
                configureNumberStampInteractions(v)
                
                v.onDelete = { [weak self] in
                    self?.deleteAnnotation(v)
                    self?.selectedAnnotation = nil
                }
                overlayView.addSubview(v)
                
            } else {
                // Existing Stamp
                let v = StampAnnotationView(id: stamp.id, stampType: stamp.stampType, color: stamp.uicolor, scale: stamp.scale, numberValue: stamp.numberValue)
                v.center = CGPoint(x: centerX, y: centerY)
                
                v.onDelete = { [weak self] in
                    self?.deleteAnnotation(v)
                    self?.selectedAnnotation = nil
                }
                overlayView.addSubview(v)
            }
        }
    }
    
    func didSelectTool(_ tool: MarkupTool) {
        // If editing text, end it when switching tools
        if activeTextView != nil { endEditingText() }
        setTool(tool)
        
        // Show toast notification
        showToast(tool: tool, color: currentColor)
        
        // Animate layout changes if toolbar resizes
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    func didSelectColor(_ color: UIColor) {
        // Capture selection because setColor() calls setTool() which clears selectedAnnotation
        let previouslySelected = selectedAnnotation
        
        setColor(color)
        
        // Show toast notification
        showToast(tool: currentTool, color: color)
        
        // Restore selection and update color
        if let selected = previouslySelected {
            selectedAnnotation = selected
            
            if let tv = selected as? TextAnnotationView {
                tv.textColor = color
            } else if let av = selected as? ArrowAnnotationView {
                av.color = color
            } else if let sv = selected as? ShapeAnnotationView {
                sv.color = color
            } else if let nv = selected as? NumberStampAnnotationView {
                let oldColor = nv.stampColor
                nv.stampColor = color
                renumberNumberStamps(shape: nv.numberShape, color: oldColor)
                renumberNumberStamps(shape: nv.numberShape, color: color)
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
    
    func didSelectStamp(_ stamp: StampType) {
        currentStamp = stamp
        // 選択されたスタンプ注釈があれば更新
        if let stampView = selectedAnnotation as? StampAnnotationView {
            stampView.stampType = stamp
        }
    }
    
    func didSelectStampScale(_ scale: CGFloat) {
        currentStampScale = scale
        // 選択されたスタンプ注釈があれば更新
        if let stampView = selectedAnnotation as? StampAnnotationView {
            stampView.scale = scale
            saveState()
        }
    }
    
    func didSelectNumberShape(_ shape: NumberShape) {
        currentNumberShape = shape
        
        // Show toast notification
        showToast(tool: currentTool, color: currentColor)
        
        if let nv = selectedAnnotation as? NumberStampAnnotationView {
            let oldShape = nv.numberShape
            nv.numberShape = shape
            renumberNumberStamps(shape: oldShape, color: nv.stampColor)
            renumberNumberStamps(shape: shape, color: nv.stampColor)
            saveState()
        }
    }

    func didSelectNumberScale(_ scale: CGFloat) {
        currentNumberStampScale = normalizedNumberStampScale(scale)
        if let nv = selectedAnnotation as? NumberStampAnnotationView {
            nv.scale = currentNumberStampScale
            saveState()
        }
    }
    
    func didSelectNumberVisibility(_ isVisible: Bool) {
        currentNumberVisible = isVisible
        let numberStamps = overlayView.subviews.compactMap { $0 as? NumberStampAnnotationView }
        for nv in numberStamps {
            nv.showsNumber = isVisible
        }
        if !numberStamps.isEmpty { saveState() }
    }
    
    func didSelectNumberFillOpacity(_ opacity: CGFloat) {
        currentNumberFillOpacity = max(0.0, min(1.0, opacity))
        let numberStamps = overlayView.subviews.compactMap { $0 as? NumberStampAnnotationView }
        for nv in numberStamps {
            nv.fillOpacity = currentNumberFillOpacity
        }
        if !numberStamps.isEmpty { saveState() }
    }

    func didSelectNumberRotation(_ rotation: CGFloat) {
        currentNumberRotation = normalizedNumberRotation(rotation)
        if let nv = selectedAnnotation as? NumberStampAnnotationView {
            nv.rotationAngle = currentNumberRotation
            saveState()
        }
    }

    // MARK: - Number Stamp Creation
    
    func createNumberStamp(at p: CGPoint) {
        let number = getNextNumberForShapeAndColor(shape: currentNumberShape, color: currentColor)
        let s = NumberStampAnnotationView(
            shape: currentNumberShape,
            color: currentColor,
            scale: currentNumberStampScale,
            number: number,
            showsNumber: currentNumberVisible,
            fillOpacity: currentNumberFillOpacity,
            rotationAngle: currentNumberRotation
        )
        s.center = p
        
        addAnnotation(s)
        selectedAnnotation = s
    }

    private func configureNumberStampInteractions(_ stamp: NumberStampAnnotationView) {
        let alreadyAdded = stamp.gestureRecognizers?.contains(where: { $0 is UIRotationGestureRecognizer }) ?? false
        if alreadyAdded { return }
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleNumberStampRotation(_:)))
        rotationGesture.delegate = self
        stamp.addGestureRecognizer(rotationGesture)
        if let pinch = scrollView.pinchGestureRecognizer {
            pinch.require(toFail: rotationGesture)
        }
    }

    @objc private func handleNumberStampRotation(_ gesture: UIRotationGestureRecognizer) {
        guard let stamp = gesture.view as? NumberStampAnnotationView else { return }
        switch gesture.state {
        case .began:
            selectedAnnotation = stamp
            updateToolbarForSelection(stamp)
            rotationGestureStartAngle = stamp.rotationAngle
        case .changed:
            let raw = rotationGestureStartAngle + gesture.rotation
            let step = CGFloat.pi / 12.0 // 15度
            let snapped = normalizedNumberRotation(round(raw / step) * step)
            if stamp.rotationAngle != snapped {
                stamp.rotationAngle = snapped
                currentNumberRotation = snapped
                toolbar.selectNumberRotation(snapped, notifyDelegate: false)
            }
        case .ended, .cancelled, .failed:
            saveState()
        default:
            break
        }
    }

    private func normalizedNumberRotation(_ angle: CGFloat) -> CGFloat {
        let step = CGFloat.pi / 12.0
        let snapped = round(angle / step) * step
        return max(0, min(.pi / 2.0, snapped))
    }

    private func normalizedNumberStampScale(_ scale: CGFloat) -> CGFloat {
        let supportedScales: [CGFloat] = [0.25, 0.5]
        return supportedScales.min(by: { abs($0 - scale) < abs($1 - scale) }) ?? 0.5
    }
    
    /// 指定された図形と色の組み合わせに対する次の番号を取得
    private func getNextNumberForShapeAndColor(shape: NumberShape, color: UIColor) -> Int {
        var maxNumber = 0
        let targetColorHex = color.toHex()
        
        for view in overlayView.subviews {
            if let nv = view as? NumberStampAnnotationView,
               nv.numberShape == shape,
               nv.stampColor.toHex() == targetColorHex {
                maxNumber = max(maxNumber, nv.numberValue)
            }
        }
        return maxNumber + 1
    }
    
    /// 指定された図形と色の数字スタンプを再連番
    func renumberNumberStamps(shape: NumberShape, color: UIColor) {
        let targetColorHex = color.toHex()
        
        // 対象の図形・色のスタンプを取得
        var targetStamps: [NumberStampAnnotationView] = []
        for view in overlayView.subviews {
            if let nv = view as? NumberStampAnnotationView,
               nv.numberShape == shape,
               nv.stampColor.toHex() == targetColorHex {
                targetStamps.append(nv)
            }
        }
        
        // 位置順（Y優先、次にX）でソート
        targetStamps.sort { a, b in
            let tolerance: CGFloat = 20
            if abs(a.center.y - b.center.y) < tolerance {
                return a.center.x < b.center.x
            }
            return a.center.y < b.center.y
        }
        
        // 連番振り直し
        for (index, stamp) in targetStamps.enumerated() {
            stamp.numberValue = index + 1
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
        } else if let numberStamp = selection as? NumberStampAnnotationView {
            currentTool = .numberStamp
            currentColor = numberStamp.stampColor
            currentNumberShape = numberStamp.numberShape
            currentNumberStampScale = normalizedNumberStampScale(numberStamp.scale)
            currentNumberVisible = numberStamp.showsNumber
            currentNumberFillOpacity = numberStamp.fillOpacity
            currentNumberRotation = numberStamp.rotationAngle
            
            toolbar.selectTool(.numberStamp, notifyDelegate: false)
            toolbar.selectColor(currentColor, notifyDelegate: false)
            toolbar.selectNumberShape(currentNumberShape, notifyDelegate: false)
            toolbar.selectNumberScale(currentNumberStampScale, notifyDelegate: false)
            toolbar.selectNumberVisibility(currentNumberVisible, notifyDelegate: false)
            toolbar.selectNumberFillOpacity(currentNumberFillOpacity, notifyDelegate: false)
            toolbar.selectNumberRotation(currentNumberRotation, notifyDelegate: false)
        } else if let stamp = selection as? StampAnnotationView {
            currentTool = .stamp
            currentColor = stamp.stampColor
            currentStamp = (stamp.stampType == .numberedCircle) ? .check : stamp.stampType
            currentStampScale = stamp.scale
            
            toolbar.selectTool(.stamp, notifyDelegate: false)
            toolbar.selectColor(currentColor, notifyDelegate: false)
            toolbar.selectStampScale(currentStampScale, notifyDelegate: false)
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
