//
//  LaunchHistoryView.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import SwiftUI

struct LaunchHistoryView: View {
    @ObservedObject var viewModel: LaunchHistoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Launch History").font(.largeTitle.weight(.semibold))
                    Text("The latest 200 launch attempts are stored locally.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Clear History", role: .destructive, action: viewModel.clear)
                    .disabled(viewModel.entries.isEmpty)
            }

            if viewModel.entries.isEmpty {
                ContentUnavailableView(
                    "No Launches Yet",
                    systemImage: "clock",
                    description: Text("Opened links and errors will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.entries) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: entry.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(entry.succeeded ? .green : .red)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.linkTitle).font(.headline)
                                Spacer()
                                Text(entry.createdAt, style: .relative).foregroundStyle(.secondary)
                            }
                            Text(entry.urlString)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                            Text("\(entry.targetName) • \(entry.platform.title)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if entry.succeeded == false {
                                Text(entry.message).font(.caption).foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .padding(24)
    }
}
