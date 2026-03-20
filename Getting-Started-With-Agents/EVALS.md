## Evaluation Framework

**When to load:** Setting up evaluations, writing evaluation sets, creating custom evaluators, or running `uipath eval`.

Reference: https://uipath.github.io/uipath-python/eval/

---

### Overview

The UiPath evaluation framework tests agent quality using two categories of evaluators:

- **Output-Based**: Assess final agent results (what the agent produces)
- **Trajectory-Based**: Assess execution paths (how the agent achieves results)
- **Custom**: Domain-specific validation logic you implement yourself

---

### Directory Structure

```
your-project/
├── evaluations/
│   ├── evaluators/          ← Built-in evaluator config .json files go here
│   └── eval-sets/           ← Eval set .json files go here
└── evals/
    └── evaluators/
        ├── custom/          ← Custom Python evaluator implementations go here
        │   ├── my_evaluator.py
        │   └── types/
        │       └── my-evaluator-types.json
        └── my-evaluator.json  ← Custom evaluator config (references Python file)
```

> **Note:** `evaluations/evaluators/` holds JSON config files for **built-in** evaluators. `evals/evaluators/custom/` holds Python code for **custom** evaluators. These are separate directories for separate purposes.

---

### Evaluator Config File Format

Each built-in evaluator needs a JSON config file in `evaluations/evaluators/`. This is the format I needed from the GitHub source that was not in the original docs:

```json
{
  "version": "1.0",
  "id": "MyEvaluatorId",
  "description": "Human-readable description of what this evaluator checks.",
  "evaluatorTypeId": "<see table below>",
  "evaluatorConfig": {
    "name": "MyEvaluatorId",
    "targetOutputKey": "*",
    "defaultEvaluationCriteria": {
      "expectedOutput": { "field": "value" }
    }
  }
}
```

**Important:** `id` and `evaluatorConfig.name` must match. The `id` is what you reference in `evaluatorRefs` and `evaluationCriterias` in the eval set.

#### `evaluatorTypeId` Values for Built-In Evaluators

| Evaluator Type | `evaluatorTypeId` |
|---|---|
| Contains | `uipath-contains` |
| Exact Match | `uipath-exact-match` |
| JSON Similarity | `uipath-json-similarity` |
| LLM Judge Output (semantic similarity) | `uipath-llm-judge-output-semantic-similarity` |
| LLM Judge Output (strict JSON) | `uipath-llm-judge-output-strict-json-similarity` |
| LLM Judge Trajectory | `uipath-llm-judge-trajectory-similarity` |

#### Working Evaluator Config File Examples

**`evaluations/evaluators/json-similarity.json`**
```json
{
  "version": "1.0",
  "id": "JsonSimilarityEvaluator",
  "description": "Tree-based structural comparison. Strings use Levenshtein, booleans exact-match. Only expected keys are evaluated.",
  "evaluatorTypeId": "uipath-json-similarity",
  "evaluatorConfig": {
    "name": "JsonSimilarityEvaluator",
    "targetOutputKey": "*",
    "defaultEvaluationCriteria": {
      "expectedOutput": { "result": 5.0 }
    }
  }
}
```

**`evaluations/evaluators/llm-judge-semantic-similarity.json`**
```json
{
  "version": "1.0",
  "id": "LLMJudgeSemanticSimilarity",
  "description": "Uses an LLM to semantically score output quality.",
  "evaluatorTypeId": "uipath-llm-judge-output-semantic-similarity",
  "evaluatorConfig": {
    "name": "LLMJudgeSemanticSimilarity",
    "targetOutputKey": "*",
    "model": "gpt-4.1-2025-04-14",
    "prompt": "Compare the actual and expected output and score 0-100.\n\nActual Output: {{ActualOutput}}\nExpected Output: {{ExpectedOutput}}",
    "temperature": 0.0,
    "defaultEvaluationCriteria": {
      "expectedOutput": { "result": "expected value" }
    }
  }
}
```

