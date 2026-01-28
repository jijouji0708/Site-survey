//
//  SiteSurveyApp.swift
//  SiteSurvey
//
//  シンプル現場調査 - メインエントリーポイント
//

import SwiftUI
import SwiftData

@main
struct SiteSurveyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Case.self,
            CasePhoto.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // マイグレーションエラーの場合、データストアを削除して再試行
            print("ModelContainer初期化エラー: \(error)")
            
            // データストアを削除
            let url = URL.applicationSupportDirectory.appending(path: "default.store")
            try? FileManager.default.removeItem(at: url)
            
            // 再試行
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("ModelContainer再初期化失敗: \(error)")
            }
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            CaseListView()
                .tint(Color(red: 0.2, green: 0.78, blue: 0.35))
        }
        .modelContainer(sharedModelContainer)
    }
}
