# AgriBridge assessment specification

## 1. What is in this repository

Two independent components, each with its own dependency manifest and its own lifecycle.

| Path   | Component | Stack |
|--------|-----------|-------|
| `api/` | `agribridge-api` — REST API, business logic, data access | Node.js (ESM), Express |
| `frontend/` | `agribridge-web` — browser client | React, built by Vite |

`api/` requires Node.js 20.11.0 or newer, declared in its manifest. Both components carry
a lockfile; reproducible dependency resolution is expected of you.

Container definitions, orchestration, the pipeline and infrastructure now accompany
the source. They implement the toolchain required in §4.

---

## 2. The application

### 2.1 Domain model

Four tables, created by a migration that ships with the API (`api/src/migrations/`):

- **users** — every account carries a role of `farmer` or `buyer`. Role determines
  authorisation, enforced server-side on every protected route.
- **lots** — a quantity of a crop offered by a farmer, with crop type, tonnage, grade and
  originating state. Carries a status reflecting whether it is still open.
- **orders** — a buyer's claim against a lot, with a status lifecycle.
- **order_events** — an append-only history of transitions, one row per change.

Order creation reserves lot capacity and inserts the order within a single transaction:
both happen or neither. Monetary values are whole naira held as 64-bit integers.

### 2.2 Roles

Authorisation is not cosmetic. Only farmers may create or withdraw lots and run a credit
check; only buyers may place orders. Order listings are scoped to the caller — a buyer
sees their own orders, a farmer sees orders against their own lots.

### 2.3 Authentication

Credentials are verified against a bcrypt hash. A successful login issues a signed JWT
delivered as an `httpOnly` cookie, which the browser returns automatically on subsequent
same-origin requests. The client never handles the token directly and no bearer token is
read from a header. Two consequences you must design around:

- The cookie is same-origin. The API and the web client must be reachable under **one
  origin** as far as the browser is concerned. How you achieve that is yours to solve, and
  it is the single decision most likely to break a first deployment.
- The cookie's `Secure` attribute follows the environment. Over plain HTTP in a production
  configuration, the browser will refuse to store it.

### 2.4 HTTP surface

Application routes live under `/api`. Operational routes live at the **root**, outside
`/api`, deliberately — so that probes and scrapes never depend on any path rewriting you
introduce in front of the service.

| Route | Purpose |
|-------|---------|
| `/api/auth/*` | login, logout, current user |
| `/api/lots/*` | browse with filters, a farmer's own lots, create, withdraw |
| `/api/orders/*` | list, fetch, create, change status, credit check |
| `/api/stats/*` | dashboard summary, breakdown by crop |

### 2.5 Operational surface

These four endpoints exist to be consumed by the platform you build. Understanding why
there are two health endpoints rather than one is part of the assessment.

| Endpoint | Meaning |
|----------|---------|
| `/healthz` | **Liveness.** Is the process alive? Touches no dependency. Answers 200 whenever the event loop is running. |
| `/readyz` | **Readiness.** Can this process usefully serve traffic right now? Checks its dependencies, answers 503 when it cannot, and reports a `degraded` flag. |
| `/metrics` | Prometheus exposition: HTTP rates and latencies, database pool saturation and query timings, cache outcomes, build information. |
| `/version` | The running version, commit SHA, build timestamp and artifact tag. |

The liveness endpoint does not check the database. Work out what would happen during a
brief database interruption if it did, and be ready to explain it.

Readiness distinguishes **unready** from **degraded**. Losing the cache costs latency;
losing the database costs availability. The API reports these differently, and whatever
you build in front of it should respect the difference rather than flatten it.

### 2.6 Process behaviour

The API retries a not-yet-available database on startup rather than exiting immediately,
so a cold environment can converge. On `SIGTERM` it stops accepting connections, drains
in-flight requests, then closes its database and cache within a bounded grace period.
Both behaviours only pay off if whatever supervises the process is configured to allow
them. Schema migrations and demo-data seeding are each controlled by their own switch.

### 2.7 The web client

Five views: login, dashboard, farmer, buyer, orders.

**The web bundle contains no API hostname, no environment name and no configuration of any
kind.** Every request it makes is relative to the origin it was served from. This is
deliberate, and it is the property that makes one build artifact promotable across every
environment unchanged. Preserve it. Two things follow:

