import SwiftUI
import PencilKit

struct PhotoMarkupView: View {
    private let saveNotification = Notification.Name("PerformMarkupSave")
    private let undoNotification = Notification.Name("PerformMarkupUndo")
    private let redoNotification = Notification.Name("PerformMarkupRedo")
    private let toggleImageAdjustNotification = Notification.Name("ToggleMarkupImageAdjustPanel")
    
    @Environment(\.dismiss) var dismiss
    var image: UIImage
    var drawing: PKDrawing?
    var annotations: MarkupData?
    
    var onSave: ((PKDrawing, MarkupData, UIImage) -> Void)?
    var onSaveEditedImage: ((UIImage?) -> Void)? = nil
    
    @State private var isDirty = false
    @State private var showDiscardAlert = false
    
    var body: some View {
        markupContent
        .edgesIgnoringSafeArea(.all)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                leadingToolbarItems
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                trailingToolbarItems
            }
        }
        .alert("変更を保存しますか？", isPresented: $showDiscardAlert, actions: discardAlertActions)
    }
    
    private var markupContent: some View {
        MarkupWrapper(
            image: image,
            existingDrawing: drawing,
            initialData: annotations,
            isDirty: $isDirty,
            onSaveEditedImage: onSaveEditedImage,
            onSave: { d, a, i in
                onSave?(d, a, i)
                dismiss()
            },
            onCancel: {
                dismiss()
            }
        )
    }
    
    @ViewBuilder
    private func discardAlertActions() -> some View {
        Button("保存") {
            NotificationCenter.default.post(name: saveNotification, object: nil)
        }
        Button("保存せずに戻る", role: .destructive) {
            dismiss()
        }
        Button("キャンセル", role: .cancel) {}
    }
    
    private var backButton: some View {
        Button(action: handleBack) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text("戻る")
            }
        }
    }

    private var imageAdjustButton: some View {
        Button(action: {
            NotificationCenter.default.post(name: toggleImageAdjustNotification, object: nil)
        }) {
            Image(systemName: "slider.horizontal.3")
        }
    }

    private var leadingToolbarItems: some View {
        HStack(spacing: 10) {
            backButton
            imageAdjustButton
        }
    }
    
    private var trailingToolbarItems: some View {
        HStack {
            Button(action: { NotificationCenter.default.post(name: undoNotification, object: nil) }) {
                Image(systemName: "arrow.uturn.backward")
            }
            Button(action: { NotificationCenter.default.post(name: redoNotification, object: nil) }) {
                Image(systemName: "arrow.uturn.forward")
            }
            Button("完了") {
                NotificationCenter.default.post(name: saveNotification, object: nil)
            }
            .fontWeight(.bold)
        }
    }

    
    private func handleBack() {
        if isDirty {
            showDiscardAlert = true
        } else {
            dismiss()
        }
    }
}
