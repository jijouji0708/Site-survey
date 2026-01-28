import SwiftUI
import PencilKit

struct PhotoMarkupView: View {
    @Environment(\.dismiss) var dismiss
    var image: UIImage
    var drawing: PKDrawing?
    var annotations: MarkupData?
    
    var onSave: ((PKDrawing, MarkupData, UIImage) -> Void)?
    
    @State private var isDirty = false
    @State private var showDiscardAlert = false
    
    var body: some View {
        NavigationStack {
            MarkupWrapper(
                image: image,
                existingDrawing: drawing,
                initialData: annotations,
                isDirty: $isDirty,
                onSave: { d, a, i in
                    onSave?(d, a, i)
                    dismiss()
                },
                onCancel: {
                    dismiss()
                }
            )
            .edgesIgnoringSafeArea(.all)
            .navigationBarBackButtonHidden(true) // Hide default back button
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: handleBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("戻る")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { NotificationCenter.default.post(name: Notification.Name("PerformMarkupUndo"), object: nil) }) {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        Button(action: { NotificationCenter.default.post(name: Notification.Name("PerformMarkupRedo"), object: nil) }) {
                            Image(systemName: "arrow.uturn.forward")
                        }
                        Button("完了") {
                            NotificationCenter.default.post(name: Notification.Name("PerformMarkupSave"), object: nil)
                        }
                        .fontWeight(.bold)
                    }
                }
            }
            .alert("変更を保存しますか？", isPresented: $showDiscardAlert) {
                Button("保存", role: .none) {
                    NotificationCenter.default.post(name: Notification.Name("PerformMarkupSave"), object: nil)
                }
                Button("保存せずに戻る", role: .destructive) {
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            }
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
