# One-way, deliberate synchronization

1. Maintain showcase templates and approved code in the private project.
2. Commit the private changes after verification.
3. Run the private `Tools/sync_showcase.py --destination <public-checkout>` command.
4. Review the generated public diff and run `./scripts/test.sh` here.
5. Commit and push each repository deliberately. The exporter never commits or pushes.

Only the explicit file allowlist is exported, plus named extracted code blocks. The exporter refuses symlinks, a dirty private source, unexpected public files or existing public edits that differ from the last manifest. It will not recursively mirror the private project or delete unknown files. The public repository has independent Git history; a recorded private commit hash is provenance, not a transfer of private history. There is no automatic public-to-private merge.
