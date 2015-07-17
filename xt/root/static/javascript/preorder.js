/**
 *
 * !THIS FILE REALLY NEEDS TO BE SPLIT!
 *
 * /

/**
 * Popup window for address selection
  **/

var popup_address__active_dialog;
var popup_address__address_type = '';
var popup_address__pre_order_id;
var popup_address__call_backs;
var popup_address__dialog;

$(document).ready(function() {

    // taken from http://whattheheadsaid.com/2010/10/a-safer-object-keys-compatibility-implementation
    // as a work-around for older browsers not supporting 'Object.keys'
    Object.keys = Object.keys || ( function () {
        var hasOwnProperty = Object.prototype.hasOwnProperty,
            hasDontEnumBug = !{toString:null}.propertyIsEnumerable("toString"),
            DontEnums = [
                'toString',
                'toLocaleString',
                'valueOf',
                'hasOwnProperty',
                'isPrototypeOf',
                'propertyIsEnumerable',
                'constructor'
            ],
            DontEnumsLength = DontEnums.length;

        return function (o) {
            if (typeof o != "object" && typeof o != "function" || o === null)
                throw new TypeError("Object.keys called on a non-object");

            var result = [];
            for (var name in o) {
                if (hasOwnProperty.call(o, name))
                    result.push(name);
            }

            if (hasDontEnumBug) {
                for (var i = 0; i < DontEnumsLength; i++) {
                    if (hasOwnProperty.call(o, DontEnums[i]))
                        result.push(DontEnums[i]);
                }
            }

            return result;
        };
    } )();

    display_either_states_dropdown_or_county_input();

    popup_address__dialog = $('#popup_address__dialog').dialog({
        autoOpen: false,
        height: 620,
        width: 500,
        draggable: false,
        resizable: false,
        modal    : true,
        open     : function() {
        // HACK: IE8 z-index bug and xtracker dont mix
            $('.ui-widget-overlay').prependTo($('#content')).css({
                position: 'fixed',
                top: 0,
                right: 0
            });
        }
    });
    popup_address__dialog.parent().prependTo($('#contentRight'));
    $(".ui-dialog-titlebar").hide();

    // Reset button click event
    $("#address_popup__new_address_reset_button").click( function(){
        $('.new_address__form_input').val('');
        $('#new_address__us_state').val('') ;
        $('#new_address__county_row').show();
        $('#new_address__state_row').hide();
        display_either_states_dropdown_or_county_input();
    });

    // Country dropdown change event
    $('#new_address__country').change(function() {
        display_either_states_dropdown_or_county_input();
    });

    // Cancel Button
    $('.address_popup__cancel_button').click(function() {
        popup_address__dialog.dialog("close");
        if (popup_address__call_backs.cancel) {
            popup_address__call_backs.cancel();
        }
    });

    // Select Address Button
    $('#address_popup__select_address_submit_button').click(function() {
        var url = $(location).attr('href');
        var url_path = url.match(new RegExp("\/PreOrder\/Summary"));

       if( url_path == null ) {
            // Update pre_order with address
            $.ajax({
                type        : 'POST',
                url         : '/StockControl/Reservation/PreOrder/WebService/Address',
                cache       : 'false',
                dataType    : 'json',
                // https://metacpan.org/module/Plack::Middleware::CSRFBlock#javascript
                headers     : { "X-CSRF-Token": $("meta[name='csrf_token']").attr("content") },
                data        : {
                    pre_order_id : popup_address__pre_order_id,
                    address_id   : $('input:radio[name=address_id]:checked').val(),
                    address_type : popup_address__address_type,
                    use_for_both : $('#address_popup__select_address_use_for_both').is(':checked') ? 1 : 0
                },
                success     : function(data, textStatus, jqXHR) {
                    popup_address__dialog.dialog('close');
                    if (popup_address__call_backs.ok) {
                        popup_address__call_backs.ok(popup_address__address_type, data);
                    }
                },
                error       : function(jqXHR, textStatus, errorThrown) {
                    alert('ajax error '+errorThrown);
                    popup_address__dialog.dialog('close');
                    return false;
                }
            });
        } else {
           // We are on PreOrder/Summary page - pre-order address update applies
           var PRE_ORDER_ADDRESS_CHANGE_MAGIC_NUMBER = 1;
           var note_text  = '';
           var postdata   = {};
           var submission = {};
            var pre_order_id = $('#new_address__pre_order_id').val();

           var po_success = function(data, textStatus, jqXHR) {
                                if (data.ok) {
                                    popup_address__dialog.dialog('close');
                                    popup_address__call_backs.ok(popup_address__address_type, data);
                                }
                                else {
                                    alert(data.errmsg);
                                }
                            };

           var po_fail = function(jqXHR, textStatus, errorThrown) {
                            alert('Error creating address note: ' + textStatus);
                            alert(jqXHR.statusText);
                            popup_address__dialog.dialog('close');
                         };

           // Build address string
           var addr_field = [];
           var addr_str   = '';
           var address_id = $('input:radio[name=address_id]:checked').val();
           var address_str = address_id+"_str";
           addr_str = $('#'+address_str).val();
           addr_str = addr_str.replace(/\+\+/g, '<br />');


           postdata['note_category']    = 'PreOrder';
           postdata['note_text']        = addr_str;
           postdata['parent_id']        = pre_order_id;
           postdata['sub_id']           = pre_order_id;
           postdata['came_from']        = 'PreOrder/AJAX';
           postdata['type_id']          = PRE_ORDER_ADDRESS_CHANGE_MAGIC_NUMBER;

           submission['type']      = 'POST';
           submission['url']       = '/StockControl/Reservation/PreOrder/CreateNote';
           submission['cache']     = 'false';
           submission['dataType']  = 'json';
           // https://metacpan.org/module/Plack::Middleware::CSRFBlock#javascript
           submission['headers']   = { "X-CSRF-Token": $("meta[name='csrf_token']").attr("content") };
           submission['data']      = postdata;
           submission['success']   = po_success;
           submission['error']     = po_fail;

           $.ajax(submission);


        }
    });

    // Save New Address
    $('#address_popup__new_address_save_button').click(function() {

        // Switch address saving operation for pre-order
        var pre_order_id = $('#new_address__pre_order_id').val();
        var url = $(location).attr('href');
        var url_path = url.match(new RegExp("\/PreOrder\/Summary"));

        // get the correct county
        var county_val = if_country_is_united_states( $('#new_address__country').val() )
                         ? $('#new_address__us_state').val()
                         : ( $('#new_address__county').is('[disabled]') )
                             ? $('#new_address__country_area_dropdown').val()
                             : $('#new_address__county').val();

         if( url_path == null ) {
            // we are NOT on PreOrder/Summary page  - normal updates apply
           $.ajax({ type        : 'POST',
                    url         : '/StockControl/Reservation/PreOrder/WebService/Address',
                    cache       : 'false',
                    dataType    : 'json',
                    // https://metacpan.org/module/Plack::Middleware::CSRFBlock#javascript
                    headers     : { "X-CSRF-Token": $("meta[name='csrf_token']").attr("content") },
                    data        : {
                        pre_order_id   : $('#new_address__pre_order_id').val(),
                        use_for_both   : $('#new_address__use_for_both').is(':checked') ? 1 : 0,
                        first_name     : $('#new_address__first_name').val(),
                        last_name      : $('#new_address__last_name').val(),
                        address_line_1 : $('#new_address__address_line_1').val(),
                        address_line_2 : $('#new_address__address_line_2').val(),
                        address_line_3 : $('#new_address__address_line_3').val(),
                        towncity       : $('#new_address__towncity').val(),
                        postcode       : $('#new_address__postcode').val(),
                        county         : county_val,
                        country        : $('#new_address__country').val(),
                        address_type   : popup_address__address_type
                    },
                    success     : function(data, textStatus, jqXHR) {
                        if (data.ok) {
                            popup_address__dialog.dialog('close');
                            popup_address__call_backs.ok(popup_address__address_type, data);
                        }
                        else {
                            alert(data.errmsg);
                        }
                    },
                    error       : function(jqXHR, textStatus, errorThrown) {
                        alert('ajax error with posting new address: '+textStatus);
                        popup_address__dialog.dialog('close');
                    }
                  });

       }
       else {
           // We are on PreOrder/Summary page - pre-order address update applies
           var PRE_ORDER_ADDRESS_CHANGE_MAGIC_NUMBER = 1;
           var note_text  = '';
           var postdata   = {};
           var submission = {};

           var po_success = function(data, textStatus, jqXHR) {
                                if (data.ok) {
                                    popup_address__dialog.dialog('close');
                                    popup_address__call_backs.ok(popup_address__address_type, data);
                                }
                                else {
                                    alert(data.errmsg);
                                }
                            };

           var po_fail = function(jqXHR, textStatus, errorThrown) {
                            alert('Error creating address note: ' + textStatus);
                            alert(jqXHR.statusText);
                            popup_address__dialog.dialog('close');
                         };

           // Build address string
           var addr_field = [];
           var addr_str   = '';

           addr_field.push($('#new_address__first_name').val());
           addr_field.push($('#new_address__last_name').val());
           addr_field.push($('#new_address__address_line_1').val());
           addr_field.push($('#new_address__address_line_2').val());
           addr_field.push($('#new_address__address_line_3').val());
           addr_field.push($('#new_address__towncity').val());
           addr_field.push($('#new_address__postcode').val());
           addr_field.push(county_val);
           addr_field.push($('#new_address__country').val());

           for ( var idx in addr_field ) {
               if ( addr_field[idx] && addr_field[idx] != '' ) {
                   addr_str += addr_field[idx] + '<br />';
               }
           }

           postdata['note_category']    = 'PreOrder';
           postdata['note_text']        = addr_str;
           postdata['parent_id']        = pre_order_id;
           postdata['sub_id']           = pre_order_id;
           postdata['came_from']        = 'PreOrder/AJAX';
           postdata['type_id']          = PRE_ORDER_ADDRESS_CHANGE_MAGIC_NUMBER;

           submission['type']      = 'POST';
           submission['url']       = '/StockControl/Reservation/PreOrder/CreateNote';
           submission['cache']     = 'false';
           submission['dataType']  = 'json';
           submission['headers']   = { "X-CSRF-Token": $("meta[name='csrf_token']").attr("content") };
           submission['data']      = postdata;
           submission['success']   = po_success;
           submission['error']     = po_fail;

           $.ajax(submission);
       }

    });
});


