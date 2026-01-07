---
name: teams
description: V1.0 - Expert in Microsoft Teams API via Microsoft Graph for reading chats, sending messages, checking presence, and managing teams with delegated user tokens.
---

# Microsoft Teams

Interact with Microsoft Teams via Microsoft Graph API using delegated user tokens.

> ⚠️ **STATUS: BLOCKED** (Jan 2026)
> 
> Azure app "Teams-Integration" (Client ID: `2c6945c4-7632-4568-8acf-fe585b838489`) was registered in Relias tenant but **admin consent is required** for ALL applications due to tenant policy. Request submitted to IT - approval unlikely. This skill is **non-functional** until IT approves the app or grants user consent permissions.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Authentication

**Token**: Uses delegated (user) access token stored in `$env:MS_GRAPH_TOKEN`

Get token via OAuth 2.0 authorization code flow:
```
https://login.microsoftonline.com/{tenant}/oauth2/v2.0/authorize
?client_id={app-id}
&response_type=code
&scope=Chat.Read Chat.ReadWrite ChatMessage.Send Presence.Read Team.ReadBasic.All Calendars.ReadWrite offline_access
```

**Base URL**: `https://graph.microsoft.com/v1.0`

## Available Permissions (No Admin Consent Required)

| Permission | Use Case |
|------------|----------|
| Chat.Read | Read your chats/messages |
| Chat.ReadWrite | Read/write chats |
| Chat.Create | Create new chats |
| ChatMessage.Read | Read chat messages |
| ChatMessage.Send | Send chat messages |
| ChannelMessage.Send | Send to channels |
| ChannelMessage.Edit | Edit your messages |
| Team.Create | Create teams |
| Team.ReadBasic.All | List teams |
| Presence.Read | Your presence |
| Presence.Read.All | All user presence |
| TeamsActivity.Read | Activity feed |
| TeamsActivity.Send | Send notifications |
| **Calendars.Read** | Read your calendar |
| **Calendars.ReadWrite** | Full calendar access |
| **Calendars.Read.Shared** | Read shared calendars |
| **Calendars.ReadBasic** | Read events (no body) |

## Common Operations

### List My Chats
```powershell
$h = @{Authorization = "Bearer $env:MS_GRAPH_TOKEN"}
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/chats" -Headers $h
```

