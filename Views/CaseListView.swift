//
//  CaseListView.swift
//  SiteSurvey
//
//  案件一覧画面
//

import SwiftUI
import SwiftData
import UIKit

private enum CaseScopeKind: Equatable {
    case all
    case archived
    case folder(String)
}

private struct CaseScopeItem: Identifiable, Equatable {
    let kind: CaseScopeKind
    let id: String
    let title: String

    static let all = CaseScopeItem(kind: .all, id: "scope_all", title: "全ファイル")
    static let archived = CaseScopeItem(kind: .archived, id: "scope_archived", title: "アーカイブ")

    static func folder(_ name: String) -> CaseScopeItem {
        CaseScopeItem(kind: .folder(name), id: "scope_folder_\(name)", title: name)
    }
}

struct CaseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Case> { $0.isArchived == false }, sort: \Case.listOrder, order: .reverse) private var cases: [Case]
    @Query(filter: #Predicate<Case> { $0.isArchived }, sort: \Case.listOrder, order: .reverse) private var archivedCases: [Case]

    @State private var path = NavigationPath()

    @State private var isSelectionMode = false
    @State private var selection = Set<Case.ID>()

    @State private var caseToDelete: Case?
    @State private var showDeleteAlert = false
    @State private var showBulkDeleteAlert = false
    @State private var showBulkFolderMoveAlert = false
    @State private var showBulkFolderActionDialog = false
    @State private var showBulkFolderPickerDialog = false
    @State private var bulkFolderNameInput: String = ""
    @State private var caseToRename: Case?
    @State private var renameTitle: String = ""
    @State private var showRenameAlert = false
    @State private var caseToEditFolder: Case?
    @State private var folderNameInput: String = ""
    @State private var showFolderEditAlert = false
    @State private var showSingleFolderPickerDialog = false
    @State private var folderToManageName: String = ""
    @State private var folderRenameInput: String = ""
    @State private var showFolderRenameAlert = false
    @State private var showFolderDeleteAlert = false
    @State private var showPDFPreview = false
    @State private var pdfPreviewURL: URL?
    @State private var previewGeneratingCaseID: UUID?
    @State private var searchText: String = ""
    @State private var selectedScopeID: String = CaseScopeItem.all.id
    @State private var isFolderDrawerOpen = false

    private let accentGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    private let neonBlue = Color(red: 0.18, green: 0.62, blue: 1.0)

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var folderNames: [String] {
        let allNames = (cases + archivedCases)
            .map { $0.folderName.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(allNames)).sorted()
    }

    private var scopeItems: [CaseScopeItem] {
        [CaseScopeItem.all, CaseScopeItem.archived] + folderNames.map { CaseScopeItem.folder($0) }
    }

    private var scopeItemsKey: String {
        scopeItems.map(\.id).joined(separator: "|")
    }

    private var selectedScopeItem: CaseScopeItem {
        scopeItems.first(where: { $0.id == selectedScopeID }) ?? CaseScopeItem.all
    }

    private var navigationTitleText: String {
        selectedScopeItem.title
    }

    private var isArchivedScope: Bool {
        if case .archived = selectedScopeItem.kind { return true }
        return false
    }

    private var isAllScope: Bool {
        if case .all = selectedScopeItem.kind { return true }
        return false
    }

    private var selectedFolderName: String? {
        if case .folder(let name) = selectedScopeItem.kind {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private var scopedCases: [Case] {
        switch selectedScopeItem.kind {
        case .all:
            return cases
        case .archived:
            return archivedCases
        case .folder(let name):
            return cases.filter { $0.folderName.trimmingCharacters(in: .whitespacesAndNewlines) == name }
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
        min(320, UIScreen.main.bounds.width * 0.78)
    }

    private var canReorderCurrentScope: Bool {
        guard isSelectionMode, trimmedSearchText.isEmpty else { return false }
        return isAllScope || isArchivedScope
    }

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
            }
            .onChange(of: scopeItemsKey) { _, _ in
                ensureSelectedScopeIsValid()
            }
            .onChange(of: selectedScopeID) { _, _ in
                if isSelectionMode {
                    selection.removeAll()
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFolderDrawerOpen = false
                }
            }
            .onChange(of: path.isEmpty) { _, isEmpty in
                if !isEmpty && isFolderDrawerOpen {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFolderDrawerOpen = false
                    }
                }
            }
            .tint(accentGreen)
    }

    private var navigationContainer: some View {
        NavigationStack(path: $path) {
            mainScene
        }
    }

    private var mainScene: some View {
        let base = AnyView(sceneStack)
        let withChrome = applyMainSceneChrome(to: base)
        let withAlerts = applyCaseAlerts(to: withChrome)
        let withDialogs = applyFolderDialogs(to: withAlerts)
        return applyScenePresentations(to: withDialogs)
    }

    private func applyMainSceneChrome(to content: AnyView) -> AnyView {
        AnyView(
            content
                .animation(.easeInOut(duration: 0.22), value: selectedScopeID)
                .animation(.easeInOut(duration: 0.2), value: isFolderDrawerOpen)
                .navigationTitle(navigationTitleText)
                .toolbar { listToolbarContent }
        )
    }

    private func applyCaseAlerts(to content: AnyView) -> AnyView {
        let alertDelete = AnyView(
            content
                .alert("案件を削除", isPresented: $showDeleteAlert) {
                    Button("キャンセル", role: .cancel) {}
                    Button("削除", role: .destructive) {
                        if let caseItem = caseToDelete {
                            deleteCase(caseItem)
                        }
                    }
                } message: {
                    Text("この案件を削除してもよろしいですか？")
                }
        )

        let alertBulkDelete = AnyView(
            alertDelete
                .alert("案件を一括削除", isPresented: $showBulkDeleteAlert) {
                    Button("キャンセル", role: .cancel) {}
                    Button("削除", role: .destructive) {
                        deleteSelectedCases()
                    }
                } message: {
                    Text("選択した\(selection.count)件の案件を削除してもよろしいですか？\n含まれる写真もすべて削除されます。")
                }
        )

        let alertBulkMove = AnyView(
            alertBulkDelete
                .alert("フォルダへ一括移動", isPresented: $showBulkFolderMoveAlert) {
                    TextField("フォルダ名（空で未分類）", text: $bulkFolderNameInput)
                    Button("未分類にする") {
                        bulkFolderNameInput = ""
                        moveSelectedCasesToFolder()
                    }
                    Button("キャンセル", role: .cancel) {}
                    Button("移動") {
                        moveSelectedCasesToFolder()
                    }
                } message: {
                    Text("選択した\(selection.count)件を指定フォルダへ移動します。")
                }
        )

        let alertRenameCase = AnyView(
            alertBulkMove
                .alert("案件名を変更", isPresented: $showRenameAlert) {
                    TextField("案件名", text: $renameTitle)
                    Button("キャンセル", role: .cancel) {}
                    Button("保存") {
                        renameCase()
                    }
                }
        )

        let alertEditFolder = AnyView(
            alertRenameCase
                .alert("フォルダ設定", isPresented: $showFolderEditAlert) {
                    TextField("フォルダ名（空で未分類）", text: $folderNameInput)
                    if !folderNames.isEmpty {
                        Button("既存フォルダから選択") {
                            showSingleFolderPickerDialog = true
                        }
                    }
                    Button("未分類にする") {
                        folderNameInput = ""
                        saveFolderName()
                    }
                    Button("キャンセル", role: .cancel) {}
                    Button("保存") {
                        saveFolderName()
                    }
                }
        )

        let alertRenameFolder = AnyView(
            alertEditFolder
                .alert("フォルダ名を変更", isPresented: $showFolderRenameAlert) {
                    TextField("フォルダ名", text: $folderRenameInput)
                    Button("キャンセル", role: .cancel) {}
                    Button("保存") {
                        renameSelectedFolder()
                    }
                } message: {
                    Text("選択中フォルダの案件をすべて移動します。")
                }
        )

        let alertDeleteFolder = AnyView(
            alertRenameFolder
                .alert("フォルダを削除", isPresented: $showFolderDeleteAlert) {
                    Button("キャンセル", role: .cancel) {}
                    Button("削除", role: .destructive) {
                        deleteSelectedFolder()
                    }
                } message: {
                    Text("フォルダ「\(folderToManageName)」を削除し、案件を未分類に移動します。")
                }
        )

        return alertDeleteFolder
    }

    private func applyFolderDialogs(to content: AnyView) -> AnyView {
        let bulkActionDialog = AnyView(
            content
                .confirmationDialog("移動先を選択", isPresented: $showBulkFolderActionDialog, titleVisibility: .visible) {
                    if !folderNames.isEmpty {
                        Button("既存フォルダから選択") {
                            showBulkFolderPickerDialog = true
                        }
                    }
                    Button("新規フォルダを入力") {
                        bulkFolderNameInput = ""
                        showBulkFolderMoveAlert = true
                    }
                    Button("未分類にする") {
                        bulkFolderNameInput = ""
                        moveSelectedCasesToFolder()
                    }
                    Button("キャンセル", role: .cancel) {}
                }
        )

        let bulkPickerDialog = AnyView(
            bulkActionDialog
                .confirmationDialog("既存フォルダを選択", isPresented: $showBulkFolderPickerDialog, titleVisibility: .visible) {
                    ForEach(folderNames, id: \.self) { folder in
                        Button(folder) {
                            bulkFolderNameInput = folder
                            moveSelectedCasesToFolder()
                        }
                    }
                    Button("キャンセル", role: .cancel) {}
                }
        )

        let singlePickerDialog = AnyView(
            bulkPickerDialog
                .confirmationDialog("フォルダを選択", isPresented: $showSingleFolderPickerDialog, titleVisibility: .visible) {
                    ForEach(folderNames, id: \.self) { folder in
                        Button(folder) {
                            folderNameInput = folder
                            saveFolderName()
                        }
                    }
                    Button("キャンセル", role: .cancel) {}
                }
        )

        return singlePickerDialog
    }

    private func applyScenePresentations(to content: AnyView) -> AnyView {
        let withSheet = AnyView(
            content
                .sheet(isPresented: $showPDFPreview) {
                    if let url = pdfPreviewURL {
                        PDFPreviewView(url: url)
                    }
                }
        )

        let withSearch = AnyView(
            withSheet
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "案件タイトルで検索"
                )
        )

        let withDestination = AnyView(
            withSearch
                .navigationDestination(for: Case.self) { caseItem in
                    CaseDetailView(caseItem: caseItem)
                }
        )

        return withDestination
    }

    private var sceneStack: some View {
        ZStack(alignment: .leading) {
            listContent
                .allowsHitTesting(!(path.isEmpty && isFolderDrawerOpen))
                .zIndex(0)

            drawerDimmer

            if path.isEmpty && isFolderDrawerOpen {
                folderDrawerPanel
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(2)
            }
        }
    }

    @ViewBuilder
    private var drawerDimmer: some View {
        if path.isEmpty && isFolderDrawerOpen {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                        isFolderDrawerOpen = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
        }
    }

    @ToolbarContentBuilder
    private var listToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if path.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        isFolderDrawerOpen.toggle()
                    }
                } label: {
                    Image(systemName: isFolderDrawerOpen ? "sidebar.left" : "sidebar.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(neonBlue)
                }
                .accessibilityLabel(isFolderDrawerOpen ? "フォルダナビを閉じる" : "フォルダナビを開く")
            }
        }

        ToolbarItem(placement: .topBarLeading) {
            Button {
                isSelectionMode.toggle()
                if !isSelectionMode {
                    selection.removeAll()
                }
            } label: {
                Text(isSelectionMode ? "キャンセル" : "選択")
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if !isSelectionMode {
                HStack(spacing: 12) {
                    Menu {
                        if let folder = selectedFolderName {
                            Button {
                                folderToManageName = folder
                                folderRenameInput = folder
                                showFolderRenameAlert = true
                            } label: {
                                Label("フォルダ名を変更", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                folderToManageName = folder
                                showFolderDeleteAlert = true
                            } label: {
                                Label("フォルダを削除", systemImage: "trash")
                            }
                        } else {
                            Button("フォルダを選択すると管理できます") {}
                                .disabled(true)
                        }
                    } label: {
                        Image(systemName: "folder.badge.gearshape")
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
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundColor(accentGreen.opacity(0.5))

            if isArchivedScope {
                Text("アーカイブは空です")
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
                            Button(action: {
                                generatePDFPreview(for: caseItem)
                            }) {
                                Group {
                                    if previewGeneratingCaseID == caseItem.id {
                                        ProgressView()
                                            .scaleEffect(0.75)
                                    } else {
                                        Image(systemName: "eye")
                                    }
                                }
                                .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(accentGreen)
                            .disabled(previewGeneratingCaseID != nil || !hasIncludedPDFPhotos(caseItem))

                            Button(action: {
                                startRename(caseItem)
                            }) {
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
                            caseToDelete = caseItem
                            showDeleteAlert = true
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                        .tint(.red)

                        Button {
                            startRename(caseItem)
                        } label: {
                            Label("名称変更", systemImage: "pencil")
                        }
                        .tint(accentGreen)

                        Button {
                            startFolderEdit(caseItem)
                        } label: {
                            Label("フォルダ", systemImage: "folder")
                        }
                        .tint(.orange)
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if !isSelectionMode {
                        if isArchivedScope {
                            Button {
                                restoreCase(caseItem)
                            } label: {
                                Label("復元", systemImage: "arrow.uturn.backward.circle")
                            }
                            .tint(accentGreen)
                        } else {
                            Button {
                                archiveCase(caseItem)
                            } label: {
                                Label("アーカイブ", systemImage: "archivebox")
                            }
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

    private var folderDrawerPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundColor(neonBlue)
                Text("フォルダナビ")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.bottom, 2)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    drawerScopeRow(item: .all, count: cases.count)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("フォルダ")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.65))
                            .padding(.horizontal, 4)

                        if folderNames.isEmpty {
                            Text("フォルダ未作成")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.45))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                        } else {
                            ForEach(folderNames, id: \.self) { name in
                                drawerScopeRow(item: .folder(name), count: cases.filter {
                                    $0.folderName.trimmingCharacters(in: .whitespacesAndNewlines) == name
                                }.count)
                            }
                        }
                    }

                    drawerScopeRow(item: .archived, count: archivedCases.count)
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
        return Button {
            selectScope(id: item.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: scopeSymbol(for: item.kind))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : scopeAccentColor(for: item).opacity(0.92))
                    .frame(width: 18)

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
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [scopeAccentColor(for: item).opacity(0.95), scopeAccentColor(for: item).opacity(0.68)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var bulkActionBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                bulkActionButton(
                    title: "移動",
                    systemImage: "folder.badge.plus",
                    tint: neonBlue
                ) {
                    showBulkFolderActionDialog = true
                }

                if isArchivedScope {
                    bulkActionButton(
                        title: "復元",
                        systemImage: "arrow.uturn.backward.circle.fill",
                        tint: accentGreen
                    ) {
                        restoreSelectedCases()
                    }
                } else {
                    bulkActionButton(
                        title: "アーカイブ",
                        systemImage: "archivebox.fill",
                        tint: neonBlue
                    ) {
                        archiveSelectedCases()
                    }
                }

                bulkActionButton(
                    title: "削除",
                    systemImage: "trash.fill",
                    tint: .red
                ) {
                    showBulkDeleteAlert = true
                }
            }

            HStack(spacing: 8) {
                Text("\(selection.count)件を選択中")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.92))
                Spacer()
                Button("選択解除") {
                    selection.removeAll()
                }
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

    private func bulkActionButton(
        title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.9))
            )
        }
        .buttonStyle(.plain)
    }

    private func scopeSymbol(for kind: CaseScopeKind) -> String {
        switch kind {
        case .all:
            return "tray.full"
        case .archived:
            return "archivebox"
        case .folder:
            return "folder"
        }
    }

    private func scopeAccentColor(for item: CaseScopeItem) -> Color {
        switch item.kind {
        case .all:
            return Color(red: 0.17, green: 0.76, blue: 0.56)
        case .archived:
            return Color(red: 0.40, green: 0.45, blue: 0.56)
        case .folder(let name):
            let palette: [Color] = [
                Color(red: 0.20, green: 0.58, blue: 0.98),
                Color(red: 0.62, green: 0.38, blue: 0.93),
                Color(red: 0.98, green: 0.50, blue: 0.17),
                Color(red: 0.95, green: 0.24, blue: 0.57),
                Color(red: 0.15, green: 0.74, blue: 0.75)
            ]
            let hashValue = abs(name.unicodeScalars.reduce(0) { ($0 * 31) + Int($1.value) })
            return palette[hashValue % palette.count]
        }
    }

    private func toggleSelection(for caseItem: Case) {
        if selection.contains(caseItem.id) {
            selection.remove(caseItem.id)
        } else {
            selection.insert(caseItem.id)
        }
    }

    private func addCase() {
        let newCase = Case()
        newCase.listOrder = (cases.first?.listOrder ?? Date().timeIntervalSince1970) + 1
        modelContext.insert(newCase)
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

    private func moveCases(from source: IndexSet, to destination: Int) {
        guard canReorderCurrentScope else { return }
        var reordered: [Case]
        if isArchivedScope {
            reordered = archivedCases
        } else if isAllScope {
            reordered = cases
        } else {
            return
        }
        reordered.move(fromOffsets: source, toOffset: destination)
        let count = reordered.count
        for (index, item) in reordered.enumerated() {
            item.listOrder = Double(count - index)
        }
        try? modelContext.save()
    }

    private func normalizeCaseListOrderIfNeeded() {
        let allCases = cases + archivedCases
        guard allCases.contains(where: { $0.listOrder <= 0 }) else { return }
        let sortedByUpdatedAt = allCases.sorted { $0.updatedAt > $1.updatedAt }
        let count = sortedByUpdatedAt.count
        for (index, item) in sortedByUpdatedAt.enumerated() {
            item.listOrder = Double(count - index)
        }
        try? modelContext.save()
    }

    private func ensureSelectedScopeIsValid() {
        guard scopeItems.contains(where: { $0.id == selectedScopeID }) else {
            selectedScopeID = CaseScopeItem.all.id
            return
        }
    }

    private func selectScope(id: String) {
        guard id != selectedScopeID else { return }
        guard scopeItems.contains(where: { $0.id == id }) else {
            selectedScopeID = id
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.26, dampingFraction: 0.9, blendDuration: 0.12)) {
            selectedScopeID = id
        }
    }

    private func hasIncludedPDFPhotos(_ caseItem: Case) -> Bool {
        caseItem.sortedPhotos.contains { $0.isIncludedInPDF }
    }

    private func startRename(_ caseItem: Case) {
        caseToRename = caseItem
        renameTitle = caseItem.title
        showRenameAlert = true
    }

    private func renameCase() {
        guard let caseItem = caseToRename else { return }
        let trimmed = renameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        caseItem.title = trimmed
        caseItem.touch()
        try? modelContext.save()
    }

    private func startFolderEdit(_ caseItem: Case) {
        caseToEditFolder = caseItem
        folderNameInput = caseItem.folderName
        showFolderEditAlert = true
    }

    private func saveFolderName() {
        guard let caseItem = caseToEditFolder else { return }
        caseItem.folderName = folderNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        caseItem.touch()
        try? modelContext.save()
    }

    private func renameSelectedFolder() {
        let oldName = folderToManageName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newName = folderRenameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !oldName.isEmpty, !newName.isEmpty else { return }
        guard oldName != newName else { return }

        let targetCases = (cases + archivedCases).filter {
            $0.folderName.trimmingCharacters(in: .whitespacesAndNewlines) == oldName
        }
        for item in targetCases {
            item.folderName = newName
            item.touch()
        }
        try? modelContext.save()
        selectScope(id: CaseScopeItem.folder(newName).id)
    }

    private func deleteSelectedFolder() {
        let targetName = folderToManageName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetName.isEmpty else { return }

        let targetCases = (cases + archivedCases).filter {
            $0.folderName.trimmingCharacters(in: .whitespacesAndNewlines) == targetName
        }
        for item in targetCases {
            item.folderName = ""
            item.touch()
        }
        try? modelContext.save()

        if selectedFolderName == targetName {
            selectScope(id: CaseScopeItem.all.id)
        }
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

                await MainActor.run {
                    pdfPreviewURL = tempURL
                    showPDFPreview = true
                    previewGeneratingCaseID = nil
                }
            } else {
                await MainActor.run {
                    previewGeneratingCaseID = nil
                }
            }
        }
    }

    private func deleteCase(_ caseItem: Case) {
        for photo in caseItem.photos {
            ImageStorage.shared.deleteImage(photo.imageFileName)
        }

        modelContext.delete(caseItem)
        try? modelContext.save()
    }

    private func deleteSelectedCases() {
        let itemsToDelete = scopedCases.filter { selection.contains($0.id) }
        for caseItem in itemsToDelete {
            deleteCase(caseItem)
        }
        selection.removeAll()
        isSelectionMode = false
    }

    private func moveSelectedCasesToFolder() {
        let destinationFolder = bulkFolderNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let itemsToMove = scopedCases.filter { selection.contains($0.id) }
        guard !itemsToMove.isEmpty else { return }

        for caseItem in itemsToMove {
            caseItem.folderName = destinationFolder
            caseItem.touch()
        }

        try? modelContext.save()
        selection.removeAll()
        isSelectionMode = false
    }

    private func archiveSelectedCases() {
        let items = selectedCaseItems
        guard !items.isEmpty else { return }
        var nextOrder = (archivedCases.first?.listOrder ?? Date().timeIntervalSince1970) + 1
        for caseItem in items {
            caseItem.archive()
            caseItem.listOrder = nextOrder
            nextOrder += 1
        }
        try? modelContext.save()
        selection.removeAll()
        isSelectionMode = false
    }

    private func restoreSelectedCases() {
        let items = selectedCaseItems
        guard !items.isEmpty else { return }
        var nextOrder = (cases.first?.listOrder ?? Date().timeIntervalSince1970) + 1
        for caseItem in items {
            caseItem.restoreFromArchive()
            caseItem.listOrder = nextOrder
            nextOrder += 1
        }
        try? modelContext.save()
        selection.removeAll()
        isSelectionMode = false
    }
}

struct CaseRowView: View {
    let caseItem: Case

    private let accentGreen = Color(red: 0.2, green: 0.78, blue: 0.35)

    private var trimmedFolderName: String {
        caseItem.folderName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentGreen)
                    .frame(width: 40, height: 40)

                Text("\(caseItem.photos.count)")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(caseItem.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(formattedDate(caseItem.updatedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !trimmedFolderName.isEmpty {
                        Text(trimmedFolderName)
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    CaseListView()
        .modelContainer(for: Case.self, inMemory: true)
}
