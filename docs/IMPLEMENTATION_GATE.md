# Implementation gate: Classic Buy/Sell and MMXM

Updated: 2026-10-29

## Mandatory entry gate

1. Establish the H4 context and all mandatory filters described in `SPECIFICATION_4H.md`.
2. Classify the entry setup as exactly one eligible path: `CLASSIC_BUY`, `CLASSIC_SELL`, `MMXM_BUY`, or `MMXM_SELL`.
3. A detected FVG does not establish a model and does not independently authorize an order.
4. The FVG used for entry must be causally associated with the already-validated model structure. If the code cannot prove that association, reject the entry.
5. Classic Buy/Sell and MMXM must retain separate setup states and entry sequences. A model from one path must not satisfy another path's requirements.
6. Use closed candles for confirmation; do not use future bars.
7. Log model classification, FVG boundaries, associated structural event, and explicit rejection reason.

## Classic path (rules already confirmed)

- Apply mandatory H4 SMT, H4 P/D, target-not-already-hit, opposite-pair veto, 8:30 New York time gate, news requirement (only if reliable news data is configured), and risk filters.
- Classic Buy: price must be below the New York midnight level; Classic Sell: price must be above it.
- Require MSS, then retest of a valid OB that has taken relevant liquidity. Choose the closest valid OB when several candidates remain.
- Enter only on an M1 candle closing in the intended direction while price remains inside the OB zone.
- A buy setup is invalidated by an M1 close below OB low; a sell setup by an M1 close above OB high. A wick alone does not invalidate.
- Do not chase a missed retest.
- Classic SL buffer: fixed 0.50 XAUUSD price units beyond the OB boundary.

## MMXM path (rules already confirmed)

- Detect the MMXM, then MSS, then pullback to a valid Breaker Block, then identify the relevant MT.
- Price must return to the MT, react away from it, and close on M1 in the intended direction. A failed MT respect invalidates that MT; do not reuse it after a later return.
- MMXM SL buffer: fixed 0.50 XAUUSD price units beyond the MT boundary.
- Classic and MMXM share management: at 1R close 50%, move the remaining 50% SL to entry, and leave the rest toward the previous H4 candle high for Buy or previous H4 candle low for Sell.
- Allow re-entry only if every entry condition is valid again; maximum 3 successful entries per broker-server day.

## Unresolved definitions — do not guess in production code

The specification still marks these as needing objective mechanical rules or chart-backed confirmation: selection of valid/larger H4 dealing range; exact MSS and swing matching; what qualifies as a large move and liquidity-taking; multi-candle OB boundaries; Breaker invalidation/boundaries; how the opposite side of MMXM is determined; exact 1:1 Proximity; relevant news-event source/scope/wait; and entry-too-late cutoff.

## Release criteria

- Compile in MetaEditor with zero errors (record warnings separately).
- Run Strategy Tester with the intended broker symbol and tick model.
- Verify no entry occurs from an isolated FVG.
- Verify each model independently with positive and negative chart fixtures.
- Test H4 SMT sequencing, target already reached, opposite-pair TP veto, New York DST, 8:30 gate, OB/MT invalidation, 1R 50% partial close, break-even, daily entry cap, and daily loss limit.
- Run out-of-sample tests. Do not describe the strategy as profitable based only on supplied examples.
