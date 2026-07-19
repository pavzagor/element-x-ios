# Room Message Search POC Implementation Plan

> For Hermes: Use subagent-driven-development to implement this plan task-by-task.

**Goal:** Ship a tested Element X iOS fork with native per-room message search and a reproducible installation path.

**Architecture:** Port PR #5620 onto current `develop` and keep the SDK-backed `Room.searchMessages` iterator. Adapt the screen to current global-search conventions, regenerate generated sources, and keep install-specific settings isolated from upstream application code. Test on GitHub-hosted Xcode 26.5 while the local Mac lacks full Xcode.

**Tech stack:** Swift 6.2, SwiftUI, MatrixRustSDK 26.07.15, XcodeGen, Sourcery, Swift Testing, GitHub Actions, Xcode 26.5.

---

### Task 1: Record and validate the port baseline

**Objective:** Preserve the approved design and prove which PR changes need manual adaptation.

**Files:**
- Create: `docs/plans/2026-07-19-room-message-search-poc.md`

**Steps:**
1. Fetch `refs/pull/5620/head` and record its merge base with current `develop`.
2. Use `git merge-tree --write-tree HEAD upstream/pr-5620` to identify conflicts.
3. Confirm current MatrixRustSDK exposes room-scoped search.
4. Commit the plan.

### Task 2: Port the room-scoped search service and tests

**Objective:** Add the SDK proxy and view-model behavior using test-first adaptation.

**Files:**
- Create: `ElementX/Sources/Services/Room/RoomMessageSearch/RoomMessageSearchProxy.swift`
- Create: `ElementX/Sources/Services/Room/RoomMessageSearch/RoomMessageSearchProxyProtocol.swift`
- Modify: `ElementX/Sources/Services/Room/JoinedRoomProxy.swift`
- Modify: `ElementX/Sources/Services/Room/RoomProxyProtocol.swift`
- Create: `UnitTests/Sources/RoomMessageSearchScreenViewModelTests.swift`
- Create: `ElementX/Sources/Screens/RoomMessageSearchScreen/*`

**Steps:**
1. Port the PR tests before production code.
2. Run the targeted test in GitHub Actions and confirm the expected red result.
3. Port the service, models, view model, coordinator, and views.
4. Adapt changed APIs to current `develop`.
5. Run targeted tests and confirm green.

### Task 3: Integrate search into the current room flow

**Objective:** Open search from the room toolbar and navigate a selected result to its event.

**Files:**
- Modify: `ElementX/Sources/Screens/RoomScreen/*`
- Modify: `ElementX/Sources/FlowCoordinators/RoomFlowCoordinator.swift`
- Modify: `ElementX/Sources/FlowCoordinators/RoomFlowCoordinatorStateMachine.swift`

**Steps:**
1. Add a failing state-machine or view-model test for opening search and displaying an event.
2. Port the PR flow changes.
3. Resolve interactions with current global search and room navigation.
4. Run targeted flow and search tests.

### Task 4: Preserve encrypted index initialization

**Objective:** Ensure both restored and newly authenticated sessions configure the encrypted local search index.

**Files:**
- Modify: `ElementX/Sources/Services/Authentication/AuthenticationClientFactory.swift`
- Verify: `ElementX/Sources/Services/UserSession/UserSessionStore.swift`
- Verify: `ElementX/Sources/Services/UserSession/SessionDirectories.swift`
- Test: relevant authentication and user-session tests

**Steps:**
1. Add or adapt a failing test that proves a fresh client builder receives the search-index path and passphrase.
2. Apply the minimal builder change.
3. Confirm restoration already uses the same protected storage.
4. Run authentication and user-session tests.

### Task 5: Regenerate all generated artifacts

**Objective:** Produce project, mocks, preview tests, and accessibility tests from source configuration.

**Files:**
- Regenerate: `ElementX.xcodeproj/project.pbxproj`
- Regenerate: `ElementX/Sources/Mocks/Generated/GeneratedMocks.swift`
- Regenerate: `ElementX/Sources/Other/TestablePreview/TestablePreviewsDictionary.swift`
- Regenerate: `PreviewTests/Sources/GeneratedPreviewTests.swift`
- Regenerate: `AccessibilityTests/Sources/GeneratedAccessibilityTests.swift`

**Steps:**
1. Install the exact project tools.
2. Run `xcodegen`.
3. Run all four Sourcery configurations.
4. Run SwiftFormat and SwiftLint.
5. Verify generated diffs contain only expected search additions.

### Task 6: Add a parallel-installable POC configuration

**Objective:** Allow the fork to coexist with App Store Element and support automatic local signing.

**Files:**
- Modify: `app.yml`
- Modify: entitlement definitions only where unsupported by Personal Team provisioning
- Create: `docs/INSTALL_SEARCH_POC.md`

**Steps:**
1. Set unique app, extension, URL-scheme, app-group, and keychain identifiers.
2. Rename the display name to `Element X Search`.
3. Keep signing team selectable locally rather than committing credentials.
4. Document capability differences for Personal Team and paid Apple Developer accounts.
5. Verify generated product identifiers are unique.

### Task 7: Build and test with Xcode 26.5

**Objective:** Produce fresh evidence that the source compiles and the tests pass.

**Files:**
- Reuse: `.github/workflows/unit-tests.yml`
- Create or modify a fork-only packaging workflow only if needed for an artifact

**Steps:**
1. Push the feature branch to the fork.
2. Dispatch the unit-test workflow on the feature branch.
3. Run a no-sign simulator build for iPhone and iPad destinations.
4. Run preview and accessibility generation checks.
5. Package the simulator `.app` and test-results artifact.
6. Inspect full logs and fix every compile, lint, and test failure.

### Task 8: Verify installation and document unavoidable gates

**Objective:** Give Pavel exact installation steps backed by the produced artifacts.

**Files:**
- Update: `docs/INSTALL_SEARCH_POC.md`

**Steps:**
1. Verify the local machine’s Xcode, disk, signing identity, provisioning profile, and connected-device state.
2. Document direct Xcode installation with a Personal Team, including seven-day expiry and capability limits.
3. Document TestFlight only for a paid Apple Developer membership.
4. If a device and valid signing identity are available, install and launch the app on the device.
5. Otherwise state the exact remaining human gate; do not claim a device install.
6. Commit, push, and perform final diff and CI review.