- Whatever serves the built assets must also route `/api` to the API at **runtime**. The
  bundle cannot do this for you and must not be rebuilt to point somewhere new.
- In local development the dev server proxies `/api` itself, honouring an `API_URL`
  variable. That mechanism exists only in development and will not be present in the
  artifact you ship.

The client targets 2 GB Android phones on slow mobile connections. A bundle-size budget is
configured in the Vite config and is a functional requirement, not a preference.

### 2.8 Checks the codebase supports

Everything in this section already exists and already runs. None of it needs writing, and
all of it belongs in your pipeline (§4.4). Both manifests declare scripts for each.

**A. Linting — both components.** Flat ESLint 9 configuration, one per component.

| | Covers | Notes |
|---|---|---|
| `api/` | `src/` and `test/` | Node globals declared explicitly |
| `frontend/` | `src/` including JSX | React plugin; React version detected |

Both enforce the same core rules as **errors** — unused variables, strict equality,
`prefer-const`, no `var`, mandatory semicolons — and the API adds quote style, trailing
commas and brace style. Two rules are **warnings**, not errors: `no-console` in both, and
a 110-character line limit in the API. Decide deliberately whether a warning is allowed to
pass your pipeline, and be able to say why.

**B. API unit tests — 28 cases, no external dependencies.** These cover the domain layer,
where the business rules live, and run anywhere with no database and no network:

- `calculateOrderTotal` — pricing, plus a dedicated input-validation suite
- `assessCreditEligibility` — the credit rules
- the order lifecycle state machine — legal and illegal transitions, and which role holds
  the authority to make each one

**C. API integration tests — 28 cases across 6 suites, against a real PostgreSQL.** This
is the suite with a hard infrastructure requirement, and the one most likely to be quietly
skipped. It covers the operational endpoints, authentication, a full order lifecycle
end to end, the dashboard aggregates, error handling, and guarantees made by the schema
itself.

What it needs, and what it does for itself:

- A **real, reachable PostgreSQL**. Not a mock. Your pipeline must provide one, and this
  is a direct consequence of §3.1 rather than a separate problem.
- It defaults to its own database name, distinct from the development one, so it is not
  pointed at anything precious.
- It runs the schema migration itself during setup, sets its own signing secret, lowers
  the password-hashing cost to stay fast, and disables the cache unless told otherwise.
- It cleans up the rows it created, in foreign-key order, afterwards.
- Suites share one database, so file parallelism is switched off; timeouts are raised to
  suit real I/O. Expect it to be slower than the unit suite, and do not "fix" that by
  making it concurrent.

A note on why it exists at all: the failure this suite guards against is a dependency
resolving to a version whose behaviour toward the database changed. A unit test with a
mocked database cannot catch that class of fault by construction. **The default test
script runs the unit suite only** — a pipeline that invokes just that will go green
without ever having reached a database. Run both.

**D. Coverage, with a real gate.** The API measures coverage with the v8 provider and
**fails below 70%** on lines, functions, branches and statements. The threshold is scoped
deliberately to the domain layer rather than the whole codebase — chasing a percentage
across glue code teaches nothing. This is a genuine pass/fail check, not a report. Reports
are emitted in text, lcov and JSON-summary form, so a coverage service can consume them.

The web component measures coverage in the same way but has **no threshold configured**.
Setting one is a legitimate improvement you may make.

**E. Machine-readable test results.** The API test run emits a JUnit XML report to a
reports directory. Use it — a pipeline that surfaces which test failed is worth more than
one that surfaces only an exit code.

**F. Web unit tests — 11 cases.** Formatting and presentation helpers: currency, tonnage,
label mapping and relative time. They run in a Node environment against `.test.js` files.

**G. The production build is itself a check.** Building the web component fails on broken
imports, bad syntax and unresolved modules, and it enforces the bundle-size budget of §2.7
through a configured warning limit and explicit vendor chunking. Treat a budget breach as
a signal, not noise.

**H. Dependency integrity.** Both components carry a lockfile. An install that resolves
strictly from the lockfile is itself a check: it fails when a manifest and its lockfile
disagree, which is exactly the drift you want caught before a release rather than after.
A vulnerability audit over those same dependencies is available from the package manager.

