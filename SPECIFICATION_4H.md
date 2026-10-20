# ICT 4H Strategy — Standalone EA Specification

## Purpose and separation from Scalp

This document defines the strategy the user says corresponds to the supplied backtest examples and trade journal. It is a separate development direction from the previous Scalp strategy. Do not assume the existing `Scalp.mq5` implements this strategy, and do not silently reuse its M15 Sweep/MSS rules as mandatory conditions. Keep the old EA as a separate legacy prototype.

## Confirmed definitions from follow-up answers
- **P/D means Premium / Discount:** determine whether price is in the upper or lower half of the dealing range.
- **P/D directional entry filter (confirmed):** Buy setups are allowed only when price is in the Discount half of the selected valid H4 dealing range; Sell setups are allowed only when price is in the Premium half. If price is in the wrong half for the intended direction, reject the setup even if other conditions are met.
- **Dealing Range selection:** use the larger, valid dealing range identified from H4 market structure. The exact mechanical criteria for selecting its boundaries remain to be defined. The user has confirmed this is the preferred basis for P/D; do not substitute the previous candle range or simply the latest swing high/low. The exact mechanical criteria for selecting its boundaries remain to be defined.
- **Target clarification:** the target referred to as PL/DH may be the high or low of the previous **H4** candle. Select by trade direction: a buy targets the previous H4 candle high; a sell targets the previous H4 candle low.
- **Take-profit (TP):** use the previous H4 candle high for a buy and the previous H4 candle low for a sell.
- **Target reached before entry (confirmed):** if price has already reached the selected previous-H4-candle TP before the entry can be placed, reject the setup entirely; do not enter late or replace the target with a farther one.
- **Classic model TP (confirmed):** use the previous H4 candle high for a buy and the previous H4 candle low for a sell.
- **TP already reached rule (confirmed):** if the selected TP level (previous H4 candle high for a buy or previous H4 candle low for a sell) has already been reached before entry, reject the setup and do not enter. Do not automatically substitute a farther target.
- **Minimum risk/reward filter (confirmed):** if the projected reward-to-risk ratio from planned entry to the selected TP versus entry to SL is below 1:1, reject the setup. A ratio of exactly 1:1 meets this minimum. Calculate using the actual planned entry, SL, and TP prices before submitting the order.
- **Classic OB entry-zone rule (confirmed):** entry must occur while price is still within the identified OB zone after the directional M1 candle closes. If price has already moved away from the OB zone before the order can be placed, do not chase it; mark the setup as missed. Do not permit a discretionary distance allowance.
- **OB selection when multiple candidates exist (confirmed):** choose the valid OB closest to the current price, subject to all other validity and entry filters.

- **H4 Manipulation Candle:** price breaks a previous high or low, then the candle closes back inside the prior range.
- **Both-side sweep rejection (confirmed):** if an H4 candle breaks both the high and low of the immediately previous H4 candle and then closes back inside that previous candle’s range, reject the setup entirely. Do not infer direction from the close location or other filters.
- **H4 SMT pair:** XAUUSD versus XAGUSD.
- **SMT definition:** one instrument fails to confirm the corresponding high/low made by the other instrument (non-confirmation of a corresponding swing high/low).
- **H4 SMT is mandatory for entry.** If the H4 SMT condition is absent, no entry is allowed.
- **Manipulation-before-SMT sequence (confirmed):** first the H4 Manipulation candle must form and qualify; only after that should the EA evaluate the H4 SMT condition for the setup. SMT that existed before the Manipulation candle is not sufficient by itself for this sequence. If the required SMT is not confirmed after the Manipulation candle, no entry is allowed.
- **SMT timeframe (confirmed):** both the Manipulation candle and the required SMT confirmation must be evaluated on H4. M1 SMT does not substitute for the mandatory H4 SMT confirmation.
- **Opposite-pair target hard veto (confirmed):** if XAGUSD (Silver) has already reached its relevant target before the planned XAUUSD (Gold) entry, reject the Gold setup completely, even if all other Gold setup conditions are satisfied. Do not treat this as conditional on whether SMT remains valid.
- **Order Block (OB), based on the user's explanation:** for a buy, the last bearish candle before a large bullish move; for a sell, the last bullish candle before a large bearish move. **Liquidity-taking for OB validity (confirmed):** liquidity can be taken from highs/lows and FVGs. Taking liquidity is part of the OB definition, not an optional extra filter: a candidate that has not taken liquidity from a relevant high/low or FVG is not a valid OB. An OB may consist of one candle or a group of candles.
- **Breaker Block, based on the user's explanation:** the last OB that drove price toward liquidity and was subsequently invalidated.
- **Mitigation Block, based on the user's explanation:** an OB located on the opposite side of an MMXM; support or resistance is expected from this zone.
- **Mitigation Block entry requirement:** price must return to the Mitigation Block zone before entry; merely identifying the zone is not sufficient.
- **Mitigation Block entry trigger for MMXM (updated by latest confirmation):** after the MMXM sequence reaches a valid MT retest, do not enter immediately. Wait for an M1 candle to close in the intended trade direction (bullish for Buy, bearish for Sell), while the setup remains valid and other mandatory filters hold. No extra OB formation is required.
- **Stop-loss:** place the SL slightly beyond the relevant high/low boundary of the Mitigation Block, accounting for spread. The exact buffer formula is still to be defined.
- **Classic model stop-loss (confirmed):** for a buy, place SL slightly below the OB low; for a sell, place SL slightly above the OB high. The user approved a **fixed buffer of 0.50 in XAUUSD price units**, independent of the current spread. For example, if a buy OB low is 4300.00, place SL at 4299.50; for a sell, place SL 0.50 above the OB high. Spread must still be considered for execution/validity checks, but it does not determine this fixed SL buffer.
- **Classic M1 entry confirmation (confirmed):** after MSS and a retest of the identified OB, enter when an M1 candle closes in the intended trade direction: bullish close/candle for Buy, bearish close/candle for Sell. Candle direction alone is sufficient; it does not need to close outside the OB, and an engulfing pattern is not required, provided the setup remains valid and price is still within the OB entry zone.
- The exact mechanical rules for what qualifies as a large move, how liquidity-taking is identified, how multi-candle OB boundaries are drawn, how an OB is considered invalidated, and how an MMXM/opposite side is detected remain to be confirmed.

