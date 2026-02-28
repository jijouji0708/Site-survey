//
//  CaseListView.swift
//  SiteSurvey
//
//  案件一覧画面（タグ管理対応版）
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - スコープ定義

fileprivate enum CaseScopeKind: Equatable {
    case all
    case untagged
    case archived
    case tag(Tag)

    static func == (lhs: CaseScopeKind, rhs: CaseScopeKind) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all), (.untagged, .untagged), (.archived, .archived): return true
        case (.tag(let a), .tag(let b)): return a.id == b.id
        default: return false
        }
    }
}

fileprivate struct CaseScopeItem: Identifiable, Equatable {
    let kind: CaseScopeKind
    let id: String
    let title: String

    static let all      = CaseScopeItem(kind: .all,      id: "scope_all",      title: "全ファイル")
    static let untagged = CaseScopeItem(kind: .untagged, id: "scope_untagged", title: "未分類")
    static let archived = CaseScopeItem(kind: .archived, id: "scope_archived", title: "アーカイブ")

    static func tag(_ tag: Tag) -> CaseScopeItem {
        CaseScopeItem(kind: .tag(tag), id: "scope_tag_\(tag.id.uuidString)", title: tag.name)
    }
}

// MARK: - 最大タグ数
private let maxTagsPerCase = 3

// MARK: - タグカラーパレット
private let tagColorPalette: [String] = [
    "#4A90E2", // Blue
    "#7B68EE", // Medium Slate Blue
    "#FF6B6B", // Coral Red
    "#F5A623", // Orange
    "#27AE60", // Emerald Green
    "#1ABC9C", // Turquoise
    "#E91E63", // Pink
    "#9B59B6", // Amethyst
    "#F39C12", // Sunflower
    "#2C3E50", // Dark Blue Gray
]

// MARK: - CaseListView

