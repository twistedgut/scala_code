BEGIN;

update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 475134);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 475134;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 475134);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 448828);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 448828;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 448828);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 445858);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 445858;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 445858);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 445884);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 445884;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 445884);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 445987);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 445987;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 445987);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 430163);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 430163;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 430163);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 406477);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 406477;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 406477);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 395975);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 395975;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 395975);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 382987);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 382987;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 382987);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 293248);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 293248;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 293248);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 349088);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 349088;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 349088);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 365448);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 365448;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 365448);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 361427);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 361427;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 361427);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 350415);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 350415;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 350415);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 346369);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 346369;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 346369);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 339412);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 339412;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 339412);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 335810);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 335810;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 335810);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 323735);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 323735;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 323735);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 318829);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 318829;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 318829);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 293090);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 293090;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 293090);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 303690);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 303690;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 303690);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 304322);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 304322;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 304322);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 300258);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 300258;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 300258);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 297194);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 297194;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 297194);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 244644);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 244644;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 244644);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 213598);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 213598;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 213598);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 217312);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 217312;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 217312);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 121373);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 121373;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 121373);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 201974);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 201974;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 201974);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 43784);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 43784;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 43784);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 162436);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 162436;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 162436);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 228776);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 228776;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 228776);
	
update inventory set allocated_quantity = allocated_quantity - 1 
where allocated_quantity > 0 and id = (select inventory_id from fulfilment_item where id = 112499);
update fulfilment_item set fulfilment_item_status_id = 8 where id = 112499;
update fulfilment set fulfilment_status_id = 3 where id = (select fulfilment_id from fulfilment_item where id = 112499);
	
-- and some other very old ones that just need clearing from picking admin
update fulfilment set fulfilment_status_id = 3 where allocation_id = '139741';
update fulfilment set fulfilment_status_id = 3 where allocation_id = '163035';
update fulfilment set fulfilment_status_id = 3 where allocation_id = '408297';

COMMIT;
