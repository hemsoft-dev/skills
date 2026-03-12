### \ud83d\udcac Slack Briefing

*Generated: 2026-03-11 22:49 | Date range: 2026-03-10 to 2026-03-11 | User: @fhemmer*

#### \ud83d\udcac Direct Messages (10)

- **[2026-03-11 11:46]** @Malia Paul: Maybe I'll just reach out to Ajith on slack instead of trying to corner him
- **[2026-03-11 11:28]** @Malia Paul: Dare I ask how that meeting went?
- **[2026-03-11 10:08]** @Malia Paul: I know. I am not sure why they keep scheduling it at a time when I clearly am booked. Also, I did talk to KJ about this group but Ajith is the decisio...
- **[2026-03-11 16:24]** @Michelle Barry: thank you
- **[2026-03-11 16:19]** @Michelle Barry: do you still use JetBrains ->dotultimate
- **[2026-03-11 16:02]** @Nick Peterson: I'm filling out the survey, need to focus :sweat_smile:
- **[2026-03-11 16:02]** @Nick Peterson: Thats MEEE
- **[2026-03-11 16:02]** @Nick Peterson: And I'm done, makes me wonder who else is getting slammed
- **[2026-03-11 16:01]** @Nick Peterson: Lmao Yes
- **[2026-03-11 08:01]** @Slack Skill Bot: :sunrise: _Morning Briefing — Wednesday, March 11th_ :clipboard: _Tasks_ _Timed:_ • 8:00 AM — Take morning meds • 9:00 AM — Prepare for presentation •...

#### \ud83d\udcc1 Channel Activity

**#platform** (21 messages)

