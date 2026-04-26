---
name: now-leadershipgroup
description: V1.1 - Expert in Now Leadership Group business, website, tech stack, infrastructure, accounts, and email/domain management. Use when working on NLG website, managing accounts, troubleshooting email/DNS, or planning infrastructure changes.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the now-leadershipgroup directory (path contains 'now-leadershipgroup'), verify that history logging occurred.
            
            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp (obtained via `Get-Date -Format "HH:mm"` command, never guessed)
            
            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if now-leadershipgroup was used (check if any files in now-leadershipgroup directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in now-leadershipgroup directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}\n\nCRITICAL: Get the current time using `Get-Date -Format \"HH:mm\"` command - never guess the timestamp."}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# Now Leadership Group (NLG)

Expert knowledge base for Rebecca Hemmer's leadership consulting business — covering the website, tech stack, infrastructure, accounts, email, DNS, and all tooling.

## Business Overview

| Field | Value |
|-------|-------|
| **Business** | Now Leadership Group |
| **Owner** | Rebecca Hemmer |
| **Website** | <https://nowleadershipgroup.com> |
| **Domain** | nowleadershipgroup.com (registered at GoDaddy, DNS at Cloudflare) |
| **Services** | Strategic Advising, Executive Coaching, Leadership Development |
| **Target Audience** | Organizations seeking leadership consulting and development |
| **Tagline** | Leadership consulting and organizational development |

### Services

| Service | Route | Description |
|---------|-------|-------------|
| Strategic Advising | `/advising` | Goal, Role, and Team clarity practices |
| Executive Coaching | `/coaching` | Architecture of Talent, Prioritization & Focus, Strategic Versatility, Coach's Boundary |
| Leadership Development | `/developing` | Emerging Leaders, Strategic Leaders, Enterprise Leaders |

### Team

- **Rebecca Hemmer** — Founder/Principal (`rebecca@hemmer.us`, `rebecca@nowleadershipgroup.com`)
- **Kerry Edwards** — Team member

## Repository

| Field | Value |
|-------|-------|
| **Path** | `D:\github\hemsoft\now-leadership-group` |
| **GitHub** | `HemSoft/now-leadership-group` (private) |
| **Git Remote** | `git@github-personal1:HemSoft/now-leadership-group.git` |

## Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| **Framework** | Next.js | 16.x |
| **UI Library** | React | 19 |
| **Language** | TypeScript | 5.x |
| **Styling** | Tailwind CSS | 4.x |
| **Components** | shadcn/ui (New York style, neutral palette) | — |
| **Animation** | Motion (Framer Motion) | — |
| **Icons** | Lucide React | — |
| **Class Utils** | clsx + tailwind-merge (via `cn()` helper) | — |
| **Package Manager** | Bun | — |
| **Linting** | ESLint (Next.js + TypeScript) | — |
| **Build Output** | Static export (`output: "export"`) | — |

### Brand Colors

| Token | Value | Usage |
|-------|-------|-------|
| `--brand-navy` | `#2F3772` | Primary text, backgrounds |
| `--brand-deep` | `#424277` | Secondary navy |
| `--brand-teal` | `#38B9C5` | Accent, CTAs |
| `--brand-teal-light` | `#9FEBDD` | Light accent |
| `--brand-bg` | `#F1F1F1` | Background |

### Fonts

- **Display** (headings): Montserrat
- **Body** (sans): Open Sans

### Design Rules

- **No section badges/pills** — do not use the `label` prop on `SectionHeading` components
- Dark mode supported via `.dark` class

## Project Structure

```text
src/
├── app/
│   ├── layout.tsx              # Root layout (metadata, fonts, schema.org JSON-LD)
│   ├── page.tsx                # Homepage
│   ├── globals.css             # Global styles + CSS variables + Tailwind theme
│   ├── advising/               # Strategic Advising page
│   ├── coaching/               # Executive Coaching page
│   ├── contact/                # Contact page with form
│   ├── developing/             # Leadership Development page
│   ├── perspective/            # Perspective page
│   ├── privacy/                # Privacy Policy page
│   ├── services/               # Services overview page
│   └── team/                   # Team bios page
├── components/
│   ├── hero.tsx                # Animated hero section
│   ├── navbar.tsx              # Fixed header nav (desktop + mobile)
│   ├── footer.tsx              # Footer with branding + links
│   ├── page-hero.tsx           # Reusable page header
│   ├── section.tsx             # Section wrapper
│   ├── dialogue-cta.tsx        # Call-to-action dialogue
│   ├── features.tsx            # Features showcase
│   ├── flip-card.tsx           # Interactive flip card (coaching)
│   └── ui/button.tsx           # shadcn/ui Button (CVA variants)
└── lib/
    └── utils.ts                # cn() helper
workers/
└── contact-form/               # Cloudflare Worker for contact form email
    ├── src/index.ts
    └── wrangler.toml
```

