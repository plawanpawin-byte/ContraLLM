//
//  ProcessingView.swift
//  ContraLLM
//

import SwiftUI
import SwiftData

struct ProcessingView: View {
    let source: SourceItem

    @StateObject private var viewModel: ProcessingViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var navigateToWorkspace: Workspace?

    init(source: SourceItem) {
        self.source = source
        _viewModel = StateObject(wrappedValue: ProcessingViewModel(source: source))
    }

    var body: some View {
        ZStack {
            ContraTheme.background.ignoresSafeArea()

            switch viewModel.state {
            case .running:
                LoadingView(
                    headline: "Analyzing your source",
                    steps: viewModel.steps,
                    activeIndex: viewModel.activeStepIndex
                )
            case .failed(let message):
                EmptyStateView(
                    symbolName: "exclamationmark.triangle",
                    title: "Processing failed",
                    message: message,
                    actionTitle: "Try again",
                    action: { viewModel.retry() }
                )
            case .done:
                Color.clear
            }
        }
        .navigationBarBackButtonHidden(viewModel.state == .running)
        .navigationDestination(item: $navigateToWorkspace) { workspace in
            WorkspaceView(workspace: workspace)
        }
        .onAppear { viewModel.start() }
        .onChange(of: viewModel.state) { _, newValue in
            if newValue == .done, let workspace = viewModel.resultWorkspace {
                modelContext.insert(workspace)
                try? modelContext.save()
                navigateToWorkspace = workspace
            }
        }
    }
}
