import SwiftUI

extension Image {
    /// Creates an image with a solid fill color of the specified size.
    init(fillColor: Color, size: CGSize) {
        let image = UIGraphicsImageRenderer(size: size) .image { context in
            UIColor(fillColor).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        self.init(uiImage: image)
    }
}