## Development Commands

```bash
# Website
bun install                     # Install dependencies
bun run dev                     # Dev server (port 3000)
bun run build                   # Production build (static export)
bun run lint                    # ESLint
bun run start                   # Start production server

# Contact Form Worker
cd workers/contact-form
bun install && bun run dev      # Local worker development
bun run deploy                  # Deploy to Cloudflare

# Vercel Deployment
bunx vercel --prod --yes        # Deploy to production
```

## Infrastructure & Accounts

### Account Inventory

| Service | Account | Purpose |
|---------|---------|---------|
| **Cloudflare** | `fphemmer@gmail.com` (Free plan) | DNS for nowleadershipgroup.com, Email Routing, Workers |
| **Vercel** | HemSoft team (`team_v5nrX8yNM2ZpAJMlqTMjqjvX`) | Website hosting & deployment |
| **GoDaddy** | — | Domain registration for nowleadershipgroup.com |
| **Network Solutions** | Account #119555933 (Franz Hemmer) | hemmer.us domain + Deluxe Email (migrating away) |
| **GitHub** | HemSoft org | Source code repository (private) |

### Vercel Deployment

| Setting | Value |
|---------|-------|
| Project ID | `prj_eEtkPEkBW5Lo8fQQCiLixuoIFiho` |
| Team/Org ID | `team_v5nrX8yNM2ZpAJMlqTMjqjvX` |
| Vercel URL | `now-leadership-group.vercel.app` |
| Custom Domains | `nowleadershipgroup.com`, `www.nowleadershipgroup.com` |
| Build | Static export, auto-deploy from GitHub |
| HSTS | `max-age=63072000` (~2 years) |

### Cloudflare Workers

| Worker | URL | Purpose |
|--------|-----|---------|
| `nlg-contact-form` | `https://nlg-contact-form.nlg.workers.dev` | Contact form → email via Cloudflare Email Routing |

- Binding: `SEND_EMAIL` → Cloudflare Email Routing
- Destination: `rebecca@hemmer.us`
- From: `website@nowleadershipgroup.com`
- CORS: `nowleadershipgroup.com`, `www.nowleadershipgroup.com`, `localhost:3000`

### Contact Form Specification

**Fields:** First Name (req), Last Name (req), Email (req), Organization (opt), Message (req), Website (honeypot)

**States:** idle → sending → success/error

**Security:** CORS enforcement, honeypot bot detection, input sanitization (newline stripping, length truncation), email validation

## DNS & Email

### nowleadershipgroup.com DNS (at Cloudflare)

| Type | Name | Value |
|------|------|-------|
| A | @ | Cloudflare proxy → Vercel |
| CNAME | www | Proxied → `cname.vercel-dns.com` |
| MX | @ | Cloudflare Email Routing (route1/2/3.mx.cloudflare.net) |
| TXT | @ (SPF) | `v=spf1 include:_spf.mx.cloudflare.net ip4:66.96.128.0/18 ~all` |
| TXT | _dmarc | `v=DMARC1; p=none; rua=mailto:rebecca@nowleadershipgroup.com` |
| TXT | cf2024-1._domainkey | Cloudflare DKIM key (2048-bit RSA) |

### hemmer.us DNS (at Network Solutions — migrating to Cloudflare)

| Type | Name | Value |
|------|------|-------|
| A | @ | `216.198.79.1` (Vercel — hemmer.us site) |
| CNAME | www | Vercel DNS |
| CNAME | dashboard | Vercel DNS (HemSoft Dashboard) |
| MX | @ | `mx.hemmer.us` (Network Solutions email) |
| MX | send.updates | `feedback-smtp.us-east-1.amazonses.com` (Amazon SES) |
| TXT | @ (SPF) | `v=spf1 ip4:66.96.128.0/18 include:websitewelcome.com ~all` |
| TXT | _dmarc | `v=DMARC1; p=none; rua=mailto:rebecca@hemmer.us,mailto:franz@hemmer.us` |
| CNAME | dkim._domainkey | `cur.dkim.v.eigmail.net` (Network Solutions DKIM — broken on SMTP) |

### Email Addresses

| Address | Domain | Type | Notes |
|---------|--------|------|-------|
| `rebecca@hemmer.us` | hemmer.us | Mailbox | Primary, Network Solutions (397.5/512 MB) |
| `franz@hemmer.us` | hemmer.us | Mailbox | Network Solutions (460.5/512 MB) |
| `rebecca.online@hemmer.us` | hemmer.us | Forward | Forward only |
| `contact@hemmer.us` | hemmer.us | Unknown | Referenced on hemmer.us site footer |
| `rebecca@nowleadershipgroup.com` | NLG | Routed alias | Cloudflare → <rebecca@hemmer.us> |
| `info@nowleadershipgroup.com` | NLG | Unknown | Referenced on NLG site footer |
| `website@nowleadershipgroup.com` | NLG | Sender identity | Contact form worker From address |

