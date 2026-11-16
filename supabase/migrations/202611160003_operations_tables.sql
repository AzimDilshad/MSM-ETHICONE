-- Additional workflows from the Mahal v1 brief.
create table if not exists public.financial_years(
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
 name text not null, starts_on date not null, ends_on date not null, active boolean not null default false,
 check(ends_on>=starts_on), unique(organisation_id,name)
);
create table if not exists public.fee_concessions(
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
 family_id uuid references public.families(id) on delete cascade, member_id uuid references public.members(id) on delete cascade,
 amount numeric(12,2) not null check(amount>=0), reason text not null, status text not null default 'pending' check(status in ('pending','approved','rejected')),
 approved_by uuid references auth.users(id), created_at timestamptz not null default now(), check(family_id is not null or member_id is not null)
);
create table if not exists public.staff_leaves(
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
 staff_id uuid not null references public.staff(id) on delete cascade, starts_on date not null, ends_on date not null,
 reason text, status text not null default 'pending' check(status in ('pending','approved','rejected')), approved_by uuid references auth.users(id),
 check(ends_on>=starts_on)
);
create table if not exists public.meeting_attendance(
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
 meeting_id uuid not null references public.meetings(id) on delete cascade, committee_member_id uuid not null references public.committee_members(id) on delete cascade,
 attended boolean not null default true, unique(meeting_id,committee_member_id)
);
create table if not exists public.nikah_documents(
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
 application_id uuid not null references public.nikah_applications(id) on delete cascade, document_id uuid not null references public.documents(id) on delete cascade,
 document_type text not null, created_at timestamptz not null default now()
);
create table if not exists public.transaction_attachments(
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
 transaction_id uuid not null references public.transactions(id) on delete cascade, document_id uuid not null references public.documents(id) on delete cascade,
 created_at timestamptz not null default now(), unique(transaction_id,document_id)
);
do $$ declare t text; begin
 foreach t in array array['financial_years','fee_concessions','staff_leaves','meeting_attendance','nikah_documents','transaction_attachments'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('create policy organisation_read on public.%I for select to authenticated using(public.has_organisation_access(organisation_id))',t);
  execute format('create policy organisation_write on public.%I for all to authenticated using(public.has_organisation_access(organisation_id) and not public.has_organisation_role(organisation_id,array[''auditor''])) with check(public.has_organisation_access(organisation_id) and not public.has_organisation_role(organisation_id,array[''auditor'']))',t);
  execute format('grant select,insert,update,delete on public.%I to authenticated',t);
 end loop;
end $$;
create index if not exists fee_concessions_org_status_idx on public.fee_concessions(organisation_id,status);
create index if not exists staff_leaves_org_dates_idx on public.staff_leaves(organisation_id,starts_on,ends_on);

-- Record who changed organisation data without copying confidential row contents.
create or replace function public.capture_audit_event()
returns trigger language plpgsql security definer set search_path=public
as $$
declare org_id uuid; record_id uuid; op text;
begin
  op:=lower(tg_op);
  if tg_op='DELETE' then org_id:=old.organisation_id;record_id:=old.id;
  else org_id:=new.organisation_id;record_id:=new.id;end if;
  insert into public.audit_logs(organisation_id,actor_id,action,entity,entity_id,details)
  values(org_id,auth.uid(),op,tg_table_name,record_id,jsonb_build_object('source','database_trigger'));
  if tg_op='DELETE' then return old;else return new;end if;
end $$;
do $$ declare t text; begin
 foreach t in array array['wards','families','members','membership_payments','transactions','donations','nikah_applications','death_records','beneficiaries','welfare_applications','welfare_distributions','staff','salary_payments','madrasa_students','student_attendance','committees','meetings','announcements','events','documents','fee_concessions','staff_leaves'] loop
  execute format('drop trigger if exists audit_capture on public.%I',t);
  execute format('create trigger audit_capture after insert or update or delete on public.%I for each row execute function public.capture_audit_event()',t);
 end loop;
end $$;
