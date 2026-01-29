---
name: shopping
description: V1.4 - Tracks shopping orders, purchases, wishlists, price monitoring, and automated re-ordering via Playwright MCP browser automation with persistent conversation history.
---

# Shopping Tracker

Track all shopping-related activities including orders, purchases, returns, wishlists, price monitoring, and automated re-ordering.

## Integration with Playwright MCP

For re-ordering functionality, this skill integrates with **Playwright MCP** to automate browser interactions with Amazon and other retailers. When performing re-orders:

1. **Read the playwright skill** (`playwright/SKILL.md`) to understand available MCP tools
2. Use Playwright MCP tools for all browser automation (`mcp_microsoft_pla_browser_*`)
3. User handles login manually - assume user is already authenticated
4. Follow snapshot-first approach: use `snapshot` before taking screenshots
5. All browser interactions must use Playwright MCP tools

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
- **Product URL**: {product_url} (for Amazon: include full URL and ASIN)
- **ASIN**: {asin} (Amazon orders only)
- **Price**: ${amount}
- **Status**: {Ordered|Shipped|Delivered|Returned|Cancelled}
- **Tracking URL**: {tracking_url}
- **Tracking #**: {tracking_number}
- **Notes**: {any relevant details}
```

**For Amazon Orders**: Always capture Product URL and ASIN to enable re-ordering.

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
| `reorder` | **Automated re-ordering** - Find previously ordered items and add to cart |

## Data to Capture

- Order/confirmation numbers
- Retailer/store name
- Product name and URL
- **Amazon Product URL/ASIN** (for Amazon orders - enables re-ordering)
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
- **"Re-order {item description}"** - Find previously ordered item and add to cart (e.g., "re-order dental sticks that I've ordered before")

## Usage

1. Read history files to find the order and its tracking URL
2. **Fetch the tracking URL** to get live status updates
3. Update the history file with the latest tracking timeline
4. Present the live status to the user

## Re-Ordering Workflow

**CRITICAL**: Use **Playwright MCP tools** for all browser automation. User will handle login manually.

### Re-Order Process

When user requests to re-order an item (e.g., "re-order dental sticks that I've ordered before"):

1. **Search Strategy** (in order):
   - First: Search local shopping history files for matching items
   - Second: Navigate to Amazon order history and search there
   - Third: If not found in order history, search Amazon product catalog

2. **Product Selection**:
   - Use **most recent** order when multiple matches found
   - Be **price-conscious** - compare current price with historical price
   - If price significantly increased, mention it to user before adding to cart

3. **Amazon Order History Navigation**:
   - Use `mcp_microsoft_pla_browser_navigate` to go to `https://www.amazon.com/your-orders`
   - Use `mcp_microsoft_pla_browser_snapshot` to get page elements (lightweight accessibility tree)
   - Look for search/filter elements or order list using element refs

4. **Finding the Product**:
   - If product URL/ASIN stored in history: Navigate directly to product page
   - If not: Search Amazon order history, then click on matching order item using `mcp_microsoft_pla_browser_click`
   - Extract product details using `mcp_microsoft_pla_browser_evaluate` for JSON data

5. **Adding to Cart**:
   - Use `mcp_microsoft_pla_browser_snapshot` to get current page elements
   - Find "Add to Cart" button using element ref from snapshot
   - Use `mcp_microsoft_pla_browser_click` with the button's ref
   - Use `mcp_microsoft_pla_browser_wait_for` with `--load networkidle` to wait for cart update

6. **Verification & Reporting**:
   - **Get cart details**: Navigate to cart page if needed
   - **Extract information** using `mcp_microsoft_pla_browser_evaluate`:
     - Product name
     - Current price
     - Quantity added
     - Subtotal
   - **Take screenshot** (ONLY at end): `mcp_microsoft_pla_browser_take_screenshot` with `type: "jpeg"` (viewport only)
   - **Report back** with:
     - ✅ Item successfully added to cart
     - Product name and details
     - Current price (compare with historical if available)
     - Quantity
     - Cart link: `https://www.amazon.com/gp/cart/view.html`
     - Screenshot saved

7. **Important Notes**:
   - **DO NOT** proceed to checkout - stop at cart
   - **DO NOT** complete purchase - user handles checkout manually
   - **Use snapshot-first approach** - ONLY take screenshot at end for verification
   - If item is unavailable or significantly more expensive, report this to user
   - If multiple variants exist (size, color, etc.), use the variant from most recent order

### Example Re-Order Flow

Using Playwright MCP tools:

1. **Search local history** (Read shopping/History/*.md files for "dental gum picks")

2. **Navigate to Amazon order history**:

   ```
   mcp_microsoft_pla_browser_navigate(url: "https://www.amazon.com/your-orders")
   ```

3. **Get page snapshot**:

   ```
   mcp_microsoft_pla_browser_snapshot()
   ```

4. **Click on matching order item** (using ref from snapshot):

   ```
   mcp_microsoft_pla_browser_click(element: "ref from snapshot", ref: "e5")
   ```

5. **Get product page snapshot**:

   ```
   mcp_microsoft_pla_browser_snapshot()
   ```

6. **Add to cart**:

   ```
   mcp_microsoft_pla_browser_click(element: "Add to Cart button", ref: "e12")
   mcp_microsoft_pla_browser_wait_for(wait_for: "networkidle")
   ```

7. **Verify and report**:

   ```
   mcp_microsoft_pla_browser_evaluate(script: "JSON.stringify({name: document.querySelector('..').textContent, price: ...})")
   mcp_microsoft_pla_browser_take_screenshot(path: "cart-screenshot.png", type: "jpeg")
   ```

### Storing Product Information

When tracking Amazon orders, **ALWAYS** capture:

- **Product URL**: Full Amazon product page URL
- **ASIN**: Amazon Standard Identification Number (found in URL or product details)
- **Product Name**: Exact name as shown on Amazon
- **Price at time of order**: For price comparison during re-orders

Example history entry format for Amazon orders:

```markdown
- **Store**: Amazon
- **Item**: Greenies Original Dental Dog Treats
- **Product URL**: https://www.amazon.com/dp/B0002UNY8Y
- **ASIN**: B0002UNY8Y
- **Price**: $45.99
```
