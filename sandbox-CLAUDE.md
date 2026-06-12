# Guidelines

This document defines the project's rules, objectives, and progress management methods. Please proceed with the project according to the following content.

## Top-Level Rules

- To maximize efficiency, **if you need to execute multiple independent processes, invoke those tools concurrently, not sequentially**.
- **You must think exclusively in English**. However, you must **respond in language that is used in the conversation** unless otherwise stated.

## Environment & Safety Rules

These rules protect the user's local environment, machine state, and shared/remote systems. This environment runs inside an **isolated Docker container** (non-root `dev` user, egress-restricted by a firewall). The container is disposable, but the mounted source tree and any credentials are not. When in doubt about any of the following, stop and ask the user before proceeding.

### Workspace Layout

- **Multiple repositories may exist under `/workspace`**, e.g. `/workspace/repo-a`, `/workspace/repo-b`.
- **Multiple Claude Code sessions may run in parallel**, each working on a different repository. Confine all reads and writes to the repository you have been asked to work on; do not touch sibling repositories unless explicitly instructed.

### Local Environment

- **Do not install tools globally without permission.** Prefer project-local alternatives (`venv`, `npx`, `pipx`, `cargo install --root`, etc.). If a global install is truly unavoidable, **stop and ask the user first**, and record the exact install/uninstall commands and version beforehand so the change is fully reversible.
- **`sudo` is restricted in this container.** The `dev` user can only run the firewall script via sudo; general `sudo` (e.g. `apt install`) is not available. If a privileged operation seems genuinely necessary, **stop and ask the user** rather than attempting workarounds.
- **Do not touch the firewall.** The egress firewall (`/usr/local/bin/init-firewall.sh`) is managed by the user. Do not run, re-apply, or modify it on your own initiative. If network access to an expected destination fails, **report it to the user** rather than altering the firewall yourself.
- **Do not pipe remote content directly into a shell** (e.g. `curl ... | sh`, `wget ... | bash`). If installing a tool genuinely requires this, **stop and ask the user for permission first**; do not do it unilaterally. Otherwise download, inspect, and execute as separate, user-confirmed steps.
- **Do not modify files under the user's home directory** (`~/.zshrc`, `~/.gitconfig`, `~/.ssh/*`, `~/.tmux.conf`, `~/.claude/*`, etc.) without explicit instruction. These affect the whole environment.
- **Do not add new dependencies without permission.** Adding packages (`npm install <pkg>`, `pip install <pkg>`, `cargo add`, `go get`, etc.) modifies lockfiles and introduces supply-chain risk. Confirm with the user before introducing any new dependency, including dev-only ones.

### Git

- **`git` may be aliased or wrapped** in the user's shell. Invoke the absolute path (`/usr/bin/git`) to guarantee predictable behavior.
- **You do not commit. Committing is the user's job.** Prepare changes, report completion, and wait for the user to review and commit.
- **Do not run `git commit`, `git push`, or `git push --force`.** These are reserved for the user.
- **Do not chain git commands with `&&` in a single Bash invocation** (e.g. `git add ... && git commit ...`). Run each git command as a separate invocation so that permission rules apply to each command individually.
- **Do not run destructive git commands without confirmation**, including `git reset --hard`, `git clean -fd`, `git checkout -- .`, branch deletion, and any operation using `--no-verify` or `--force` flags.
- **Investigate unfamiliar files, branches, or commits before deleting or overwriting them.** They may represent the user's in-progress work.

### Remote Services

- **Do not create PRs or Issues** on GitHub or any remote forge (including drafts) without explicit user instruction.
- **Do not post comments, reviews, or reactions** on GitHub (PRs, Issues, Discussions) without explicit user instruction.

### Secrets

- **Do not stage, commit, or echo the contents of files that may contain secrets** (`.env`, `*.pem`, `credentials.json`, SSH keys, etc.). If reading is necessary for the task, do not output the contents back to the user or to logs.
- **Never read credential stores by any means** -- not via the `Read` tool, nor via shell commands (`cat`, `grep`, `head`, command substitution, etc.). This includes `~/.claude/`, `~/.ssh/`, and any `credentials*` file. There is no legitimate task that requires their contents.

### Tool Usage and Verification

- **Always `Read` a file before `Edit`/`Write`.** Do not modify files based on guesses about their contents.
- **Before reporting a task as complete, state explicitly which verification you performed** (type-check, unit tests, integration tests, manual confirmation). "It should work" is not a completion criterion.
- **Do not run commands that require interactive TTY input** (`vim`, `less`, `git rebase -i`, `git add -i`, `npm init` without `-y`, etc.). They will hang the session. Use non-interactive flags or ask the user to run the command themselves.
- **Manage background processes responsibly.** If you start a long-running process (`npm run dev`, dev servers, file watchers), track the PID and terminate it once the task is done. Do not leave orphaned processes running.
- **Do not fake test success.** Disabling failing tests with `it.skip` / `xit` / `// @ts-expect-error` / commenting out assertions to make a suite "pass" is forbidden. Either fix the underlying issue or stop and consult the user.
- **When searching for hidden folders** like `.tmp`, the `List` tool is unlikely to find them. **Use the `Bash` tool to find hidden folders.**

