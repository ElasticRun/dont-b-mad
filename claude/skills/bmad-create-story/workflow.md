# Create Story Workflow

**Goal:** Create a comprehensive story file that gives the dev agent everything needed for flawless implementation.

**Your Role:** Story context engine that prevents LLM developer mistakes, omissions, or disasters.
- Communicate all responses in {communication_language} and generate all documents in {document_output_language}
- Your purpose is NOT to copy from epics - it's to create a comprehensive, optimized story file that gives the DEV agent EVERYTHING needed for flawless implementation
- COMMON LLM MISTAKES TO PREVENT: reinventing wheels, wrong libraries, wrong file locations, breaking regressions, ignoring UX, vague implementations, lying about completion, not learning from past work
- EXHAUSTIVE ANALYSIS REQUIRED: You must thoroughly analyze ALL artifacts to extract critical context - do NOT be lazy or skim! This is the most important function in the entire development process!
- UTILIZE SUBPROCESSES AND SUBAGENTS: Use research subagents, subprocesses or parallel processing if available to thoroughly analyze different artifacts simultaneously and thoroughly
- SAVE QUESTIONS: If you think of questions or clarifications during analysis, save them to a list `{{open_questions}}` — they get resolved in step 5b via the grill skill, not dropped on the user as a wall of text at the end
- LOW USER INTERVENTION: Process should be fully automated except for: initial epic/story selection, missing documents, and the step 5b grill pass when ambiguities were collected. A story with zero collected ambiguities skips step 5b entirely and stays fully automated.

---

## INITIALIZATION

### Configuration Loading

Load config from `{project-root}/_bmad/bmm/config.yaml` and resolve:

- `project_name`, `user_name`
- `communication_language`, `document_output_language`
- `user_skill_level`
- `planning_artifacts`, `implementation_artifacts`
- `date` as system-generated current datetime

### Paths

- `sprint_status` = `{implementation_artifacts}/sprint-status.yaml`
- `epics_file` = `{planning_artifacts}/epics.md`
- `prd_file` = `{planning_artifacts}/prd.md`
- `architecture_file` = `{planning_artifacts}/architecture.md`
- `ux_file` = `{planning_artifacts}/*ux*.md`
- `story_title` = "" (will be elicited if not derivable)
- `project_context` = `**/project-context.md` (load if exists)
- `default_output_file` = `{implementation_artifacts}/{{story_key}}.md`

### Input Files

| Input | Description | Path Pattern(s) | Load Strategy |
|-------|-------------|------------------|---------------|
| prd | PRD (fallback - epics file should have most content) | whole: `{planning_artifacts}/*prd*.md`, sharded: `{planning_artifacts}/*prd*/*.md` | SELECTIVE_LOAD |
| architecture | Architecture (fallback - epics file should have relevant sections) | whole: `{planning_artifacts}/*architecture*.md`, sharded: `{planning_artifacts}/*architecture*/*.md` | SELECTIVE_LOAD |
| ux | UX design (fallback - epics file should have relevant sections) | whole: `{planning_artifacts}/*ux*.md`, sharded: `{planning_artifacts}/*ux*/*.md` | SELECTIVE_LOAD |
| epics | Enhanced epics+stories file with BDD and source hints | whole: `{planning_artifacts}/*epic*.md`, sharded: `{planning_artifacts}/*epic*/*.md` | SELECTIVE_LOAD |

---

## EXECUTION

<workflow>

