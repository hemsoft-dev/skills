---
name: shopping
description: V1.2 - Tracks shopping orders, purchases, wishlists, and price monitoring with persistent conversation history.
---

# Shopping Tracker

Track all shopping-related activities including orders, purchases, returns, wishlists, and price monitoring.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## History Management

Every interaction MUST be logged to the History folder:
- Location: `~/.claude/skills/shopping/History/{YYYY-MM-DD}.md`
- Create file if it doesn't exist for the current date
- Append new entries with timestamp

### History Entry Format

```markdown
## {HH:MM} - {Action Type}

- **Order #**: {order_number}
- **Store**: {retailer}
- **Item**: {product_name}
- **Price**: ${amount}
- **Status**: {Ordered|Shipped|Delivered|Returned|Cancelled}
- **Tracking URL**: {tracking_url}
- **Tracking #**: {tracking_number}
- **Notes**: {any relevant details}
```

## Live Tracking

**CRITICAL**: When checking order status or showing tracking info:
1. **Always fetch the tracking URL** using `fetch_webpage` to get live status
2. Extract the latest checkpoint data (dates, times, locations, status)
3. Update the history file with the fresh timeline
4. Present the current status from the live data, not from cached history

### Common Tracking URL Patterns

| Carrier | URL Pattern |
|---------|-------------|
| UPS | `https://www.ups.com/track?tracknum={tracking_number}` |
| FedEx | `https://www.fedex.com/fedextrack/?trknbr={tracking_number}` |
| USPS | `https://tools.usps.com/go/TrackConfirmAction?tLabels={tracking_number}` |
| Corsair | `https://orders.corsair.com/order-status?c_token={token}` |
| Amazon | Use order page URL from history |

## Supported Actions

| Action | Description |
|--------|-------------|
| `track` | Add/update an order |
| `status` | **Fetch live tracking** and update history |
| `list` | Show recent orders |
| `search` | Find orders by keyword |
| `wishlist` | Manage wishlist items |
| `price` | Log price for comparison |

## Data to Capture

- Order/confirmation numbers
- Retailer/store name
- Product name and URL
- Price paid (and original price if on sale)
- Order date
- Expected delivery date
- Tracking numbers and carrier
- Tracking URL (store this for live lookups)
- Current status
- Return window expiration

## Commands

- **"Track order {number} from {store}"** - Log a new order
- **"Update {order} to {status}"** - Change order status
- **"What orders are pending?"** - List undelivered orders
- **"Search {keyword}"** - Find matching orders in history
- **"Check status of {order}"** - **Fetches live tracking data**

## Usage

1. Read history files to find the order and its tracking URL
2. **Fetch the tracking URL** to get live status updates
3. Update the history file with the latest tracking timeline
4. Present the live status to the user
