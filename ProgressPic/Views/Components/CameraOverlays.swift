import SwiftUI

/// Grid overlay for camera view (rule of thirds)
struct GridOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                // Vertical lines
                for i in 1..<3 {
                    let x = w * CGFloat(i) / 3
                    p.move(to: .init(x: x, y: 0))
                    p.addLine(to: .init(x: x, y: h))
                }
                // Horizontal lines
                for i in 1..<3 {
                    let y = h * CGFloat(i) / 3
                    p.move(to: .init(x: 0, y: y))
                    p.addLine(to: .init(x: w, y: y))
                }
            }
            .stroke(Color.white.opacity(0.3), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

/// Subtle crosshair guidelines for face positioning
struct GuidelinesOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                p.move(to: .init(x: w/2, y: h*0.25)); p.addLine(to: .init(x: w/2, y: h*0.75))
                p.move(to: .init(x: w*0.2, y: h*0.5)); p.addLine(to: .init(x: w*0.8, y: h*0.5))
            }
            .stroke(Color.white.opacity(0.7), lineWidth: 2)

            Path { p in // grid
                for i in 1..<3 {
                    let x = w * CGFloat(i) / 3
                    let y = h * CGFloat(i) / 3
                    p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: h))
                    p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: w, y: y))
                }
            }
            .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
