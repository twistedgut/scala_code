$('#no_generate').click(function( event ) {
    event.preventDefault();

    populate_fields();
});

function populate_fields(){
    var channel = ['NAP-INTL', 'NAP-APAC', 'NAP-AM', 'MRP-AM', 'MRP-INTL', 'TON-AM', 'TON-INTL'];
    var customer = [ 1555813, 1555814, 1555815, 1555816, 1555817, 1555818 ];
    var currency = randCurrency;
    document.getElementById('no_orderid').value = '3' + randNumberSequence(7);
    document.getElementById('no_order_date').value = '2014-12-04 10:49:53';
    document.getElementById('no_channel').value = channel[randNumber(0, 6)];
    document.getElementById('no_customer_id').value = '3' + randNumberSequence(8);
    document.getElementById('no_account_urn').value = 'urn:nap:address:95ffb2b4-86f6-4f22-9049-f8d2fb66b1dd';

    document.getElementById('no_username').value = 'perl@net-a-porter.com';
    document.getElementById('no_shipping_sku').value = '903002-001';
    document.getElementById('no_shipping_description').value = 'Standard';

    var shipping_price = randPrice(1);
    var shipping_tax = (shipping_price * 0.2).toFixed(2);

    document.getElementById('no_shipping_unprice').value = shipping_price;
    document.getElementById('no_shipping_uncurrency').value = currency;
    document.getElementById('no_shipping_taxprice').value = shipping_tax;
    document.getElementById('no_shipping_taxcurrency').value = currency;
    document.getElementById('no_shipping_dutyprice').value = 0.00;
    document.getElementById('no_shipping_dutycurrency').value = currency;

    document.getElementById('no_delivery_contact_title').value = 'Mr';
    document.getElementById('no_delivery_contact_fname').value = 'James';
    document.getElementById('no_delivery_contact_lname').value = 'Bond';
    document.getElementById('no_delivery_contact_hphone').value = randNumberSequence(11);
    document.getElementById('no_delivery_contact_mphone').value = randNumberSequence(11);
    document.getElementById('no_delivery_contact_ophone').value = randNumberSequence(11);
    document.getElementById('no_delivery_contact_email').value = randString(8) + '@example.com';
    document.getElementById('no_delivery_address_urn').value = 'urn:nap:address:95ffb2b4-86f6-4f22-9049-f8d2fb66b1dd';
    document.getElementById('no_delivery_address_line1').value = '13 Banul Andronache St';
    document.getElementById('no_delivery_address_line2').value = 'Sector 1';
    document.getElementById('no_delivery_address_line3').value = '13 Banul Andronache St';
    document.getElementById('no_delivery_address_city').value = 'Bucharest';
    document.getElementById('no_delivery_address_postcode').value = '011663';
    document.getElementById('no_delivery_address_country').value = 'RO';

    if ( document.getElementById('no_order_items').rows.length <= 2 ) {
        add_order_line();
    }
    document.getElementById('oi_0_sku').value = '903100-001';
    document.getElementById('oi_0_unamount').value = '0.00';
    document.getElementById('oi_0_taxamount').value = '0.00';
    document.getElementById('oi_0_dutiesamount').value = '0.00';
    document.getElementById('oi_0_saleitem').value = '903100-001';
    document.getElementById('oi_0_quantity').value = '1';

    document.getElementById('oi_1_sku').value = '903100-001';
    document.getElementById('oi_1_unamount').value = '648.33';
    document.getElementById('oi_1_taxamount').value = '155.60';
    document.getElementById('oi_1_dutiesamount').value = '0.00';
    document.getElementById('oi_1_saleitem').value = '500272-011';
    document.getElementById('oi_1_quantity').value = '1';

    var total  = parseFloat(shipping_price)
        + parseFloat(shipping_tax) +
        + parseFloat(document.getElementById('oi_1_unamount').value)
        + parseFloat(document.getElementById('oi_1_taxamount').value);
    document.getElementById('no_gross_amount').value = total.toFixed(2);

    var postageTotal  = parseFloat(shipping_price)
        + parseFloat(shipping_tax);
    document.getElementById('no_postage_amount').value = postageTotal.toFixed(2);

}

function randString(x){
    var s = "";
    while(s.length<x&&x>0){
        s+= String.fromCharCode(randNumber(97, 122));
    }
    return s;
}

function randNumber(min, max){
return Math.floor(Math.random() * (max - min + 1) + min);
}

function randNumberSequence(x){
    var fullNumber = "";
    while (fullNumber.length < x){
        fullNumber += randNumber(0, 9);
    }
    return fullNumber;
}

function randCurrency(){
    var currency = ['EUR', 'GBP', 'USD', 'HKD'];
    return currency[randNumberSequence(3)];
}

function randPrice(digits){
    return randNumberSequence(digits) + '.' + randNumberSequence(2);
}