function activate_shipment_address_popup(pre_order_id, call_backs, default_address_id) {
    popup_with_default_address(default_address_id);
    popup_address__pre_order_id = pre_order_id;
    popup_address__address_type = 'shipment';
    popup_address__call_backs   = call_backs;
}


function popup_with_default_address (addressid) {

    if (addressid) {
        $.ajax({ type    : 'GET',
             url         : '/StockControl/Reservation/PreOrder/WebService/Address',
             cache       : 'true',
             dataType    : 'json',
             data        :  {address_id   : addressid},
             success     : function(data, textStatus, jqXHR) {
                if (data.ok) {
                    $('#new_address__first_name').val(data.first_name);
                    $('#new_address__last_name').val(data.last_name);
                    $('#new_address__address_line_1').val(data.address_line_1);
                    $('#new_address__address_line_2').val(data.address_line_2);
                    $('#new_address__towncity').val(data.towncity);
                    $('#new_address__postcode').val(data.postcode);
                    $('#new_address__county').val(data.county);
                    $('#new_address__us_state').val(data.county);
                    $('#new_address__country_area_dropdown').val(data.county);
                    $('#new_address__country').val(data.country);
                    current_county = data.county;
                    display_either_states_dropdown_or_county_input(data.country);
                }
              popup_address__dialog.dialog("open");
            },
            error: function(jqXHR, textStatus, errorThrown) {
                popup_address__dialog.dialog("open");
            }

          });
    }
    else {
        popup_address__dialog.dialog("open");
    }
}

