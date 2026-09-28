# Underground Mining DBMS

**[→ Visual walkthrough](https://akshit9162.github.io/Underground-Mining_DBMS-Project/)**

A database system for managing an underground mining operation: workers, equipment, shifts,
training, maintenance and safety incidents. It has two parts: an Oracle schema with the business
rules enforced in the database, and a Flask web application with analytics dashboards.

Team project (DBMS course). Originally committed by [Rachit Pandey](https://github.com/rachhittt);
this copy keeps the full history.

## Database (`database_part/`)

| File | Contents |
|---|---|
| `01_Schema.sql` | 15 tables with primary and foreign keys (24 references), 14 CHECK constraints and 15 indexes |
| `02_PL_SQL.sql` | 21 triggers and 14 stored procedures and functions that enforce safety and data-integrity rules |
| `03_Complex_Queries.sql` | Reporting queries: multi-way joins, CTEs, aggregation with `GROUP BY` / `HAVING`, `LISTAGG` |

## Application (`mining_app/`)

Flask app (SQLite for local use) with 25+ routes and 7 analytics dashboards: safety incidents and
hotspots, equipment performance and maintenance compliance, worker and shift utilisation, training
compliance, risk assessment, and department scorecards. See [`mining_app/README.md`](mining_app/README.md)
for setup and [`mining_app/COMPLEX_QUERIES_GUIDE.md`](mining_app/COMPLEX_QUERIES_GUIDE.md) for the
queries behind each dashboard.

## Contributors

Built jointly by **Rachit Pandey** and **Akshit Gupta** across the whole project: schema,
PL/SQL triggers and procedures, reporting queries, and the Flask application.
