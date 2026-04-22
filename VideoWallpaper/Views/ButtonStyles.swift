//
//  ButtonStyles.swift
//  VideoWallpaper
//
//  Created by Grant Wilson on 4/19/26.
//


// ============================================================
// ButtonStyles.swift
// ============================================================

import SwiftUI

struct GridButtonStyle: ButtonStyle {
    var color: Color
    var liquidGlass: Bool

    @Environment(\.popoverRippleTrigger) private var popoverRipple
    @Environment(\.buttonRippleFXEnabled) private var rippleFXEnabled

    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .background(
                Group {
                    if liquidGlass, #available(macOS 26, *) {
                        RoundedRectangle(cornerRadius: 14).fill(.clear)
                            .glassEffect(in: .rect(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(color.opacity(isHovered || configuration.isPressed ? 0.65 : 0.35), lineWidth: isHovered || configuration.isPressed ? 1.6 : 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(color.opacity(configuration.isPressed ? 0.35 : (isHovered ? 0.28 : 0.22)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(color.opacity(configuration.isPressed ? 0.95 : (isHovered ? 0.75 : 0.5)), lineWidth: configuration.isPressed ? 1.6 : 1)
                            )
                    }
                }
            )
            .shadow(color: color.opacity(configuration.isPressed ? 0.8 : (isHovered ? 0.35 : 0.2)),
                    radius: configuration.isPressed ? 18 : (isHovered ? 10 : 6))
            .scaleEffect(configuration.isPressed ? 0.94 : (isHovered ? 1.02 : 1))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .onChange(of: configuration.isPressed) { _, pressed in
                guard pressed, rippleFXEnabled else { return }
                popoverRipple?(color)
            }
    }
}

struct DarkButtonStyle: ButtonStyle {
    var color: Color
    var liquidGlass: Bool = false

    @Environment(\.popoverRippleTrigger) private var popoverRipple
    @Environment(\.buttonRippleFXEnabled) private var rippleFXEnabled

    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .background(
                Group {
                    if liquidGlass, #available(macOS 26, *) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.clear)
                            .glassEffect(in: .rect(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(color.opacity(isHovered || configuration.isPressed ? 0.75 : 0.5), lineWidth: isHovered || configuration.isPressed ? 1.5 : 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color.opacity(configuration.isPressed ? 0.4 : (isHovered ? 0.32 : 0.22)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(color.opacity(configuration.isPressed ? 0.95 : (isHovered ? 0.7 : 0.45)),
                                                  lineWidth: configuration.isPressed ? 1.5 : 1)
                            )
                    }
                }
            )
            .shadow(color: color.opacity(configuration.isPressed ? 0.85 : (isHovered ? 0.4 : 0.22)),
                    radius: configuration.isPressed ? 16 : (isHovered ? 8 : 5))
            .scaleEffect(configuration.isPressed ? 0.97 : (isHovered ? 1.02 : 1))
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .onChange(of: configuration.isPressed) { _, pressed in
                guard pressed, rippleFXEnabled else { return }
                popoverRipple?(color)
            }
    }
}
