$(document).ready(function() {

    // Hover over the Key to the Switch Options
    $('IMG.key_icon').hover(
        function () {
            var id = this.id + '_div';
            $( '#' + id ).show();
        },
        function () {
            var id = this.id + '_div';
            $( '#' + id ).hide();
        }
    );

    // Toggle Show/Hide Switch Logs
    $('[class^=log_toggle_]').click( function() {
        var id = this.id;
        $('#fraud_rules_switch_log').toggle();
        $('[class^=log_toggle_]').toggle();
    } );

} );
