---
name: relias
description: V1.2 - Expert in everything about Relias (the company), including HR policies, benefits, culture, organizational structure, and workplace procedures.
disable-model-invocation: true
compatibility: Requires docling for PDF/DOCX to Markdown conversion of HR documents
metadata:
  author: HemSoft Developments
  version: "1.2"
  document_location: HR/
---

# Relias

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Expert knowledge base for everything related to Relias - the company, its culture, policies, benefits, organizational structure, and employee-related information.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}

{One-line summary of what was done}
```

## Branding & Design Assets (assets/)

All company branding, logos, and design assets are stored in the `/assets` folder:

**Current Assets**:

- `relias-logo.png` - Relias organization official logo from GitHub (34 KB, PNG format)
  - Source: <https://github.com/relias-engineering>
  - Avatar URL: <https://avatars.githubusercontent.com/u/135147856?v=4>
  - Used for: Official company branding, documentation, presentations

This folder is the central location for all Relias design assets and can be expanded with:

- Brand guidelines and color palettes
- Official icon sets
- Approved templates
- Marketing assets
- Internal design resources

## Knowledge Base Structure

### HR Documents (HR/)

All HR-related documents are stored in the `HR/` subfolder as Markdown files converted from original PDF/DOCX formats using docling.

**Document Conversion Process**:

1. User provides PDF or DOCX HR document
2. Use docling skill to convert to Markdown
3. Save converted Markdown to `HR/{document-name}.md`
4. Original formats are not stored; only Markdown versions

**Document Types**:

- Employee handbooks
- Benefits guides
- Policy documents
- Onboarding materials
- Compliance training materials
- Organizational charts
- Company announcements

## Core Knowledge Areas

### 1. Company Overview

- Mission, vision, and values
- Company history and milestones
- Products and services
- Market position and industry focus

### 2. HR & Benefits

- Health insurance (medical, dental, vision)
- Retirement plans (401k, matching)
- Paid time off (PTO, holidays, sick leave)
- Parental leave policies
- Employee assistance programs
- Professional development and tuition reimbursement

### 3. Workplace Policies

- Code of conduct
- Remote work policies
- Hybrid work arrangements
- Expense reimbursement
- Travel policies
- Equipment and technology use

### 7. IT Resources

- **IT Help Desk**: <https://relias.atlassian.net/servicedesk/customer/portals>

#### Active IT Requests

**2026-01-28 - Slack Service Account Token Request**

**Ticket Number**: ITHC-20764

**Ticket URL**: <https://relias.atlassian.net/servicedesk/customer/portal/14/ITHC-20764?created=true>

**Subject**: Request for Service Account with Slack User Token for Relias Assistant

**Status**: Submitted

**Request Details**:

We need a Slack service account token for the Relias Assistant application that performs Slack message searches.

**Current Issue**:

The Slack search functionality currently uses a token created under my personal Slack credentials. This means the assistant can search and return messages from private channels I'm a member of. Since the assistant will be used by others, this creates a data exposure risk—users could potentially see messages from private channels they don't have access to.

**What We Need**:

A user token tied to a service account (e.g., <relias-assistant@relias.com> or similar) because Slack's Search API doesn't support bot tokens. This service account should:

- Only be a member of public channels (or a curated list of approved channels)
- Authenticate to a Slack App we control, generating an OAuth user token with search:read scope

**Why It Must Be a User Token**:

Due to Slack API limitations, the search.messages endpoint only accepts user tokens (xoxp-...)—bot tokens are explicitly rejected with a not_allowed_token_type error. Search results are always scoped to the authenticating user's channel membership, so we need a dedicated user account with controlled access rather than relying on an individual's credentials.

**Reference**: <https://github.com/slackapi/bolt-python/issues/539>

**2026-01-29 - [Subject to be added]**

**Ticket Number**: ITHC-20802

**Ticket URL**: <https://relias.atlassian.net/servicedesk/customer/portal/14/ITHC-20802?created=true>

**Subject**: [To be filled in]

**Status**: Submitted

**Request Details**:

[Details to be added]

### 4. Organizational Structure

- Departments and teams
- Reporting relationships
- Key leadership contacts
- Productivity Engineering team structure

### 5. Career Development

- Performance review processes
- Career pathing opportunities
- Training and certification programs
- Internal mobility

### 6. Culture & Values

- Company culture
- Diversity, equity, and inclusion initiatives
- Employee resource groups
- Social events and team building

## Usage Workflows

### Adding New HR Documents

When user provides a new HR document:

1. **Convert to Markdown**: Use docling skill

   ```bash
   docling {document-path} --to markdown --output HR/
   ```

2. **Verify Conversion**: Check output quality, table preservation, formatting

3. **Store in HR/**: Save as `HR/{document-name}.md`

4. **Update Knowledge**: Incorporate key information into this skill if frequently referenced

5. **Log Interaction**: Add entry to `History/{YYYY-MM-DD}.md`

### Answering Questions

When user asks about Relias-related topics:

1. **Search HR Documents**: Check `HR/` folder for relevant documents
2. **Extract Information**: Pull specific policies, benefits, or procedures
3. **Provide Context**: Include document source and section references
4. **Clarify Scope**: If information is not available, suggest which document might contain it

### Document Management

- **Versioning**: When updating documents, include date in filename (e.g., `employee-handbook-2026-01.md`)
- **Organization**: Group related documents by category if collection grows
- **Archiving**: Move outdated documents to `HR/archive/` subfolder

## Example Interactions

**Q**: "What's Relias's PTO policy?"
**A**: Check `HR/employee-handbook.md` for PTO section, extract policy details

**Q**: "How do I submit an expense report?"
**A**: Reference `HR/expense-policy.md` for step-by-step submission process

**Q**: "Who do I contact for benefits questions?"
**A**: Look up HR contacts in organizational documents

## Document Conversion Best Practices

When converting documents with docling:

- **Preserve Tables**: Ensure benefits tables, policy matrices remain structured
- **Maintain Hierarchy**: Keep section headings and numbering intact
- **Extract Links**: Preserve references to external resources
- **Handle Images**: Include organizational charts, diagrams where relevant
- **Verify Accuracy**: Spot-check converted content against original

## Current Document Inventory

*This section will be updated as documents are added to HR/*

- **2025-Relias-Employee-Handbook.md** - Complete employee handbook covering all HR policies, benefits, leave policies, compensation, and workplace guidelines
- **2026-Payroll-Calendar.md** - 2026 payroll schedule and holiday calendar
- **Anti-Harassment-Policy-FINAL.md** - Anti-harassment and workplace conduct policy
- **Caregiver-Leave-Policy.md** - Leave for family caregiving responsibilities
- **CINNAA.md** - Confidential information and non-disclosure agreement
- **Flexible-PTO-Policy.md** - Unlimited time off policy guidelines
- **Flexible-Work-Policy.md** - Remote and hybrid work arrangements
- **Flexible-Work-Policy-FAQ-for-Employees.md** - Common questions about flexible work arrangements
- **Parental-Leave-Policy.md** - Parental leave benefits and eligibility
- **Personal-Leave-Policy.md** - Personal leave of absence provisions
- **Sabbatical-Leave-Policy.md** - Detailed policy for 10-year tenure sabbatical leave benefit
- **Social-Media-Policy.md** - Social media usage and conduct guidelines

## Notes

- This skill grows organically as more Relias information is added
- Focus on accuracy - always cite document sources
- Respect confidentiality - only store documents explicitly provided by user
- Keep information current - update when policies change
