# Swift CLI as M1 core (shared with future app)

The M1 `loadout` CLI is a Swift executable using the Security framework for
Keychain access, not a shell script or Go binary. M2's menu-bar app will
bundle the same library/executable rather than reimplementing storage.

Go and shell were considered for faster initial delivery; rejected because
Keychain CRUD, import parsing, and quoting logic would need a second
implementation (or awkward FFI) when the SwiftUI app arrives. One Swift
codebase owns storage, export, and import from day one.