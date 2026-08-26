# MALDI-TOF Sample Preparation — E-Learning Course

A self-contained e-learning site: 5 modules → final exam → PDF certificate → feedback survey, with an admin dashboard showing every learner's progress. Pure static HTML/CSS/JS (deployable free on GitHub Pages) backed by [Supabase](https://supabase.com) for accounts, progress tracking, and the database — no server to run yourself.

## How it works

- **Learners** sign up, work through the modules in order, mark each complete, then take the exam once all modules are done.
- The exam is **graded server-side** (inside Supabase, via a Postgres function) so the answer key is never sent to the browser and can't be inspected by a learner.
- Passing (≥80%, configurable) unlocks a certificate — a code + record is stored in the database, and a PDF is generated in-browser for download.
- The feedback survey is available once the exam is passed.
- **Admins** (any account you flag as `role = 'admin'`) see `/admin.html`: a live table of every learner's module completion, best exam score, pass status, certificate, and feedback status, with CSV export.

## One-time setup

### 1. Create a Supabase project

1. Go to [supabase.com](https://supabase.com) → New project (free tier is enough).
2. Once it's ready, open **SQL Editor** → New query, paste the entire contents of [`supabase/schema.sql`](supabase/schema.sql), and run it. This creates all tables, the exam-grading function, the admin view, and Row Level Security policies. It also seeds the 5 modules and the 12-question exam already written for this course.
3. Go to **Settings → API** and copy your **Project URL** and **anon public key**.
4. Paste them into `assets/js/supabase-client.js` (replace `YOUR-PROJECT-REF` and `YOUR-ANON-PUBLIC-KEY`).
5. Under **Authentication → Providers**, email/password is enabled by default. If you don't want learners to confirm their email before logging in, turn off "Confirm email" under **Authentication → Settings** (fine for an internal training tool).

### 2. Make yourself an admin

Sign up for an account on the live site first, then in Supabase's SQL Editor run:

```sql
update profiles set role = 'admin' where email = 'you@yourcompany.com';
```

You'll then see an "Admin" link on your dashboard and can visit `/admin.html`.

### 3. Push to GitHub and enable Pages

```bash
git init
git add .
git commit -m "Initial e-learning site"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPO.git
git push -u origin main
```

Then in the repo on GitHub: **Settings → Pages → Source: Deploy from a branch → main / (root)**. Your site will be live at `https://YOUR-USERNAME.github.io/YOUR-REPO/` within a minute or two.

## Editing the content

- Module text lives in `content/module-1.md` … `content/module-5.md` (plain Markdown, rendered client-side).
- Module titles/order/slugs are defined in `assets/js/modules-config.js` — **this must stay in sync with the `modules` table** in Supabase (same `id`s).
- To add/remove a module: add a row to the `modules` table (SQL Editor), add the matching entry to `MODULES` in `modules-config.js`, and add/remove the content file.

## Editing the exam

Exam questions and their correct answers live only in the `exam_questions` table in Supabase (never in the frontend code, by design). To change them:

```sql
-- edit a question
update exam_questions set question = '...', choices = '["A","B","C"]', correct_index = 0 where id = 3;

-- add a question
insert into exam_questions (question, choices, correct_index, sort_order)
values ('New question?', '["A","B","C"]', 1, 13);

-- change the pass mark (currently 80%) — edit `pass_mark` inside the submit_exam() function in schema.sql, then re-run just that function definition in the SQL Editor.
```

## Project structure

```
index.html          Sign in / sign up
dashboard.html       Learner home — module list, progress bar, next steps
module.html          Single module viewer (?slug=module-1)
exam.html            Final exam (server-graded)
certificate.html     Certificate view + PDF download
feedback.html        Post-course survey
admin.html           Admin-only learner overview table
content/*.md         Module content
assets/css/style.css Design system
assets/js/*          App logic (auth, Supabase client, module list)
supabase/schema.sql  Full database schema, security policies, exam grading, seed data
```

## Notes & limits

- This is a fully static site — GitHub Pages alone cannot store data, which is why Supabase (a free hosted Postgres + auth service) is used for accounts, progress, exam results, certificates, and feedback. The anon key in `supabase-client.js` is meant to be public; Row Level Security policies (in `schema.sql`) are what actually keep learners from reading or editing each other's data.
- Certificates are generated as PDFs in the learner's browser (via jsPDF) from data stored in Supabase — there's no email delivery built in. If you want certificates emailed automatically, that would need a small serverless function (e.g. a Supabase Edge Function) — ask if you'd like that added.
- The original MALDI-TOF SOP document didn't mark correct answers for its 12 quiz questions, so they were derived from the procedure text itself (e.g. "store at -20°C" → the "room temperature" question is False). Worth a quick sanity check against your own source document before going live.
