/*
    Used with the Choose Address page which is part of the Edit Shipping/Billing
    Address functionality.

    It will get a list of the Customer's Addresses by using the 'customerAddresses'
    JavaScript Class to make an API call and display them in the 'customer_addresses'
    <div>.
*/

$(document).ready( function() {
    var wrapper_div      = $('#customer_addresses');
    var customer_id      = $('#use_address :input[name="customer_id"]').val();
    var current_addr_key = $('#base_address :input[name="current_address_addr_key"]').val();

    // this function will be called if Addresses are found and
    // will draw the buttons beneath them so that they can be used
    var add_edit_or_use_buttons = function () {
        var raquo = String.fromCharCode(187);
        var edit_btn = $('<input>').addClass('button')
                                   .attr( 'type', 'submit' )
                                   .attr( 'name', 'submit_edit' )
                                   .val( 'Edit and Use Address ' + raquo );

        var use_btn  = $('<input>').addClass('button')
                                   .attr( 'type', 'submit' )
                                   .attr( 'name', 'submit_use' )
                                   .val( 'Use Address' );

        var or_text  = $('<strong>').html('&nbsp;&nbsp;Or&nbsp;&nbsp;');

        var div = $('<div>').css( 'text-align', 'right' )
                            .css( 'clear', 'both' )
                            .append( edit_btn, or_text, use_btn );
        wrapper_div.append( div );

        return;
    };

    // get the Customer's Addresses and display them
    var custAddrs = new customerAddresses( {
        wrapper_div     : wrapper_div,
        customer_id     : customer_id,
        failure_message : 'No addresses found',
        exclude_addr_key: current_addr_key,
        run_once_done   : add_edit_or_use_buttons
    } );
    custAddrs.getAddresses();
} );

