//
//  PhotoDetailView.swift
//  SiteSurvey
//
//  写真詳細画面
//

import SwiftUI
import SwiftData
import PencilKit

struct PhotoDetailView: View {
    @Bindable var photo: CasePhoto
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayImage: UIImage?
    @State private var isRotating = false
    @State private var showDeleteAlert = false
    
    // 仕様: アクセントカラー Color(red: 0.2, green: 0.78, blue: 0.35)
    private let accentGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    
    var body: some View {
        VStack(spacing: 0) {
            // 仕様: 画像表示 .aspectRatio(contentMode: .fit)、クロップなし
            imageSection
            
            // 仕様: メモ入力 TextField、3〜6行、systemGray6背景
            noteSection
            
            // 仕様: 操作ボタン（横並び）マークアップ（オレンジ）+ 回転（緑）+ 削除（赤）
            actionButtons
        }
        // 仕様: 背景 Color(.systemGray6)
        .background(Color(.systemGray6))
        .navigationTitle("写真詳細")
        .navigationBarTitleDisplayMode(.inline)
        // 仕様: 削除確認 アラート表示
        .alert("写真を削除", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                deletePhoto()
            }
        } message: {
            Text("この写真を削除してもよろしいですか？")
        }
        .onAppear {
            loadImage()
        }
        .onReceive(NotificationCenter.default.publisher(for: ImageStorage.thumbUpdatedNotification)) { notification in
            if let fileName = notification.object as? String, fileName == photo.imageFileName {
                loadImage()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
    
    // MARK: - 画像セクション
    // 仕様: .aspectRatio(contentMode: .fit)、クロップなし
    
    private var imageSection: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemGray5)
                
                if let image = displayImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                } else {
                    ProgressView()
                }
                
                if isRotating {
                    Color.black.opacity(0.3)
                    ProgressView()
                        .tint(.white)
                }
            }
        }
    }
    
    // MARK: - メモセクション
    // 仕様: TextField、3〜6行、systemGray6背景
    
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("メモ")
                    .font(.headline)
                
                Spacer()
                
                // 6行を超えた場合の警告
                if noteLineCount > 6 {
                    Text("PDFではみ出る可能性があります")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            TextField("メモを入力...", text: $photo.note, axis: .vertical)
                .lineLimit(3...6)
                .padding(10)
                .background(Color(.systemGray5))
                .cornerRadius(8)
                .onChange(of: photo.note) { _, _ in
                    photo.parentCase?.touch()
                    try? modelContext.save()
                }
        }
        .padding()
    }
    
    private var noteLineCount: Int {
        photo.note.components(separatedBy: "\n").count
    }
    
    // MARK: - 操作ボタン
    // 仕様: マークアップ（オレンジ）+ 回転（緑）+ 削除（赤）
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            NavigationLink(destination: MarkupLoaderView(photo: photo)) {
                Label("マーク", systemImage: "pencil.tip.crop.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            // 回転ボタン（緑）
            // 仕様: 90度右回転、非同期処理
            Button(action: rotateImage) {
                Label("回転", systemImage: "rotate.right")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(accentGreen)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(isRotating)
            
            // 削除ボタン（赤）
            Button(action: {
                showDeleteAlert = true
            }) {
                Label("削除", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    
    // MARK: - アクション
    
    private func loadImage() {
        // データをローカルにコピーしてからTask.detachedで使用
        let fileName = photo.imageFileName
        let drawing = photo.drawing
        let textOverlay = photo.textOverlay
        
        Task {
            let image = ImageStorage.shared.getCompositeImage(
                fileName,
                drawing: drawing,
                textOverlay: textOverlay
            )
            displayImage = image
        }
    }
    
    // 仕様: 90度右回転、非同期処理
    private func rotateImage() {
        isRotating = true
        
        Task {
            let success = await ImageStorage.shared.rotateImage(photo.imageFileName)
            
            if success {
                // マークアップデータをクリア（回転すると座標がずれるため）
                photo.markupData = nil
                photo.textOverlayData = nil
                photo.parentCase?.touch()
                
                try? modelContext.save()
            }
            
            isRotating = false
            loadImage()
        }
    }
    
    private func deletePhoto() {
        ImageStorage.shared.deleteImage(photo.imageFileName)
        
        if let caseItem = photo.parentCase {
            if let index = caseItem.photos.firstIndex(of: photo) {
                caseItem.photos.remove(at: index)
            }
            caseItem.normalizePhotoOrder()
            caseItem.touch()
        }
        
        modelContext.delete(photo)
        try? modelContext.save()
        
        dismiss()
    }
}

// データロード用の中間ビュー
struct MarkupLoaderView: View {
    var photo: CasePhoto
    @State private var originalImage: UIImage?
    
    var body: some View {
        Group {
            if let image = originalImage {

                PhotoMarkupView(image: image, drawing: photo.drawing, annotations: photo.annotations) { newDrawing, newAnnotations, overlayImage in
                    photo.setDrawing(newDrawing)
                    photo.annotations = newAnnotations
                    photo.setTextOverlay(overlayImage) // サムネイル/後方互換用
                    photo.parentCase?.touch()
                    // サムネイル更新
                    ImageStorage.shared.updateThumbSync(photo.imageFileName, drawing: newDrawing, textOverlay: overlayImage)
                    NotificationCenter.default.post(name: ImageStorage.thumbUpdatedNotification, object: photo.imageFileName)
                }
            } else {
                ProgressView()
                    .onAppear {
                        loadImageWithTextOverlay()
                    }
            }
        }
    }
    
    /// 元画像をロード（テキスト/矢印オーバーレイは元画像に焼き込まない）
    /// 既存のオーバーレイは別途表示用として管理し、保存時のみ最終合成
    private func loadImageWithTextOverlay() {
        guard let baseImage = ImageStorage.shared.loadImage(photo.imageFileName) else { return }
        
        // 常に元画像のみをロード（テキスト/矢印は焼き込まない）
        // textOverlayDataは保持したまま、マークアップ画面では別レイヤーとして表示
        originalImage = baseImage
    }
}

#Preview {
    NavigationStack {
        PhotoDetailView(photo: CasePhoto(imageFileName: "test.jpg", orderIndex: 0))
    }
    .modelContainer(for: CasePhoto.self, inMemory: true)
}
