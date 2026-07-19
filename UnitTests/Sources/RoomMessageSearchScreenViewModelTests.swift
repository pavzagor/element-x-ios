//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementX
import Foundation
import Testing

@MainActor
struct RoomMessageSearchScreenViewModelTests {
    var viewModel: RoomMessageSearchScreenViewModelProtocol!
    var context: RoomMessageSearchScreenViewModelType.Context!
    
    private static func makeResult(eventID: String, body: String) -> RoomMessageSearchResult {
        RoomMessageSearchResult(id: eventID,
                                sender: TimelineItemSender(id: "@alice:matrix.org", displayName: "Alice"),
                                timestamp: .init(timeIntervalSince1970: 0),
                                message: AttributedString(body))
    }
    
    private func makeViewModel(results: [RoomMessageSearchResult]) -> RoomMessageSearchScreenViewModel {
        let searchProxy = RoomMessageSearchProxyMock()
        var batches: [[RoomMessageSearchResult]?] = [results, nil]
        searchProxy.loadNextResultsClosure = {
            .success(batches.isEmpty ? nil : batches.removeFirst())
        }
        let roomProxy = JoinedRoomProxyMock(.init())
        roomProxy.messageSearchProxyQueryReturnValue = searchProxy
        
        return RoomMessageSearchScreenViewModel(roomProxy: roomProxy,
                                                mediaProvider: MediaProviderMock(configuration: .init()))
    }
    
    @Test
    mutating func searching() async throws {
        viewModel = makeViewModel(results: [Self.makeResult(eventID: "$1", body: "Hello"),
                                            Self.makeResult(eventID: "$2", body: "World")])
        context = viewModel.context
        
        let deferred = deferFulfillment(context.observe(\.viewState)) { state in
            state.results.count == 2
        }
        
        context.searchQuery = "hello"
        
        try await deferred.fulfill()
    }
    
    @Test
    mutating func emptyResults() async throws {
        viewModel = makeViewModel(results: [])
        context = viewModel.context
        
        let deferred = deferFulfillment(context.observe(\.viewState)) { state in
            state.shouldShowEmptyState
        }
        
        context.searchQuery = "missing"
        
        try await deferred.fulfill()
    }
    
    @Test
    mutating func clearingQueryResetsResults() async throws {
        viewModel = makeViewModel(results: [Self.makeResult(eventID: "$1", body: "Hello")])
        context = viewModel.context
        
        var deferred = deferFulfillment(context.observe(\.viewState)) { $0.results.count == 1 }
        context.searchQuery = "hello"
        try await deferred.fulfill()
        
        deferred = deferFulfillment(context.observe(\.viewState)) { $0.results.isEmpty && !$0.hasSearched }
        context.searchQuery = ""
        try await deferred.fulfill()
    }
    
    @Test
    mutating func endOfResultsStopsQueryingTheProxy() async throws {
        let searchProxy = RoomMessageSearchProxyMock()
        var batches: [[RoomMessageSearchResult]?] = [[Self.makeResult(eventID: "$1", body: "Hello")], nil]
        searchProxy.loadNextResultsClosure = {
            .success(batches.isEmpty ? nil : batches.removeFirst())
        }
        let roomProxy = JoinedRoomProxyMock(.init())
        roomProxy.messageSearchProxyQueryReturnValue = searchProxy
        
        viewModel = RoomMessageSearchScreenViewModel(roomProxy: roomProxy,
                                                     mediaProvider: MediaProviderMock(configuration: .init()))
        context = viewModel.context
        
        var deferred = deferFulfillment(context.observe(\.viewState)) { $0.results.count == 1 }
        context.searchQuery = "hello"
        try await deferred.fulfill()
        
        deferred = deferFulfillment(context.observe(\.viewState)) { $0.hasSearched && !$0.isLoading && !$0.hasMoreResults }
        context.send(viewAction: .reachedBottom)
        try await deferred.fulfill()
        
        let callsAfterReachingTheEnd = searchProxy.loadNextResultsCallsCount
        
        context.send(viewAction: .reachedBottom)
        context.send(viewAction: .reachedBottom)
        
        #expect(searchProxy.loadNextResultsCallsCount == callsAfterReachingTheEnd)
    }
    
    @Test
    mutating func retryAfterFailure() async throws {
        let failedProxy = RoomMessageSearchProxyMock()
        failedProxy.loadNextResultsReturnValue = .failure(.eventNotFound)
        let successfulProxy = RoomMessageSearchProxyMock()
        successfulProxy.loadNextResultsReturnValue = .success([Self.makeResult(eventID: "$1", body: "Recovered")])
        let roomProxy = JoinedRoomProxyMock(.init())
        roomProxy.messageSearchProxyQueryClosure = { _ in
            roomProxy.messageSearchProxyQueryCallsCount == 1 ? failedProxy : successfulProxy
        }
        
        viewModel = RoomMessageSearchScreenViewModel(roomProxy: roomProxy,
                                                     mediaProvider: MediaProviderMock(configuration: .init()))
        context = viewModel.context
        
        var deferred = deferFulfillment(context.observe(\.viewState)) { $0.hasError && !$0.isLoading }
        context.searchQuery = "hello"
        try await deferred.fulfill()
        
        deferred = deferFulfillment(context.observe(\.viewState)) { $0.results.count == 1 && !$0.hasError }
        context.send(viewAction: .retry)
        try await deferred.fulfill()
        
        #expect(roomProxy.messageSearchProxyQueryCallsCount == 2)
    }
    
    @Test
    mutating func newQueryWhileLoadingStillReturnsResults() async throws {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        let firstProxy = RoomMessageSearchProxyMock()
        firstProxy.loadNextResultsClosure = {
            _ = await stream.first()
            return .success([])
        }
        
        let secondProxy = RoomMessageSearchProxyMock()
        secondProxy.loadNextResultsReturnValue = .success([Self.makeResult(eventID: "$1", body: "Second")])
        let roomProxy = JoinedRoomProxyMock(.init())
        roomProxy.messageSearchProxyQueryClosure = { query in
            query == "first" ? firstProxy : secondProxy
        }
        
        viewModel = RoomMessageSearchScreenViewModel(roomProxy: roomProxy,
                                                     mediaProvider: MediaProviderMock(configuration: .init()))
        context = viewModel.context
        
        var deferred = deferFulfillment(context.observe(\.viewState)) { $0.isLoading }
        context.searchQuery = "first"
        try await deferred.fulfill()
        
        deferred = deferFulfillment(context.observe(\.viewState)) { state in
            state.results.count == 1 && !state.isLoading
        }
        context.searchQuery = "second"
        try await deferred.fulfill()
        
        continuation.finish()
    }
    
    @Test
    mutating func resultSelection() async throws {
        viewModel = makeViewModel(results: [])
        context = viewModel.context
        
        let deferred = deferFulfillment(viewModel.actionsPublisher) { action in
            switch action {
            case .displayEvent(let eventID):
                eventID == "$42"
            default:
                false
            }
        }
        
        context.send(viewAction: .selectResult(eventID: "$42"))
        
        try await deferred.fulfill()
    }
    
    @Test
    mutating func dismiss() async throws {
        viewModel = makeViewModel(results: [])
        context = viewModel.context
        
        let deferred = deferFulfillment(viewModel.actionsPublisher) { action in
            switch action {
            case .dismiss:
                true
            default:
                false
            }
        }
        
        context.send(viewAction: .dismiss)
        
        try await deferred.fulfill()
    }
}
