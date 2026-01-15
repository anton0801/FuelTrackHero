import SwiftUI
import WebKit

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct Config {
    static let appsFlyerId = "6757674877"
    static let appsFlyerKey = "Rdmgo7f6hnpbp7tAmKT7CE"
}

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - View Extensions
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Button Styles
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct GlowButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Asphalt Background
struct AsphaltBackground: View {
    var body: some View {
        ZStack {
            Color(hex: "#1E1E1E")
                .ignoresSafeArea()
            
            // Subtle texture
            LinearGradient(
                colors: [
                    Color.white.opacity(0.02),
                    Color.clear,
                    Color.white.opacity(0.01)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Loading View
struct LoadingView: View {
    @State private var isAnimating = false
    let color: Color
    
    init(color: Color = Color(hex: "#FFD84A")) {
        self.color = color
    }
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                AngularGradient(
                    colors: [color, color.opacity(0.3)],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .frame(width: 40, height: 40)
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}


final class PersistenceManager {
    
    private let identifier = "stored_sessions"
    
    func loadSessions() {
        guard let stored = UserDefaults.standard.object(forKey: identifier) as? [String: [String: [HTTPCookiePropertyKey: AnyObject]]] else {
            return
        }
        
        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
        
        let cookies = stored.values
            .flatMap { $0.values }
            .compactMap { properties in
                HTTPCookie(properties: properties as [HTTPCookiePropertyKey: Any])
            }
        
        cookies.forEach { cookie in
            cookieStore.setCookie(cookie)
        }
    }
    
    func saveSessions(from interface: WKWebView) {
        let cookieStore = interface.configuration.websiteDataStore.httpCookieStore
        
        cookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            
            var storage: [String: [String: [HTTPCookiePropertyKey: Any]]] = [:]
            
            for cookie in cookies {
                var domainCookies = storage[cookie.domain] ?? [:]
                
                if let properties = cookie.properties {
                    domainCookies[cookie.name] = properties
                }
                
                storage[cookie.domain] = domainCookies
            }
            
            UserDefaults.standard.set(storage, forKey: self.identifier)
        }
    }
}


// MARK: - Custom TextField
struct NeonTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let color: Color
    
    init(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        color: Color = Color(hex: "#FFD84A")
    ) {
        self.icon = icon
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 24)
            
            TextField(placeholder, text: $text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .keyboardType(keyboardType)
                .accentColor(color)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#2A2A2A"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Paw Print View
struct PawPrintView: View {
    let opacity: Double
    let size: CGFloat
    
    init(opacity: Double = 0.1, size: CGFloat = 30) {
        self.opacity = opacity
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Main pad
            Circle()
                .fill(Color.white.opacity(opacity))
                .frame(width: size * 0.6, height: size * 0.6)
                .offset(y: size * 0.2)
            
            // Toes
            ForEach(0..<4) { index in
                Circle()
                    .fill(Color.white.opacity(opacity))
                    .frame(width: size * 0.25, height: size * 0.35)
                    .offset(
                        x: [size * -0.3, size * -0.1, size * 0.1, size * 0.3][index],
                        y: [size * -0.1, size * -0.25, size * -0.25, size * -0.1][index]
                    )
            }
        }
    }
}

// MARK: - Number Formatter
extension Double {
    func formatted(digits: Int = 2) -> String {
        return String(format: "%.\(digits)f", self)
    }
}

// MARK: - Date Formatting
extension Date {
    func formatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    func timeAgo() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day, .hour, .minute], from: self, to: now)
        
        if let days = components.day, days > 0 {
            return days == 1 ? "Yesterday" : "\(days) days ago"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else {
            return "Just now"
        }
    }
}

final class NotificationHandler {
    
    func process(_ payload: [AnyHashable: Any]) {
        guard let url = extractURL(from: payload) else {
            return
        }
        
        UserDefaults.standard.set(url, forKey: "temp_url")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            NotificationCenter.default.post(
                name: Notification.Name("LoadTempURL"),
                object: nil,
                userInfo: ["temp_url": url]
            )
        }
    }
    
    private func extractURL(from payload: [AnyHashable: Any]) -> String? {
        // Direct extraction
        if let url = payload["url"] as? String {
            return url
        }
        
        // Nested extraction
        if let nested = payload["data"] as? [String: Any],
           let url = nested["url"] as? String {
            return url
        }
        
        return nil
    }
}

// MARK: - Haptic Feedback
struct HapticFeedback {
    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    static func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
