# MT5 Position Sizer & Basket Manager

An Expert Advisor (EA) for MetaTrader 5 designed to help manage manual trades through risk-based position sizing, visual stop-loss calculations, daily profit targets, session-separated basket management, and multi-day carry-over position tracking.

The EA does not place trades automatically. It is designed to assist with positions opened manually by the trader.

## Features

- Percentage-based or fixed-money risk calculation
- Automatic position-size calculation
- Displays the calculated lot size without artificially capping it to the broker maximum
- Displays the broker's maximum allowed lot size separately
- Calculates required margin using MetaTrader 5's margin calculation
- Displays the current spread
- Visual draggable stop-loss line
- Automatically adds the current spread to the entered stop-loss level
- Automatically adds the current spread after manually moving the stop-loss line
- Does not create or modify the broker's actual stop loss
- Percentage-based or fixed-money daily profit targets
- Tracks realised and floating profit/loss
- Session-separated basket management
- Multi-day carry-over position management
- Automatic basket closing when a session target is reached
- Responsive chart panel
- Manual panel scaling from 50% to 150%
- Multi-chart/account-wide shared settings
- Session boundary at 23:30 broker/server time

## How It Works

### Position Sizer

The Position Sizer helps calculate the appropriate trade size before manually opening a position.

1. Select the risk mode:
   - `Percentage` — risk a percentage of the account balance.
   - `Money` — risk a fixed amount of money.

2. Enter the amount or percentage you want to risk.

3. Enter the intended entry price.

4. Enter your intended stop-loss price or move the visual SL line on the chart.

5. The EA automatically adds the current spread to the stop-loss level.

6. Click `CALCULATE`.

The panel displays:

- Risk Amount
- Calculated Size
- Broker Max
- Required Margin
- Current Spread

The calculated size is informational. The EA does not automatically open the position.

### Visual Stop-Loss Line

The SL line is a calculation tool only.

You can either:

- Type a stop-loss price into the Stop Loss field, or
- Drag the SL line directly on the chart.

The current spread is automatically added to the selected stop-loss level.

The adjusted stop-loss price is then displayed in the Stop Loss field and used for the position-size calculation.

The spread is added once when the SL is entered or moved. Resizing or scaling the panel does not repeatedly add the spread.

**Important:** The EA does not create, move, or delete the actual broker stop loss on your position. You remain responsible for setting the real stop loss when placing or managing your position.

### Daily Profit Target

The Daily Performance section allows the target to be specified as either:

- A percentage, or
- A fixed monetary amount.

The remaining target is calculated dynamically using the session's realised profit/loss.

For example:

If the daily target is $100 and $40 has already been realised, the remaining target is $60.

### Trading Sessions

The EA uses a custom trading-day boundary:

**23:30:00 to 23:29:59 broker/server time**

A position permanently belongs to the session in which it was originally opened.

For example:

- A position opened at `23:29:59` belongs to the previous session.
- A position opened at `23:30:00` belongs to the new session.

This allows the EA to separate positions and profit targets across trading days.

### Carry-Over Positions

A position that remains open after the session changes becomes a carry-over position.

Carry-over positions remain permanently associated with their original session and original session target.

They are not transferred into the new day's basket.

A carry-over position can remain open for multiple days. Regardless of whether it remains open for two days, five days, or longer, it continues to belong to the session in which it was originally opened.

For example:

```text
Monday Basket
└── Position A still open

Tuesday Basket
├── Position B
└── Position C

Wednesday Basket
└── Position D