## Market model classification: Classic Buy/Sell Model vs MMXM

The user describes two alternative market behaviors/models. The EA must distinguish and record which model is active; do not merge their entry sequences into one generic setup.

### Classic Buy/Sell Model
1. On H4, the user notes SMT between Gold and Silver and waits to see how the current 2:00 a.m. H4 candle develops before deciding on the long idea.
2. On M1, the user waits until after 8:30 and watches price reach the 1:1 proximity level, described in the chart note as related to the midnight level.
3. The chart note says entry could have been taken after price hit the FVG, but the user waited for an OB to open the position.
4. The user confirmed that MSS had already formed in this example before the OB-based entry.
5. In M1, use the New York midnight level as a directional filter: price above the midnight level is for sell setups; price below the midnight level is for buy setups.
6. Around this level, two entry patterns are possible: (a) price crosses above/below midnight and reaches/reacts at an already-existing OB or Mitigation Block; or (b) after crossing the level, an OB or Mitigation Block forms there. The user has confirmed the direction mapping, but has not said that both patterns must occur in every trade.
6. The general classic model rule is: after MSS, wait for price to return to the OB. **Entry trigger (confirmed):** enter after a 1-minute candle closes in the direction of the intended trade (bullish candle for a buy, bearish candle for a sell) following the OB retest. Candle color/direction alone is sufficient; the candle does not need to close fully outside the OB, and engulfing is not required. Other mandatory strategy filters still apply.
7. **Missed-pullback rule (confirmed):** if price does not return to the identified OB after MSS and moves away without a retest, do not enter or chase price. Mark/log the setup as missed.
8. **No immediate invalidation on first candle (confirmed):** if price retests the OB but the first 1-minute candle does not close in the trade direction, keep waiting for a directional 1-minute candle close, provided the setup remains valid and other mandatory filters still hold. No maximum waiting-candle count is imposed: keep waiting for a directional M1 candle close for as long as the setup remains valid and price remains within the OB zone, while all mandatory filters continue to hold.
9. **OB invalidation rule (confirmed):** if price crosses the boundary that keeps the setup valid after the OB retest, invalidate the setup and do not enter. **Boundary confirmed:** for a buy setup, invalidation occurs when a 1-minute candle closes below the OB low; for a sell setup, invalidation occurs when a 1-minute candle closes above the OB high. A wick beyond the boundary without a candle close beyond it does not invalidate the setup. Any spread buffer remains to be defined before coding.
7. These chart observations are an example, not yet universal numeric rules; exact time zone/DST handling and the OB boundary/trigger still need confirmation.

### MMXM
1. Identify the MMXM model.
2. Wait for MSS.
3. After MSS, wait for a pullback to the Breaker Block.
4. Then identify Mitigation Blocks (MTs).
5. Entry is considered only after price returns to the relevant MT zone and an M1 candle closes in the intended trade direction (bullish for Buy, bearish for Sell).

