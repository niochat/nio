import SwiftUI
import NioKit

struct BadgeView: View {
    let image: Image
    let foregroundColor: Color
    let backgroundColor: Color

    var body: some View {
        let lineWidth: CGFloat = 3.0

        let circle = Circle()
            .stroke(foregroundColor, lineWidth: lineWidth)
            .overlay(
                Circle()
                    .fill(backgroundColor)
            )
            .padding(lineWidth)

        return image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(foregroundColor)
            .padding(4.0)
            .background(circle)
    }
}

struct BadgeView_Previews: PreviewProvider {
    static var previews: some View {
        let image = Image(Asset.Badge.edited.name)
        let foregroundColor = Color(UXColor.lightGray)
        let backgroundColor = Color(UXColor.darkGray)

        return BadgeView(
            image: image,
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor
        )
            .previewLayout(.sizeThatFits)
    }
}
