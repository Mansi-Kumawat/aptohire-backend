alter table public.notifications add constraint notifications_kind_allowed check(kind in (
 'audit_ready','review_needed','review_decided','appeal_update','access_request','access_expiring','affiliation_proposal','feedback_received','source_proposals',
 'application_decided','roster_matched','demand_alert','student_registered',
 'access_accepted','access_declined','access_withdrawn','new_match','subscription_changed',
 'application_received','ticket_opened','run_failed'
));
create index if not exists notifications_user_created_idx on public.notifications(user_id,created_at desc);
