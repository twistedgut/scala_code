
-- DCA-3482: GOH: add allocation_status ready_to_deliver

BEGIN TRANSACTION;

INSERT INTO ALLOCATION_STATUS (status, description)
    VALUES (
        'ready_to_deliver',
        'If the PRL supports delivery, after "picking" it goes to "ready_to_deliver", perhaps to allocate pack space, before "preparing"'
    );

COMMIT;
