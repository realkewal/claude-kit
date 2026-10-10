# linkedin-audit

A [Claude Code](https://claude.com/claude-code) skill that audits a LinkedIn profile and
writes a feedback report the owner can work through.

It reads the profile from LinkedIn's own "Save to PDF" export. Nothing logs in to
LinkedIn, scrapes it, or edits the profile.

## What you get

A report in HTML, and in PDF if a Chromium-family browser is installed:

- A summary page with the three changes that matter most and a rating for every section
- A page per major finding, with "now" and "suggested" shown side by side
- Rewritten text ready to paste, with a highlighted gap wherever the owner needs to add a fact
- A checklist, in the order to do it

## Install

```
/plugin marketplace add realkewal/claude-kit
/plugin install linkedin-audit@claude-kit
```

## Use

1. Open the LinkedIn profile.
2. Choose **Resources** on your own profile, or **More** on someone else's, then **Save to PDF**.
3. In Claude Code:

   ```
   /linkedin-audit:audit path/to/Profile.pdf
   ```

   Or just ask: "audit this LinkedIn profile" with the file path.

It asks five short questions first: what the goal is, and four things the export does
not include (recommendations, Featured, recent posts, pinned skills). The advice depends
on the goal, so a profile aimed at a lead role and one aimed at freelance clients get
different reports.

## How it stays honest

- **Only the owner's facts.** A suggested rewrite reorders and tightens what the profile
  already says. It does not add achievements, numbers, or stronger verbs.
- **Gaps are questions.** Where a role needs a result, the report asks for "one number"
  and leaves the choice to the owner.
- **Unseen is not missing.** The export leaves out Featured, posts, recommendations, and
  the full skills list. Without an answer from the owner, the report marks those "Not
  visible" instead of calling them absent.
- **Contact details stay out.** The export includes a phone number and email. Neither is
  copied into the report.

## What the export leaves out

The "Save to PDF" file contains the headline, About, every role and its description,
education, languages, and contact details. It does not contain the photo, banner,
Featured, posts, recommendations, the full skills list, or the skill tags on each role.

One quirk to know about: the "Top Skills" in the export are not the five pinned on the
profile. The skill knows this and asks for the pinned list.

## Why not read the live profile

LinkedIn's terms prohibit automated access, and it blocks tools that try. The export is
LinkedIn's own feature, takes two clicks, and works for someone else's profile if they
send you the file.

## Requirements

None beyond Claude Code. To produce the PDF, the skill uses Chrome, Brave, Edge, or
Chromium in headless mode if one is installed. Without one you get the HTML, which
prints to PDF from any browser.

## License

MIT. See [LICENSE](../../LICENSE).
