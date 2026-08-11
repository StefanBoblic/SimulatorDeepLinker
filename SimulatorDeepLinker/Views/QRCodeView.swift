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

    var body: some View {
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
        .padding(28)
        .frame(width: 360)
    }
}