The user's previously confirmed definition remains applicable: price must return to the Mitigation Block zone; identification alone is not enough. For the MMXM path, after MSS and a pullback to the Breaker Block, identify MT zones. When price returns to the relevant MT zone, wait for an M1 candle close in the intended trade direction before entering. This latest confirmation supersedes the earlier direct-entry/no-reaction-confirmation rule.

The exact mechanical definitions of MSS, Classic Buy/Sell Model, MMXM, Breaker Block formation/invalidation, MT formation, the 1:1 proximity level, and the FVG-to-OB entry distinction remain to be confirmed from chart examples. H4 SMT remains a mandatory entry filter.

## Strategy rules supplied directly by the user

### H4
- Look for a **manipulation candle**.
- Look for **SMT**.
- Look for **P/D**.
- Target **liquidity or PL/DH**.
- Notice the **time** and the **open/close of the H4 candle**.

### M1
- Look for **SMT**.
- Look for **MT/OB**.
- Look for **MMXM**.
- Consider **midnight or Proximity** for entry.
- Trade **after 8:30 a.m. New York time (mandatory even without news) and after relevant news**.
- Check the **opposite pair** too, and determine whether it has hit its TP or not.

These are the user's terms. Do not silently expand or redefine P/D, PL/DH, Proximity, MT, or MMXM. Their exact mechanical definitions must be agreed from the user's examples or later instructions before being encoded as hard entry rules.

## Notes from the provided journal/images

The supplied trade notes include observations such as:
- Missing H4 SMT was noted in a losing example.
- News and H4 SMT were noted as things missed in a losing example.
- A note says not to enter after silver has already reached its target.
- A note says to notice the target (PL/PH).
- A note identifies an entry as too late.
- One note describes a 4H manipulation candle and expected distribution toward DOL.
- Examples refer to NY KZ, LO KZ, and LO Close KZ.
- The journal contains both continuation and reversal examples.
- The images include XAUUSD examples and at least one GBPAUD example. Do not assume the gold examples validate all symbols.

These notes are examples and observations, not proof of profitability or a universal rule by themselves.

## Strategy flow to investigate and implement

1. **H4 context:** identify the manipulation candle, SMT and P/D context; mark the liquidity target or PL/DH target; record H4 candle open/close times and prices.
2. **M1 entry context:** evaluate SMT, MT/OB and MMXM as specified by the user's eventual mechanical definitions.
3. **Timing:** evaluate the user's midnight or Proximity entry context, and the rule to trade after news and 8:30. Do not assume the timezone or exact news waiting interval until specified.
4. **Opposite pair:** check the relevant opposite/comparison pair and whether its corresponding TP has already been reached before allowing the setup.
5. **Target state:** do not initiate an entry if the intended target has already been reached or the intended path is no longer valid, consistent with the user's target and opposite-pair notes.
6. **No chasing:** the journal includes an example described as too late. The EA must have a defined, testable entry window and log when a setup is missed/late; the exact cutoff still needs definition.
7. Record the setup classification (continuation/reversal) rather than combining different models invisibly.

**Important:** The user's latest description does not mention M15. Do not add a mandatory M15 Purge/MSS stage from the older Scalp model unless the user explicitly asks for it for this strategy.

## News and timing

- **Mandatory 8:30 New York time gate (confirmed):** no entry is allowed before 8:30 a.m. New York time, even when no news event is scheduled. Treat 8:30 as an independent mandatory time condition, not merely a news filter. Handle New York daylight-saving time and broker-server time explicitly. The separate “after news” requirement remains applicable, but the news-event scope and post-news waiting interval are still undefined.
- The journal contains NY KZ, LO KZ and LO Close KZ references. These should be treated as observations for testing, not a universal session restriction without confirmation.
- Record H4 candle open/close times and the timezone used. New York DST and broker server time must be handled explicitly if New York time is intended.
- Do not claim a news filter is active unless the EA has a reliable, implemented news source and tested event-time logic.

## Risk and trade management

Use these as configurable safeguards carried forward from the project unless the user changes them:
- Base risk: 0.50% balance per trade.
- Recovery risk below explicitly configured initial balance: 0.25%.
- Maximum aggregate open risk for EA-owned positions: 2.0%.
- Maximum 3 successful entries per broker-server day.
- Daily loss limit: 2.0%; stop entries and close EA-owned positions according to the final risk policy.
- Daily profit limit: 2.0%; stop new entries.
- Manage only positions matching the EA's symbol and Magic Number.
- Normalize volume using broker limits and calculate monetary risk before order submission.
- Initial account balance must be explicitly set; zero must block entries with a clear log message.
- No live use before compilation and out-of-sample testing.

