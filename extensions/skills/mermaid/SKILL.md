---
name: mermaid
description: Generate Mermaid diagram code for any supported type (flowchart, sequence, class, ER, state, gantt, pie, mindmap, timeline, gitgraph, c4, sankey, quadrant, treemap, packet, radar, kanban, architecture, block, xychart, zenuml, user-journey, requirement, venn, wardley, ishikawa, eventmodeling, treeView). Triggers on requests to draw/diagram/visualize/chart/render structure as Mermaid; on `.mmd` files; on phrases like "make a flowchart", "sequence diagram for...", "ER for this schema", "show this as a state machine". For unfamiliar or rarely-used types, Read the matching `references/<type>.md` first.
allowed-tools: Read Write Edit
---

# Mermaid

Generate syntactically-correct Mermaid code. References are official mermaid-js docs vendored from upstream (`mermaid-js/mermaid` repo, `docs/syntax/` + `docs/config/`).

## Workflow

1. Pick the diagram type that fits the user's intent. Ask only if genuinely ambiguous.
2. If you know the syntax cold (flowchart, sequence, class, ER, state, gantt, pie), write it directly.
3. Otherwise Read the matching reference before writing code. Newer/obscure types where this is mandatory: packet, sankey, treemap, radar, kanban, c4, requirement, zenuml, architecture, block, xychart, gitgraph.
4. Output a ` ```mermaid ` fenced block. No prose unless asked.

## Type -> reference

| Type | Reference |
|---|---|
| Flowchart | `references/flowchart.md` |
| Sequence | `references/sequenceDiagram.md` |
| Class | `references/classDiagram.md` |
| State | `references/stateDiagram.md` |
| ER | `references/entityRelationshipDiagram.md` |
| Gantt | `references/gantt.md` |
| Pie | `references/pie.md` |
| Mindmap | `references/mindmap.md` |
| Timeline | `references/timeline.md` |
| Git graph | `references/gitgraph.md` |
| Quadrant | `references/quadrantChart.md` |
| Requirement | `references/requirementDiagram.md` |
| C4 | `references/c4.md` |
| Sankey | `references/sankey.md` |
| XY chart | `references/xyChart.md` |
| Block | `references/block.md` |
| Packet | `references/packet.md` |
| Kanban | `references/kanban.md` |
| Architecture | `references/architecture.md` |
| Radar | `references/radar.md` |
| Treemap | `references/treemap.md` |
| User Journey | `references/userJourney.md` |
| ZenUML | `references/zenuml.md` |
| Venn | `references/venn.md` |
| Wardley | `references/wardley.md` |
| Ishikawa | `references/ishikawa.md` |
| Event Modeling | `references/eventmodeling.md` |
| Tree View | `references/treeView.md` |

## Config / theming

- Theme + colors: `references/config-theming.md`
- Per-diagram directives (`%%{init:...}%%`): `references/config-directives.md`
- Layout direction + spacing: `references/config-layouts.md`
- Global config: `references/config-configuration.md`
- Math/LaTeX: `references/config-math.md`
- Tidy-tree (flowchart layout): `references/config-tidy-tree.md`

## Refreshing the references

Refs come from `mermaid-js/mermaid` upstream. Run `extensions/skills/mermaid/sync.sh` to refresh.
