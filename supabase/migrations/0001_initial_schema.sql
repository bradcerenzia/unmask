-- =============================================================================
-- Unmask v1 — Initial Schema
-- =============================================================================

-- Enable required extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- =============================================================================
-- ENUMS
-- =============================================================================

create type employer_certification_tier as enum ('none', 'bronze', 'silver', 'gold');
create type listing_status as enum ('draft', 'active', 'closed');
create type application_status as enum ('applied', 'reviewing', 'rejected', 'offered');
create type employment_type as enum ('full_time', 'part_time', 'contract', 'internship');
create type work_location as enum ('remote', 'hybrid', 'onsite');
create type office_layout as enum ('open_office', 'mixed', 'private_offices', 'fully_remote');
create type communication_style as enum ('mostly_async', 'mixed', 'mostly_sync');
create type meeting_load as enum ('low', 'medium', 'high');
create type management_style as enum ('highly_structured', 'moderate', 'autonomous');
create type noise_level as enum ('quiet', 'moderate', 'loud');

-- =============================================================================
-- EMPLOYERS
-- =============================================================================

create table employers (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid references auth.users(id) on delete cascade not null,
  name                    text not null,
  slug                    text unique not null,
  website                 text,
  logo_url                text,
  description             text,

  -- Subscription / certification
  stripe_customer_id      text unique,
  stripe_subscription_id  text unique,
  subscription_active     boolean not null default false,
  certification_tier      employer_certification_tier not null default 'none',
  certification_expires_at timestamptz,
  audit_completed_at      timestamptz,

  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

-- =============================================================================
-- ENVIRONMENT PROFILES (one per employer, reused across listings)
-- =============================================================================

create table environment_profiles (
  id                      uuid primary key default gen_random_uuid(),
  employer_id             uuid references employers(id) on delete cascade not null,

  -- Physical environment
  office_layout           office_layout,
  noise_level             noise_level,
  lighting_control        boolean,     -- can employees adjust their lighting?
  fragrance_free_policy   boolean,
  dress_code_flexible     boolean,

  -- Work modality
  work_location           work_location,
  work_location_notes     text,        -- e.g. "3 days onsite required"

  -- Communication
  communication_style     communication_style,
  meeting_load            meeting_load,
  meeting_load_notes      text,        -- e.g. "avg 4 hrs/week of meetings"
  written_preferred       boolean,     -- written > verbal by default?

  -- Management
  management_style        management_style,
  feedback_cadence        text,        -- e.g. "weekly 1:1s"
  structure_provided      text,        -- e.g. "tasks broken into daily goals"

  -- Accommodation
  formal_accommodation_process boolean,
  accommodation_examples  text[],      -- brief examples the employer provided
  hr_nd_awareness         boolean,     -- HR trained on ND?

  -- Disclosure safety (self-reported; not a legal claim)
  disclosure_safety_score smallint check (disclosure_safety_score between 1 and 5),
  disclosure_safety_notes text,

  -- Trust signals
  data_source             text[] not null default array['employer_self_report'],
  -- values: 'employer_self_report', 'employee_reviews', 'nd_verified_audit'
  last_verified_at        timestamptz,

  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

-- =============================================================================
-- LISTINGS
-- =============================================================================

create table listings (
  id                      uuid primary key default gen_random_uuid(),
  employer_id             uuid references employers(id) on delete cascade not null,
  environment_profile_id  uuid references environment_profiles(id) on delete set null,

  -- Core listing data
  title                   text not null,
  slug                    text unique not null,
  description             text not null,   -- original, unmodified listing text
  employment_type         employment_type not null default 'full_time',
  work_location           work_location,
  location_city           text,
  location_country        text default 'US',
  salary_min              integer,         -- annual, USD
  salary_max              integer,
  apply_url               text,            -- external ATS link (null = native apply)

  -- AI-generated content
  translated_description  text,            -- Role Translation Layer output
  translation_generated_at timestamptz,
  translation_model       text,            -- e.g. "claude-sonnet-4-6"
  what_a_day_looks_like   text,            -- AI-generated if enough data

  status                  listing_status not null default 'draft',
  published_at            timestamptz,
  closes_at               timestamptz,

  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

-- =============================================================================
-- ENVIRONMENT TAGS (normalized tag taxonomy)
-- =============================================================================

create table environment_tags (
  id          uuid primary key default gen_random_uuid(),
  category    text not null,   -- e.g. 'sensory', 'communication', 'management'
  key         text not null,
  label       text not null,   -- display name
  description text,
  unique (category, key)
);

-- Junction: which tags apply to a listing (from environment profile + overrides)
create table listing_environment_tags (
  listing_id  uuid references listings(id) on delete cascade not null,
  tag_id      uuid references environment_tags(id) on delete cascade not null,
  value       text,            -- for range/score tags; null for boolean tags
  source      text not null default 'employer_self_report',
  primary key (listing_id, tag_id)
);

-- =============================================================================
-- JOB SEEKER PROFILES
-- =============================================================================

create table seeker_profiles (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid references auth.users(id) on delete cascade not null unique,

  -- Basic info
  display_name            text,
  headline                text,          -- e.g. "Former marketing manager, pivoting to UX"
  resume_url              text,

  -- Environment preferences (mirrors environment_profiles structure)
  preferred_work_location work_location[],
  preferred_communication communication_style,
  preferred_meeting_load  meeting_load,
  preferred_management    management_style,
  preferred_noise_level   noise_level,

  -- Burnout signals ("what drains you" framing)
  drains                  text[],        -- free-form phrases from onboarding wizard
  energizes               text[],

  -- ND self-identification (optional, never required)
  nd_self_identified      boolean not null default false,

  -- Job search state
  open_to_work            boolean not null default true,
  preferred_employment_type employment_type[],
  salary_min_expectation  integer,
  target_roles            text[],        -- e.g. ["UX Designer", "Product Designer"]

  onboarding_completed    boolean not null default false,

  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

-- Seeker environment tag preferences (mirrors listing_environment_tags)
create table seeker_tag_preferences (
  seeker_id   uuid references seeker_profiles(id) on delete cascade not null,
  tag_id      uuid references environment_tags(id) on delete cascade not null,
  weight      smallint not null default 3 check (weight between 1 and 5),
  -- 1 = nice-to-have, 5 = dealbreaker if absent
  primary key (seeker_id, tag_id)
);

-- =============================================================================
-- FIT SCORES (cached, recomputed on profile/listing change)
-- =============================================================================

create table fit_scores (
  id                  uuid primary key default gen_random_uuid(),
  seeker_id           uuid references seeker_profiles(id) on delete cascade not null,
  listing_id          uuid references listings(id) on delete cascade not null,
  score               smallint not null check (score between 0 and 100),
  breakdown           jsonb not null default '{}',
  -- e.g. {"communication": 90, "sensory": 60, "management": 80}
  computed_at         timestamptz not null default now(),
  unique (seeker_id, listing_id)
);

-- =============================================================================
-- APPLICATIONS
-- =============================================================================

create table applications (
  id              uuid primary key default gen_random_uuid(),
  seeker_id       uuid references seeker_profiles(id) on delete cascade not null,
  listing_id      uuid references listings(id) on delete cascade not null,
  status          application_status not null default 'applied',
  cover_note      text,
  ai_prep_note    text,    -- AI-generated "what to watch for" note
  applied_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (seeker_id, listing_id)
);

-- =============================================================================
-- EMPLOYEE REVIEWS (anonymous, employer-blind)
-- =============================================================================

create table employee_reviews (
  id                  uuid primary key default gen_random_uuid(),
  employer_id         uuid references employers(id) on delete cascade not null,
  -- No user_id link — fully anonymous. Token issued at submission time.
  submission_token    text unique not null default replace(gen_random_uuid()::text, '-', ''),

  -- Structured ratings
  nd_friendliness     smallint check (nd_friendliness between 1 and 5),
  disclosure_safety   smallint check (disclosure_safety between 1 and 5),
  management_rating   smallint check (management_rating between 1 and 5),
  accommodation_rating smallint check (accommodation_rating between 1 and 5),

  -- Free-text
  what_worked         text,
  what_to_watch       text,

  -- Moderation
  approved            boolean not null default false,
  flagged             boolean not null default false,

  created_at          timestamptz not null default now()
);

-- =============================================================================
-- UPDATED_AT TRIGGERS
-- =============================================================================

create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger employers_updated_at before update on employers
  for each row execute function set_updated_at();
create trigger environment_profiles_updated_at before update on environment_profiles
  for each row execute function set_updated_at();
create trigger listings_updated_at before update on listings
  for each row execute function set_updated_at();
create trigger seeker_profiles_updated_at before update on seeker_profiles
  for each row execute function set_updated_at();
create trigger applications_updated_at before update on applications
  for each row execute function set_updated_at();

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

alter table employers enable row level security;
alter table environment_profiles enable row level security;
alter table listings enable row level security;
alter table seeker_profiles enable row level security;
alter table seeker_tag_preferences enable row level security;
alter table fit_scores enable row level security;
alter table applications enable row level security;
alter table employee_reviews enable row level security;

-- Employers: only the owning user can read/write their employer record
create policy "employers: owner full access"
  on employers for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Environment profiles: employer owner can manage; anyone can read
create policy "environment_profiles: public read"
  on environment_profiles for select
  using (true);
create policy "environment_profiles: employer owner write"
  on environment_profiles for all
  using (
    exists (
      select 1 from employers e
      where e.id = environment_profiles.employer_id
        and e.user_id = auth.uid()
    )
  );

-- Listings: anyone can read active listings; employer owner can manage
create policy "listings: public read active"
  on listings for select
  using (status = 'active');
create policy "listings: employer owner full access"
  on listings for all
  using (
    exists (
      select 1 from employers e
      where e.id = listings.employer_id
        and e.user_id = auth.uid()
    )
  );

-- Seeker profiles: only the owning user
create policy "seeker_profiles: owner full access"
  on seeker_profiles for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Seeker tag preferences: only the owning seeker
create policy "seeker_tag_preferences: owner full access"
  on seeker_tag_preferences for all
  using (
    exists (
      select 1 from seeker_profiles sp
      where sp.id = seeker_tag_preferences.seeker_id
        and sp.user_id = auth.uid()
    )
  );

-- Fit scores: only the seeker who owns them
create policy "fit_scores: seeker read own"
  on fit_scores for select
  using (
    exists (
      select 1 from seeker_profiles sp
      where sp.id = fit_scores.seeker_id
        and sp.user_id = auth.uid()
    )
  );

-- Applications: seeker sees own; employer sees applications to their listings
create policy "applications: seeker sees own"
  on applications for all
  using (
    exists (
      select 1 from seeker_profiles sp
      where sp.id = applications.seeker_id
        and sp.user_id = auth.uid()
    )
  );
create policy "applications: employer sees their listing applications"
  on applications for select
  using (
    exists (
      select 1 from listings l
      join employers e on e.id = l.employer_id
      where l.id = applications.listing_id
        and e.user_id = auth.uid()
    )
  );

-- Employee reviews: approved reviews are public; nobody can see their own token
create policy "employee_reviews: public read approved"
  on employee_reviews for select
  using (approved = true);

-- =============================================================================
-- INDEXES
-- =============================================================================

create index listings_employer_id_idx on listings(employer_id);
create index listings_status_idx on listings(status);
create index listings_published_at_idx on listings(published_at desc);
create index fit_scores_seeker_id_idx on fit_scores(seeker_id);
create index fit_scores_listing_id_idx on fit_scores(listing_id);
create index applications_seeker_id_idx on applications(seeker_id);
create index applications_listing_id_idx on applications(listing_id);
create index employee_reviews_employer_id_idx on employee_reviews(employer_id);