<step n="1" goal="Determine target story">
  <check if="{{story_path}} is provided by user or user provided the epic and story number such as 2-4 or 1.6 or epic 1 story 5">
    <action>Parse user-provided story path: extract epic_num, story_num, story_title from format like "1-2-user-auth"</action>
    <action>Set {{epic_num}}, {{story_num}}, {{story_key}} from user input</action>
    <action>GOTO step 2a</action>
  </check>

  <action>Check if {{sprint_status}} file exists for auto discover</action>
  <check if="sprint status file does NOT exist">
    <output>🚫 No sprint status file found and no story specified</output>
    <output>
      **Required Options:**
      1. Run `sprint-planning` to initialize sprint tracking (recommended)
      2. Provide specific epic-story number to create (e.g., "1-2-user-auth")
      3. Provide path to story documents if sprint status doesn't exist yet
    </output>
    <ask>Choose option [1], provide epic-story number, path to story docs, or [q] to quit:</ask>

    <check if="user chooses 'q'">
      <action>HALT - No work needed</action>
    </check>

    <check if="user chooses '1'">
      <output>Run sprint-planning workflow first to create sprint-status.yaml</output>
      <action>HALT - User needs to run sprint-planning</action>
    </check>

    <check if="user provides epic-story number">
      <action>Parse user input: extract epic_num, story_num, story_title</action>
      <action>Set {{epic_num}}, {{story_num}}, {{story_key}} from user input</action>
      <action>GOTO step 2a</action>
    </check>

    <check if="user provides story docs path">
      <action>Use user-provided path for story documents</action>
      <action>GOTO step 2a</action>
    </check>
  </check>

  <!-- Auto-discover from sprint status only if no user input -->
  <check if="no user input provided">
    <critical>MUST read COMPLETE {sprint_status} file from start to end to preserve order</critical>
    <action>Load the FULL file: {{sprint_status}}</action>
    <action>Read ALL lines from beginning to end - do not skip any content</action>
    <action>Parse the development_status section completely</action>

    <action>Find the FIRST story (by reading in order from top to bottom) where:
      - Key matches pattern: number-number-name (e.g., "1-2-user-auth")
      - NOT an epic key (epic-X) or retrospective (epic-X-retrospective)
      - Status value equals "backlog"
    </action>

    <check if="no backlog story found">
      <output>📋 No backlog stories found in sprint-status.yaml

        All stories are either already created, in progress, or done.

        **Options:**
        1. Run sprint-planning to refresh story tracking
        2. Load PM agent and run correct-course to add more stories
        3. Check if current sprint is complete and run retrospective
      </output>
      <action>HALT</action>
    </check>

    <action>Extract from found story key (e.g., "1-2-user-authentication"):
      - epic_num: first number before dash (e.g., "1")
      - story_num: second number after first dash (e.g., "2")
      - story_title: remainder after second dash (e.g., "user-authentication")
    </action>
    <action>Set {{story_id}} = "{{epic_num}}.{{story_num}}"</action>
    <action>Store story_key for later use (e.g., "1-2-user-authentication")</action>

    <!-- Mark epic as in-progress if this is first story -->
    <action>Check if this is the first story in epic {{epic_num}} by looking for {{epic_num}}-1-* pattern</action>
    <check if="this is first story in epic {{epic_num}}">
      <action>Load {{sprint_status}} and check epic-{{epic_num}} status</action>
      <action>If epic status is "backlog" → update to "in-progress"</action>
      <action>If epic status is "contexted" (legacy status) → update to "in-progress" (backward compatibility)</action>
      <action>If epic status is "in-progress" → no change needed</action>
      <check if="epic status is 'done'">
        <output>🚫 ERROR: Cannot create story in completed epic</output>
        <output>Epic {{epic_num}} is marked as 'done'. All stories are complete.</output>
        <output>If you need to add more work, either:</output>
        <output>1. Manually change epic status back to 'in-progress' in sprint-status.yaml</output>
        <output>2. Create a new epic for additional work</output>
        <action>HALT - Cannot proceed</action>
      </check>
      <check if="epic status is not one of: backlog, contexted, in-progress, done">
        <output>🚫 ERROR: Invalid epic status '{{epic_status}}'</output>
        <output>Epic {{epic_num}} has invalid status. Expected: backlog, in-progress, or done</output>
        <output>Please fix sprint-status.yaml manually or run sprint-planning to regenerate</output>
        <action>HALT - Cannot proceed</action>
      </check>
      <output>📊 Epic {{epic_num}} status updated to in-progress</output>
    </check>

    <action>GOTO step 2a</action>
  </check>
</step>

