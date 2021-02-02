import SwiftUI

extension Image {
    init(fillColour: Color, size: CGSize) {
        var image: UIImage?

        UIGraphicsBeginImageContextWithOptions(size, true, 0.0)
        if let context: CGContext = UIGraphicsGetCurrentContext() {
            UIColor(fillColour).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image = UIGraphicsGetImageFromCurrentImageContext()
        }
        UIGraphicsEndImageContext()

        self.init(uiImage: image ?? UIImage())
    }
}
