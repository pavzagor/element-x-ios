# Install Element X Search on iPhone

This fork is parallel-installable with App Store Element. Its bundle identifier is `com.pavzagor.elementxsearch`, display name is `Element X Search`, and shared container is `group.com.pavzagor.elementxsearch`.

## What the Personal Team build deliberately removes

The Personal Team build keeps App Groups and Keychain Sharing. Apple currently supports both for free Apple Developer accounts.

It removes:

- Push Notifications and Communication Notifications.
- Associated Domains.
- The Notification Service Extension from the app product.
- Access to Element Classic’s app group and keychain.

Consequences:

- Push notifications do not work.
- The Share Extension remains available.
- Matrix Authentication Service/OIDC login that depends on Element’s HTTPS callback domain does not work.
- Ordinary Synapse username/password login remains the practical path.
- The app stores its own session and encrypted search index separately from App Store Element.

Apple’s current capability table: <https://developer.apple.com/help/account/reference/supported-capabilities-ios/>

## Install with a free Apple account

### 1. Prepare the Mac

Install Xcode 26.5. Element X currently builds with Xcode 26.5 and targets iOS 18.5 or newer.

After installing Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -version
```

Clone and prepare the fork:

```bash
git clone --branch feat/room-message-search-poc https://github.com/pavzagor/element-x-ios.git
cd element-x-ios
swift run tools setup-project
open ElementX.xcodeproj
```

`setup-project` installs XcodeGen, Sourcery, SwiftFormat, Git LFS, and the other project tools, then regenerates the Xcode project.

### 2. Enable signing

In Xcode:

1. Add your Apple Account under `Xcode → Settings → Accounts`.
2. Select the `ElementX` project.
3. Select the `ElementX` target, then `Signing & Capabilities`.
4. Enable `Automatically manage signing`.
5. Select your Personal Team.
6. Repeat the team selection for the `ShareExtension` target.

Do not change the committed bundle identifiers. They are already unique. If your Apple account has previously registered the same identifiers and Xcode rejects them, change these three values in `app.yml`, then run `xcodegen` again:

```yaml
APP_GROUP_IDENTIFIER: group.com.<your-name>.elementxsearch
BASE_BUNDLE_IDENTIFIER: com.<your-name>.elementxsearch
DEVELOPMENT_TEAM: ""
```

Keep `DEVELOPMENT_TEAM` empty in Git. Select the team in Xcode so the account identifier is not baked into the fork.

### 3. Install on the iPhone

1. Connect the iPhone by USB.
2. Trust the Mac if iOS asks.
3. Enable `Settings → Privacy & Security → Developer Mode` on the iPhone if Xcode asks for it.
4. Select the iPhone as the run destination in Xcode.
5. Select the `ElementX` scheme.
6. Press `Run` or `⌘R`.

The first build resolves Swift packages and can take several minutes. Xcode signs the app with the Personal Team, installs it, and launches it.

### 4. Renew every seven days

A free Personal Team profile expires seven days after issuance. Reconnect the iPhone, open the project, select the same team and device, and press `⌘R` again.

Apple’s documented Personal Team limits are:

- 10 active App IDs, each expiring after seven days.
- 3 test devices per platform, each expiring after seven days.
- Provisioning profiles expiring after seven days.

Source: <https://developer.apple.com/support/compare-memberships/>

## Use the simulator artifact

The `Search POC Build` GitHub Actions workflow packages `ElementXSearch-Simulator.zip`. This is useful for verification but cannot be installed on a physical iPhone.

With a booted Xcode simulator:

```bash
unzip ElementXSearch-Simulator.zip
xcrun simctl install booted ElementX.app
xcrun simctl launch booted com.pavzagor.elementxsearch
```

## Test message search

1. Sign in to a Synapse account using username and password.
2. Wait for the room list and recent messages to sync.
3. Open a room.
4. Tap the search icon in the room toolbar.
5. Enter a message fragment.
6. Tap a result to return to the room and focus that event.

Search uses Matrix Rust SDK `Room.searchMessages` against the encrypted local search index. It does not query the homeserver’s complete history. Messages become searchable after the SDK has synced and indexed them; very old history that has never been loaded locally is not guaranteed to appear.

The current SDK surface does not expose a safe bounded “index all older room history” operation for this UI. The fork therefore reports cached/indexed history honestly instead of pretending the search is complete.

## TestFlight requires the paid program

A free Personal Team cannot distribute through TestFlight. TestFlight needs the paid Apple Developer Program, App Store Connect, registered app and extension identifiers, signing certificates, and provisioning profiles.

For a paid build, restore and configure these capabilities before uploading:

- Push Notifications and the Notification Service Extension.
- Communication Notifications.
- Associated Domains with an `apple-app-site-association` file for the fork’s OIDC callback domain.
- Production APNs and push-gateway configuration.

The fork does not contain Apple credentials or App Store Connect keys. Those must remain local or in protected CI secrets.

## Current machine gate

On 2026-07-19 this Mac had:

- Command Line Tools only; no full Xcode.
- `13 GiB` free disk space.
- No code-signing identity.
- No provisioning profile.
- No connected iPhone or iPad.

Source, generation, unit tests, and simulator packaging can be verified in GitHub Actions. A physical-device install cannot be claimed until Xcode is installed, a Personal Team is selected, and the iPhone is connected. Free at least `40 GiB` before installing Xcode, simulator runtimes, package dependencies, and DerivedData.
