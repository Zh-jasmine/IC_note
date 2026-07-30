# Current Note Style Baseline

Source note directory: `/Users/zh-jasmine/Documents/笔记`
User-facing path: `/Users/zh-jasmine/Desktop/笔记`
Baseline scope: Markdown notes only; Obsidian config and binary assets are excluded.

## Observed Structure

- Notes are organized as a numbered learning path.
- Main-topic notes use titles like `00 AXI4 Full 总览`, `01 五通道结构`.
- Larger topics are split into an index note plus a subdirectory of numbered component notes.
- Each note starts directly with the topic, not with background chatter.
- Sections use short `##` headings phrased as questions or concrete concepts.
- Dense ideas are separated into short paragraphs, tables, bullets, and code blocks.

## Observed Writing Pattern

- Start from the lowest causal reason when the concept is subtle.
- Define the concept first, then explain why it exists, then show how it appears in signals/code/verification.
- Prefer "核心含义 / 关键点 / 为什么 / 当前理解重点" style anchors.
- Keep sentences short and direct.
- Use precise technical terms, with short Chinese explanations when needed.
- Avoid motivational language and long summaries.
- Use examples immediately after formulas or rules.
- Preserve uncertainty or project status explicitly, for example "当前限制" and "当前阶段结论".

## Common Formats

- Tables for signal-to-meaning mapping.
- `text` code blocks for protocol sequences, formulas, and data flow.
- `systemverilog` code blocks only when showing actual assertion or RTL-style snippets.
- Bullets for rules, edge cases, and verification points.
- Mermaid diagrams for system connections.
- Obsidian wiki links and embedded image links are used when helpful.

## Quality Targets Inferred From Current Notes

- Rigorous: every rule should be tied to a protocol reason or implementation consequence.
- Brief: omit generic textbook prose and keep only what helps understanding or verification.
- Readable: structure should let another person scan the note and recover the logic.
- Bottom-up: explain the underlying mechanism before naming higher-level conclusions.
- Actionable: where possible, connect concept notes to RTL/UVM/scoreboard/assertion consequences.

## Baseline Caveats

- Some notes are more polished than others; later user edits should be treated as authoritative style corrections.
- The current notes focus on AXI/UVM, so the skill should generalize the style without hardcoding AXI-specific content.

## Revision Signal: 2026-07-18 from `09/04 axi_master_driver`

- Prefer shorter filenames that name the object directly instead of embedding the whole conclusion in the filename.
- Strengthen bottom-up explanation: start from the most abstract responsibility, then move to protocol behavior, then to implementation structure.
- Prefer causal chain over catalog structure. Explain "why this thread/mailbox/outstanding design exists" before listing components.
- Allow longer continuous prose when a mechanism needs to be derived step by step.
- Reduce section fragmentation when the whole note is one continuous argument.
- Keep code skeletons only as anchors; let the main body carry the reasoning.
- Explicitly connect protocol semantics to implementation decisions, such as:
  - why request/response are separated
  - why outstanding needs pending-by-ID storage
  - why `ready` can be split into an independent thread
- Preserve open limitations at the end as a short residual-issues list.
- Risk to control in future revisions: do not let long prose remove scanability entirely; retain clear visual anchors even when using a continuous explanation style.

## Revision Signal: 2026-07-19 from `09/05 axi_slave_mem_driver`

- Keep the same bottom-up style, but anchor it with a more explicit opening sentence that states the component's job relative to its counterpart.
- Use a stronger "start from the simplest model" move before expanding into the real implementation.
- Explain why a small local structure is enough for the slave side, instead of only describing what fields it stores.
- Use paired chains for symmetric behavior when the protocol has a write path and a read path.
- Reserve a final paragraph for exact limitations so the reader can separate implemented behavior from missing AXI features.
- The tone can stay direct and technical even when the note gets long, as long as each paragraph advances the mechanism.

## Revision Signal: 2026-07-25 from revised `09/05 axi_slave_mem_driver`

- Focus more on prose movement than on rigid section layout.
- Use short clauses and visible pauses to slow the reader at key steps.
- Keep the explanation voice direct but slightly conversational, especially when introducing the simple model or the reason a design exists.
- Lean on transition words like "所以", "不过", "同理", "因此" to show the logic chain explicitly.
- Accept sentence fragments or compressed explanatory lines when they help the rhythm of the note.
- Use parenthetical clarifications sparingly to remove ambiguity without breaking the flow.
- Treat mailbox and thread behavior as narrative mechanisms to explain, not just as code objects to enumerate.
- The main style signal here is cadence and explanation flow, not heading density.
