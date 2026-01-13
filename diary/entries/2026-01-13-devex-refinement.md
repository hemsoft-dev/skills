# DevEx Refinement Meeting

**Date:** January 13, 2026  
**Time:** 10:00 AM  
**Attendees:** Malia, Nick, Bryan, Franz

---

## Meeting Summary

The team discussed ongoing challenges with Jira board configuration and refined the process
for ticket management and prioritization. Key topics included resolving ticket visibility
issues, standardizing team fields, updating backups with new seed scripts, and improving
board organization.

---

## Discussion Topics

### 1. Jira Board Configuration and Filtering Issues

The team identified and addressed multiple configuration problems affecting workflow visibility and board functionality.

#### Ticket Visibility Problems

- Several tickets were not appearing on the board due to misconfigured team fields and filter settings
- Nick and Bryan noted discrepancies between the backlog and board view
- Malia confirmed that filter criteria were excluding certain tickets based on their backlog status

#### Team and Product Team Field Confusion

- **Key Decision:** The 'product team' field is a legacy field being phased out; the correct field to use is 'team'
- Nick tested changes to these fields to see their effect on ticket visibility
- The group agreed to standardize on the 'team' field moving forward

#### Filter Creation and Permissions

- Malia created a new filter called 'prod eng dash developer experience'
- All team members were added as editors to the new filter
- Bryan and Nick confirmed their access, though some delays occurred
- Some permissions issues persisted due to board ownership by Doug

#### Board Access and Legacy Data

- Discussed the need to clean up legacy fields
- Some board settings and permissions are tied to previous configurations
- Malia mentioned being part of a task force working on cleaning up these fields
- Bryan updated admin access for the team

#### Next Steps for Board Organization

- Nick and Malia agreed to continue refining the board setup
- Bryan suggested everyone review and clean up tickets in both the backlog and epics
- Team planned to address any remaining issues after the meeting

---

### 2. Ticket Refinement and Prioritization Process

The team reviewed criteria and processes for preparing tickets for development work.

#### Criteria for Ticket Refinement

**Nick asked:** What makes a ticket considered "refined"?  
**Malia's response:** A ticket is ready when it:

- Contains sufficient detail
- Has been discussed by the team
- Is prioritized among other work
- Is ready to be picked up by a developer

#### T-Shirt Sizing Versus Story Points

- Malia suggested using T-shirt sizing (small, medium, large)
- T-shirt sizing has been added to the productivity engineering project
- Bryan and Nick discussed the limitations of available fields in Jira
- Team debated the merits of story points vs. T-shirt sizing

#### .NET 10 Upgrade Ticket Discussion

- Bryan described the .NET 10 upgrade ticket as a **small** task
- Used an AI tool to automate most changes
- Malia questioned the size assessment
- Clarified that the upgrade was limited to the configurator tool, not all services

#### Backup Update Ticket Handling

- Discussed the ticket for updating UM IDP LMS backup restore files
- Referenced a recent meeting with Chris
- **Agreement:** Update backups rather than adding a one-off seed script
- Franz noted the importance of testing and using a reliable backup for restoration

---

### 3. Technical Process for Updating Backups and Seed Scripts

Nick, Bryan, and Franz detailed the technical approach for updating backups.

#### Seed Script Integration

- A seed script added in the last release is required for developers' local environments
- The script populates a new permissions table
- Bryan suggested updating the backups to include the seed script rather than modifying the configurator tool

#### Backup Update Workflow

- Franz described the process of updating backups stored in BLOB storage
- Backups used to be updated automatically (this is no longer the case)
- **Team agreement:** Updating backups should be a recurring task
- Backups should include the latest EF migration history

#### Testing and Validation

- Franz emphasized the need for thorough testing when updating backups
- Must ensure migrations are correctly applied
- **Proposed process:**
  1. Use a local environment to create the backup
  2. Have another developer restore it to verify functionality

---

### 4. Jira Board Usability and Workflow Challenges

#### Jira Complexity Observations

- Franz and Bryan remarked on the clunky and complex nature of Jira
- Significant meeting time was spent troubleshooting field and filter issues
- Managing Jira requires specialized knowledge and ongoing attention
- The group acknowledged this as an ongoing challenge

---

## Follow-Up Tasks

### Jira Board Filter Management

- **Owner:** Bryan
- **Task:** Create a new Jira filter for the team to avoid issues with legacy fields
  and ensure all relevant tickets are visible and editable

### Delete Old Jira Filter

- **Owner:** Malia
- **Task:** Submit a ticket to delete the old Jira filter owned by Doug, as it may
  cause confusion and cannot be deleted without his involvement

### Backlog and Board Cleanup

- **Owner:** The entire team
- **Task:** Review and clean up the backlog and board by:
  - Moving tickets currently only in epics into the backlog
  - Ensuring all items are properly organized
  - Reviewing ticket details for completeness

---

## Key Decisions

1. ✅ Standardize on 'team' field (phase out 'product team' field)
2. ✅ Use T-shirt sizing for ticket estimation
3. ✅ Update backups to include seed scripts (rather than one-off configurator changes)
4. ✅ Establish recurring process for backup updates
5. ✅ Create new filter for team board configuration

---

## Action Items Summary

| Owner | Action                          | Priority |
| ----- | ------------------------------- | -------- |
| Bryan | Create new Jira filter for team | High     |
| Malia | Submit ticket to delete filter  | Medium   |
| Team  | Clean up backlog and board      | High     |
| Team  | Review and validate backup      | High     |
