### \ud83d\udcac Slack Briefing

*Generated: 2026-03-02 22:25 | Date range: 2026-03-01 to 2026-03-02 | User: @fhemmer*

#### \ud83d\udcac Direct Messages (15)

- **[2026-03-02 16:57]** @Bryan Halterman: but its important info that skills have a scope and they need to be built to that scope
- **[2026-03-02 16:56]** @Bryan Halterman: probably just Jeff and I
- **[2026-03-02 16:47]** @Bryan Halterman: is taskforce meeting still oging?
- **[2026-03-02 14:20]** @John Martin: yeah, it sounds super cool
- **[2026-03-02 14:15]** @John Martin: ahh ok, ty ty. if i can find a use case for it i'll definitely dive a little deeper! and if i can't find one I might fabricate one haha
- **[2026-03-02 14:12]** @John Martin: i've heard similar about providers like digital ocean being way more user friendly for smaller projects or things that aren't a cluster of different t...
- **[2026-03-02 14:11]** @John Martin: true, but Azure's meant to host more than a simple website :upside_down_face:
- **[2026-03-02 14:11]** @John Martin: agentic workflows is something I'll have to look into. it sounds powerful, but I'm happy just trying to grasp the basics for now :slightly_smiling_fac...
- **[2026-03-02 16:39]** @Malia Paul: It's not yet a series - which is why I didn't have it setup properly (I apparently missed all kinds of things on this meeting invite)
- **[2026-03-02 14:39]** @Malia Paul: I ironically JUST uploaded a doc to it for the AI Task Force meeting this afternoon.
- **[2026-03-02 14:39]** @Malia Paul: It is not. They actually created an actual site for us.
- **[2026-03-02 14:28]** @Warren Sutherland: Can i get an invite to the task force meeting? I'd like to stay in this loop :slightly_smiling_face:. I'll try to make it work with my calendar
- **[2026-03-02 14:16]** @Warren Sutherland: :slightly_smiling_face:
- **[2026-03-02 14:16]** @Warren Sutherland: <https://relias.atlassian.net/browse/PE-1157?issueKey=PE-1157&subProduct=jira-software>
- **[2026-03-02 14:16]** @Warren Sutherland: What's the best way to subscribe to progress on this?

#### \ud83d\udce2 Announcements (1)

- **[2026-03-02 14:44] #reliasalerts-ssl** - @datadog:

#### \ud83d\udcc1 Channel Activity

**#prod-eng-devex-private** (41 messages)

- [2026-03-02 18:27] @Malia Paul: Tyler or Sid should be able to help. Are PRs blocked for now?
- [2026-03-02 18:26] @Malia Paul: I'd prefer to add the analyzer to the Cypress pr pipeline, if we must. But I am curious why the pr pipeline isn't a sub process of another pipeline that runs the analyzer? It just figures out which te...
- [2026-03-02 16:46] @Bryan Halterman: <@U032050R2TY|Malia Paul> idk if you have an opinion here
- [2026-03-02 16:44] @Bryan Halterman: or someone in management can override and force merge
- [2026-03-02 16:42] @Bryan Halterman: so we either need to turn the gate off for RLMS-Website, or add the analyzer to the cypress pipeline
- [2026-03-02 16:41] @Bryan Halterman: Its failing because the cypress pr pipeline is not running the sonarcloud analyzer
- [2026-03-02 16:01] @Nick Peterson: <@U01RRQXEEG5|Halterman> when you get back, seeing that rlms-web PRs have the same issue we resolved for the content library service
- [2026-03-02 15:51] @Nick Peterson: Gotcha, I told Nico we are waiting on info to resolve his issue
- [2026-03-02 15:50] @Bryan Halterman: Pe doesnt own Snyk, thats a security thing we can just help by being the middle man
- [2026-03-02 15:50] @Nick Peterson: offline.

**#productivity-engineering-public** (33 messages)

