$(document).ready(function() {
    $('#refundForm').submit( function() {
        var valid_form  = true;

        var reason_select = $('#refundForm select[name="invoice_reason"]');
        if ( reason_select.attr('name') ) {
            // field exists on the form
            var value = reason_select.val();
            if ( !value ) {
                valid_form = false;
                alert( "Please specify a Reason for the Invoice" );
            }
        }

        return valid_form;
    } );

    // if 'misc_refund' has been set in 'validation_obj' then set-up
    // the validation rules that apply to the 'misc_refund' field
    if ( validation_obj.misc_refund ) {
        var renum_type_fld  = $("#refundForm [name='type_id']");
        var misc_refund_fld = $("#refundForm [name='misc_refund']");

        // set-up what will get passed in 'event.data' to the onChange Event Handler
        var eventData = {
            'renum_type_fld' : renum_type_fld,
            'misc_refund_fld': misc_refund_fld,
            'validation'     : validation_obj.misc_refund
        };

        renum_type_fld.change( eventData, function ( event ) {
            _validate_misc_refund( event.data );
        } );

        // call this now to set-up the page from the start
        _validate_misc_refund( eventData );
    }
});


/*
    this will make sure that the 'misc_refund' field can't be used
    and an appropriate error message is shown on the page when
    'Card Refund' has been selected and the Order's Payment Method
    doesn't allow pure Goodwill Refunds.
*/
function _validate_misc_refund ( data ) {
    var misc_refund_fld = data.misc_refund_fld;
    var renum_type_fld  = data.renum_type_fld;

    // Renumeration Type Id '2' = 'Card Refund'
    if ( renum_type_fld.val() == 2 ) {
        $('#misc_refund_err').text( data.validation.error_message ).addClass('standout');
        $('#misc_refund_short_err').html("<br/>* can't use this field").addClass('standout');
        misc_refund_fld.val('0.00').attr( 'disabled', 'disabled' );
    }
    else {
        $('#misc_refund_err').text('').removeClass('standout');
        $('#misc_refund_short_err').text('').removeClass('standout');
        misc_refund_fld.removeAttr('disabled');
    }
}

