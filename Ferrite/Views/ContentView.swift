//
//  ContentView.swift
//  Ferrite
//
//  Created by Brian Dashore on 7/1/22.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var scrapingModel: ScrapingViewModel
    @EnvironmentObject var debridManager: DebridManager
    @EnvironmentObject var navModel: NavigationViewModel
    @EnvironmentObject var pluginManager: PluginManager
    @EnvironmentObject var logManager: LoggingManager

    @AppStorage("Behavior.AutocorrectSearch") var autocorrectSearch: Bool = false
    @AppStorage("Search.LastQuery") var lastSearchQuery: String = ""

    @FetchRequest(
        entity: Source.entity(),
        sortDescriptors: []
    ) var sources: FetchedResults<Source>

    @State private var searchText = ""
    @State private var isSearching = false
    @State private var isEditingSearch = false
    @State private var dismissAction: () -> Void = {}
    @State private var searchDebounceTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if !scrapingModel.sessionErrors.isEmpty {
                    Section("Source errors") {
                        ForEach(scrapingModel.sessionErrors, id: \.self) { error in
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if searchText.isEmpty, !lastSearchQuery.isEmpty {
                    Section("Quick actions") {
                        Button("Repeat last search: \(lastSearchQuery)") {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()

                            searchText = lastSearchQuery
                            executeSearch()
                        }
                    }
                }

                SearchResultsView(searchText: $searchText)
            }
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .top, spacing: 0) {
                Spacer()
                    .frame(height: 20)
            }
            .navigationTitle("Search")
            .overlay {
                if
                    scrapingModel.searchResults.isEmpty,
                    isSearching,
                    scrapingModel.runningSearchTask == nil,
                    !isEditingSearch
                {
                    EmptyInstructionView(
                        systemName: "magnifyingglass",
                        title: "No results found",
                        message: pluginManager.filteredInstalledSources.isEmpty ?
                            "Make sure you have plugins installed and enabled." :
                            "Check your source filter and redo your search."
                    )
                }
            }
            .expandedSearchable(
                text: $searchText,
                isSearching: $isSearching,
                isEditingSearch: $isEditingSearch,
                prompt: navModel.searchPrompt,
                dismiss: $dismissAction,
                scopeBarContent: {
                    SearchFilterHeaderView()
                },
                onSubmit: {
                    if
                        let runningSearchTask = scrapingModel.runningSearchTask,
                        runningSearchTask.isCancelled
                    {
                        scrapingModel.runningSearchTask = nil
                        return
                    }

                    executeSearch()
                }
            )
            .autocorrectionDisabled(!autocorrectSearch)
            .esAutocapitalization(autocorrectSearch ? .sentences : .none)
            .onAppear {
                navModel.getSearchPrompt()
            }
            .onChange(of: searchText) { newValue in
                guard isSearching else {
                    return
                }

                if newValue.isEmpty {
                    searchDebounceTask?.cancel()
                    return
                }

                searchDebounceTask?.cancel()
                searchDebounceTask = Task {
                    try? await Task.sleep(seconds: 0.4)
                    if Task.isCancelled {
                        return
                    }
                    await MainActor.run {
                        executeSearch()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if scrapingModel.runningSearchTask != nil {
                        Button("Cancel") {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()

                            scrapingModel.cancelCurrentTask()
                            logManager.hideIndeterminateToast()
                        }
                    }
                }
            }
        }
    }

    func executeSearch() {
        lastSearchQuery = searchText
        if let runningSearchTask = scrapingModel.runningSearchTask {
            runningSearchTask.cancel()
            scrapingModel.runningSearchTask = nil
        }
        scrapingModel.runningSearchTask = Task {
            await scrapingModel.scanSources(
                sources: pluginManager.fetchInstalledSources(
                    searchResultsEmpty: scrapingModel.searchResults.isEmpty
                ),
                searchText: searchText,
                debridManager: debridManager
            )

            logManager.hideIndeterminateToast()
            scrapingModel.runningSearchTask = nil
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