<step n="2" goal="Load and analyze core artifacts">
  <action>Initialize {{open_questions}} = [] — populate throughout steps 2-4 whenever a clarification is needed that the artifacts don't answer</action>
  <critical>🔬 EXHAUSTIVE ARTIFACT ANALYSIS - This is where you prevent future developer mistakes!</critical>

  <!-- Load all available content through discovery protocol -->
  <action>Read fully and follow `./discover-inputs.md` to load all input files</action>
  <note>Available content: {epics_content}, {prd_content}, {architecture_content}, {ux_content},
  {project_context}</note>

  <!-- Graphify: load knowledge graph for codebase-aware story creation -->
  <check if="graphify-out/GRAPH_REPORT.md exists">
    <action>Read graphify-out/GRAPH_REPORT.md. Use god nodes, communities, and module structure to write accurate Dev Notes: correct file paths, real function names, actual dependencies. This prevents the dev agent from navigating blind.</action>
    <action if="graphify-out/graph.json exists">For stories that modify existing code, query graph.json to identify exact files, functions, and callers that will be affected. Include these in the story's technical context.</action>
  </check>

  <!-- Analyze epics file for story foundation -->
  <action>From {epics_content}, extract Epic {{epic_num}} complete context:</action> **EPIC ANALYSIS:** - Epic
  objectives and business value - ALL stories in this epic for cross-story context - Our specific story's requirements, user story
  statement, acceptance criteria - Technical requirements and constraints - Dependencies on other stories/epics - Source hints pointing to
  original documents <!-- Extract specific story requirements -->
  <action>Extract our story ({{epic_num}}-{{story_num}}) details:</action> **STORY FOUNDATION:** - User story statement
  (As a, I want, so that) - Detailed acceptance criteria (already BDD formatted) - Technical requirements specific to this story -
  Business context and value - Success criteria <!-- Previous story analysis for context continuity -->
  <check if="story_num > 1">
    <action>Find {{previous_story_num}}: scan {implementation_artifacts} for the story file in epic {{epic_num}} with the highest story number less than {{story_num}}</action>
    <action>Load previous story file: {implementation_artifacts}/{{epic_num}}-{{previous_story_num}}-*.md</action> **PREVIOUS STORY INTELLIGENCE:** -
  Dev notes and learnings from previous story - Review feedback and corrections needed - Files that were created/modified and their
  patterns - Testing approaches that worked/didn't work - Problems encountered and solutions found - Code patterns established <action>Extract
  all learnings that could impact current story implementation</action>
  </check>

  <!-- Git intelligence for previous work patterns -->
  <check
    if="previous story exists AND git repository detected">
    <action>Get last 5 commit titles to understand recent work patterns</action>
    <action>Analyze 1-5 most recent commits for relevance to current story:
      - Files created/modified
      - Code patterns and conventions used
      - Library dependencies added/changed
      - Architecture decisions implemented
      - Testing approaches used
    </action>
    <action>Extract actionable insights for current story implementation</action>
  </check>
</step>

<step n="3" goal="Architecture analysis for developer guardrails">
  <critical>🏗️ ARCHITECTURE INTELLIGENCE - Extract everything the developer MUST follow!</critical> **ARCHITECTURE DOCUMENT ANALYSIS:** <action>Systematically
  analyze architecture content for story-relevant requirements:</action>

  <!-- Load architecture - single file or sharded -->
  <check if="architecture file is single file">
    <action>Load complete {architecture_content}</action>
  </check>
  <check if="architecture is sharded to folder">
    <action>Load architecture index and scan all architecture files</action>
  </check> **CRITICAL ARCHITECTURE EXTRACTION:** <action>For
  each architecture section, determine if relevant to this story:</action> - **Technical Stack:** Languages, frameworks, libraries with
  versions - **Code Structure:** Folder organization, naming conventions, file patterns - **API Patterns:** Service structure, endpoint
  patterns, data contracts - **Database Schemas:** Tables, relationships, constraints relevant to story - **Security Requirements:**
  Authentication patterns, authorization rules - **Performance Requirements:** Caching strategies, optimization patterns - **Testing
  Standards:** Testing frameworks, coverage expectations, test patterns - **Deployment Patterns:** Environment configurations, build
  processes - **Integration Patterns:** External service integrations, data flows <action>Extract any story-specific requirements that the
  developer MUST follow</action>
  <action>Identify any architectural decisions that override previous patterns</action>
  <action>For any architectural area where the artifact is silent, ambiguous, or contradicts an epic AC, append a question to {{open_questions}}. Example entries: "AC4 says 'cache the response' — TTL not specified; pick from architecture cache strategy?", "Story touches `lib/hubspot/` but architecture doesn't say whether retries are story-level or client-level".</action>
</step>

