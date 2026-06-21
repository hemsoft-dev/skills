### \ud83d\udcac Slack Briefing

*Generated: 2026-04-14 22:48 | Date range: 2026-04-13 to 2026-04-14 | User: @fhemmer*

#### \ud83d\udd14 Direct @Mentions (1)

- **[2026-04-14 11:28] #ai-chapter** - @Jason Twichell: I agree! What I'd like to see is a standard directory (docs/context) in all of our repos that we can maintain through github actions (per <@U2XMZDPJ7|Franz>, <@U04T14A5U0G|jbuda>) and then instruct th...

#### \ud83d\udcac Direct Messages (7)

- **[2026-04-14 10:48]** @Gray Anthony: We have a server stood up here and according to the ADR, all services should be using it :sweat_smile:
- **[2026-04-14 10:47]** @Gray Anthony: Yes.
- **[2026-04-14 10:42]** @Jira:
- **[2026-04-14 10:42]** @Jira:
- **[2026-04-14 10:42]** @Jira:
- **[2026-04-14 10:42]** @Jira:
- **[2026-04-14 08:01]** @Slack Skill Bot: :sunrise: *Morning Briefing — Tuesday, April 14th* :clipboard: *Tasks* Overdue: • 10:00 PM (Apr 12) — Use the Diary skill to record today's diary entr...

#### \ud83d\udce2 Announcements (8)

- **[2026-04-14 15:12] #courses** - @Shilpa Ambardekar: So I ran the pipelines and seeing expected failures and few passing tests. Results are in cypress channel.
- **[2026-04-14 13:42] #policies-procedures-cypress** - @Drazen Jovanovic: added an integration to this channel: <<https://relias-engineering.slack.com/services/B0ASVBQMBPC|Cypress> Bot>
- **[2026-04-14 12:49] #nds** - @Shane Neiman: <@U01QFKJFMK7|Vritti Gautam> For tomorrow, I have messaged in the public channels for the teams with tickets in the fix version.
- **[2026-04-14 12:43] #hg-stormbreakers-public** - @Shane Neiman: Hello! The NDS has been deployed to staging and Stormbreakers has five tickets in the deployment. Please reach out if you have questions or concerns! Fix Version: <<https://relias.atlassian.net/projects/RPLAT/versions/45799/tab/release-report-all-issu>...
- **[2026-04-14 12:41] #hg-titans** - @Shane Neiman: Hello! The NDS has been deployed to staging and Titans has one ticket in the deployment. Please reach out if you have questions or concerns! Fix Version: <https://relias.atlassian.net/projects/RPLAT/versions/45799/tab/release-report-all-issues> NDS C...
- **[2026-04-14 12:41] #wizar-dry-public** - @Shane Neiman: Hello! The NDS has been deployed to staging and Wizardry has two tickets in the deployment. Please reach out if you have questions or concerns! Fix Version: <https://relias.atlassian.net/projects/RPLAT/versions/45799/tab/release-report-all-issues> ND...
- **[2026-04-14 09:22] #cls-deployments** - @Nathan Seith:
- **[2026-04-14 08:47] #cls-deployments** - @Josh DiCristo: Had an issue with the deployment (posted in the channel) so staging has not yet been deployed

#### \ud83d\udcc1 Channel Activity

**#productivity-engineering-public** (18 messages)

- [2026-04-14 18:34] @Tyler Deal: Vritti, Karthika, and I will be having a three way chat a bout this PR in the morning (EDT).
- [2026-04-14 16:50] @Ravindra Rayi: Hi <@U04AD8G1ABY|Karthika Menon>, PR for RPLAT-17253 is ready — all your review comments have been addressed. Could you please re-review and approve? Pipeline is currently blocked due to dev1 service ...
- [2026-04-14 15:21] @Bryan Halterman: I think Josh has the right idea, you could move those duplicated props into a base class and then have the two Configs extend the base class. Should be a pretty quick fix
- [2026-04-14 15:19] @Tyler Deal: It's not very clear but in the screenshot above, the specific lines it is complaining about are denoted by that thin gray sidebar.
- [2026-04-14 15:09] @Malia Paul: <@U01RRQXEEG5|Halterman> any input here?
- [2026-04-14 15:03] @Charles Moore: each use case is different - i will adjust
- [2026-04-14 15:03] @Charles Moore: i will go that route - its not ideal but ok.
- [2026-04-14 15:02] @Charles Moore: yes they should be different
- [2026-04-14 15:00] @Josh Bowman: I think it's complaining about your two configuration classes being substantially the same. PreviewerApiConfiguration and FilterApiConfiguration have identical members except for the const. I assume t...
- [2026-04-14 14:48] @Malia Paul: Looks like Karthika has recently left comments to be resolve on your PR <@U08EYBKBFS4|s.tambolkar>

**#dev-env-help** (13 messages)

