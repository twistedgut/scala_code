$(document).ready(function() {
    $( "#quick_search_ext_help_content" ).dialog({
        autoOpen: false,
        width: "400",
        draggable: false,
        resizable: false
    });

    $( '#quick_search_ext_help' ).click(function() {
        $( "#quick_search_ext_help_content" ).dialog('open');
        return false;
    });
    $('.ui-dialog').prependTo($('#content'));
    $('.ui-dialog-titlebar').remove();
});
