# ProtestParty

**A fictional, round-based Roblox social comedy and faction-roleplay experience.**

Players join fictional movements, debate absurd policies, participate in rallies, and influence temporary city rules. The humour is aimed at fictional bureaucracy and everyday absurdity—not at protected groups.

## Project status

The located source package is version **0.8.0** and includes Luau service/client scripts, Rojo project configuration, design and security documentation, a static audit script, and a Roblox Studio place file. This repository overview is in place; the source tree and place asset still need to be imported and runtime-validated.

## Technology

- Roblox Studio
- Luau
- Rojo project format
- Roblox DataStore, MemoryStore and MessagingService integrations

## Intended repository layout

```text
src/
  ServerScriptService/
  StarterPlayer/
  ReplicatedStorage/
docs/
tests/
studio/
  ProtestParty_v0.8.0_Studio_Place.rbxlx
default.project.json
```

## Development workflow

1. Install Roblox Studio and Rojo (CLI and Studio plugin).
2. Open a terminal in the project directory.
3. Run `rojo serve default.project.json`.
4. Connect the Rojo Studio plugin to the local server.
5. Test in a private experience before publishing.
6. Use Studio's multi-client test mode for party and cross-server features.

## Security and moderation

- Keep moderator UserIds in trusted server-side configuration.
- Enforce voting, rewards, purchases, party membership, and moderation permissions on the server.
- Filter user-generated text using Roblox's text filtering APIs.
- Test DataStore, MemoryStore and MessagingService behavior in a dedicated test experience.
- Do not rely on client-supplied role or permission claims.

## Validation status

Static source checks are not equivalent to Luau type analysis, Roblox Studio runtime testing, multi-server validation, or exploit testing. Treat this as a development build until those checks are completed.

## License

No license has been selected yet. All rights remain with the project owner; do not assume permission to reuse or redistribute this code.
