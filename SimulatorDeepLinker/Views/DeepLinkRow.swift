//
//  DeepLinkRow.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 22.05.2026.
//

import SwiftUI

struct DeepLinkRow: View {
    let item: DeepLinkItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if item.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                    .padding(.top, 3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(item.urlString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if item.group.isEmpty == false || item.tags.isEmpty == false {
                    Text(([item.group] + item.tags).filter { $0.isEmpty == false }.joined(separator: " • "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
