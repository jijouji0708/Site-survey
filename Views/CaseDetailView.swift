//
//  CaseDetailView.swift
//  SiteSurvey
//
//  案件詳細画面 + PhotoThumb + CameraPicker + ShareView
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import VisionKit
import PencilKit
import Photos
import PDFKit

enum PhotoViewMode {
    case grid
    case list
}

struct CaseDetailView: View {
    @Bindable var caseItem: Case
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var showScanner = false
    // @State private var isReordering = false // 削除: 常時ドラッグ可能
    @State private var showPDFShare = false
    @State private var showPDFPreview = false // Preview State
    @State private var pdfData: Data?
    @State private var pdfURL: URL? // URLを追加
    @State private var isGeneratingPDF = false
    @State private var thumbUpdateTrigger = UUID()
    
    @State private var photoToDelete: CasePhoto?
    @State private var showDeleteAlert = false
    @State private var isDetailsExpanded = false // 詳細セクションの開閉状態

    // タグ
    @State private var showTagSheet = false

    @State private var draggingPhoto: CasePhoto? // ドラッグ中の写真を追跡
    @State private var dropTargetPhotoId: UUID? // ドロップターゲットのハイライト用
    @State private var photoViewMode: PhotoViewMode = .list // 写真表示モード（リストがデフォルト）
    @State private var showMemoLineAlert = false // メモ行数超過アラート
    @FocusState private var focusedPhotoId: UUID? // リスト表示時のフォーカス管理
    @State private var photoForMarkup: CasePhoto? // 撮影後マークアップ画面への遷移用
    
    // 写真結合モード
    @State private var isComposeMode = false
    @State private var selectedPhotosForCompose: Set<UUID> = []
    @State private var showComposeConfirmAlert = false
    
    // PDF添付
    @State private var showDocumentPicker = false
    @State private var attachmentToDelete: CaseAttachment?
    @State private var showAttachmentDeleteAlert = false
    
    // PDF取込（写真化）
    @State private var showPDFImportPicker = false
    @State private var isImportingPDF = false
    @State private var pdfImportFailedFiles: [String] = []
    @State private var showPDFImportFailedAlert = false
    
    // アクセントカラー（緑）- 仕様: Color(red: 0.2, green: 0.78, blue: 0.35)
    private let accentGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    private let maxPhotos = 50
    
    private var hasIncludedPDFPhotos: Bool {
        caseItem.sortedPhotos.contains { $0.isIncludedInPDF }
    }
    
    private func exportNumberMap(for photos: [CasePhoto]) -> [UUID: Int] {
        var map: [UUID: Int] = [:]
        var number = 1
        for photo in photos where photo.isIncludedInPDF {
            map[photo.id] = number
            number += 1
        }
        return map
    }
    
