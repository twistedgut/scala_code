var order_item_count = 0;
var promotion_line_count = 0;
var promotion_basket_count = 0;

$('#no_use_delivery_data_for_billings').click(function( event ) {
    $('#no_billing table').toggleClass('hidden');
});

$('#no_add_order_items').click(function( event ) {
    event.preventDefault();

    add_order_line();
});

$('#no_add_promotion_line_items').click(function( event ) {
    event.preventDefault();

    add_promotion_line();
});

$('#no_add_promotion_basket_items').click(function( event ) {
    event.preventDefault();

    add_promotion_basket();
});

function generate_selector(params, id){
    var checkbox = '<select id="'+id+'">';
    for(i=0; i<params.length; i++){
        checkbox += '<option value='+params[i]+'>'+params[i]+'</option>';
    }
    checkbox += '</select>';
    return checkbox;
}

function generate_field(columns, i, field_type, count){
    var def = columns[i];
    switch(field_type){
        case "promotion_line":
            var idtype = 'pli';
            break;
        case "promotion_basket":
            var idtype = 'pbi';
            break;
        case "order_item":
            var idtype = 'oi'
    }
    var id = idtype + '_' + count + '_' + def['name'];
    if(def['type'] == 'text') {
        return '<input id="'+id+'" type="text" />';
    } else if(def['type'] == 'currency') {
        return generate_selector(['GBP', 'USD', 'HKD', 'EUR'], id);
    } else if (def['type'] == 'remove') {
        return '<button id="'+id+'" class="remove_' +idtype+ '" type="checkbox" checked="checked">-</button>';
    } else if (def['type'] == 'checkbox') {
        return '<input id="'+id+'" type="checkbox" checked="checked" />';
    }
}

function add_order_line() {
    if (order_item_count == 0) {
        $('#no_add_order_items').after('<table id="no_order_items"><tr></tr></table');
        var columns = ['SKU', 'Unit Net Price', '', 'Tax', '', 'Duties', '', 'Sale Item', 'Returnable', 'Quantity']
        for (var i in columns) {
            $('#no_order_items tr:first').append('<th>' + columns[i] + '</th>')
        }
     }
    $('#no_order_items tbody').append('<tr id="oi_row_'+order_item_count+'"></tr>')
    var columns = [
        { 'name': 'sku',            'type': 'text' },
        { 'name': 'unamount',       'type': 'text' },
        { 'name': 'uncurrency',     'type': 'currency' },
        { 'name': 'taxamount',      'type': 'text' },
        { 'name': 'taxcurrency',    'type': 'currency' },
        { 'name': 'dutiesamount',   'type': 'text' },
        { 'name': 'dutiescurrency', 'type': 'currency' },
        { 'name': 'saleitem',       'type': 'checkbox'},
        { 'name': 'returnable',     'type': 'checkbox' },
        { 'name' : 'quantity',      'type': 'text'},
        { 'name': 'remove',         'type': 'remove' }
    ];
    for (var i in columns) {
        var content = generate_field(columns, i, 'order_item', order_item_count);
        $('#no_order_items tr:last').append('<td>'+content+'</td>');
    }
    order_item_count+=1;

    $('.remove_oi').click(function( event ) {
        var order_line = $(this).attr('id').split('_')[1];
        $('#oi_row_' + order_line).remove();
        order_item_count -= 1;
    });
}

function add_promotion_line() {
    if (promotion_line_count == 0) {
        $('#no_add_promotion_line_items').after('<table id="no_promotion_line_items"><tr></tr></table');
        var columns = ['Type', 'Description', 'Value', '']
        for (var i in columns) {
            $('#no_promotion_line_items tr:first').append('<th>' + columns[i] + '</th>')
        }
    }
    promotion_line_count+=1;

    $('#no_promotion_line_items tbody').append('<tr id="pli_row_'+promotion_line_count+'"></tr>')
    var columns = [
        { 'name': 'promotype',      'type': 'text' },
        { 'name': 'description',    'type': 'text' },
        { 'name': 'value',          'type': 'text' },
        { 'name': 'valcurrency',    'type': 'currency' },
        { 'name': 'remove',         'type': 'remove' }
    ];
    for (var i in columns) {
        var def = columns[i];
        var content = generate_field(columns, i, 'promotion_line', promotion_line_count);
        $('#no_promotion_line_items tr:last').append('<td>'+content+'</td>');
    }
    $('.remove_pli').click(function( event ) {
        var promotion_line = $(this).attr('id').split('_')[1];
        $('#pli_row_' + promotion_line).remove();
        promotion_line_count-=1;
    });
}

