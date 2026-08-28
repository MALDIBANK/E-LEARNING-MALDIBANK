-- ============================================================
-- E-LEARNING PLATFORM — SUPABASE SCHEMA
-- Run this once in your Supabase project: SQL Editor > New query > paste > Run
-- ============================================================

-- ---------- PROFILES ----------
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  role text not null default 'learner' check (role in ('learner','admin')),
  created_at timestamptz default now()
);

-- Auto-create a profile row whenever someone signs up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, role)
  values (new.id, new.raw_user_meta_data->>'full_name', new.email, 'learner');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Helper used by RLS policies below
create or replace function public.is_admin()
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

-- ---------- MODULES ----------
create table if not exists modules (
  id int primary key,
  slug text unique not null,
  title text not null,
  sort_order int not null
);

insert into modules (id, slug, title, sort_order) values
  (1, 'module-1', 'Introduction, Safety & Materials', 1),
  (2, 'module-2', 'Sample Prep — Yeast & Filamentous Fungi', 2),
  (3, 'module-3', 'Sample Prep — Bacteria', 3),
  (4, 'module-4', 'Preparing the MALDI-TOF Target Plate', 4),
  (5, 'module-5', 'Cleaning Reusable Target Plates', 5)
on conflict (id) do nothing;

-- ---------- PROGRESS ----------
create table if not exists progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  module_id int references modules(id),
  completed_at timestamptz default now(),
  unique(user_id, module_id)
);

-- ---------- EXAM QUESTIONS (correct answers never exposed to learners) ----------
create table if not exists exam_questions (
  id serial primary key,
  question text not null,
  choices jsonb not null,       -- e.g. ["Option A","Option B","Option C","Option D"]
  correct_index int not null,   -- 0-based index into choices
  sort_order int not null
);

-- Learner-safe view: no correct_index column
create or replace view exam_questions_public as
  select id, question, choices, sort_order from exam_questions order by sort_order;

-- Final exam for the MALDI-TOF sample-preparation course
insert into exam_questions (question, choices, correct_index, sort_order) values
  ('Which of the following are the required health & safety procedures for this SOP?',
   '["Lab coat and gloves during practical work, work in a microbial biosafety cabinet, and use a chemical fume hood for TFA cleaning","A lab coat only, no other precautions needed","Safety goggles and a biosafety cabinet only","No special precautions are required"]', 0, 1),
  ('For yeast and filamentous fungi, if growth is too limited after 3 days, extend the incubation until sufficient material is available.',
   '["True","False"]', 0, 2),
  ('How many washes are needed for sample preparation of yeast and filamentous fungi using solid culture media?',
   '["1x with 300 µl ultrapure water and 900 µl ethanol","1x with 300 µl ultrapure water only","1x with 900 µl ethanol only"]', 0, 3),
  ('How many washes with water alone must be done for sample preparation of filamentous fungi using liquid culture media?',
   '["2","3","4"]', 1, 4),
  ('Sample preparation for bacteria can be done using both liquid and solid culture media.',
   '["True","False"]', 0, 5),
  ('For sample preparation from bacteria (solid or liquid media), there is only one washing step using 300 µl of ultrapure water and 900 µl of ethanol.',
   '["True","False"]', 0, 6),
  ('It is acceptable to have a damp pellet prior to adding formic acid.',
   '["True","False"]', 0, 7),
  ('The volume of formic acid and acetonitrile can be adjusted according to the size of the pellet.',
   '["True","False"]', 0, 8),
  ('The volumes added of formic acid and acetonitrile do not have to be the same.',
   '["True","False"]', 1, 9),
  ('You can store the extract at room temperature until further analysis.',
   '["True","False"]', 1, 10),
  ('What volume of HCCA matrix is used to overlay the spots with dried extracts?',
   '["0.5 µl","1 µl","1.5 µl"]', 1, 11),
  ('Which reagents/solutions are used to clean reusable target plates?',
   '["70% Ethanol","80% TFA","Acetone","Water","All of the above"]', 4, 12)
on conflict do nothing;

