# Survey: LLM-Driven Scenario Generation for Autonomous Driving

This document summarizes recent research and frameworks for scenario generation in autonomous driving, focusing on the use of LLMs, DSLs, and simulation platforms such as Scenic and CARLA.

---

## 1. ChatScene: Knowledge-Enabled Safety-Critical Scenario Generation for Autonomous Vehicles
- **Approach:** Uses Scenic (a probabilistic programming language for scenario specification) and CARLA (an open-source simulator).
- **Workflow:**
  1. Retrieve relevant code snippets (Scenic DSL) using a knowledge-enabled retrieval system.
  2. Evaluate the generated Scenic code in the CARLA simulator to test safety-critical scenarios.
- **Key Point:** Integrates knowledge retrieval and code generation for scenario-based testing.

---

## 2. Generating Traffic Scenarios via In-Context Learning to Learn Better Motion Planner
- **Approach:** Uses LLMs with in-context learning to generate Python code for CARLA simulation.
- **Resource:** [Scenario descriptions and code](https://github.com/Ezharjan/AutoSceneGen/blob/master/Codes/ICL/questions.py)
- **Workflow:**
  1. LLM generates Python scripts that describe traffic scenarios.
  2. The scripts are executed in CARLA to evaluate motion planners.
- **Key Point:** Direct Python code generation for simulation, leveraging in-context learning.

---

## 3. TARGET: Traffic Rule-based Test Generation for Autonomous Driving via Validated LLM-Guided Knowledge Extraction
- **Motivation:** Scenic and OpenScenario DSLs are error-prone and hard to validate.
- **Approach:**
  1. Proposes a new, validated DSL for scenario description.
  2. End-to-end framework: LLM extracts knowledge, generates DSL, and scenarios are validated before simulation.

---

## 4. LLM-Driven Testing for Autonomous Driving Scenarios
- **Approach:**
  1. LLM generates a JSON scenario description, following OCL (Object Constraint Language) rules.
  2. A custom engine translates the JSON into Python scripts for CARLA simulation.

---

## 5. Text2Scenario: Text-Driven Scenario Generation for Autonomous Driving Test
- **Approach:**
  1. LLM generates scenario code directly from text descriptions.
  2. No retrieval-augmented generation (RAG); LLM also performs syntax checking.

---