function add_promotion_basket() {
    if (promotion_basket_count == 0) {
        $('#no_add_promotion_basket_items').after('<table id="no_promotion_basket_items"><tr></tr></table');
        var columns = ['Type', 'Description', 'Value', '']
        for (var i in columns) {
            $('#no_promotion_basket_items tr:first').append('<th>' + columns[i] + '</th>')
        }
    }
    promotion_basket_count+=1;

    $('#no_promotion_basket_items tbody').append('<tr id="pbi_row_'+promotion_basket_count+'"></tr>')
    var columns = [
        { 'name': 'promotype',      'type': 'text' },
        { 'name': 'description',    'type': 'text' },
        { 'name': 'value',          'type': 'text' },
        { 'name': 'valcurrency',    'type': 'currency' },
        { 'name': 'remove',         'type': 'remove' }
    ];
    for (var i in columns) {
        var def = columns[i];
        var content = generate_field(columns, i, 'promotion_basket', promotion_basket_count);
        $('#no_promotion_basket_items tr:last').append('<td>'+content+'</td>');
    }
    $('.remove_pbi').click(function( event ) {
    promotion_basket_count -= 1;

    var promotion_basket = $(this).attr('id').split('_')[1];
    $('#pbi_row_' + promotion_basket).remove();
    });
}

