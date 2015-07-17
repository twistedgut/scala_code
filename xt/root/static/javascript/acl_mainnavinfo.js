$(document).ready(function() {
    if( data ) {

        $.each(selection_list.split(","), function(i,e){
            $(".selection_list option[value='" + e + "']").prop("selected", true);
        });


        $(function() {
            $('#tree1').tree({
                data: data,
                autoEscape: false,
                autoOpen: collapse_flag
            });
        });
    }

    $('#acl_user_roles__submit').click(function() {
        if($('#user_roles').val() ) {
             $("#nav_options").val([]);
            $('#acl__mainnavinfo___form').submit();
        } else {
            alert( "Please Select atleast one  role." );
            return false;
        }
    });

    $('#acl_nav_options__submit').click(function() {
        if( $('#nav_options').val() ) {
            $('#user_roles').val([]);
            $('#acl__mainnavinfo___form').submit();
        } else {
            alert( "Please select atleast one navigation option.");
            return false;
        }
    });

});
