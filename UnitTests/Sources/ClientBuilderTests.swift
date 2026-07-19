//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import MatrixRustSDKMocks
import Testing

struct ClientBuilderTests {
    @Test
    func persistentStoresUseDedicatedEncryptedSearchIndex() {
        let builder = ClientBuilderSDKMock()
        builder.sqliteStoreConfigReturnValue = builder
        builder.withSearchIndexStorePathPasswordReturnValue = builder
        let sessionDirectories = SessionDirectories(dataDirectory: URL(filePath: "/tmp/session"),
                                                    cacheDirectory: URL(filePath: "/tmp/cache"))
        
        _ = builder.persistentStores(sessionDirectories: sessionDirectories, passphrase: "secret")
        
        #expect(builder.sqliteStoreConfigCallsCount == 1)
        #expect(builder.withSearchIndexStorePathPasswordReceivedArguments?.path == "/tmp/session/matrix-sdk-search-index")
        #expect(builder.withSearchIndexStorePathPasswordReceivedArguments?.password == "secret")
    }
}
