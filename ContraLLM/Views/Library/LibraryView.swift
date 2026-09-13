//
//  LibraryView.swift
//  ContraLLM
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \Workspace.createdAt, order: .reverse) private var workspaces: [Workspace]

    var body: some View {
        NavigationStack {
            ZStack {
                ContraTheme.background.ignoresSafeArea()

                if workspaces.isEmpty {
                    EmptyStateView(
                        symbolName: "square.grid.2x2",
                        title: "Your library is empty",
                        message: "Sources you add from Home will show up here as workspaces you can revisit anytime."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(workspaces) { workspace in
                                NavigationLink(value: workspace) {
                                    LibraryRow(workspace: workspace)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: Workspace.self) { workspace in
                WorkspaceView(workspace: workspace)
            }
        }
    }
}

private struct LibraryRow: View {
    let workspace: Workspace

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: workspace.sourceType.symbolName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(ContraTheme.accent)
                .frame(width: 44, height: 44)
                .background(ContraTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(workspace.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ContraTheme.textPrimary)
                    .lineLimit(2)

                Text("\(workspace.sourceDisplayName) · \(workspace.sourceType.displayName)")
                    .font(.system(size: 12))
                    .foregroundStyle(ContraTheme.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    ForEach(workspace.availableOutputs, id: \.self) { output in
                        Text(output)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ContraTheme.textSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(ContraTheme.surface)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 2)
            }

            Spacer()

            Text(workspace.createdAt, style: .date)
                .font(.system(size: 11))
                .foregroundStyle(ContraTheme.textTertiary)
        }
        .padding(14)
        .contraCard(padding: 0)
        .padding(0)
    }
}