$('#no_submit').click(function( event ) {
    event.preventDefault();
    var delivery_data = {
        name: {
            title: $('#no_delivery_contact_title').val(),
            firstname: $('#no_delivery_contact_fname').val(),
            last_name: $('#no_delivery_contact_lname').val()
        },
        address: {
            urn: $('#no_delivery_address_urn').val(),
            line_1: $('#no_delivery_address_line1').val(),
            line_2: $('#no_delivery_address_line2').val(),
            line_3: $('#no_delivery_address_line3').val(),
            towncity: $('#no_delivery_address_city').val(),
            county: ( $('#no_delivery_address_country').val() == 'US' ? null : $('#no_delivery_address_divison').val() ),
            state: ( $('#no_delivery_address_country').val() == 'US' ? $('#no_delivery_address_divison').val() : null ),
            postcode: $('#no_delivery_address_postcode').val(),
            country_code: $('#no_delivery_address_country').val(),
        },
        contact: {
                home: $('#no_delivery_contact_hphone').val(),
                mobile: $('#no_delivery_contact_mphone').val(),
                office: $('#no_delivery_contact_ophone').val(),
                email: $('#no_delivery_contact_email').val(),
        },
    };

    var order_items = [];

    for (var order_item = 1; order_item <= order_item_count; order_item++) {
        order_items.push({
            description: $('#oi_' + order_item + '_description').val(),
            sku: $('#oi_' + order_item + '_sku').val(),
            unit_net_price: {
                amount: $('#oi_' + order_item + '_unamount').val(),
                currency: $('#oi_' + order_item + '_uncurrency').val()
            },
            tax: {
                amount: $('#oi_' + order_item + '_taxamount').val(),
                currency: $('#oi_' + order_item + '_taxcurrencys').val()
            },
            duties: {
                amount: $('#oi_' + order_item + '_dutiesamount').val(),
                currency: $('#oi_' + order_item + 'unamoundutiescurrency').val(),
            },
            quantity: $('#oi_' + order_item + '_quantity').val(),
            saleflag: $('#oi_' + order_item + '_saleitem').val(),
            is_returnable: $('#oi_' + order_item + '_returnable').val(),
        });
    }
    var promotion_line_items = [];

    for (var promotion_line_item = 1; promotion_line_item <= promotion_line_count; promotion_line_item++) {
        promotion_line_items.push({
            type: $('#pli_' + promotion_line_item + '_promotype').val(),
            description: $('#pli_' + promotion_line_item + '_description').val(),
            value: $('#pli_' + promotion_line_item + '_value').val(),
            currency: $('#pli_' + promotion_line_item + '_valcurrency').val()
        });
    }

    var promotion_basket = [];

    for (var promotion_basket_item = 1; promotion_basket_item <= promotion_basket_count; promotion_basket_item++) {
        promotion_basket.push({
            type: $('#pbi_' + promotion_basket_item + '_promotype').val(),
            description: $('#pli_' + promotion_basket_item + '_description').val(),
            value: $('#pbi_' + promotion_basket_item + '_value').val(),
            currency: $('#pbi_' + promotion_basket_item + '_valcurrency').val()
        });
    }
    $.ajax({
        url: "/api/order",
        type: "POST",
        data: JSON.stringify({
            order_id: $('#no_orderid').val(),
            order_date: $('#no_order_date').val(),
            channel: $('#no_channel').val(),
            customer_id: $('#no_customer_id').val(),
            account_urn: $('#no_account_urn').val(),
            used_stored_credit_card: 0,
            is_signature_required: $('#no_is_signature_required').val(),
            logged_in_username: $('#no_username').val(),
            tender: {
                id: "36",
                type: $('#no_payment_type').val(),
                amount: $('#no_gross_amount').val(),
                currency: $('#no_gross_currency').val(),
                pre_auth_code: $('#no_auth_code').val(),
                rank  : "1",
            },
            basket_promotions: promotion_basket,
            billing: ( $("#no_use_delivery_data_for_billings").attr('checked')
                ? delivery_data
                :  {
                    name: {
                        title: $('#no_billing_contact_title').val(),
                        firstname: $('#no_billing_contact_fname').val(),
                        last_name: $('#no_billing_contact_lname').val()
                    },
                    address: {
                        urn: $('#no_billing_address_urn').val,
                        line_1: $('#no_billing_address_line1').val(),
                        line_2: $('#no_billing_address_line2').val(),
                        line_3: $('#no_billing_address_line3').val(),
                        towncity: $('#no_billing_address_city').val(),
                        county: ( $('#no_billing_address_country').val() == 'US' ? null : $('#no_billing_address_divison').val() ),
                        state: ( $('#no_billing_address_country').val() == 'US' ? $('#no_billing_address_divison').val() : null ),
                        postcode: $('#no_billing_address_postcode').val(),
                        country_code: $('#no_billing_address_country').val(),
                    },
                    contact: {
                        home: $('#no_billing_contact_hphone').val(),
                        mobile: $('#no_billing_contact_mphone').val(),
                        office: $('#no_billing_contact_ophone').val(),
                        email: $('#no_billing_contact_email').val(),
                    },
                }
            ),
            delivery: delivery_data,
            promotion_lines: promotion_line_items,
            shipping: {
                description: $('#no_shipping_description').val(),
                sku: $('#no_shipping_sku').val(),
                unit_net_price: {
                    amount: $('#no_shipping_unprice').val(),
                    currency: $('#no_shipping_uncurrency').val()
                },
                tax: {
                    amount: $('#no_shipping_taxprice').val(),
                    currency: $('#no_shipping_taxcurrency').val()
                },
                duties: {
                    amount: $('#no_shipping_dutyprice').val(),
                    currency: $('#no_shipping_dutycurrency').val()
                },
                is_returnable: 0,
                quantity: '1',
            },
            order_lines: order_items,
            gross_total: {
                amount: $('#no_gross_amount').val(),
                currency: $('#no_gross_currency').val()
            },
            postage: {
                amount: $('#no_postage_amount').val(),
                currency: $('#no_postage_currency').val()
            }
        }),
        contentType: "application/json; charset=utf-8",
        dataType: "json",
        success: function(data, textStatus, jqXHR) {
            alert("An order file has been created: " + data['file_path']);
        },
        error: function (jqXHR, textStatus, errorThrown) {
            alert("Big sad :( : " + errorThrown);
        }
    });

});


add_order_line();
add_promotion_line();
add_promotion_basket();
