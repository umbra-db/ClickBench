# Trash Schema Benchmark

The same as ClickBench, but the `hits` table is split into a hundred tables with two columns each: `id` and one of the original columns. `hits` becomes a view that joins all of them by `id`, so every query has to join a hundred tables.

This models data science and AI workloads where there is often a large dataset of objects (images, comments, HTML pages) with iteratively computed properties (classification, embeddings, annotations), each stored in a separate "parallel" table sharing the same primary key. The goal is to find opportunities to optimize queries on top of such a schema.

The queries and settings are identical to ClickBench. `create.sql` defines the per-column tables sorted by `id` and the `hits` view; `split.sql` distributes the loaded data from a staging table into the per-column tables.
