-- Summarise one evaluation window from music_library.chunk_stats.
--
-- chunk_stats rows are cumulative snapshots, not deltas. Keep only the
-- most complete row per (user, song), then aggregate those rows across the swarm.
--
-- Optional psql variables:
--   since      timestamp lower bound, defaults to 1970-01-01
--   price      egress price in USD per decimal GB, defaults to 0.09
--   chunk_kib  chunk size, defaults to 64

\if :{?since}
\else
  \set since 1970-01-01
\endif
\if :{?price}
\else
  \set price 0.09
\endif
\if :{?chunk_kib}
\else
  \set chunk_kib 64
\endif

DROP TABLE IF EXISTS _eval_final_rows;

CREATE TEMP TABLE _eval_final_rows AS
SELECT DISTINCT ON (cs.user_id, cs.song_file_hash)
       cs.user_id,
       cs.song_file_hash,
       cs.song_name,
       cs.local_cached_chunks,
       cs.p2p_chunks,
       cs.server_chunks,
       cs.total_chunks
FROM   music_library.chunk_stats cs
WHERE  cs.timestamp >= :'since'::timestamptz
ORDER  BY cs.user_id, cs.song_file_hash, cs.total_chunks DESC, cs.timestamp DESC;

\echo ''
\echo '== Per listener / song =='
SELECT user_id,
       left(song_name, 28) AS song,
       total_chunks        AS total,
       server_chunks       AS server,
       p2p_chunks          AS p2p,
       local_cached_chunks AS cache,
       round(100.0 * server_chunks / NULLIF(total_chunks, 0), 1)        AS server_pct,
       round(100.0 * p2p_chunks / NULLIF(total_chunks, 0), 1)           AS p2p_pct,
       round(100.0 * local_cached_chunks / NULLIF(total_chunks, 0), 1)  AS cache_pct
FROM   _eval_final_rows
ORDER  BY user_id, song_name;

\echo ''
\echo '== Swarm aggregate =='
SELECT sum(total_chunks) AS total_chunks,
       sum(server_chunks) AS server_chunks,
       sum(p2p_chunks) AS p2p_chunks,
       sum(local_cached_chunks) AS cache_chunks,
       count(*) AS sessions,
       round(100.0 * sum(server_chunks) / NULLIF(sum(total_chunks), 0), 2) AS server_share_pct,
       round(100.0 * sum(p2p_chunks) / NULLIF(sum(total_chunks), 0), 2) AS p2p_offload_pct,
       round(100.0 * sum(local_cached_chunks) / NULLIF(sum(total_chunks), 0), 2) AS cache_share_pct,
       round(100.0 * (sum(total_chunks) - sum(server_chunks)) / NULLIF(sum(total_chunks), 0), 2)
         AS egress_saving_pct,
       round((sum(total_chunks) * :chunk_kib * 1024.0 / 1e9)::numeric, 4) AS total_gb,
       round((sum(server_chunks) * :chunk_kib * 1024.0 / 1e9)::numeric, 4) AS server_egress_gb,
       round(((sum(total_chunks) - sum(server_chunks)) * :chunk_kib * 1024.0 / 1e9)::numeric, 4)
         AS saved_gb,
       round((((sum(total_chunks) - sum(server_chunks)) * :chunk_kib * 1024.0 / 1e9) * :price)::numeric, 4)
         AS projected_saving_usd
FROM   _eval_final_rows;

DROP TABLE IF EXISTS _eval_final_rows;
