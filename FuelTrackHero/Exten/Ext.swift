import SwiftUI
import Charts

extension Double {
    func format(_ digits: Int = 2) -> String {
        return String(format: "%.\(digits)f", self)
    }
    
    func formatted(to places: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = places
        formatter.minimumFractionDigits = places
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Color {
    static let goldenNeon = Color(hex: "#FFD84A")
    static let orangeGloss = Color(hex: "#FF8A1F")
    static let purpleNeon = Color(hex: "#6B4CFF")
    static let turquoiseLight = Color(hex: "#3ED4C9")
    static let asphaltBlack = Color(hex: "#1E1E1E")
    static let whiteHighlight = Color.white.opacity(0.3)
    static let shadowBlack = Color(hex: "#0D0D0D")
    static let metalGray = Color(hex: "#C7C7C7")
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct LineChart: View {
    var data: [Double]
    var color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let stepX = width / CGFloat(data.count - 1)
                
                path.move(to: CGPoint(x: 0, y: height - (data[0] / data.max()! * height)))
                
                for i in 1..<data.count {
                    let y = height - (data[i] / data.max()! * height)
                    path.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: y))
                }
            }
            .stroke(color, lineWidth: 2)
            .shadow(color: color.opacity(0.5), radius: 5)
        }
    }
}

struct BarChart: View {
    var data: [Double]
    var color: Color
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                ForEach(data.indices, id: \.self) { index in
                    Rectangle()
                        .fill(LinearGradient(gradient: Gradient(colors: [color, color.opacity(0.7)]), startPoint: .top, endPoint: .bottom))
                        .frame(height: (data[index] / data.max()!) * geometry.size.height)
                        .cornerRadius(4)
                        .shadow(color: color.opacity(0.3), radius: 3)
                }
            }
        }
    }
}
