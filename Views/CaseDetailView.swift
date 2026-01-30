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
    
    @State private var draggingPhoto: CasePhoto? // ドラッグ中の写真を追跡
    
    // アクセントカラー（緑）- 仕様: Color(red: 0.2, green: 0.78, blue: 0.35)
    private let accentGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    private let maxPhotos = 20
    
    // 仕様: LazyVGrid、adaptive(minimum: 100, maximum: 140)、spacing: 10
    private let columns = [
        GridItem(.adaptive(minimum: 85), spacing: 10)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 全体メモ
                overallNoteSection
                
                // 詳細（曜日・時間）
                detailsSection
                
                // 写真ヘッダー: 「写真 N枚」
                photoHeaderSection
                
                // 写真追加ボタン（上限20枚まで）
                if caseItem.photos.count < maxPhotos {
                    photoAddSection
                }
                
                // 写真グリッド
                photoGridSection
            }
            .padding()
        }
        // 仕様: 背景 Color(.systemGray6)
        .background(Color(.systemGray6))
        // 仕様: ナビゲーションタイトル 編集可能（$caseItem.title）
        .navigationTitle($caseItem.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
                    .disabled(isGeneratingPDF || caseItem.photos.isEmpty)
                    
                    // Share Button
                    Button(action: { generatePDF(forPreview: false) }) {
                        if isGeneratingPDF && !showPDFPreview {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(accentGreen)
                        }
                    }
                    .disabled(isGeneratingPDF || caseItem.photos.isEmpty)
                }
            }
            
            // キーボード完了ボタン
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                addPhoto(image)
            }
        }
        .sheet(isPresented: $showScanner) {
            DocumentScanner { images in
                for image in images {
                    addPhoto(image)
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
    }
    
    // MARK: - 全体メモセクション
    // 仕様: TextField、2〜5行、systemGray6背景、角丸8
    
    private var overallNoteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("全体メモ")
                .font(.headline)
            
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
    
    // MARK: - 写真ヘッダーセクション
    // 仕様: 「写真 N枚」
    
    private var photoHeaderSection: some View {
        HStack {
            Text("写真 \(caseItem.photos.count)枚")
                .font(.headline)
            
            Spacer()
        }
    }
    
    // MARK: - 写真追加セクション
    // 仕様: PhotosPicker「追加」+ カメラ「撮影」+ スキャン「スキャン」、systemGray5背景
    
    private var photoAddSection: some View {
        HStack(spacing: 12) {
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: maxPhotos - caseItem.photos.count,
                matching: .images
            ) {
                Label("追加", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }
            
            // 仕様: カメラ使用前に isSourceTypeAvailable(.camera) で確認
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button(action: {
                    showCamera = true
                }) {
                    Label("撮影", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
                
                // スキャン機能 (VisionKitが利用可能な場合)
                if VNDocumentCameraViewController.isSupported {
                    Button(action: {
                        showScanner = true
                    }) {
                        Label("スキャン", systemImage: "doc.text.viewfinder")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .foregroundColor(accentGreen)
        .font(.caption.bold())
    }
    
    // MARK: - 写真グリッドセクション
    // 仕様: 並替モード ドラッグ&ドロップ
    
    private var photoGridSection: some View {
        let screenWidth = UIScreen.main.bounds.width
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
            ForEach(caseItem.sortedPhotos) { photo in
                PhotoThumbView(
                    photo: photo,
                    index: (caseItem.sortedPhotos.firstIndex(of: photo) ?? 0) + 1,
                    isReordering: false,
                    updateTrigger: thumbUpdateTrigger,
                    onDuplicate: { duplicatePhoto(photo) },
                    onDelete: {
                        photoToDelete = photo
                        showDeleteAlert = true
                    }
                )
                .onDrag {
                    self.draggingPhoto = photo
                    return NSItemProvider(object: photo.id.uuidString as NSString)
                }
                .onDrop(of: [UTType.text], delegate: PhotoDropDelegate(
                    photo: photo,
                    caseItem: caseItem,
                    draggingPhoto: draggingPhoto,
                    modelContext: modelContext
                ))
            }
        }
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
    
    private func duplicatePhoto(_ photo: CasePhoto) {
        guard let image = ImageStorage.shared.loadImage(photo.imageFileName),
              let newFileName = ImageStorage.shared.saveImage(image) else { return }
        
        let newPhoto = CasePhoto(imageFileName: newFileName, orderIndex: caseItem.photos.count)
        newPhoto.note = photo.note
        newPhoto.markupData = photo.markupData
        newPhoto.parentCase = caseItem
        
        caseItem.photos.append(newPhoto)
        caseItem.touch()
        
        // サムネイル更新
        if photo.markupData != nil {
            ImageStorage.shared.updateThumbSync(
                newFileName,
                drawing: photo.drawing
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
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingPhoto = draggingPhoto else { return }
        guard draggingPhoto != photo else { return }
        
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
}

// MARK: - PhotoThumbView
// 仕様: 番号バッジ（緑）+ マークアップ（オレンジ）+ 複製（緑）+ 削除（赤）

struct PhotoThumbView: View {
    let photo: CasePhoto
    let index: Int
    let isReordering: Bool
    let updateTrigger: UUID
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    
    @State private var thumbImage: UIImage?
    
    private let accentGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    

    
    var body: some View {
        NavigationLink(destination: PhotoDetailView(photo: photo)) {
            // 仕様: 正方形コンテナ
            Color.clear
                .aspectRatio(1.0, contentMode: .fit) // 正方形を強制
                .overlay(
                    ZStack(alignment: .topLeading) {
                        // 背景（白）
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        
                        // サムネイル画像（全体表示）
                        if let image = thumbImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit) // 全体を表示
                                .padding(8) // 余白を持たせる
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        
                        // 番号バッジ（緑円形）
                        ZStack {
                            Circle()
                                .fill(accentGreen)
                                .frame(width: 24, height: 24)
                            
                            Text("\(index)")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        .padding(6)
                        
                        // 操作ボタン
                        if true { // 常に表示
                            VStack {
                                Spacer()
                                HStack(spacing: 4) {
                                    // マークアップボタン（オレンジ）
                                    NavigationLink(destination: MarkupLoaderView(photo: photo)) {
                                        Image(systemName: "pencil.tip.crop.circle")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background(Color.orange)
                                            .clipShape(Circle())
                                    }
                                    
                                    Spacer()
                                    
                                    // 複製ボタン（緑）
                                    Button(action: onDuplicate) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background(accentGreen)
                                            .clipShape(Circle())
                                    }
                                    
                                    // 削除ボタン（赤）
                                    Button(action: onDelete) {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(6)
                            }
                        }
                    }
                )
        }
        .buttonStyle(.plain)
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

#Preview {
    NavigationStack {
        CaseDetailView(caseItem: Case())
    }
    .modelContainer(for: Case.self, inMemory: true)
}
