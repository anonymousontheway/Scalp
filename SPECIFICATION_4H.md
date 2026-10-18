# ICT 4H Strategy — Standalone EA Specification

## Purpose and separation from Scalp

This document defines a separate strategy based on the user's 4H / 15M / 1M notes and trade journal. It is a replacement direction for future development, not a claim that the existing `Scalp.mq5` already implements these rules. Keep the existing Scalp EA available as a legacy prototype until the new EA is separately implemented and tested.

## Source-derived framework

The user's `4H.pdf` specifies:

- **H4:** Look for IRL/ERL or any PD Array; look for SMT.
- **M15:** Look for Purge; look for SMT; wait for MSS.
- **M1:** Wait for the M15 MSS; look for OB/MT; look for SMT.

The user's trade journal and notes add these observations:

- One losing example notes that 4H SMT was absent and that the setup was overtrading.
- One losing example notes that news and 4H SMT were missed.
- One note says not to enter after silver has already reached its target.
- One note says to pay attention to the target (PL/PH).
- One note says an entry was too late.
- A note says a 4H manipulation candle was used and price was expected to distribute toward DOL.
- Some examples use the New York Kill Zone; some are marked London Kill Zone or London Close Kill Zone.
- The journal includes both continuation and reversal examples.
- The examples include XAUUSD and one GBPAUD example. The primary EA market should be explicitly configured; do not assume every market is validated by the gold examples.

These notes are evidence from a small, manually recorded sample, not proof of profitability or universal rules.

## Strategy sequence to implement

### 1. H4 context (setup qualification)

1. Detect a relevant, confirmed H4 PD Array and/or IRL/ERL target.
2. Identify the intended draw on liquidity (DOL) and record the relevant prior high/low (including PL/PH where applicable).
3. Evaluate SMT using the selected comparison instrument. For the user's gold setup, the intended comparison appears to be XAUUSD versus XAGUSD, but the exact swing-matching algorithm must be documented in code and tested.
4. Preserve setup direction as either reversal or continuation; do not merge these into one signal without recording which type qualified.
5. A setup with unclear target/path is invalid and must not enter.
6. The journal suggests H4 SMT is an important quality condition, particularly to avoid weak/overtraded setups. Whether it is a hard requirement for every continuation setup remains an explicit strategy decision; do not silently make it mandatory for all setups.

### 2. M15 trigger

1. After an H4 context is valid, wait for a Purge/liquidity sweep in the relevant direction.
2. Evaluate M15 SMT as additional context.
3. Wait for a confirmed M15 Market Structure Shift (MSS) after the Purge. Use closed candles for confirmation.
4. Do not enter before the M15 MSS.
5. Expire the setup if it becomes stale or the H4 context/target is invalidated. Expiry must be an input and logged.

### 3. M1 entry

1. Only evaluate entry after the relevant M15 MSS is confirmed.
2. Search for the user's stated OB/MT entry model. “MT” is not defined in the supplied PDF/journal; do not invent a definition. Implement OB first only if its exact mechanical definition is written down and expose MT as a pending extension until clarified.
3. Evaluate M1 SMT as confluence according to the eventual explicit rule.
4. Enter only at a defined OB/MT trigger; no chasing after price has left the entry zone.
5. Before sending an order, verify the original H4 target remains available and has not already been reached. Do not enter after the relevant target has been hit, including the noted case where silver has already reached its target if that is part of the selected SMT rule.
6. Record the exact rejection reason whenever a potential setup does not become a trade.

## Session and news observations

- The trade journal contains NY KZ, LO KZ, and LO Close KZ examples. One note questions taking trades during London and another says an entry was too late.
- Sessions should be configurable and evaluated separately in backtests; do not infer that all London trades are prohibited from a single note.
- News mattered in at least one noted loss, and another note explicitly says no news was present. The source material does not specify an authoritative news feed or a complete blackout window.
- Until a reliable news feed and exact rule are implemented, news filtering must be clearly marked as unavailable/disabled; never claim that news is being filtered when it is not.
- Any timezone conversion must account for New York DST and broker server time.

## Risk and trade management

Carry forward the existing project's risk controls as configurable safeguards unless the user explicitly changes them:
- Base risk: 0.50% balance per trade.
- Recovery risk below explicitly configured initial balance: 0.25%.
- Maximum aggregate open risk for EA-owned positions: 2.0%.
- Maximum 3 successful entries per broker-server day.
- Daily loss limit: 2.0%; stop entries and close EA-owned positions according to the existing risk policy.
- Daily profit limit: 2.0%; stop new entries.
- Only manage positions matching the EA's symbol and Magic Number.
- Use broker-aware volume normalization and calculate monetary risk before order submission.
- Initial account balance must be explicitly set; zero must visibly block entries with a clear log message.
- A target touch should close the strategy's owned position(s) as specified by the final implementation and clear stale setup state.
- No live use before compilation and out-of-sample testing.

## Required diagnostic logging

Every run should log:
- EA name/version, configured symbol and chart/test symbol.
- H4 context detected: PD Array, DOL, direction, continuation/reversal classification, H4 SMT result.
- M15 Purge and SMT result, MSS level/time, setup expiry.
- M1 OB/MT zone, M1 SMT result, entry eligibility.
- Explicit reason for every rejected entry (e.g. no H4 PD Array, target unclear/already reached, missing required SMT, no Purge, no MSS, no OB/MT, session blocked, risk invalid, spread too high, order rejected).
- Order request/result codes and position lifecycle.
- Daily risk counters and daily P/L.

## Inputs and backtest design

Expose inputs for:
- Trade symbol (exact broker symbol, e.g. XAUUSDb where that is the broker's name).
- SMT comparison symbol and whether comparison data is required.
- Separate toggles for H4, M15 and M1 SMT use, with the effective hard/soft rule documented.
- Session windows and New York DST handling.
- News filter state (only functional if a reliable feed exists).
- Risk controls and daily limits.
- Setup expiry, spread/slippage limits and Magic Number.

Backtest the new EA separately from Scalp on the same symbol, dates and tick model. Compare:
- trade count and rejected-setup reasons,
- net profit, profit factor, expected payoff,
- maximum balance/equity drawdown,
- win rate and average R,
- continuation vs reversal,
- sessions and news proximity,
- entry quality and missed/late entries.
Use out-of-sample periods and avoid selecting parameters solely to fit the supplied examples.

## Open definitions that must not be silently guessed

The supplied notes do not define these mechanically:
1. Which PD Arrays qualify and how a valid H4 one is selected.
2. Exact definitions of Purge, M15 MSS, and the required swing points.
3. Exact SMT algorithm, comparison pair, timeframe and whether SMT is mandatory for reversals, continuations, or both.
4. The meaning of “MT” in “OB/MT”.
5. Exact OB selection, mitigation/entry price, invalidation, stop placement and target selection.
6. Whether news, session windows, and the silver-target rule are hard blockers or optional confluence.
7. Exact trade management and exit/partial-take-profit rules.

Implement a transparent, testable first version with explicit inputs and diagnostic logs. If a definition is still unresolved, mark it as an assumption or leave that feature disabled rather than presenting it as a source-derived rule.
