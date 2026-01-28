import SwiftUI
import PDFKit

struct PDFPreviewView: View {
    let url: URL
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            PDFKitView(url: url)
                .edgesIgnoringSafeArea(.all)
                .navigationTitle("プレビュー")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("閉じる") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}
