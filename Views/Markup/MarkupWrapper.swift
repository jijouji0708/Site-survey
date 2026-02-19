import SwiftUI
import PencilKit

struct MarkupWrapper: UIViewControllerRepresentable {
    var image: UIImage
    var existingDrawing: PKDrawing?
    var initialData: MarkupData?
    @Binding var isDirty: Bool
    var onSaveEditedImage: ((UIImage?) -> Void)? = nil
    
    var onSave: ((PKDrawing, MarkupData, UIImage) -> Void)?
    var onCancel: (() -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> MarkupViewController {
        let vc = MarkupViewController()
        vc.image = image
        vc.initialDrawing = existingDrawing
        vc.initialData = initialData
        
        vc.onSave = context.coordinator.save
        vc.onSaveEditedImage = context.coordinator.saveEditedImage
        vc.onCancel = context.coordinator.cancel
        
        // Pass dirty callback
        vc.onDirtyChange = { dirty in
            context.coordinator.parent.isDirty = dirty
        }
        
        context.coordinator.vc = vc
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MarkupViewController, context: Context) {}
    
    class Coordinator: NSObject {
        var parent: MarkupWrapper
        weak var vc: MarkupViewController?
        
        init(_ parent: MarkupWrapper) {
            self.parent = parent
            super.init()
            
            NotificationCenter.default.addObserver(self, selector: #selector(doSave), name: Notification.Name("PerformMarkupSave"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(doUndo), name: Notification.Name("PerformMarkupUndo"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(doRedo), name: Notification.Name("PerformMarkupRedo"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(toggleImageAdjustPanel), name: Notification.Name("ToggleMarkupImageAdjustPanel"), object: nil)
        }
        
        deinit { NotificationCenter.default.removeObserver(self) }
        
        @objc func doSave() { vc?.save() }
        @objc func doUndo() { vc?.undo() }
        @objc func doRedo() { vc?.redo() }
        @objc func toggleImageAdjustPanel() { vc?.toggleImageAdjustPanel() }
        
        func save(drawing: PKDrawing, data: MarkupData, img: UIImage) {
            parent.onSave?(drawing, data, img)
        }

        func saveEditedImage(_ image: UIImage?) {
            parent.onSaveEditedImage?(image)
        }
        
        func cancel() {
            parent.onCancel?()
        }
    }
}
