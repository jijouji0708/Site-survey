//
//  PDFGenerator.swift
//  SiteSurvey
//
//  PDF生成（シンプル・実用的なデザイン）
//

import UIKit
import PDFKit
import PencilKit

@MainActor
class PDFGenerator {
    
    // 用紙設定 A4
    private let pageWidth: CGFloat = 595
    private let pageHeight: CGFloat = 842
    private let margin: CGFloat = 40
    
    // カラー設定
    private let accentGreen = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1)
    private let textDark = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
    private let textLight = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
    
    func generatePDF(for caseItem: Case) async -> Data? {
        let title = caseItem.title
        let createdAt = caseItem.createdAt
        let updatedAt = caseItem.updatedAt
        let overallNote = caseItem.overallNote
        let photos = caseItem.sortedPhotos
        let photoCount = photos.count
        
        var photoDataList: [(fileName: String, note: String, drawing: Data?, textOverlay: UIImage?)] = []
        for photo in photos {
            photoDataList.append((
                fileName: photo.imageFileName,
                note: photo.note,
                drawing: photo.markupData,
                textOverlay: photo.textOverlay
            ))
        }
        
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), nil)
        
        // 表紙
        drawCoverPage(caseItem: caseItem)
        
        // 写真ページ (4枚/ページ)
        let photosPerPage = 4
        let totalPhotoPages = max(1, (photoDataList.count + photosPerPage - 1) / photosPerPage)
        
        for pageIndex in 0..<totalPhotoPages {
            let startIndex = pageIndex * photosPerPage
            let endIndex = min(startIndex + photosPerPage, photoDataList.count)
            let pagePhotos = Array(photoDataList[startIndex..<endIndex])
            
            drawPhotoPage(
                title: title,
                photos: pagePhotos,
                startNumber: startIndex + 1,
                pageNumber: pageIndex + 1,
                totalPages: totalPhotoPages
            )
        }
        
        UIGraphicsEndPDFContext()
        return pdfData as Data
    }
    
    // MARK: - 表紙（シンプル版）
    
    private func drawCoverPage(caseItem: Case) {
        UIGraphicsBeginPDFPage()
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let title = caseItem.title
        let createdAt = caseItem.createdAt
        let updatedAt = caseItem.updatedAt
        let overallNote = caseItem.overallNote
        let photoCount = caseItem.sortedPhotos.count
        
        // ヘッダーバー（シンプルなライン）
        context.saveGState()
        let headerLineRect = CGRect(x: margin, y: 50, width: pageWidth - margin*2, height: 3)
        accentGreen.setFill()
        context.fill(headerLineRect)
        context.restoreGState()
        
        // メインタイトル
        let mainTitleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .heavy),
            .foregroundColor: textDark
        ]
        let titleY: CGFloat = 80
        (title as NSString).draw(in: CGRect(x: margin, y: titleY, width: pageWidth - margin*2, height: 80), withAttributes: mainTitleAttr)
        
        // 情報エリア（横並びコンパクト）
        let infoY: CGFloat = titleY + 60
        let infoFont = UIFont.systemFont(ofSize: 11)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
        
        // 作成・更新・枚数を横並びに
        let infoText = "作成: \(dateFormatter.string(from: createdAt))　　更新: \(dateFormatter.string(from: updatedAt))　　写真: \(photoCount)枚"
        let infoAttr: [NSAttributedString.Key: Any] = [
            .font: infoFont,
            .foregroundColor: textLight
        ]
        (infoText as NSString).draw(at: CGPoint(x: margin, y: infoY), withAttributes: infoAttr)
        
        var currentY = infoY + 30
        let bottomMargin: CGFloat = 80
        
        // 詳細情報の構築
        var detailsComponents: [String] = []
        
        // 所在地
        if !caseItem.address.isEmpty {
            detailsComponents.append("所在地: \(caseItem.address)")
        }
        
        // 作業日時 (入力がある＝空でないor未定でない 場合のみ表示)
        // 曜日
        let weekdaysOrder = [2, 3, 4, 5, 6, 7, 1]
        let weekdayLabels = ["月", "火", "水", "木", "金", "土", "日"]
        var selectedLabels: [String] = []
        for (i, day) in weekdaysOrder.enumerated() {
            if caseItem.workWeekdays.contains(day) {
                selectedLabels.append(weekdayLabels[i])
            }
        }
        
        // 時間
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        let hasTime = caseItem.workStartTime != nil || caseItem.workEndTime != nil
        let hasWeekdays = !caseItem.workWeekdays.isEmpty
        
        if hasWeekdays || hasTime {
            // どちらか入力があればこのブロックを表示
            let weekdayStr = selectedLabels.isEmpty ? "未定" : selectedLabels.joined(separator: ", ")
            
            let startStr = caseItem.workStartTime.map { timeFormatter.string(from: $0) } ?? "未定"
            let endStr = caseItem.workEndTime.map { timeFormatter.string(from: $0) } ?? "未定"
            let timeStr = "\(startStr) 〜 \(endStr)"
            
            detailsComponents.append("作業可能日: \(weekdayStr)")
            detailsComponents.append("作業時間: \(timeStr)")
        }
        
        let detailContent = detailsComponents.joined(separator: "\n")
        let showDetails = !detailsComponents.isEmpty
        
        // 詳細エリアの高さ（表示時のみ確保）
        // 内容に応じて高さを微調整してもよいが、一旦固定または行数ベースで確保
        let detailHeight: CGFloat = showDetails ? (CGFloat(detailsComponents.count) * 20 + 50) : 0
        
        // 全体メモエリアの計算
        // 詳細がある場合はその分上に底上げ
        let detailY = pageHeight - bottomMargin - detailHeight
        
        // メモの下端目安: 詳細エリアの上 - 20 (詳細がない場合は margin - 0 - 20 なので bottomMarginのみ)
        // Adjust spacing: if details hidden, margin is from bottom
        let noteBottomY = showDetails ? (detailY - 20) : (pageHeight - bottomMargin)
        let noteHeight = noteBottomY - currentY
        
        if !overallNote.isEmpty {
            currentY += 20
            // noteHeightが小さすぎないかチェック
            if noteHeight > 40 {
                let noteBoxRect = CGRect(x: margin, y: currentY, width: pageWidth - margin*2, height: noteHeight)
                drawSectionBox(context: context, rect: noteBoxRect, title: "メモ", content: overallNote, titleColor: accentGreen)
            }
        }
        
        // 詳細情報エリア描画
        if showDetails {
            // detailYは計算済み
            let detailBoxRect = CGRect(x: margin, y: detailY, width: pageWidth - margin*2, height: detailHeight)
            drawSectionBox(context: context, rect: detailBoxRect, title: "詳細情報", content: detailContent, titleColor: accentGreen)
        }
        
        // フッターライン
        context.saveGState()
        let footerLineRect = CGRect(x: margin, y: pageHeight - 50, width: pageWidth - margin*2, height: 1)
        accentGreen.withAlphaComponent(0.3).setFill()
        context.fill(footerLineRect)
        context.restoreGState()
    }
    
    private func drawSectionBox(context: CGContext, rect: CGRect, title: String, content: String, titleColor: UIColor) {
        context.saveGState()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        UIColor(white: 0.97, alpha: 1).setFill()
        path.fill()
        context.restoreGState()
        
        // ラベル
        (title as NSString).draw(at: CGPoint(x: rect.minX + 15, y: rect.minY + 15), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: titleColor])
        
        // 内容
        let contentRect = CGRect(x: rect.minX + 15, y: rect.minY + 45, width: rect.width - 30, height: rect.height - 60)
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 4
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1),
            .paragraphStyle: para
        ]
        (content as NSString).draw(in: contentRect, withAttributes: attr)
    }
    
    // MARK: - 写真ページ
    
    private func drawPhotoPage(
        title: String,
        photos: [(fileName: String, note: String, drawing: Data?, textOverlay: UIImage?)],
        startNumber: Int,
        pageNumber: Int,
        totalPages: Int
    ) {
        UIGraphicsBeginPDFPage()
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // ヘッダー
        let headerY: CGFloat = 25
        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: textLight
        ]
        (title as NSString).draw(at: CGPoint(x: margin, y: headerY), withAttributes: headerAttr)
        
        let pageStr = "\(pageNumber) / \(totalPages)"
        let pageAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: textLight
        ]
        let pageSize = pageStr.size(withAttributes: pageAttr)
        (pageStr as NSString).draw(at: CGPoint(x: pageWidth - margin - pageSize.width, y: headerY), withAttributes: pageAttr)
        
        // グリッド計算 (2x2)
        let gridSpacing: CGFloat = 15
        let gridAreaY: CGFloat = 50
        let gridAreaH = pageHeight - gridAreaY - 40
        
        let cellW = (pageWidth - margin*2 - gridSpacing) / 2
        let cellH = (gridAreaH - gridSpacing) / 2
        
        for (index, photoData) in photos.enumerated() {
            let col = index % 2
            let row = index / 2
            
            let x = margin + CGFloat(col) * (cellW + gridSpacing)
            let y = gridAreaY + CGFloat(row) * (cellH + gridSpacing)
            let rect = CGRect(x: x, y: y, width: cellW, height: cellH)
            
            drawPhotoCell(context: context, photoData: photoData, number: startNumber + index, rect: rect)
        }
    }
    
    private func drawPhotoCell(
        context: CGContext,
        photoData: (fileName: String, note: String, drawing: Data?, textOverlay: UIImage?),
        number: Int,
        rect: CGRect
    ) {
        // 写真エリア計算 - 常に一定の比率で固定（メモの有無に関わらず）
        let badgeInset: CGFloat = 15  // バッジ用の余白
        let noteAreaHeight: CGFloat = rect.height * 0.25  // メモエリアは常に25%確保
        let imageH = rect.height - noteAreaHeight
        let imageRect = CGRect(x: rect.origin.x + badgeInset, y: rect.origin.y + badgeInset, 
                              width: rect.width - badgeInset, height: imageH - badgeInset)
        
        // 画像描画
        var drawing: PKDrawing? = nil
        if let drawingData = photoData.drawing {
            drawing = try? PKDrawing(data: drawingData)
        }
        
        if let image = ImageStorage.shared.getImageForPDF(
            photoData.fileName,
            drawing: drawing,
            textOverlay: photoData.textOverlay
        ) {
            context.saveGState()
            
            // 白背景
            UIColor.white.setFill()
            let bgPath = UIBezierPath(roundedRect: imageRect, cornerRadius: 4)
            bgPath.fill()
            
            // アスペクト比維持して中央配置 (Fit)
            let aspect = image.size.width / image.size.height
            let targetAspect = imageRect.width / imageRect.height
            
            var drawRect = imageRect
            if aspect > targetAspect {
                // 横長
                let h = imageRect.width / aspect
                drawRect = CGRect(x: imageRect.minX, y: imageRect.midY - h/2, width: imageRect.width, height: h)
            } else {
                // 縦長
                let w = imageRect.height * aspect
                drawRect = CGRect(x: imageRect.midX - w/2, y: imageRect.minY, width: w, height: imageRect.height)
            }
            
            // クリップして画像を描画
            let clipPath = UIBezierPath(roundedRect: imageRect, cornerRadius: 4)
            clipPath.addClip()
            image.draw(in: drawRect)
            
            context.restoreGState()
            
            // 枠線（クリップ解除後）
            context.saveGState()
            UIColor(white: 0.85, alpha: 1).setStroke()
            let borderPath = UIBezierPath(roundedRect: imageRect, cornerRadius: 4)
            borderPath.lineWidth = 1
            borderPath.stroke()
            context.restoreGState()
        }
        
        // 番号バッジ（画像の左上隅に配置、見切れないように）
        context.saveGState()
        let badgeSize: CGFloat = 22
        let badgeRect = CGRect(x: rect.origin.x + 5, y: rect.origin.y + 5, width: badgeSize, height: badgeSize)
        
        // バッジ背景
        accentGreen.setFill()
        let badgePath = UIBezierPath(ovalIn: badgeRect)
        badgePath.fill()
        
        // 番号テキスト
        let numStr = "\(number)"
        let numAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor.white
        ]
        let numSize = numStr.size(withAttributes: numAttr)
        (numStr as NSString).draw(at: CGPoint(x: badgeRect.midX - numSize.width/2, y: badgeRect.midY - numSize.height/2), withAttributes: numAttr)
        context.restoreGState()
        
        // メモエリア（常に表示、メモがなくても背景を描く）
        let noteY = rect.origin.y + imageH + 5
        let noteH = noteAreaHeight - 10
        // 写真と同じ幅に調整
        let noteRect = CGRect(x: rect.minX + badgeInset, y: noteY, width: rect.width - badgeInset, height: noteH)
        
        context.saveGState()
        let notePath = UIBezierPath(roundedRect: noteRect, cornerRadius: 4)
        UIColor(white: 0.96, alpha: 1).setFill()
        notePath.fill()
        context.restoreGState()
        
        // テキスト（メモがある場合のみ）
        if !photoData.note.isEmpty {
            let para = NSMutableParagraphStyle()
            para.alignment = .left
            para.lineBreakMode = .byWordWrapping
            
            let noteAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: textDark,
                .paragraphStyle: para
            ]
            
            let noteInsetRect = noteRect.insetBy(dx: 6, dy: 4)
            (photoData.note as NSString).draw(in: noteInsetRect, withAttributes: noteAttr)
        }
    }
}
