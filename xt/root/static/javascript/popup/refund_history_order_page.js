$(document).ready( function() {

    $("#order_tracker__shared__payment_details__refund_history").click( function() {
        api__payment__refund_history__make_call( "order", $(this), false );
    });

});
