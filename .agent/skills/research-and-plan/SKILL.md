---
description: Pipeline for researching, asking questions, and planning before implementing complex features.
---

# Skill: Research -> Questions -> Plan Pipeline

Use this skill when tackling medium-to-complex user requests, feature additions, or UI/UX overhauls.
Do not make any code changes immediately. You MUST follow this pipeline:

## Step 1: Research First
Gather context by:
- Reviewing existing files in the workspace.
- Scraping provided web links (e.g., competitors, inspiration) using `read_url_content` or `browser_subagent`.
- Searching the web for concepts to understand industry standards and common terminology.

## Step 2: Ask Questions
Identify any ambiguities in the user's request:
- Formulate clear, concise questions regarding business logic, UI preferences, or database schema decisions.
- If multiple paths are possible, outline the pros and cons of each.

## Step 3: Draft an Implementation Plan
Create an `implementation_plan.md` artifact outlining:
- Database migrations and schema updates.
- Logic changes to core services and repositories.
- UI/UX designs and how they match the requested aesthetics.
- A Verification Plan detailing how you will test the changes locally.
- A "User Review Required" section highlighting specific design decisions or questions that need the user's input.

## Step 4: Notify User
Present your findings, ask your questions, and link the plan artifact for the user's approval.
- Use the `notify_user` tool with `BlockedOnUser: true`.
- Present your questions in a numbered list.
- Keep the message concise.

## Step 5: Wait for Approval
Do not begin Execution mode or edit any code until the user explicitly approves the plan or answers the questions.
