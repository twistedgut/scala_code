/* Pre-Order On Hold Page */

$(document).ready(function() {

    api_queue({
        description         : 'Pre-Orders',
        button_text         : 'Release Pre-Orders',
        progress_bar_id     : '#order_update_progress_bar',
        attribute_name      : 'order_id',
        cancel_id           : '#order_update__cancel',
        start_id            : '#order_update__start',
        url                 : '/API/StockControl/Reservation/PreOrder/PreOrderOnhold/UpdateOrderStatus',
        select_all_id       : '#select_all_orders',
        confirm_id          : '#dialog-confirm',
        payload_callback    : function( checkbox ) { return { order_id: checkbox.attr('order_id') } }
    });

});
