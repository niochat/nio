import SwiftUI

struct IndividuallyRoundedRectangle: Shape {
    var topLeft: CGFloat = 0.0
    var topRight: CGFloat = 0.0
    var bottomLeft: CGFloat = 0.0
    var bottomRight: CGFloat = 0.0

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.size.width
        let height = rect.size.height

        let topRight = min(min(self.topRight, height * 0.5), width * 0.5)
        let topLeft = min(min(self.topLeft, height * 0.5), width * 0.5)
        let bottomLeft = min(min(self.bottomLeft, height * 0.5), width * 0.5)
        let bottomRight = min(min(self.bottomRight, height * 0.5), width * 0.5)

        path.move(to: CGPoint(x: width * 0.5, y: 0.0))

        path.addLine(to: CGPoint(x: width - topRight, y: 0.0))
        path.addArc(
            center: CGPoint(x: width - topRight, y: topRight),
            radius: topRight,
            startAngle: Angle(degrees: -90.0),
            endAngle: Angle(degrees: 0.0),
            clockwise: false
        )

        path.addLine(to: CGPoint(x: width, y: height - bottomRight))
        path.addArc(
            center: CGPoint(x: width - bottomRight, y: height - bottomRight),
            radius: bottomRight,
            startAngle: Angle(degrees: 0.0),
            endAngle: Angle(degrees: 90.0),
            clockwise: false
        )

        path.addLine(to: CGPoint(x: bottomLeft, y: height))
        path.addArc(
            center: CGPoint(x: bottomLeft, y: height - bottomLeft),
            radius: bottomLeft,
            startAngle: Angle(degrees: 90.0),
            endAngle: Angle(degrees: 180.0),
            clockwise: false
        )

        path.addLine(to: CGPoint(x: 0.0, y: topLeft))
        path.addArc(
            center: CGPoint(x: topLeft, y: topLeft),
            radius: topLeft,
            startAngle: Angle(degrees: 180.0),
            endAngle: Angle(degrees: 270.0),
            clockwise: false
        )

        return path
    }
}