## Required diagnostic logging

Log each relevant stage so zero trades can be diagnosed:
- EA name/version, configured symbol and tester symbol.
- H4 manipulation candle: timestamp, open/close, high/low and why it qualified.
- H4 SMT and P/D state.
- Selected liquidity / PL/DH target and whether it has been reached.
- M1 SMT, MT/OB and MMXM state.
- Midnight/Proximity state and the exact time basis.
- News event/time and 8:30 rule evaluation.
- Opposite-pair state and whether its TP has been reached.
- Explicit rejection reason for every skipped entry.
- Order request/result codes and position lifecycle.
- Daily risk counters and daily P/L.

## Inputs and backtest plan

Expose configurable inputs for:
- Exact broker trade symbol and comparison/opposite-pair symbol(s).
- H4 manipulation-candle definition (once agreed).
- SMT and P/D definitions/settings (once agreed).
- MT/OB and MMXM definitions/settings (once agreed).
- Midnight/Proximity timing and timezone.
- News source, event importance and waiting interval; disabled with clear status if no reliable source is available.
- 8:30 timezone and DST handling.
- Risk controls, daily limits, spread/slippage and Magic Number.

Run this EA as a separate test from the legacy Scalp EA, using the same symbol, date range and tick model when comparing results. Review:
- total trades and rejected-setup reasons,
- net profit, profit factor and expected payoff,
- maximum balance/equity drawdown,
- win rate and average R,
- results by continuation/reversal and session,
- news proximity,
- late/missed entries,
- cases where the opposite pair had already hit its TP.

Use out-of-sample periods; do not optimize only to fit the manually supplied examples.

## Definitions still needed before reliable mechanical implementation

The supplied notes do not yet define these mechanically:
1. Exact meaning and detection rules for “manipulation candle”.
2. Exact SMT pair, swing-matching rule, timeframe and whether it is a hard requirement.
3. Exact meaning and selection of “P/D”.
4. Exact definition of “liquidity or PL/DH” target and target selection priority.
5. Exact meaning of “MT”, “OB”, “MMXM” and “Proximity”.
6. What “midnight” means in timezone terms.
7. Which news events count, what “after news” interval means, and the timezone for 8:30.
8. Which opposite pair to check for each market and the exact condition for its TP being considered hit.
9. Stop-loss placement, order-entry price, invalidation, partial exits and final take-profit handling.
10. Exact cutoff that defines an entry as “too late”.

Do not invent definitions and label them as the user's rules. Use the supplied chart examples to infer candidate definitions only when clearly supported, document each assumption, and keep it configurable until confirmed.


## Latest MMXM MT-retest waiting rule (confirmed)

- After price returns to the identified Mitigation Block (MT) zone, if the first M1 candle does not close in the intended trade direction, continue waiting for a later M1 candle to close in that direction.
- Do not reject solely because the first M1 candle is non-directional. Keep the setup eligible only while the original setup remains valid, price remains within the MT zone, and all mandatory filters continue to hold.
- If price leaves the MT zone before a qualifying directional M1 close, do not chase the move; the entry opportunity is missed. No maximum number of M1 candles is imposed while price remains in the MT zone and the setup remains valid.


## MMXM Mitigation Block respect and invalidation (confirmed)

- For an MMXM entry, price must demonstrate respect for the identified Mitigation Block (MT) before entry; merely touching or returning to the MT is not enough. Entry still requires an M1 candle to close in the intended trade direction while the setup remains valid.
- If price does not respect the MT, the MMXM setup is invalidated and must be rejected. Do not wait for price to return again and do not enter from that invalidated MT.
- The precise mechanical definition of MT “respect” (the objective price/candle behavior that distinguishes respect from violation) remains to be defined from the user's chart examples before coding; do not invent it.


## Objective MT respect confirmation (confirmed)

- For the MMXM model, MT respect means price reaches the MT zone and an M1 candle reacts away from the zone and closes in the intended trade direction. A bullish M1 close is required for Buy; a bearish M1 close is required for Sell.
- If this directional reaction/close does not occur and the MT is not respected, invalidate the setup; do not wait for a later return to reuse the same MT. The setup must remain valid and all other mandatory filters must still pass before entry.
- Any more detailed numeric/candle-structure test for MT respect is not specified yet and must not be invented without chart-backed confirmation.
