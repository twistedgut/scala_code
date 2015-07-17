function api_queue( parameters ) {

    var description         = parameters[ 'description' ];
    var button_text         = parameters[ 'button_text' ];
    var progress_bar_id     = parameters[ 'progress_bar_id' ];
    var attribute_name      = parameters[ 'attribute_name' ];
    var cancel_id           = parameters[ 'cancel_id' ];
    var start_id            = parameters[ 'start_id' ];
    var url                 = parameters[ 'url' ];
    var select_all_id       = parameters[ 'select_all_id' ];
    var confirm_id          = parameters[ 'confirm_id' ];
    var payload_callback    = parameters[ 'payload_callback' ];
    var start_callback      = parameters[ 'start_callback' ];

    var preloaded_image_processing  = $( '<img>', { src: '/images/action/ajax-loader_5.gif' } );
    var preloaded_image_done        = $( '<img>', { src: '/images/icons/accept.png' } );
    var preloaded_image_error       = $( '<img>', { src: '/images/icons/bullet_error.png' } );
    var progress_bar                = $( progress_bar_id );
    var checkboxes                  = 'input[' + attribute_name + '][type="checkbox"]:enabled'
    var selected_checkboxes         = 'input[' + attribute_name + '][type="checkbox"]:checked:enabled';
    var error_count                 = 0;
    var success_count               = 0;

    // Functions

    var set_cancel_button_enabled = function( visible ) {
        if ( visible ) {
            $(cancel_id).prop( 'disabled', false );
            $(cancel_id).fadeIn( 300 );
        } else {
            $(cancel_id).prop( 'disabled', true );
            $(cancel_id).fadeOut( 300 );
        }
    };

    var set_start_button_enabled = function( visible ) {
        if ( visible ) {
            $(start_id).prop( 'disabled', false );
            $(start_id).fadeTo( 300, 1 );
        } else {
            $(start_id).prop( 'disabled', true );
            $(start_id).fadeTo( 300, 0.5 );
        }
    };

    var update_start_button = function() {
        if ( $(selected_checkboxes).length > 0 ) {
            set_start_button_enabled( true );
        } else {
            set_start_button_enabled( false );
        }
    };

    var update_select_all = function() {
        var checkbox_count      = $(checkboxes).length;
        var selected_count      = $(selected_checkboxes).length;
        var select_all   = $(select_all_id);
        if ( checkbox_count > 0 ) {
            select_all.prop( 'disabled', false );
            if ( selected_count == checkbox_count ) {
                select_all.prop( 'checked', true );
            } else {
                select_all.prop( 'checked', false );
            }
        } else {
            select_all.prop( 'disabled', true );
        }
    };

    var display_feedback = function() {
        if ( error_count == 0 && success_count > 0 ) {
            feedback_success('All of the selected ' + description + ' have been updated sucessfully.')
        } else if ( error_count > 0 && success_count == 0 ) {
            feedback_error('There was a problem updating all of the selected ' + description + '.');
        } else if ( error_count > 0 && success_count > 0 ) {
            feedback_error('There was a problem updating some of the selected ' + description + ' (see individual status for details).');
            feedback_success('Some of the selected ' + description + ' have been updated sucessfully (see individual status for details).')
        }
    };

    var start_update = function() {

        feedback_clear();
        error_count = 0;
        success_count = 0;

        set_cancel_button_enabled( true );
        set_start_button_enabled( false );

        progress_bar.progressbar({
            max:    $(selected_checkboxes).length,
            value:  0
        });

        $(selected_checkboxes).each(function() {

            var image_processing    = preloaded_image_processing.clone();
            var checkbox            = $(this);
            var payload             = payload_callback( checkbox )
            var status_element      = checkbox.parent().next();
            var report_error        = function( message ) {
                var image_error = preloaded_image_error.clone();
                image_error.prop( 'title', message + ', please try again.' );
                status_element.append( image_error );
                checkbox.prop( 'disabled', false );
            };

            queue.Queue({
                data: JSON.stringify( payload ),
                beforeSend: function() {
                    checkbox.prop( 'disabled', true );
                    status_element.children().remove();
                    status_element.append( image_processing );
                },
                complete: function() {
                    image_processing.remove();
                    progress_bar.progressbar( 'value', progress_bar.progressbar('value') + 1 );
                },
                success: function( data ) {
                    success_count = success_count + 1;
                    if ( data.status === 'SUCCESS' ) {
                        var image_done = preloaded_image_done.clone();
                        image_done.prop( 'title', 'Item processed succesfully.' );
                        status_element.append( image_done );
                    } else {
                        report_error( 'There was a problem processing the item' );
                    }
                },
                error: function( jqXHR ) {
                    error_count = error_count + 1;
                    try {
                        if ( jqXHR.statusCode().status == 401 ) {
                            report_error( 'You do not have permission to use this feature' );
                        } else {
                            var data = JSON.parse( jqXHR.responseText );
                            report_error( data.error );
                        }
                    } catch( error ) {
                        console.log( error );
                        report_error( 'The response from the server was not understood' );
                    }
                }
            });

        });

    };

    // Queue

    var queue = $.qjax({
        ajaxSettings: {
            url:            url,
            type:           'POST',
            contentType:    'application/json',
            dataType:       'json',
        },
        onQueueChange: function(length) {
            if ( length == 0 ) {
                set_cancel_button_enabled( false );
                update_start_button();
                update_select_all();
                display_feedback();
                setTimeout( function(){ progress_bar.progressbar('destroy') }, 500 );
            }
        }
    });

    // Events

    $(select_all_id).change(function() {
        $('input[' + attribute_name + ',type="checkbox"]:enabled').prop(
            'checked',
            $(this).prop('checked') );
        update_start_button();
    });

    $('input[' + attribute_name + '][type="checkbox"]').change(function() {
        update_start_button();
        update_select_all();
    });

    $(cancel_id).click(function() {
        queue.Clear();
        set_cancel_button_enabled( false );
        update_start_button();
    });

    $(start_id).click(function() {
        // If we've been given a callback and the return value is FALSE, don't
        // continue any further.
        if ( typeof start_callback != "undefined" ) {
            if ( start_callback() == false ) {
                return;
            }
        }
        dialog_confirm.open();
    });

    // Dialogs

    // We have to declare an object first, then add the keys below,
    // because JavaScript cannot handle using variable names in object keys.
    var buttons = {};

    buttons[button_text] = function() {
        $( this ).dialog( "close" );
        start_update();
    };

    buttons['Cancel'] = function() {
        $( this ).dialog( "close" );
    };

    var dialog_confirm = new xui_dialog( confirm_id, {
        height:     200,
        width:      300,
        resizable:  false,
        autoOpen:   false,
        modal:      true,
        buttons:    buttons
    });

    update_start_button();
    update_select_all();

}
