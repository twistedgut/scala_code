var _xui_popup_order_view_fraud_rules_dialog = {
    autoOpen  : false,
    height    : 600,
    width     : 800,
    modal     : true,
    resizable : false,
    draggable : true
};

var _xt_popup_specifications = {
    order_view_fraud_rules_outcome : {
        function : 'xui_popup',
        tag_id : 'fraudrules__test_popup',
        loading_message : "Please wait while the system loads the Fraud Rules Outcome information.",
        xui_dialog_args : _xui_popup_order_view_fraud_rules_dialog
    },
    order_view_fraud_rules_live : {
        function : 'xui_popup',
        tag_id : 'fraudrules__test_popup',
        loading_message : "Please wait while the system runs the Live Fraud Rules against this order.",
        xui_dialog_args : _xui_popup_order_view_fraud_rules_dialog
    },
    order_view_fraud_rules_staging : {
        function : 'xui_popup',
        tag_id : 'fraudrules__test_popup',
        loading_message : "Please wait while the system runs the Staging Fraud Rules against this order.",
        xui_dialog_args : _xui_popup_order_view_fraud_rules_dialog
    },
    order_view_access_log : {
        function : 'window_open',
        window_name : 'NotesPop',
        options  : 'location=0,status=0,toolbar=0,resizable=1,width=750,height=600,scrollbars=1'
    },
    order_view_contact_history : {
        function : 'window_open'
    },
    key_to_finance_icons : {
        function : 'window_open',
        window_name : 'NotesPop',
        options  : 'location=0,status=0,toolbar=0,resizable=1,width=400,height=400,scrollbars=1'
    }
};

var xt_popup_functions = {
    xui_popup : function( url, args ) {
        var id = '#' + args.tag_id;
        $(id).empty();

        var xui_popup = new xui_dialog( id, args.xui_dialog_args );

        $(document).ready( function() {
            $("#xui_close_button").click( function(e) {
                xui_popup.close();
            } );

            if ( args.loading_message ) {
                $(id).append('<h3>'+args.loading_message+'</h3>');
            }
        } );

        xui_popup.open();

        $(id).load(url, function() {
            $("#xui_close_button").click( function(e) {
                xui_popup.close();
            } );
        } );
    },
    window_open : function( url, args ) {
        var params = new Array();

        // Assign the parts that are defined for opening the window
        if ( url )              params.push( url );
        if ( args.window_name ) params.push( args.window_name );
        if ( args.options )     params.push( args.options );

        switch ( params.length ) {
            case 1:
                window.open( params[0] );
                break;
            case 2:
                window.open( params[0], params[1] );
                break;
            case 3:
                window.open( params[0], params[1], params[2] );
                break;
        }
    }
};

$(document).ready( function() {
    $('a[class*="_xt_popup_"]').click( function() {
        var class_re = /\b_xt_popup_(.*)\b/;
        var match    = class_re.exec( $(this).attr('class') );
        var class_name = match[1];

        var popup_args = _xt_popup_specifications[class_name];
        xt_popup_functions[ popup_args.function ](
            $(this).attr('href'),
            popup_args
        );

        return false;
    } );
} );
