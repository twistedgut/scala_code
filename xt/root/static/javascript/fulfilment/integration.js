$(document).ready(function() {

    'use strict';

/*
 *  Make sure scanner input is active when page is loaded
 *
 * */
    $('#scanner').focus();

/*
 *  Handle user's click on Missing button.
 *
 *  The idea is:
 *      * in case if it is Missing SKU
 *        show the dialog window suggesting user to
 *        have a look onto Problem rail.
 *      * in case if it is missing Container on
 *        Integration rail - omit showing modal
 *        window and immediately submit the form.
 *
 * */
    var missing_container_function =
        ( $('#missing_dialog').length )
            ? function(e) {
                e.stopImmediatePropagation();
                e.preventDefault();
                $('#missing_dialog').modal({
                    backdrop : 'static',
                    keyboard : false
                });
            }
            : function(e) {
                e.stopImmediatePropagation();
                e.preventDefault();
                $('#missing_container_dialog').modal({
                    backdrop : 'static',
                    keyboard : false
                });
            };
    $('#missing_btn').on('click', missing_container_function);

    $('#missing_sku_is_found').on('click', function(e){
        e.stopImmediatePropagation();
        e.preventDefault();

        $('#missing_dialog').modal('hide');
    });

    $('#missing_sku_is_not_found').on('click', function(e){
        e.stopImmediatePropagation();
        e.preventDefault();

        $('form[name="missing_form"]').submit();
    });

    $('#missing_container_ok').on('click', function(e){
        e.stopImmediatePropagation();
        e.preventDefault();

        var empty_container_id = $('input#empty_container_id').first().val();

        var missing_form = $('form[name="missing_form"]');

        // Add empty contianer barcode to the missing form
        $('<input />').attr('type', 'hidden')
            .attr('name', 'empty_container_id')
            .attr('value', empty_container_id)
            .appendTo(missing_form);

        // Submit the form
        missing_form.submit();
    });

    $('#missing_container_cancel').on('click', function(e){
        e.stopImmediatePropagation();
        e.preventDefault();

        $('#missing_container_dialog').modal('hide');
    });


/*
 *  Wire up container fullness dialog if it exists
 *
 * */
    if ( $('#container_fullness_dialog').length ) {
        $('#tote_full_btn').on('click', function(e){
            e.stopImmediatePropagation();
            e.preventDefault();

            $('#container_fullness_dialog').modal({
                backdrop : 'static',
                keyboard : false
            });
        });

        $('#container_fullness_YES').on('click', function(e){
            e.stopImmediatePropagation();
            e.preventDefault();

            $('form[name="full_tote_form"]').submit();
        });

        $('#container_fullness_NO').on('click', function(e){
            e.stopImmediatePropagation();
            e.preventDefault();

            $('#container_fullness_dialog').modal('hide');
        });
    }

    /*
        Manage collapsible SKU list.

        Make sure small picture of garment is not shown after
        SKU details are exposed.
    */
    $( 'img', $('.collapse.in').prev() ).hide();
    $('.collapse').on('show.bs.collapse', function () {
        $('img', $(this).prev() ).hide();
        updateProductImage($('img', $(this)));
    });

    $('.collapse').on('hide.bs.collapse', function () {
        $('img', $(this).prev() ).show();
        updateImages(); // update all, in case several more are in view after collapsing the large area
    });


    /*
        The user will want to be looking at the top of the page.
    */
    $(window).scrollTop(0);


    /*
        Load product images - we make separate ajax requests to fetch
        the urls, to avoid slowing down the initial page display.
    */

    // Load the image for one product
    function updateProductImage (img) {
        if (img.data('src') == null) {
            // usually this means we already loaded it. but if it's null
            // for any other reason we also can't do anything useful.
            return true;
        }
        $.ajax({
            type    : 'GET',
            dataType: 'text',
            cache   : true,
            url     : img.data('src'),
            success : function (imageUrl) {
                img.attr('src', imageUrl);
            }
        });
        img.data('src',null);
    }

    // Load images for any products that are in view
    function updateImages() {
        $('.product-image').each( function (i, img) {
            // If it's not visible at the moment we can stop now.
            if (!$(img).is(":visible")) {
                return true;
            }
            // Note: this isn't a particularly clever or generic way of checking what's
            // in the viewport, it's optimised for the normal usage patterns on the GOH
            // integration page where users will start at the top and might scroll down.
            // Include a 300 pixel buffer so that we load the ones they might want soon.
            if($(img).offset().top < ($(window).scrollTop() + $(window).height() + 300)){
                updateProductImage($(img));
            }
        });
    }
    // Update all product images on initial load.
    updateImages();

    // Also check which new images need to be displayed on scroll or resize.
    $(window).bind("scroll", function() {
        updateImages();
    });
    $(window).bind("resize", function() {
        updateImages();
    });

/*
 * Wire up remove SKU button.
 *
 * Remove SKU confirmation process consists of
 * two steps: 1) ask if user is willing to remove
 * garment from the integration container,
 * 2) Prompt user to place removed garment back to
 * the front of the lane
*/
    // When Remove SKU dialog is invoked, make sure
    // it is aware of SKU that is to be removed
    $('.glyphicon-remove').on( 'click', function(e){
        if (e) e.preventDefault();

        var sku = $(this).attr('data-sku');

        // update form to have correct SKU to submit
        $('#remove_sku_dialog input[name="sku"]').val(sku);

        // update user message to contain correct SKU
        $('#sku_to_be_removed').html(sku);

        $('#remove_sku_dialog').modal({
            backdrop : 'static',
            keyboard : false,
        });
    });

    // Whenever Remove SKU dialog is shown make sure elements
    // from second step of confirmation are not visible
    $('#remove_sku_dialog').on('show.bs.modal', function (e) {
        $('#remove_sku_confirm').hide();
    });

    // Fist confirmation step, YES button handler:
    // move dialog into second step: hide YES/NO buttons,
    // show Confirm button instead, update user prompt
    $('#remove_sku_YES').on('click', function(e){
        if (e) e.preventDefault();

        $('#remove_sku_user_prompt').html("Place the SKU back on the front of the lane");
        $('#remove_sku_confirm').show();
        $('#remove_sku_YES').hide();
        $('#remove_sku_NO').hide();
    });

    // First confirmation step, NO button handler:
    // just hide the dialog.
    $('#remove_sku_NO').on('click', function(e){
        if (e) e.preventDefault();

        $('#remove_sku_dialog ').modal('hide');
    });

    // Second confirmation step, Confirm button handler:
    // submit remove SKU request to the server
    $('#remove_sku_confirm').on('click', function(e){
        if (e) e.preventDefault();

        $('#remove_sku_dialog form[name="remove_sku_from_container"]').submit();
    });


/*
 *  Make sure all tooltips over icons are active
 * */
    $('.glyphicon').tooltip();
});