### Get Chat Messages
```powershell
$chatId = "19:xxx@thread.v2"
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/chats/$chatId/messages?`$top=20" -Headers $h
```

### Send Chat Message
```powershell
$body = @{
    body = @{
        content = "Hello from API!"
    }
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/chats/$chatId/messages" `
    -Method POST -Headers $h -Body $body -ContentType "application/json"
```

### Get My Presence
```powershell
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/presence" -Headers $h
```

### Get User Presence (by email)
```powershell
$email = "user@company.com"
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users/$email/presence" -Headers $h
```

### List Teams I'm In
```powershell
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/joinedTeams" -Headers $h
```

### Get Team Channels
```powershell
$teamId = "team-guid-here"
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/teams/$teamId/channels" -Headers $h
```

### Send Channel Message
```powershell
$teamId = "team-guid"
$channelId = "channel-id"
$body = @{ body = @{ content = "Hello channel!" } } | ConvertTo-Json

Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/teams/$teamId/channels/$channelId/messages" `
    -Method POST -Headers $h -Body $body -ContentType "application/json"
```

### Get Activity Feed
```powershell
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/teamwork/installedApps" -Headers $h
```

## Calendar Operations

### List Today's Events
```powershell
$today = (Get-Date).ToString("yyyy-MM-ddT00:00:00")
$tomorrow = (Get-Date).AddDays(1).ToString("yyyy-MM-ddT00:00:00")
$url = "https://graph.microsoft.com/v1.0/me/calendarView?startDateTime=$today&endDateTime=$tomorrow"
Invoke-RestMethod -Uri $url -Headers $h
```

### List Upcoming Events (Next 7 Days)
```powershell
$start = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
$end = (Get-Date).AddDays(7).ToString("yyyy-MM-ddTHH:mm:ss")
$url = "https://graph.microsoft.com/v1.0/me/calendarView?startDateTime=$start&endDateTime=$end&`$orderby=start/dateTime"
Invoke-RestMethod -Uri $url -Headers $h
```

### Get All Calendars
```powershell
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/calendars" -Headers $h
```

### Get Specific Event
```powershell
$eventId = "event-id-here"
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/events/$eventId" -Headers $h
```

### Create Calendar Event
```powershell
$event = @{
    subject = "Team Meeting"
    start = @{
        dateTime = "2026-01-07T14:00:00"
        timeZone = "Eastern Standard Time"
    }
    end = @{
        dateTime = "2026-01-07T15:00:00"
        timeZone = "Eastern Standard Time"
    }
    body = @{
        contentType = "HTML"
        content = "Meeting agenda here"
    }
    location = @{
        displayName = "Conference Room A"
    }
    attendees = @(
        @{
            emailAddress = @{ address = "colleague@company.com"; name = "Colleague" }
            type = "required"
        }
    )
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/events" `
    -Method POST -Headers $h -Body $event -ContentType "application/json"
```

### Create Teams Meeting
```powershell
$meeting = @{
    subject = "Teams Video Call"
    start = @{ dateTime = "2026-01-07T14:00:00"; timeZone = "Eastern Standard Time" }
    end = @{ dateTime = "2026-01-07T15:00:00"; timeZone = "Eastern Standard Time" }
    isOnlineMeeting = $true
    onlineMeetingProvider = "teamsForBusiness"
} | ConvertTo-Json -Depth 3

$response = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/events" `
    -Method POST -Headers $h -Body $meeting -ContentType "application/json"

# Get the Teams join link
$response.onlineMeeting.joinUrl
```

### Update Event
```powershell
$eventId = "event-id"
$update = @{ subject = "Updated Meeting Title" } | ConvertTo-Json
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/events/$eventId" `
    -Method PATCH -Headers $h -Body $update -ContentType "application/json"
```

### Delete Event
```powershell
$eventId = "event-id"
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/events/$eventId" `
    -Method DELETE -Headers $h
```

### Find Free/Busy Time
```powershell
$body = @{
    schedules = @("user1@company.com", "user2@company.com")
    startTime = @{ dateTime = "2026-01-07T09:00:00"; timeZone = "Eastern Standard Time" }
    endTime = @{ dateTime = "2026-01-07T18:00:00"; timeZone = "Eastern Standard Time" }
    availabilityViewInterval = 30
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/calendar/getSchedule" `
    -Method POST -Headers $h -Body $body -ContentType "application/json"
```

## Pagination

Results are paginated. Check `@odata.nextLink` for more results:
```powershell
$response = Invoke-RestMethod -Uri $url -Headers $h
if ($response.'@odata.nextLink') {
    $nextPage = Invoke-RestMethod -Uri $response.'@odata.nextLink' -Headers $h
}
```

## Filtering Messages by Date

```powershell
$startDate = "2026-01-01T00:00:00Z"
$url = "https://graph.microsoft.com/v1.0/me/chats/$chatId/messages?`$filter=createdDateTime ge $startDate&`$orderby=createdDateTime desc"
```

## Error Handling

| Code | Meaning |
|------|---------|
| 401 | Token expired/invalid |
| 403 | Permission denied |
| 404 | Resource not found |
| 429 | Rate limited (retry after header) |

## Token Setup Guide

1. Register app at https://entra.microsoft.com (Azure Portal > App Registrations)
2. Add redirect URI: `http://localhost`
3. Under API Permissions, add Microsoft Graph delegated permissions
4. Generate auth URL and complete OAuth flow
5. Store access token in `$env:MS_GRAPH_TOKEN`

## Refresh Token

Tokens expire (~1 hour). Use refresh token for new access:
```powershell
$body = @{
    client_id = $clientId
    grant_type = "refresh_token"
    refresh_token = $env:MS_GRAPH_REFRESH_TOKEN
    scope = "Chat.Read Chat.ReadWrite ChatMessage.Send Presence.Read offline_access"
}
$response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token" `
    -Method POST -Body $body
$env:MS_GRAPH_TOKEN = $response.access_token
```

## Permissions Requiring Admin Consent (NOT Available)

These require IT admin approval:
- ChannelMessage.Read.All (read all channel messages)
- Chat.Read.All (read all chats)
- Group.Read.All (read all groups)
- TeamMember.Read.All (read team members)
- Channel.Create/Delete (manage channels)
