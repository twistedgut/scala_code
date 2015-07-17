// Name:        feedback.js
// Author:      Andrew Benson
// Description: Adds feedback to an XT page, the same way as xt_warn/feedback_warn do in perl.

function feedback_message( type, message ) {
    $('#contentRight').prepend('<p class="' + type + '">' + message + '</p>');
}

function feedback_error( message ) {
    feedback_message( 'error_msg', message );
}

function feedback_success( message ) {
    feedback_message( 'display_msg', message );
}

function feedback_info( message ) {
    feedback_message( 'info', message );
}

function feedback_clear() {
    $('#contentRight > p.error_msg,p.display_msg,p.info').remove();
}
