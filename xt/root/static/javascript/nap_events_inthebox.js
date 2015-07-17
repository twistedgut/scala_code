// Add a new option to a SELECT list.
function dropdown_append( id, display, value ) {
    var new_option = $('<option>');
    if ( value ) {
        new_option.val( value );
    }
    if ( display ) {
        new_option.html( display );
    }
    $(id).append( new_option );
}

// Clear the SELECT list, disable it and add just one item to let
// the user know what is going on.
function dropdown_mesage( id, message ) {
    $(id).empty();
    $(id).attr('disabled', 'disabled');
    dropdown_append( id, message );
}

$(document).ready(function() {

    // Store promotion types to clone from in weighted promotions.
    var existing_promotion_types = {};

    // Update the promotion type list when this value changes.
    $('#channel_id').change( function() {

        dropdown_mesage( '#weighted_existing', 'please wait ...' );

        if ( $('#channel_id').val() ) {
        // If a channel has been selected from the list.

            // Send an AJAX request.
            $.ajax({
                type     : 'GET',
                async    : true,
                url      : '/AJAX/GetPromotionTypes',
                cache    : false,
                dataType : 'json',
                data     : {
                    channel_id: $('#channel_id').val()
                },
                error    : function(jqXHR, textStatus, errorThrown) {
                    dropdown_mesage( '#weighted_existing', 'Error refreshing list, try again.' );
                },
                success  : function(data, textStatus, jqXHR) {

                    if ( data.result == 'OK' ) {
                        // Populate and enable the list if we got some data.

                        // Clear the list and add an empty value.
                        $('#weighted_existing').empty();
                        existing_promotion_types = {};
                        dropdown_append( '#weighted_existing', '-----------------', 0 );

                        // Populate with data.
                        $.each(data.data, function( index, element ) {
                            existing_promotion_types[element.id] = element;
                            dropdown_append( '#weighted_existing', element.name, element.id );
                        });

                        // Enable the list.
                        $('#weighted_existing').removeAttr( 'disabled' );

                    } else if ( data.result == 'NO_RESULTS' ) {

                        dropdown_mesage( '#weighted_existing', 'nothing to clone from' );

                    } else {

                        dropdown_mesage( '#weighted_existing', 'Error refreshing list, try again.' );

                    }

                }
            })

        } else {

            dropdown_mesage( '#weighted_existing', '-- please select a channel first --' );

        }

    } );

    // Populate the weighted fields when the user chooses to clone.
    $('#weighted_existing').change( function() {

        var id = $(this).val();

        if ( id > 0 ) {
            $('#weighted_invoice').val( existing_promotion_types[id].product_type );
            $('#weighted_weight').val( existing_promotion_types[id].weight );
            $('#weighted_fabric').val( existing_promotion_types[id].fabric );
            $('#weighted_country').val( existing_promotion_types[id].origin );
            $('#weighted_hscode').val( existing_promotion_types[id].hs_code );
        }

    } );

    // Show/Hide the weighted fields when the dropdown changes.
    $('#is_weighted').change(function () {

        if ( $(this).val() == 1 ) {

            $('#weighted').fadeIn( 500, function() {
                $('#weighted_table').animate( { backgroundColor: '#ff6' }, 1000, function() {
                    $('#weighted_table').animate( { backgroundColor: '#fff' }, 3000 );
                } );
            } );

        } else {

            $('#weighted').fadeOut( 500 );

        }

    } );

    /* In the Box Prmotion - Validation on submit */
    $('#inthebox_promotion_submit_button').click(function() {

        var startDate = _get_date( $('#promotion_start').val() );
        var endDate   = _get_date( $('#promotion_end').val() );

        /* channel not null */
        if($('#channel_id').val() == 0){
            alert('No channel selected');
            return false;
        }

        /* promotion title */
        if($('#promotion_title').val() == '') {
            alert( 'Please enter promotion title' );
            return false;
        }

        /* promotion start date & end date validation */
        if( ($('#promotion_start').val() == '') || ($('#promotion_end').val() == '')) {
            alert( "Please enter both Promotion start date and end date");
            return false;
        }

        if(isNaN(startDate)) {
            alert(' Please enter Valid Start Date' );
            return false;
        }


        if( isNaN(endDate)) {
            alert(' Please enter Valid End Date' );
            return false;
        }

        var date_result = compare_date( startDate,endDate );
        if (date_result < 0) {
            alert( 'Promotion End Date should NOT be less than Promotion Start Date' );
            return false;
        }

        /* packers note message */
        if($('#packers_message').val() == '') {
            alert('Please enter Message for Packers');
            return false;
        }


        if ( $('#is_weighted').val() == 1  ) {

            // weighted_invoice
            // weighted_weight
            // weighted_fabric

            if ( $('#weighted_invoice').val() == '' ) {

                alert( 'Please enter something to display on the invoice' );
                return false;

            }

            if ( $('#weighted_weight').val() == '' ) {

                alert( 'Please enter a weight' );
                return false;

            } else {

                if ( isNaN( $('#weighted_weight').val() ) ) {

                    alert( 'Weight must be a number' );
                    return false;

                }

            }

            if ( $('#weighted_fabric').val() == '' ) {

                alert( 'Please enter a type of fabric' );
                return false;

            }

            if ( $('#weighted_country').val() == 0 ) {

                alert( 'Please select a Country of Origin' );
                return false;

            }

            if ( $('#weighted_hscode').val() == 0 ) {

                alert( 'Please select an HS Code' );
                return false;

            }

        }

    });

    $('.toggle_show_hide_element').click( function() {
        var id_of_toggle    = '#' + this.id;
        var toggle_obj      = $(id_of_toggle);

        var id_to_toggle    = id_of_toggle;
        id_to_toggle        = id_to_toggle.replace(/_toggle$/,'');

        // Switch the On/Off Images used for the Toggle
        if ( $(id_to_toggle).css('display') == 'none' ) {
            toggle_obj.attr('src','/images/icons/zoom_out.png');
        }
        else {
            toggle_obj.attr('src','/images/icons/zoom_in.png');
        }

        // Show/Hide the Element
        $(id_to_toggle).toggle();
    } );

    if (typeof in_edit_mode == 'undefined') {
        in_edit_mode = false;
    }

    if (in_edit_mode) {
        $('.option_channel_'+$('#channel_id').val()).show();        // show all the Options for the Promotion's Channel
    }
    else {
        $('#channel_id').change( function() {
            // for all Channelised Options
            $('.option_channel_list').remove();                                 // remove the hidden field containing any selected Ids
            $('.inthebox_list_channels').hide();                                // hide list for all Channels
            $('.inthebox_option_picked_channel').html('');                      // clear Picked right hand side box
            $('.option_channel_'+$(this).val()).show();                         // now show the list for the selected Channel
            $('.inthebox_list_channels').find('input').prop('checked', false);  // make sure all checkboxes are Unticked for every Channel
        } );
    }

    $('#show_all_designers').click( function() {
       if ($('#'+this.id).prop('checked')) {
           $('.invisible_designer_for_channel_'+$('#channel_id').val()).show();
       }
       else {
           $('.invisible_designer_for_channel_'+$('#channel_id').val()).hide();
       }
    });

    /* Customer Segment */
    $('#customer_segment_submit_button').click(function(){
        /* channel not null */
        if($('#segment_channel_id').val() == 0){
            alert('No channel selected');
            return false;
        }

        /* customer segment name */
        if($('#customer_segment_name').val() == '') {
            alert( 'Please enter Customer Segment Name' );
            return false;
        }

    });

    $('#customer_segment_add_button').click(function(){
        if($('#select_customer_list_textarea').val() == 0){
            alert('Please Enter Customer Numbers to Add');
            return false
        }
        if (confirm('Are you sure you want to Add Customers to segment?')) {
            $('#customer_segment_form').submit();
        }
        return false;
    });

    $('#reset_customer_list_button').click(function(){
        if (confirm('Are you sure you want to Clear all Customers from segment?')) {
            $('#hidden_edit_action').val('clear_all');
            $('#customer_segment_form').submit();
        }
        return false;
    });

    $('#delete_customer_list_button').click(function(){
        if($('#select_customer_list_textarea').val() == 0){
            alert('Please Enter Customer Numbers to Delete');
            return false
        }
        if (confirm('Are you sure you want to Delete Customers Attached to this segment?')) {
            $('#hidden_edit_action').val('delete');
            $('#customer_segment_form').submit();
        }
        return false;
    });

    $('.option_item_checkboxes').click(function() {
        var checkbox    = $('#'+this.id);
        var option      = checkbox.parent()

        if (checkbox.prop('checked')) {
            add_option_to_picked_list(option)
        }
        else {
            $('#clone_'+option.attr('id')).remove();
            $('#list_'+option.attr('id')).remove();
        }
    });
});

