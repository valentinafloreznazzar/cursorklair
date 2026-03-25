# Cursor Hackathon · IE University · March 2026

**Organized by TechIE x Building and Tech · Sponsored by Cursor**

## 1. Overview

This repository is your starting point for the hackathon.

Your flow is simple.

1. Clone this repo
2. Build your project during the event
3. Deploy it on Vercel
4. Submit it through the Google Form
5. Present it live

This repo is here to help you move quickly from idea to deployment.

## 2. The Challenge

**Make one person’s hard day easier.**

This challenge is intentionally open to interpretation.

You are not being asked to build one specific type of product. You are being asked to identify a real person, understand what makes their day difficult, and build something that helps in a meaningful way.

The strongest projects will be grounded in a real situation, focused in scope, and clear in their usefulness.

Read the full brief and rubric in [CHALLENGE.md](./CHALLENGE.md).

## 3. Who Can Participate

1. Solo participants or teams of up to 4
2. No technical background required
3. All participants receive Cursor credits

You do not need to be an experienced developer to participate. If you can clearly describe what should exist, you can use this hackathon to build it.

## 4. Rules

1. Your project must be built during the event
2. Your project must be deployed on Vercel
3. Your final submission must include a live link
4. Teams may have up to 4 people
5. Solo participation is allowed

## 5. Evaluation Rubric

Projects will be evaluated based on the rubric in [CHALLENGE.md](./CHALLENGE.md), with particular attention to the following areas:

1. Understanding of the person and problem
2. Relevance and usefulness
3. Quality of execution
4. Creativity and interpretation
5. Use of tools to extend what was possible
6. Presentation and storytelling

## 6. How to Use This Repo

### 6.1 Clone the repository

```bash
git clone <YOUR_REPO_URL>
cd <YOUR_REPO_NAME>
```

### 6.2 Build your project

Use this starter however you want. You can adapt it, replace it, or extend it to match your idea.

Your goal is to create a project that clearly demonstrates your solution and can be accessed through a live URL.

### 6.3 Run locally

The web landing and Gemini API live at the **repository root** (so Vercel needs no subfolder setting):

```bash
npm install
npm run dev
```

For the **Gemini chat**, copy [`.env.example`](./.env.example) to `.env.local` and set `GEMINI_API_KEY` (read by `npm run dev`).

### 6.4 Deploy to Vercel

Your final project must be live on Vercel.

Import this repo and leave **Root Directory** empty (repository root). In **Environment Variables**, add `GEMINI_API_KEY` (and optionally `GEMINI_MODEL`). See [`DEPLOY.md`](./DEPLOY.md).

```bash
npx vercel
```

You can also connect your GitHub repository directly to Vercel and deploy from there.

Before submitting, make sure the deployment link works, the project loads correctly, and the core functionality is accessible to judges.

## 7. Submission

**Klair / this fork:** step-by-step GitHub + Vercel URLs for the form are in [SUBMISSION.md](./SUBMISSION.md).

Once your project is deployed, submit it through the Google Form:

**[Submit here](https://forms.gle/dS1H98eJoZwsXj7e7).**

Your submission should include the following:

1. Team name
2. Team members
3. Project title
4. Short description
5. Deployed Vercel link

Only submitted projects with a working deployed link will be considered.

## 8. Presentation

After submitting, your team will present the project live.

Your presentation should clearly communicate four things:

1. Who you built for
2. What problem you identified
3. What you built
4. Why your solution makes that person’s day easier

This is not only about showing features. It is also about showing your reasoning, your interpretation of the challenge, and the story behind the project.

## 9. Included Resources

1. [Challenge brief and rubric](./CHALLENGE.md)
2. [Practical tips](./resources/tips.md)
3. [Starter reference folder](./starter/) (site + API are at repo root)

## 10. Final Reminder

Build something focused.

Deploy it.

Submit the live link.

Then tell the story of why it matters.