## Email Deliverability Crisis

### The Core Problem

Rebecca's outbound email is **unreliable**. She sends as `rebecca@nowleadershipgroup.com` (her business identity) from her `rebecca@hemmer.us` mailbox. Some recipients receive her email fine; others never see it or it lands in spam. This is actively hurting her business.

### Why It Happens — Technical Root Cause

The problem is a **confirmed platform bug at Network Solutions** (ticket E-502096, escalated Apr 8, 2026):

| Sending Method | SPF | DKIM | DMARC | Result |
|----------------|-----|------|-------|--------|
| Network Solutions **webmail** | ✅ PASS | ✅ PASS | ✅ PASS | Works reliably |
| iPhone/Outlook via **SMTP** | ✅ PASS | ❌ ABSENT | ⚠️ PASS (SPF only) | Inconsistent delivery |

Network Solutions confirmed their **SMTP relay does not attach DKIM signatures** — only their webmail system does. When Rebecca sends from her iPhone or Outlook, the email goes through their SMTP infrastructure (`cmsmtp` → `cloudfilter.net`) which simply does not sign DKIM. This is not a misconfiguration; it is a platform limitation with **no ETA for a fix**.

### Why Some Recipients Get It and Others Don't

When Rebecca sends as `rebecca@nowleadershipgroup.com` from her hemmer.us mailbox via SMTP:

