# Non-sandboxed, direct distribution (not App Store)

The macOS app (M2+) ships outside the App Store without App Sandbox enabled.

Sandboxing blocks straightforward Keychain sharing between the menu-bar app and
the `loadout` CLI helper, complicates writing the CLI symlink, and adds
entitlement friction for a single-user dev tool with no untrusted input surface.
Distribution is direct install or `brew install --cask` to the author's machine
only.