$(document).ready( function() {

    // assign a click event to all the checkboxes for 'Enable All Packs'
    $('[class^=conf_group_]').click( function() {
        toggle_radio_buttons_display( this );
    } );

    // set the page up accordingly based on the state of the checkboxes
    $('[class^=conf_group_]').each( function() {
        toggle_radio_buttons_display( this );
    } );

    // Toggle Show/Hide Change Logs
    $('[class^=log_toggle_]').click( function() {
        var id = this.id;
        $('#welcome_pack_change_log').toggle();
        $('[class^=log_toggle_]').toggle();
    } );

} );


function toggle_radio_buttons_display ( xthis ) {
    var class_name = $(xthis).attr('class');

    if ( xthis.checked ) {
        $( '.notallow_' + class_name ).hide();
        $( '.allow_'    + class_name ).show();
    }
    else {
        $( '.allow_'    + class_name ).hide();
        $( '.notallow_' + class_name ).show();
    }

    return;
}
