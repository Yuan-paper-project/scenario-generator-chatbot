# Search Workflow Documentation

## Overview

The `SearchWorkflow` is a sophisticated LangGraph-based system for generating and refining Scenic DSL scenario code based on natural language queries. It combines vector database search, LLM-powered scoring, and iterative refinement to produce high-quality scenario code.

---

## Architecture

### Core Components

1. **ScenarioMilvusClient**: PyMilvus client for accessing the `scenario_components` collection
2. **Code2LogicalAgent**: Converts user queries to structured logical interpretations
3. **ComponentScoringAgent**: Scores component matches against user criteria
4. **ComponentAssemblerAgent**: Merges component code snippets into the base scenario
5. **CodeAdapterAgent**: Adapts final code to match user requirements

---

## Workflow Graph

```
┌─────────────────────────────────────────────────────────────────┐
│                           START                                  │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                    ┌───────▼────────┐
                    │ Decide Start   │
                    │   Point        │
                    └───┬────┬───┬───┘
                        │    │   │
        ┌───────────────┘    │   └──────────────┐
        │                    │                   │
   ┌────▼─────┐      ┌──────▼──────┐     ┌─────▼────────┐
   │ Interpret│      │   Handle    │     │   Search     │
   │  Query   │      │  Feedback   │     │  Scenario    │
   └────┬─────┘      └──────┬──────┘     └──────┬───────┘
        │                   │                    │
        │  confirmed        │  search            │
        └──────────┬────────┘                    │
                   │                             │
                   └──────────┬──────────────────┘
                              │
                       ┌──────▼──────────┐
                       │  Score          │
                       │  Components     │
                       └──┬──────┬───┬───┘
                          │      │   │
            all_satisfied │      │   │ max_iterations
                          │      │   │
                          │      │   └─────────────┐
                          │      │                 │
                          │      │ needs_refinement│
                          │      │                 │
                          │  ┌───▼────────┐        │
                          │  │  Search    │        │
                          │  │  Snippets  │        │
                          │  └───┬────────┘        │
                          │      │                 │
                          │      └─────────────────┤
                          │                        │
                     ┌────▼────────┐               │
                     │  Assemble   │◄──────────────┘
                     │    Code     │
                     └────┬────────┘
                          │
                     ┌────▼────────┐
                     │   Adapt     │
                     │    Code     │
                     └────┬────────┘
                          │
                     ┌────▼────────┐
                     │     END     │
                     └─────────────┘
```


## Example Full Workflow Execution

```
User Query: "A car yields to another car at a 4-way intersection"

Step 1: Interpret Query
└─ Output: JSON logical interpretation

Step 2: Search Scenario
├─ Search 5 scenarios
├─ Select best: Scenario ID 42 (vector score: 0.8756)
└─ Retrieved base code

Step 3: Score Components (Iteration 0)
├─ Ego Vehicle: 100/100 ✓
├─ Adversarial Object: 100/100 ✓
├─ Ego Behavior: 50/100 ✗ (turns instead of yields)
├─ Adversarial Behavior: 80/100 ✓
└─ Spatial Relation: 95/100 ✓

Step 4: Search Snippets (Iteration 0→1)
└─ Ego Behavior: 50→72 (found better match)

Step 5: Score Components (Iteration 1)
└─ Ego Behavior: 72/100 ✓ (now satisfied!)

Step 6: Assemble Code
├─ Replace Ego Behavior (code changed)
└─ Output: Assembled code with new behavior

Step 7: Adapt Code
├─ Fine-tune parameters
├─ Adjust variable names
└─ Output: Final Scenic DSL code

Result: ✅ Complete scenario code matching user requirements
```

## Future Enhancements

- [ ] Config MODEL, weather, map
- [ ] Validatio with Validation Agent