- [2026-03-11 11:46] @Aaron Mundy: ooo. I see. so. I'll put that in the ticket, and reach out to ccops.
- [2026-03-11 11:45] @Trey Walters: Yes, but caveat that this is the intended behavior for target. We probably need to align on whether we are ok with that behavior for legacy. (when this was added there was no decision made to split th...
- [2026-03-11 11:44] @Aaron Mundy: Grabbing a screenshot now :smile:
- [2026-03-11 11:44] @Aaron Mundy: OR should the proxied user still be able to see, but not modify, the page?
- [2026-03-11 11:43] @Aaron Mundy: But should it show the 'not-allowed' url/page?
- [2026-03-11 11:43] @Trey Walters: Ahh, that permission is not marked as "readonly" because it allows data changes so it is not available to impersonated users.
- [2026-03-11 11:40] @Aaron Mundy: Impersonating is where we hit the issue though.
- [2026-03-11 11:08] @Trey Walters: The page is guarded by the editIPAllowList permission, which admins have. If the user proxy-ing is not an administrator, they would not have this permission. A workaround would be to impersonate an ad...
- [2026-03-11 11:00] @Aaron Mundy: :case_of_the_mundys:
- [2026-03-11 11:00] @Christopher LaGant: You're good! It's a Monday Wednesday

**#productivity-engineering-public** (15 messages)

- [2026-03-11 12:42] @Mike Toothaker: Invite sent. Thank you again for your help
- [2026-03-11 12:25] @Mike Toothaker: <@U01RRQXEEG5|Halterman> I think that we are going to shoot for tomorrow (3/12 ) at 9:30 AM ET, how much time do we need?
- [2026-03-11 12:13] @Mike Toothaker: <@U06TPNXQQ57|Bri Neuhoff> I will check with my team and send out an invite. Thank you very much for your help
- [2026-03-11 12:12] @Bryan Halterman: If you don't have a test suite setup, like unit tests or integration tests, we could edit the rule set for the project to not require the >80% test coverage on new code so that does not block. My cale...
- [2026-03-11 12:09] @Mike Toothaker: Thank you. I would appreciate that. What does your schedule look like? I would like to include <@U048SG3V1AA|p.kumar>, and possibly someone from our team in India, if there is going to need to be a te...
- [2026-03-11 12:06] @Bryan Halterman: your manager should be able to override the check and merge for now. Since this is code, it should be setup in sonarqube. I'm happy to schedule time and help you get that setup
- [2026-03-11 12:04] @Mike Toothaker: Is this something that can be remedied quickly or do we need to cancel our deployment and go through some kind of training/setup proocess?
- [2026-03-11 12:04] @Mike Toothaker: I am not sure what that means. We have tests that our team runs, but I think they are run from our QA person's local machine. I don't even see a project for this in SonarQube.
- [2026-03-11 12:01] @Bryan Halterman: it doesn't need to be a full deployment pipeline. You would just need to run the analyzer and publish the results. If you have test written you would want to run your test suite in the pipelines to re...
- [2026-03-11 11:59] @Mike Toothaker: I would love to setup a pipeline, but that is quite involved and would involve upgrades to the package on Webscale.

**#next-deployment** (12 messages)

- [2026-03-11 21:43] @Mike Toothaker: :rocket-shake: <http://Nurse.com|Nurse.com> EComm &amp; Education Deployment Complete
- [2026-03-11 21:17] @Mike Toothaker: :rocket-shake: <http://Nurse.com|Nurse.com> EComm &amp; Education Deployment Started <https://relias.atlassian.net/browse/CHM-5984>
- [2026-03-11 16:36] @Samuel Harris: <!here> Manual and Cypress automation verification for DE is completed successfully
- [2026-03-11 16:29] @Josh DiCristo: Good afternoon <https://relias-engineering.slack.com/admin/user_groups|@cloudengineers-sysadmins>! Can Snack Overflow please get some assistance with tomorrow night's CLS deployment? We have tickets t...
- [2026-03-11 16:22] @Clark Bonham: DE Deployment complete
- [2026-03-11 16:21] @Samuel Harris: <!here> Starting DE verification
- [2026-03-11 16:01] @Mark Earl: <!here> starting DE deployment
- [2026-03-11 13:29] @Clark Bonham: Looks like it's going now
- [2026-03-11 13:19] @Scott Burnette: hi <@U01FN6UP16C|Clark Bonham> would you be able to approve the MFE staging deployment gate here? <https://dev.azure.com/ReliasDevelopment/ReliasPlatform/_build/results?buildId=357555&view=logs&s=3502...
- [2026-03-11 10:48] @Charlotte Fowler: Instructions look simple enough, though I did have one question that I've included as a comment on the ticket.

**#relias-engineering** (9 messages)

- [2026-03-11 17:23] @Franz Hemmer: Another thing worth noting is switching to pnpm instead of npm - that would be a massive time and resource saver. I pitched this idea in the fall of last year and the estimated saving in time and reso...
- [2026-03-11 14:48] @John Martin: I'm not a developer or QA engineer, so most of these pipelines go way over my head; however, I had Sonnet and Opus 4.6 review the repo and generate a summary the other day when I was waiting on the AD...
- [2026-03-11 13:24] @Tyler Deal: Just not all the time which was an unfortunate realization for myself, too. :weary:
- [2026-03-11 13:23] @Tyler Deal: Yeah, I didn't mean to come across as totally devaluing. It will still be a timesaver under particular conditions.
- [2026-03-11 13:16] @India Evans: fair point, it should still cut down some compute time within a single pipeline run though
- [2026-03-11 12:54] @Tyler Deal: I think this is consistent with something I added in the Cypress pipelines <https://github.com/relias-engineering/rlms-website/commit/0bd2fe7f1d718af88c517f3d935a7b258afee775|recently>. I don't know h...
- [2026-03-11 12:46] @Kyle McDaniel: I would be honored to help out in anyway
- [2026-03-11 12:40] @Gray Anthony: Idk if I meet the requirements, but I'm happy to take a look!
- [2026-03-11 12:36] @India Evans: is there anyone particularly savvy with azure pipelines / passionate about making our rlms-website pipeline :sparkles: faster :sparkles: that can give feedback on some improvements I'm trying to make?...

**#dev-tribe** (3 messages)

- [2026-03-11 02:03] @Clark Bonham: set the channel topic: Fix Version for current monolith sprint work: 26.Q1.5 RPLAT Deployment Current monolith deployment: <#C0AKFMYKPED>
- [2026-03-11 02:02] @Clark Bonham: set the channel topic: Fix Version for current monolith sprint work: 26.Q1.5 RPLAT Deployment Current monolith deployment: <#C0AKFMYKPED> <#C0AGPL9AQ11>
- [2026-03-11 00:00] @Jason Smith: STG-US healthchecks are back up

**#ai-chapter** (3 messages)

- [2026-03-11 18:10] @Christian Mutaba: Interesting read on how AI adoption is impacting large tech companies in unexpected ways. Amazon reportedly linked several recent outages to AI-assisted code changes and is now requiring stronger over...
- [2026-03-11 17:14] @Franz Hemmer: 
- [2026-03-11 17:08] @Geo Rufino: A little moment of silence for edit mode...

---
*Mentions: 0 | DMs: 10 | Announcements: 0 | Channel Messages: 63 (across 6 channels) | Action Items: 0*
