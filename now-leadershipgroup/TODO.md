# Now Leadership Group — TODO

| Status | Priority | Task | Notes |
|--------|----------|------|-------|
| 📋 | High | [Pre-flight: inventory and backup](#pre-flight-inventory-and-backup) | Must complete before any migration work |
| 📋 | High | [Phase 1: Sign up for Google Workspace](#phase-1-sign-up-for-google-workspace) | Business Starter, hemmer.us primary domain, 2 users |
| 📋 | High | [Phase 2: Migrate hemmer.us DNS to Cloudflare](#phase-2-migrate-hemmerus-dns-to-cloudflare) | Move nameservers, replicate all records exactly |
| 📋 | High | [Phase 3: Migrate email data](#phase-3-migrate-email-data) | IMAP copy from Network Solutions → Google (~1.1 GB) |
| 📋 | High | [Phase 4: MX cutover — the big switch](#phase-4-mx-cutover--the-big-switch) | Point both domains at Google, update all devices |
| 📋 | High | [Phase 5: Add nowleadershipgroup.com to Google Workspace](#phase-5-add-nowleadershipgroupcom-to-google-workspace) | Secondary domain, Rebecca sends as NLG natively |
| 📋 | Medium | [Phase 6: Transfer hemmer.us domain to Cloudflare Registrar](#phase-6-transfer-hemmerus-domain-to-cloudflare-registrar) | $6.50/yr, must start by mid-June |
| 📋 | Medium | [Phase 7: Decommission Network Solutions](#phase-7-decommission-network-solutions) | Cancel Deluxe Email before 7/2/2026 renewal |
| 📋 | Medium | [Phase 8: Harden DMARC](#phase-8-harden-dmarc) | p=none → quarantine → reject on both domains |
| 📋 | Medium | [Fix Rebecca's display name](#fix-rebeccas-display-name) | Currently shows "<rebecca@hemmer.us>" instead of "Rebecca Hemmer" |
| 📋 | Medium | [Contact form worker adaptation](#contact-form-worker-adaptation) | Cloudflare send_email binding may break after Phase 5 |
| 📋 | Medium | [Contact form end-to-end test](#contact-form-end-to-end-test) | Worker deployed, needs full send/receive verification |
| ✅ | High | Initialize GitHub repository | HemSoft/now-leadership-group, private (2026-02-19) |
| ✅ | High | Scaffold static website | Next.js 16 + Tailwind 4 + shadcn/ui + Motion + Bun (2026-02-19) |
| ✅ | High | Deploy to Vercel | Live at nowleadershipgroup.com (2026-02-20) |
| ✅ | High | Set up email routing | Cloudflare catch-all → <rebecca@hemmer.us> (2026-02-19) |
| ✅ | High | Coming Soon page | Logo + Coming Soon + email link (2026-02-20) |
| ✅ | High | Connect custom domain | DNS + SSL live, all 4 endpoints 200 OK (2026-02-20) |
| ✅ | Medium | SSL and production hardening | Vercel auto-SSL, DNS-only mode (2026-02-20) |
| ✅ | Low | Build website content | Full site with services, team, contact, FAQ (2026-02-21) |
| ✅ | Medium | Email deliverability (SPF/DKIM/DMARC) | DMARC fixed, SPF updated (2026-03-23) |

## Progress

**Completed: 9 / 21** (43%) — Pre-flight: 4/9 items resolved (2026-04-26)

**Hard deadline: July 2, 2026** — Network Solutions email renewal + hemmer.us domain expiry

---

## Why We're Doing This

Network Solutions confirmed (ticket E-502096) their SMTP relay **does not sign DKIM**. Rebecca's outbound email as `rebecca@nowleadershipgroup.com` fails SPF alignment, has no DKIM, and fails DMARC. Header analysis (Apr 26, 2026) confirmed: SPF SoftFail, DKIM None, DMARC Fail, compauth=none. Email delivers to some recipients by luck (lenient policies) but silently fails for others.

**This is not fixable at Network Solutions. The platform doesn't support it.**

---

## Account Inventory

| Person | Gmail (current) | hemmer.us (migrating from) | NLG (target sending identity) |
|--------|-----------------|----------------------------|-------------------------------|
| Franz Hemmer | `fphemmer@gmail.com` | `franz@hemmer.us` | — |
| Rebecca Hemmer | `rebeccahemmernow@gmail.com` | `rebecca@hemmer.us` | `rebecca@nowleadershipgroup.com` |

| Service | Account | Role |
|---------|---------|------|
| Network Solutions | #119555933 (Franz Hemmer) | hemmer.us domain + email (decommissioning) |
| Cloudflare | `fphemmer@gmail.com` | DNS for nowleadershipgroup.com, Email Routing, Workers |
| GoDaddy | — | Domain registration for nowleadershipgroup.com |
| Vercel | HemSoft team | Website hosting |

---

## Remaining Items

### Pre-flight: inventory and backup

Must complete before starting Phase 1.

- [ ] Inventory ALL devices using hemmer.us email (Rebecca's iPhone, Franz's phone, Outlook desktop, other clients)
- [ ] Inventory all "Send as" configurations — Rebecca sends as `rebecca@nowleadershipgroup.com` from Outlook
- [ ] Back up all email from Network Solutions (IMAP download to local archive)
- [ ] Note any email filters/rules configured at Network Solutions or in email clients
- [x] Check hemmer.us domain lock status *(checked 2026-04-26)*
  - **Status: LOCKED** (`clientTransferProhibited`) — must unlock before Phase 6
  - **Registrar: Domain.com, LLC** (Network Solutions family — admin may be at domain.com portal)
  - **Expiry: 2026-07-02** confirmed
  - **NS: ns1.domain.com, ns2.domain.com** (Network Solutions/Domain.com)
- [x] Decide: annual billing ($7/user/mo) or monthly ($8.40/user/mo) → **Annual ($7/user/mo)** — saves ~$34/yr, committed to migration *(decided 2026-04-26)*
- [x] Decide: keep catch-all for hemmer.us? → **No** — create explicit aliases only (`contact@hemmer.us`, etc.), reduces spam *(decided 2026-04-26)*
- [x] Decide: is `rebecca.online@hemmer.us` still needed? → **No, retire it** — not referenced in any active workflows *(decided 2026-04-26)*
- [ ] Decide: decommission Amazon SES subdomain (`send.updates.hemmer.us`) or preserve?
  - ⚠️ **Needs investigation** — MX record still active (`feedback-smtp.us-east-1.amazonses.com`). Ask Rebecca/Franz if anything sends email via this subdomain (newsletters, notifications, etc.)

---

### Phase 1: Sign up for Google Workspace

**Risk:** 🟢 Low — no changes to live systems

- [ ] Sign up at [workspace.google.com](https://workspace.google.com) — Business Starter plan
- [ ] Use `hemmer.us` as the primary domain
- [ ] Create user: `franz@hemmer.us`
- [ ] Create user: `rebecca@hemmer.us`
- [ ] **DO NOT verify domain yet** — we verify after DNS moves to Cloudflare (Phase 2)
- [ ] Note the DNS records Google provides (MX, SPF, DKIM, verification TXT)

**Google will provide:**

| Record | Value |
|--------|-------|
| MX (5 records) | `aspmx.l.google.com` (pri 1), `alt1-4.aspmx.l.google.com` (pri 5/10) |
| SPF | `v=spf1 include:_spf.google.com ~all` |
| DKIM | TXT record with Google's public key |
| Verification | `google-site-verification=XXXXX` TXT record |

---

### Phase 2: Migrate hemmer.us DNS to Cloudflare

**Risk:** 🟡 Medium — DNS change affects all services, but we replicate records exactly

- [ ] In Cloudflare: add `hemmer.us` as a new site (Free plan)
- [ ] Cloudflare will scan and import existing DNS records
- [ ] **Verify ALL records imported correctly** — compare against this table:

| Type | Name | Value | Critical? |
|------|------|-------|-----------|
| A | @ | `216.198.79.1` | ✅ hemmer.us website (Vercel) |
| CNAME | www | Vercel DNS | ✅ <www.hemmer.us> |
| CNAME | dashboard | Vercel DNS | ✅ dashboard.hemmer.us |
| MX | @ | `mx.hemmer.us` (pri 30) | ✅ Keep — email still at NS during transition |
| MX | send.updates | `feedback-smtp.us-east-1.amazonses.com` | ⚠️ Amazon SES subdomain |
| TXT | @ (SPF) | `v=spf1 ip4:66.96.128.0/18 include:websitewelcome.com ~all` | ✅ Keep for now |
| TXT | _dmarc | `v=DMARC1; p=none; rua=mailto:rebecca@hemmer.us,mailto:franz@hemmer.us` | ✅ |
| CNAME | dkim._domainkey | `cur.dkim.v.eigmail.net` | Keep (broken but harmless) |

- [ ] At Network Solutions: change nameservers to Cloudflare's assigned pair
- [ ] Wait for propagation: `nslookup -type=NS hemmer.us 1.1.1.1`
- [ ] **Test:** Send email to `franz@hemmer.us` and `rebecca@hemmer.us` — should still arrive at Network Solutions
- [ ] **Test:** Verify `hemmer.us`, `www.hemmer.us`, `dashboard.hemmer.us` all load correctly

---

### Phase 3: Migrate email data

**Risk:** 🟢 Low — read-only copy, doesn't affect live email

- [ ] In Google Workspace Admin Console → Data Migration
- [ ] Set up IMAP migration from Network Solutions:
  - Source: IMAP, `mail.hemmer.us`, port 993, SSL
  - `franz@hemmer.us` → `franz@hemmer.us`
  - `rebecca@hemmer.us` → `rebecca@hemmer.us`
- [ ] Start migration, monitor progress (~1.1 GB total: Franz 460 MB + Rebecca 397 MB)
- [ ] Verify email appears in Gmail (spot-check old emails in both accounts)
- [ ] Set up catch-all route in Google Workspace Admin (if keeping catch-all behavior)
- [ ] Create `rebecca.online@hemmer.us` as alias for `rebecca@hemmer.us` (if still needed)
- [ ] Create `contact@hemmer.us` as alias for the appropriate user (referenced on hemmer.us site footer)
- [ ] **DO NOT switch MX records yet** — both systems now have the email

---

### Phase 4: MX cutover — the big switch

**Risk:** 🔴 High — email stops going to Network Solutions, starts going to Google
**Best time:** Friday evening or weekend morning (lowest volume)

#### Step 4a: DNS changes in Cloudflare

- [ ] Add Google domain verification TXT record
- [ ] Verify domain in Google Workspace Admin Console
- [ ] **Replace MX records:**

| Action | Old | New |
|--------|-----|-----|
| Delete | `mx.hemmer.us` (pri 30) | — |
| Add | — | `aspmx.l.google.com` (pri 1) |
| Add | — | `alt1.aspmx.l.google.com` (pri 5) |
| Add | — | `alt2.aspmx.l.google.com` (pri 5) |
| Add | — | `alt3.aspmx.l.google.com` (pri 10) |
| Add | — | `alt4.aspmx.l.google.com` (pri 10) |

- [ ] **Replace SPF:** `v=spf1 include:_spf.google.com ~all`
- [ ] **Add Google DKIM record** (from Admin → Gmail → Authenticate Email)
- [ ] **Delete old Network Solutions DKIM** (`dkim._domainkey` CNAME)
- [ ] **Update DMARC** (keep `p=none` during transition): `v=DMARC1; p=none; rua=mailto:franz@hemmer.us,mailto:rebecca@hemmer.us`

#### Step 4b: Enable DKIM signing

- [ ] Google Workspace Admin → Apps → Gmail → Authenticate Email
- [ ] Generate 2048-bit DKIM key for `hemmer.us`
- [ ] After DNS propagation, click "Start Authentication"
- [ ] **Verify:** Send test from Gmail as `franz@hemmer.us` → check "Show original" → DKIM PASS

#### Step 4c: Update email clients

- [ ] **Rebecca's iPhone:** Remove old hemmer.us account → Add Google account → Sign in as `rebecca@hemmer.us`
- [ ] **Franz's devices:** Remove old hemmer.us account → Add Google account → Sign in as `franz@hemmer.us`
- [ ] **Any other devices** (Outlook desktop, other phones)
- [ ] **Test send/receive from every device**

#### Step 4d: Verification

- [ ] Send FROM `franz@hemmer.us` (Gmail) TO personal Gmail → DKIM PASS ✅
- [ ] Send FROM `rebecca@hemmer.us` (iPhone) TO personal Gmail → DKIM PASS ✅
- [ ] Send TO `franz@hemmer.us` from external → arrives in Gmail ✅
- [ ] Send TO `rebecca@hemmer.us` from external → arrives in Gmail ✅
- [ ] Check: `nslookup -type=MX hemmer.us 1.1.1.1` → Google servers ✅
- [ ] Check: `nslookup -type=TXT hemmer.us 1.1.1.1` → Google SPF ✅

**Rollback:** If email breaks, change MX back to `mx.hemmer.us` in Cloudflare (5-min TTL). Network Solutions mailboxes still exist.

---

### Phase 5: Add nowleadershipgroup.com to Google Workspace

**Risk:** 🟡 Medium — changes email routing for the business domain
**This is the phase that fixes Rebecca's deliverability problem.**

- [ ] Google Workspace Admin → Add `nowleadershipgroup.com` as secondary domain
- [ ] Add `rebecca@nowleadershipgroup.com` as alias for `rebecca@hemmer.us`
- [ ] Add `info@nowleadershipgroup.com` as alias (referenced on NLG site footer)
- [ ] In Cloudflare DNS for nowleadershipgroup.com:

| Action | Type | Name | Old Value | New Value |
|--------|------|------|-----------|-----------|
| Replace | MX | @ | Cloudflare Email Routing | Google MX (same 5 servers) |
| Replace | TXT | @ (SPF) | `...include:_spf.mx.cloudflare.net ip4:66.96.128.0/18 ~all` | `v=spf1 include:_spf.google.com ~all` |
| Add | TXT | google._domainkey | — | Google DKIM key for NLG |
| Delete | TXT | cf2024-1._domainkey | Cloudflare DKIM key | — |
| Keep | TXT | _dmarc | `p=none` | Same (update rua if desired) |

- [ ] **Disable Cloudflare Email Routing** for nowleadershipgroup.com
- [ ] **Test:** Send as `rebecca@nowleadershipgroup.com` from Gmail → DKIM PASS, DMARC PASS ✅
- [ ] **Test:** Receive at `rebecca@nowleadershipgroup.com` → arrives in Gmail ✅
- [ ] **Test:** Send to a Microsoft 365 recipient → delivered to inbox ✅
- [ ] Remove old "Send as" configuration from Rebecca's Outlook (no longer needed)

**Result:** Rebecca sends/receives as both `rebecca@hemmer.us` and `rebecca@nowleadershipgroup.com` from the same Gmail inbox. DKIM signs properly on ALL paths. The E-502096 problem is permanently solved.

---

### Phase 6: Transfer hemmer.us domain to Cloudflare Registrar

**Risk:** 🟡 Medium — domain transfer takes 5-7 days
**Must start by mid-June 2026** (hemmer.us expires July 2, 2026)

- [ ] At Network Solutions: unlock hemmer.us domain (remove `client transfer prohibited`)
- [ ] Get EPP/Auth code from Network Solutions
- [ ] At Cloudflare: initiate domain transfer ($6.50)
- [ ] Approve transfer via email
- [ ] Wait for transfer to complete (5-7 days)
- [ ] Verify domain appears in Cloudflare Registrar
- [ ] Verify all DNS records intact after transfer

---

### Phase 7: Decommission Network Solutions

**Risk:** 🟢 Low — must verify everything works first
**Do before July 2, 2026** (email renewal date)

- [ ] **Wait at least 1 week** after Phase 5 — confirm no email issues
- [ ] Download any remaining data from Network Solutions webmail
- [ ] Cancel Deluxe Email plan
- [ ] Close or let Network Solutions account go dormant

---

### Phase 8: Harden DMARC

**Risk:** 🟢 Low — gradual tightening with monitoring

After everything is stable on Google Workspace:

- [ ] Monitor DMARC reports for 2-4 weeks
- [ ] hemmer.us: `p=none` → `p=quarantine` (in Cloudflare DNS)
- [ ] nowleadershipgroup.com: `p=none` → `p=quarantine` (in Cloudflare DNS)
- [ ] After 2-4 more clean weeks: both → `p=reject`
- [ ] **Final state:** Both domains reject forged email, DKIM passes on every sending path

---

### Fix Rebecca's display name

Header analysis (Apr 26, 2026) revealed the From header shows:

```text
"rebecca@hemmer.us" <rebecca@nowleadershipgroup.com>
```

The display name is her email address instead of her actual name. Should be:

```text
"Rebecca Hemmer" <rebecca@nowleadershipgroup.com>
```

- [ ] After Phase 5, configure display name in Google Workspace Admin or Gmail settings
- [ ] Verify by sending test email and checking recipient's view

---

### Contact form worker adaptation

The NLG contact form worker (`nlg-contact-form`) uses Cloudflare's `send_email` binding. When Cloudflare Email Routing is disabled in Phase 5, this binding may stop working.

**Options (decide before Phase 5):**

1. Keep Cloudflare Email Routing active for the worker's sending path only (if Cloudflare supports this)
2. Switch worker to Google Workspace SMTP relay
3. Switch worker to Resend/SendGrid API (free tier sufficient)
4. Verify that `send_email` binding works independently of inbound email routing

- [ ] Test which option works
- [ ] Update worker code + wrangler.toml if needed
- [ ] Redeploy worker: `cd workers/contact-form && bun run deploy`

---

### Contact form end-to-end test

Worker (`nlg-contact-form`) is deployed at `https://nlg-contact-form.nlg.workers.dev`.

- [ ] Redeploy site: `bunx vercel --prod --yes`
- [ ] Submit test form → Worker receives → email arrives at `rebecca@hemmer.us`
- [ ] Optional: set up custom domain `api.nowleadershipgroup.com`

---

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Email loss during MX cutover | High | Migrate data first, keep NS mailboxes as fallback, cutover at low-traffic time |
| DNS propagation delay | Medium | Cloudflare has ~5 min TTL; allow 24-48hr buffer for ISP caches |
| Devices not updated after cutover | Medium | Inventory all devices in pre-flight, update same day as MX switch |
| Domain transfer rejected | Low | Ensure domain unlocked, EPP code correct, domain >60 days old |
| Contact form worker breaks | Medium | Test worker adaptation before Phase 5; have fallback sending method ready |
| hemmer.us domain expires during transfer | High | Start Phase 6 by mid-June (15-day ICANN buffer before July 2 expiry) |

---

## Timeline

| Phase | What | Depends On | Can Start |
|-------|------|------------|-----------|
| Pre-flight | Inventory, backup, decisions | Nothing | **Now** |
| Phase 1 | Google Workspace signup | Nothing | **Now** |
| Phase 2 | hemmer.us DNS → Cloudflare | Phase 1 | After Phase 1 |
| Phase 3 | Email data migration | Phase 1 | After Phase 1 |
| Phase 4 | MX cutover | Phases 2 + 3 | After both complete |
| Phase 5 | NLG domain → Google Workspace | Phase 4 verified | After Phase 4 |
| Phase 6 | Domain transfer to Cloudflare | Phase 5 verified | **By mid-June 2026** |
| Phase 7 | Cancel Network Solutions | Phase 6 complete | **Before July 2, 2026** |
| Phase 8 | DMARC hardening | Phase 7 | 2-4 weeks after Phase 7 |
