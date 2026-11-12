# kora_customs agent guide

## Boundary

`kora_customs` is a public, self-service cosmetic vehicle shop. It is not a
mechanic job, repair system, performance tuner, or vehicle garage. Keep engine,
brakes, transmission, suspension, armour, turbo, condition, fuel, ownership,
and vehicle state outside this resource.

The one exception is `Config.selfRepair`: an opt-out, paid self-service repair
for when no mechanic is on duty. The server counts on-duty mechanics, checks the
shop, seat, distance, cooldown and elapsed progress time, and charges before
the client fixes the vehicle. Keep it a fallback, not a mechanic feature set.

## Authority

The client may preview cosmetic changes, but checkout is authoritative on the
server. Re-resolve the shop, player, vehicle entity, routing bucket, plate,
model, ownership row, cosmetic allow-list, and price for every purchase. Never
persist a client-supplied complete vehicle-property blob. Merge only validated
cosmetic fields into the properties already stored by kora_core.

Charge before persistence and refund tax-free if persistence fails. Keep the
per-plate lock around both operations so two checkout requests cannot race.

## Tests

Pure validation, pricing, diff, and merge behavior lives in
`shared/catalog.lua` and is exercised by `test/catalog.lua`. Run
`test/run.sh` after changing the cosmetic contract or prices.

## Documentation

User-facing documentation lives in `docs/` (Markdown, published via the Kora Docusaurus site, kora_docs_next). Read `docs/index.md` first for an overview of features, configuration, commands, exports, events and database usage.

When you add, change, or remove a feature, config option, command, export, event, item, permission, or database table/column, update the matching page in `docs/` in the same change. Keep docs accurate to the code; do not document behaviour that does not exist.

Docs rules: plain Markdown with `title`/`sidebar_position` front matter (no `id`/`slug`), relative links only between docs pages, assets inside `docs/`, fenced code blocks with a language, and no raw `<`, `>`, `{`, `}` outside code (pages are parsed as MDX). The release version comes from `fxmanifest.lua`'s `version` field.
