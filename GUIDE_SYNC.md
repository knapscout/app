## Guide Sync Rule
The field guide (knapscout.github.io repo, guide/index.html) describes the app to
real users. It must match what is actually built. Any time a user-facing feature
is added, changed, or removed in app-repo, update the guide in the same work
session before considering the change done. Treat the guide as part of the
definition of done, not a separate task.

Drift check: the guide must never describe a feature that is not in the shipped
code. As of June 12 2026 the guide was corrected after it claimed photo capture,
a material/condition flow, a "Significant?" popup, and "no account" sign-in, none
of which were built. Do not let that gap reopen.

Pairing: app feature work -> guide update, every time. When in doubt, read
guide/index.html and confirm each claim against the code.
