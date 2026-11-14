-- Apply after 202611140001_initial_schema.sql. Safe to run more than once.
create table if not exists public.prayer_schedules (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  prayer_name text not null check(prayer_name in ('Fajr','Dhuhr','Asr','Maghrib','Isha','Jumuah','Eid')),
  prayer_date date not null, adhan_time time, iqamah_time time, notes text, created_at timestamptz not null default now(),
  unique(organisation_id,prayer_name,prayer_date)
);
alter table public.prayer_schedules enable row level security;
alter table public.documents add column if not exists cloudinary_resource_type text;
alter table public.documents add column if not exists cloudinary_version bigint;
alter table public.documents add column if not exists cloudinary_format text;
drop policy if exists organisation_scope on public.prayer_schedules;
create policy organisation_read on public.prayer_schedules for select to authenticated using(public.has_organisation_access(organisation_id));
create policy organisation_write on public.prayer_schedules for all to authenticated
  using(public.has_organisation_access(organisation_id) and not public.has_organisation_role(organisation_id,array['auditor']))
  with check(public.has_organisation_access(organisation_id) and not public.has_organisation_role(organisation_id,array['auditor']));
grant select,insert,update,delete on public.prayer_schedules to authenticated;

-- Read access remains organisation-scoped. Auditor role cannot mutate workspace data.
do $$ declare t text; begin
  foreach t in array array['organisation_settings','wards','families','members','family_relationships','membership_categories','membership_fee_structures','membership_payments','account_categories','funds','accounts','transactions','transaction_lines','receipts','donors','donations','nikah_applications','nikah_witnesses','death_records','janazah_records','burial_records','staff','staff_attendance','salary_payments','madrasa_classes','madrasa_students','madrasa_teachers','student_attendance','examinations','exam_marks','committees','committee_members','meetings','meeting_minutes','resolutions','announcements','events','document_categories','notifications'] loop
    execute format('drop policy if exists organisation_scope on public.%I',t);
    execute format('create policy organisation_read on public.%I for select to authenticated using(public.has_organisation_access(organisation_id))',t);
    execute format('create policy organisation_write on public.%I for all to authenticated using(public.has_organisation_access(organisation_id) and not public.has_organisation_role(organisation_id,array[''auditor''])) with check(public.has_organisation_access(organisation_id) and not public.has_organisation_role(organisation_id,array[''auditor'']))',t);
  end loop;
end $$;

-- Audit history cannot be altered from the client. Insert audit records through trusted server code.
drop policy if exists organisation_scope on public.audit_logs;
drop policy if exists organisation_read on public.audit_logs;
drop policy if exists organisation_write on public.audit_logs;
create policy audit_read on public.audit_logs for select to authenticated using(public.has_organisation_access(organisation_id));

-- Sensitive document categories are only visible to the roles that handle them.
drop policy if exists organisation_scope on public.documents;
drop policy if exists organisation_read on public.documents;
drop policy if exists organisation_write on public.documents;
create policy documents_read on public.documents for select to authenticated using (
  public.has_organisation_access(organisation_id) and case category
    when 'finance' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','president','treasurer','auditor'])
    when 'nikah' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','secretary','imam'])
    when 'death' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','secretary','imam'])
    when 'committee' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','president','secretary'])
    when 'property' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','treasurer'])
    when 'welfare' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','president','secretary','treasurer'])
    else true end
);
create policy documents_write on public.documents for all to authenticated using (
  public.has_organisation_access(organisation_id) and not public.has_organisation_role(organisation_id,array['auditor']) and case category
    when 'finance' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','treasurer'])
    when 'nikah' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','secretary','imam'])
    when 'death' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','secretary','imam'])
    when 'committee' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','president','secretary'])
    when 'property' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','treasurer'])
    when 'welfare' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','president','secretary','treasurer'])
    else true end
) with check (
  public.has_organisation_access(organisation_id) and not public.has_organisation_role(organisation_id,array['auditor']) and case category
    when 'finance' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','treasurer'])
    when 'nikah' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','secretary','imam'])
    when 'death' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','secretary','imam'])
    when 'committee' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','president','secretary'])
    when 'property' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','treasurer'])
    when 'welfare' then public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','president','secretary','treasurer'])
    else true end
);

-- Zakat and welfare records are visible only to the committee roles listed here.
do $$ declare t text; begin
  foreach t in array array['beneficiaries','welfare_applications','welfare_distributions'] loop
    execute format('drop policy if exists organisation_read on public.%I',t);
    execute format('drop policy if exists organisation_write on public.%I',t);
    execute format('drop policy if exists welfare_authorised on public.%I',t);
    execute format('create policy welfare_read on public.%I for select to authenticated using(public.has_organisation_role(organisation_id,array[''super_admin'',''mahal_admin'',''president'',''secretary'',''treasurer'']))',t);
    execute format('create policy welfare_write on public.%I for all to authenticated using(public.has_organisation_role(organisation_id,array[''super_admin'',''mahal_admin'',''president'',''secretary'',''treasurer''])) with check(public.has_organisation_role(organisation_id,array[''super_admin'',''mahal_admin'',''president'',''secretary'',''treasurer'']))',t);
  end loop;
end $$;
