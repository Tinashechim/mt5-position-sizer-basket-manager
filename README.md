# MT5 Position Sizer & Basket Manager

A MetaTrader 5 Expert Advisor for position sizing, panel-based trade execution, risk management, daily profit targets, and multi-session basket management.

Developed by Tinashe Chimanikire.

## Features

### Position Sizer

The EA calculates position size using:

- Percentage risk
- Fixed-money risk
- Executable market price
- Stop Loss
- Symbol tick size and tick value
- Broker minimum, maximum, and volume step

The panel displays:

- Spread
- Risk Amount
- Calculated Size
- Broker Max
- Required Margin

The calculated position size remains informational and is not silently capped to the broker maximum.

## Panel Trade Execution

Trades can be opened directly from the EA panel.

- BUY uses the current Ask price
- SELL uses the current Bid price
- Position size is recalculated immediately before execution
- The Stop Loss is submitted as an actual broker Stop Loss
- Trades above the broker's maximum volume are rejected rather than silently capped

## Stop Loss Line

The chart includes a draggable red Stop Loss line.

The Stop Loss can be changed using either:

- The Stop Loss input field
- The draggable SL line

The line represents the actual intended broker Stop Loss price.

It can also be shown or hidden from the panel.

## Cost-Aware Risk

The `RISK COSTS: ON/OFF` control determines whether estimated trading costs are included in position sizing.

When enabled:

Planned Risk = Market Loss + Estimated Trading Costs

The current commission estimate was calibrated using an FTMO ETHUSD trade.

Commission structures vary between brokers, account types, and symbols, so the estimate should be treated as configurable rather than universal.

## Required Margin

The EA estimates the margin required for the calculated position using MT5's order-calculation functions.

This allows the trader to compare the intended position size with its approximate margin requirement before execution.

## Daily Profit Target

The daily target can be configured using:

- Percentage mode
- Fixed-money mode

The panel tracks:

- Starting Balance
- Daily Target
- Realized P/L
- Floating P/L
- Remaining Target

## Trading Session

The EA uses a custom trading-day boundary:

**23:30:00 → 23:29:59**

A new session begins at 23:30 broker/server time.

## Multi-Day Carry-Over

Positions remain permanently associated with the session in which they were opened.

For example:

- A trade opened Monday and held into Tuesday remains part of Monday's basket.
- A new Tuesday trade belongs only to Tuesday's basket.
- Monday's carried position does not affect Tuesday's floating P/L or target.
- Tuesday's positions do not affect Monday's basket.

This allows several independent session baskets to coexist.

## Session P/L

Session calculations include:

- Trading profit/loss
- Swap
- Commission where available

Closed trades are attributed to their original opening session rather than the session in which they were closed.

## Automatic Basket Closing

When a session reaches its profit target, the EA can automatically close the open positions belonging to that session.

It does not close positions belonging to another session.

This allows an older carry-over basket and a newer trading-day basket to operate independently.

## Multi-Chart Synchronization

Terminal Global Variables are used to share important EA state between chart instances.

This allows the EA to maintain session information and coordinate basket-management behaviour across charts.

A close lock helps prevent multiple chart instances from attempting to close the same basket simultaneously.

## Responsive Panel

The panel supports manual scaling from:

**50% to 150%**

The `-` and `+` controls adjust panel scale in **1% increments**.

The selected scale is saved so that the panel can retain the preferred size.

## Clean Chart Execution

The EA does not intentionally add trade-entry or trade-exit arrow objects to the chart.

The custom red Stop Loss line remains available for visual risk management.

Platform-native MT5 trade-level displays are controlled separately by MetaTrader chart settings.

## Removing the EA

The `X` button removes the EA and its panel from the chart.

It does **not** close existing trades.

## Installation

1. Open MetaTrader 5.
2. Open MetaEditor.
3. Place `PositionSizerBasketManager.mq5` in the appropriate `MQL5/Experts` folder.
4. Compile the EA.
5. Return to MetaTrader 5.
6. Attach the EA to a chart.
7. Enable Algo Trading.
8. Allow algorithmic trading when required.
9. Test the EA on a demo account before using it on a live or funded account.

## Important Notes

Broker specifications differ between symbols and accounts.

Actual results can be affected by:

- Slippage
- Commission
- Tick value
- Tick size
- Contract size
- Spread
- Broker stop-distance rules
- Volume limits
- Execution conditions

Always verify position sizing and trade execution on the intended broker/account before live use.

## Current Version

### v2.20

Current functionality includes:

- Direct BUY and SELL execution
- Actual broker Stop Loss
- Executable-price risk calculation
- Cost-aware position sizing
- Required Margin
- Percentage and fixed-money risk
- Daily profit targets
- Multi-session basket management
- Multi-day carry-over
- Session-specific automatic basket closing
- Draggable Stop Loss line
- 1% panel scaling
- Multi-chart state coordination
- Clean chart execution

## Author

**Tinashe Chimanikire**
