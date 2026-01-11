---
task: Check-LinkedIn-Messages
created: 2026-01-11
last_run: null
success_rate: null
difficulty: Medium
---

# Check LinkedIn Messages

## Description

Automates checking for unread messages on LinkedIn by logging in and navigating to the messaging section.

## Goals

- [ ] Navigate to LinkedIn login page
- [ ] Authenticate with user credentials
- [ ] Navigate to messaging section
- [ ] Count unread messages
- [ ] Report results

## Workflow

### Step 1: Navigate to LinkedIn

**Action**: Go to <https://www.linkedin.com>  
**Expected**: Homepage loads with sign-in options  
**Error Handling**: If page fails to load, retry up to 3 times

### Step 2: Dismiss App Dialog

**Action**: Click "Dismiss" button on app promotion dialog if present  
**Expected**: Dialog closes and reveals homepage content  
**Error Handling**: Continue if dialog not present

### Step 3: Navigate to Login Page

**Action**: Click "Sign in with email" link  
**Expected**: Login page loads at /login  
**Error Handling**: If link not found, try "Access account" in navigation

### Step 4: Enter Credentials

**Action**: Fill in email/phone and password fields

```javascript
// Use fill_form for both fields
fields: [
  {
    name: "Email or phone",
    type: "textbox",
    ref: "e34",  // May change, use snapshot to get current ref
    value: "{USER_EMAIL}"
  },
  {
    name: "Password",
    type: "textbox",
    ref: "e37",  // May change, use snapshot to get current ref
    value: "{USER_PASSWORD}"
  }
]
```

**Expected**: Credentials entered in form fields  
**Error Handling**: Verify fields are not empty before proceeding

### Step 5: Click Sign In

**Action**: Click "Sign in" button  
**Expected**: Dashboard loads, user is authenticated  
**Error Handling**:

- If 2FA required, handle verification prompt
- If invalid credentials, report error and stop
- If security checkpoint, follow prompts

### Step 6: Navigate to Messaging

**Action**: Look for messaging icon/link in navigation bar  
**Expected**: Messaging page loads showing conversations  
**Error Handling**: If messaging not accessible, check if on correct page

### Step 7: Check for Unread Messages

**Action**: Use snapshot to find unread message indicators

- Look for notification badge on messaging icon
- Count unread conversation items
- Extract sender names and preview text

**Expected**: List of unread messages with counts  
**Error Handling**: If no messages, report "0 unread messages"

### Step 8: Extract Data

**Action**: Use evaluate to extract structured data:

```javascript
async (page) => {
  const unreadMessages = await page.$$eval(
    '[data-test-msg-list-item]:has([data-test-msg-is-unread="true"])',
    items => items.map(item => ({
      sender: item.querySelector('[data-test-msg-sender-name]')?.textContent?.trim(),
      preview: item.querySelector('[data-test-msg-preview]')?.textContent?.trim(),
      time: item.querySelector('[data-test-msg-time]')?.textContent?.trim()
    }))
  );
  
  return {
    totalUnread: unreadMessages.length,
    messages: unreadMessages
  };
}
```

**Expected**: JSON object with unread message details  
**Error Handling**: Return empty array if no messages found

## Output

**Format**: JSON  
**Location**: Console output (can be saved to file if needed)

**Example**:

```json
{
  "totalUnread": 3,
  "messages": [
    {
      "sender": "John Doe",
      "preview": "Hey, wanted to follow up on...",
      "time": "2h ago"
    },
    {
      "sender": "Jane Smith",
      "preview": "Thanks for connecting!",
      "time": "5h ago"
    },
    {
      "sender": "Bob Johnson",
      "preview": "Quick question about...",
      "time": "1d ago"
    }
  ]
}
```

## Security Considerations

**⚠️ CREDENTIAL MANAGEMENT**:

- **Never hardcode credentials** in task files
- Use environment variables or secure credential storage
- Consider using a password manager integration
- LinkedIn may block automated logins - use at own risk

**Recommended Approach**:

1. Store credentials in environment variables:

   ```powershell
   $env:LINKEDIN_EMAIL = "your@email.com"
   $env:LINKEDIN_PASSWORD = "your-password"
   ```

2. Reference them in the task execution
3. Clear variables after use

**Alternative**: Use LinkedIn API with OAuth tokens for production use

## Notes

- LinkedIn has anti-bot detection; automation may trigger security checks
- Login flow may vary if 2FA is enabled
- Element refs (e34, e37, etc.) may change; always use `snapshot` to get current refs
- Consider rate limiting - don't run too frequently
- LinkedIn's UI changes regularly; task may need updates

## Dependencies

- Valid LinkedIn account
- Credentials stored securely
- Browser configured (Microsoft Edge default)

## Known Limitations

- Does not handle 2FA automatically (requires manual intervention)
- May be blocked by LinkedIn's bot detection
- Element selectors may change with LinkedIn UI updates
- Cannot mark messages as read (read-only operation)

## History

### 2026-01-11 15:30

- Status: Created
- Duration: N/A
- Notes: Initial task definition created. Not yet executed with real credentials.
