BEGIN;

	alter table public.channel add colour_detail_override boolean default false not null;
	update public.channel set colour_detail_override = true where name = 'theOutnet.com';

COMMIT;