**`evaluations/evaluators/trajectory.json`**
```json
{
  "version": "1.0",
  "id": "TrajectoryEvaluator",
  "description": "Evaluates the agent's execution trajectory and decision sequence.",
  "evaluatorTypeId": "uipath-llm-judge-trajectory-similarity",
  "evaluatorConfig": {
    "name": "TrajectoryEvaluator",
    "model": "gpt-4.1-2025-04-14",
    "prompt": "Evaluate the agent's execution trajectory based on the expected behavior.\n\nExpected Agent Behavior: {{ExpectedAgentBehavior}}\nAgent Run History: {{AgentRunHistory}}\n\nProvide a score from 0-100.",
    "temperature": 0.0,
    "defaultEvaluationCriteria": {
      "expectedAgentBehavior": "The agent should correctly perform the task and return the result."
    }
  }
}
```

**`evaluations/evaluators/contains.json`**
```json
{
  "version": "1.0",
  "id": "ContainsEvaluator",
  "description": "Checks if the output includes specific text.",
  "evaluatorTypeId": "uipath-contains",
  "evaluatorConfig": {
    "name": "ContainsEvaluator",
    "targetOutputKey": "result",
    "negated": false,
    "ignoreCase": false,
    "defaultEvaluationCriteria": {
      "searchText": "expected text"
    }
  }
}
```

**`evaluations/evaluators/exact-match.json`**
```json
{
  "version": "1.0",
  "id": "ExactMatchEvaluator",
  "description": "Strict string comparison of output fields.",
  "evaluatorTypeId": "uipath-exact-match",
  "evaluatorConfig": {
    "name": "ExactMatchEvaluator",
    "targetOutputKey": "result",
    "negated": false,
    "ignoreCase": false,
    "defaultEvaluationCriteria": {
      "expectedOutput": { "result": "5.0" }
    }
  }
}
```

> **camelCase note:** All field names inside the JSON config use camelCase (`targetOutputKey`, `ignoreCase`, `searchText`), not snake_case. The parameter tables below reflect this correctly.

---

### Evaluation Set Structure

Evaluation sets are JSON files in `evaluations/eval-sets/`. They define test cases and which evaluators to run.

```json
{
  "version": "1.0",
  "id": "my-eval-set",
  "name": "My Evaluation Set",
  "evaluatorRefs": ["JsonSimilarityEvaluator", "TrajectoryEvaluator"],
  "modelSettings": [
    {
      "id": "default",
      "modelName": "gpt-4.1-mini-2025-04-14"
    }
  ],
  "evaluations": [
    {
      "id": "test-case-1",
      "name": "Description of the test case",
      "inputs": {
        "query": "What is 2+2?"
      },
      "evaluationCriterias": {
        "JsonSimilarityEvaluator": {
          "expectedOutput": { "result": "4" }
        },
        "TrajectoryEvaluator": {
          "expectedAgentBehavior": "The agent should compute the answer directly."
        }
      }
    }
  ]
}
```

**Key fields:**
- `evaluatorRefs`: List of evaluator IDs — must match the `id` field in each evaluator config file
- `modelSettings`: LLM model overrides for the eval run (the `"default"` ID is used unless `--model-settings-id` is specified)
- `evaluations[].inputs`: Maps to your agent's `Input` model fields
- `evaluations[].evaluationCriterias`: Keyed by evaluator ID, contains per-evaluator criteria

#### Eval-Level `expectedOutput` Shorthand

You can set `expectedOutput` and `expectedAgentBehavior` at the evaluation level instead of repeating them inside every evaluator's criteria. Evaluators with `null` criteria will inherit them automatically:

```json
{
  "id": "test-case-2",
  "name": "Shorthand form",
  "inputs": { "a": 3, "b": 7, "operator": "+" },
  "expectedOutput": { "result": 10.0 },
  "expectedAgentBehavior": "The agent should add the two numbers.",
  "evaluationCriterias": {
    "JsonSimilarityEvaluator": null,
    "TrajectoryEvaluator": null
  }
}
```

Per-evaluator criteria override the eval-level value when both are present.

> **`selectedEntrypoint` note:** This field appears in some older examples but is not required. Pass the entrypoint as a CLI argument instead: `uv run uipath eval main.py eval-sets/...`

---

### Output-Based Evaluators

#### Contains Evaluator

Checks if output includes specific text. Returns 1.0 (found) or 0.0 (not found).

**`evaluatorConfig` fields:**
| Field | Type | Default | Description |
|---|---|---|---|
| `name` | str | `"ContainsEvaluator"` | Evaluator identifier (must match `id`) |
| `ignoreCase` | bool | `false` | Case-insensitive matching |
| `negated` | bool | `false` | Invert logic (fail when text IS found) |
| `targetOutputKey` | str | `"*"` | Output field to check (`"*"` = entire output) |