- [2026-03-02 16:33] @Zach Owen: This is happening for us too on Nurse Jobs - e.g. <https://github.com/relias-engineering/nurse-job-seekers/pull/93>
- [2026-03-02 15:58] @Nick Peterson: I see that other rlms-web PR's also are pending, looking into this now
- [2026-03-02 15:55] @Mahmuda Hamid: <@U69NKFZ9A|nick> I'm having the same SonarCloud issue on <https://github.com/relias-engineering/rlms-website/pull/1361|this> PR.
- [2026-03-02 15:48] @Nick Peterson: Will let you know when I have found a resolution on the Snyk issue
- [2026-03-02 15:40] @Nick Peterson: Taking a look
- [2026-03-02 15:35] @Nicolas Tobis: <@U69NKFZ9A|nick> I have the same issue with Snyk. Is that being looked at, too?
- [2026-03-02 13:35] @Franz Hemmer: Now Sonnet is crying, it was the active model at the time Bryan :giggle:
- [2026-03-02 13:21] @Bryan Halterman: It should be able to resolve without needing to re-run your pipelines. there was an issue with the mapping on the connector. When we updated that we saw the check pass on the repos we were monitoring
- [2026-03-02 13:20] @Bryan Halterman: <@U062HDDF03B|Nico>, I remove reporting hub from the exclusion. The blocker should be resolved now. Let me know if you have any more issues!
- [2026-03-02 13:20] @Geo Rufino: <<https://github.com/relias-engineering/content-library-service/pull/459|Issue> resolved>. Thanks y'all! <@U0230R6B6RJ|chuck> <@U09NJ519EM8|clyons> If you have a stuck pipeline, either rerun the pipelin...

**#sonarcloud-public** (22 messages)

- [2026-03-02 14:26] @Zack Clark: This is the only failure, but that isn't blocking anything. I'm re-running just to be sure
- [2026-03-02 14:26] @Zack Clark: <https://dev.azure.com/ReliasEngineering/PlatformDevelopment/_build/results?buildId=86422&view=results>
- [2026-03-02 14:26] @Zack Clark: that does look like it's working now
- [2026-03-02 14:21] @Bryan Halterman: The entitlements errors in your pipelines are known errors for sonarcloud but they shouldn't be blockers
- [2026-03-02 14:18] @Bryan Halterman: the build passed the testing phase and I see sonarcloud is now passing too
- [2026-03-02 14:16] @Bryan Halterman: I see you have an active build, lets see when that finishes if it updates correctly
- [2026-03-02 14:14] @Zack Clark: I am certain that those tests are there. I've pushed whitespace changes just to retrigger it, and it does pass sometimes.
- [2026-03-02 14:14] @Zack Clark: yeah - it passed earlier
- [2026-03-02 14:14] @Bryan Halterman: <<https://sonarcloud.io/summary/new_code?id=relias-engineering_incident-service-handlers&pullRequest=54|Summary> - incident-service-handlers in Relias-GitHub SonarQube Cloud> checking sonarcloud it seem...
- [2026-03-02 14:14] @Zack Clark: I dont think that report is accurate

**#dev-tribe** (4 messages)

- [2026-03-02 11:20] @Beth Dodd: More Information about 7, 8 and 11: Enginge: There have been no deployments since 3/2025. Resources only exist in dev1/dev2. Looks abandoned. Further cleanup may be needed for the other resources. Tra...
- [2026-03-02 08:07] @Lakshminarayanan Ramachandran: <@U036JBV3JJV|Beth>, Agreed on #1. This can be taken down! :+1: CC: <@U08DAGFQFEG|Henryk> <@UB6J3MF71> <@U08EMFNFJPK|Ketaki> <@U08EC64NSJG|a.kulkarni>
- [2026-03-02 07:50] @Hemant Patil: `<S09BX3APGTS>` Please ignore, testing is done via Test/Run Method for OrganizationCreatedFunction function on Dev1.
- [2026-03-02 04:58] @Hemant Patil: Hi `<S09BX3APGTS>`, I was following this Confluence doc to create a target organization via the Onboarding Service: <<https://relias.atlassian.net/wiki/spaces/RLPD/pages/5901680668/Create+Target+Organiza>...

**#ai-chapter** (2 messages)

- [2026-03-02 10:19] @Todd Southwell: how about a nice game of chess ?
- [2026-03-02 09:03] @Gray Anthony:

---
*Mentions: 0 | DMs: 15 | Announcements: 1 | Channel Messages: 102 (across 5 channels) | Action Items: 0*
