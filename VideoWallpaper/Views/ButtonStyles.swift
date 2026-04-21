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
                                    .stroke(color.opacity(0.35), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(color.opacity(configuration.isPressed ? 0.35 : 0.22))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(color.opacity(configuration.isPressed ? 0.95 : 0.5), lineWidth: configuration.isPressed ? 1.6 : 1)
                            )
                    }
                }
            )
            .shadow(color: color.opacity(configuration.isPressed ? 0.8 : 0.2),
                    radius: configuration.isPressed ? 18 : 6)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
                                    .strokeBorder(color.opacity(0.5), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color.opacity(configuration.isPressed ? 0.4 : 0.22))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(color.opacity(configuration.isPressed ? 0.95 : 0.45),
                                                  lineWidth: configuration.isPressed ? 1.5 : 1)
                            )
                    }
                }
            )
            .shadow(color: color.opacity(configuration.isPressed ? 0.85 : 0.22),
                    radius: configuration.isPressed ? 16 : 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                guard pressed, rippleFXEnabled else { return }
                popoverRipple?(color)
            }
    }
}
