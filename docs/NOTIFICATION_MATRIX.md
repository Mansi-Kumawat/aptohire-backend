# Notification-kind source/test candidate matrix (static; review required)

> Expected kinds are parsed from the authoritative prompt §15A. Producer and test columns use raw source-text matching; these matches do **not** prove that a code path reaches the producer, that the payload is correct, or that a test asserts delivery/identity minimization. Runtime DB tests and code review remain required.

Prompt kinds: 21; kinds with a producer-source text match: 21; kinds with a test-file text match: 21.

| Kind | Producer-source files (text match) | Candidate test files (text match) |
|---|---|---|
| `audit_ready` | `supabase/migrations/0039_admin_event_notifications.sql` | `supabase/tests/0022_admin_event_notifications.test.sql`, `supabase/tests/0068_owner_owned_rows_rls.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `review_needed` | `supabase/migrations/0039_admin_event_notifications.sql` | `supabase/tests/0022_admin_event_notifications.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `review_decided` | `supabase/migrations/0033_admin_review_audit.sql` | `supabase/tests/0014_admin_review_audit.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `appeal_update` | `supabase/migrations/0034_admin_ticket_decisions.sql` | `supabase/tests/0015_admin_ticket_decisions.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `access_request` | `supabase/migrations/0028_access_consent_transitions.sql`, `supabase/migrations/0038_expire_access_grants.sql`, `supabase/migrations/0045_access_expiring_notifications.sql`, `supabase/migrations/0094_atomic_access_request.sql`, `supabase/functions/reveal-student/index.ts` | `supabase/tests/0004_org_delta_contract.test.sql`, `supabase/tests/0009_access_consent_transitions.test.sql`, `supabase/tests/0016_feedback_policy_guard.test.sql`, `supabase/tests/0018_student_account_deletion.test.sql`, `supabase/tests/0020_expire_access_grants.test.sql`, `supabase/tests/0021_org_blind_value_scan.test.sql`, `supabase/tests/0028_access_expiring_notifications.test.sql`, `supabase/tests/0064_realtime_publication_membership.test.sql`, `supabase/tests/0079_atomic_access_request.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql`, `supabase/tests/0087_access_request_pipeline_rls.test.sql`, `supabase/tests/0089_reviewed_pipeline_stage.test.sql` |
| `access_expiring` | `supabase/migrations/0038_expire_access_grants.sql`, `supabase/migrations/0045_access_expiring_notifications.sql` | `supabase/tests/0020_expire_access_grants.test.sql`, `supabase/tests/0028_access_expiring_notifications.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `affiliation_proposal` | `supabase/migrations/0032_admin_university_approval.sql`, `supabase/migrations/0091_atomic_affiliation_proposals.sql` | `supabase/tests/0013_admin_university_approval.test.sql`, `supabase/tests/0047_identity_rls_behaviour.test.sql`, `supabase/tests/0075_atomic_affiliation_proposals.test.sql`, `supabase/tests/0078_confirm_affiliation_preserves_student.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `feedback_received` | `supabase/migrations/0035_feedback_policy_guard.sql` | `supabase/tests/0016_feedback_policy_guard.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `source_proposals` | `supabase/migrations/0039_admin_event_notifications.sql` | `supabase/tests/0022_admin_event_notifications.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `application_decided` | `supabase/migrations/0031_admin_organization_actions.sql`, `supabase/migrations/0032_admin_university_approval.sql` | `supabase/tests/0012_admin_organization_actions.test.sql`, `supabase/tests/0013_admin_university_approval.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `roster_matched` | `supabase/migrations/0032_admin_university_approval.sql` | `supabase/tests/0013_admin_university_approval.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `demand_alert` | `supabase/migrations/0039_admin_event_notifications.sql` | `supabase/tests/0022_admin_event_notifications.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `student_registered` | `supabase/migrations/0039_admin_event_notifications.sql` | `supabase/tests/0022_admin_event_notifications.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `access_accepted` | `supabase/migrations/0028_access_consent_transitions.sql` | `supabase/tests/0009_access_consent_transitions.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `access_declined` | `supabase/migrations/0028_access_consent_transitions.sql` | `supabase/tests/0009_access_consent_transitions.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `access_withdrawn` | `supabase/migrations/0028_access_consent_transitions.sql` | `supabase/tests/0009_access_consent_transitions.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `new_match` | `supabase/migrations/0099_atomic_match_persistence.sql`, `supabase/migrations/0100_fix_match_jsonb_key_count.sql` | `supabase/tests/0085_notification_kind_contract.test.sql`, `supabase/tests/0086_atomic_match_persistence.test.sql` |
| `subscription_changed` | `supabase/migrations/0031_admin_organization_actions.sql` | `supabase/tests/0012_admin_organization_actions.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `application_received` | `supabase/migrations/0039_admin_event_notifications.sql`, `supabase/migrations/0041_submit_application_atomic.sql` | `supabase/tests/0022_admin_event_notifications.test.sql`, `supabase/tests/0024_submit_application.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `ticket_opened` | `supabase/migrations/0034_admin_ticket_decisions.sql` | `supabase/tests/0015_admin_ticket_decisions.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |
| `run_failed` | `supabase/migrations/0039_admin_event_notifications.sql` | `supabase/tests/0022_admin_event_notifications.test.sql`, `supabase/tests/0085_notification_kind_contract.test.sql` |