    // 仕様: LazyVGrid、adaptive(minimum: 100, maximum: 140)、spacing: 10
    private let columns = [
        GridItem(.adaptive(minimum: 85), spacing: 10)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 全体メモ（トグル付き）
                overallNoteSection

                // タグセクション
                tagSection

                // 詳細（曜日・時間）- 表紙表示時のみ
                if caseItem.showCoverPage {
                    detailsSection
                }
                
                // 写真ヘッダー: 「写真 N枚」
                photoHeaderSection
                
                // 写真追加ボタン
                photoAddSection
                
                // 写真グリッド
                photoGridSection
                
                // 添付PDFセクション
                attachmentSection
            }
            .padding()
        }
        // 仕様: 背景 Color(.systemGray6)
        .background(Color(.systemGray6))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // カスタムタイトル（直接編集可能）
            ToolbarItem(placement: .principal) {
                TextField("案件名", text: $caseItem.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .onChange(of: caseItem.title) { _, _ in
                        caseItem.touch()
                    }
            }
            // 仕様: ツールバー右上 square.and.arrow.up
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    // Preview Button
                    Button(action: { generatePDF(forPreview: true) }) {
                        if isGeneratingPDF && showPDFPreview {
                            ProgressView()
                        } else {
                            Image(systemName: "eye")
                                .foregroundColor(accentGreen)
                        }
                    }
                    .disabled(isGeneratingPDF || !hasIncludedPDFPhotos)
                    
                    // Share Button
                    Button(action: { generatePDF(forPreview: false) }) {
                        if isGeneratingPDF && !showPDFPreview {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(accentGreen)
                        }
                    }
                    .disabled(isGeneratingPDF || !hasIncludedPDFPhotos)
                }
            }
            
            // キーボード完了ボタン（リスト表示時は上下ナビも表示）
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                
                // リスト表示時のみ上下ナビゲーションを表示
                if photoViewMode == .list {
                    // 上の写真に移動
                    Button(action: {
                        moveFocusToPreviousPhoto()
                    }) {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(!canMoveToPrevious())
                    
                    // 下の写真に移動
                    Button(action: {
                        moveFocusToNextPhoto()
                    }) {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(!canMoveToNext())
                }
                
                Button("完了") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                addPhotoFromCamera(image)
            }
        }
        .sheet(isPresented: $showScanner) {
            DocumentScanner { images in
                for image in images {
                    addScannedPhoto(image)
                }
            }
        }
        .sheet(isPresented: $showPDFPreview) {
             if let url = pdfURL {
                 PDFPreviewView(url: url)
             }
        }
        .sheet(isPresented: $showPDFShare) {
            if let url = pdfURL {
                ShareSheet(activityItems: [url])
            } else if let data = pdfData {
                ShareSheet(activityItems: [data])
            }
        }
        .fullScreenCover(item: $photoForMarkup) { photo in
            // 撮影後のマークアップ画面
            NavigationStack {
                MarkupLoaderView(photo: photo)
            }
        }
        .onChange(of: selectedPhotoItems) { oldValue, newValue in
            Task {
                await loadSelectedPhotos()
            }
        }
        // 仕様: サムネイル更新 NotificationCenter購読で即座反映
        .onReceive(NotificationCenter.default.publisher(for: ImageStorage.thumbUpdatedNotification)) { _ in
            thumbUpdateTrigger = UUID()
        }
        .alert("写真を削除", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                if let photo = photoToDelete {
                    deletePhoto(photo)
                }
            }
        } message: {
            Text("この写真を削除してもよろしいですか？")
        }
        .alert("写真を結合", isPresented: $showComposeConfirmAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("結合", role: .destructive) {
                composePhotos()
            }
        } message: {
            Text("\(selectedPhotosForCompose.count)枚の写真を1枚に結合します。元の写真は削除されます。")
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { urls in
                for url in urls {
                    addAttachment(from: url)
                }
            }
        }
        .alert("添付ファイルを削除", isPresented: $showAttachmentDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                if let attachment = attachmentToDelete {
                    deleteAttachment(attachment)
                }
            }
        } message: {
            Text("この添付ファイルを削除してもよろしいですか？")
        }
        .sheet(isPresented: $showPDFImportPicker) {
            DocumentPickerView { urls in
                Task {
                    await importPDFAsPhotos(urls: urls)
                }
            }
        }
        .alert("PDF取込エラー", isPresented: $showPDFImportFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("以下のファイルは取り込めませんでした（パスワード保護または破損の可能性）:\n\(pdfImportFailedFiles.joined(separator: "\n"))")
        }
    }
    
    // MARK: - タグセクション

    @Query(sort: \Tag.createdAt, order: .forward) private var allTagsForDetail: [Tag]

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("タグ")
                    .font(.headline)
                Spacer()
                Button {
                    showTagSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "tag")
                        Text("編集")
                    }
                    .font(.subheadline)
                    .foregroundColor(accentGreen)
                }
            }

            if caseItem.tags.isEmpty {
                Text("タグなし")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(caseItem.tags) { tag in
                            Text(tag.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(tag.color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(tag.color.opacity(0.15))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(tag.color.opacity(0.35), lineWidth: 1))
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showTagSheet) {
            TagPickerSheet(
                caseItem: caseItem,
                allTags: allTagsForDetail,
                onCreateTag: { name in
                    let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !n.isEmpty else { return }
                    let tag = Tag(name: n)
                    modelContext.insert(tag)
                    try? modelContext.save()
                }
            )
        }
    }

    // MARK: - 全体メモセクション
    // 仕様: TextField、2〜5行、systemGray6背景、角丸8

    private var overallNoteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // メモヘッダー（トグル付き）
            HStack {
                Text("メモ")
                    .font(.headline)
                
                Spacer()
                
                Toggle("", isOn: $caseItem.showCoverPage)
                    .labelsHidden()
                    .tint(accentGreen)
                    .onChange(of: caseItem.showCoverPage) { _, _ in
                        caseItem.touch()
                    }
            }
            
            // メモ入力欄（表紙表示時のみ）
            if caseItem.showCoverPage {
                TextField("メモを入力...", text: $caseItem.overallNote, axis: .vertical)
                    .lineLimit(2...5)
                    .padding(10)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                    .onChange(of: caseItem.overallNote) { _, _ in
                        caseItem.touch()
                    }
            }
        }
    }
    
    // MARK: - 写真ヘッダーセクション
    // 仕様: 「写真 N枚」
    
    private var photoHeaderSection: some View {
        HStack {
            if isComposeMode {
                // 結合モード時のヘッダー
                Text("結合する写真を選択 (\(selectedPhotosForCompose.count)/4)")
                    .font(.headline)
                    .foregroundColor(accentGreen)
                
                Spacer()
                
                // キャンセルボタン
                Button("キャンセル") {
                    withAnimation {
                        isComposeMode = false
                        selectedPhotosForCompose.removeAll()
                    }
                }
                .foregroundColor(.secondary)
                
                // 結合実行ボタン
                Button("結合") {
                    showComposeConfirmAlert = true
                }
                .foregroundColor(selectedPhotosForCompose.count >= 2 ? accentGreen : .gray)
                .fontWeight(.bold)
                .disabled(selectedPhotosForCompose.count < 2)
            } else {
                // 通常モード
                Text("写真 \(caseItem.photos.count)枚")
                    .font(.headline)
                
                Spacer()

                // 白紙A4追加ボタン（結合ボタンの左）
                Button(action: addBlankA4Photo) {
                    Image(systemName: "doc.badge.plus")
                        .foregroundColor(caseItem.photos.count >= maxPhotos ? .gray : accentGreen)
                }
                .disabled(caseItem.photos.count >= maxPhotos)
                
                // 結合ボタン（2枚以上あれば表示）
                if caseItem.photos.count >= 2 {
                    Button(action: {
                        withAnimation {
                            isComposeMode = true
                            selectedPhotosForCompose.removeAll()
                        }
                    }) {
                        Image(systemName: "rectangle.on.rectangle")
                            .foregroundColor(accentGreen)
                    }
                }
                
                // 表示モード切り替えボタン
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        photoViewMode = (photoViewMode == .grid) ? .list : .grid
                    }
                }) {
                    Image(systemName: photoViewMode == .grid ? "list.bullet" : "square.grid.2x2")
                        .foregroundColor(accentGreen)
                }
            }
        }
    }
    
    // MARK: - 写真追加セクション
    // 仕様: PhotosPicker「追加」+ カメラ「撮影」+ スキャン「スキャン」、systemGray5背景
    
    private struct PhotoActionLabelMetrics {
        let iconSize: CGFloat
        let textSize: CGFloat
        let itemSpacing: CGFloat
        let horizontalPadding: CGFloat
        let rowHeight: CGFloat
    }
    
    private func photoActionLabelMetrics(buttonWidth: CGFloat) -> PhotoActionLabelMetrics {
        if buttonWidth < 70 {
            return PhotoActionLabelMetrics(
                iconSize: 10.5,
                textSize: 10,
                itemSpacing: 2,
                horizontalPadding: 2,
                rowHeight: 40
            )
        } else if buttonWidth < 82 {
            return PhotoActionLabelMetrics(
                iconSize: 11,
                textSize: 10.5,
                itemSpacing: 3,
                horizontalPadding: 3,
                rowHeight: 42
            )
        } else {
            return PhotoActionLabelMetrics(
                iconSize: 12,
                textSize: 11,
                itemSpacing: 4,
                horizontalPadding: 4,
                rowHeight: 44
            )
        }
    }
    
    private func photoActionLabel(
        title: String,
        systemImage: String,
        isAtLimit: Bool,
        metrics: PhotoActionLabelMetrics
    ) -> some View {
        HStack(spacing: metrics.itemSpacing) {
            Image(systemName: systemImage)
                .font(.system(size: metrics.iconSize, weight: .semibold))
                .frame(width: metrics.iconSize + 2)
            
            Text(title)
                .font(.system(size: metrics.textSize, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, minHeight: metrics.rowHeight)
        .padding(.horizontal, metrics.horizontalPadding)
        .background(isAtLimit ? Color(.systemGray4) : Color(.systemGray5))
        .cornerRadius(8)
    }
    
    private var photoAddSection: some View {
        let isAtLimit = caseItem.photos.count >= maxPhotos
        let remainingSlots = maxPhotos - caseItem.photos.count
        let hasCamera = UIImagePickerController.isSourceTypeAvailable(.camera)
        let hasScanner = VNDocumentCameraViewController.isSupported
        let buttonCount = 2 + (hasCamera ? 1 : 0) + (hasScanner ? 1 : 0)
        
        return VStack(spacing: 8) {
            // 上限到達時のメッセージ
            if isAtLimit {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("写真の上限（\(maxPhotos)枚）に達しました")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            GeometryReader { proxy in
                let compact = proxy.size.width < 360
                let spacing: CGFloat = compact ? 8 : 12
                let buttonWidth = (proxy.size.width - spacing * CGFloat(max(0, buttonCount - 1))) / CGFloat(max(1, buttonCount))
                let metrics = photoActionLabelMetrics(buttonWidth: buttonWidth)
                
                HStack(spacing: spacing) {
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: max(0, remainingSlots),
                        matching: .images
                    ) {
                        photoActionLabel(
                            title: "追加",
                            systemImage: "photo.on.rectangle",
                            isAtLimit: isAtLimit,
                            metrics: metrics
                        )
                    }
                    .disabled(isAtLimit)
                    
                    // 仕様: カメラ使用前に isSourceTypeAvailable(.camera) で確認
                    if hasCamera {
                        Button(action: {
                            showCamera = true
                        }) {
                            photoActionLabel(
                                title: "撮影",
                                systemImage: "camera",
                                isAtLimit: isAtLimit,
                                metrics: metrics
                            )
                        }
                        .disabled(isAtLimit)
                    }
                    
                    // スキャン機能 (VisionKitが利用可能な場合)
                    if hasScanner {
                        Button(action: {
                            showScanner = true
                        }) {
                            photoActionLabel(
                                title: "スキャン",
                                systemImage: "viewfinder",
                                isAtLimit: isAtLimit,
                                metrics: metrics
                            )
                        }
                        .disabled(isAtLimit)
                    }
                    
                    // PDF取込（写真として取り込み）
                    Button(action: {
                        showPDFImportPicker = true
                    }) {
                        photoActionLabel(
                            title: "PDF",
                            systemImage: "doc.fill",
                            isAtLimit: isAtLimit,
                            metrics: metrics
                        )
                    }
                    .disabled(isAtLimit || isImportingPDF)
                }
                .foregroundColor(isAtLimit ? .gray : accentGreen)
            }
            .frame(height: 44)
            
            // インポート中表示
            if isImportingPDF {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("PDFを取り込み中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - 写真グリッドセクション
    // 仕様: 並替モード ドラッグ&ドロップ
    
    @ViewBuilder
    private var photoGridSection: some View {
        if photoViewMode == .grid {
            gridPhotoView
        } else {
            listPhotoView
        }
    }
    
    // グリッド表示
    private var gridPhotoView: some View {
        let screenWidth = UIScreen.main.bounds.width
        let sortedPhotos = caseItem.sortedPhotos
        let exportNumbers = exportNumberMap(for: sortedPhotos)
        // パディング(16*2)を考慮した有効幅
        let availableWidth = screenWidth - 32
        // セル間のスペース
        let spacing: CGFloat = 10
        // 目標とするアイテム幅（これを目安に列数を決定）
        let targetItemWidth: CGFloat = 100 
        
        // (有効幅 + スペース) / (アイテム幅 + スペース) で列数を概算
        let columnsCount = max(3, Int((availableWidth + spacing) / (targetItemWidth + spacing)))
        
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnsCount)
        
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(sortedPhotos) { photo in
                ZStack {
                    PhotoThumbView(
                        photo: photo,
                        exportNumber: exportNumbers[photo.id],
                        isIncludedInPDF: photo.isIncludedInPDF,
                        onTogglePDFInclusion: {
                            photo.isIncludedInPDF.toggle()
                            caseItem.touch()
                        },
                        isReordering: false,
                        updateTrigger: thumbUpdateTrigger,
                        onDuplicate: { duplicatePhoto(photo) },
                        onDelete: {
                            photoToDelete = photo
                            showDeleteAlert = true
                        }
                    )
                    
                    // 結合モード時のオーバーレイ
                    if isComposeMode {
                        let isSelected = selectedPhotosForCompose.contains(photo.id)
                        
                        // 選択状態オーバーレイ
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? accentGreen.opacity(0.3) : Color.black.opacity(0.2))
                        
                        // チェックマーク
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? accentGreen : Color.white.opacity(0.8))
                                        .frame(width: 24, height: 24)
                                    
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(6)
                            }
                            Spacer()
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if isComposeMode {
                        togglePhotoSelection(photo)
                    }
                }
                // ドラッグ中のビジュアルフィードバック
                .scaleEffect(draggingPhoto?.id == photo.id ? 1.05 : 1.0)
                .opacity(draggingPhoto?.id == photo.id ? 0.7 : 1.0)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(dropTargetPhotoId == photo.id ? accentGreen : .clear, lineWidth: 3)
                )
                .animation(.easeInOut(duration: 0.15), value: draggingPhoto?.id)
                .animation(.easeInOut(duration: 0.15), value: dropTargetPhotoId)
                .onDrag {
                    guard !isComposeMode else { return NSItemProvider() }
                    // ハプティックフィードバック
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    self.draggingPhoto = photo
                    return NSItemProvider(object: photo.id.uuidString as NSString)
                }
                .onDrop(of: [UTType.text], delegate: PhotoDropDelegate(
                    photo: photo,
                    caseItem: caseItem,
                    draggingPhoto: draggingPhoto,
                    modelContext: modelContext,
                    dropTargetPhotoId: $dropTargetPhotoId,
                    onDropComplete: {
                        // ドラッグ終了時のハプティックフィードバック
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        draggingPhoto = nil
                    }
                ))
            }
        }
    }
    
    // リスト表示（写真 + メモ入力欄）
    private var listPhotoView: some View {
        // 画面幅に応じてサムネイルサイズを動的に計算
        let screenWidth = UIScreen.main.bounds.width
        let isCompactWidth = screenWidth <= 375
        let thumbnailSize: CGFloat = isCompactWidth
            ? max(96, min(112, screenWidth * 0.28))
            : max(100, min(132, screenWidth * 0.25))
        let sortedPhotos = caseItem.sortedPhotos
        let exportNumbers = exportNumberMap(for: sortedPhotos)
        
        return LazyVStack(spacing: 12) {
            ForEach(sortedPhotos) { photo in
                HStack(alignment: .top, spacing: 12) {
                    // 写真サムネイル（PhotoThumbViewを使用、動的サイズ）
                    ZStack {
                        PhotoThumbView(
                            photo: photo,
                            exportNumber: exportNumbers[photo.id],
                            isIncludedInPDF: photo.isIncludedInPDF,
                            onTogglePDFInclusion: {
                                photo.isIncludedInPDF.toggle()
                                caseItem.touch()
                            },
                            isReordering: false,
                            updateTrigger: thumbUpdateTrigger,
                            onDuplicate: { duplicatePhoto(photo) },
                            onDelete: {
                                photoToDelete = photo
                                showDeleteAlert = true
                            }
                        )
                        
                        // 結合モード時のオーバーレイ
                        if isComposeMode {
                            let isSelected = selectedPhotosForCompose.contains(photo.id)
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? accentGreen.opacity(0.3) : Color.black.opacity(0.2))
                            
                            VStack {
                                HStack {
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .fill(isSelected ? accentGreen : Color.white.opacity(0.8))
                                            .frame(width: 24, height: 24)
                                        
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(6)
                                }
                                Spacer()
                            }
                        }
                    }
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isComposeMode {
                            togglePhotoSelection(photo)
                        }
                    }
                    
                    // メモ入力欄（結合モード時は非表示）
                    if !isComposeMode {
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("メモを入力...", text: Binding(
                                get: { photo.note },
                                set: { newValue in
                                    photo.note = newValue
                                    caseItem.touch()
                                }
                            ), axis: .vertical)
                            .lineLimit(6)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .focused($focusedPhotoId, equals: photo.id)
                            
                            // 6行を超えている場合、超過分を赤で表示
                            let lines = photo.note.components(separatedBy: "\n")
                            if lines.count > 6 {
                                let overflowLines = Array(lines.dropFirst(6))
                                Text(overflowLines.joined(separator: "\n"))
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .lineLimit(nil)
                                
                                Text("※7行目以降はPDFに表示されません")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        .frame(minHeight: thumbnailSize, alignment: .topLeading)
                    }
                }
                .padding(.vertical, 4)
                // ドラッグ中のビジュアルフィードバック
                .scaleEffect(draggingPhoto?.id == photo.id ? 1.02 : 1.0)
                .opacity(draggingPhoto?.id == photo.id ? 0.7 : 1.0)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(dropTargetPhotoId == photo.id ? accentGreen : .clear, lineWidth: 2)
                )
                .animation(.easeInOut(duration: 0.15), value: draggingPhoto?.id)
                .animation(.easeInOut(duration: 0.15), value: dropTargetPhotoId)
                .onDrag {
                    guard !isComposeMode else { return NSItemProvider() }
                    // ハプティックフィードバック
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    self.draggingPhoto = photo
                    return NSItemProvider(object: photo.id.uuidString as NSString)
                }
                .onDrop(of: [UTType.text], delegate: PhotoDropDelegate(
                    photo: photo,
                    caseItem: caseItem,
                    draggingPhoto: draggingPhoto,
                    modelContext: modelContext,
                    dropTargetPhotoId: $dropTargetPhotoId,
                    onDropComplete: {
                        // ドラッグ終了時のハプティックフィードバック
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        draggingPhoto = nil
                    }
                ))
            }
        }
    }
    
    // 前の写真に移動可能か
    private func canMoveToPrevious() -> Bool {
        let photos = caseItem.sortedPhotos
        guard let currentId = focusedPhotoId,
              let currentIndex = photos.firstIndex(where: { $0.id == currentId }) else { return false }
        return currentIndex > 0
    }
    
    // 次の写真に移動可能か
    private func canMoveToNext() -> Bool {
        let photos = caseItem.sortedPhotos
        guard let currentId = focusedPhotoId,
              let currentIndex = photos.firstIndex(where: { $0.id == currentId }) else { return false }
        return currentIndex < photos.count - 1
    }
    
    // 前の写真のメモにフォーカスを移動
    private func moveFocusToPreviousPhoto() {
        let photos = caseItem.sortedPhotos
        guard let currentId = focusedPhotoId,
              let currentIndex = photos.firstIndex(where: { $0.id == currentId }),
              currentIndex > 0 else { return }
        focusedPhotoId = photos[currentIndex - 1].id
    }
    
    // 次の写真のメモにフォーカスを移動
    private func moveFocusToNextPhoto() {
        let photos = caseItem.sortedPhotos
        guard let currentId = focusedPhotoId,
              let currentIndex = photos.firstIndex(where: { $0.id == currentId }),
              currentIndex < photos.count - 1 else { return }
        focusedPhotoId = photos[currentIndex + 1].id
    }
    
    // MARK: - Actions
    
    // MARK: - Actions
    
    private var detailsSection: some View {
        DisclosureGroup("詳細", isExpanded: $isDetailsExpanded) {
            VStack(alignment: .leading, spacing: 16) {
                // 所在地行
                HStack(alignment: .center, spacing: 12) {
                    detailLabel("所在地")
                    
                    TextField("所在地を入力...", text: $caseItem.address)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: caseItem.address) { _, _ in
                            caseItem.touch()
                        }
                    
                    if !caseItem.address.isEmpty {
                        Button(action: {
                            caseItem.address = ""
                            caseItem.touch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // エリア行
                HStack(alignment: .center, spacing: 12) {
                    detailLabel("エリア")
                    
                    TextField("エリアを入力...", text: $caseItem.area)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: caseItem.area) { _, _ in
                            caseItem.touch()
                        }
                    
                    if !caseItem.area.isEmpty {
                        Button(action: {
                            caseItem.area = ""
                            caseItem.touch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 曜日行
                HStack(alignment: .center, spacing: 12) {
                    detailLabel("曜日")
                    
                    HStack(spacing: 2) {
                        // 月(2)〜日(1)の順で表示
                        let weekDays = [2, 3, 4, 5, 6, 7, 1]
                        let labels = ["月", "火", "水", "木", "金", "土", "日"]
                        
                        ForEach(0..<weekDays.count, id: \.self) { index in
                            let day = weekDays[index]
                            let label = labels[index]
                            let isSelected = caseItem.workWeekdays.contains(day)
                            
                            Button(action: {
                                toggleWeekday(day)
                            }) {
                                Text(label)
                                    .font(.caption) // 少し小さくして1列に収める
                                    .fontWeight(isSelected ? .bold : .regular)
                                    .frame(width: 28, height: 28)
                                    .background(isSelected ? accentGreen : Color(.systemGray5))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer()
                    
                    if !caseItem.workWeekdays.isEmpty {
                        Button(action: {
                            caseItem.workWeekdays.removeAll()
                            caseItem.touch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 時間行
                HStack(alignment: .center, spacing: 12) {
                    detailLabel("時間")
                    
                    // 開始時間
                    if let start = caseItem.workStartTime {
                        DatePicker("", selection: Binding<Date>(
                            get: { start },
                            set: { newDate in
                                caseItem.workStartTime = newDate
                                caseItem.touch()
                            }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    } else {
                        Text("--:--")
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                // タップでデフォルト値をセット
                                let now = Date()
                                let cal = Calendar.current
                                var comps = cal.dateComponents([.year, .month, .day], from: now)
                                comps.hour = 9; comps.minute = 0
                                caseItem.workStartTime = cal.date(from: comps)
                                caseItem.touch()
                            }
                    }
                    
                    Text("〜")
                        .foregroundColor(.secondary)
                    
                    // 終了時間
                    if let end = caseItem.workEndTime {
                        DatePicker("", selection: Binding<Date>(
                            get: { end },
                            set: { newDate in
                                caseItem.workEndTime = newDate
                                caseItem.touch()
                            }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    } else {
                        Text("--:--")
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                let now = Date()
                                let cal = Calendar.current
                                var comps = cal.dateComponents([.year, .month, .day], from: now)
                                comps.hour = 17; comps.minute = 0
                                caseItem.workEndTime = cal.date(from: comps)
                                caseItem.touch()
                            }
                    }
                    
                    Spacer()
                    
                    if caseItem.workStartTime != nil || caseItem.workEndTime != nil {
                        Button(action: {
                            caseItem.workStartTime = nil
                            caseItem.workEndTime = nil
                            caseItem.touch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .padding(10)
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
    
    // ラベル共通化 helper
    private func detailLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundColor(accentGreen)
            .frame(width: 50, alignment: .leading) // 幅を固定して揃える
    }
    
    private func toggleWeekday(_ day: Int) {
        if caseItem.workWeekdays.contains(day) {
            caseItem.workWeekdays.removeAll { $0 == day }
        } else {
            caseItem.workWeekdays.append(day)
        }
        caseItem.touch() // 更新日時更新
    }
    
    // MARK: - アクション
    
    private func loadSelectedPhotos() async {
        for item in selectedPhotoItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    addPhoto(image)
                }
            }
        }
        await MainActor.run {
            selectedPhotoItems = []
        }
    }
    
    private func addPhoto(_ image: UIImage) {
        guard let fileName = ImageStorage.shared.saveImage(image) else { return }
        
        let photo = CasePhoto(imageFileName: fileName, orderIndex: caseItem.photos.count)
        photo.parentCase = caseItem
        caseItem.photos.append(photo)
        caseItem.touch()
        
        try? modelContext.save()
    }

    private func addScannedPhoto(_ image: UIImage) {
        guard let fileName = ImageStorage.shared.saveScannedImage(image) else { return }

        let photo = CasePhoto(imageFileName: fileName, orderIndex: caseItem.photos.count)
        photo.parentCase = caseItem
        caseItem.photos.append(photo)
        caseItem.touch()

        try? modelContext.save()
    }

    private func addBlankA4Photo() {
        guard caseItem.photos.count < maxPhotos else { return }
        let image = createBlankA4Image()
        addPhoto(image)
    }

    private func createBlankA4Image() -> UIImage {
        // A4縦比率（約1:1.414）。容量を抑えつつ十分な解像度で生成。
        let size = CGSize(width: 1240, height: 1754)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    /// カメラ撮影後の処理: iOS標準写真アプリに保存し、マークアップ画面へ遷移
    private func addPhotoFromCamera(_ image: UIImage) {
        guard let fileName = ImageStorage.shared.saveImage(image) else { return }
        
        let photo = CasePhoto(imageFileName: fileName, orderIndex: caseItem.photos.count)
        photo.parentCase = caseItem
        caseItem.photos.append(photo)
        caseItem.touch()
        
        try? modelContext.save()
        
        // iOS標準写真アプリに保存
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            if status == .authorized || status == .limited {
                PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.creationRequestForAsset(from: image)
                } completionHandler: { success, error in
                    if let error = error {
                        print("写真アプリへの保存エラー: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // マークアップ画面へ遷移
        DispatchQueue.main.async {
            self.photoForMarkup = photo
        }
    }
    
    private func duplicatePhoto(_ photo: CasePhoto) {
        guard let image = ImageStorage.shared.loadImage(photo.imageFileName),
              let newFileName = ImageStorage.shared.saveImage(image) else { return }
        
        // 元の写真のインデックスを取得
        let originalIndex = photo.orderIndex
        
        // 新しい写真を作成（元の写真のすぐ後ろに挿入）
        let newPhoto = CasePhoto(imageFileName: newFileName, orderIndex: originalIndex + 1)
        newPhoto.note = photo.note
        newPhoto.markupData = photo.markupData
        newPhoto.annotationData = photo.annotationData
        newPhoto.textOverlayData = photo.textOverlayData
        newPhoto.isComposite = photo.isComposite
        newPhoto.sourceImageFileNames = photo.sourceImageFileNames
        newPhoto.isFullPage = photo.isFullPage
        newPhoto.isIncludedInPDF = photo.isIncludedInPDF
        newPhoto.isStampSummaryEnabled = photo.isStampSummaryEnabled
        newPhoto.stampLegendMeaningsData = photo.stampLegendMeaningsData
        newPhoto.parentCase = caseItem
        
        // 元の写真より後ろにある全ての写真のorderIndexを+1
        for existingPhoto in caseItem.photos {
            if existingPhoto.orderIndex > originalIndex {
                existingPhoto.orderIndex += 1
            }
        }
        
        caseItem.photos.append(newPhoto)
        caseItem.touch()
        
        // サムネイル更新
        if photo.markupData != nil || photo.textOverlayData != nil {
            ImageStorage.shared.updateThumbSync(
                newFileName,
                drawing: photo.drawing,
                textOverlay: photo.textOverlay
            )
        }
        
        try? modelContext.save()
    }
    
    private func deletePhoto(_ photo: CasePhoto) {
        ImageStorage.shared.deleteImage(photo.imageFileName)
        
        if let index = caseItem.photos.firstIndex(of: photo) {
            caseItem.photos.remove(at: index)
        }
        
        caseItem.normalizePhotoOrder()
        caseItem.touch()
        
        try? modelContext.save()
    }
    
    // MARK: - 写真結合
    
    private func togglePhotoSelection(_ photo: CasePhoto) {
        if selectedPhotosForCompose.contains(photo.id) {
            selectedPhotosForCompose.remove(photo.id)
        } else if selectedPhotosForCompose.count < 4 {
            selectedPhotosForCompose.insert(photo.id)
        }
    }
    
    private func composePhotos() {
        // 選択された写真をorderIndex順で取得
        let selectedPhotos = caseItem.sortedPhotos.filter { selectedPhotosForCompose.contains($0.id) }
        guard selectedPhotos.count >= 2 else { return }
        
        // 元画像のファイル名リスト
        let sourceFileNames = selectedPhotos.map { $0.imageFileName }
        
        // 結合画像を生成
        guard let compositeFileName = ImageStorage.shared.composeImages(sourceFileNames) else { return }
        
        // 最初に選択された写真のインデックスを取得
        let insertIndex = selectedPhotos.first?.orderIndex ?? caseItem.photos.count
        
        // 新しい結合写真を作成
        let compositePhoto = CasePhoto(imageFileName: compositeFileName, orderIndex: insertIndex)
        compositePhoto.isComposite = true
        compositePhoto.sourceImageFileNames = sourceFileNames
        compositePhoto.parentCase = caseItem
        
        // 元写真を削除（ファイルは保持、CasePhotoレコードのみ削除）
        for photo in selectedPhotos {
            if let index = caseItem.photos.firstIndex(of: photo) {
                caseItem.photos.remove(at: index)
            }
            // ファイルは削除しない（解除時に復元するため）
        }
        
        // 結合写真を追加
        caseItem.photos.append(compositePhoto)
        caseItem.normalizePhotoOrder()
        caseItem.touch()
        
        try? modelContext.save()
        
        // モード終了
        withAnimation {
            isComposeMode = false
            selectedPhotosForCompose.removeAll()
        }
    }
    
    // 仕様: PDF生成 Task.detached を使用
    private func generatePDF(forPreview: Bool) {
        isGeneratingPDF = true
        // Optimistic UI Removed to ensure fresh content
        
        Task {
            let generator = PDFGenerator()
            if let data = await generator.generatePDF(for: caseItem) {
                // 一時ファイルに保存（毎回新しいフォルダを作成して、強制的にURLを変更する）
                let fileName = caseItem.title.isEmpty ? "SiteSurvey.pdf" : "\(caseItem.title).pdf"
                let safeFileName = fileName.replacingOccurrences(of: "/", with: "-")
                
                // UUIDフォルダを作成
                let uniqueDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try? FileManager.default.createDirectory(at: uniqueDir, withIntermediateDirectories: true, attributes: nil)
                
                let tempURL = uniqueDir.appendingPathComponent(safeFileName)
                
                try? data.write(to: tempURL)
                
                await MainActor.run {
                    pdfData = nil // DataではなくURLを使うため
                    isGeneratingPDF = false
                    
                    // 生成完了後にURLをセットしてからフラグを立てる
                    self.pdfURL = tempURL
                    
                    if forPreview {
                        showPDFPreview = true
                    } else {
                        showPDFShare = true
                    }
                }
            } else {
                await MainActor.run {
                     isGeneratingPDF = false
                }
            }
        }
    }

}

// MARK: - PhotoDropDelegate（ドラッグ&ドロップ並替）

struct PhotoDropDelegate: DropDelegate {
    let photo: CasePhoto
    let caseItem: Case
    let draggingPhoto: CasePhoto?
    let modelContext: ModelContext
    @Binding var dropTargetPhotoId: UUID?
    var onDropComplete: (() -> Void)?
    
    func performDrop(info: DropInfo) -> Bool {
        // ドロップ完了時にハイライトをクリアしてコールバックを呼び出す
        DispatchQueue.main.async {
            dropTargetPhotoId = nil
            onDropComplete?()
        }
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingPhoto = draggingPhoto else { return }
        guard draggingPhoto != photo else {
            // ドラッグ元と同じ場所ではハイライトしない
            dropTargetPhotoId = nil
            return
        }
        
        // ドロップターゲットをハイライト
        dropTargetPhotoId = photo.id
        
        // Use sortedPhotos to get the visual index
        var sorted = caseItem.sortedPhotos
        
        guard let fromIndex = sorted.firstIndex(of: draggingPhoto),
              let toIndex = sorted.firstIndex(of: photo) else { return }
        
        if fromIndex != toIndex {
            withAnimation {
                // Move in the sorted array
                let movedPhoto = sorted.remove(at: fromIndex)
                sorted.insert(movedPhoto, at: toIndex)
                
                // Update orderIndex for ALL photos based on new sorted order
                for (index, p) in sorted.enumerated() {
                    p.orderIndex = index
                }
                
                // Invalidate cache and notify
                caseItem.invalidateSortCache() // Ensure the model knows the sort changed
                caseItem.touch()
                
                // Note: We don't need to mutate caseItem.photos array order itself 
                // because sorting relies on orderIndex.
            }
        }
    }
    
    func dropExited(info: DropInfo) {
        // ドロップエリアから離れたらハイライトをクリア
        if dropTargetPhotoId == photo.id {
            dropTargetPhotoId = nil
        }
    }
}

// MARK: - PhotoThumbView
// 仕様: 番号バッジ（緑）+ マークアップ（オレンジ）+ 複製（緑）+ 削除（赤）

struct PhotoThumbView: View {
    let photo: CasePhoto
    let exportNumber: Int?
    let isIncludedInPDF: Bool
    let onTogglePDFInclusion: () -> Void
    let isReordering: Bool
    let updateTrigger: UUID
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    
    @State private var thumbImage: UIImage?
    
    private let accentGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let isCompact = size < 100
            let buttonSize: CGFloat = isCompact ? 18 : 20
            let selectorSize: CGFloat = isCompact ? 26 : 30
            let imagePadding: CGFloat = isCompact ? 4 : 6
            let controlPadding: CGFloat = isCompact ? 3 : 4
            
            ZStack(alignment: .topLeading) {
                NavigationLink(destination: PhotoDetailView(photo: photo)) {
                    ZStack {
                        // 背景（白）
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        
                        // サムネイル画像（全体表示）
                        if let image = thumbImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(.horizontal, imagePadding)
                                .padding(.top, imagePadding)
                                .padding(.bottom, buttonSize + controlPadding * 4)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        
                        // 操作ボタン（常にサムネイル内に収まる小型バー）
                        VStack {
                            Spacer()
                            HStack(spacing: controlPadding * 2) {
                                // マークアップボタン（オレンジ）
                                NavigationLink(destination: MarkupLoaderView(photo: photo)) {
                                    Image(systemName: "pencil.tip.crop.circle")
                                        .font(.system(size: buttonSize * 0.5))
                                        .foregroundColor(.white)
                                        .frame(width: buttonSize, height: buttonSize)
                                        .background(Color.orange)
                                        .clipShape(Circle())
                                }

                                Button(action: onDuplicate) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: buttonSize * 0.5))
                                        .foregroundColor(.white)
                                        .frame(width: buttonSize, height: buttonSize)
                                        .background(accentGreen)
                                        .clipShape(Circle())
                                }

                                Button(action: onDelete) {
                                    Image(systemName: "trash")
                                        .font(.system(size: buttonSize * 0.5))
                                        .foregroundColor(.white)
                                        .frame(width: buttonSize, height: buttonSize)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, controlPadding * 2)
                            .padding(.vertical, controlPadding)
                            .background(Color.black.opacity(0.36))
                            .clipShape(Capsule())
                            .padding(.bottom, controlPadding)
                        }
                        
                        if !isIncludedInPDF {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.22))
                        }
                    }
                    .frame(width: size, height: size)
                    .clipped() // はみ出し防止
                }
                .buttonStyle(.plain)
                .frame(width: geometry.size.width, height: geometry.size.height)
                
                // PDF/プレビュー出力対象トグル（左上・グレー）
                Button(action: onTogglePDFInclusion) {
                    Circle()
                        .fill(isIncludedInPDF ? accentGreen : Color(.systemGray3))
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.9), lineWidth: 1)
                        )
                        .overlay {
                            if isIncludedInPDF, let exportNumber {
                                Text("\(exportNumber)")
                                    .font(.system(size: selectorSize * 0.54, weight: .bold))
                                    .foregroundColor(.white)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                        .frame(width: selectorSize, height: selectorSize)
                }
                .frame(width: selectorSize + 10, height: selectorSize + 10)
                .buttonStyle(.plain)
                .padding(controlPadding + 1)
            }
        }
        .aspectRatio(1.0, contentMode: .fit) // 正方形を維持
        .onAppear {
            loadThumb()
        }
        .onChange(of: updateTrigger) { _, _ in
            loadThumb()
        }
    }
    
    private func loadThumb() {
        thumbImage = ImageStorage.shared.loadThumb(photo.imageFileName)
    }
}

// MARK: - CameraPicker
// 仕様: カメラ撮影画面も日本語

struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        
        init(_ parent: CameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - DocumentScanner
// 仕様: VisionKitを使用した書類スキャン

struct DocumentScanner: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        
        init(_ parent: DocumentScanner) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            parent.onScan(images)
            parent.dismiss()
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Scan error: \(error)")
            parent.dismiss()
        }
    }
}

// MARK: - 添付PDFセクション

extension CaseDetailView {
    private var attachmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("添付ファイル")
                    .font(.headline)
                
                Text("\(caseItem.attachments.count)件")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { showDocumentPicker = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("PDF追加")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(accentGreen)
                }
            }
            
            if caseItem.attachments.isEmpty {
                Text("PDFファイルを追加できます")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(sortedAttachments, id: \.id) { attachment in
                    AttachmentRow(
                        attachment: attachment,
                        onDelete: {
                            attachmentToDelete = attachment
                            showAttachmentDeleteAlert = true
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var sortedAttachments: [CaseAttachment] {
        caseItem.attachments.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    private func addAttachment(from url: URL) {
        guard let fileName = ImageStorage.shared.saveAttachment(from: url) else { return }
        
        let attachment = CaseAttachment(
            fileName: fileName,
            originalName: url.lastPathComponent,
            orderIndex: caseItem.attachments.count
        )
        attachment.parentCase = caseItem
        caseItem.attachments.append(attachment)
        caseItem.touch()
        try? modelContext.save()
    }
    
    private func deleteAttachment(_ attachment: CaseAttachment) {
        ImageStorage.shared.deleteAttachment(attachment.fileName)
        caseItem.attachments.removeAll { $0.id == attachment.id }
        modelContext.delete(attachment)
        caseItem.touch()
        try? modelContext.save()
    }
    
    // MARK: - PDF取込（写真化）
    
    @MainActor
    private func importPDFAsPhotos(urls: [URL]) async {
        isImportingPDF = true
        defer { isImportingPDF = false }
        
        let remainingSlots = maxPhotos - caseItem.photos.count
        var importedCount = 0
        var failedFiles: [String] = []
        
        print("PDF Import: Starting with \(urls.count) URLs")
        
        for url in urls {
            let fileName = url.lastPathComponent
            print("PDF Import: Processing \(fileName)")
            
            // asCopy: trueなのでセキュリティスコープは不要だが念のため
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // ファイルの存在確認
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("PDF Import: File does not exist at \(url.path)")
                failedFiles.append("\(fileName) (ファイルが見つかりません)")
                continue
            }
            
            // PDFドキュメントを読み込み - まずData経由で試行（より信頼性が高い）
            var pdfDoc: PDFDocument?
            
            if let data = try? Data(contentsOf: url) {
                pdfDoc = PDFDocument(data: data)
                if pdfDoc == nil {
                    print("PDF Import: Failed to create PDFDocument from Data")
                }
            }
            
            // Data経由で失敗した場合はURL経由で試行
            if pdfDoc == nil {
                pdfDoc = PDFDocument(url: url)
            }
            
            guard let loadedPDF = pdfDoc else {
                print("PDF Import: Failed to load PDF \(fileName)")
                failedFiles.append("\(fileName) (読み込み失敗)")
                continue
            }
            
            // ロック/暗号化チェック
            if loadedPDF.isLocked {
                print("PDF Import: PDF is locked \(fileName)")
                failedFiles.append("\(fileName) (パスワード保護)")
                continue
            }
            
            // ページ数チェック
            if loadedPDF.pageCount == 0 {
                print("PDF Import: PDF has no pages \(fileName)")
                failedFiles.append("\(fileName) (ページなし)")
                continue
            }
            
            print("PDF Import: Loaded PDF with \(loadedPDF.pageCount) pages")
            await processPages(from: loadedPDF, remainingSlots: remainingSlots, importedCount: &importedCount)
            
            if importedCount >= remainingSlots { break }
        }
        
        print("PDF Import: Completed, imported \(importedCount) pages")
        
        // 失敗したファイルがある場合は通知
        if !failedFiles.isEmpty {
            pdfImportFailedFiles = failedFiles
            showPDFImportFailedAlert = true
        }
    }
    
    @MainActor
    private func processPages(from pdfDoc: PDFDocument, remainingSlots: Int, importedCount: inout Int) async {
        for pageIndex in 0..<pdfDoc.pageCount {
            guard importedCount < remainingSlots else { break }
            guard let page = pdfDoc.page(at: pageIndex) else { continue }
            
            // 300 DPIでレンダリング（高品質）
            let pageRect = page.bounds(for: .mediaBox)
            let scale: CGFloat = 300.0 / 72.0  // PDF標準72dpi → 300dpi
            let renderSize = CGSize(
                width: pageRect.width * scale,
                height: pageRect.height * scale
            )
            
            // 画像生成
            let renderer = UIGraphicsImageRenderer(size: renderSize)
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: renderSize))
                
                ctx.cgContext.translateBy(x: 0, y: renderSize.height)
                ctx.cgContext.scaleBy(x: scale, y: -scale)
                
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            
            // 写真として保存
            addPhoto(image)
            importedCount += 1
            print("PDF Import: Added page \(pageIndex + 1)")
        }
    }
}

// MARK: - 添付ファイル行

struct AttachmentRow: View {
    let attachment: CaseAttachment
    let onDelete: () -> Void
    
    @State private var showPreview = false
    
    var body: some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundColor(.red)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.originalName)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onTapGesture {
            showPreview = true
        }
        .sheet(isPresented: $showPreview) {
            let url = ImageStorage.shared.getAttachmentURL(attachment.fileName)
            PDFPreviewView(url: url)
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: attachment.createdAt)
    }
}

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: ([URL]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        CaseDetailView(caseItem: Case())
    }
    .modelContainer(for: Case.self, inMemory: true)
}
