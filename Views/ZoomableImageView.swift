//
//  ZoomableImageView.swift
//  SiteSurvey
//
//  ピンチズーム・パン・ダブルタップリセット対応の画像ビュー
//

import SwiftUI
import UIKit

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    var onSwipeLeft: (() -> Void)?
    var onSwipeRight: (() -> Void)?
    
    func makeUIView(context: Context) -> ZoomableScrollView {
        let scrollView = ZoomableScrollView(image: image)
        scrollView.onSwipeLeft = onSwipeLeft
        scrollView.onSwipeRight = onSwipeRight
        return scrollView
    }
    
    func updateUIView(_ uiView: ZoomableScrollView, context: Context) {
        uiView.updateImage(image)
        uiView.onSwipeLeft = onSwipeLeft
        uiView.onSwipeRight = onSwipeRight
    }
}

class ZoomableScrollView: UIScrollView, UIScrollViewDelegate {
    private let imageView = UIImageView()
    private var currentImage: UIImage?
    
    var onSwipeLeft: (() -> Void)?
    var onSwipeRight: (() -> Void)?
    
    init(image: UIImage) {
        super.init(frame: .zero)
        self.currentImage = image
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        delegate = self
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        backgroundColor = UIColor.systemGray5
        
        // ズーム設定
        minimumZoomScale = 1.0
        maximumZoomScale = 5.0
        
        // ImageView設定
        imageView.contentMode = .scaleAspectFit
        imageView.image = currentImage
        imageView.isUserInteractionEnabled = true
        addSubview(imageView)
        
        // ダブルタップでズームリセット/ズームイン
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTap)
        
        // スワイプジェスチャー（ズームしていない時のみ有効）
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft))
        swipeLeft.direction = .left
        addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        swipeRight.direction = .right
        addGestureRecognizer(swipeRight)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        centerImage()
    }
    
    func updateImage(_ image: UIImage) {
        guard image != currentImage else { return }
        currentImage = image
        imageView.image = image
        
        // ズームをリセット
        zoomScale = 1.0
        imageView.frame = bounds
        centerImage()
    }
    
    private func centerImage() {
        guard let image = currentImage else { return }
        
        // 画像をフィットさせる
        let imageSize = image.size
        let boundsSize = bounds.size
        
        if boundsSize.width == 0 || boundsSize.height == 0 { return }
        
        let xScale = boundsSize.width / imageSize.width
        let yScale = boundsSize.height / imageSize.height
        let scale = min(xScale, yScale) * zoomScale
        
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        
        imageView.frame.size = CGSize(width: scaledWidth, height: scaledHeight)
        
        // 中央に配置
        let xOffset = max(0, (boundsSize.width - scaledWidth) / 2)
        let yOffset = max(0, (boundsSize.height - scaledHeight) / 2)
        
        contentSize = CGSize(width: max(scaledWidth, boundsSize.width), 
                            height: max(scaledHeight, boundsSize.height))
        
        if zoomScale == 1.0 {
            imageView.frame.origin = CGPoint(x: xOffset, y: yOffset)
        }
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > 1.0 {
            // ズームアウト（リセット）
            setZoomScale(1.0, animated: true)
        } else {
            // ズームイン（タップした位置を中心に2倍）
            let location = gesture.location(in: imageView)
            let zoomRect = zoomRectForScale(scale: 2.5, center: location)
            zoom(to: zoomRect, animated: true)
        }
    }
    
    private func zoomRectForScale(scale: CGFloat, center: CGPoint) -> CGRect {
        let width = bounds.width / scale
        let height = bounds.height / scale
        let x = center.x - (width / 2)
        let y = center.y - (height / 2)
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    @objc private func handleSwipeLeft() {
        guard zoomScale == 1.0 else { return }
        onSwipeLeft?()
    }
    
    @objc private func handleSwipeRight() {
        guard zoomScale == 1.0 else { return }
        onSwipeRight?()
    }
    
    // MARK: - UIScrollViewDelegate
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // ズーム後に中央揃え
        let boundsSize = bounds.size
        var frameToCenter = imageView.frame
        
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }
        
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }
        
        imageView.frame = frameToCenter
    }
}

#Preview {
    ZoomableImageView(image: UIImage(systemName: "photo")!)
}
