$(document).ready(function() {
    if (edit_table_mode) {
        // Buttons on the log message popup.

        $("#fraudscreen__cancel_save_changes").click(function() {
            change_log_popup.close();
        });

        $("#fraudscreen__confirm_save_changes").click(function() {
            var change_log_msg = $("#fraudscreen__log_message").val();

            if ( change_log_msg ) {
                change_log_popup.close();
                pushToLiveAction( change_log_msg );
            }
            else {
                alert("Please provide a change log message");
            }
        });

        // Log message popup.

        $('#fraudscreen__push_staging_to_live_button').click(function() {

            // Clear the log message.
            $("#fraudscreen__log_message").val( '' );

            change_log_popup = new xui_dialog("#fraudscreen__change_log_message", {
                height: 200,
                width: 650,
                resizable: true,
                autoOpen: false
            });

            change_log_popup.open();
        });
    }
})
