# Keychain-direct secret storage (not envchain)

M1 stores secrets in the macOS Keychain via the Security framework, not via
envchain namespaces or encrypted files. Each secret is a
`kSecClassGenericPassword` item: service attr `loadout:<service>:<variant>`,
account = var name, value = secret. Accessibility is
`kSecAttrAccessibleWhenUnlocked` so new terminals don't trigger Touch ID on
every shell open.

envchain was considered for faster initial delivery but rejected: M1 already
requires a custom CLI for export/import/state, envchain adds an external
dependency and a second namespace model to migrate away from later, and owning
Keychain CRUD keeps one schema for the future GUI (M2+) and the import wizard.