**What the codebase does not have.** There are no component or DOM tests over the React
views, no end-to-end browser tests, and no load tests. The web test environment is plain
Node, with no browser environment configured. Adding any of these is permitted and is a
genuine improvement, but each introduces new development dependencies and is an extension
beyond the required work — get A through H running in the pipeline first.

---

## 3. Backing services you must provide

The application is not self-contained. It will not start usefully without these.

### 3.1 PostgreSQL — required

The system of record. The API refuses to become ready without it.

- It must **persist**. Storage that is lost when the workload restarts or moves is not
  acceptable, and a demonstration that survives a restart is part of the assessment.
- The API expects to connect as a named database and user, with a password, and can be
  told whether to negotiate TLS.
- Connection pool sizing, connection and idle timeouts, and a per-statement timeout are
  all tunable through configuration. Defaults exist; defaults are rarely right.
- The schema is created by the application's own migration, not by hand. Decide when and
  by what that migration runs, and what happens when two instances start at once.
- You are responsible for a backup and restore story. An untested backup is not a backup.

### 3.2 Redis — required

The cache for the price index and dashboard aggregates.

The API treats the cache as **optional at runtime**: if Redis is unreachable it keeps
serving from PostgreSQL, reports itself degraded, and continues. That is a property of the
application's resilience design. **It is not permission to skip standing Redis up.** You
must provide it, and you must be able to show the difference in behaviour and in the cache
metrics between a healthy cache and an absent one.

A switch exists to declare the cache mandatory, which promotes its loss from degradation
to unreadiness. Decide which posture each of your environments takes, and justify it.

### 3.3 A secrets manager — required

**The API's secret configuration must come from a secrets manager. This is not optional
and there is no accepted alternative.**

These three values are secrets:

| Secret | Consequence of exposure |
|--------|------------------------|
| `PGPASSWORD` | direct access to all marketplace data |
| `JWT_SECRET` | forge a session for any account, in any role |
| `SEED_PASSWORD` | known credentials on every seeded demo account |

Requirements:

- Secrets are resolved from the secrets manager and delivered to the process **at
  runtime**, as part of starting it in an environment.
- No secret may be committed to this repository, written into a build artifact, passed as
  a build argument, or embedded in any layer or bundle. Build inputs are recoverable by
  anyone who obtains the artifact; treat them as public.
- No secret may appear in logs, in a pipeline transcript, or in any tracked file.
- A secret must be rotatable without rebuilding the application. If rotation forces a
  rebuild, your configuration is in the wrong place.
- `JWT_SECRET` has no default in a production environment — the API deliberately refuses
  to start without it. Do not defeat this.

`api/.env.example` documents the **shape** of local development configuration only. It is
not a deployment mechanism, and nothing resembling it should reach a real environment.

### 3.4 Beyond the application

The application emits Prometheus metrics and structured JSON logs to stdout, carrying a
correlation id per request. Both are produced whether or not anything collects them.
Deciding what collects, stores, queries and alerts on them is part of your platform
design — as is how traffic reaches the components, how TLS terminates, and how the two
components are built, versioned, promoted and rolled back.

---

## 4. Required toolchain

Four deliverables, all of them living in this repository alongside the application. The
tools are named deliberately and are **not** a free choice — substituting an equivalent
does not satisfy the requirement. What you build with each of them is yours to design.

They are assessed as one system, not four separate exercises. See §4.5.

### 4.1 Terraform — the infrastructure

All infrastructure is defined as Terraform configuration held in this repository.

- **It must be complete.** Everything the application depends on is created by Terraform:
  networking, the compute or cluster it runs on, the PostgreSQL and Redis services of
  §3 or their hosting, the secrets manager of §3.3 and the secret entries within it,
  ingress and DNS, and the identities and permissions that tie them together. If any part
  of the environment exists because someone made it by hand, it is not done.
- **Nobody may SSH into anything.** There is no step in your submission that involves
  logging into a machine to finish a job — not to install a package, not to edit a config
  file, not to start a service, not to load a schema, not to fix something once. Any
  configuration a machine needs is expressed in the Terraform configuration itself and
  applied when the machine is created. A deliverable that needs a human on a shell to
  become usable is incomplete, and this is the requirement most likely to catch people
  out late.
