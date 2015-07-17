-- DCA-2944: Shipment items that were ever cancelled shouldn't be new

begin;

update shipment_item set shipment_item_status_id = 10 -- cancelled
where id in (
    select si.id from shipment_item si
        join cancelled_item ci on ci.shipment_item_id=si.id
        join shipment s on si.shipment_id=s.id
    where s.shipment_status_id in (2,3) -- processing, hold
    and si.shipment_item_status_id=1 --new
);

commit;
