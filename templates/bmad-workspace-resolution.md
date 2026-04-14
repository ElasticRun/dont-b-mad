# BMad Workspace — {project-root} Resolution

This workspace may contain multiple projects, each with its own `_bmad/` configuration tree and output artifacts. All BMAD skills reference `{project-root}` as the anchor for config and outputs. Use the rules below to resolve it.

## Resolution Order

1. **File context** — If the conversation involves files inside a specific project directory (open files, referenced paths, edited files), use that project's root.

2. **Workspace config** — Read `_bmad/workspace.yaml` at the workspace root. It maps project names to directories and may set a `default_project`.

3. **Single project** — If only one project is listed (or only one `_bmad/` directory exists in the workspace), use it without asking.

4. **Default project** — If `default_project` is set in `workspace.yaml` and no file context disambiguates, use the default.

5. **Ask the user** — If multiple projects exist and the target is ambiguous, ask which project before proceeding. Present the project names and descriptions from `workspace.yaml`.

## Once Resolved

- Set `{project-root}` to the **absolute path** of the chosen project directory.
- All config loads (`{project-root}/_bmad/...`) and artifact writes (`{planning_artifacts}/...`, `{implementation_artifacts}/...`, etc.) scope to that project.
- If the user switches to a different project mid-conversation, re-resolve.

## Single-Project Backward Compatibility

When the workspace root itself contains `_bmad/` (no sub-projects), treat the workspace root as `{project-root}`. No `workspace.yaml` is needed.
