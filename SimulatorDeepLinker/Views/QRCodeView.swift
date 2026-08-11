//
//  QRCodeView.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import AppKit
import SwiftUI

struct QRCodeView: View {
    let image: NSImage?
    let value: String
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 16) {
                Text("Open on a Device").font(.title2.weight(.semibold))
                if let image {
                    Image(nsImage: image)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 280, height: 280)
                }
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .multilineTextAlignment(.center)
            }

            Button(action: onClose) {
                Label("Close", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.cancelAction)
            .help("Close")
        }
        .padding(28)
        .frame(width: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.separator.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
    }
}
