//
//  PhotoDetailView.swift
//  SiteSurvey
//
//  写真詳細画面
//

import SwiftUI
import SwiftData
import PencilKit
import UIKit

struct PhotoDetailView: View {
    @State private var currentPhoto: CasePhoto
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayImage: UIImage?
    @State private var isRotating = false
    @State private var showDeleteAlert = false
    @State private var showDecomposeAlert = false // 結合解除確認
    @State private var slideOffset: CGFloat = 0 // スライドアニメーション用
    @State private var isStampSummaryExpanded = false
    
    // 仕様: アクセントカラー Color(red: 0.2, green: 0.78, blue: 0.35)
    private let accentGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    
    init(photo: CasePhoto) {
        _currentPhoto = State(initialValue: photo)
    }
    
    var body: some View {
        // body内でのBinding用（必要に応じて）
        // noteSectionなどは直接 $currentPhoto を使うため、ここでは必須ではないが、
        // 既存ロジックとの整合性のため残すことは可能。ただし今回は computed property で管理するため
        // body直下での @Bindable は削除し、各セクションで適切に参照する形にする。
        
        VStack(spacing: 0) {
            // 写真番号表示
            if let indexStr = photoIndexString {
                Text(indexStr)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }
            
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
        .navigationBarBackButtonHidden(true) // 標準の戻るジェスチャーを無効化
        .alert("写真を削除", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                deletePhoto()
            }
        } message: {
            Text("この写真を削除してもよろしいですか？")
        }
        .alert("結合を解除", isPresented: $showDecomposeAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("解除", role: .destructive) {
                decomposePhoto()
            }
        } message: {
            Text("結合を解除して元の写真に戻します。\nマークアップはリセットされます。")
        }
        .onAppear {
            loadImage()
        }
        .onReceive(NotificationCenter.default.publisher(for: ImageStorage.thumbUpdatedNotification)) { notification in
            if let fileName = notification.object as? String, fileName == currentPhoto.imageFileName {
                loadImage()
            }
        }
        .toolbar {
            // カスタム戻るボタン
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("戻る")
                    }
                    .foregroundColor(accentGreen)
                }
            }
            
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
    
    // MARK: - 画像セクション
    // 仕様: .aspectRatio(contentMode: .fit)、クロップなし、ピンチズーム対応
    
    private var imageSection: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemGray5)
                
                if let image = displayImage {
                    ZoomableImageView(
                        image: image,
                        onSwipeLeft: { moveToNext() },
                        onSwipeRight: { moveToPrevious() },
                        onSwipeDown: { dismiss() }
                    )
                    .offset(x: slideOffset)
                } else {
                    ProgressView()
                }
                
                if isRotating {
                    Color.black.opacity(0.3)
                    ProgressView()
                        .tint(.white)
                }
                
                // ナビゲーションボタン
                HStack {
                    if hasPrevious {
                        Button(action: moveToPrevious) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
                                .padding()
                                .background(Color.black.opacity(0.1)) // タップ領域確保
                                .clipShape(Circle())
                        }
                        .padding(.leading, 8)
                    }
                    
                    Spacer()
                    
                    if hasNext {
                        Button(action: moveToNext) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
                                .padding()
                                .background(Color.black.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 8)
                    }
                }
            }
            .clipped() // スライドアニメーション時のオーバーフローを隠す
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
            
            // $currentPhoto.note を直接使用
            TextField("メモを入力...", text: $currentPhoto.note, axis: .vertical)
                .lineLimit(3...6)
                .padding(10)
                .background(Color(.systemGray5))
                .cornerRadius(8)
                .onChange(of: currentPhoto.note) { _, _ in
                    currentPhoto.parentCase?.touch()
                    try? modelContext.save()
                }
            
            // 1ページ表示トグル
            HStack {
                Image(systemName: "doc.richtext")
                    .foregroundColor(accentGreen)
                Text("PDFで1ページ表示")
                    .font(.subheadline)
                
                Spacer()
                
                Toggle("", isOn: $currentPhoto.isFullPage)
                    .labelsHidden()
                    .tint(accentGreen)
                    .onChange(of: currentPhoto.isFullPage) { _, _ in
                        currentPhoto.parentCase?.touch()
                        try? modelContext.save()
                    }
            }
            .padding(.top, 4)
            
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.orange)
                Text("スタンプ集計を表示")
                    .font(.subheadline)
                Spacer()
                Toggle("", isOn: stampSummaryEnabledBinding)
                    .labelsHidden()
                    .tint(accentGreen)
            }
            .padding(.top, 2)
            
            if currentPhoto.isStampSummaryEnabled {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isStampSummaryExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .rotationEffect(.degrees(isStampSummaryExpanded ? 90 : 0))
                            .foregroundColor(.secondary)
                        Text("凡例 \(stampLegendItems.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                
                if isStampSummaryExpanded {
                    VStack(alignment: .leading, spacing: 4) {
                        if stampLegendItems.isEmpty {
                            Text("スタンプなし")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(stampLegendItems) { item in
                                HStack(spacing: 8) {
                                    StampLegendSwatchView(item: item)
                                        .frame(width: 56, alignment: .leading)
                                    TextField("意味", text: stampLegendMeaningBinding(for: item))
                                        .textFieldStyle(.roundedBorder)
                                        .font(.caption2)
                                    Text("\(item.count)個")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(.secondary)
                                        .frame(width: 40, alignment: .trailing)
                                }
                                .frame(minHeight: 30)
                            }
                        }
                    }
                    .padding(.top, 2)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .padding()
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    // 右スワイプで案件詳細に戻る
                    if value.translation.width > 50 && abs(value.translation.height) < abs(value.translation.width) {
                        dismiss()
                    }
                }
        )
    }
    
    private var noteLineCount: Int {
        currentPhoto.note.components(separatedBy: "\n").count
    }

    private var stampSummaryEnabledBinding: Binding<Bool> {
        Binding(
            get: { currentPhoto.isStampSummaryEnabled },
            set: { newValue in
                currentPhoto.isStampSummaryEnabled = newValue
                currentPhoto.parentCase?.touch()
                try? modelContext.save()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isStampSummaryExpanded = false
                }
            }
        )
    }

    private var stampLegendItems: [StampLegendItem] {
        StampLegendBuilder.summarize(stamps: currentPhoto.annotations?.stamps ?? [])
    }

    private func stampLegendMeaningBinding(for item: StampLegendItem) -> Binding<String> {
        Binding(
            get: {
                currentPhoto.stampLegendMeanings[item.key] ?? ""
            },
            set: { newValue in
                var meanings = currentPhoto.stampLegendMeanings
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    meanings.removeValue(forKey: item.key)
                } else {
                    meanings[item.key] = newValue
                }
                currentPhoto.stampLegendMeanings = meanings
                currentPhoto.parentCase?.touch()
                try? modelContext.save()
            }
        )
    }
    
    private var photoIndexString: String? {
        guard let parent = currentPhoto.parentCase else { return nil }
        if let index = parent.sortedPhotos.firstIndex(of: currentPhoto) {
            return "\(index + 1) / \(parent.photos.count)"
        }
        return nil
    }
    
    private var hasPrevious: Bool {
        guard let parent = currentPhoto.parentCase,
              let index = parent.sortedPhotos.firstIndex(of: currentPhoto) else { return false }
        return index > 0
    }
    
    private var hasNext: Bool {
        guard let parent = currentPhoto.parentCase,
              let index = parent.sortedPhotos.firstIndex(of: currentPhoto) else { return false }
        return index < parent.sortedPhotos.count - 1
    }
    
    // MARK: - 操作ボタン
    // 仕様: マークアップ（オレンジ）+ 回転（緑）+ 削除（赤）
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 結合写真の場合は解除ボタンを表示
            if currentPhoto.isComposite {
                Button(action: {
                    showDecomposeAlert = true
                }) {
                    Label("結合解除", systemImage: "rectangle.2.swap")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            
            HStack(spacing: 16) {
                NavigationLink(destination: MarkupLoaderView(photo: currentPhoto)) {
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
            .padding(.horizontal)
        }
        .padding(.vertical)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    // 右スワイプで案件詳細に戻る
                    if value.translation.width > 50 && abs(value.translation.height) < abs(value.translation.width) {
                        dismiss()
                    }
                }
        )
    }
    
    // MARK: - アクション
    
    private func moveToPrevious() {
        guard let parent = currentPhoto.parentCase,
              let index = parent.sortedPhotos.firstIndex(of: currentPhoto) else { return }
        
        // ハプティックフィードバック
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        // 最初の写真なら最後にループ
        let prevIndex = index > 0 ? index - 1 : parent.sortedPhotos.count - 1
        let prevPhoto = parent.sortedPhotos[prevIndex]
        
        // スライドアウトアニメーション（右へ）
        withAnimation(.easeOut(duration: 0.15)) {
            slideOffset = UIScreen.main.bounds.width
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            currentPhoto = prevPhoto
            isStampSummaryExpanded = false
            slideOffset = -UIScreen.main.bounds.width
            loadImage()
            
            // スライドインアニメーション（左から）
            withAnimation(.easeOut(duration: 0.15)) {
                slideOffset = 0
            }
        }
    }
    
    private func moveToNext() {
        guard let parent = currentPhoto.parentCase,
              let index = parent.sortedPhotos.firstIndex(of: currentPhoto) else { return }
        
        // ハプティックフィードバック
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        // 最後の写真なら最初にループ
        let nextIndex = index < parent.sortedPhotos.count - 1 ? index + 1 : 0
        let nextPhoto = parent.sortedPhotos[nextIndex]
        
        // スライドアウトアニメーション（左へ）
        withAnimation(.easeOut(duration: 0.15)) {
            slideOffset = -UIScreen.main.bounds.width
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            currentPhoto = nextPhoto
            isStampSummaryExpanded = false
            slideOffset = UIScreen.main.bounds.width
            loadImage()
            
            // スライドインアニメーション（右から）
            withAnimation(.easeOut(duration: 0.15)) {
                slideOffset = 0
            }
        }
    }
    
    private func loadImage() {
        // データをローカルにコピーしてからTask.detachedで使用
        let fileName = currentPhoto.imageFileName
        let drawing = currentPhoto.drawing
        let textOverlay = currentPhoto.textOverlay
        
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
        
        // 回転前の画像サイズを取得
        let originalImageSize = ImageStorage.shared.loadImage(currentPhoto.imageFileName)?.size ?? .zero
        
        Task {
            let success = await ImageStorage.shared.rotateImage(currentPhoto.imageFileName)
            
            if success {
                // マークアップを回転変換（クリアではなく変換）
                currentPhoto.rotateMarkup90Clockwise(originalImageSize: originalImageSize)
                currentPhoto.parentCase?.touch()
                
                try? modelContext.save()
                
                // サムネイル更新
                ImageStorage.shared.updateThumbSync(
                    currentPhoto.imageFileName,
                    drawing: currentPhoto.drawing,
                    textOverlay: currentPhoto.textOverlay
                )
            }
            
            isRotating = false
            loadImage()
        }
    }
    
    private func deletePhoto() {
        ImageStorage.shared.deleteImage(currentPhoto.imageFileName)
        
        if let caseItem = currentPhoto.parentCase {
            if let index = caseItem.photos.firstIndex(of: currentPhoto) {
                caseItem.photos.remove(at: index)
            }
            caseItem.normalizePhotoOrder()
            caseItem.touch()
        }
        
        modelContext.delete(currentPhoto)
        try? modelContext.save()
        
        dismiss()
    }
    
    private func decomposePhoto() {
        guard currentPhoto.isComposite,
              let sourceFileNames = currentPhoto.sourceImageFileNames,
              let caseItem = currentPhoto.parentCase else { return }
        
        // 結合写真の位置を取得
        let insertIndex = currentPhoto.orderIndex
        
        // 元写真をCasePhotoとして復元
        for (offset, fileName) in sourceFileNames.enumerated() {
            let restoredPhoto = CasePhoto(imageFileName: fileName, orderIndex: insertIndex + offset)
            restoredPhoto.parentCase = caseItem
            caseItem.photos.append(restoredPhoto)
        }
        
        // 結合写真を削除（結合画像ファイルも削除）
        ImageStorage.shared.deleteImage(currentPhoto.imageFileName)
        if let index = caseItem.photos.firstIndex(of: currentPhoto) {
            caseItem.photos.remove(at: index)
        }
        
        caseItem.normalizePhotoOrder()
        caseItem.touch()
        
        modelContext.delete(currentPhoto)
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

private struct StampLegendSwatchView: View {
    let item: StampLegendItem
    
    private var stampUIColor: UIColor {
        UIColor(hex: item.colorHex) ?? .systemRed
    }
    
    private var stampColor: Color {
        Color(uiColor: stampUIColor)
    }
    
    private var showsNumberText: Bool {
        item.isNumberStamp && item.showsNumber
    }
    
    var body: some View {
        swatchBody
    }
    
    @ViewBuilder
    private var swatchBody: some View {
        if item.isNumberStamp {
            ZStack {
                LegendNumberShape(shape: item.numberShape ?? .circle)
                    .fill(stampColor.opacity(item.fillOpacity))
                    .overlay(LegendNumberShape(shape: item.numberShape ?? .circle).stroke(Color.white, lineWidth: 1.5))
                if showsNumberText {
                    Text("\(item.sampleNumber ?? 1)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: numberShapeSize.width, height: numberShapeSize.height)
        } else {
            Text(item.symbolText)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(stampColor)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .frame(width: nonNumberSize.width, height: nonNumberSize.height)
        }
    }
    
    private var numberShapeSize: CGSize {
        if item.numberShape == .rectangle {
            return CGSize(width: 34, height: 22)
        }
        return CGSize(width: 24, height: 24)
    }
    
    private var nonNumberSize: CGSize {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold)
        ]
        let width = (item.symbolText as NSString).size(withAttributes: attrs).width
        let clamped = min(max(width + 4, 14), 56)
        return CGSize(width: clamped, height: 20)
    }
}

private struct LegendNumberShape: Shape {
    let shape: NumberStampShapeKind
    
    func path(in rect: CGRect) -> Path {
        switch shape {
        case .circle:
            return Circle().path(in: rect)
        case .square, .rectangle:
            return RoundedRectangle(cornerRadius: 4, style: .continuous).path(in: rect)
        case .diamond:
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
            return path
        case .triangle:
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

#Preview {
    NavigationStack {
        PhotoDetailView(photo: CasePhoto(imageFileName: "test.jpg", orderIndex: 0))
    }
    .modelContainer(for: CasePhoto.self, inMemory: true)
}
