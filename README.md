# Mahal Management System v1.0

React + TypeScript + Vite frontend with Supabase PostgreSQL/Auth and Cloudinary document uploads.

## Local setup

1. Install Node.js 20 or later and run `npm install`.
2. Copy `.env.example` to `.env.local` and fill `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, and `VITE_ORGANISATION_ID`. The browser key must be Supabase's anon/publishable key. Never put a service-role key in a `VITE_` variable.
3. In Supabase, apply `supabase/migrations/202611140001_initial_schema.sql` using the SQL Editor. If you already applied it, apply `202611140002_module_permissions_and_prayer.sql` as well to add prayer scheduling, role-based private documents, and read-only auditor rules.
4. Create an organisation and first admin membership. After creating the admin user in Supabase Auth, run this once as the project owner in SQL Editor, replacing the sample values:

```sql
insert into public.organisations (id, name) values ('YOUR_ORGANISATION_UUID', 'Your Mahal');
insert into public.user_masals (user_id, organisation_id)
values ('YOUR_AUTH_USER_UUID', 'YOUR_ORGANISATION_UUID');
insert into public.user_roles (user_id, organisation_id, role_id)
select 'YOUR_AUTH_USER_UUID', 'YOUR_ORGANISATION_UUID', id
from public.roles where name = 'super_admin';
```

Set `VITE_ORGANISATION_ID` to that organisation UUID, then run `npm run dev`.

## Cloudinary document uploads

1. Create a Cloudinary account and obtain its cloud name, API key, and API secret.
2. Set `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, and `CLOUDINARY_API_SECRET` as Supabase Edge Function secrets. For example, use `supabase secrets set CLOUDINARY_CLOUD_NAME=... CLOUDINARY_API_KEY=... CLOUDINARY_API_SECRET=...` from a trusted terminal. Do not add these secrets to `.env.local` or React.
3. Deploy both `supabase/functions/create-document-upload` and `supabase/functions/create-document-download`.
4. Sign in with an account that has an organisation membership. Uploads are limited to 10 MB and use Cloudinary's authenticated asset type; the Edge Function verifies the Supabase session and organisation membership before signing.

## Supabase CLI deployment on Windows

Run these in a second terminal, from this project directory. Keep the Vite terminal running. The Supabase CLI is run locally through `npx`, so a global `supabase` command is not required:

```powershell
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase functions deploy create-document-upload
npx supabase functions deploy create-document-download
```

If `npx` asks to install Supabase CLI, accept. The project ref is the subdomain in `https://YOUR_PROJECT_REF.supabase.co`.

The app includes sign-in and password reset, live dashboard totals, searchable and paginated CRUD screens for the core Mahal records, CSV export of the visible page, and private Cloudinary document upload and authorized download links. Access is isolated by organisation membership and Supabase RLS. First admin provisioning remains a one-time SQL operation in the setup steps above.

## Demo data for a presentation

After creating your organisation and applying the migrations, open `supabase/seed_presentation.sql`, copy its contents into the Supabase SQL Editor, and run it. It seeds fictional wards, families, members, transactions, donations, events, and announcements for the most recently created organisation. It can be run again without duplicating those sample records. Review the selected organisation first if your project contains more than one Mahal.
