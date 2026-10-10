---
name: audit
description: Use when someone wants feedback on, a review of, or improvements to a LinkedIn profile, their own or someone else's, and can provide the profile's "Save to PDF" export, or asks how to get a LinkedIn profile audited.
---

# Audit a LinkedIn profile

Write a feedback report from a LinkedIn "Save to PDF" export.

**Core rule:** the report states only what the export shows or the owner told you, and every suggested rewrite is built from the owner's own facts.

## Input

A path to the PDF. To get one: open the profile, choose **Resources** (own profile) or **More** (someone else's), then **Save to PDF**.

Given a profile URL instead, ask for the export. Do not open LinkedIn in a browser to read or edit a profile: LinkedIn's terms prohibit automated access, and edits need the owner's judgement.

## What the export is

Read the PDF with the Read tool. No other tooling is needed.

| | |
|---|---|
| **Contains** | Headline, location, About ("Summary"), every role with its full description, education, languages, certifications and honours if any, contact details |
| **Omits** | Photo, banner, Featured, posts and activity, recommendations, the full skills list, skill tags on roles, connection count |
| **"Top Skills" is not the pinned list** | It shows three skills, often the most recently added. Never compare it with the headline or call it the owner's top skills. |
| **Paragraph breaks are lost** | `scale.At` or `productionsafe` are export artefacts, not typos. |
| **Contact details** | The phone number and email are the owner's private data. Neither appears in the report. Profile and website URLs are fine. |

## Steps

1. **Read the export.**
2. **Ask before auditing**, in one batch:
   - What is the goal? (new job, promotion, a specific role, clients, visibility)
   - How many recommendations have you received?
   - What is in your Featured section, if anything?
   - When did you last write a post of your own?
   - Which five skills are pinned at the top of your profile?

   Answered: rate the section from the answer and write "You told me: ...", since you have not seen the content. Use **Missing** only when the owner confirms there is none.
   No answer, or no way to ask: mark the section **Not visible**. An omitted section is unknown, not missing. Group the omitted sections that have no question (photo, banner, full skills list) in one Not visible row.
3. **Audit each section against the goal.**
   - Headline: says what the person does, not only title and employer. The limit is 220 characters.
   - About: opens with the current role, gives proof, and is not a keyword list that repeats Skills.
   - Each role: has a description; states results, not duties; no bullet copied across roles; the bullet that is the best evidence for the goal comes first.
   - Consistency: the same claim is worded the same everywhere. Add up the dates yourself, from the first role listed, and compare with any "N years" claim. Say which roles you counted.
   - Dated items that work against the goal: old certificates, test scores, early roles.
   - Pinned skills, Featured, recommendations, posts (from the answers): does each one support the goal? For recommendations, name who could write one, taken from the roles.
4. **Write the suggestions.**
   - A rewrite uses facts already on the profile, reordered and tightened. A fact may move from one section to another (About into a role); say so in a `.note`, because the owner knows where it belongs.
   - A gap is a question for the owner, marked with `.fill`: "one number: users, speed, revenue". It names the kind of fact wanted and leaves the achievement to them.
   - An assumption goes in a `.note` so the owner can correct it.
   - Address the owner as "you". Refer to anyone else as "they" unless the profile states pronouns.
5. **Build the report** from `report-template.html` in this directory. Save it as `<full-name-lowercase-hyphenated>-linkedin-review.html` in the working directory. Order: summary page with the three changes that matter most and a table rating every section, then the findings, then the checklist. A finding that does not fit on one page is split across two.
6. **Make the PDF** if a Chromium-family browser is installed (Chrome, Brave, Edge, Chromium):

   ```sh
   "<browser binary>" --headless=new --no-pdf-header-footer \
     --print-to-pdf="<name>-linkedin-review.pdf" "file://$PWD/<name>-linkedin-review.html"
   ```

   The browser exits when the file is written. Then Read the PDF. Every page has a fixed height and clips overflow, so check that no page ends mid-content, and move content to a new page if one does. No browser: hand over the HTML and say it prints to PDF from any browser.
7. **Reply** with the path of each file, the three top changes, and what the review could not see.

## Common mistakes

| Mistake | Instead |
|---|---|
| "Your top skills don't match your headline" | The export's Top Skills is not the pinned list. Ask. |
| "You have no recommendations / Featured / posts" | The export omits them. Ask, or mark Not visible. |
| Placeholder like "cut latency from [x] to [y]" | That presumes an achievement. Ask for "one number" and let the owner choose it. |
| "Aim for 20 to 30 skills", "post weekly" | A rule of thumb stated as fact. Give the reason, or leave it out. |
| Rounding a claim up ("led", a bigger number) | Keep the owner's verb and figure. Interviewers ask about both. |
| A long prose report | The template: tables, before and after pairs, a checklist. |