function activate_invoice_address_popup(pre_order_id, call_backs,default_address_id) {

    popup_with_default_address(default_address_id);
    //display_either_states_dropdown_or_county_input();
    popup_address__pre_order_id = pre_order_id;
    popup_address__address_type = 'invoice';
    popup_address__call_backs   = call_backs;
    popup_address__dialog.dialog("open");
}

function display_either_states_dropdown_or_county_input(default_country) {
    var country;
    if(default_country) {
        country = default_country;
    } else {
        country = $('#new_address__country').val();
    }
    if ( if_country_is_united_states( country  ) ) {
        $('#new_address__county').val('');
        $('#new_address__county_row').hide();
        $('#new_address__state_row').show();
    }
    else {
        $('#new_address__us_state').val('') ;
        $('#new_address__county_row').show();
        $('#new_address__state_row').hide();
        show_country_areas( country );
    }
}

function if_country_is_united_states (country) {

    if ( country == "United States" ) {
        return 1;
    }
    else {
        return 0;
    }
}


/**
 * Select Products Page
 **/
$(document).ready(function() {

    show_country_subdivision();

    $('#select_products__shipment_country_selection').change(function() {
        show_country_subdivision();
    });


    // Click on the 'Update Shipment Country' button
    $('#select_products__update_shipping_country_button').click(function() {

        if (($('#select_products__shipment_country_selection option:selected').text() == 'United States')
            && ($('#select_products__shipment_us_state').val() == 0)) {
            alert('You must select a state before you can continue');
            return false;
        }

        $('#select_products__shipment_country_id').val($('#select_products__shipment_country_selection').val());
        $('#select_products__shipment_country_subdivision_id').val($('#select_products__shipment_us_state').val());

        $('#select_products__search_form').submit();
    });

    $('#select_products__reset_variants_button').click(function() {
        $('.select_products__variants_checkbox').removeAttr('checked');
        $('#select_products__reservation_source_dropdown').val(0);
        $('#select_products__reservation_type_dropdown').val(0);
        $('.select_products__variants_dropdown').val(0);
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
                    if ($('#'+this.id+' select option').length >= 1 ) {
                        if ($('#'+ this.id+' select option:selected').length >=1 ) {
                            $('#'+this.id+' select option:selected').each(function () {
                                if($(this).val() != 0 ){
                                    show_none_selected_dialog    = false;
                                } else {
                                    show_not_all_selected_dialog = true;
                                }
                            });
                        }
                    }
        });

    if (show_none_selected_dialog) {
            alert('No products Quantity selected');
        }
        else if (show_not_all_selected_dialog) {
            if (confirm('Not all the product quantities were selected. Do you wish to continue?')) {
                select_products__submit_variants_form();
            }
        }
        else {
            select_products__submit_variants_form();
        }

});

    $('#select_products__shipment_address_button').click(function() {
        activate_shipment_address_popup(0, {
            ok    : select_products__update_shipment_address
        },$('.select_products__shipment_address_id').val());
    });
});

