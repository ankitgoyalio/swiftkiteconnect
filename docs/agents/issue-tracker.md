# Issue tracker: GitHub

Issues and specs live in GitHub Issues for
`ankitgoyalio/swiftkiteconnect`. Use the `gh` CLI.

## Operations

- Create: `gh issue create --title "..." --body-file <path>`.
- Read: `gh issue view <number> --json number,title,body,labels,comments`.
- List: `gh issue list --state open --json number,title,labels`.
- Comment: `gh issue comment <number> --body-file <path>`.
- Apply labels: `gh issue edit <number> --add-label "..."`.
- Remove labels: `gh issue edit <number> --remove-label "..."`.
- Close: `gh issue close <number> --comment "..."`.

Run commands inside this repository, or pass
`--repo ankitgoyalio/swiftkiteconnect` explicitly.

When a skill says “publish to the issue tracker,” create an issue.
When it says “fetch the relevant ticket,” read the issue.

## Related issues

Use GitHub sub-issues for parent-child relationships and native
issue dependencies for blockers. Where unavailable, record
`Part of #<parent>` and `Blocked by: #<number>` in issue bodies.

## Pull requests as a triage surface

**PRs as a request surface: no.**
