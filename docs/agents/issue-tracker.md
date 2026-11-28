# Issue tracker

Track tickets and specs in `ankitgoyalio/swiftkiteconnect` GitHub Issues. Use `gh` from this checkout and verify the target with `gh repo view --json nameWithOwner` before creating an issue.

- Publish with `gh issue create`. Pass multiline bodies using `--body-file`.
- Fetch with `gh issue view <number> --json number,title,body,labels,comments`.
- List with `gh issue list` using the relevant state and label filters.
- Use GitHub sub-issues for parent and child tickets, and GitHub issue dependencies for blockers. A ticket is unblocked when every blocker is closed.
- Apply or remove triage labels with `gh issue edit --add-label` or `--remove-label`.
- Post the closing explanation with `gh issue comment`, then close with `gh issue close`.

**PRs as a request surface: no.**