function show_country_subdivision() {
    if ($('#select_products__shipment_country_selection option:selected').text() == 'United States') {
        $('#select_products__shipment_us_state').show();
    }
    else {
        $('#select_products__shipment_us_state').hide();
        show_country_areas( $('#select_products__shipment_country_selection option:selected').text() );
    };
}

function select_products__submit_variants_form() {

    if ($('#select_products__shipment_country_id').val()) {

        display_either_states_dropdown_or_county_input();

        $('#new_address__use_for_both').attr('checked', 'true');
        $('#new_address__use_for_both').attr('disabled', 'true');

        activate_shipment_address_popup(0, {
            ok : function(address_type, data) {
                $('.select_products__shipment_address_id').val(data.address.address_id);
                $('.select_products__invoice_address_id').val(data.address.address_id);
                $('#select_products__variants_form').submit();
            }
        },null);
    }
    else {
        $('#select_products__variants_form').submit();
    }
}

function select_products__update_shipment_address(address_type, data) {
    $('.select_products__shipment_address_id').val(data.address.address_id);

    if ( data.used_for_both == true ) {
        $('.select_products__invoice_address_id').val(data.address.address_id);
    }

    $('#select_products__search_form').submit();
}

/**
 * Basket Page
 **/

var please_wait_dialog;

