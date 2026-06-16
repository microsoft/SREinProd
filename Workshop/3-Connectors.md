# Module 3 - Connectors

[← Module 2: Deploy the Agent](./2-Deploy-Agent.md) | [Workshop home](./ReadMe.md) | [Next: Module 4 →](./4-Connect-Observability.md)

## Objective

Extend the agent's tool surface beyond the built-in data sources by adding **connectors**. Connectors give the agent additional tools for automating incident handling: opening tickets in your incident system, drafting change records, talking to non-Azure platforms, or triggering external runbooks.

Walk through the connector catalog **before** Module 5 (response plans), so participants understand which automated actions are even possible before they design the guardrails around them.

> Time: ~20 min (5 min framing, 10 min hands-on, 5 min discussion).
> Prereq: a working agent from Module 2 (`sreagent-sreinprod`).

## What a connector is (and is not)

| Aspect | What it is | What it is not |
| --- | --- | --- |
| **Connectors** | Optional, discrete tool integrations the agent can call to read or write external systems while reasoning about an incident | Telemetry data sources (those are wired in Module 4) |
| **Examples** | Incident systems, ticketing / change-management, communication platforms, CI/CD, secrets brokers, custom HTTP / MCP endpoints | Anything reachable purely through Azure RBAC (the agent already has that path) |
| **Why use one** | The agent can take a closed-loop action: investigate, propose, then act in a system *outside* Azure | A connector does not bypass the agent's response plan or its RBAC; you still control approvals |

For the catalog and configuration reference, see [Connectors in Azure SRE Agent](https://go.microsoft.com/fwlink/?linkid=2341945) on Microsoft Learn.

## Lab steps

### Step 1: Open the Connectors page

In the agent (`https://sre.azure.com/agents/.../sreagent-sreinprod`), open the agent's left navigation and select **`Connectors`**.

You should see the page header **"Connectors"** with the introductory copy:

> *Add a connector to give the agent additional tools for automating incident handling.*

### Step 2: Inspect the catalog

Browse the available connector tiles. They are typically grouped by category (incident management, ticketing / change, communication, custom). For each tile, capture three things:

- the system it integrates with
- the actions it exposes to the agent (read-only vs read/write)
- the authentication mode it requires (OAuth, PAT, API key, managed identity, etc.)

Discuss as a group: which two or three connectors would have shortened your most recent real incident?

### Step 3: Add one connector

Pick one connector that maps to a system you already operate (an incident platform you actually use, a ticketing system you actually file in, a chat platform you actually post to). Click **`+ Add`** on its tile and walk the configuration dialog:

1. Provide a connector name (this is how the agent will refer to the tool in chat).
2. Authenticate. Use a *test* account or a scoped PAT, never personal production credentials.
3. Scope the connector. Most connectors let you constrain *which* projects, queues, or channels the agent can touch.
4. Save.

> If your tenant blocks all listed connectors, configure a **custom HTTP / MCP connector** pointing at a sandbox endpoint of your choice. The mechanics are the same and the discussion below still applies.

### Step 4: Validate from chat

Back in the agent's chat pane, ask a question that *requires* the new connector. Example prompts:

```text
What incidents are currently open in <connector-name>?
```

```text
Open a draft change record in <connector-name> for "rotate INJECT_ERROR back to 0 on the production slot of app-sreinprod-demo-*". Do not submit; show me the payload.
```

Confirm the agent uses the connector tool and surfaces a verifiable response (an incident ID, a change-record draft, a chat-post preview, etc.).

### Step 5: Remove or scope down for the workshop

Connectors that can *write* to production systems should not stay enabled in a learning environment. After validation, do one of:

- **Remove** the connector, or
- **Reduce its scope** to read-only or to a sandbox project, or
- **Disable** it (toggle off) until Module 6's drill explicitly needs it.

This intentional cleanup is part of the lab; participants should leave Module 3 with the habit of pruning the agent's tool surface.

## Discussion prompts

- Which non-Azure systems do you most often update by hand during an incident?
- Who in your org owns the credentials a connector would need? (Often this is the missing prereq.)
- For each connector you would enable, what is the minimum scope that still makes it useful?
- What action do you absolutely *not* want the agent to take through a connector, even with approval?

## Success criteria

- Participants can articulate the difference between a data source (Module 4) and a connector (this module).
- At least one connector has been added, validated from chat, then scoped down or removed.
- The team leaves with a written list of which connectors they would enable in production, and which they would not.

## Further reading

- [Connectors in Azure SRE Agent](https://go.microsoft.com/fwlink/?linkid=2341945): the official catalog and configuration reference.
- [Module 4: Connect Observability](./4-Connect-Observability.md) wires the *data* the agent needs to know an incident is happening.
- [Module 5: Response Plans and Guardrails](./5-Response-Plans-and-Guardrails.md) governs *when* the agent is allowed to invoke a connector.
