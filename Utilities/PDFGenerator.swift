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
        let photos = caseItem.sortedPhotos
        let showCoverPage = caseItem.showCoverPage
        
        // 写真データを準備（isFullPage/スタンプ集計情報も含む）
        var photoDataList: [(
            fileName: String,
            note: String,
            drawing: Data?,
            textOverlay: UIImage?,
            annotations: MarkupData?,
            isFullPage: Bool,
            isStampSummaryEnabled: Bool,
            stampLegendMeanings: [String: String]
        )] = []
        for photo in photos {
            photoDataList.append((
                fileName: photo.imageFileName,
                note: photo.note,
                drawing: photo.markupData,
                textOverlay: photo.textOverlay,
                annotations: photo.annotations,
                isFullPage: photo.isFullPage,
                isStampSummaryEnabled: photo.isStampSummaryEnabled,
                stampLegendMeanings: photo.stampLegendMeanings
            ))
        }
        
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), nil)
        
        // 表紙（showCoverPageがtrueの場合のみ）
        if showCoverPage {
            drawCoverPage(caseItem: caseItem)
        }
        
        // 写真ページを生成（フルページと通常を順序維持しながら処理）
        var normalPhotos: [(fileName: String, note: String, drawing: Data?, textOverlay: UIImage?, index: Int)] = []
        var photoNumber = 1
        
        for (index, photoData) in photoDataList.enumerated() {
            if photoData.isFullPage {
                // まず溜まっている通常写真を出力
                if !normalPhotos.isEmpty {
                    drawNormalPhotoPages(title: title, photos: normalPhotos)
                    normalPhotos.removeAll()
                }
                // フルページ写真を出力
                drawFullPagePhoto(
                    title: title,
                    photoData: (
                        fileName: photoData.fileName,
                        note: photoData.note,
                        drawing: photoData.drawing,
                        textOverlay: photoData.textOverlay,
                        annotations: photoData.annotations,
                        isStampSummaryEnabled: photoData.isStampSummaryEnabled,
                        stampLegendMeanings: photoData.stampLegendMeanings
                    ),
                    number: photoNumber
                )
            } else {
                normalPhotos.append((photoData.fileName, photoData.note, photoData.drawing, photoData.textOverlay, index))
            }
            photoNumber += 1
        }
        
        // 残りの通常写真を出力
        if !normalPhotos.isEmpty {
            drawNormalPhotoPages(title: title, photos: normalPhotos)
        }
        
        UIGraphicsEndPDFContext()
        
        // 添付PDFがある場合はマージ
        let attachments = caseItem.attachments.sorted { $0.orderIndex < $1.orderIndex }
        if attachments.isEmpty {
            return pdfData as Data
        }
        
        // PDFドキュメントとしてマージ
        guard let mainPDF = PDFDocument(data: pdfData as Data) else {
            return pdfData as Data
        }
        
        for attachment in attachments {
            let attachURL = ImageStorage.shared.getAttachmentURL(attachment.fileName)
            if let attachPDF = PDFDocument(url: attachURL) {
                for pageIndex in 0..<attachPDF.pageCount {
                    if let page = attachPDF.page(at: pageIndex) {
                        mainPDF.insert(page, at: mainPDF.pageCount)
                    }
                }
            }
        }
        
        return mainPDF.dataRepresentation()
    }
    
    // MARK: - 通常写真ページ（4枚/ページ）
    
    private func drawNormalPhotoPages(
        title: String,
        photos: [(fileName: String, note: String, drawing: Data?, textOverlay: UIImage?, index: Int)]
    ) {
        let photosPerPage = 4
        let totalPages = max(1, (photos.count + photosPerPage - 1) / photosPerPage)
        
        for pageIndex in 0..<totalPages {
            let startIndex = pageIndex * photosPerPage
            let endIndex = min(startIndex + photosPerPage, photos.count)
            let pagePhotos = Array(photos[startIndex..<endIndex])
            
            let photoDataForPage = pagePhotos.map { ($0.fileName, $0.note, $0.drawing, $0.textOverlay) }
            let startNumber = pagePhotos.first?.index ?? 0
            
            drawPhotoPage(
                title: title,
                photos: photoDataForPage,
                startNumber: startNumber + 1,
                pageNumber: pageIndex + 1,
                totalPages: totalPages
            )
        }
    }
    
    // MARK: - フルページ写真（1枚/ページ）
    
    private func drawFullPagePhoto(
        title: String,
        photoData: (
            fileName: String,
            note: String,
            drawing: Data?,
            textOverlay: UIImage?,
            annotations: MarkupData?,
            isStampSummaryEnabled: Bool,
            stampLegendMeanings: [String: String]
        ),
        number: Int
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
        
        let trimmedNote = photoData.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasNote = !trimmedNote.isEmpty
        let summaryItems = photoData.isStampSummaryEnabled
            ? StampLegendBuilder.summarize(stamps: photoData.annotations?.stamps ?? [])
            : []
        let hasSummary = !summaryItems.isEmpty
        
        let summaryLayout = summaryGridLayout(for: summaryItems.count)
        let summarySectionHeight: CGFloat = hasSummary
            ? (CGFloat(summaryLayout.rowCount) * summaryLayout.rowHeight + 34)
            : 0
        let noteSectionHeight: CGFloat = hasNote ? 78 : 0
        let sectionSpacing: CGFloat = (hasNote && hasSummary) ? 8 : 0
        let infoAreaHeight = noteSectionHeight + summarySectionHeight + sectionSpacing
        
        // 写真エリア（バッジ用の余白を確保）
        let badgeInset: CGFloat = 20
        let photoAreaY: CGFloat = 50
        let photoAreaHeight = pageHeight - photoAreaY - margin - infoAreaHeight
        let photoRect = CGRect(x: margin + badgeInset, y: photoAreaY + badgeInset, 
                              width: pageWidth - margin * 2 - badgeInset, height: photoAreaHeight - badgeInset)
        
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
            let bgPath = UIBezierPath(roundedRect: photoRect, cornerRadius: 6)
            bgPath.fill()
            
            // アスペクト比維持して中央配置
            let aspect = image.size.width / image.size.height
            let targetAspect = photoRect.width / photoRect.height
            
            var drawRect = photoRect
            if aspect > targetAspect {
                let h = photoRect.width / aspect
                drawRect = CGRect(x: photoRect.minX, y: photoRect.midY - h/2, width: photoRect.width, height: h)
            } else {
                let w = photoRect.height * aspect
                drawRect = CGRect(x: photoRect.midX - w/2, y: photoRect.minY, width: w, height: photoRect.height)
            }
            
            let clipPath = UIBezierPath(roundedRect: photoRect, cornerRadius: 6)
            clipPath.addClip()
            image.draw(in: drawRect)
            
            context.restoreGState()
            
            // 枠線
            context.saveGState()
            UIColor(white: 0.85, alpha: 1).setStroke()
            let borderPath = UIBezierPath(roundedRect: photoRect, cornerRadius: 6)
            borderPath.lineWidth = 1
            borderPath.stroke()
            context.restoreGState()
        }
        
        // 番号バッジ（画像の左上隅に配置）
        context.saveGState()
        let badgeSize: CGFloat = 28
        let badgeRect = CGRect(x: margin + 5, y: photoAreaY + 5, width: badgeSize, height: badgeSize)
        
        // バッジ背景
        accentGreen.setFill()
        let badgePath = UIBezierPath(ovalIn: badgeRect)
        badgePath.fill()
        
        // 番号テキスト
        let numStr = "\(number)"
        let numAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.white
        ]
        let numSize = numStr.size(withAttributes: numAttr)
        (numStr as NSString).draw(at: CGPoint(x: badgeRect.midX - numSize.width/2, y: badgeRect.midY - numSize.height/2), withAttributes: numAttr)
        context.restoreGState()
        
        // メモ + スタンプ凡例
        var sectionY = photoRect.maxY + 10
        if hasNote {
            let noteRect = CGRect(
                x: photoRect.minX,
                y: sectionY,
                width: photoRect.width,
                height: noteSectionHeight
            )
            drawSimpleNoteSection(context: context, rect: noteRect, content: trimmedNote)
            sectionY = noteRect.maxY + (hasSummary ? 8 : 0)
        }
        
        if hasSummary {
            let summaryRect = CGRect(
                x: photoRect.minX,
                y: sectionY,
                width: photoRect.width,
                height: summarySectionHeight
            )
            drawStampSummarySection(
                context: context,
                rect: summaryRect,
                items: summaryItems,
                meanings: photoData.stampLegendMeanings,
                columnCount: summaryLayout.columnCount,
                rowHeight: summaryLayout.rowHeight
            )
        }
    }
    
    private func drawSimpleNoteSection(context: CGContext, rect: CGRect, content: String) {
        context.saveGState()
        let notePath = UIBezierPath(roundedRect: rect, cornerRadius: 6)
        UIColor(white: 0.96, alpha: 1).setFill()
        notePath.fill()
        context.restoreGState()
        
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: accentGreen
        ]
        ("メモ" as NSString).draw(at: CGPoint(x: rect.minX + 10, y: rect.minY + 8), withAttributes: titleAttr)
        
        let para = NSMutableParagraphStyle()
        para.alignment = .left
        para.lineBreakMode = .byWordWrapping
        
        let noteAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: textDark,
            .paragraphStyle: para
        ]
        
        let noteInsetRect = CGRect(
            x: rect.minX + 10,
            y: rect.minY + 24,
            width: rect.width - 20,
            height: rect.height - 30
        )
        (content as NSString).draw(in: noteInsetRect, withAttributes: noteAttr)
    }
    
    private func drawStampSummarySection(
        context: CGContext,
        rect: CGRect,
        items: [StampLegendItem],
        meanings: [String: String],
        columnCount: Int,
        rowHeight: CGFloat
    ) {
        context.saveGState()
        let panelPath = UIBezierPath(roundedRect: rect, cornerRadius: 6)
        UIColor(white: 0.96, alpha: 1).setFill()
        panelPath.fill()
        context.restoreGState()
        
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: accentGreen
        ]
        ("スタンプ集計" as NSString).draw(at: CGPoint(x: rect.minX + 10, y: rect.minY + 8), withAttributes: titleAttr)
        
        guard !items.isEmpty else { return }
        
        let safeColumnCount = max(1, min(3, columnCount))
        let rowsPerColumn = Int(ceil(Double(items.count) / Double(safeColumnCount)))
        let contentX = rect.minX + 10
        let contentY = rect.minY + 24
        let contentWidth = rect.width - 20
        let columnGap: CGFloat = 10
        let totalGap = CGFloat(max(0, safeColumnCount - 1)) * columnGap
        let columnWidth = (contentWidth - totalGap) / CGFloat(safeColumnCount)
        
        let iconWidth: CGFloat = 44
        let countWidth: CGFloat = 32
        
        for (index, item) in items.enumerated() {
            let column = index / rowsPerColumn
            let row = index % rowsPerColumn
            guard column < safeColumnCount else { continue }
            
            let cellX = contentX + CGFloat(column) * (columnWidth + columnGap)
            let cellY = contentY + CGFloat(row) * rowHeight
            let cellRect = CGRect(x: cellX, y: cellY, width: columnWidth, height: rowHeight)
            
            let iconRect = CGRect(
                x: cellRect.minX,
                y: cellRect.minY + 1,
                width: iconWidth,
                height: max(14, rowHeight - 2)
            )
            drawStampLegendIcon(context: context, item: item, rect: iconRect)
            
            let countRect = CGRect(
                x: cellRect.maxX - countWidth,
                y: cellRect.minY + 1,
                width: countWidth,
                height: max(14, rowHeight - 2)
            )
            let countAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: textDark
            ]
            let countText = "\(item.count)個"
            let countSize = countText.size(withAttributes: countAttr)
            let countPoint = CGPoint(
                x: countRect.maxX - countSize.width,
                y: countRect.midY - countSize.height / 2
            )
            (countText as NSString).draw(at: countPoint, withAttributes: countAttr)
            
            let textX = iconRect.maxX + 6
            let textRect = CGRect(
                x: textX,
                y: cellRect.minY + 1,
                width: max(10, countRect.minX - textX - 4),
                height: max(14, rowHeight - 2)
            )
            let meaning = meanings[item.key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let text = meaning.isEmpty ? " " : meaning
            let para = NSMutableParagraphStyle()
            para.alignment = .left
            para.lineBreakMode = .byTruncatingTail
            let textAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: textDark,
                .paragraphStyle: para
            ]
            (text as NSString).draw(in: textRect, withAttributes: textAttr)
        }
    }
    
    private func summaryGridLayout(for itemCount: Int) -> (columnCount: Int, rowCount: Int, rowHeight: CGFloat) {
        guard itemCount > 0 else { return (1, 0, 20) }
        let maxRowsBeforeSplit = 8
        let columnCount = min(3, max(1, Int(ceil(Double(itemCount) / Double(maxRowsBeforeSplit)))))
        let rowCount = Int(ceil(Double(itemCount) / Double(columnCount)))
        let rowHeight: CGFloat = rowCount > 10 ? 18 : 20
        return (columnCount, rowCount, rowHeight)
    }
    
    private func drawStampLegendIcon(context: CGContext, item: StampLegendItem, rect: CGRect) {
        let color = UIColor(hex: item.colorHex) ?? .systemRed
        
        if item.isNumberStamp {
            context.saveGState()
            context.setFillColor(color.withAlphaComponent(item.fillOpacity).cgColor)
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(1.2)
            
            let shape = item.numberShape ?? .circle
            let targetSize: CGSize = (shape == .rectangle)
                ? CGSize(width: 24, height: 14)
                : CGSize(width: 16, height: 16)
            let drawRect = CGRect(
                x: rect.midX - targetSize.width / 2,
                y: rect.midY - targetSize.height / 2,
                width: targetSize.width,
                height: targetSize.height
            )
            switch shape {
            case .circle:
                context.fillEllipse(in: drawRect)
                context.strokeEllipse(in: drawRect)
            case .square, .rectangle:
                let rounded = UIBezierPath(roundedRect: drawRect, cornerRadius: 3)
                context.addPath(rounded.cgPath)
                context.drawPath(using: .fillStroke)
            case .diamond:
                context.beginPath()
                context.move(to: CGPoint(x: drawRect.midX, y: drawRect.minY))
                context.addLine(to: CGPoint(x: drawRect.maxX, y: drawRect.midY))
                context.addLine(to: CGPoint(x: drawRect.midX, y: drawRect.maxY))
                context.addLine(to: CGPoint(x: drawRect.minX, y: drawRect.midY))
                context.closePath()
                context.drawPath(using: .fillStroke)
            case .triangle:
                context.beginPath()
                context.move(to: CGPoint(x: drawRect.midX, y: drawRect.minY))
                context.addLine(to: CGPoint(x: drawRect.maxX, y: drawRect.maxY))
                context.addLine(to: CGPoint(x: drawRect.minX, y: drawRect.maxY))
                context.closePath()
                context.drawPath(using: .fillStroke)
            }
            
            if item.showsNumber {
                let text = "\(item.sampleNumber ?? 1)"
                let textAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 9),
                    .foregroundColor: UIColor.white
                ]
                let textSize = text.size(withAttributes: textAttr)
                let textPoint = CGPoint(
                    x: drawRect.midX - textSize.width / 2,
                    y: drawRect.midY - textSize.height / 2
                )
                (text as NSString).draw(at: textPoint, withAttributes: textAttr)
            }
            context.restoreGState()
            return
        }
        
        let text = item.symbolText
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineBreakMode = .byClipping
        let textAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9),
            .foregroundColor: color,
            .paragraphStyle: para
        ]
        let textRect = rect.insetBy(dx: 0.5, dy: 2)
        (text as NSString).draw(in: textRect, withAttributes: textAttr)
    }
    
    // MARK: - 表紙（シンプル版）
    
    private func drawCoverPage(caseItem: Case) {
        UIGraphicsBeginPDFPage()
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let title = caseItem.title
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
        
        // 情報エリア（写真枚数のみ）
        let infoY: CGFloat = titleY + 60
        let infoFont = UIFont.systemFont(ofSize: 12)
        
        let infoText = "写真: \(photoCount)枚"
        let infoAttr: [NSAttributedString.Key: Any] = [
            .font: infoFont,
            .foregroundColor: textLight
        ]
        (infoText as NSString).draw(at: CGPoint(x: margin, y: infoY), withAttributes: infoAttr)
        
        var currentY = infoY + 30
        let bottomMargin: CGFloat = 80
        
        // 詳細情報の構築（ラベル:値 の形式で配列に保存）
        var detailsItems: [(label: String, value: String)] = []
        
        // 所在地
        if !caseItem.address.isEmpty {
            detailsItems.append(("所在地", caseItem.address))
        }
        
        // エリア
        if !caseItem.area.isEmpty {
            detailsItems.append(("エリア", caseItem.area))
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
            
            detailsItems.append(("作業可能日", weekdayStr))
            detailsItems.append(("作業時間", timeStr))
        }
        
        let showDetails = !detailsItems.isEmpty
        
        // 詳細エリアの高さ（表示時のみ確保）
        let detailHeight: CGFloat = showDetails ? (CGFloat(detailsItems.count) * 20 + 50) : 0
        
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
        
        // 詳細情報エリア描画（表形式）
        if showDetails {
            let detailBoxRect = CGRect(x: margin, y: detailY, width: pageWidth - margin*2, height: detailHeight)
            drawDetailsSectionBox(context: context, rect: detailBoxRect, title: "詳細情報", items: detailsItems, titleColor: accentGreen)
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
    
    /// 詳細情報をラベルと値を揃えて描画する
    private func drawDetailsSectionBox(context: CGContext, rect: CGRect, title: String, items: [(label: String, value: String)], titleColor: UIColor) {
        context.saveGState()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        UIColor(white: 0.97, alpha: 1).setFill()
        path.fill()
        context.restoreGState()
        
        // ラベル
        (title as NSString).draw(at: CGPoint(x: rect.minX + 15, y: rect.minY + 15), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: titleColor])
        
        // 表形式で描画（ラベル幅を固定して値の開始位置を揃える）
        let labelWidth: CGFloat = 80 // ラベルの固定幅
        let labelFont = UIFont.systemFont(ofSize: 11, weight: .medium)
        let valueFont = UIFont.systemFont(ofSize: 11)
        let labelColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        let valueColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        
        var y = rect.minY + 45
        let lineHeight: CGFloat = 20
        
        for item in items {
            // ラベル（左揃え）
            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: labelColor
            ]
            let labelX = rect.minX + 15
            (item.label as NSString).draw(at: CGPoint(x: labelX, y: y), withAttributes: labelAttr)
            
            // 値（ラベルの右側に固定位置から開始）
            let valueAttr: [NSAttributedString.Key: Any] = [
                .font: valueFont,
                .foregroundColor: valueColor
            ]
            let valueX = rect.minX + 15 + labelWidth + 15 // ラベル幅 + 間隔
            (item.value as NSString).draw(at: CGPoint(x: valueX, y: y), withAttributes: valueAttr)
            
            y += lineHeight
        }
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