1. **SPF check** — The receiving server checks if the sending IP is authorized for `nowleadershipgroup.com`. The NLG SPF record includes Network Solutions' IP range (`ip4:66.96.128.0/18`), so SPF **passes**.
2. **DKIM check** — The receiving server looks for a DKIM signature header. There is **none** (Network Solutions SMTP doesn't sign). DKIM **fails/absent**.
3. **DMARC check** — DMARC requires either SPF or DKIM to pass **and align** with the From domain. SPF passes for `hemmer.us` but the From header says `nowleadershipgroup.com` — **misaligned**. DKIM is absent. So DMARC **may fail** depending on how strict the receiving server is.

**Result by recipient mail provider:**

| Recipient Provider | Likely Outcome | Why |
|--------------------|----------------|-----|
| **Gmail** | Usually delivers (inbox or spam) | Lenient with `p=none` DMARC; SPF pass gives partial credit |
| **Microsoft 365/Outlook.com** | Often spam or rejected | Stricter DMARC evaluation; missing DKIM heavily penalized |
| **Yahoo/AOL** | Often spam or rejected | Strict DMARC enforcement since 2024 |
| **Corporate mail servers** | Unpredictable | Depends on admin policy; many block missing DKIM |

### Real-World Impact on Rebecca

- Emails to potential clients may never arrive
- Follow-ups after coaching sessions silently disappear
- No bounce-back notification — Rebecca has no idea the email didn't land
- Forces workaround of using webmail (poor UX on mobile)
- Undermines professional credibility of the business

### Why DMARC Can't Be Tightened

DMARC is stuck at `p=none` (monitor mode) for both domains. Tightening to `p=quarantine` or `p=reject` would cause Rebecca's own SMTP-sent emails to be **quarantined or rejected** by receiving servers, since they lack DKIM. We'd be blocking our own legitimate mail.

### Evidence on File

- **Ticket E-502096** — Network Solutions escalation confirming the bug (`docs/E-502096.md` in repo)
- **Gmail "Show Original"** from Rebecca's iPhone (Mar 31, 2026) — SPF PASS, DKIM ABSENT
- **Network Solutions webmail test** (Apr 8, 2026) — SPF PASS, DKIM PASS (proves webmail works, SMTP doesn't)
- **Network Solutions response** — "DKIM signing is built directly into the webmail system... our system is mainly configured to sign those internally generated webmail emails"

## Game Plans for Fixing Email

### Game Plan A: Google Workspace Migration (Recommended — Already Planned)

**Timeline:** Before July 2, 2026 (Network Solutions renewal deadline)

**What it fixes:** Everything. Google Workspace signs DKIM on ALL sending paths — Gmail web, iPhone, Outlook, any SMTP client. Rebecca can send as `rebecca@nowleadershipgroup.com` with proper DKIM alignment from any device.

**Steps:** See [Active Migration Plan](#active-migration-plan) below (7 phases).

**Pros:**

- Permanent fix for DKIM on all paths
- 30 GB storage per user (vs 512 MB now)
- Google-grade spam filtering
- Calendar, Drive included
- Familiar Gmail interface
- Can tighten DMARC to `p=reject` after migration

**Cons:**

- $14/mo (2 users × $7)
- Requires careful DNS migration
- Multiple devices need reconfiguration
- Contact form worker needs adaptation (Cloudflare Email Routing binding may break)

### Game Plan B: Immediate Workaround — Use Webmail Only

**Timeline:** Now (zero effort)

**What it fixes:** DKIM passes when sending from Network Solutions webmail.

**How:** Rebecca uses `https://webmail.hemmer.us` or the Network Solutions webmail URL instead of iPhone Mail / Outlook for business email.

**Pros:** Works today, no cost, no migration

**Cons:** Terrible mobile UX, not sustainable for a business professional

### Game Plan C: Cloudflare Email Routing + SMTP Relay (Interim)

**Timeline:** Could implement in 1-2 sessions

**What it fixes:** Outbound email authentication for NLG domain specifically.

**How:**

1. Set up a third-party transactional email service (Resend, SendGrid, or Mailgun — most have free tiers)
2. Configure Rebecca's mail client to use the relay's SMTP server for outbound `@nowleadershipgroup.com` mail
3. The relay signs DKIM with NLG's domain key
4. Inbound still routes through Cloudflare → <rebecca@hemmer.us>

**Pros:** Fixes NLG outbound without full migration; can be done quickly

**Cons:**

- Extra service to manage
- Doesn't fix hemmer.us DKIM (only NLG domain)
- Still need Google Workspace migration eventually
- Free tiers have sending limits

### Game Plan D: Fast-Track DNS to Cloudflare (De-risks Migration)

**Timeline:** 1 session + 24-48hr propagation

**What it fixes:** Gets hemmer.us DNS under our control at Cloudflare, de-risking future changes.

**How:** Execute Phase 2 of the migration plan now — move hemmer.us nameservers from Network Solutions to Cloudflare. Email stays at Network Solutions (MX unchanged), but we gain:

- Faster DNS changes when we're ready for MX cutover
- Single dashboard for both domains
- Ability to add/modify records instantly

**Pros:** Low risk, high value prep step; no email disruption

**Cons:** Doesn't fix the DKIM problem itself (still Network Solutions SMTP)

### Recommended Sequence

1. **Now:** Game Plan B (webmail workaround for critical emails)
2. **Next session:** Game Plan D (move hemmer.us DNS to Cloudflare)
3. **May-June 2026:** Game Plan A (full Google Workspace migration)
4. **Post-migration:** Tighten DMARC to `p=reject` on both domains

## Active Migration Plan

**Goal:** Migrate hemmer.us email from Network Solutions to Google Workspace before **July 2, 2026** renewal deadline.

**Why:** Network Solutions DKIM is broken on SMTP (ticket E-502096) — cannot tighten DMARC beyond `p=none`.

**Target:** Google Workspace Business Starter ($7/user/mo, 2 users)

### Migration Phases

| Phase | Description | Risk | Status |
|-------|-------------|------|--------|
| 1 | Set up Google Workspace | 🟢 Low | Pending |
| 2 | Migrate hemmer.us DNS to Cloudflare | 🟡 Medium | Pending |
| 3 | Migrate email data (IMAP) | 🟢 Low | Pending |
| 4 | Switch MX records to Google | 🔴 High | Pending |
| 5 | Add nowleadershipgroup.com to Google Workspace | 🟡 Medium | Pending |
| 6 | Transfer hemmer.us domain to Cloudflare Registrar | 🟡 Medium | Pending |
| 7 | Decommission Network Solutions | 🟢 Low | Pending |

### Critical Deadlines

| Date | Event |
|------|-------|
| **July 2, 2026** | hemmer.us domain expiry + Network Solutions email renewal |
| Mid-June 2026 | Latest safe date to start domain transfer (15-day ICANN buffer) |

### Known Issues

- Network Solutions DKIM not signing on SMTP (ticket E-502096, no ETA)
- Contact form worker uses Cloudflare Email Routing `send_email` binding — may break when NLG email moves to Google Workspace
- Amazon SES subdomain (`send.updates.hemmer.us`) needs preservation or decommissioning
- `contact@hemmer.us` and `info@nowleadershipgroup.com` not explicitly routed

## Current TODO Status

| Status | Priority | Task |
|--------|----------|------|
| 📋 | Medium | Contact form end-to-end test |
| 📋 | Low | DMARC progression (p=none → quarantine → reject) |
| ✅ | — | 9 of 11 tasks completed (82%) |

## SEO Configuration

- **Schema.org JSON-LD** in root layout (Organization + Services)
- **OpenGraph** and **Twitter Card** tags on all pages
- `robots.txt` and `sitemap.xml` in public/
- Metadata API via Next.js `metadata` export

## ALWAYS: Log This Interaction

Append to `History/{YYYY-MM-DD}.md`:

```markdown
## HH:MM - Action Taken
One-line summary of what was done
```

**Get timestamp:** Run `Get-Date -Format "HH:mm"` — never guess.