## Task Completion

- This environment runs inside an isolated container without a desktop. Native OS notifications (e.g. macOS `osascript`) are unavailable and must not be used.
- Task-completion and decision-required notifications are handled by Claude Code's Remote Control push, configured outside this file. Do not attempt to send notifications from within the container.
- **You must report task completion to the user** in the conversation. "Task completion" refers to the state immediately after you have finished responding and are awaiting the user's next input. A brief completion report is expected even for minor tasks (format correction, refactoring, documentation updates).
- **When you stop because the user's action is required** (e.g. reviewing changes and committing), **state this explicitly** at the end of your report, e.g. "Changes are ready for your review and commit."

## Project Rules

- Follow the rules below for writing code comments and documentation:
  - **Documentation** such as JSDoc and Docstrings must be written in **English**.
  - **Comments embedded within the code**, such as descriptions for tests or schemas, must be written in **English**.
  - **Code comments** that describe the background or reasoning behind the implementation should be written in **English**.
  - **Do not use emojis in code comments and embedded comments.**
- When writing Japanese, do not include unnecessary spaces.
  - for example
    - O "Claude Code入門"
    - X "Claude Code 入門"

## Project Objectives

### Development Style

- **The `.tmp/` working directory must be created at the root of the repository you are working on** (e.g. `/workspace/<repo>/.tmp/`), **never directly under `/workspace/`**. Each repository has its own independent `.tmp/`; do not read or write the `.tmp/` of a repository you are not working on.
- **Requirements and design for each task must be documented in `<repo>/.tmp/design.md`.**
- **Detailed sub-tasks for each main task must be defined in `<repo>/.tmp/task.md`.**
- **You must update `.tmp/task.md` as you make progress on your work.**
- The `.tmp/` directory is **git-ignored** and must not be committed; it is working memory, not part of the repository. Externally provided documents (design notes, performance reports) may be placed under `.tmp/` (e.g. `.tmp/incoming/`) by the user; treat them as read-only inputs.
- **Exception for trivial changes:** The `.tmp/design.md` / `.tmp/task.md` workflow is required for non-trivial work only. Single-line fixes, typo corrections, simple Q&A, formatter-only changes, and small configuration tweaks may skip this step.
- **Check for a pre-existing `.tmp/design.md` or `.tmp/task.md` in the repository you are working on before starting any non-trivial work.** Use the `Bash` tool (the `List` tool may not surface hidden directories). If either file exists:
  1. **Do not overwrite, modify, or delete them** as a first action. They may represent in-progress work by the user or another agent (e.g. a parallel Claude Code session working on the same repository, a remote agent, or a scheduled routine).
  2. Read the contents and summarize them to the user in the conversation language: what the design describes, which tasks are checked off, which remain, and the apparent current state.
  3. Ask the user explicitly how to proceed -- for example: continue the existing plan, start a new plan after archiving the old one, or hand off because another agent is still working on it. Wait for the user's instruction before writing to either file.

1.  First, create a plan and document the requirements in `<repo>/.tmp/design.md`.
2.  Based on the requirements, identify all necessary tasks and list them in `<repo>/.tmp/task.md`.
3.  Once the plan is established, create a new branch and begin your work.
    - Branch names should start with `feat/` followed by a brief summary of the task.
4.  Break down tasks into small, manageable units that can be completed within a single commit.
5.  Create a checklist for each task to manage its progress.
6.  Always apply a code formatter to maintain readability.
7.  **Do not commit your changes.** Report completion and ask the user to review and commit.
8.  When instructed to create a Pull Request (PR), use the following format:
    - **Title**: A brief summary of the task.
    - **Key Changes**: Describe the changes, points of caution, etc.
    - **Testing**: Specify which tests passed, which tests were added, and clearly state how to run the tests.
    - **Related Tasks**: Provide links or numbers for related tasks.
    - **Other**: Include any other special notes or relevant information.

## Programming Rules

- Avoid hard-coding values unless absolutely necessary.
- Do not use `any` or `unknown` types in TypeScript.
- You must not use a TypeScript `class` unless it is absolutely necessary (e.g., extending the `Error` class for custom error handling that requires `instanceof` checks).
- **Do not swallow errors.** Empty `catch {}` blocks, `|| true` shortcuts, blanket `--force` flags that mask failures, and bare `except: pass` are forbidden. Investigate the root cause; if there is a legitimate reason to ignore an error, document it with a code comment explaining why.
- **Follow the existing style and conventions of the surrounding code** (naming, import order, comment density, error-handling patterns, file layout). Do not opportunistically "improve" style in unrelated areas while completing a task.
