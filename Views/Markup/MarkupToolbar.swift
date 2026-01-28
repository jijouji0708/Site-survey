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
    private var buttonColors: [UIButton: UIColor] = [:]
    
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
        
        NSLayoutConstraint.activate([
            colorStack.topAnchor.constraint(equalTo: colorContainer.topAnchor),
            colorStack.bottomAnchor.constraint(equalTo: colorContainer.bottomAnchor),
            colorStack.leadingAnchor.constraint(equalTo: colorContainer.leadingAnchor),
            colorStack.trailingAnchor.constraint(equalTo: colorContainer.trailingAnchor),
            colorStack.heightAnchor.constraint(equalTo: colorContainer.heightAnchor)
        ])
        
        for color in MarkupColors.all {
            let btn = UIButton()
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.widthAnchor.constraint(equalToConstant: 24).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 24).isActive = true
            btn.backgroundColor = color
            btn.layer.cornerRadius = 12
            btn.layer.borderWidth = 2
            btn.layer.borderColor = UIColor.clear.cgColor
            
            // For white/black visibility
            if color == MarkupColors.black {
                btn.layer.borderColor = UIColor.darkGray.cgColor
                btn.layer.borderWidth = 1
            }
            
            btn.addAction(UIAction { [weak self] _ in self?.selectColor(color) }, for: .touchUpInside)
            colorStack.addArrangedSubview(btn)
            colorButtons.append(btn)
            buttonColors[btn] = color
        }
        
        updateUI()
    }
    
    func selectTool(_ tool: MarkupTool) {
        selectedTool = tool
        delegate?.didSelectTool(tool)
        updateUI()
    }
    
    func selectColor(_ color: UIColor) {
        selectedColor = color
        delegate?.didSelectColor(color)
        updateUI()
    }
    
    func updateUI() {
        for (t, b) in toolButtons {
            b.tintColor = (t == selectedTool) ? .green : .white
        }
        
        for btn in colorButtons {
            guard let color = buttonColors[btn] else { continue }
            let isSelected = color == selectedColor
            
            if isSelected {
                btn.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                btn.layer.borderColor = UIColor.white.cgColor // Selection ring
                btn.layer.borderWidth = 2
            } else {
                btn.transform = .identity
                // Reset border
                if color == MarkupColors.black {
                    btn.layer.borderColor = UIColor.darkGray.cgColor
                    btn.layer.borderWidth = 1
                } else {
                    btn.layer.borderColor = UIColor.clear.cgColor
                    btn.layer.borderWidth = 0
                }
            }
        }
    }
}
