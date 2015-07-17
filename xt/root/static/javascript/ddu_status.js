
$(document).ready(function() {

    //hide send email confirmation
    $('.send_email').hide();

    //on change event
    $('#select_ddu_authorisation__dropdown').change(function() {
        var selection = $(this).val();
        if(selection == "authorise_all" ){
            $('.send_email').show();
        } else {
            $('.send_email').hide();
        }

    });

    // Check if DDU authorisation dropdown is selected
    $("form[name='acceptDDUcharges']").submit(function() {
        var selection = $('#select_ddu_authorisation__dropdown').val();
        if( selection == '' ){
            alert("Please select an option for DDU authorisation");
            return false;
        }
    });

});