function add_option_to_picked_list(option) {

    var option_id    = option.attr('id').replace(/^\w+_id_/, '');
    var option_label = option.attr('id').replace(/_id_\d+$/, '');
    var channel_class= '';
    // get rid of a Channel Id prefix should it be there
    if ( option_label.match( /^\d+_/ ) ) {
        option_label = option_label.replace(/^\d+_/, '');
        channel_class= ' option_channel_list';
    }

    //~ Clone the option box
    var cloned_option = option.clone();
    cloned_option.prop('id', 'clone_'+option.attr('id'));
    cloned_option.appendTo('#inthebox_'+option_label+'_picked');
    cloned_option.prop('class',"formrow dividebelow");

    cloned_option.find('input').click(function() {
        cloned_option.remove();
        option.find('input').prop('checked', false);
        $('#list_'+option.attr('id')).remove();

    });

    //~ Add the hiden value to the form
    $('<input type="hidden" class="'+option_label+'_list'+channel_class+'"/>').attr( {
        name : option_label + '_list',
        id   : 'list_'+option.attr('id'),
        value: option_id
    }).appendTo('#inthebox_promotion_form');
}

/* check if two dates objects have equal dates, disregarding times */

function compare_date(date1, date2) {
    var d1 = new Date(date1.getTime()).clearTime();
    var d2 = new Date(date2.getTime()).clearTime();

    if(d1.getTime() >d2.getTime() ) {
        return -1;
    } else if ( d1.getTime() < d2.getTime() ) {
        return 1;
    } else {
        return 0;
    }
}

function _get_date (datestr) {
    var date_parts  = datestr.split('-');
    return new Date( date_parts[0], date_parts[1], date_parts[2] );
}