- **It must be repeatable.** Applying a second time changes nothing. Destroying and
  re-applying reproduces a working environment from nothing. An environment that only
  exists because of the particular order someone did things in is not reproducible.
- **State is a decision.** Where state lives, how it is locked against concurrent use,
  and who can read it are all things to decide deliberately and explain. Note that state
  can contain secret material even when your configuration does not.
- **It creates secrets; it does not contain them.** Terraform provisions the secrets
  manager and the entries in it. Secret values are never committed as part of doing so.
- **It must hand off cleanly.** The values the rest of your stack needs — endpoints,
  connection details, secret identifiers, cluster information — are surfaced as outputs
  so that §4.2 and §4.4 can consume them. Copying a value by hand from one place to
  another is the failure this requirement exists to prevent.

Terraform may be run locally. It does not have to run in the pipeline — see §4.4.

### 4.2 Helm — the Kubernetes deployment

Both components are deployed to Kubernetes by a Helm chart held in this repository.

- The chart carries the runtime configuration of §5.2, the probe wiring of §2.5, the
  persistence required by §3.1, and the `/api` routing required by §2.7.
- It references secrets; it never contains them. The values that reach the API come from
  the secrets manager at startup, per §3.3.
- The termination grace it allows the pod must be consistent with the API's own shutdown
  grace, or the draining behaviour described in §2.6 is wasted.
- The image tags it deploys correspond to the build-time identity of §5.1, so that what
  `/version` reports can be traced back to a commit.
- **One chart, several environments.** Environments differ by the values supplied to the
  chart, never by a separate copy of it.

### 4.3 Docker Compose — the local environment

A Compose definition that brings up the whole stack — API, web, PostgreSQL and Redis —
on one machine.

Both components must therefore be containerised, and the images Compose runs are the
same images the pipeline builds and Helm deploys. If the local stack and the deployed
stack are built from different things, the local one is not evidence of anything.

This is the one place where configuration may come from local files rather than a secrets
manager. Local development values only: no real credential belongs in a Compose file, an
environment file, or anything else this repository tracks.

### 4.4 GitHub Actions — the CI/CD pipeline

A pipeline defined in this repository that genuinely runs and genuinely passes. A workflow
file that has never executed successfully is not a deliverable.

It must, on its own and without anyone intervening:

- resolve dependencies reproducibly from the lockfiles, strictly enough that a manifest
  which has drifted from its lockfile fails the run (§2.8 H);
- lint both components, and treat the warning-level rules as a decision you have made
  rather than one you have ignored (§2.8 A);
- run **every** check in §2.8, not the convenient ones: the API unit suite (B), the API
  integration suite against a real PostgreSQL that the pipeline stands up for it (C), and
  the web unit suite (F);
- enforce the coverage threshold (§2.8 D) as a gate that can fail the run, and publish the
  test report it produces (§2.8 E) so a failure names the test that broke;
- build both components — the web build being a check in its own right (§2.8 G) — and
  stamp both images with the build-time identity of §5.1, derived from the commit being
  built rather than supplied by hand;
- publish those images somewhere the deployment can pull them from;
- deploy them with the chart of §4.2;
- stop, and release nothing, the moment any check fails.

Whatever credentials it needs are held as pipeline secrets and never committed. The
pipeline deploys into the infrastructure Terraform created; it consumes those outputs
rather than hardcoding what they produced.

**Terraform is not required to run in this pipeline.** Provisioning infrastructure from
your own machine is acceptable for this project. That exemption applies to Terraform and
nothing else: the build, test, publish and deploy path must be automated end to end and
must work.

### 4.5 They must fit together

The four deliverables above are one system. The test is whether a person who has never
seen your project can go from an empty account to a running, reachable application using
only what is in this repository, without editing a file that was not meant to be edited,
without copying a value from one output into another input by hand, without an
undocumented step, and without opening a shell on any machine.

If any seam between Terraform, Helm, Compose and the pipeline needs a human to bridge it,
that seam is where you lost the marks.

---

## 5. Configuration: build-time versus runtime

