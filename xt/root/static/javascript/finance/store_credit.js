$(function(){
    $("form[name='edit_store_Credit__form']").submit(function() {
        var value =_strip_comma_and_spaces($('#value').val());

        return _IsNumeric(value);
    });

    $("form[name='create_store_credit']").submit(function() {
        var value =_strip_comma_and_spaces($('#value').val());
        return  _IsNumeric(value);
    });
});

function _strip_comma_and_spaces ( value ) {
    value = value.replace(/,/g,'');
    return value.replace(/ /g,'');
}

function _IsNumeric ( value ) {
    if(!$.isNumeric( value)) {
        alert('Value must be numeric');
        return false;
    } else {
        return true;
    }
}
