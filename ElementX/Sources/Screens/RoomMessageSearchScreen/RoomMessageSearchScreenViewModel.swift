//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AsyncAlgorithms
import Combine
import Foundation

typealias RoomMessageSearchScreenViewModelType = StateStoreViewModelV2<RoomMessageSearchScreenViewState, RoomMessageSearchScreenViewAction>

class RoomMessageSearchScreenViewModel: RoomMessageSearchScreenViewModelType, RoomMessageSearchScreenViewModelProtocol {
    private let roomProxy: JoinedRoomProxyProtocol
    private var searchProxy: RoomMessageSearchProxyProtocol?
    private var searchQueryObservationTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    
    private let actionsSubject: PassthroughSubject<RoomMessageSearchScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<RoomMessageSearchScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(roomProxy: JoinedRoomProxyProtocol, mediaProvider: MediaProviderProtocol?) {
        self.roomProxy = roomProxy
        
        super.init(initialViewState: RoomMessageSearchScreenViewState(), mediaProvider: mediaProvider)
        
        let searchQueryStream = context.observe(\.viewState.bindings.searchQuery)
            .debounce(for: .milliseconds(250))
            .removeDuplicates()
        searchQueryObservationTask = Task { [weak self] in
            for await query in searchQueryStream {
                self?.search(query: query)
            }
        }
    }
    
    isolated deinit {
        searchQueryObservationTask?.cancel()
        loadTask?.cancel()
    }
    
    override func process(viewAction: RoomMessageSearchScreenViewAction) {
        switch viewAction {
        case .dismiss:
            actionsSubject.send(.dismiss)
        case .selectResult(let eventID):
            actionsSubject.send(.displayEvent(eventID: eventID))
        case .reachedBottom:
            loadNextResults()
        case .retry:
            search(query: state.bindings.searchQuery)
        }
    }
    
    private func search(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        loadTask?.cancel()
        state.results = []
        state.hasSearched = false
        state.isLoading = false
        state.hasMoreResults = false
        state.hasError = false
        
        guard !trimmedQuery.isEmpty else {
            searchProxy = nil
            return
        }
        
        searchProxy = roomProxy.messageSearchProxy(query: trimmedQuery)
        state.hasMoreResults = true
        loadNextResults()
    }
    
    private func loadNextResults() {
        guard let searchProxy, state.hasMoreResults, !state.isLoading else { return }
        
        state.isLoading = true
        loadTask = Task { [weak self, searchProxy] in
            let result = await searchProxy.loadNextResults()
            
            guard let self, self.searchProxy === searchProxy, !Task.isCancelled else { return }
            
            switch result {
            case .success(let results):
                if let results {
                    state.results += results
                } else {
                    self.searchProxy = nil
                    state.hasMoreResults = false
                }
            case .failure(let error):
                MXLog.error("Failed loading message search results: \(error)")
                self.searchProxy = nil
                state.hasMoreResults = false
                state.hasError = true
            }
            
            state.hasSearched = true
            state.isLoading = false
        }
    }
}
