-- Deduplication / upsert strategy for revocation events
-- - Loads the latest batch from a staging table
-- - Keeps one canonical row per (docket, dot, license type, revocation type, effective date, serve date)
-- - Updates "last_seen_at" on repeated occurrences to support historical monitoring

INSERT INTO revokes_events (
  docket_number,
  dot_number,
  type_license,
  order1_serve_date,
  order2_type_desc,
  order2_effective_date,
  last_run_id
)
SELECT DISTINCT ON (
  s.docket_number,
  s.dot_number,
  s.type_license,
  s.order2_type_desc,
  s.order2_effective_date,
  s.order1_serve_date
)
  s.docket_number,
  s.dot_number,
  s.type_license,
  CASE
    WHEN NULLIF(s.order1_serve_date, '') IS NULL THEN NULL
    ELSE TO_DATE(s.order1_serve_date, 'MM/DD/YYYY')
  END AS order1_serve_date,
  s.order2_type_desc,
  TO_DATE(s.order2_effective_date, 'MM/DD/YYYY') AS order2_effective_date,
  s.run_id AS last_run_id
FROM revokes_stage s
WHERE s.run_id = '{{ RUN_ID }}'
ORDER BY
  s.docket_number,
  s.dot_number,
  s.type_license,
  s.order2_type_desc,
  s.order2_effective_date,
  s.order1_serve_date,
  s.ingested_at DESC
ON CONFLICT (
  docket_number,
  dot_number,
  type_license,
  order2_type_desc,
  order2_effective_date,
  order1_serve_date
)
DO UPDATE SET
  last_seen_at = NOW(),
  last_run_id  = EXCLUDED.last_run_id;
