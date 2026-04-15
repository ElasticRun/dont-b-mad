# BMad Team — Agent Name Customization

Agent display names can be overridden via a team config file so each team can personalize their BMAD agents without modifying skill files.

## Resolution

When activating any `bmad-agent-*` or `bmad-cis-agent-*` skill:

1. Check for `{project-root}/_bmad/_config/team.yaml`. If not found, fall back to `_bmad/_config/team.yaml` at the workspace root.
2. If the file exists, read the `agents` map and look up the role key for the active skill (see mapping below).
3. If a custom name is found, use it **instead of** the default name from the skill's SKILL.md heading and description. Apply the custom name in:
   - Persona embodiment ("Act as {custom_name}")
   - Greetings and dialogue
   - Retrospective and party-mode agent roster and dialogue lines
4. If team.yaml is missing or the role key is absent, use the default name from the skill file. No error.

## Skill-to-Role-Key Mapping

| Skill folder | Role key |
|---|---|
| `bmad-agent-dev` | `dev` |
| `bmad-agent-pm` | `pm` |
| `bmad-agent-architect` | `architect` |
| `bmad-agent-analyst` | `analyst` |
| `bmad-agent-tech-writer` | `tech-writer` |
| `bmad-agent-ux-designer` | `ux-designer` |
| `bmad-cis-agent-brainstorming-coach` | `brainstorming` |
| `bmad-cis-agent-creative-problem-solver` | `problem-solver` |
| `bmad-cis-agent-design-thinking-coach` | `design-thinking` |
| `bmad-cis-agent-innovation-strategist` | `innovation` |
| `bmad-cis-agent-presentation-master` | `presentations` |
| `bmad-cis-agent-storyteller` | `storyteller` |

## Example

Given this `_bmad/_config/team.yaml`:

```yaml
agents:
  dev: Arjun
  pm: Priya
  architect: Kiran
```

- Invoking `bmad-agent-dev` activates the developer persona as **Arjun** instead of the default.
- Invoking `bmad-agent-pm` activates the PM persona as **Priya**.
- Agents without an entry (e.g. `analyst`) keep their default SKILL.md name.
