---
name: fix-pipeline-failures
description: Debug and fix Woodpecker CI pipeline failures, inspect run history for flakes, and manually rerun only the affected step until it passes. Use when asked to investigate or repair failed or stuck CI runs.
---

# Fix pipeline failures

Carry the repair through a passing manual execution of the affected step. Use history to investigate flakes; a lucky retry is not a fix.

## Inspect through Woodpecker MCP

Use Woodpecker MCP for all Woodpecker access, including run discovery, configuration, status, and logs. Discover the currently available tools rather than assuming tool names or capabilities. Do not substitute the Woodpecker CLI, raw HTTP, browser access, or SSH into its database. If MCP is unavailable, report the blocker; continue independent local investigation where useful.

The currently exposed tools include `list_repos`, `list_pipelines`, `get_pipeline`, `get_failed_step_logs`, `get_step_log`, and `get_pipeline_config`. Use `ci_health` for stuck scheduling or connectivity. Resolve the repository and run from the user's request and available context; ask only if the target remains ambiguous.

- Record the failing run's number, commit, branch, variables, workflow, step name, and worker. Read the first causal error, not just the final wrapper failure. Expand truncated logs as needed; `get_step_log` takes `step_id`, not `pid`.
- For a run with no steps, inspect compile errors and the compiled configuration instead of inventing a failing command.
- Trace the step through the run's configuration into its scripts and relevant source at the triggering revision. Read applicable repository instructions before editing.

## Check history for flakes

Inspect recent successful and failed runs of the same step on the relevant branch. Expand the history window when necessary to establish recurrence; do not treat missing history as evidence of reliability.

Compare failure signatures, commits (especially both pass and fail at an unchanged revision), worker identity, timing, resource pressure, dependencies, and configuration changes. A pass and fail at the same commit suggests intermittency but does not establish its cause: inputs and infrastructure can change too. Check whether internal retries already concealed failures.

Separate deterministic defects, suspected flakes, and confirmed intermittent causes using the available evidence. Preserve representative run and step references. Fix the underlying race, isolation problem, resource issue, or other demonstrated cause; do not suppress checks, weaken assertions, or add blanket retries to make CI green.

Use the historical pattern to choose further focused verification rather than a fixed retry count. If the step passes unchanged, continue investigating the suspected flake. Report unresolved uncertainty explicitly instead of claiming it is fixed.

## Fix and manually rerun the affected step

Do not trigger or restart the entire pipeline. The current MCP exposes pipeline triggering, not individual-step retry; do not use `trigger_pipeline` as a substitute or invent an MCP retry capability.

Run only the affected step's actual command manually on the appropriate worker, using authorized shell or SSH access. Shell access is for executing the step and inspecting worker conditions, not bypassing MCP for Woodpecker access.

Before execution, reconstruct the required checkout and submodule revisions, working directory, environment, toolchain, runtime secret source, dependencies, and run-specific artifacts from the configuration and scripts. Do not print secrets. Establish which revision contains the fix and record it with the rerun result. Do not reset a shared checkout, overlap an active job that uses the same resources, or silently substitute another run's artifacts.

If required artifacts or context cannot be recovered, report the concrete blocker. Do not expand to a full pipeline or execute unrelated prerequisites without authorization. For compile-time failures, validate the corrected configuration through available non-release checks and state that there was no executable step to rerun.

Apply the smallest causal fix, run relevant local checks, then manually execute the affected step and capture its exit status and logs. If it fails, use the new evidence to refine the diagnosis and repeat until it passes. Repeated identical failures require further investigation, not blind execution. Continue while meaningful progress is possible; stop for a concrete access, authorization, or external-state blocker and explain what is needed.

Keep reruns within the user's authorized scope. Before repeating a deploy or publish step, inspect partial completion and idempotency so the retry does not duplicate irreversible effects. Ask only when the required action expands scope or needs permission not already granted. A request to create this skill does not authorize running live CI.

## Respect repository constraints and report evidence

Follow the active repository's `AGENTS.md` for edits, tests, formatting, git workflow, and deployment. In CoderMana infra, evaluate all applicable product surfaces, preserve dev/prod pipeline parity and run-specific artifact provenance, and include any required runtime wiring. Read the current CI documentation for operational details; a poller change requires its separate deployment, whereas in-pipeline scripts run from the triggering checkout. Never claim an undeployed operational fix is active.

Finish with the root cause, changes and affected surfaces, relevant history and remaining flake uncertainty, checks performed, and the manual step command, revision, and outcome. Redact sensitive command arguments and logs. Distinguish a passing manual rerun from the original Woodpecker run's recorded status; do not mark or describe that failed run as green. If blocked or the failure is unreproduced but unexplained, say so plainly.