**Understanding this distinction, and applying it correctly, is an explicit assessment
criterion.** Getting it wrong is the most common way a project that "works" fails review.

### 5.1 Build-time configuration

Values fixed at the moment the artifact is produced. They are **baked in**. They are
identical in every environment the artifact is promoted to, and changing one means
producing a new artifact.

In this application, build-time values exist for one purpose only: traceability. They
originate from the build's git context, not from a human, and they surface on `/version`
and as build information in the metrics.

| Variable | Origin |
|----------|--------|
| `APP_VERSION` | the release version of the artifact |
| `GIT_SHA` | the commit the artifact was built from |
| `BUILD_DATE` | when it was built |
| `IMAGE_TAG` | the tag it was published under |

These let anyone answer "which commit is actually running?" in one request. You should be
able to walk the chain — commit, to artifact, to release, to running instance — without
guessing. Expect to be asked.

The web component has **no** build-time configuration at all. See §2.7.

### 5.2 Runtime configuration

Values supplied when the process starts in a particular environment. They differ between
environments. Changing one requires a restart, never a rebuild.

Everything else is runtime configuration, grouped by concern:

| Concern | Variables |
|---------|-----------|
| Process | `NODE_ENV`, `PORT`, `LOG_LEVEL`, `TRUST_PROXY`, `SHUTDOWN_GRACE_MS` |
| Database | `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`, `PGSSL`, `PG_POOL_MAX`, `PG_POOL_MIN`, `PG_CONNECT_TIMEOUT_MS`, `PG_IDLE_TIMEOUT_MS`, `PG_STATEMENT_TIMEOUT_MS` |
| Cache | `REDIS_ENABLED`, `REDIS_URL`, `REDIS_REQUIRED`, `CACHE_TTL_SECONDS` |
| Auth | `JWT_SECRET`, `TOKEN_TTL_SECONDS`, `COOKIE_NAME`, `COOKIE_SECURE`, `BCRYPT_ROUNDS` |
| Startup | `RUN_MIGRATIONS`, `SEED_DEMO_DATA`, `SEED_PASSWORD` |

Runtime configuration divides again, and the two halves must not be carried the same way:

- **Non-secret** values — hostnames, ports, sizes, timeouts, feature switches. Visible,
  reviewable, held in ordinary configuration.
- **Secret** values — the three named in 3.3. Held in the secrets manager, resolved at
  startup, never visible in configuration or in the repository.

### 5.3 The test

A single question settles where any value belongs:

> Does this value change when the same artifact is deployed to a different environment?

If yes, it is runtime configuration, and baking it in is a defect — you have created an
artifact that cannot be promoted, and the thing you tested in staging is not the thing you
released. If no, and it describes the artifact itself, it is build-time.

A secret is **always** runtime, whatever the answer.

---

## 6. What you are being assessed on

The application already works. You are assessed on everything around it:

1. Both components build into versioned, reproducible artifacts, and the running version
   is identifiable from `/version` at any moment.
2. PostgreSQL and Redis are stood up and reachable, and PostgreSQL's data survives a
   restart.
3. The API's secrets come from a secrets manager at runtime, and nothing in your
   repository or your artifacts contains a secret.
4. Build-time and runtime configuration are correctly separated, and you can defend every
   placement.
5. The same artifact reaches more than one environment, differing only in runtime
   configuration.
6. Liveness and readiness are wired to the right endpoints, with the right consequences.
7. Tests and linting run automatically, and a failure stops a release.
8. Metrics and logs are collected and visible, and the degraded cache state is observable.
9. A deployment can be rolled back, and a database restored, on evidence rather than hope.
10. Every environment is created by Terraform, reproducibly, and no part of it was made or
    repaired by hand.
11. Nothing in your submission requires anyone to SSH into a machine, for any reason.
12. The Compose stack, the chart and the pipeline all run the same images, and the four
    deliverables of §4 join up without a human bridging the gaps.
13. Nothing in your setup requires a human to remember an undocumented step.

The tooling is fixed: Terraform, Helm, Docker Compose and GitHub Actions, as set out in
§4. Everything else — the topology, the platform, how you cut the environments, what you
run where — is yours to choose, and yours to justify. A defensible simple design beats an
impressive one you cannot explain.
