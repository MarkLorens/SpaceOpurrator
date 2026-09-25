# Graph Report - SpaceOpurrator  (2026-09-25)

## Corpus Check
- 7 files · ~14,773 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 212 file(s) not represented in the graph (top: .import 89, .uid 27, .gd 26)

## Summary
- 32 nodes · 30 edges · 5 communities (3 shown, 2 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `9012ccba`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Bonjour
- GameCenterKit for Godot
- bonjour_module.cpp
- bonjour.mm
- build.sh

## God Nodes (most connected - your core abstractions)
1. `Bonjour` - 9 edges
2. `GameCenterKit for Godot` - 7 edges
3. `build.sh script` - 2 edges
4. `compile()` - 2 edges
5. `_bind_methods` - 1 edges
6. `start_advertising` - 1 edges
7. `stop_advertising` - 1 edges
8. `start_browsing` - 1 edges
9. `stop_browsing` - 1 edges
10. `get_pending_event_count` - 1 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (5 total, 2 thin omitted)

### Community 0 - "Bonjour"
Cohesion: 0.22
Nodes (9): Bonjour, _bind_methods, get_pending_event_count, pop_pending_event, start_advertising, start_browsing, stop_advertising, stop_browsing (+1 more)

### Community 1 - "GameCenterKit for Godot"
Cohesion: 0.25
Nodes (7): API, App Store Connect setup, Compatibility, GameCenterKit for Godot, Install, License, Troubleshooting

### Community 3 - "bonjour.mm"
Cohesion: 0.40
Nodes (4): dns_sd, foundation, inet, network

## Knowledge Gaps
- **13 isolated node(s):** `_bind_methods`, `start_advertising`, `stop_advertising`, `start_browsing`, `stop_browsing` (+8 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 24 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Bonjour` connect `Bonjour` to `bonjour_module.cpp`?**
  _High betweenness centrality (0.267) - this node is a cross-community bridge._
- **What connects `_bind_methods`, `start_advertising`, `stop_advertising` to the rest of the system?**
  _13 weakly-connected nodes found - possible documentation gaps or missing edges._