**Criteria:** `{ "searchText": "Paris" }`

> **Note:** The criteria key is `searchText` (camelCase), not `search_text`.

---

#### Exact Match Evaluator

Strict string comparison. Returns 1.0 (match) or 0.0 (mismatch).

**`evaluatorConfig` fields:**
| Field | Type | Default | Description |
|---|---|---|---|
| `name` | str | `"ExactMatchEvaluator"` | Evaluator identifier |
| `ignoreCase` | bool | `false` | Case-insensitive comparison |
| `negated` | bool | `false` | Invert matching logic |
| `targetOutputKey` | str | `"*"` | Output field to compare |

**Criteria:** `{ "expectedOutput": { "result": "4" } }`

---

#### JSON Similarity Evaluator

Tree-based structural comparison of JSON outputs. Returns continuous 0.0–1.0 score.

- **Strings**: Levenshtein distance
- **Numbers**: Absolute difference with 1% tolerance
- **Booleans**: Exact match
- **Score**: `matched_leaves / total_leaves`
- Extra keys in actual output are ignored; only expected keys are evaluated

**`evaluatorConfig` fields:**
| Field | Type | Default | Description |
|---|---|---|---|
| `name` | str | `"JsonSimilarityEvaluator"` | Evaluator identifier |
| `targetOutputKey` | str | `"*"` | Output field to compare |

**Criteria:** `{ "expectedOutput": { "key": "value" } }`

---

#### LLM Judge Output Evaluator

Uses an LLM to semantically assess output quality. Returns continuous 0.0–1.0 score.

**`evaluatorConfig` fields:**
| Field | Type | Default | Description |
|---|---|---|---|
| `name` | str | `"LLMJudgeOutputEvaluator"` | Evaluator identifier |
| `prompt` | str | — | Custom evaluation template |
| `model` | str | — | LLM model to use |
| `temperature` | float | `0.0` | Randomness (use 0.0 for consistency) |
| `maxTokens` | int | — | Response length limit |
| `targetOutputKey` | str | `"*"` | Output field to evaluate |

**Prompt placeholders:** `{{ActualOutput}}`, `{{ExpectedOutput}}`

**Criteria:** `{ "expectedOutput": { "result": "expected value" } }`

**Strict JSON variant** (`uipath-llm-judge-output-strict-json-similarity`): Per-key matching with penalty-based scoring for missing, wrong, similar, or extra keys.

---

### Trajectory-Based Evaluators

These evaluators inspect the agent's execution trace (tool calls, order, arguments, outputs).

#### LLM Judge Trajectory Evaluator

Uses an LLM to evaluate the agent's execution trajectory and decision-making.

**`evaluatorConfig` fields:**
| Field | Type | Default | Description |
|---|---|---|---|
| `name` | str | `"TrajectoryEvaluator"` | Evaluator identifier |
| `prompt` | str | — | Custom evaluation template |
| `model` | str | — | LLM model |
| `temperature` | float | `0.0` | Use 0.0 for consistency |

**Prompt placeholders:** `{{AgentRunHistory}}`, `{{ExpectedAgentBehavior}}`, `{{UserOrSyntheticInput}}`, `{{SimulationInstructions}}`

**Criteria:**
```json
{ "expectedAgentBehavior": "The agent should authenticate first, then fetch data." }
```

---

#### Tool Call Order Evaluator

Validates tools are called in expected sequence.

**`evaluatorConfig` fields:**
| Field | Type | Default | Description |
|---|---|---|---|
| `name` | str | `"ToolCallOrderEvaluator"` | Evaluator identifier |
| `strict` | bool | `false` | `true` = exact match (1.0/0.0), `false` = LCS-based partial credit |

**Non-strict scoring:** `score = LCS_length / expected_length`

**Criteria:**
```json
{ "tool_calls_order": ["authenticate", "fetch_data", "process"] }
```

---

#### Tool Call Count Evaluator

Validates tool invocation frequency.

**`evaluatorConfig` fields:**
| Field | Type | Default | Description |
|---|---|---|---|
| `name` | str | `"ToolCallCountEvaluator"` | Evaluator identifier |
| `strict` | bool | `false` | `true` = all-or-nothing, `false` = ratio of matched counts |

