# CI runner policy

The owner paused iOS CI on 2026-10-11 until a self-hosted Mac is available.
Keep the iOS workflow disabled and manual-only. Never restore a GitHub-hosted
macOS runner or re-enable automatic iOS builds without a working self-hosted Mac.
Missing or canceled iOS validation is not a passing check.
