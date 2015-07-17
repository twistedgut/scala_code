/* Bulk Reassign Page */

$(document).ready(function() {

    api_queue({
        description         : 'Reservations',
        button_text         : 'Reassign Reservations',
        progress_bar_id     : '#reservation_update_progress_bar',
        attribute_name      : 'reservation_id',
        cancel_id           : '#update__cancel',
        start_id            : '#update__start',
        url                 : '/API/StockControl/Reservation/Reassign',
        select_all_id       : '#select_all_reservations',
        confirm_id          : '#dialog-confirm',
        payload_callback    : function( checkbox ) {
            return {
                reservation_id:     checkbox.attr('reservation_id'),
                new_operator_id:    $('#new_operator').val()
            }
        },
        start_callback      : function() {
            if ( $('#new_operator').val() == "" ) {
                alert("Please select an operator to reassign the selected reservation(s) to.");
                return false;
            } else {
                return true;
            }
        }
    });

});