**Criteria:**
```json
{
  "tool_calls_count": {
    "fetch_data": ["=", 1],
    "process_item": [">=", 3]
  }
}
```

Supported operators: `"="`, `"=="`, `">"`, `"<"`, `">="`, `"<="`

---

#### Tool Call Args Evaluator

Validates tool call arguments.

**`evaluatorConfig` fields:**
| Field | Type | Default | Description |
|---|---|---|---|
| `name` | str | `"ToolCallArgsEvaluator"` | Evaluator identifier |
| `strict` | bool | `false` | All-or-nothing vs proportional scoring |
| `subset` | bool | `false` | Allow actual args as subset of expected |

**Criteria:**
```json
{
  "tool_calls": [
    { "name": "search", "args": { "query": "weather" } }
  ]
}
```

---

#### Tool Call Output Evaluator

Validates tool return values.

**`evaluatorConfig` fields:**
| Field | Type | Default | Description |
|---|---|---|---|
| `name` | str | `"ToolCallOutputEvaluator"` | Evaluator identifier |
| `strict` | bool | `false` | All-or-nothing vs proportional scoring |

**Criteria:**
```json
{
  "tool_outputs": [
    { "name": "fetch_data", "output": "expected result" }
  ]
}
```

---

### Custom Evaluators

Custom evaluators live in `evals/evaluators/custom/` and have three components:

**Project structure:**
```
your-project/
├── evals/
│   ├── evaluators/
│   │   ├── custom/
│   │   │   ├── my_evaluator.py
│   │   │   └── types/
│   │   │       └── my-evaluator-types.json
│   │   └── my-evaluator.json
│   └── eval_sets/
```

**Implementation pattern:**

```python
from uipath.eval.evaluators import BaseEvaluator, BaseEvaluatorConfig, BaseEvaluatorJustification
from uipath.eval.models import AgentExecution, BaseEvaluationCriteria, NumericEvaluationResult
from pydantic import Field

class MyEvaluationCriteria(BaseEvaluationCriteria):
    expected_values: list[str] = Field(default_factory=list)

class MyEvaluatorConfig(BaseEvaluatorConfig[MyEvaluationCriteria]):
    name: str = "MyCustomEvaluator"
    threshold: float = 0.8

class MyCustomEvaluator(
    BaseEvaluator[MyEvaluationCriteria, MyEvaluatorConfig, BaseEvaluatorJustification]
):
    async def evaluate(self, agent_execution, criteria) -> NumericEvaluationResult:
        # Your evaluation logic here
        score = 1.0  # Calculate your score
        return NumericEvaluationResult(score=score, details="Justification")
```

The custom evaluator's JSON config file references the Python implementation:
```json
{
  "version": "1.0",
  "id": "CorrectOperatorEvaluator",
  "evaluatorTypeId": "file://types/correct-operator-evaluator-types.json",
  "evaluatorSchema": "file://correct_operator.py:CorrectOperatorEvaluator",
  "description": "A custom evaluator that checks if the correct operator is used.",
  "evaluatorConfig": {
    "name": "CorrectOperatorEvaluator",
    "defaultEvaluationCriteria": { "operator": "+" },
    "negated": false
  }
}
```

**CLI commands:**
```bash
# Generate a template
uv run uipath add evaluator my-custom-evaluator

# Register evaluator (validates and generates config/type schemas)
uv run uipath register evaluator my_custom_evaluator.py
```

**Helper functions** (from `uipath.eval._helpers.evaluators_helpers`):
- `extract_tool_calls` — Extract tool calls with arguments from trace
- `extract_tool_calls_names` — Get tool names only
- `extract_tool_calls_outputs` — Extract tool outputs
- `trace_to_str` — Convert trace to string

---

### Running Evaluations

```bash
# Auto-discover entrypoint and eval set
uv run uipath eval --workers 10

# Specify entrypoint and eval set
uv run uipath eval main.py evaluations/eval-sets/evaluation-set-default.json --workers 10

# Run specific eval IDs only
uv run uipath eval --eval-ids "['valid-standard-address', 'invalid-address']" --workers 10

# Save results to file
uv run uipath eval --workers 10 --output-file results.json

# Override model settings
uv run uipath eval --workers 10 --model-settings-id default

# Resume from suspended state
uv run uipath eval --workers 10 --resume
```

