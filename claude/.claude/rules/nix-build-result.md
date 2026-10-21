# Clean up `result` after test builds

When you run `nix build` only to check that a change evaluates and builds (e.g. testing a NixOS configuration change), delete the `result` symlink it creates as soon as the build finishes: `rm result` (also `result-*` for multi-output builds).

- Do this immediately after the test build, success or failure.
- Keep it only when the build output is actually needed afterwards (e.g. the user asked for the artifact, or a later step uses `./result`).
- Prefer `nix build --no-link` when you know up front the output won't be needed.
- Only remove symlinks you created; never touch a `result` that existed before your build.
