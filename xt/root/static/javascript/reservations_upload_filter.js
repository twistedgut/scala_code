$(document).ready(function() {
    $('.toggle_show_hide_element').click( function() {
                var id_of_toggle    = '#' + this.id;
                var toggle_obj      = $(id_of_toggle);

                var id_to_toggle    = id_of_toggle;
                id_to_toggle        = id_to_toggle.replace(/_toggle$/,'');

                // Switch the On/Off Images used for the Toggle
                var curr_state  = $(id_to_toggle).css('display');
                if ( curr_state == 'none' )
                    toggle_obj.attr('src','/images/icons/zoom_out.png');
                else
                    toggle_obj.attr('src','/images/icons/zoom_in.png');

                // Show/Hide the Element
                $(id_to_toggle).toggle();
        } );

    var number_of_designer_checkboxes   = $('input.designer_list_checkbox').length;
    $('.designer_list_checkbox').change( function() {
                var number_checked  = $('input.designer_list_checkbox:checked').length;
                var number_unchecked= ( number_of_designer_checkboxes - number_checked );
                var msg_bit         = ( number_unchecked == 1 ? ' Designer has ' : ' Designers have ' );
                $('#designer_list_progress').html( '<strong>' + number_unchecked + '</strong>' + msg_bit + 'been Excluded' );
        } );

    $('#exclude_pids').change( function() {
                var msg = "";
                if ( this.value && this.value != '' )
                    msg = "<strong>Product IDs</strong>";
                else
                    msg = "<strong>NO</strong>";
                $('#product_id_entry_progress').html( msg + ' have been entered to be Excluded' );
        } );

    $('.designer_list_checkbox').trigger('change');
    $('#exclude_pids').trigger('change');

    $('#upload_filter_options').submit(function() {
        if ( confirm('Are you sure?') ) {
            return true;
        } else {
            return false;
        }
    });
});
