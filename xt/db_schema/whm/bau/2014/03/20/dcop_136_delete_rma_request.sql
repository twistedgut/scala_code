begin;

delete from rma_request_detail where rma_request_id=1017;
delete from rma_request_note where rma_request_id=1017;
delete from rma_request_status_log where rma_request_id=1017;
delete from rma_request where id=1017;

commit;
