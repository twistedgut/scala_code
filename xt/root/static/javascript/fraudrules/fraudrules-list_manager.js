function list_type_show_selected() {

    // Hide all the DIVs.
    $('.list_type_select').each( function() {
        $(this).hide();
    });
    $('label#list_type_select_label').hide();

    // Show only the selected one.
    var id = $('#list_type_id').val();

    if ( id != 'Please select a List Type' ) {
        $('label#list_type_select_label').show();
        $( '#list_type_select_' + id ).show();
    }

}

$(document).ready(function() {
    list_type_show_selected();

    $('span#fraudrule_list_manager__submit_button input[name="submit"]').click( function(e) {
        if ( $('#list_type_id').val() == 'Please select a List Type' ) {
            alert('You must select a list type and the list values before you can submit the list');
            if ( e.preventDefault) {
                e.preventDefault();
            }
            else {
                e.returnValue = false;
            }
            return 0;
        }
    } );
});