**Key options:**

| Option | Description |
|--------|-------------|
| `--workers N` | Parallel workers (CLI default: 1; use 10 in this project) |
| `--eval-ids` | Run specific evaluation IDs only |
| `--eval-set-run-id` | Custom run ID (default: auto-generated UUID) |
| `--output-file` | Save detailed results to JSON |
| `--model-settings-id` | Override model settings from eval set |
| `--input-overrides` | Override input parameters per eval (JSON) |
| `--max-llm-concurrency` | Max concurrent LLM requests (default: 20) |
| `--enable-mocker-cache` | Cache LLM mocker responses |
| `--trace-file` | Save traces in JSONL format |

### Input Overrides (Multimodal)

Override file attachments per evaluation:

```bash
uv run uipath eval agent.py eval_set.json --workers 10 \
  --eval-ids '["eval-001"]' \
  --input-overrides '{
    "eval-001": {
      "filePath": {
        "ID": "550e8400-e29b-41d4-a716-446655440000"
      }
    }
  }'
```

Design-time format (relative paths):
```json
{
  "filePath": {
    "ID": "evaluationFiles/document.pdf",
    "FullName": "Document.pdf",
    "MimeType": "application/pdf"
  }
}
```

---

### Best Practices

1. **Combine evaluators**: Use output-based evaluators for result validation and trajectory-based for process validation
2. **Set temperature to 0.0** for LLM judge evaluators to get deterministic results
3. **Use non-strict mode** by default for trajectory evaluators — reserve strict for security-critical sequences
4. **Start simple**: Begin with JsonSimilarity for structured output, add LLM Judge for semantic edge cases
5. **Target specific fields**: Use `targetOutputKey` to minimize false positives
6. **Write specific trajectory descriptions**: Include sequential steps and decision points in `expectedAgentBehavior`
7. **Use eval-level `expectedOutput`** with `null` criteria when most evaluators share the same expected output — reduces repetition
8. **Use a stronger model for judges**: Use `gpt-4.1-2025-04-14` (not mini) in evaluator configs for more reliable scoring

---

### Developer-in-the-Loop Eval Improvement Loop

Use this as the default collaboration pattern when improving evaluations with a user.

**Loop:** Synthetic Data Generation -> Evaluation -> Refinement -> Evaluation


1. **Generate synthetic evaluation data**
   - Add or expand realistic and adversarial test cases in `evaluations/eval-sets/evaluation-set-default.json`.
   - For each case, define both:
     - `LLMJudgeSemanticSimilarity.expectedOutput`
     - `LLMJudgeTrajectory.expectedAgentBehavior`
   - Include edge cases intentionally (format noise, ambiguous inputs, incomplete addresses).

2. **Run evaluation and collect evidence**
   - Run targeted evals first for fast iteration:
     ```bash
     uv run uipath eval agent evaluations/eval-sets/evaluation-set-default.json --workers 10 --eval-ids "['case-1','case-2']" --output-file eval_results_targeted.json
     ```
   - Use full eval runs to validate broad quality:
     ```bash
     uv run uipath eval agent evaluations/eval-sets/evaluation-set-default.json --workers 10 --output-file eval_results_full.json
     ```

3. **Refine prompts and behavior with the developer**
   - Review low-score cases together and agree on intended behavior before changing code/prompt logic.
   - Prioritize prompt and criteria refinement first:
     - tighten `expectedAgentBehavior` wording for trajectory accuracy,
     - clarify expected output normalization rules,
     - remove ambiguous acceptance criteria.
   - Apply small, testable changes per iteration.

4. **Re-evaluate and compare deltas**
   - Re-run the same eval IDs after each refinement.
   - Compare before/after JSON outputs and trajectory scores to confirm improvement.
   - After any trajectory-focused change, always run a full regression pass and compare against the previous full-results file before considering the iteration complete.
   - Keep iterating until target quality is reached, then run full regression.

5. **Keep the user in the loop every cycle**
   - Share what changed, why it changed, and how scores moved.
   - Ask for explicit approval on behavior trade-offs when multiple valid interpretations exist.
   - Treat the loop as collaborative tuning, not one-shot implementation.
