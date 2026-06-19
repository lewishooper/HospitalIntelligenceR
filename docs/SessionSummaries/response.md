Tier 1 — Audit, clean, demographics
This is the foundation everything else rests on. Structured fields that are reliably extractable: meeting date, meeting type (regular/special/annual), quorum met, attendance count, board size, chair name, CEO name present. This produces minutes_master.csv — one row per meeting — and is the precondition for all temporal analysis. Low interpretive risk, high reliability.
Tier 2 — Board foci and sentiment
This is where it gets analytically interesting. Agenda items or topics, with theme classification (aligned to your existing WRK/PAT/FIN etc. taxonomy), and sentiment per topic. The sentiment angle is genuinely novel for this sector — most governance research just counts mentions. The "over time" dimension here is important: are boards spending more time on workforce post-pandemic? Did financial scrutiny spike in certain years?
Tier 3 — Strategy concordance
The operational vs. ceremonial test from the work plan. Joining minutes_topics.csv to strategy_classified.csv by FAC — do boards actually discuss what their strategic plans say they prioritize? This is probably the highest-value finding the project can produce.

A few design questions before we go further:

What's the unit of analysis for foci? Agenda items are the cleanest unit, but minutes vary hugely — some hospitals publish verbatim discussion, others just action items. Do you want to extract agenda items as discrete rows, or score each meeting as a whole against themes?
Sentiment at what level? Per agenda item, per theme per meeting, or per meeting overall? Granular is more powerful but also more fragile if the source documents are terse.
Priority subset for Phase 2? Given the prompt iteration cost, are you inclined to start with Teaching hospitals (best-quality minutes, most strategic richness) or go broad from the start?
##Tier 1
I think we need meeting date, type, and hospital type. I think the other topics(attendence, chair,ceo, etc) are difficult to achieve and i am not sure where I would apply them.
I also think tier 1, will need to do some cleanup, to make sure we have the acutal minutes, and not a Board package. i.e. agenda, and or additional documents. Some agenda packages, will contain presentations,ceo report, chair reports, sub- committee meeting minutes etc.  these may be rare but we want to be sure we identify them

##Tier 2 ##
There was some prior work on board foci, I will dig up the paper and we can review it when we move to tier 2. The foci and sentiment are a bit deeper than agenda items, so I think agenda items becomes a part of the corpus and we may consider weighting it a bit heavier but where discussion is recorded will be very important.  Foci will vary from meeting to meeting, and I am not sure if its a binary output (e.g. finance was discussed true or false) or(20% of the content was related to finance) but lets treat sentiment as a "per meeting" item

Lets build a base using natural language processing tools, particularly for tier 1 and tier 2. Once we have established a baseline of audited data, foci and sentiment, We can then look at testing those results against an AI analysis.
Once we have a clear understanding for tier 1 and 2 then lets come back to the strategic concordance topic, but I would like to make sure we have some deep knowledge on  board minutes before we dive into that. We may also want to consider concordance with Mission Vision and values as a part of tier 3


