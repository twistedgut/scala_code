/**
 * Select Products Page
 **/
$(document).ready(function() {

    $('#select_products__reset_variants_button').click(function() {
        $('.select_products__variants_checkbox').removeAttr('checked');
        $('#select_products__reservation_source_dropdown').val(0);
    });

    $('#select_products__submit_variants_button').click(function() {
        var show_none_selected_dialog    = true;
        var show_not_all_selected_dialog = false;

        var flag = 0;
        var errMessage ='' ;
        if ($('#select_products__reservation_source_dropdown').val() == 0) {
            flag = 1;
            errMessage = "* Please Select Reservation source.\n";
        }
        if ($('#select_products__reservation_type_dropdown').val() == 0) {
            flag = 1;
            errMessage += "* Please Select Reservation Type.\n";
        }

        if (flag == 1 ) {
            alert( errMessage );
            /* reset variables */
            flag = 0;
            errMessage = '';
            return false;
        }
        $('.select_products__product_variants_table').each(
            function(index, element) {
                if ($('#'+this.id+' input:checked').length > 0) {
                    show_none_selected_dialog    = false;
                }
                else {
                    show_not_all_selected_dialog = true;
                }
            }
        );

        if (show_none_selected_dialog) {
            alert('No products selected');
        }
        else if (show_not_all_selected_dialog) {
            if (confirm('Not all the products were selected. Do you wish to continue?')) {
                $('#select_products__variants_form').submit();
            }
        }
        else {
            $('#select_products__variants_form').submit();
        }
    });
});
