//
//  GettingStartedView.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import SwiftUI

struct GettingStartedView: View {
    let openSettingsTab: (SettingsTab) -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Welcome to SimulatorDeepLinker")
                        .font(.title.weight(.semibold))
                    Text("Save a link once, then open it on a simulator, device, or from Raycast.")
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Environment variables are optional", systemImage: "slider.horizontal.3")
                        .font(.headline)
                    Text("BASE_URL is not built in. It is an example variable name that you create yourself for each environment.")
                        .foregroundStyle(.secondary)
                    Text("Development: BASE_URL=https://dev.example.com")
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                    Text("Saved link: {{BASE_URL}}/product/42")
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                    Button("Configure Environments…") {
                        openSettingsTab(.environments)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Raycast integration is optional", systemImage: "command.square")
                        .font(.headline)
                    Text("Install the extension to search and open the same saved links directly from Raycast.")
                        .foregroundStyle(.secondary)
                    Button("Set Up Raycast…") {
                        openSettingsTab(.raycast)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Open Full Guide") {
                    openSettingsTab(.guide)
                }
                Spacer()
                Button("Get Started", action: dismiss)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 620)
    }
}