$(document).ready(function() {

    please_wait_dialog = $('#basket__updating_basket_dialog').dialog({
        autoOpen: false,
        height: 130,
        width: 180,
        modal: true,
        draggable: false,
        resizable: false
    });
    please_wait_dialog.parent().prependTo($('#contentRight'));
    $(".ui-dialog-titlebar").hide();

    $('.basket__options_form_input').change(function() {
       if ($('#packaging_type').val() == '' && $('#packaging_type')) {
            alert( 'Invalid selection.\nPlease choose appropriate shipment option' );
            return false;
        }
        please_wait_dialog.dialog('open');
        $('#basket__page_options_form').submit();
    });

    $('#basket__edit_items_button').click(function() {
        var day_tel     = $('#basket__page_options_form input[name=telephone_day]').val();
        var eve_tel     = $('#basket__page_options_form input[name=telephone_eve]').val();
        var org_day_tel = $('#basket__edit_item_selection input[name=org_telephone_day]').val();
        var org_eve_tel = $('#basket__edit_item_selection input[name=org_telephone_eve]').val();

        // any changes to telephone numbers then ask for confirmation
        if ( day_tel != org_day_tel || eve_tel != org_eve_tel ) {
            if ( !confirm( "Contact Details have changed without being 'Saved'.\n\nDo you still want to continue?" ) )
                return false;
        }
        $('#basket__edit_item_selection').submit();
    });

    $('#basket__take_payment_button').click(function() {
        var day_tel     = $('#basket__page_options_form input[name=telephone_day]').val();
        var eve_tel     = $('#basket__page_options_form input[name=telephone_eve]').val();
        var org_day_tel = $('#basket__complete_pre_order_form input[name=org_telephone_day]').val();
        var org_eve_tel = $('#basket__complete_pre_order_form input[name=org_telephone_eve]').val();

        // any changes to telephone numbers then ask for confirmation
        if ( day_tel != org_day_tel || eve_tel != org_eve_tel ) {
            if ( !confirm( "Contact Details have changed without being 'Saved'.\n\nDo you still want to continue?" ) )
                return false;
        }
        //check shipment option is selected.
        if ($('#packaging_type').val() == 0 ) {
            alert('Please select the shipment option');
            return false;
        }

        $('#basket__complete_pre_order_form').submit();
    });

    $('#basket__shipment_address_button').click(function() {
        activate_shipment_address_popup($('#basket__page_options__pre_order_id').val(), {
            ok    : basket__submit_options_form
        },$('#basket__page_options__shipment_address_id').val());
    });

    $('#basket__invoice_address_button').click(function() {
        activate_invoice_address_popup($('#basket__page_options__pre_order_id').val(), {
            ok    : basket__submit_options_form
        },$('#basket__page_options__invoice_address_id').val());
    });

    $('#basket__contact_details_button').click(function() {
        var day_tel = $('#basket__page_options_form input[name=telephone_day]').val();
        if ( !day_tel || day_tel == '' ) {
            alert( "You can't have an empty 'Phone day' field" );
            return false;
        }
        else {
            please_wait_dialog.dialog('open');
            $('#basket__page_options_form').submit();
        }
    });

});

function basket__submit_options_form(address_type, data) {
    if (data.used_for_both == true) {
        $('#basket__page_options__shipment_address_id').val(data.address.address_id);
        $('#basket__page_options__invoice_address_id').val(data.address.address_id);
    }
    else {
        $('#basket__page_options__'+address_type+'_address_id').val(data.address.address_id);
    }
    please_wait_dialog.dialog('open');
    $('#basket__page_options_form').submit();
}

/**
 * Payment Page
 */

var payment_popup;

$(document).ready(function() {

    payment_popup = $('#payment_popup__processing_dialog').dialog({
        autoOpen: false,
        height: 130,
        width: 220,
        draggable: false,
        resizable: false,
        closeOnEscape: false
    });
    payment_popup.parent().prependTo($('#contentRight'));

    $(".ui-dialog-titlebar").hide();

    $('#payment__pay_with_card_button').click(function() {
        if (payment_pre_validation()) {
            $('#payment_popup__processing_waiting').show();
            $('#payment_popup__processing_error').hide();
            payment_popup.dialog("open");
            payment_ajax_call();
        }
    });

    $('#payment_popup__try_again_button').click(function() {
        $('#payment_popup__processing_waiting').show();
        $('#payment_popup__processing_error').hide();
        payment_ajax_call();
    });

    $('#payment_popup__cancel_button').click(function() {
        payment_popup.dialog("close");
    });

    $('#payment__cancel_button').click(function() {
        if (confirm('Are you sure you want to cancel')) {
            $('#payment__cancel_button_form').submit();
        } else {
            return false;
        }
    });

});

function payment_ajax_call() {
    $.ajax({
        type        : 'POST',
        url         : '/StockControl/Reservation/PreOrder/WebService/Payment',
        cache       : 'false',
        dataType    : 'json',
        // https://metacpan.org/module/Plack::Middleware::CSRFBlock#javascript
        headers     : { "X-CSRF-Token": $("meta[name='csrf_token']").attr("content") },
        data        : {
            pre_order_id     : $('#payment__pre_order_id').val(),
            currency         : $('#payment__currency').val(),
            payment_due      : $('#payment__payment_due').val(),
            card_type        : $('#payment_card__card_type').val(),
            card_number      : $('#payment_card__number').val(),
            cvs              : $('#payment_card__security_number').val(),
            card_holders_name: $('#payment_card__name').val(),
            start_month      : $('#payment_card__start_month').val(),
            start_year       : $('#payment_card__start_year').val(),
            end_month        : $('#payment_card__end_month').val(),
            end_year         : $('#payment_card__end_year').val(),
            issue_number     : $('#payment_card__issue_number').val()
        },
        beforeStart : function() {
        },
        success     : function(data, textStatus, jqXHR) {
            if (data.ok) {
                payment_ok(data, textStatus, jqXHR);
            }
            else {
                payment_not_ok(data, textStatus, jqXHR);
            }
        },
        error       : payment_error
    });
}