-- ---------- EXAM ATTEMPTS ----------
create table if not exists exam_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  score numeric not null,
  passed boolean not null,
  answers jsonb,
  submitted_at timestamptz default now()
);

-- Server-side grading so answer keys never reach the browser
create or replace function public.submit_exam(p_answers jsonb)
returns table(score numeric, passed boolean)
language plpgsql
security definer set search_path = public
as $$
declare
  total int;
  correct int := 0;
  q record;
  ans int;
  pass_mark numeric := 0.8; -- 80% to pass — change as needed
  computed_score numeric;
  did_pass boolean;
begin
  select count(*) into total from exam_questions;
  if total = 0 then
    raise exception 'No exam questions configured';
  end if;

  for q in select id, correct_index from exam_questions loop
    ans := (p_answers ->> q.id::text)::int;
    if ans = q.correct_index then
      correct := correct + 1;
    end if;
  end loop;

  computed_score := round((correct::numeric / total::numeric) * 100, 1);
  did_pass := computed_score >= (pass_mark * 100);

  insert into exam_attempts(user_id, score, passed, answers)
  values (auth.uid(), computed_score, did_pass, p_answers);

  return query select computed_score, did_pass;
end;
$$;

grant execute on function public.submit_exam(jsonb) to authenticated;

-- ---------- CERTIFICATES ----------
create table if not exists certificates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade unique,
  certificate_code text unique not null,
  issued_at timestamptz default now()
);

-- ---------- FEEDBACK SURVEY ----------
create table if not exists feedback_responses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  ratings jsonb,
  comments text,
  submitted_at timestamptz default now()
);

-- ---------- ADMIN OVERVIEW (one row per learner) ----------
create or replace view admin_learner_overview as
select
  p.id as user_id,
  p.full_name,
  p.email,
  p.created_at as signed_up_at,
  (select count(*) from progress pr where pr.user_id = p.id) as modules_completed,
  (select count(*) from modules) as modules_total,
  (select max(score) from exam_attempts ea where ea.user_id = p.id) as best_exam_score,
  (select bool_or(passed) from exam_attempts ea where ea.user_id = p.id) as exam_passed,
  (select count(*) from exam_attempts ea where ea.user_id = p.id) as exam_attempts_count,
  c.certificate_code,
  c.issued_at as certificate_issued_at,
  (select count(*) from feedback_responses f where f.user_id = p.id) > 0 as feedback_submitted
from profiles p
left join certificates c on c.user_id = p.id
where p.role = 'learner';

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table profiles enable row level security;
alter table modules enable row level security;
alter table exam_questions enable row level security;
alter table exam_attempts enable row level security;
alter table progress enable row level security;
alter table certificates enable row level security;
alter table feedback_responses enable row level security;

-- profiles
create policy "own profile select" on profiles for select using (auth.uid() = id or is_admin());
create policy "own profile update" on profiles for update using (auth.uid() = id);

-- modules: any signed-in learner can read; only admins write
create policy "modules readable" on modules for select using (auth.role() = 'authenticated');
create policy "modules admin write" on modules for all using (is_admin());

-- exam_questions: admin only (learners use exam_questions_public view instead)
create policy "exam_questions admin only" on exam_questions for all using (is_admin());

-- exam_attempts
create policy "own attempts select" on exam_attempts for select using (auth.uid() = user_id or is_admin());
-- inserts happen only via the submit_exam() function (security definer), not directly by learners

-- progress
create policy "own progress select" on progress for select using (auth.uid() = user_id or is_admin());
create policy "own progress insert" on progress for insert with check (auth.uid() = user_id);

-- certificates
create policy "own certificate select" on certificates for select using (auth.uid() = user_id or is_admin());
create policy "own certificate insert" on certificates for insert with check (auth.uid() = user_id);

-- feedback
create policy "own feedback select" on feedback_responses for select using (auth.uid() = user_id or is_admin());
create policy "own feedback insert" on feedback_responses for insert with check (auth.uid() = user_id);

-- admin_learner_overview view: relies on RLS of underlying tables (profiles select policy already checks is_admin() for other people's rows)
