---
description: How to synchronize schema changes with PowerSync sync_rules.yaml
---

# Sync Rules Update Skill

When you modify the database schema (e.g., adding/modifying tables or columns), you MUST also update the PowerSync configuration to ensure the offline database mirrors the cloud database accurately. 

## Process

1. **Modify Supabase Schema**: Change the schema in Supabase using migrations(using the supabase MCP) or the SQL editor.
2. **Update `lib/core/config/powersync.dart`**: Ensure the local `Schema` definition matches the new table structures exactly. Add or modify `Column` definitions as needed.
3. **Update `sync_rules.yaml`**: Ensure the `bucket_definitions` pull the required data. If a new table was added, add a `SELECT * FROM new_table WHERE ...` line matching the tenant scoping rules. 
4. **Deploy Sync Rules**: (If the user asks you to deploy). The sync rules need to be deployed to the PowerSync instance to take effect on the server side.

## Example `sync_rules.yaml` update

```yaml
config:
  edition: 2

bucket_definitions:
  user_data:
    parameters: SELECT tenant_id FROM profiles WHERE user_id = token_parameters.user_id
    data:
      - SELECT * FROM profiles WHERE tenant_id = bucket.tenant_id
      # ... other tables
      - SELECT * FROM new_table WHERE tenant_id = bucket.tenant_id
```

## Warnings
- Failing to update `sync_rules.yaml` will result in the new table data never downloading to the client device.
- Failing to update `powersync.dart` will result in local crashes when trying to query columns that don't exist in the local SQLite database.
