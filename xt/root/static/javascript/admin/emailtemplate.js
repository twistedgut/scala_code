
$(document).ready(function() {


    $('[class^=log_toggle_]').click( function() {
        var id = this.id;
        $('#template_log').toggle();
        $('[class^=log_toggle_]').toggle();
    } );


});
