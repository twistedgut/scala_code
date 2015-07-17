function api__payment__refund_history__make_call( type, context, for_reset_psp ) {

    var wait_dialog = new xui_wait_dialog();
    wait_dialog.setDialogMessage( 'Loading the refund history ...' );
    wait_dialog.open();

    $.ajax({
        type        : "GET",
        url         : "/api/payment/" + type + "/" + context.attr("payment_id") + "/refund_history",
        cache       : false,
        dataType    : "json",
        contentType : "application/json",
        complete    : function( data, text_status ) { api__payment__refund_history__complete( text_status, wait_dialog ) },
        error       : function( data, text_status ) { api__payment__refund_history__error( context, for_reset_psp ) },
        timeout     : 10000, // (10 seconds)
        statusCode  : {
            200 : function( data, text_status ) { api__payment__refund_history__status__success( data, context, for_reset_psp ) },
            404 : api__payment__refund_history__status__not_found,
            500 : api__payment__refund_history__status__internal_server_error,
            401 : api__payment__refund_history__status__unauthorized
        }
    });

}

function api__payment__refund_history__complete( text_status, wait_dialog ) {

    wait_dialog.close();

    if ( text_status == "timeout" ) {
        api__payment__refund_history__general_error_alert( "timeout" );
    }

}

function api__payment__refund_history__status__success( data, context, for_reset_psp ) {

    var buttons;
    var title;

    if ( for_reset_psp ) {

        title   = "Do you want to 'Reset PSP' for this item?";
        buttons = [
            { text: "No", click: function() { context.prop( "checked", false ); popup.close(); } },
            { text: "Yes", click: function() { context.prop( "checked", true ); popup.close(); } }
        ];

    } else {

        title   = "Refund History for Order";
        buttons = [
            { text: "OK", click: function() { popup.close(); } },
        ];

    }

    var head = $("#api__payment__refund_history__popup table thead tr").html("");
    var body = $("#api__payment__refund_history__popup table tbody").html("");

    $.each( [ "Date Refunded", "Amount Refunded", "Reason", "Success" ], function( i, item ) {
        $("<td>").html( item ).appendTo( head );
    });

    $.each( data, function( i, item ) {
        var tr = $("<tr>");
        $.each( [ "dateRefunded", "amountRefunded", "reason", "success" ], function( i, key ) {
            $("<td>").html( item[key] ).appendTo( tr );
        } );
        body.append( tr );
    });

    popup = new xui_dialog("#api__payment__refund_history__popup", {
        title           : title,
        height          : 300,
        width           : 500,
        resizable       : true,
        autoOpen        : false,
        closeOnEscape   : false,
        modal           : true,
        buttons         : buttons,
        dialogClass     : 'api__payment__refund_history__popup__no_close'
    });

    popup.open();

}

function api__payment__refund_history__error( context, for_reset_psp ) {
    if ( for_reset_psp ) {
        context.prop( "checked", false );
    }
}

function api__payment__refund_history__status__not_found( data, text_status ) {
    alert( "There is currently no history available for this refund." );
}

function api__payment__refund_history__status__internal_server_error( data, text_status ) {
    api__payment__refund_history__general_error_alert( "server error" );
}

function api__payment__refund_history__status__unauthorized( data, text_status ) {
    console.log( data );
    alert( "You are either not logged in, or do not have permission to view refund history (you need permission for the Active Invoices page), please check and try again." );
}

function api__payment__refund_history__general_error_alert( details ) {
    alert( "There was a problem getting the history for this refund (" + details + "), please try again." );
}