## Manual review required

For each kind, verify the producer is invoked under the expected lifecycle transition, payload fields are allowlisted, organization-bound notifications contain no student identity, and tests assert both recipient delivery and prohibited fields. `none found` is a source-text gap signal, not proof a producer/test does not exist.

## Runtime verification still required

Execute the mapped pgTAP/Deno suites and inspect failures on the local stack. Confirm lifecycle triggers and payload expectations match the frozen portal behavior; do not treat source review as a passing test result. `none found` in the generated candidate table is only a source-text gap signal.

## Manually reviewed behavioral evidence (source review, not execution)

The text-matched candidate list above is not itself proof. Manual source review of the current pgTAP/Deno sources found a delivery assertion for each frozen kind. SQL/Deno behavior remains unexecuted in this workspace.

| Kind | Behavioral test source | Behavior asserted in test source |
|---|---|---|
| `audit_ready` | `0022_admin_event_notifications.test.sql` | Completed audit delivers to its student. |
| `review_needed` | `0022_admin_event_notifications.test.sql` | Pending review notifies admin and student; student payload omits identity/contact. |
| `review_decided` | `0014_admin_review_audit.test.sql` | Human review decision notifies the student. |
| `appeal_update` | `0015_admin_ticket_decisions.test.sql` | Ticket decision notifies the student. |
| `access_request` | `0079_atomic_access_request.test.sql` | Student receives atomic request notification with identity-minimal payload. |
| `access_expiring` | `0020_expire_access_grants.test.sql`, `0028_access_expiring_notifications.test.sql` | Student and organization receive expiry notices; organization payload omits student identity; repeat is idempotent. |
| `affiliation_proposal` | `0013_admin_university_approval.test.sql`, `0075_atomic_affiliation_proposals.test.sql` | Proposal is delivered once and its payload omits student identity/raw ID. |
| `feedback_received` | `0016_feedback_policy_guard.test.sql` | Valid feedback notifies the student; payload omits identity/contact. |
| `source_proposals` | `0022_admin_event_notifications.test.sql` | Pending source proposal produces a notification for its student. |
| `application_decided` | `0012_admin_organization_actions.test.sql`, `0013_admin_university_approval.test.sql` | Organization/university members receive decisions; student identity is omitted. |
| `roster_matched` | `0013_admin_university_approval.test.sql` | University receives count-only match result. |
| `demand_alert` | `0022_admin_event_notifications.test.sql` | University members receive aggregate reasons/skills only; repeated unchanged update does not duplicate. |
| `student_registered` | `0022_admin_event_notifications.test.sql` | Linked student notifies university; unlinked row does not; name/email omitted. |
| `access_accepted` | `0009_access_consent_transitions.test.sql` | Organization receives accept event; payload omits student identity. |
| `access_declined` | `0009_access_consent_transitions.test.sql` | Organization receives decline event; payload omits student identity. |
| `access_withdrawn` | `0009_access_consent_transitions.test.sql` | Organization receives withdrawal event after grant is cleared. |
| `new_match` | `0086_atomic_match_persistence.test.sql` | First new match returns count 1 and notifies organization members with exact job/count-only payload; rerun reports zero new candidates, updates the match, and does not duplicate the notification. RPC rejects malformed/duplicate rows and non-member actors. Source only; pgTAP remains unrun. |
| `subscription_changed` | `0012_admin_organization_actions.test.sql` | Organization member receives updated subscription status. |
| `application_received` | `0022_admin_event_notifications.test.sql`, `0024_submit_application.test.sql` | Admin receives safe application identifiers; contact/payload secrets omitted. |
| `ticket_opened` | `0015_admin_ticket_decisions.test.sql` | Admin receives ticket notice; student identity omitted. |
| `run_failed` | `0022_admin_event_notifications.test.sql` | Admin receives run/stage status; private provider error text omitted. |
