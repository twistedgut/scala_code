
BEGIN WORK;

-- FLEX-206 -- The Nominated Day tests uses channel.timezone, which
-- are erroneously America/Chicago. This patch fixes that.

-- All channels in XTDC2 is for DC2 which is in NJ.
UPDATE channel set timezone = 'America/New_York';

COMMIT WORK;
