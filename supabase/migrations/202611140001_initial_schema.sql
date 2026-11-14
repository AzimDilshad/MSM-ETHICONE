-- Mahal Management System v1.0 — run in the Supabase SQL editor or via Supabase CLI.
create extension if not exists pgcrypto;

create table public.organisations (
  id uuid primary key default gen_random_uuid(), name text not null, address text, phone text,
  email text, logo_url text, currency text not null default 'INR', created_at timestamptz not null default now()
);
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade, full_name text not null default '',
  phone text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.roles (
  id uuid primary key default gen_random_uuid(), name text unique not null,
  permissions jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
insert into public.roles(name) values ('super_admin'),('mahal_admin'),('president'),('secretary'),('treasurer'),('imam'),('madrasa_admin'),('staff'),('auditor') on conflict do nothing;
create table public.user_roles (
  user_id uuid not null references auth.users(id) on delete cascade, role_id uuid not null references public.roles(id),
  organisation_id uuid not null references public.organisations(id) on delete cascade, primary key(user_id, role_id, organisation_id)
);
create table public.user_masals (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  organisation_id uuid not null references public.organisations(id) on delete cascade, created_at timestamptz not null default now(), unique(user_id, organisation_id)
);
create table public.organisation_settings (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null unique references public.organisations(id) on delete cascade,
  settings jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now()
);
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null, action text not null, entity text not null, entity_id uuid,
  details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create table public.wards (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  name text not null, ward_number text not null, representative_name text, phone text, created_at timestamptz not null default now(), unique(organisation_id,ward_number)
);
create table public.families (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  ward_id uuid references public.wards(id) on delete set null, family_code text not null, family_name text not null, house_name text,
  house_number text, address text, post_office text, pin_code text, phone text, whatsapp text,
  registration_date date not null default current_date, membership_status text not null default 'active' check(membership_status in ('active','inactive','pending')),
  remarks text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(organisation_id,family_code)
);
create table public.members (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete restrict, member_code text not null, full_name text not null,
  malayalam_name text, gender text check(gender in ('male','female','other')), date_of_birth date, father_name text, mother_name text,
  spouse_name text, relationship_to_head text, phone text, education text, occupation text, photo_url text,
  marriage_status text, member_status text not null default 'active' check(member_status in ('active','inactive','deceased','migrated')),
  emergency_contact text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(organisation_id,member_code)
);
create table public.family_relationships (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade, member_id uuid not null references public.members(id) on delete cascade,
  relationship text not null, is_head boolean not null default false, unique(family_id,member_id)
);
create table public.membership_categories (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  name text not null, description text, active boolean not null default true, unique(organisation_id,name)
);
create table public.membership_fee_structures (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  category_id uuid references public.membership_categories(id) on delete set null, name text not null, amount numeric(12,2) not null check(amount>=0),
  frequency text not null check(frequency in ('monthly','annual','one_time')), effective_from date not null default current_date, active boolean not null default true
);
create table public.membership_payments (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  family_id uuid references public.families(id) on delete set null, member_id uuid references public.members(id) on delete set null,
  fee_structure_id uuid references public.membership_fee_structures(id) on delete set null, amount numeric(12,2) not null check(amount>0),
  payment_date date not null default current_date, method text not null default 'cash', receipt_number text, period_start date, period_end date,
  notes text, created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table public.account_categories (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  name text not null, direction text not null check(direction in ('income','expense')), unique(organisation_id,name,direction)
);
create table public.funds (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  name text not null, restricted boolean not null default false, description text, unique(organisation_id,name)
);
create table public.accounts (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  name text not null, account_type text not null check(account_type in ('cash','bank','other')), opening_balance numeric(14,2) not null default 0,
  active boolean not null default true, unique(organisation_id,name)
);
create table public.transactions (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  account_id uuid references public.accounts(id) on delete set null, category_id uuid references public.account_categories(id) on delete set null,
  fund_id uuid references public.funds(id) on delete set null, direction text not null check(direction in ('income','expense')),
  amount numeric(14,2) not null check(amount>0), transaction_date date not null default current_date, description text not null,
  payment_method text not null default 'cash', approval_status text not null default 'approved' check(approval_status in ('pending','approved','rejected')),
  created_by uuid references auth.users(id) on delete set null, approved_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create table public.transaction_lines (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  transaction_id uuid not null references public.transactions(id) on delete cascade, account_id uuid references public.accounts(id),
  fund_id uuid references public.funds(id), description text, debit numeric(14,2) not null default 0, credit numeric(14,2) not null default 0,
  check(debit>=0 and credit>=0 and not(debit>0 and credit>0))
);
create table public.receipts (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  transaction_id uuid references public.transactions(id) on delete set null, receipt_number text not null, issued_at timestamptz not null default now(), unique(organisation_id,receipt_number)
);
create table public.donors (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  name text, phone text, anonymous boolean not null default false, created_at timestamptz not null default now()
);
create table public.donations (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  donor_id uuid references public.donors(id) on delete set null, fund_id uuid references public.funds(id) on delete set null,
  amount numeric(14,2) not null check(amount>0), donation_date date not null default current_date, purpose text, payment_method text not null default 'cash',
  receipt_number text, created_at timestamptz not null default now()
);
create table public.nikah_applications (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  registration_number text, groom_name text not null, bride_name text not null, guardian_name text, nikah_at timestamptz, location text,
  imam_name text, fee numeric(12,2) not null default 0, status text not null default 'pending', notes text, created_at timestamptz not null default now()
);
create table public.nikah_witnesses (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  application_id uuid not null references public.nikah_applications(id) on delete cascade, name text not null, phone text, witness_type text
);
create table public.death_records (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  member_id uuid references public.members(id) on delete set null, deceased_name text not null, date_of_death date, family_contact text, announcement text, created_at timestamptz not null default now()
);
create table public.janazah_records (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  death_record_id uuid not null references public.death_records(id) on delete cascade, janazah_at timestamptz, location text, imam_name text
);
create table public.burial_records (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  death_record_id uuid not null references public.death_records(id) on delete cascade, burial_location text, grave_number text, burial_date date
);
create table public.beneficiaries (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  family_id uuid references public.families(id) on delete set null, full_name text not null, phone text, confidential_notes text, created_at timestamptz not null default now()
);
create table public.welfare_applications (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  beneficiary_id uuid not null references public.beneficiaries(id) on delete cascade, assistance_type text not null, amount_requested numeric(12,2),
  status text not null default 'pending', committee_notes text, created_at timestamptz not null default now()
);
create table public.welfare_distributions (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  application_id uuid references public.welfare_applications(id) on delete set null, beneficiary_id uuid not null references public.beneficiaries(id) on delete cascade,
  amount numeric(12,2) not null check(amount>=0), distributed_at date not null default current_date, notes text
);
create table public.staff (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  full_name text not null, position text not null, phone text, appointed_on date, salary numeric(12,2), active boolean not null default true
);
create table public.staff_attendance (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  staff_id uuid not null references public.staff(id) on delete cascade, attendance_date date not null, status text not null, unique(staff_id,attendance_date)
);
create table public.salary_payments (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  staff_id uuid not null references public.staff(id) on delete cascade, amount numeric(12,2) not null check(amount>0), paid_on date not null default current_date, period text
);
create table public.madrasa_classes (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade, name text not null, teacher_name text
);
create table public.madrasa_students (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  class_id uuid references public.madrasa_classes(id) on delete set null, full_name text not null, parent_name text, parent_phone text, date_of_birth date, active boolean not null default true
);
create table public.madrasa_teachers (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade, full_name text not null, phone text
);
create table public.student_attendance (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  student_id uuid not null references public.madrasa_students(id) on delete cascade, attendance_date date not null, status text not null, unique(student_id,attendance_date)
);
create table public.examinations (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade, name text not null, exam_date date
);
create table public.exam_marks (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  examination_id uuid not null references public.examinations(id) on delete cascade, student_id uuid not null references public.madrasa_students(id) on delete cascade,
  marks numeric(8,2) not null check(marks>=0), unique(examination_id,student_id)
);
create table public.committees (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  name text not null, tenure_start date, tenure_end date, active boolean not null default true
);
create table public.committee_members (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  committee_id uuid not null references public.committees(id) on delete cascade, full_name text not null, role text not null, phone text
);
create table public.meetings (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  committee_id uuid references public.committees(id) on delete set null, title text not null, meeting_at timestamptz, agenda text
);
create table public.meeting_minutes (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  meeting_id uuid not null references public.meetings(id) on delete cascade, body text not null, created_at timestamptz not null default now()
);
create table public.resolutions (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  meeting_id uuid references public.meetings(id) on delete set null, title text not null, details text, status text not null default 'proposed'
);
create table public.announcements (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  title text not null, body text not null, language text not null default 'en', starts_at timestamptz, expires_at timestamptz, published boolean not null default false, created_at timestamptz not null default now()
);
create table public.events (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  title text not null, description text, starts_at timestamptz, location text, speaker text, created_at timestamptz not null default now()
);
create table public.document_categories (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade, name text not null, unique(organisation_id,name)
);
create table public.documents (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  category_id uuid references public.document_categories(id) on delete set null, category text not null default 'general', name text not null,
  object_key text not null, secure_url text, mime_type text, size_bytes bigint check(size_bytes is null or size_bytes>=0),
  uploaded_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade, title text not null, body text, read_at timestamptz, created_at timestamptz not null default now()
);
create table public.prayer_schedules (
  id uuid primary key default gen_random_uuid(), organisation_id uuid not null references public.organisations(id) on delete cascade,
  prayer_name text not null check(prayer_name in ('Fajr','Dhuhr','Asr','Maghrib','Isha','Jumuah','Eid')),
  prayer_date date not null, adhan_time time, iqamah_time time, notes text, created_at timestamptz not null default now(),
  unique(organisation_id,prayer_name,prayer_date)
);

-- Indexes used by organisation scoped lists, searches, and reporting.
create index families_org_ward_idx on public.families(organisation_id,ward_id);
create index families_org_name_idx on public.families(organisation_id,family_name);
create index members_org_family_idx on public.members(organisation_id,family_id);
create index members_org_name_idx on public.members(organisation_id,full_name);
create index transactions_org_date_idx on public.transactions(organisation_id,transaction_date desc);
create index donations_org_date_idx on public.donations(organisation_id,donation_date desc);
create index documents_org_date_idx on public.documents(organisation_id,created_at desc);
create index announcements_org_date_idx on public.announcements(organisation_id,starts_at);

-- Every organisation member can access rows for that organisation. Privileged operations
-- such as assigning roles and removing organisations should be done by trusted admins.
create or replace function public.has_organisation_access(target uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.user_masals m where m.user_id = auth.uid() and m.organisation_id = target) $$;
create or replace function public.has_organisation_role(target uuid, allowed_roles text[])
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.user_roles ur join public.roles r on r.id=ur.role_id where ur.user_id=auth.uid() and ur.organisation_id=target and r.name=any(allowed_roles)) $$;
revoke all on function public.has_organisation_access(uuid) from public;
grant execute on function public.has_organisation_access(uuid) to authenticated;
revoke all on function public.has_organisation_role(uuid,text[]) from public;
grant execute on function public.has_organisation_role(uuid,text[]) to authenticated;

alter table public.organisations enable row level security;
create policy organisations_member_read on public.organisations for select to authenticated using (public.has_organisation_access(id));
alter table public.profiles enable row level security;
create policy profiles_self_read on public.profiles for select to authenticated using (id = auth.uid());
create policy profiles_self_insert on public.profiles for insert to authenticated with check (id = auth.uid());
create policy profiles_self_update on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
alter table public.roles enable row level security;
create policy roles_authenticated_read on public.roles for select to authenticated using (true);

do $$ declare t text; begin
  foreach t in array array['organisation_settings','audit_logs','wards','families','members','family_relationships','membership_categories','membership_fee_structures','membership_payments','account_categories','funds','accounts','transactions','transaction_lines','receipts','donors','donations','nikah_applications','nikah_witnesses','death_records','janazah_records','burial_records','beneficiaries','welfare_applications','welfare_distributions','staff','staff_attendance','salary_payments','madrasa_classes','madrasa_students','madrasa_teachers','student_attendance','examinations','exam_marks','committees','committee_members','meetings','meeting_minutes','resolutions','announcements','events','document_categories','documents','notifications','prayer_schedules'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('create policy organisation_scope on public.%I for all to authenticated using (public.has_organisation_access(organisation_id)) with check (public.has_organisation_access(organisation_id))',t);
  end loop;
end $$;

-- Welfare case notes and beneficiary records are limited to approved committee roles.
drop policy organisation_scope on public.beneficiaries;
create policy welfare_authorised on public.beneficiaries for all to authenticated
  using (public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','president','secretary','treasurer']))
  with check (public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','president','secretary','treasurer']));
drop policy organisation_scope on public.welfare_applications;
create policy welfare_authorised on public.welfare_applications for all to authenticated
  using (public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','president','secretary','treasurer']))
  with check (public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','president','secretary','treasurer']));
drop policy organisation_scope on public.welfare_distributions;
create policy welfare_authorised on public.welfare_distributions for all to authenticated
  using (public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','president','secretary','treasurer']))
  with check (public.has_organisation_role(organisation_id,array['super_admin','mahal_admin','president','secretary','treasurer']));

-- Membership and role assignment cannot be self granted by an ordinary member.
alter table public.user_masals enable row level security;
create policy user_masals_read on public.user_masals for select to authenticated using (public.has_organisation_access(organisation_id));
create policy user_masals_admin_write on public.user_masals for all to authenticated using (public.has_organisation_role(organisation_id,array['super_admin'])) with check (public.has_organisation_role(organisation_id,array['super_admin']));
alter table public.user_roles enable row level security;
create policy user_roles_read on public.user_roles for select to authenticated using (public.has_organisation_access(organisation_id));
create policy user_roles_admin_write on public.user_roles for all to authenticated using (public.has_organisation_role(organisation_id,array['super_admin'])) with check (public.has_organisation_role(organisation_id,array['super_admin']));

grant usage on schema public to authenticated;
grant select,insert,update,delete on all tables in schema public to authenticated;
