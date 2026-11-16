# Mahal Management System v1.0

React + TypeScript + Vite frontend with Supabase PostgreSQL/Auth and Cloudinary document uploads.

## Local setup

1. Install Node.js 20 or later and run `npm install`.
2. Copy `.env.example` to `.env.local` and fill `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, and `VITE_ORGANISATION_ID`. The browser key must be Supabase's anon/publishable key. Never put a service-role key in a `VITE_` variable.
3. In Supabase, apply these migrations in order using the SQL Editor: `202611140001_initial_schema.sql`, `202611140002_module_permissions_and_prayer.sql`, and `202611160003_operations_tables.sql`. If you have already applied earlier migrations, apply any later migration you have not run.
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

The app includes sign-in and password reset, live dashboard totals and charts, member and family profiles, relationship selectors, search, status/date/demographic filters, pagination, CSV and Excel import/export for family/member registers, report filtering and export, print-friendly profiles, and private Cloudinary document upload/download. Access is organisation-scoped with Supabase RLS; welfare and document categories have narrower role policies. First admin provisioning remains a one-time SQL operation in the setup steps above.

## Deploy to Vercel

Import `AzimDilshad/MSM-ETHICONE` from the Vercel dashboard. Vercel detects the Vite setup and uses `npm run build` with `dist` output; `vercel.json` includes the single-page app fallback. In the Vercel project settings, add these Environment Variables for Production (and Preview if needed): `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, and `VITE_ORGANISATION_ID`. Use the Supabase URL, public anon/publishable key, and organisation UUID from your local config. Do not add a Supabase service-role key or Cloudinary API secret to Vercel. After the first deploy, add the new Vercel domain under Supabase Authentication URL Configuration → Redirect URLs so password reset can return to the app.

## Demo data for a presentation

After creating your organisation and applying the migrations, open `supabase/seed_presentation.sql`, copy its contents into the Supabase SQL Editor, and run it. It seeds fictional wards, families, members, transactions, donations, events, and announcements for the most recently created organisation. It can be run again without duplicating those sample records. Review the selected organisation first if your project contains more than one Mahal.
