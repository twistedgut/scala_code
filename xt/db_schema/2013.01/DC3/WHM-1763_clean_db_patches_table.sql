BEGIN;

-- first one in there shou be
--  Common/01_CANDO-711_performance.sql                                          | 2012-06-13 15:48:57.688011+01

delete from dbadmin.applied_patch where created < '2012-06-10 00:00:00';

COMMIT;
