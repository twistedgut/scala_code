/**
 * Payment Page
 */

$(document).ready(function() {

    $('#payment__pay_with_card_button').click(function() {

        if ( is_new_card() ) {
            if ( ! payment_pre_validation() ) {
                return false;
            }
        }

        build_and_submit_payment_form();

    });

    $('#payment__cancel_button').click(function() {
        if (confirm('Are you sure you want to cancel')) {
            $('#payment__cancel_button_form').submit();
        }
        return false;
    });

    // Default to entering new card details.
    $('.payment__saved_card_option[value="-1"]').prop( 'checked', 'true' );

})

function payment_pre_validation() {

    var cardchoice = $('.payment__saved_card_option:checked').val();
    var cardcvs    = $('#payment_card__security_number').val();

    if ( is_new_card() && cardcvs == '' ) {
        alert('No security number');
        return false;
    }

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

    if ($('#payment_card__security_number').val() == '' && cardchoice == -1) {
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

function is_new_card() {

    var no_saved_cards = $('#payment__no_saved_cards').length;
    var cardchoice     = $('.payment__saved_card_option:checked').val();

    if ( no_saved_cards || cardchoice == -1 ) {
        return true;
    } else {
        return false;
    }

}

function build_and_submit_payment_form() {

    var form = $('#payment__payment_form');

    if ( is_new_card() ) {

        add_input( form, 'savedCard', 'false' );
        add_input( form, 'keepCard' );
        add_input( form, 'cardType' );
        add_input( form, 'expiryMonth' );
        add_input( form, 'expiryYear' );
        add_input( form, 'cVSNumber' );
        add_input( form, 'cardNumber' );
        add_input( form, 'cardHoldersName' );
        add_input( form, 'issueNumber' );
        add_input( form, 'startMonth' );
        add_input( form, 'startYear' );

    } else {

        var saved_card    = $('.payment__payment_form_field[name="savedCard"]');
        var card_type     = saved_card.attr( 'cardtype' );
        var last_4_digits = saved_card.attr( 'value' );

        add_input( form, 'savedCard', 'true' );
        add_input( form, 'keepCard', 'true' );
        add_input( form, 'cardType', card_type );
        add_input( form, 'last4Digits', last_4_digits );

    }

    form.submit();

}

function add_input( form, name, value ) {

    var input = $('<input>');

    if ( ! value ) {
        value = $('.payment__payment_form_field[name="' + name + '"]').val();
    }

    input.attr( 'name', name );
    input.attr( 'value', value );
    input.attr( 'type', 'hidden' );

    form.append( input );

}
