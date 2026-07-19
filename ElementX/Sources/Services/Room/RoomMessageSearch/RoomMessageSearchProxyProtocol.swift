//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

// sourcery: AutoMockable
protocol RoomMessageSearchProxyProtocol: AnyObject {
    /// Loads the next batch of search results. Returns `nil` once the query is exhausted.
    func loadNextResults() async -> Result<[RoomMessageSearchResult]?, RoomProxyError>
}

struct RoomMessageSearchResult: Identifiable, Equatable {
    let id: String
    let sender: TimelineItemSender
    let timestamp: Date
    let message: AttributedString?
}