<step n="4" goal="Web research for latest technical specifics (conditional)">
  <critical>SKIP unless this story introduces a new dependency or upgrades a version-sensitive integration. Web research is expensive (search + fetch tokens) and rarely actionable for stories that build on already-established stack choices.</critical>

  <!-- Decide if web research is needed -->
  <action>Inspect the story's acceptance criteria, technical requirements, and source hints from {epics_content}, plus the architecture deltas extracted in step 3. Web research fires ONLY if at least one of these is true:
    - Story explicitly adds a NEW library, framework, SDK, or external API not already in use
    - Story upgrades a major version of an existing dependency (e.g., React 17 → 18, Node 18 → 20)
    - Story integrates with a third-party service whose API surface changes frequently AND the architecture doc is silent on which version/endpoint to target
    - User explicitly requested fresh tech research for this story
  </action>

  <check if="none of the above triggers fire">
    <output>⏭️ Step 4 skipped — story builds on already-established stack; no web research needed.</output>
    <action>GOTO step 5</action>
  </check>

  <check if="at least one trigger fires">
    <action>Identify the specific libraries, APIs, or frameworks that triggered the research (do NOT research the entire stack — only the new/upgraded items).</action>
    <action>For each triggering technology, research latest stable version and key changes:
      - Latest API documentation and breaking changes
      - Security vulnerabilities or updates
      - Performance improvements or deprecations
      - Best practices for current version
    </action>
    <action>Include in story any critical latest information the developer needs:
      - Specific library versions and why chosen
      - API endpoints with parameters and authentication
      - Recent security patches or considerations
      - Performance optimization techniques
      - Migration considerations if upgrading
    </action>
    <action>For any technical specific the web research couldn't pin down (e.g., "library X v3 changed the auth callback signature — pick old or new?"), append a question to {{open_questions}}.</action>
  </check>
</step>

<step n="5" goal="Create comprehensive story file">
  <critical>📝 CREATE ULTIMATE STORY FILE - The developer's master implementation guide!</critical>

  <action>Initialize from template.md:
  {default_output_file}</action>
  <template-output file="{default_output_file}">story_header</template-output>

  <!-- Story foundation from epics analysis -->
  <template-output
    file="{default_output_file}">story_requirements</template-output>

  <!-- Developer context section - MOST IMPORTANT PART -->
  <template-output file="{default_output_file}">
  developer_context_section</template-output> **DEV AGENT GUARDRAILS:** <template-output file="{default_output_file}">
  technical_requirements</template-output>
  <template-output file="{default_output_file}">architecture_compliance</template-output>
  <template-output
    file="{default_output_file}">library_framework_requirements</template-output>
  <template-output file="{default_output_file}">
  file_structure_requirements</template-output>
  <template-output file="{default_output_file}">testing_requirements</template-output>

  <!-- Previous story intelligence -->
  <check
    if="previous story learnings available">
    <template-output file="{default_output_file}">previous_story_intelligence</template-output>
  </check>

  <!-- Git intelligence -->
  <check
    if="git analysis completed">
    <template-output file="{default_output_file}">git_intelligence_summary</template-output>
  </check>

  <!-- Latest technical specifics -->
  <check if="web research completed">
    <template-output file="{default_output_file}">latest_tech_information</template-output>
  </check>

  <!-- Project context reference -->
  <template-output
    file="{default_output_file}">project_context_reference</template-output>

  <!-- Final status update -->
  <template-output file="{default_output_file}">
  story_completion_status</template-output>

  <!-- AI Engineering Record: fill the Story Creation row -->
  <action>In the AI Engineering Record table, set the Story Creation row:
    - Tool/Model = the agent/model currently running (e.g. "cursor/claude-sonnet-4-20250514")
    - Story Ref = {{story_key}}
  </action>

  <!-- CRITICAL: Set status to ready-for-dev -->
  <action>Set story Status to: "ready-for-dev"</action>
  <action>Add completion note: "Ultimate
  context engine analysis completed - comprehensive developer guide created"</action>
</step>

