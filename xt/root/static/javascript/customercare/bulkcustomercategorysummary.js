/*
 * Back button and retry button on summary customer category update page
 */

$(document).ready(function() {

    //back button - take user back to CustomerCare/CustomerCategory
    $('.back').click(function() {
        window.location = "/CustomerCare/CustomerCategory";
    });

});

