//
//  DebridTransferBrowserView.swift
//  Ferrite
//
//  Created by Brian Dashore on 1/24/26.
//

import SwiftUI

struct DebridTransferBrowserView: View {
    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var navModel: NavigationViewModel
    @EnvironmentObject var debridManager: DebridManager
    @EnvironmentObject var logManager: LoggingManager

    let debridSource: DebridSource
    let handle: DebridTransferHandle?
    let initialFiles: [DebridTransferFile]
    let title: String
    let resultFromCloud: Bool

    @AppStorage("Behavior.AutocorrectSearch") var autocorrectSearch = true

    @State private var files: [DebridTransferFile] = []
    @State private var searchText: String = ""
    @State private var isLoading = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    init(
        debridSource: DebridSource,
        handle: DebridTransferHandle? = nil,
        initialFiles: [DebridTransferFile] = [],
        title: String,
        resultFromCloud: Bool
    ) {
        self.debridSource = debridSource
        self.handle = handle
        self.initialFiles = initialFiles
        self.title = title
        self.resultFromCloud = resultFromCloud
    }

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }

                ForEach(files.filter {
                    searchText.isEmpty ? true : $0.name.lowercased().contains(searchText.lowercased())
                }, id: \.self) { file in
                    Button(file.name) {
                        Task {
                            await unrestrict(file: file)
                        }
                    }
                    .tint(.primary)
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .autocorrectionDisabled(!autocorrectSearch)
            .textInputAutocapitalization(autocorrectSearch ? .sentences : .never)
            .navigationTitle("Select a file")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Transfer error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadFilesIfNeeded()
            }
        }
    }

    private func loadFilesIfNeeded() async {
        if !files.isEmpty {
            return
        }

        if !initialFiles.isEmpty {
            files = initialFiles
            return
        }

        guard let handle else {
            return
        }

        isLoading = true
        do {
            files = try await debridSource.fetchTransferFiles(handle)
            if files.isEmpty {
                errorMessage = "No files were found for this transfer."
                showErrorAlert = true
            }
        } catch {
            errorMessage = friendlyErrorMessage(error)
            showErrorAlert = true
        }
        isLoading = false
    }

    private func unrestrict(file: DebridTransferFile) async {
        guard let handle else {
            return
        }

        do {
            let result = try await debridSource.unrestrictTransferFile(handle, file: file)
            debridManager.downloadUrl = result.urlString
            navModel.selectedTitle = title
            navModel.selectedBatchTitle = file.name
            navModel.resultFromCloud = resultFromCloud
            navModel.selectedMagnet = nil

            var historyInfo = HistoryEntryJson(
                name: title,
                source: debridSource.id
            )
            historyInfo.url = result.urlString
            historyInfo.subName = file.name
            PersistenceController.shared.createHistory(historyInfo, performSave: true)

            navModel.currentChoiceSheet = .action
            dismiss()
        } catch {
            logManager.error("Debrid transfer error: \(error.localizedDescription)")
            errorMessage = friendlyErrorMessage(error)
            showErrorAlert = true
        }
    }

    private func friendlyErrorMessage(_ error: Error) -> String {
        switch error {
        case DebridError.IsCaching:
            return "This item is still caching on the provider. Try again later."
        case DebridError.EmptyUserMagnets, DebridError.EmptyData:
            return "No files were found for this transfer."
        case DebridError.FailedRequest(let description):
            return description
        case DebridError.InvalidPostBody:
            return "Could not process the selected file. Try another file."
        case DebridError.InvalidToken:
            return "You're not authenticated with this provider."
        case DebridError.InvalidUrl:
            return "The provider returned an invalid URL."
        default:
            return error.localizedDescription
        }
    }
}

@MainActor struct DebridTransferBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        DebridTransferBrowserView(
            debridSource: RealDebrid() as DebridSource,
            initialFiles: [
                DebridTransferFile(id: "1", name: "Example.mkv"),
                DebridTransferFile(id: "2", name: "Sample.srt")
            ],
            title: "Example",
            resultFromCloud: true
        )
        .environmentObject(NavigationViewModel())
        .environmentObject(DebridManager())
        .environmentObject(LoggingManager())
    }
}
