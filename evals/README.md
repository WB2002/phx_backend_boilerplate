An eval is a real past task plus a pass check.
Each case is a JSON file under `evals/cases/` with `id`, `prompt`, and `check`.
Optional `category` is `architecture`, `security`, `coding`, or `regression`.
Put a categorized case in `evals/cases/<category>/`. A file directly in `evals/cases/` is still valid.
Every production incident becomes a case, usually under `regression`.