- [2026-04-14 14:42] @Anthony Garera: Looks like it's 29 Gigs the LMS DB
- [2026-04-14 14:29] @Aris Spivey: I don't think there's anything in the script that would cause it to run indefinitely (like there's no loops or anything that it could be repeating). It prints output indicating where it's getting to w...
- [2026-04-14 14:20] @Anthony Garera: made the swap, 2nd query just hangs/runs indefinitely
- [2026-04-14 14:03] @Aris Spivey: That's likely due to the ROLLBACK at the end of the PersonalizedLearningDataImportForAssessments_TEST script since it undoes creating that table technically. If you change "ROLLBACK" to "COMMIT" in th...
- [2026-04-14 14:01] @Anthony Garera: great that worked, now the second TEST script - PersonalizedLearningDataImportForLMS_TEST is failing on the step after Transfer Course Assessments data from PL_Stage to LMS database Msg 208, Level 16,...
- [2026-04-14 11:08] @Aris Spivey: That error is indicating that you don't have the Assessments database set up (hence Assessments.dbo.Assessment wouldn't exist). You’ll want to go to the assessment-service repo in GitHub, clone it, an...
- [2026-04-14 10:45] @Anthony Garera: Seeing the following error when running the PersonalizedLearningDataImportForAssessments_TEST sql script
- [2026-04-14 09:47] @Josh Bowman: there's also the .gitattributes file in the repo that controls some of this stuff, so worth checking it as well
- [2026-04-14 09:46] @Jason Twichell: Oh, yeah its gotta be that, or something similar. Just realized its only happening when I open the repo on linux
- [2026-04-14 09:44] @Priyanka Goyal: Sometimes, formatting matters ..and it picks up the rules defined in the lint/pretty formatters

**#prod-eng-devex-private** (8 messages)

- [2026-04-14 14:09] @Bryan Halterman: <https://relias.atlassian.net/browse/PE-1038> I think its this issue reported by Christian Roberts
- [2026-04-14 14:04] @Nick Peterson: Noted :memo: I'll confirm where this lives in terms of work item
- [2026-04-14 14:03] @Malia Paul: Here's the issue the new dev (Anthony) found with configurator. <@U69NKFZ9A|Nick> can you make sure this is in fact covered by an existing ticket (and prioritize it as part of our version update).
- [2026-04-14 10:11] @Bryan Halterman: I plan to start drafting a similar one around GitHub as a part of the work I'll be doing this quarter
- [2026-04-14 10:11] @Bryan Halterman: I drafted this yesterday for SonarCloud documentation. I want to provide a formal process around sonarcloud over to IT
- [2026-04-14 10:10] @Bryan Halterman:
- [2026-04-14 08:52] @Malia Paul: and with that, now I have 30 minutes to get ready, eat, and get to the office :slightly_smiling_face:
- [2026-04-14 08:51] @Malia Paul: Let's keep it very focused today in refinement. Agenda items? • Quarterly planning review • Contract testing - scope and plan • Show configurator updates/changes • Revisit our role in an observability...

**#ai-chapter** (8 messages)

- [2026-04-14 12:01] @Jason Twichell: <@U087SA5AE1H|Yuhua> is this the kind of thing we could bring to an Architectural Round Table?
- [2026-04-14 11:42] @Josh Bowman: I'm sure others will have opinions on it, but for me it seems like it would be really nice to have the following: • Automation on every repo that is responsible for parsing the existing state of the r...
- [2026-04-14 11:28] @Jason Twichell: I agree! What I'd like to see is a standard directory (docs/context) in all of our repos that we can maintain through github actions (per <@U2XMZDPJ7|Franz>, <@U04T14A5U0G|jbuda>) and then instruct th...
- [2026-04-14 11:22] @Josh Bowman: That seems like exactly the sort of thing I'm looking for: ongoing and updated context for our architecture (presumably via an MCP that can query that info). I understand that some people have this in...
- [2026-04-14 11:20] @Jason Twichell: Links: <https://docs.github.com/en/copilot/concepts/context/spaces> <https://learn.microsoft.com/en-us/training/modules/introduction-copilot-spaces/> <<https://github.blog/changelog/2025-05-29-introduc>...
- [2026-04-14 11:18] @Jason Twichell: <!here> good morning! I apologize if this has been shared already, but its new to me. Github has a feature called <<https://docs.github.com/en/copilot/how-tos/provide-context/use-copilot-spaces/create->...
- [2026-04-14 09:15] @Zachary Shaffer: A couple days ago GitHub closed the option for Copilot Pro free trials. Yesterday they suspended access for everyone on a Copilot Pro trial. If your personal account is using the trial, it will not wo...
- [2026-04-14 00:32] @Franz Hemmer: I did try it from an Edge browser but you won't be able to get it to work until Bertelsmann enables the feature for us. Just FYI. I'll keep you posted if this changes.

**#product-engineering** (2 messages)

- [2026-04-14 18:48] @Yuhua Zhong: Welcome, <@U0AS1L9LFB3|Abhi Gill> !
- [2026-04-14 15:15] @Ashley Edds: If you had issues transitioning Epics from Proposed to Refined due to issues with the UX Contact, that should be resolved now

**#platform** (1 messages)

- [2026-04-14 13:50] @Matthew Wilson: Hi <@S030YMH3Z4J|relias-platform-pms>. I am looking for confirmation on expected functionality for live events. I found that if a learner has been marked as attended for a session with a completion da...

**#dev-ex-private** (1 messages)

- [2026-04-14 13:41] @Franz Hemmer: I need more cores and I need more ram :scream:

**#next-deployment** (1 messages)

- [2026-04-14 15:15] @Jason Tolhurst: :rocket: Physicians|WCEI|AP Craft &amp; Magento Release planned for tomorrow: <https://relias.atlassian.net/browse/CHM-6046>

---
*Mentions: 1 | DMs: 7 | Announcements: 8 | Channel Messages: 52 (across 8 channels) | Action Items: 0*
