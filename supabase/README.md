# Supabase backend (free, no credit card)

This powers the **in-app parent dashboard**: each child phone writes location +
screen time to Supabase, and the parent phone reads it back. Data is private to
your family account and only the last 3 days are kept.

## One-time setup (in the browser)

1. Go to **https://supabase.com** → sign up (no card) → **New project**.
   - Give it a name and a database password → create. Wait ~2 minutes.
2. **SQL Editor → New query** → paste the contents of **`schema.sql`** (in this
   folder) → **Run**. This creates the tables and privacy rules.
3. Create the shared **family account**:
   - **Authentication → Providers →** make sure **Email** is enabled.
   - **Authentication → Users → Add user** → enter an email + password you'll
     remember. (Disable "email confirmation" for that user, or turn off
     "Confirm email" under Authentication → Providers → Email, so it can sign
     in immediately.)
4. Get your connection details: **Project Settings → API**:
   - **Project URL** (looks like `https://xxxx.supabase.co`)
   - **anon public** key (a long `eyJ...` string — this one is safe to put in
     the app; it only allows what the privacy rules permit)

## Enter it in the app

Use the **same 4 values on every phone** (parent and each child):

- **Project URL**, **Anon public key**, **Family email**, **Family password**

Where:
- **Parent phone:** Parent screen → *Family Dashboard (Supabase)* → **Supabase
  setup** → fill in → **Save** → **Test** (should say "Connected").
- **Each child phone:** Child screen → **Supabase setup (optional)** → same
  values → Save.

Then on a child phone tap **Grant Access & Start**. Within ~15 minutes its data
appears on the parent phone under **Open Family Dashboard**.

## Notes

- The **anon key is meant to be public** (it ships inside the app). Security
  comes from Row Level Security + the family login, so only someone with the
  email/password can read your data.
- Free tier is far more than enough for a family (location every 15 min).
- Retention: the app deletes rows older than 3 days automatically.
