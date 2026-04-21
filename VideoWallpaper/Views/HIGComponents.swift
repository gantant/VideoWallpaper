import SwiftUI

struct LiquidCardBackground: View {
    let cornerRadius: CGFloat
    let tint: Color
    let liquidGlass: Bool

    var body: some View {
        Group {
            if liquidGlass, #available(macOS 26, *) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.clear)
                    .glassEffect(in: .rect(cornerRadius: cornerRadius))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(tint.opacity(0.22), lineWidth: 1)
                    )
            }
        }
    }
}

struct BackNavigationButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.backward")
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .frame(minWidth: 78, minHeight: 28, alignment: .center)
            .padding(.horizontal, 10)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.09))
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel("Back")
        .accessibilityHint("Returns to previous screen")
    }
}
