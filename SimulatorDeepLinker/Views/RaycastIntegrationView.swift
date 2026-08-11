//
//  RaycastIntegrationView.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import SwiftUI

struct RaycastIntegrationView: View {
    @ObservedObject var viewModel: RaycastIntegrationViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "command.square.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Raycast Extension")
                        .font(.title2.weight(.semibold))
                    Text("Search and open saved deep links without leaving Raycast.")
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("Status") {
                        Label(
                            viewModel.isRaycastInstalled ? "Raycast Installed" : "Raycast Not Found",
                            systemImage: viewModel.isRaycastInstalled
                                ? "checkmark.circle.fill"
                                : "exclamationmark.circle.fill"
                        )
                        .foregroundStyle(viewModel.isRaycastInstalled ? .green : .orange)
                    }

                    Divider()

                    Text("Storage and environments are detected automatically. No CLI path or JSON file selection is required.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Install Extension", systemImage: "arrow.down.circle", action: viewModel.installExtension)
                Button("Open in Raycast", systemImage: "command", action: viewModel.openExtension)
                    .disabled(viewModel.isRaycastInstalled == false)
                Spacer()
            }

            Spacer()
        }
        .padding(18)
        .onAppear(perform: viewModel.refresh)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                viewModel.refresh()
            }
        }
    }
}