function payment_pre_validation() {


    if ($('#payment_card__number').val() == '') {
        alert('No card number');
        return false;
    }

    var card_number = /^[0-9]{13,19}$/;

    if (!card_number.test($('#payment_card__number').val())) {
        alert('Card number must be a number between 13 and 19 digits long');
        return false;
    }

    if ($('#payment_card__name').val() == '') {
        alert('No card name');
        return false;
    }

    if ($('#payment_card__security_number').val() == '') {
        alert('No security number');
        return false;
    }

    var security_number = /^[0-9]{3,6}$/;
    if (!security_number.test($('#payment_card__security_number').val())) {
        alert('Security number must be a number minimum of 3 digits long');
        return false;
    }

    if ($('#payment_card__start_year').val() != '' && $('#payment_card__start_month').val() == '' ) {
        alert('Credit Card start month is invalid');
        return false;
    }

    if ($('#payment_card__start_year').val() == '' && $('#payment_card__start_month').val() != '' ) {
        alert('Credit Card Start year is invalid');
        return false;
    }


    if ($('#payment_card__start_year').val() != '' && $('#payment_card__start_month').val() != '') {
        var minMonth = new Date().getMonth() + 1;
        var minYear = new Date().getFullYear();
        minYear = minYear%100;
        var month = parseInt($('#payment_card__start_month').val(), 10);
        var year = parseInt($('#payment_card__start_year').val(), 10);
        if(year > minYear || (year == minYear && month > minMonth)) {
            alert('Credit Card Start date is invalid.');
            return false;
        }
    }

    //expiry month and year
    if ($('#payment_card__end_month').val() == '') {
        alert('Please Enter Valid expiry month');
        return false;
    }

    if ($('#payment_card__end_year').val() == '') {
        alert('Please Enter Valid expiry year');
        return false;
    }



    if($('#payment_card__end_year').val() != '' && $('#payment_card__end_month').val() != '') {
        var minMonth = new Date().getMonth() + 1;
        var minYear = new Date().getFullYear();
        minYear = minYear%100;
        var month = parseInt($('#payment_card__end_month').val(), 10);
        var year = parseInt($('#payment_card__end_year').val(), 10);
        if(year < minYear || (year == minYear && month < minMonth)) {
            alert('Credit Card Expiration date is invalid.');
            return false;
        }
    }

    return true;
}

function payment_ok(data, textStatus, jqXHR) {
    $('#payment__complete_pre_order_form').submit();
}

function payment_not_ok(data, textStatus, jqXHR) {
    $('#payment_popup__processing_waiting').hide();
    $('#payment_popup__processing_error_reason').html(data.errmsg);
    $('#payment_popup__processing_error').show();
}

function payment_error(jqXHR, textStatus, errorThrown) {
    $('#payment_popup__processing_waiting').hide();
    $('#payment_popup__processing_error_reason').html("Unknown error occurred: '"+textStatus+"'. Please report this to service desk");
    $('#payment_popup__processing_error').show();
}

/**
 * Summary Page
 */
$(document).ready(function() {
    $('#summary__shipment_address_button').click(function() {
        activate_shipment_address_popup($('#summary__page_options__pre_order_id').val(),
        { ok : summary__reload },$('#summary__shipment_address_id').val());
    });

    $('#summary__cancel_pre_order_button').click(function() {
        if ( !confirm("Are you sure you wish to Cancel the Pre-Order?\n\nThere will be NO more Confirmation pages") )
            return false;
    } );

    $('#summary__cancel_pre_order_item_button').click(function() {
        if ( !confirm("Are you sure you wish to Cancel these Pre-Order Items?\n\nThere will be NO more Confirmation pages") )
            return false;
    } );

    $('.summary__status_logs_toggle').click(function() {
        $('#summary__status_logs_zoom_out_img').toggle();
        $('#summary__status_logs_zoom_in_img').toggle();
        $('#summary__status_logs').toggle();
    });

    $('.summary__operator_logs_toggle').click(function() {
        $('#summary__operator_logs_zoom_out_img').toggle();
        $('#summary__operator_logs_zoom_in_img').toggle();
        $('#summary__operator_logs').toggle();
    });
});

