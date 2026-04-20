# Jira Comment Style Guide

Voice and structure preferences for Jira comments (analysis, findings, status updates).

## Analysis / findings comments

1. **Lead with context and methodology** before presenting findings. Don't assume the reader knows the tools or process — introduce what was done, link to scripts/tools at first mention, and describe the approach briefly.

2. **Integrate document/resource links into narrative prose** rather than as standalone lines or a header block. The reader should encounter them naturally while reading.

3. **Connect findings to the team's recent shared context** (e.g., "mostly in line with the fixes we implemented on Friday"). Anchor results in something the audience already knows rather than presenting in a vacuum.

4. **Separate questions from proposed solutions** using sub-bullets. Keep the ask on the main bullet; put "if so, here's how we'd handle it" on an indented sub-bullet. Cleaner for the reader to distinguish what they need to answer vs. what's already been thought through.

5. **Do NOT include "Next steps" sections** in analysis/findings comments. Comments should report findings and ask questions, not prescribe follow-up actions. Next steps belong in separate tickets or are for the reader to decide.

6. **Backtick all tool/executable names** — `schemachange`, `SqlPackage`, `terraform`, `msbuild`, etc. should always be in backticks, not bare text.

## Status update comments

Progress updates on deliverables have different norms — they can be more direct and transactional. Numbered deliverables with per-item progress notes work well. Don't try to impose the analysis-comment structure on routine status posts.

## Applying the guidance

Before finalizing any draft, classify it (analysis vs. status update) and apply the corresponding rules. Universal: lead with "what did we do and how" before "what did we find."