<step n="5b" goal="Resolve outstanding ambiguities via grill (skip if none collected)">
  <critical>🎯 STORY-QUALITY GATE — Ambiguities resolved here never reach the dev agent as guesses</critical>

  <check if="{{open_questions}} is empty">
    <output>No outstanding ambiguities collected during analysis. Skipping grill step.</output>
    <action>GOTO step 6</action>
  </check>

  <action>Invoke the `dontbmad-grill` skill with:
    - `topic`: "story {{story_key}} — outstanding ambiguities surfaced during context engineering"
    - `draft_so_far`: the story file at {{default_output_file}} as written by step 5, plus the {{open_questions}} list as the explicit decision-tree roots
    - `intensity`: `light` (auto-invocation default — the user did not explicitly ask for a deep grill on this story)
  </action>

  <action>The grill skill returns:
    - A `Grilled Decisions` table — every resolved ambiguity with the user's chosen answer
    - An optional `Deferred (Need Info)` list — ambiguities the user could not resolve right now
  </action>

  <action>Amend the story file at {{default_output_file}}:
    - For each row in `Grilled Decisions`, find the corresponding section in the story (acceptance criteria, dev notes, technical context) and update it with the resolved answer. Do NOT append a separate "grilled decisions" block — the resolutions belong inline where the dev agent reads them.
    - For each row in `Deferred (Need Info)`, append an `## Open Questions` section to the story listing the deferred items with their unblock conditions. The dev agent reads this section first and pauses if any are blocking.
  </action>

  <action>After amending, ask user: "Light grill complete. Story updated with {{N}} resolved ambiguities and {{M}} deferred. Accept and finalize? (y/n) — or [D] to go deeper at standard intensity"</action>
  <check if="user chooses D">
    <action>Re-invoke `dontbmad-grill` with `intensity: standard` and the same topic; merge new resolutions on top</action>
  </check>
  <check if="user chooses n">
    <action>Revert {{default_output_file}} to the step-5 version (no grilled amendments). Ask user what they want adjusted before re-running.</action>
  </check>
</step>

<step n="6" goal="Update sprint status and finalize">
  <action>Validate the newly created story file {default_output_file} against `./checklist.md` and apply any required fixes before finalizing</action>
  <action>Save story document unconditionally</action>

  <!-- Update sprint status -->
  <check if="sprint status file exists">
    <action>Update {{sprint_status}}</action>
    <action>Load the FULL file and read all development_status entries</action>
    <action>Find development_status key matching {{story_key}}</action>
    <action>Verify current status is "backlog" (expected previous state)</action>
    <action>Update development_status[{{story_key}}] = "ready-for-dev"</action>
    <action>Update last_updated field to current date</action>
    <action>Save file, preserving ALL comments and structure including STATUS DEFINITIONS</action>
  </check>

  <!-- Git Checkpoint: commit the story file -->
  <check if="version control is available AND the working tree is dirty">
    <action>All git commands MUST target the project repo using `git -C {project-root}`.
      Stage {default_output_file} and {{sprint_status}} if it was updated:
        git -C {project-root} add {default_output_file} {{sprint_status}}
      Create a local commit: "docs: create story {{story_key}}"
      Append AI tracking trailers:
        AI-Phase: story
        AI-Tool: {agent/model currently running, e.g. "cursor/claude-sonnet-4-20250514"}
        Story-Ref: {{story_key}}
      Do NOT push.
    </action>
  </check>

  <action>Report completion</action>
  <output>**🎯 ULTIMATE BMad Method STORY CONTEXT CREATED, {user_name}!**

    **Story Details:**
    - Story ID: {{story_id}}
    - Story Key: {{story_key}}
    - File: {{story_file}}
    - Status: ready-for-dev

    **Next Steps:**
    1. Review the comprehensive story in {{story_file}}
    2. Run dev agents `dev-story` for optimized implementation
    3. Run `code-review` when complete (auto-marks done)
    4. Optional: If Test Architect module installed, run `/bmad:tea:automate` after `dev-story` to generate guardrail tests

    **The developer now has everything needed for flawless implementation!**
  </output>
</step>


</workflow>

## AIEye Live

When this workflow completes (final step finished), run once as a fire-and-forget shell command. Do not wait for output; failures must not block or fail the session.

```bash
AIEYE_HOOK="$HOME/.claude/hooks/aieye-live/bin/aieye-live-hook"
test -x "$AIEYE_HOOK" && "$AIEYE_HOOK" bmad-create-story || true
```

Uses the same ingest URL and payload logic as `~/.claude/hooks/aieye-live/lib/dispatch.js` (deployed from `hooks/post-skill/` via `scripts/install.sh`; see `hooks/post-skill/README.md`). Requires `~/.claude/aieye-live.env` and git credentials for `engg.elasticrun.in` as documented there.

