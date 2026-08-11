//
//  DeepLinkGuideView.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import SwiftUI

struct DeepLinkGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Groups, Tags, and Environments")
                    .font(.title2.weight(.semibold))
                Text("Use groups for navigation, tags for search, and environments for values that change between builds.")
                    .foregroundStyle(.secondary)

                guideSection(
                    title: "Groups",
                    systemImage: "folder",
                    description: "A link can belong to one optional group. Groups appear in the sidebar filter and work best as broad product areas.",
                    example: "Examples: Authentication, Catalog, Checkout"
                )

                guideSection(
                    title: "Tags",
                    systemImage: "tag",
                    description: "A link can have multiple comma-separated tags. Tags are included in search and work best for platforms, test suites, or temporary labels.",
                    example: "Examples: ios, android, smoke, regression"
                )

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Environments", systemImage: "slider.horizontal.3")
                            .font(.headline)
                        Text("Write reusable placeholders in the saved URL, then define a different value for each environment in Settings → Environments.")
                            .foregroundStyle(.secondary)

                        exampleRow("Saved Template", value: "{{BASE_URL}}/product/${PRODUCT_ID}")
                        exampleRow("Development", value: "https://dev.example.com/product/42")
                        exampleRow("Production", value: "https://example.com/product/42")

                        Label(
                            "Selecting an environment does not change the saved template. Substitution only affects the resolved preview, Open action, and QR code.",
                            systemImage: "info.circle"
                        )
                        .font(.callout)

                        Label(
                            "A placeholder without a value remains in the URL, so define every required variable before opening the link.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.callout)
                        .foregroundStyle(.orange)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(18)
        }
    }

    private func guideSection(
        title: LocalizedStringKey,
        systemImage: String,
        description: LocalizedStringKey,
        example: LocalizedStringKey
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Text(description)
                    .foregroundStyle(.secondary)
                Text(example)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func exampleRow(_ title: LocalizedStringKey, value: String) -> some View {
        LabeledContent(title) {
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}
