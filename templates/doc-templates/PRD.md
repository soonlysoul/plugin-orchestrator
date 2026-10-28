# PRD — <Project name>

| | |
| --- | --- |
| Objective | What the software must do for its users, and how each need is verified |
| Status | DRAFT |
| Approved | — (date and the user's words, written only after the user's explicit approval; an approved document that changes goes back to REVIEW until approved again) |
| Assumptions | <what this document takes for granted> |
| Confirmed decisions | <decisions the user has confirmed, with their date> |
| Related documents | docs/engineering/DECISIONS.md, the TRD of each part (<path>/docs/technical/TRD.md) |
| Verification criteria | Every acceptance criterion is testable and covered by at least one test named after its id |

The PRD is unique to the project: one product, whatever the number of parts. What a part is made of belongs to its language plugin, not to this document.

## Problem

<The problem this software solves, in two or three sentences.>

## Users

<Who uses it, and in which situation.>

## Scope

In:

- <capability>

Out:

- <explicitly excluded capability>

## Acceptance criteria

Numbered `AC-001`, `AC-002`, … Each one is observable and testable, describes behaviour seen by the user, and never names the part that implements it. An id is never renumbered nor reused: a criterion that no longer applies is marked "removed".

| ID | Criterion | Priority |
| --- | --- | --- |
| AC-001 | <Given …, when …, then …> | must |

## Non-goals

- <what this version will not do>

## Open questions

- none
