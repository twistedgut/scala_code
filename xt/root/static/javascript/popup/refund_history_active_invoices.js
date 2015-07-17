$(document).ready( function() {

    $(".reset_sent_to_psp_standard").change( function() {
        if ( $(this).prop("checked") && $(this).attr("payment_id") ) {
            api__payment__refund_history__make_call( "order", $(this), true );
        }
    });

    $(".reset_sent_to_psp_preorder").change( function() {
        if ( $(this).prop("checked") && $(this).attr("payment_id") ) {
            api__payment__refund_history__make_call( "preorder", $(this), true );
        }
    });

});