struct CaseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Case> { $0.isArchived == false }, sort: \Case.listOrder, order: .reverse) private var cases: [Case]
    @Query(filter: #Predicate<Case> { $0.isArchived }, sort: \Case.listOrder, order: .reverse) private var archivedCases: [Case]
    @Query(sort: \Tag.sortOrder, order: .forward) private var allTags: [Tag]
    @Query private var settingsQuery: [AppSettings]

    @State private var path = NavigationPath()

    @State private var isSelectionMode = false
    @State private var selection = Set<Case.ID>()

    // 削除アラート
    @State private var caseToDelete: Case?
    @State private var showDeleteAlert = false
    @State private var showBulkDeleteAlert = false

    // 案件名変更
    @State private var caseToRename: Case?
    @State private var renameTitle: String = ""
    @State private var showRenameAlert = false

    // PDF
    @State private var showPDFPreview = false
    @State private var pdfPreviewURL: URL?
    @State private var previewGeneratingCaseID: UUID?

    // 検索
    @State private var searchText: String = ""

    // スコープ
    @State private var selectedScopeID: String = CaseScopeItem.all.id

    // サイドバー
    @State private var isTagDrawerOpen = false

    // タグ管理シート
    @State private var showTagManagerSheet = false

    // 案件へのタグ付けシート
    @State private var caseToTag: Case?
    @State private var showTagPickerSheet = false

    // 一括タグ付けシート
    @State private var showBulkTagSheet = false

    // デフォルトスコープ設定シート
    @State private var showDefaultScopeSheet = false

    // タグリネームシート
    @State private var tagToRename: Tag?
    @State private var tagRenameInput: String = ""
    @State private var showTagRenameAlert = false

    // タグ削除確認
    @State private var tagToDelete: Tag?
    @State private var showTagDeleteAlert = false

    // タグ新規作成
    @State private var newTagNameInput: String = ""
    @State private var newTagColorHex: String = tagColorPalette[0]
    @State private var showNewTagAlert = false

    private let accentGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    private let neonBlue = Color(red: 0.18, green: 0.62, blue: 1.0)

    // MARK: - Computed

    private var appSettings: AppSettings {
        if let s = settingsQuery.first { return s }
        let s = AppSettings()
        modelContext.insert(s)
        try? modelContext.save()
        return s
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var scopeItems: [CaseScopeItem] {
        [.all, .untagged] + allTags.map { CaseScopeItem.tag($0) } + [.archived]
    }

    private var scopeItemsKey: String {
        scopeItems.map(\.id).joined(separator: "|")
    }

    private var selectedScopeItem: CaseScopeItem {
        scopeItems.first(where: { $0.id == selectedScopeID }) ?? CaseScopeItem.all
    }

    private var navigationTitleText: String { selectedScopeItem.title }

    private var isArchivedScope: Bool {
        if case .archived = selectedScopeItem.kind { return true }
        return false
    }

    private var isAllScope: Bool {
        if case .all = selectedScopeItem.kind { return true }
        return false
    }

    private var selectedTag: Tag? {
        if case .tag(let t) = selectedScopeItem.kind { return t }
        return nil
    }

    private var scopedCases: [Case] {
        switch selectedScopeItem.kind {
        case .all:      return cases
        case .untagged: return cases.filter { $0.tags.isEmpty }
        case .archived: return archivedCases
        case .tag(let t):
            let tid = t.id
            return cases.filter { $0.tags.contains(where: { $0.id == tid }) }
        }
    }

    private var filteredScopedCases: [Case] {
        guard !trimmedSearchText.isEmpty else { return scopedCases }
        return scopedCases.filter { $0.title.localizedCaseInsensitiveContains(trimmedSearchText) }
    }

    private var selectedCaseItems: [Case] {
        scopedCases.filter { selection.contains($0.id) }
    }

    private var shouldShowBulkActionBar: Bool {
        path.isEmpty && isSelectionMode && !selectedCaseItems.isEmpty
    }

    private var drawerWidth: CGFloat {
        min(300, UIScreen.main.bounds.width * 0.76)
    }

    private var canReorderCurrentScope: Bool {
        guard isSelectionMode, trimmedSearchText.isEmpty else { return false }
        return isAllScope || isArchivedScope
    }

    // MARK: - Body

    var body: some View {
        navigationContainer
            .environment(\.editMode, .constant(isSelectionMode ? .active : .inactive))
            .safeAreaInset(edge: .bottom) {
                if shouldShowBulkActionBar {
                    bulkActionBar
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                normalizeCaseListOrderIfNeeded()
                ensureSelectedScopeIsValid()
                applyDefaultScope()
            }
            .onChange(of: scopeItemsKey) { _, _ in ensureSelectedScopeIsValid() }
            .onChange(of: selectedScopeID) { _, _ in
                if isSelectionMode { selection.removeAll() }
                withAnimation(.easeInOut(duration: 0.2)) { isTagDrawerOpen = false }
            }
            .onChange(of: path.isEmpty) { _, isEmpty in
                if !isEmpty && isTagDrawerOpen {
                    withAnimation(.easeInOut(duration: 0.2)) { isTagDrawerOpen = false }
                }
            }
            .tint(accentGreen)
            // アラート・シート
            .alert("案件を削除", isPresented: $showDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    if let c = caseToDelete { deleteCase(c) }
                }
            } message: { Text("この案件を削除してもよろしいですか？") }
            .alert("案件を一括削除", isPresented: $showBulkDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) { deleteSelectedCases() }
            } message: { Text("選択した\(selection.count)件の案件を削除してもよろしいですか？\n含まれる写真もすべて削除されます。") }
            .alert("案件名を変更", isPresented: $showRenameAlert) {
                TextField("案件名", text: $renameTitle)
                Button("キャンセル", role: .cancel) {}
                Button("保存") { renameCase() }
            }
            .alert("タグ名を変更", isPresented: $showTagRenameAlert) {
                TextField("タグ名", text: $tagRenameInput)
                Button("キャンセル", role: .cancel) {}
                Button("保存") { saveTagRename() }
            }
            .alert("タグを削除", isPresented: $showTagDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    if let t = tagToDelete { deleteTag(t) }
                }
            } message: {
                Text("タグ「\(tagToDelete?.name ?? "")」を削除します。\n付与された案件からは外されます。")
            }
            .alert("タグを作成", isPresented: $showNewTagAlert) {
                TextField("タグ名", text: $newTagNameInput)
                Button("キャンセル", role: .cancel) {}
                Button("作成") { createNewTag() }
            }
            .sheet(isPresented: $showPDFPreview) {
                if let url = pdfPreviewURL { PDFPreviewView(url: url) }
            }
            .sheet(isPresented: $showTagPickerSheet) {
                if let c = caseToTag {
                    TagPickerSheet(caseItem: c, allTags: allTags, onCreateTag: { createNewTagFrom(name: $0) })
                }
            }
            .sheet(isPresented: $showBulkTagSheet) {
                BulkTagSheet(cases: selectedCaseItems, allTags: allTags, onCreateTag: { createNewTagFrom(name: $0) }, onDone: {
                    showBulkTagSheet = false
                    selection.removeAll()
                    isSelectionMode = false
                })
            }
            .sheet(isPresented: $showTagManagerSheet) {
                TagManagerSheet(
                    allTags: allTags,
                    onRename: { tag in
                        tagToRename = tag
                        tagRenameInput = tag.name
                        showTagRenameAlert = true
                    },
                    onDelete: { tag in
                        tagToDelete = tag
                        showTagDeleteAlert = true
                    },
                    onCreate: {
                        newTagNameInput = ""
                        newTagColorHex = nextTagColor()
                        showNewTagAlert = true
                    }
                )
            }
            .sheet(isPresented: $showDefaultScopeSheet) {
                DefaultScopeSheet(
                    scopeItems: scopeItems,
                    currentDefault: appSettings.defaultScopeRaw,
                    onSelect: { raw in
                        appSettings.defaultScopeRaw = raw
                        try? modelContext.save()
                        showDefaultScopeSheet = false
                    }
                )
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "案件タイトルで検索"
            )
    }

    // MARK: - Navigation Container

    private var navigationContainer: some View {
        NavigationStack(path: $path) {
            sceneStack
                .navigationTitle(navigationTitleText)
                .toolbar { listToolbarContent }
                .navigationDestination(for: Case.self) { CaseDetailView(caseItem: $0) }
        }
    }

    // MARK: - Scene Stack

    private var sceneStack: some View {
        ZStack(alignment: .leading) {
            listContent
                .allowsHitTesting(!(path.isEmpty && isTagDrawerOpen))
                .zIndex(0)

            drawerDimmer

            if path.isEmpty && isTagDrawerOpen {
                tagDrawerPanel
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: selectedScopeID)
        .animation(.easeInOut(duration: 0.2), value: isTagDrawerOpen)
    }

    // MARK: - Drawer Dimmer

    @ViewBuilder
    private var drawerDimmer: some View {
        if path.isEmpty && isTagDrawerOpen {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                        isTagDrawerOpen = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var listToolbarContent: some ToolbarContent {
        // ← サイドバートグル
        ToolbarItem(placement: .topBarLeading) {
            if path.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        isTagDrawerOpen.toggle()
                    }
                } label: {
                    Image(systemName: isTagDrawerOpen ? "sidebar.left" : "sidebar.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(neonBlue)
                }
                .accessibilityLabel(isTagDrawerOpen ? "タグナビを閉じる" : "タグナビを開く")
            }
        }

        // 選択モード切替
        ToolbarItem(placement: .topBarLeading) {
            Button {
                isSelectionMode.toggle()
                if !isSelectionMode { selection.removeAll() }
            } label: {
                Text(isSelectionMode ? "キャンセル" : "選択")
            }
        }

        // 右上メニュー
        ToolbarItem(placement: .navigationBarTrailing) {
            if !isSelectionMode {
                HStack(spacing: 12) {
                    // タグ管理
                    Menu {
                        Button {
                            showTagManagerSheet = true
                        } label: {
                            Label("タグを管理", systemImage: "tag.fill")
                        }
                        Button {
                            showDefaultScopeSheet = true
                        } label: {
                            Label("起動時の表示を設定", systemImage: "house.fill")
                        }
                    } label: {
                        Image(systemName: "tag.circle")
                            .foregroundColor(accentGreen)
                            .font(.title3)
                    }

                    Button(action: addCase) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(accentGreen)
                            .font(.title2)
                    }
                }
            }
        }
    }

    // MARK: - List Content

    @ViewBuilder
    private var listContent: some View {
        if scopedCases.isEmpty && trimmedSearchText.isEmpty {
            emptyStateView
        } else if filteredScopedCases.isEmpty {
            noSearchResultView
        } else {
            caseListView
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: isArchivedScope ? "archivebox" : "tag")
                .font(.system(size: 60))
                .foregroundColor(accentGreen.opacity(0.5))

            if isArchivedScope {
                Text("アーカイブは空です")
                    .font(.headline)
                    .foregroundColor(.secondary)
            } else if case .untagged = selectedScopeItem.kind {
                Text("未分類の案件はありません")
                    .font(.headline)
                    .foregroundColor(.secondary)
            } else {
                Text("案件がありません")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("右上の＋ボタンで追加")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var noSearchResultView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34))
                .foregroundColor(.secondary)
            Text("該当する案件がありません")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }

    private var caseListView: some View {
        List {
            ForEach(filteredScopedCases) { caseItem in
                HStack {
                    if isSelectionMode {
                        Image(systemName: selection.contains(caseItem.id) ? "checkmark.square.fill" : "square")
                            .foregroundColor(selection.contains(caseItem.id) ? neonBlue : .gray)
                            .font(.title2)
                    }

                    CaseRowView(caseItem: caseItem)

                    if !isSelectionMode {
                        HStack(spacing: 10) {
                            Button(action: { generatePDFPreview(for: caseItem) }) {
                                Group {
                                    if previewGeneratingCaseID == caseItem.id {
                                        ProgressView().scaleEffect(0.75)
                                    } else {
                                        Image(systemName: "eye")
                                    }
                                }
                                .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(accentGreen)
                            .disabled(previewGeneratingCaseID != nil || !hasIncludedPDFPhotos(caseItem))

                            Button(action: { startRename(caseItem) }) {
                                Image(systemName: "pencil")
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(accentGreen)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if isSelectionMode {
                        toggleSelection(for: caseItem)
                    } else {
                        path.append(caseItem)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if !isSelectionMode {
                        Button(role: .destructive) {
                            caseToDelete = caseItem; showDeleteAlert = true
                        } label: { Label("削除", systemImage: "trash") }
                        .tint(.red)

                        Button { startRename(caseItem) } label: { Label("名称変更", systemImage: "pencil") }
                        .tint(accentGreen)

                        Button {
                            caseToTag = caseItem
                            showTagPickerSheet = true
                        } label: { Label("タグ", systemImage: "tag") }
                        .tint(.orange)
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if !isSelectionMode {
                        if isArchivedScope {
                            Button { restoreCase(caseItem) } label: { Label("復元", systemImage: "arrow.uturn.backward.circle") }
                            .tint(accentGreen)
                        } else {
                            Button { archiveCase(caseItem) } label: { Label("アーカイブ", systemImage: "archivebox") }
                            .tint(.blue)
                        }
                    }
                }
                .moveDisabled(!canReorderCurrentScope)
            }
            .onMove(perform: moveCases)
        }
        .listStyle(.plain)
    }

    // MARK: - Tag Drawer

    private var tagDrawerPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .foregroundColor(neonBlue)
                Text("タグ")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                // タグ管理ボタン
                Button {
                    withAnimation { isTagDrawerOpen = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showTagManagerSheet = true
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    // 固定スコープ
                    drawerScopeRow(item: .all,      count: cases.count)
                    drawerScopeRow(item: .untagged, count: cases.filter { $0.tags.isEmpty }.count)

                    if !allTags.isEmpty {
                        Divider().background(Color.white.opacity(0.15)).padding(.vertical, 4)

                        Text("タグ")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.65))
                            .padding(.horizontal, 4)

                        ForEach(allTags) { tag in
                            let count = cases.filter { c in c.tags.contains(where: { $0.id == tag.id }) }.count
                            drawerScopeRow(item: .tag(tag), count: count)
                        }
                    }

                    Divider().background(Color.white.opacity(0.15)).padding(.vertical, 4)
                    drawerScopeRow(item: .archived, count: archivedCases.count)

                    // タグ追加
                    Button {
                        newTagNameInput = ""
                        newTagColorHex = nextTagColor()
                        showNewTagAlert = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(accentGreen.opacity(0.9))
                            Text("タグを追加")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(accentGreen.opacity(0.9))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 12)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .frame(width: drawerWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.12),
                    Color(red: 0.09, green: 0.11, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [neonBlue.opacity(0.38), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1),
            alignment: .trailing
        )
        .shadow(color: .black.opacity(0.45), radius: 18, x: 4, y: 0)
    }

    private func drawerScopeRow(item: CaseScopeItem, count: Int) -> some View {
        let isSelected = item.id == selectedScopeID
        let accent = scopeAccentColor(for: item)
        return Button { selectScope(id: item.id) } label: {
            HStack(spacing: 10) {
                // カラードットまたはアイコン
                if case .tag(let t) = item.kind {
                    Circle()
                        .fill(t.color)
                        .frame(width: 12, height: 12)
                        .padding(.leading, 3)
                } else {
                    Image(systemName: scopeSymbol(for: item.kind))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : accent.opacity(0.92))
                        .frame(width: 18)
                }

                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.9))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(isSelected ? .white.opacity(0.95) : .white.opacity(0.62))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected
                          ? LinearGradient(colors: [accent.opacity(0.95), accent.opacity(0.68)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.06)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bulk Action Bar

    private var bulkActionBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                bulkActionButton(title: "タグ設定", systemImage: "tag.fill", tint: neonBlue) {
                    showBulkTagSheet = true
                }
                if isArchivedScope {
                    bulkActionButton(title: "復元", systemImage: "arrow.uturn.backward.circle.fill", tint: accentGreen) {
                        restoreSelectedCases()
                    }
                } else {
                    bulkActionButton(title: "アーカイブ", systemImage: "archivebox.fill", tint: neonBlue) {
                        archiveSelectedCases()
                    }
                }
                bulkActionButton(title: "削除", systemImage: "trash.fill", tint: .red) {
                    showBulkDeleteAlert = true
                }
            }

            HStack(spacing: 8) {
                Text("\(selection.count)件を選択中")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.92))
                Spacer()
                Button("選択解除") { selection.removeAll() }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(neonBlue)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(neonBlue.opacity(0.38), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
    }

    private func bulkActionButton(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage).font(.system(size: 15, weight: .bold))
                Text(title).font(.caption2.weight(.semibold)).lineLimit(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.9)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func scopeSymbol(for kind: CaseScopeKind) -> String {
        switch kind {
        case .all:      return "tray.full"
        case .untagged: return "tag.slash"
        case .archived: return "archivebox"
        case .tag:      return "tag"
        }
    }

    private func scopeAccentColor(for item: CaseScopeItem) -> Color {
        switch item.kind {
        case .all:      return Color(red: 0.17, green: 0.76, blue: 0.56)
        case .untagged: return Color(red: 0.60, green: 0.60, blue: 0.64)
        case .archived: return Color(red: 0.40, green: 0.45, blue: 0.56)
        case .tag(let t): return t.color
        }
    }

    private func nextTagColor() -> String {
        let usedCount = allTags.count
        return tagColorPalette[usedCount % tagColorPalette.count]
    }

    private func toggleSelection(for caseItem: Case) {
        if selection.contains(caseItem.id) { selection.remove(caseItem.id) }
        else { selection.insert(caseItem.id) }
    }

    private func selectScope(id: String) {
        guard id != selectedScopeID else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.26, dampingFraction: 0.9, blendDuration: 0.12)) {
            selectedScopeID = id
            isTagDrawerOpen = false
        }
    }

    private func ensureSelectedScopeIsValid() {
        guard !scopeItems.contains(where: { $0.id == selectedScopeID }) else { return }
        selectedScopeID = CaseScopeItem.all.id
    }

    private func applyDefaultScope() {
        let raw = appSettings.defaultScopeRaw
        // raw が現在のスコープIDに存在するか確認
        if raw == AppSettings.defaultScopeAll {
            selectedScopeID = CaseScopeItem.all.id
        } else if raw == AppSettings.defaultScopeUntagged {
            selectedScopeID = CaseScopeItem.untagged.id
        } else if raw == AppSettings.defaultScopeArchived {
            selectedScopeID = CaseScopeItem.archived.id
        } else if raw.hasPrefix("tag:") {
            let uuidString = String(raw.dropFirst(4))
            if let tag = allTags.first(where: { $0.id.uuidString == uuidString }) {
                selectedScopeID = CaseScopeItem.tag(tag).id
            }
        }
    }

    private func hasIncludedPDFPhotos(_ caseItem: Case) -> Bool {
        caseItem.sortedPhotos.contains { $0.isIncludedInPDF }
    }

    // MARK: - CRUD

    private func addCase() {
        let newCase = Case()
        newCase.listOrder = (cases.first?.listOrder ?? Date().timeIntervalSince1970) + 1
        // 現在タグスコープを見ていれば、そのタグを付与する
        if let t = selectedTag { newCase.tags.append(t) }
        modelContext.insert(newCase)
        try? modelContext.save()
    }

    private func startRename(_ caseItem: Case) {
        caseToRename = caseItem; renameTitle = caseItem.title; showRenameAlert = true
    }

    private func renameCase() {
        guard let c = caseToRename else { return }
        let trimmed = renameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        c.title = trimmed; c.touch()
        try? modelContext.save()
    }

    private func archiveCase(_ caseItem: Case) {
        caseItem.archive()
        caseItem.listOrder = (archivedCases.first?.listOrder ?? Date().timeIntervalSince1970) + 1
        try? modelContext.save()
        selection.remove(caseItem.id)
    }

    private func restoreCase(_ caseItem: Case) {
        caseItem.restoreFromArchive()
        caseItem.listOrder = (cases.first?.listOrder ?? Date().timeIntervalSince1970) + 1
        try? modelContext.save()
        selection.remove(caseItem.id)
    }

    private func deleteCase(_ caseItem: Case) {
        for photo in caseItem.photos { ImageStorage.shared.deleteImage(photo.imageFileName) }
        modelContext.delete(caseItem)
        try? modelContext.save()
    }

    private func deleteSelectedCases() {
        let items = scopedCases.filter { selection.contains($0.id) }
        items.forEach { deleteCase($0) }
        selection.removeAll(); isSelectionMode = false
    }

    private func archiveSelectedCases() {
        var nextOrder = (archivedCases.first?.listOrder ?? Date().timeIntervalSince1970) + 1
        for c in selectedCaseItems { c.archive(); c.listOrder = nextOrder; nextOrder += 1 }
        try? modelContext.save()
        selection.removeAll(); isSelectionMode = false
    }

    private func restoreSelectedCases() {
        var nextOrder = (cases.first?.listOrder ?? Date().timeIntervalSince1970) + 1
        for c in selectedCaseItems { c.restoreFromArchive(); c.listOrder = nextOrder; nextOrder += 1 }
        try? modelContext.save()
        selection.removeAll(); isSelectionMode = false
    }

    private func moveCases(from source: IndexSet, to destination: Int) {
        guard canReorderCurrentScope else { return }
        var reordered = isArchivedScope ? archivedCases : cases
        reordered.move(fromOffsets: source, toOffset: destination)
        let count = reordered.count
        for (i, item) in reordered.enumerated() { item.listOrder = Double(count - i) }
        try? modelContext.save()
    }

    private func normalizeCaseListOrderIfNeeded() {
        let all = cases + archivedCases
        guard all.contains(where: { $0.listOrder <= 0 }) else { return }
        let sorted = all.sorted { $0.updatedAt > $1.updatedAt }
        let count = sorted.count
        for (i, item) in sorted.enumerated() { item.listOrder = Double(count - i) }
        try? modelContext.save()
    }

    // Tag CRUD
    private func createNewTag() {
        let name = newTagNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let tag = Tag(name: name, colorHex: newTagColorHex)
        modelContext.insert(tag)
        try? modelContext.save()
    }

    private func createNewTagFrom(name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        let tag = Tag(name: n, colorHex: nextTagColor())
        modelContext.insert(tag)
        try? modelContext.save()
    }

    private func saveTagRename() {
        guard let tag = tagToRename else { return }
        let name = tagRenameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        tag.name = name
        try? modelContext.save()
    }

    private func deleteTag(_ tag: Tag) {
        // タグを削除すると SwiftData がリレーションを自動解除
        if selectedTag?.id == tag.id { selectedScopeID = CaseScopeItem.all.id }
        modelContext.delete(tag)
        try? modelContext.save()
    }

    private func generatePDFPreview(for caseItem: Case) {
        previewGeneratingCaseID = caseItem.id
        Task {
            let generator = PDFGenerator()
            if let data = await generator.generatePDF(for: caseItem) {
                let fileName = caseItem.title.isEmpty ? "SiteSurvey.pdf" : "\(caseItem.title).pdf"
                let safeFileName = fileName.replacingOccurrences(of: "/", with: "-")
                let uniqueDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try? FileManager.default.createDirectory(at: uniqueDir, withIntermediateDirectories: true)
                let tempURL = uniqueDir.appendingPathComponent(safeFileName)
                try? data.write(to: tempURL)
                await MainActor.run { pdfPreviewURL = tempURL; showPDFPreview = true; previewGeneratingCaseID = nil }
            } else {
                await MainActor.run { previewGeneratingCaseID = nil }
            }
        }
    }
}

// MARK: - CaseRowView

struct CaseRowView: View {
    let caseItem: Case
    private let accentGreen = Color(red: 0.2, green: 0.78, blue: 0.35)

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(accentGreen).frame(width: 40, height: 40)
                Text("\(caseItem.photos.count)")
                    .font(.headline).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(caseItem.title).font(.headline).lineLimit(1)
                HStack(spacing: 6) {
                    Text(formattedDate(caseItem.updatedAt))
                        .font(.caption).foregroundColor(.secondary)
                    // タグバッジ（最大3個）
                    let sortedTags = caseItem.tags.prefix(maxTagsPerCase)
                    ForEach(sortedTags) { tag in
                        Text(tag.name)
                            .font(.caption2)
                            .foregroundColor(tag.color)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(tag.color.opacity(0.15))
                            .clipShape(Capsule())
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.string(from: date)
    }
}

// MARK: - TagPickerSheet（単一案件のタグ付けシート）

struct TagPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var caseItem: Case
    let allTags: [Tag]
    let onCreateTag: (String) -> Void

    @State private var newTagName = ""
    @State private var showNewTagInput = false

    var body: some View {
        NavigationStack {
            List {
                Section("タグを選択（最大\(maxTagsPerCase)個）") {
                    ForEach(allTags) { tag in
                        let isAttached = caseItem.tags.contains(where: { $0.id == tag.id })
                        Button {
                            toggleTag(tag)
                        } label: {
                            HStack(spacing: 12) {
                                Circle().fill(tag.color).frame(width: 12, height: 12)
                                Text(tag.name).foregroundColor(.primary)
                                Spacer()
                                if isAttached {
                                    Image(systemName: "checkmark").foregroundColor(.accentColor).fontWeight(.bold)
                                }
                            }
                        }
                        .disabled(!isAttached && caseItem.tags.count >= maxTagsPerCase)
                    }
                }

                Section {
                    if showNewTagInput {
                        HStack {
                            TextField("新規タグ名", text: $newTagName)
                            Button("作成") {
                                onCreateTag(newTagName)
                                newTagName = ""
                                showNewTagInput = false
                            }
                            .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    } else {
                        Button {
                            showNewTagInput = true
                        } label: {
                            Label("新規タグを作成", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("タグを設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func toggleTag(_ tag: Tag) {
        if let idx = caseItem.tags.firstIndex(where: { $0.id == tag.id }) {
            caseItem.tags.remove(at: idx)
        } else {
            guard caseItem.tags.count < maxTagsPerCase else { return }
            caseItem.tags.append(tag)
        }
    }
}

// MARK: - BulkTagSheet（複数案件への一括タグ付け）

struct BulkTagSheet: View {
    @Environment(\.dismiss) private var dismiss
    let cases: [Case]
    let allTags: [Tag]
    let onCreateTag: (String) -> Void
    let onDone: () -> Void

    @State private var newTagName = ""
    @State private var showNewTagInput = false

    var body: some View {
        NavigationStack {
            List {
                Section("\(cases.count)件の案件にタグを適用") {
                    ForEach(allTags) { tag in
                        let allHave = cases.allSatisfy { c in c.tags.contains(where: { $0.id == tag.id }) }
                        let someHave = cases.contains { c in c.tags.contains(where: { $0.id == tag.id }) }
                        Button { bulkToggle(tag, allHave: allHave) } label: {
                            HStack(spacing: 12) {
                                Circle().fill(tag.color).frame(width: 12, height: 12)
                                Text(tag.name).foregroundColor(.primary)
                                Spacer()
                                if allHave {
                                    Image(systemName: "checkmark").foregroundColor(.accentColor).fontWeight(.bold)
                                } else if someHave {
                                    Image(systemName: "minus").foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                Section {
                    if showNewTagInput {
                        HStack {
                            TextField("新規タグ名", text: $newTagName)
                            Button("作成") { onCreateTag(newTagName); newTagName = ""; showNewTagInput = false }
                            .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    } else {
                        Button { showNewTagInput = true } label: { Label("新規タグを作成", systemImage: "plus.circle") }
                    }
                }
            }
            .navigationTitle("タグを一括設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完了") { onDone() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func bulkToggle(_ tag: Tag, allHave: Bool) {
        if allHave {
            // 全員持っている → 全員から外す
            for c in cases {
                c.tags.removeAll(where: { $0.id == tag.id })
            }
        } else {
            // 持っていない案件に付与（上限範囲内のみ）
            for c in cases where !c.tags.contains(where: { $0.id == tag.id }) {
                if c.tags.count < maxTagsPerCase { c.tags.append(tag) }
            }
        }
    }
}

// MARK: - TagManagerSheet（タグ一覧管理）

struct TagManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let allTags: [Tag]
    let onRename: (Tag) -> Void
    let onDelete: (Tag) -> Void
    let onCreate: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if allTags.isEmpty {
                    Text("タグがありません")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(allTags) { tag in
                        HStack(spacing: 12) {
                            Circle().fill(tag.color).frame(width: 14, height: 14)
                            Text(tag.name)
                            Spacer()
                            Menu {
                                Button { onRename(tag); dismiss() } label: { Label("名前を変更", systemImage: "pencil") }
                                Button(role: .destructive) { onDelete(tag); dismiss() } label: { Label("削除", systemImage: "trash") }
                            } label: {
                                Image(systemName: "ellipsis.circle").foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("タグを管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { onCreate(); dismiss() } label: { Image(systemName: "plus") }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - DefaultScopeSheet（デフォルト表示設定）

struct DefaultScopeSheet: View {
    @Environment(\.dismiss) private var dismiss
    fileprivate let scopeItems: [CaseScopeItem]
    let currentDefault: String
    let onSelect: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(scopeItems) { item in
                    let raw = rawValue(for: item)
                    let isSelected = (raw == currentDefault)
                    Button {
                        onSelect(raw)
                    } label: {
                        HStack(spacing: 12) {
                            if case .tag(let t) = item.kind {
                                Circle().fill(t.color).frame(width: 12, height: 12)
                            } else {
                                Image(systemName: scopeIcon(for: item.kind))
                                    .frame(width: 16)
                                    .foregroundColor(.secondary)
                            }
                            Text(item.title).foregroundColor(.primary)
                            Spacer()
                            if isSelected { Image(systemName: "checkmark").foregroundColor(.accentColor).fontWeight(.bold) }
                        }
                    }
                }
            }
            .navigationTitle("起動時の表示")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func rawValue(for item: CaseScopeItem) -> String {
        switch item.kind {
        case .all:      return AppSettings.defaultScopeAll
        case .untagged: return AppSettings.defaultScopeUntagged
        case .archived: return AppSettings.defaultScopeArchived
        case .tag(let t): return AppSettings.tagScope(t.id)
        }
    }

    private func scopeIcon(for kind: CaseScopeKind) -> String {
        switch kind {
        case .all:      return "tray.full"
        case .untagged: return "tag.slash"
        case .archived: return "archivebox"
        case .tag:      return "tag"
        }
    }
}

#Preview {
    CaseListView()
        .modelContainer(for: [Case.self, Tag.self, AppSettings.self], inMemory: true)
}
