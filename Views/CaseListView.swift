//
//  CaseListView.swift
//  SiteSurvey
//
//  案件一覧画面
//

import SwiftUI
import SwiftData

struct CaseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Case.updatedAt, order: .reverse) private var cases: [Case]
    
    // ナビゲーションパス（プログラム制御用）
    @State private var path = NavigationPath()
    
    // 独自の選択モード管理
    @State private var isSelectionMode = false
    @State private var selection = Set<Case.ID>()
    
    @State private var caseToDelete: Case?
    @State private var showDeleteAlert = false
    @State private var showBulkDeleteAlert = false
    
    // 仕様: アクセントカラー（緑）Color(red: 0.2, green: 0.78, blue: 0.35)
    private let accentGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    
    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if cases.isEmpty {
                    // 仕様: 空状態表示 フォルダアイコン（緑・薄め）+ 「案件がありません」+ 「右上の＋ボタンで追加」
                    emptyStateView
                } else {
                    caseListView
                }
            }
            // 仕様: ナビゲーションタイトル「案件一覧」
            .navigationTitle("案件一覧")
            .toolbar {
                // 仕様: ツールバー 左上に「選択」/「キャンセル」ボタン
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isSelectionMode.toggle()
                        if !isSelectionMode {
                            selection.removeAll()
                        }
                    } label: {
                        Text(isSelectionMode ? "キャンセル" : "選択")
                    }
                }
                
                // 仕様: ツールバー 右上に plus.circle.fill アイコン（緑）
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isSelectionMode {
                        Button(action: addCase) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(accentGreen)
                                .font(.title2)
                        }
                    }
                }
                
                // 仕様: 一括削除ボタン（下部バー）
                ToolbarItem(placement: .bottomBar) {
                    if isSelectionMode {
                        HStack {
                            Spacer()
                            Button(role: .destructive) {
                                showBulkDeleteAlert = true
                            } label: {
                                Text(selection.isEmpty ? "削除" : "削除 (\(selection.count))")
                                    .foregroundColor(.red)
                            }
                            .disabled(selection.isEmpty)
                        }
                    }
                }
            }
            // 仕様: 削除確認 アラート（個別）
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
            // 仕様: 一括削除確認 アラート
            .alert("案件を一括削除", isPresented: $showBulkDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    deleteSelectedCases()
                }
            } message: {
                Text("選択した\(selection.count)件の案件を削除してもよろしいですか？\n含まれる写真もすべて削除されます。")
            }
            .navigationDestination(for: Case.self) { caseItem in
                 CaseDetailView(caseItem: caseItem)
            }
        }
        // 仕様: tint設定 .tint(accentGreen) でナビゲーション全体を緑に
        .tint(accentGreen)
    }
    
    // MARK: - 空状態表示
    // 仕様: フォルダアイコン（緑・薄め）+ 「案件がありません」+ 「右上の＋ボタンで追加」
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
            .font(.system(size: 60))
            .foregroundColor(accentGreen.opacity(0.5))
            
            Text("案件がありません")
            .font(.headline)
            .foregroundColor(.secondary)
            
            Text("右上の＋ボタンで追加")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 案件リスト
    // 仕様: リスト項目 写真枚数バッジ（緑円形、40x40）+ タイトル + 更新日時
    //       スワイプアクション 削除（destructive）
    
    private var caseListView: some View {
        List {
            ForEach(cases) { caseItem in
                HStack {
                    // 選択モード時のチェックボックス
                    if isSelectionMode {
                        Image(systemName: selection.contains(caseItem.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selection.contains(caseItem.id) ? accentGreen : .gray)
                            .font(.title2)
                    }
                    
                    CaseRowView(caseItem: caseItem)
                }
                .contentShape(Rectangle()) // タップ領域を広げる
                .onTapGesture {
                    if isSelectionMode {
                        toggleSelection(for: caseItem)
                    } else {
                        // 選択モードでない場合は詳細へ遷移（プログラム制御）
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
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - アクション
    
    private func toggleSelection(for caseItem: Case) {
        if selection.contains(caseItem.id) {
            selection.remove(caseItem.id)
        } else {
            selection.insert(caseItem.id)
        }
    }
    
    private func addCase() {
        let newCase = Case()
        modelContext.insert(newCase)
        try? modelContext.save()
    }
    
    private func deleteCase(_ caseItem: Case) {
        // 写真ファイルを削除
        for photo in caseItem.photos {
            ImageStorage.shared.deleteImage(photo.imageFileName)
        }
        
        modelContext.delete(caseItem)
        try? modelContext.save()
    }
    
    private func deleteSelectedCases() {
        // IDベースでフィルタリングして削除
        let itemsToDelete = cases.filter { selection.contains($0.id) }
        
        for caseItem in itemsToDelete {
            deleteCase(caseItem)
        }
        selection.removeAll()
        isSelectionMode = false
    }
}

// MARK: - 案件行ビュー
// 仕様: 写真枚数バッジ（緑円形、40x40）+ タイトル + 更新日時

struct CaseRowView: View {
    let caseItem: Case
    
    private let accentGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    
    var body: some View {
        HStack(spacing: 12) {
            // 仕様: 写真枚数バッジ（緑円形、40x40）
            ZStack {
                Circle()
                    .fill(accentGreen)
                    .frame(width: 40, height: 40)
                
                Text("\(caseItem.photos.count)")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // タイトル
                Text(caseItem.title)
                    .font(.headline)
                    .lineLimit(1)
                
                // 更新日時
                Text(formattedDate(caseItem.updatedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
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
