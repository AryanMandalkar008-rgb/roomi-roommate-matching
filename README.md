# Roomi

Roomi is an online-only roommate matching app. There are no demo users or local fake-data sign-ins. Supabase Auth protects accounts; Supabase Postgres, Storage, and row-level security hold profiles, private contact details, likes, messages, notifications, and profile photos. Vercel serves the Vite frontend with security headers.

## Start locally

1. Install Node.js 20.19 or newer and npm.
2. Create a Supabase project and run `supabase.sql` in its SQL Editor.
3. Copy `.env.example` to `.env.local` and set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` to the project URL and publishable/anon browser key. Never use a `service_role` key in frontend variables.
4. Run `npm install`, then `npm run dev`.

If the Supabase values are missing, the page shows a setup notice and does not load a demo or let anyone sign in.

## Deploy on Vercel

1. Push this repository to a Git provider and import it from the Vercel dashboard.
2. Set the project framework to Vite (detected automatically), build command `npm run build`, and output directory `dist`.
3. Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` under Vercel Project Settings → Environment Variables for Production and Preview.
4. Deploy, then add the production domain to Supabase Authentication → URL Configuration (Site URL and Redirect URLs). Set the Supabase Site URL to the Vercel production URL.
5. In Supabase Auth, keep email confirmation enabled for production and configure your own SMTP sender and email templates. Set the app URL as the password recovery redirect URL.

The Supabase publishable/anon key is meant for browser clients. Database RLS is the access boundary; never expose the Supabase service-role secret.

## Create the real admin account

1. Open the deployed app and choose **Create an account**. Register with the admin's own email and a unique password. Confirm the address using the Supabase email.
2. In Supabase SQL Editor, run the admin promotion statement at the bottom of `supabase.sql`, replacing the example email with that exact address.
3. Sign out and sign back in. The **Admin studio** navigation and management dashboard appear only when the database profile has the `admin` role.

Roomi does not have a shared built-in admin password. The account owner chooses and keeps the password; Supabase Auth stores password hashes. Do not put admin passwords in source code or Vercel environment variables.

## Free non-commercial testing

This project is configured for your chosen **Vercel Hobby + Supabase Free** test setup. Vercel Hobby is free for personal, non-commercial use only. Supabase Free currently lists 500 MB database, 1 GB file storage, and 50,000 monthly active users. Free projects can pause after a week of low activity and do not include automatic backups. Check current quotas in both dashboards while testing. These free plans are not a commercial production setup.

## Security included

- Authenticated sessions gate every in-app view; the admin route also checks the stored profile role.
- Database tables use row-level security. Users can edit their own profiles, see their own notifications and conversations, and only access private contact details as owner/admin/mutual match.
- Admin actions use database policies, not a client-provided role alone.
- Vercel response headers set a restrictive content policy, HTTPS transport, no framing, and safer referrer/permissions defaults.
- Browser code uses only the Supabase public key. Passwords are handled by Supabase Auth rather than client-side hashing.

Before accepting real housing-related user data, add a reviewed privacy notice/terms, moderation and report flows, account deletion/data export, secure support contact, configured email delivery, and a recovery/incident process. Supabase Free has no automatic database backups.
