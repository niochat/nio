import SwiftUI

extension Image {
    init(fillColour: Color, size: CGSize) {
        let image = UIGraphicsImageRenderer(size: size) .image { context in
            UIColor(fillColour).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        self.init(uiImage: image)
    }
}
