
BEGIN;

-- Container.place shouldn't never have been set to 'Invetory Desk'

update
    public.container
set
    place = null
where
    place != 'Commissioner';

COMMIT;

