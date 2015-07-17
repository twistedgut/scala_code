-- DCA-1935: Remove Dematic Pool size parameter from admin screen

BEGIN WORK;

DELETE FROM system_config.parameter WHERE name = 'dematic_pool_size';

COMMIT;
