# ICT 4H Strategy — Standalone EA Specification

## Purpose and separation from Scalp

This document defines the strategy the user says corresponds to the supplied backtest examples and trade journal. It is a separate development direction from the previous Scalp strategy. Do not assume the existing `Scalp.mq5` implements this strategy, and do not silently reuse its M15 Sweep/MSS rules as mandatory conditions. Keep the old EA as a separate legacy prototype.

## Confirmed definitions from follow-up answers

- **H4 Manipulation Candle:** price breaks a previous high or low, then the candle closes back inside the prior range.
- **H4 SMT pair:** XAUUSD versus XAGUSD.
- **SMT definition:** one instrument fails to confirm the corresponding high/low made by the other instrument (non-confirmation of a corresponding swing high/low).
- **H4 SMT is mandatory for entry.** If the H4 SMT condition is absent, no entry is allowed.

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
- Trade **after news and 8:30**.
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

- The user says: “Trade after news and 8:30.” This indicates post-news / 8:30 timing is relevant; it does not yet define an exact number of minutes before/after news or whether every news event is included.
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
