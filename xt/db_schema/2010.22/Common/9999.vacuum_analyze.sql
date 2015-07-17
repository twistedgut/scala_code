-- This is the tail end of http://jira.nap/browse/TP-706 and friends
--
-- A number of the queries showed improvement after a VAC-AN after the
-- addition of the extra indexes


-- We won't do this because it takes *** AGES *** and we don't want to be this mean
-- VACUUM ANALYZE;

-- We *** WILL *** encourage people to VAC-AN in their own time though

BEGIN;
    \echo '***************************************************'
    \echo '**                                               **'
    \echo '** There are a number of new indexes in 2010.22  **'
    \echo '**                                               **'
    \echo '** Please consider running the following on your **'
    \echo '**    database(s) if you don''t already do this   **'
    \echo '**        automatically (e.g. via cron)          **'
    \echo '**                                               **'
    \echo '**                                               **'
    \echo '** $ psql -U postgres -d xtracker                **'
    \echo '** > VACUUM ANALYZE                              **'
    \echo '**                                               **'
    \echo '**                                               **'
    \echo '** This is not run automatically because it is a **'
    \echo '**  long-running, slow operation that you will   **'
    \echo '**   thank me for not making you sit and watch   **'
    \echo '**                                               **'
    \echo '***************************************************'
COMMIT;
