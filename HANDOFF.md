# Unmask — Handoff to Nate

Hey Nate! This document tells you everything you need to know to take ownership of this project and keep building it. It's written for someone who is new to Claude Code and the tools involved. Read it top to bottom once, then use the kickoff prompt at the bottom to start your first Claude session.

---

## Table of Contents

1. [What Unmask Is](#1-what-unmask-is)
2. [What's Already Been Built](#2-whats-already-been-built)
3. [The Tech Stack, Explained](#3-the-tech-stack-explained)
4. [Accounts You Need to Create](#4-accounts-you-need-to-create)
5. [Step-by-Step: Getting the Code](#5-step-by-step-getting-the-code)
6. [Step-by-Step: Supabase Setup](#6-step-by-step-supabase-setup)
7. [Step-by-Step: Anthropic API Key](#7-step-by-step-anthropic-api-key)
8. [Step-by-Step: Stripe Setup](#8-step-by-step-stripe-setup)
9. [Step-by-Step: Railway (Hosting)](#9-step-by-step-railway-hosting)
10. [Step-by-Step: Cloudflare (Domain)](#10-step-by-step-cloudflare-domain)
11. [Wiring Everything Together](#11-wiring-everything-together)
12. [How to Use Claude Code](#12-how-to-use-claude-code)
13. [Your First Session Kickoff Prompt](#13-your-first-session-kickoff-prompt)

---

## 1. What Unmask Is

Unmask is a job platform for neurodivergent (ND) career changers — people with ADHD, autism, dyslexia, and related conditions who are deliberately switching careers after burning out in wrong-fit roles.

The core insight: most job boards focus on skills. Unmask focuses on **environment fit** — does the actual workplace (noise level, meeting culture, communication style, management approach) match how this person's brain works?

**Business model: employers pay, job seekers search free.**

The four headline features:
- **ND-Fit Score** — a 0–100 match score on every listing based on the seeker's environment preferences vs. the role's actual conditions
- **Workplace Environment Profiler** — structured tags on every listing describing real working conditions (not just "fast-paced culture")
- **ND Verified badge** — employers earn a Bronze/Silver/Gold badge by completing an audit of their ND-friendliness; this is the subscription product
- **Role Translation Layer** — Claude AI rewrites job listings in plain, honest language and flags neurotypical code phrases like "self-starter" and "culture fit"

The full product vision is in [`PRD.md`](./PRD.md).

---

## 2. What's Already Been Built

Here's what exists in the codebase right now:

### Foundation
- **Next.js 15 app** with TypeScript, Tailwind CSS, and ESLint — the full modern web app framework
- **Supabase wired up** — database client for both browser and server components, plus authentication middleware

### Database (live in Supabase)
The full schema is already pushed to a Supabase project. It includes 10 tables:

| Table | What it stores |
|---|---|
| `employers` | Company accounts, Stripe subscription info, certification tier |
| `environment_profiles` | Structured workplace data — noise, layout, comms style, accommodation posture |
| `listings` | Job postings + the AI-translated version |
| `environment_tags` | The tag taxonomy (categories like "sensory", "communication", "management") |
| `listing_environment_tags` | Which tags apply to which listing |
| `seeker_profiles` | Job seeker preferences, "what drains you" data, no diagnosis required |
| `seeker_tag_preferences` | Per-tag importance weights for the Fit Score |
| `fit_scores` | Cached 0–100 scores per seeker × listing pair |
| `applications` | Application tracking + AI-generated prep notes |
| `employee_reviews` | Fully anonymous employer reviews |

Row Level Security (RLS) is enabled — users can only see their own data.

### UI (stubbed with demo data, no real login required yet)
- **Nav** — Cloudflare-inspired fixed top bar, responsive hamburger menu on mobile, blue/navy color scheme
- **Homepage** — hero section with headline, subhead, two CTAs, and three feature cards
- **Employer onboarding** — 4-step flow: Company Info → Environment Disclosure → ND Verified opt-in → Confirmation. Pre-filled with "Meridian Health Systems" demo data so you can click through the whole thing.

### What's NOT built yet
- Job listings browse page (the main seeker experience)
- Supabase Auth (sign up / sign in — works structurally but no UI)
- Saving real data from the onboarding form to the database
- The Fit Score algorithm
- The Role Translation Layer (Claude API call)
- Stripe subscription flow
- Employer dashboard (post/manage listings)
- Seeker profile wizard

---

## 3. The Tech Stack, Explained

You don't need to be an expert in these. Here's what each one does in plain English:

**Next.js** — the web framework. Handles routing, pages, and server-side logic. Think of it as the skeleton of the app.

**TypeScript** — JavaScript with types. Catches bugs before you run the code. You'll write `.ts` and `.tsx` files.

**Tailwind CSS** — a styling system. Instead of writing CSS files, you add class names directly to HTML elements like `className="text-blue-600 font-bold"`.

**Supabase** — your database + authentication + storage, all in one hosted service. Postgres under the hood. You interact with it through a simple JavaScript SDK.

**Claude API (Anthropic)** — the AI that powers the Role Translation Layer. You send it a job listing, it sends back a plain-language rewrite.

**Stripe** — handles employer subscriptions and payments. Never store card numbers yourself — Stripe does that.

**Railway** — hosts your app. You push code to GitHub, Railway detects it and deploys automatically. Think Heroku but modern.

**Cloudflare** — manages your domain (DNS) and acts as a security/performance layer in front of Railway. When someone visits `unmask.com`, Cloudflare routes them to Railway.

---

## 4. Accounts You Need to Create

Create all of these before your first coding session. Free tiers are fine to start.

| Service | URL | Notes |
|---|---|---|
| GitHub | github.com | Where the code lives |
| Supabase | supabase.com | Database + auth |
| Anthropic | console.anthropic.com | Claude API key |
| Stripe | stripe.com | Payments (use test mode to start) |
| Railway | railway.app | Hosting |
| Cloudflare | cloudflare.com | Domain + DNS |
| A domain registrar | namecheap.com or similar | Buy your domain here, then point it to Cloudflare |

---

## 5. Step-by-Step: Getting the Code

The code lives at: **https://github.com/bradcerenzia/unmask**

You'll want to fork it to your own GitHub account so you own it going forward.

1. Go to https://github.com/bradcerenzia/unmask
2. Click **Fork** in the top right → Fork to your own account
3. On your computer, open Terminal and run:
   ```bash
   git clone https://github.com/YOUR_USERNAME/unmask.git
   cd unmask
   npm install
   ```
4. Copy the environment file:
   ```bash
   cp .env.local.example .env.local
   ```
5. You'll fill in `.env.local` with your own API keys as you complete the steps below.

---

## 6. Step-by-Step: Supabase Setup

The existing Supabase project belongs to Brad's account. You need your own.

1. Go to [supabase.com](https://supabase.com) and create a free account
2. Click **New project**, give it a name (`unmask`), choose a region close to you, set a database password (save it somewhere)
3. Once it spins up (takes ~1 min), go to **Project Settings → API**
4. Copy these values into your `.env.local`:
   - **Project URL** → `NEXT_PUBLIC_SUPABASE_URL`
   - **anon public key** → `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - **service_role key** → `SUPABASE_SERVICE_ROLE_KEY` (keep this secret — never expose it in the browser)
5. Push the database schema:
   - Install the Supabase CLI: `brew install supabase/tap/supabase`
   - Run: `supabase link --project-ref YOUR_PROJECT_REF`
   - Run: `supabase db push --dns-resolver https`
   - Your project ref is the string in your Supabase project URL: `https://supabase.com/dashboard/project/YOUR_PROJECT_REF`

---

## 7. Step-by-Step: Anthropic API Key

1. Go to [console.anthropic.com](https://console.anthropic.com)
2. Sign up or log in
3. Go to **API Keys** → **Create Key**
4. Copy the key into `.env.local` as `ANTHROPIC_API_KEY`
5. Note: the API costs money per use — very cheap for development, but add a spending limit in the console so you don't get surprised

---

## 8. Step-by-Step: Stripe Setup

1. Go to [stripe.com](https://stripe.com) and create an account
2. In the Stripe dashboard, make sure you're in **Test mode** (toggle in the top left)
3. Go to **Developers → API Keys**
4. Copy into `.env.local`:
   - **Publishable key** → `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`
   - **Secret key** → `STRIPE_SECRET_KEY`
5. For the webhook secret (`STRIPE_WEBHOOK_SECRET`): you'll set this up later when you add the Stripe webhook endpoint. Skip for now.
6. When you're ready to go live, you'll switch to live mode keys — but test mode is fine for all of development.

---

## 9. Step-by-Step: Railway (Hosting)

Railway is where your app runs on the internet.

1. Go to [railway.app](https://railway.app) and sign up with your GitHub account
2. Click **New Project → Deploy from GitHub repo**
3. Select your forked `unmask` repo
4. Railway will detect it's a Next.js app and configure it automatically
5. Go to your project → **Variables** and add all the same key/value pairs from your `.env.local` file (Railway needs them to run the app)
6. Railway gives you a free `.railway.app` subdomain to start — use that until you have a real domain

**Important:** Railway redeploys automatically every time you push to your `main` branch on GitHub. So your workflow is: write code → push to GitHub → Railway deploys it.

---

## 10. Step-by-Step: Cloudflare (Domain)

Cloudflare sits between your domain and Railway, adding speed and security for free.

1. Buy a domain from a registrar (Namecheap, Google Domains, etc.). Something like `unmaskjobs.com` or `tryunmask.com`.
2. Go to [cloudflare.com](https://cloudflare.com) and create a free account
3. Click **Add a site** → enter your domain
4. Cloudflare will scan your existing DNS records. Follow the prompts.
5. Update your domain's **nameservers** at your registrar to point to Cloudflare's nameservers (Cloudflare tells you what they are). This takes up to 24 hours to propagate.
6. Once active, go to **DNS → Add record**:
   - Type: `CNAME`
   - Name: `@` (or your subdomain)
   - Target: your Railway app URL (e.g. `unmask.up.railway.app`)
   - Proxied: ON (the orange cloud)
7. In Railway, go to your project → **Settings → Domains** → add your custom domain

That's it. Cloudflare handles SSL certificates automatically.

---

## 11. Wiring Everything Together

Once all accounts are set up, here's the full data flow:

```
User visits unmask.com
    ↓
Cloudflare (DNS + security layer)
    ↓
Railway (hosts the Next.js app)
    ↓
Next.js app
    ├── Supabase (database + auth)
    ├── Anthropic Claude API (AI rewrites)
    └── Stripe (payments)
```

Your `.env.local` file is what connects all of these locally. Railway's environment variables do the same in production. **Never commit `.env.local` to GitHub** — it's already in `.gitignore`.

---

## 12. How to Use Claude Code

Claude Code is a coding assistant that lives in your terminal. It reads your codebase, writes code, runs commands, and has a real conversation with you about what to build.

**Installing it:**
```bash
npm install -g @anthropic-ai/claude-code
```
Then run `claude` in your project folder.

**The golden rule:** The more context you give Claude, the better the output. Don't just say "build the login page." Say:
> "Build the login page for Unmask. It should match the existing nav and color scheme (navy `#0B1829`, blue `#2563EB`). Use Supabase Auth for sign-in — the client is at `src/lib/supabase/client.ts`. Redirect to `/dashboard` after login. Match the style of the existing employer onboarding page at `src/app/employers/onboard/page.tsx`."

**Starting a new session:** Claude doesn't remember previous conversations. Each new session starts fresh. That's why this handoff document exists — paste the kickoff prompt below at the start of every new session to bring Claude up to speed instantly.

**What Claude is great at:**
- Writing boilerplate and repetitive code
- Wiring up APIs you've never used before
- Explaining errors and fixing bugs
- Scaffolding entire features from a description
- Refactoring and cleaning up code

**What to watch for:**
- Always review code before committing — Claude can make mistakes
- If Claude seems confused, start a new session with a clearer prompt
- For big features, describe the goal and ask Claude to propose a plan before it starts coding

---

## 13. Your First Session Kickoff Prompt

Copy and paste this entire block into a new Claude Code session. It gives Claude full context to pick up exactly where development left off.

---

> I'm building **Unmask** — a job platform for neurodivergent career changers. The PRD is at `PRD.md` — read it first before doing anything.
>
> **What's already been built:**
> - Next.js 15 (App Router) + TypeScript + Tailwind — fully scaffolded
> - Supabase wired up: browser client at `src/lib/supabase/client.ts`, server client at `src/lib/supabase/server.ts`, auth middleware at `src/middleware.ts`
> - Full database schema live in Supabase — 10 tables covering employers, environment profiles, listings, environment tags, seeker profiles, fit scores, applications, and employee reviews. Schema file is at `supabase/migrations/0001_initial_schema.sql`. TypeScript types are at `src/types/database.ts`.
> - Nav component at `src/components/Nav.tsx` — Cloudflare-style fixed top bar, mobile hamburger drawer, blue/navy color scheme (`#0B1829` navy, `#2563EB` blue, `#94A3B8` silver)
> - Homepage at `src/app/page.tsx` — hero + 3 feature cards
> - Employer onboarding at `src/app/employers/onboard/page.tsx` — 4-step flow, stubbed with demo data, no real database writes yet
>
> **Stack:** Next.js 15 App Router + TypeScript, Supabase (Postgres + Auth + RLS), Claude API (Anthropic), Railway, Stripe.
>
> **What to build next:** The job listings browse page. This is the core seeker experience — a filterable list/grid of job cards showing:
> - The listing title, company, location, salary range
> - ND-Fit Score badge (0–100, color-coded: green 80+, yellow 60–79, red below 60)
> - Environment tags (3–4 key tags like "Remote", "Low meetings", "Async-first")
> - ND Verified badge if the employer has one (Bronze/Silver/Gold)
> - A toggle on each card to flip between the original listing description and the AI-translated plain-language version
>
> Stub it with 5–6 realistic listings (different industries, scores, and certification levels) so the UI looks real and we can feel the product. No real API calls yet — hardcoded demo data is fine.
>
> The design should match the existing nav and color system. Keep it responsive — desktop shows a two-column grid, mobile shows single column.
>
> Start by reading `src/app/page.tsx` and `src/components/Nav.tsx` to understand the existing style, then build `src/app/jobs/page.tsx`.

---

Good luck, Nate. The product is real and the foundation is solid. Go build it.
