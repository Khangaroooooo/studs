# Studs — Claude Code project notes

Durable project knowledge lives in the Evervault knowledge base: `~/Documents/Evervault/projects/studs/` (README, code-architecture, tidepool-cove-terrain, overnight-automation, studio-safety-rules). Read the relevant file there before large tasks, and **update it when architecture, conventions, or world-building idioms change**.

Quick facts:
- Rojo project (`rojo serve`); edit `src/**` here, never scripts inside Studio. Validate with `luau-analyze` + `rojo build`.
- TidepoolCove geometry is live-edited in Studio via MCP and NOT in `src/` — git doesn't version it.
- Before any bulk delete/mutate in Studio, follow `~/Documents/Evervault/projects/studs/studio-safety-rules.md` (dry-run, no substring name-matching, reparent-to-trash).