function summary__reload() {
    window.location.reload(true);
}

/**
 * Pre-Order Item Size Change
 */

$(document).ready(function() {
    $('.pre_order_select_size').click(function() {
        var new_size_id = '#item_new_size-' + this.id.replace(/.*-/,'');
        if ( this.checked ) {
            $(new_size_id).attr( 'disabled', false );
        }
        else {
            $(new_size_id + ' option')[0].selected  = true;
            $(new_size_id).attr( 'disabled', true );
        }
    } );
});

// check the form before submitting
function validate_pre_order_item_size_change_form() {
    var num_selected            = 0;
    var num_sold_out_selected   = 0;

    $('.pre_order_select_size').each(
            function(index, element) {
                if ( element.checked ) {
                    num_selected++;
                }
            }
        );
    if ( num_selected == 0 ) {
        alert("You haven't selected anything to Change");
        return false;
    }

    $('.pre_order_select_alternative').each(
            function(index, element) {
                if ( !element.disabled ) {
                    var idx = element.selectedIndex;
                    if ( element.options[idx].value == 0 )
                        num_selected--;
                    if ( element.options[idx].text.match(/SOLD OUT/) )
                        num_sold_out_selected++;
                }
            }
        );
    if ( num_selected <= 0 ) {
        alert("You haven't selected any Alternative Sizes");
        return false;
    }
    if ( num_sold_out_selected > 0 ) {
        alert("You have selected 'SOLD OUT' Sizes, please re-select");
        return false;
    }

    if ( !confirm("Are you sure you wish to Change these Sizes?\n\nThere will be NO more Confirmation pages") )
        return false;

    return true;
}

/*
    The following was copied from:
        javascript/editaddress_dropdown.js
    due to time constraints which is why the existing code
    hasn't been re-factored to be-able to use that file
    unchanged.
*/

// Build the DropDown for Country Areas
function build_areas_dropdown(country_areas) {

    var dropdown = $('#new_address__country_area_dropdown');
    var in_dropdown = false;
    //sort the keys
    var sorted_keys = Object.keys(country_areas).sort();

    dropdown.append( $('<option></option>')
        .attr('value', "")
        .attr('selected', 'selected')
        .text("----------------"));

    sorted_keys.forEach(function( key, index, value) {
        if(key != 'none' ) {
            dropdown.append($('<optgroup></optgroup>').attr('label', key));
        }

        $.each(country_areas[key], function(idx, val) {
            $.each(val, function ( id, county ) {
                dropdown.append( $('<option></option>')
                    .attr('value', id )
                    .text(county));
                if( current_county &&  current_county.indexOf(county ) >= 0 ) {
                    in_dropdown = true;
                    dropdown.val(current_county);
                }
            });
        });
    });

    // Add county to top of dropdown if it is not from the list
    if( current_county  && ! in_dropdown ) {
        dropdown.prepend( $('<option></option>')
                        .attr('value', current_county)
                        .attr('selected', 'selected')
                        .text(current_county + " - ( Please select correct option)"));
    }
}

function show_country_areas( country ) {
    var areas = {};
    if(country &&  country_areas ) {
        $.each(country_areas, function(key, value) {
            if(key == country ) {
                areas = value;
                return false;
            }
        });
    }

    if( $.isEmptyObject(areas) ) {
        $('#new_address__country_area_dropdown').hide();
        $('#new_address__county').show();
        //disable from form submission
        $('#new_address__country_area_dropdown').attr('disabled','disabled');
        $('#new_address__county').removeAttr('disabled');
    } else {
        $('#new_address__country_area_dropdown').find('option').remove();
        $('#new_address__country_area_dropdown').find('optgroup').remove();
        build_areas_dropdown(areas);
        $('#new_address__country_area_dropdown').show();
        $('#new_address__county').hide();
        $('#new_address__county').attr("disabled", "disabled");
        $('#new_address__country_area_dropdown').removeAttr('disabled');
    }
}

