# Terminals-only scope — no GUI-app env injection

Loadout feeds shell sessions only. It does not attempt `launchctl setenv`,
`~/.MacOSX/environment.plist`, or other best-effort GUI-app env wiring.

Modern macOS removed reliable system-wide per-user env for GUI apps; injection
is fragile, hard to debug, and out of scope for a personal terminal tool. If
GUI apps need secrets, they read config another way or are launched from a
terminal that already has the **Active set**.