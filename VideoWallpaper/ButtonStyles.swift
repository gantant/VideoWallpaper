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
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(color.opacity(configuration.isPressed ? 0.35 : 0.22))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(color.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct DarkButtonStyle: ButtonStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(configuration.isPressed ? 0.4 : 0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(color.opacity(0.45), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
