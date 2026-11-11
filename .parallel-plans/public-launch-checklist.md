# Public launch checklist (chief, 2026-11-11)

Private file; `.parallel-plans/` does not go into the public tree.

## Done on `main`
- README: icon header, own badges (`docs/readme/badges/`, no badge service), hero, the two ways to get Edgy with the $5 signed build at edgy.to, actions table, key-sequence shot, links to changelog and code of conduct.
- `CHANGELOG.md`, `CODE_OF_CONDUCT.md`, `.github/FUNDING.yml` (Sponsor button → edgy.to), `SECURITY.md` (GitHub's private vulnerability reporting, no email).
- `.github/workflows/ci.yml`: build, test, lint on pull requests and by hand. Never run yet. It does not run on push, so it costs nothing until someone starts it.
- `docs/readme/social-preview.png` (1280×640).
- Topics and homepage set on the private repo (they must be set again if the public repo is a new one).

## At launch, in order
1. Public tree = one clean commit (backlog § Before going public): noreply author, no `.parallel-plans/`, denylist + home-path grep.
2. Repo settings (web): upload `docs/readme/social-preview.png` under Settings → Social preview; turn on Security → Private vulnerability reporting (public repos only); turn on Discussions if wanted.
3. `gh repo edit --homepage https://edgy.to --add-topic macos,macos-app,menu-bar,menubar-app,trackpad,gestures,multitouch,swift,swiftui,productivity,open-source,accessibility`
4. Start the Check workflow once by hand; when it is green, add its status badge to the README.
5. Demo clip: drag the .mp4 into the README's marked slot in the GitHub web editor (it only plays in place when uploaded that way; a video file committed to the repo shows as a link).
6. Cut a GitHub release for the tag with the changelog section as its notes. The DMG itself is sold on edgy.to, not attached.
7. README claims to re-check on that day: "$5", "notarized", "Included in the $5" (new versions), clone URL.

## Open with Gabriel
- Who makes the interim demo clip (a 15–20 s screen recording with Test Mode plates would do until the 30 s film exists).
- Run the Check workflow once now (uses about 10 billed macOS minutes ×10 on a private repo) or wait for public.
