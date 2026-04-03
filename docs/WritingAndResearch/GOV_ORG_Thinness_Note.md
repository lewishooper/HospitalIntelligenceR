# Why Governance & Leadership (GOV) and Organizational Culture (ORG) Are Thin
## A Note on the Thematic Classification Results
*HospitalIntelligenceR Analytics — April 2026*

---

The thematic classification of 543 strategic directions across 115 Ontario hospitals
returned only 2 directions coded GOV (Governance & Leadership) and 15 coded ORG
(Organizational Culture & Excellence) — together representing just 3% of all directions.
This is not a classification error. It reflects something real and analytically important
about how Ontario hospitals write strategic plans.

---

## Why GOV Is Nearly Absent

Governance and leadership are not absent from Ontario hospital life — they are present
everywhere. But they are almost never articulated as a *strategic direction* in a public
strategic plan, for three related reasons.

**Governance is assumed, not declared.** Board governance, accountability structures,
and leadership pipelines are understood as preconditions for any strategy, not
strategic choices in themselves. A hospital that lists "Strong Governance" as a
strategic direction is implicitly signalling that its governance was previously weak —
which no board wants to put in writing.

**The accountability framework already mandates it.** Ontario hospitals operate under
the Accountability Agreement framework with Ontario Health, which explicitly requires
governance standards as a condition of funding. Because governance is externally
mandated and monitored, it need not be restated as an internal strategic priority.
The plan would be redundant.

**Governance content lives in different documents.** Board governance frameworks,
by-laws, committee structures, and CEO accountability agreements are typically housed
in board-facing governance documents — not in the public-facing strategic plan. The
strategic plan is an external communication tool. Governance is an internal operating
discipline. The two documents serve different audiences.

The 2 GOV directions in our dataset are therefore likely edge cases — hospitals that
made an unusual choice to include governance explicitly — rather than representatives
of a genuine strategic theme. They should be reclassified before analysis.

---

## Why ORG Is Thin

Organizational Culture & Excellence is thin for a different but equally structural
reason: it tends to get absorbed by adjacent themes rather than standing alone.

**Culture is embedded in Workforce directions.** When hospitals write about building
a positive workplace, fostering psychological safety, or living their values, that
content is almost always framed as a *people* strategy rather than an *organizational*
strategy. The classifier correctly assigns those directions to WRK. What remains for
ORG is the narrower set of directions about the hospital as an institution — its
identity, its pursuit of continuous improvement as an end in itself — which is
genuinely less common as a standalone strategic priority.

**Excellence language is ubiquitous but rarely primary.** "Excellence" appears in
direction names across the dataset, but it almost always modifies something else —
clinical excellence, operational excellence, excellence in patient care. As a
standalone theme it is rare. The classifier correctly treats "excellence" as
secondary context rather than the primary theme in most cases.

**Organizational identity is implicit in Ontario hospital strategy.** The Denis,
Langley & Lozeau research on Ontario hospitals found that strategic plans tend to be
consensus-driven and politically shaped — meaning the organizational identity content
that might generate ORG directions is often embedded in the vision and mission
statements rather than articulated as discrete strategic directions. Our extraction
captures vision and mission as plan-level fields, not as direction rows, which means
that organizational culture content may be systematically undercounted in the
direction-level analysis.

---

## What This Means for 01b

**GOV** should be retired from the taxonomy for direction-level analysis. The 2 GOV
directions will be manually reviewed and reclassified before 01b is run.

**ORG** sits at the 15% hospital floor. The decision to keep it as a standalone
category or fold it into WRK should be made after counting how many distinct hospitals
are represented in those 15 directions. If the answer is fewer than 17 hospitals,
the case for consolidation is strong. If it appears across 20+ hospitals in small
numbers, it may be worth retaining as a minor but real theme.

The thinness of GOV and ORG is, in itself, an analytical finding: Ontario hospital
strategic plans are externally oriented documents focused on care delivery, people,
and financial sustainability — not on internal governance or organizational identity.
This is consistent with the literature and worth noting in the white paper.

---

*Note: PAR (Partnerships & Integration) is high — 86 directions, 16% of the total —
for a different structural reason: provincial policy. Ontario Health's integration
mandate, the shift from LHINs to Ontario Health Teams, and the explicit accountability
requirements around system partnership have made partnerships a near-universal
strategic priority across hospital types. PAR's prominence reflects policy pressure,
not organic strategic choice — a distinction worth making explicit in any comparative
analysis.*
