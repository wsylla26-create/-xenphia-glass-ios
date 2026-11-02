import SwiftUI
import UIKit

/// Native SwiftUI surfaces keep controls sharp, interactive and accessible.
struct GlassSurface: ViewModifier {
    let accent: Color
    let radius: CGFloat
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius)
                    .fill(Color(red: 0.005, green: 0.055, blue: 0.065).opacity(0.82))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius)
                            .fill(LinearGradient(colors: [accent.opacity(0.22), .clear, accent.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.6), accent.opacity(0.4), accent.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
            .shadow(color: accent.opacity(0.18), radius: 6, y: 1)
    }
}
extension View {
    func glassSurface(accent: Color, radius: CGFloat) -> some View {
        modifier(GlassSurface(accent: accent, radius: radius))
    }
}

struct GlassRim: View {
    private var image: UIImage? {
        guard let loaded = UIImage(named: "GlassRim", in: .main, compatibleWith: nil), let pixels = loaded.cgImage else { return nil }
        // Four pixels per point keeps corners compact when the centre stretches.
        return UIImage(cgImage: pixels, scale: 4, orientation: .up)
    }
    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable(capInsets: EdgeInsets(top: 40, leading: 44, bottom: 40, trailing: 44), resizingMode: .stretch)
        }
    }
}

enum GlassPalette {
    static let names = ["Green", "Teal", "Pink", "Cyan"]
    static let shades: [Color] = [
        Color(red: 0.54, green: 0.92, blue: 0.48), Color(red: 0.38, green: 0.84, blue: 0.49), Color(red: 0.19, green: 0.92, blue: 0.65),
        Color(red: 0.22, green: 0.91, blue: 0.82), Color(red: 0.15, green: 0.79, blue: 0.75), Color(red: 0.20, green: 0.85, blue: 0.87),
        Color(red: 1.00, green: 0.35, blue: 0.68), Color(red: 0.90, green: 0.25, blue: 0.56), Color(red: 1.00, green: 0.49, blue: 0.69),
        Color(red: 0.31, green: 0.94, blue: 0.98), Color(red: 0.24, green: 0.82, blue: 0.95), Color(red: 0.16, green: 0.73, blue: 0.96)
    ]
    static let hue: [Double] = [-60, -50, -40, -12, -6, 0, 140, 150, 160, 0, 8, 15]
}
