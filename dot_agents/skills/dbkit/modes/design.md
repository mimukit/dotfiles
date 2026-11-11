# Mode `design`: model a schema change

Design turns a feature's data needs into a schema edit that matches the project and passes [the schema standard](../SKILL.md#the-schema-standard). It edits the project's schema source, generates the migration through the project's tool, and checks that migration before it reports. It never applies the migration.

Run the steps in order. At each choice, make the call and give the reason in one line; offer one answer, never a menu.

### 1. Read the existing schema

Run [Stack detection](../SKILL.md#stack-detection) and [Project conventions win](../SKILL.md#project-conventions-win). Then list every existing table the change touches or references, with its key type and the indexes on the columns the change uses.

**Done when** the stack and convention lines are stated, and every table the change touches or references is listed, or the change is stated to add only standalone tables.

### 2. Settle each table, key, constraint, and index

Write down every entity and every fact the feature stores. Place each one under [Normalize first](../SKILL.md#normalize-first), then walk every heading of the schema standard against it, with the engine file's types (for Postgres, [Types to avoid](../engines/postgres.md#types-to-avoid) and [Index types](../engines/postgres.md#index-types)). Where the repo's convention overrides a rule, follow the repo and record the break as a finding.

Every index names the query or constraint it serves under [Indexes earn their write cost](../SKILL.md#indexes-earn-their-write-cost), and every foreign key column gets its index under [Foreign keys and their index](../SKILL.md#foreign-keys-and-their-index).

A schema question with no change ends here: go to [Report the decisions](#5-report-the-decisions).

**Done when** every table, column, key, constraint, and index in the change has a decision and a one-line reason, and every heading of the schema standard has been applied.

### 3. Edit the schema source and generate the migration

Edit the project's own schema source (a Drizzle schema file, `schema.prisma`, Django models, or SQL for a raw-SQL repo) in the repo's style. Read [orms.md](../orms.md), then generate the migration with the project's script (`db:generate`) or the tool's generate command. A generator that connects to a database follows [the disposable target](../SKILL.md#the-disposable-target) rule.

A change to a live table that needs more than one deploy (a rename, a drop, a type change, a tightened constraint on existing rows) goes through `migrate` **write**: read [migrate.md](migrate.md) and follow its write branch for that part.

**Done when** the schema source holds every decision, and one migration file exists for the change, or the change has passed to `migrate` write.

### 4. Check the generated migration

Run `migrate` **check** on the generated file as the last step before the report: read [migrate.md](migrate.md) and follow its check branch. Fix every statement with a verdict other than safe, in the migration or the schema source, then check again.

**Done when** the risk table shows every statement as safe, or each remaining verdict has a stated reason for the user to decide.

### 5. Report the decisions

Report in chat:

- **Decisions table.** One row per table, key, constraint, and index: the item, the decision, and a one-line reason. Mark each repo-convention override.
- **Risk table.** The table from the check step, when a migration was written.
- **ER diagram.** A Mermaid `erDiagram` only when the change adds three or more related tables.

**Done when** every settled item has a row, and the diagram is present exactly when the change adds three or more related tables.

### 6. Hand off

**What changed.** Name each changed schema file and the migration file. State that no migration was applied. State whether a generator ran or you wrote the SQL by hand, and which `--help` or docs you read.

**Where it landed.** Give the path of each changed file.

**Next.** Apply the migration on the dev database with the project's own command, for example `pnpm db:migrate`. When the change has held steps, follow the `migrate` hand-off instead.
