//
//  HomeView.swift
//  ContraLLM
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var navigatedSource: SourceItem?

    var body: some View {
        NavigationStack {
            ZStack {
                ContraTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(ContraTheme.accent)
                        Text("What do you want to understand?")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(ContraTheme.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("Add a source and Contra will turn it into something you can read, listen to, and explore.")
                            .font(.system(size: 14))
                            .foregroundStyle(ContraTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        QuickSourceChips { type in
                            viewModel.requestFileImport(for: type)
                        }
                        .padding(.horizontal, 16)

                        SourceInputBar(
                            text: $viewModel.inputText,
                            isBusy: false,
                            onPickFileType: { viewModel.requestFileImport(for: $0) },
                            onSubmitURLOrText: { input in
                                navigatedSource = viewModel.makeSource(fromInput: input)
                            }
                        )
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 12)
                }
            }
            .navigationDestination(item: $navigatedSource) { source in
                ProcessingView(source: source)
            }
            .fileImporter(
                isPresented: $viewModel.isImporterPresented,
                allowedContentTypes: viewModel.importerContentTypes,
                allowsMultipleSelection: false
            ) { result in
                if let source = viewModel.handleFileImportResult(result) {
                    navigatedSource = source
                }
            }
            .alert("Something went wrong", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Contra")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ContraTheme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

#Preview {
    HomeView()
}
