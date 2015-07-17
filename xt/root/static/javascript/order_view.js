var popup_geolocation__dialog;
$(function() {
    // Strips id integer from 'id' attribute of element
    $.fn.stripId = function() {
        return this.attr('id').match(/\d+$/);
    }

    // Display voucher usage history on mouseover
    var xvusage_on_id   = 0;
    $("img[name='voucher_usage']").mouseenter( function() {
        var id = $(this).stripId();
        if ( xvusage_on_id ) {
            $("#voucher_usage_container_"+xvusage_on_id).hide();
        }
        xvusage_on_id   = id;
        $("#voucher_usage_container_"+id).css({
            top: 10,
            left: 10
        }).fadeIn('fast')
        .mouseleave( function() {
            xvusage_on_id   = 0;
            $("#voucher_usage_container_"+id).hide();
        })
    });

    // Confirm dialog for editing the gift message
    $("form[name='preview_form']").submit(function() {
        return confirm('Are you sure you want to edit this gift message?');
    });

    $("form[name='email_preview_form']").submit(function() {
        return confirm('Are you sure you want to edit recipient email ?');
    });

    // User wants to preview/edit a shipment message
    $("input[name='preview_gift_message']").click(function() {
        var shipment_id = $(this).stripId();
        var overlay = $("#gift_message_preview_"+shipment_id);
        create_overlay( overlay, 'Gift Message');
    });

    // User wants to preview/edit a shipment item message
    $("img[name='preview_voucher_message']").click(function() {
        var shipment_item_id = $(this).stripId();
        var overlay = $("#voucher_message_preview_"+shipment_item_id);
        create_overlay( overlay, 'Gift Voucher Message' );
    });

    //user wants to edit virtual gift recipient email id
    $("img[name='preview_recipient_email']").click(function() {
        var shipment_item_id = $(this).stripId();
        var overlay = $("#recipient_email_preview_"+shipment_item_id);
        create_overlay( overlay, 'Gift Voucher Recipient Email' );
    });


    function create_overlay ( overlay, title ) {
        var form = overlay.children("form");

        var textarea = form.find("textarea").attr("readonly", true);
        var from = form.find("input[id^='gift_from']").attr("readonly", true);
        var to = form.find("input[id^='gift_to']").attr("readonly", true);
        var original_message = textarea.val();
        var original_from = from.val();
        var original_to = to.val();

        var email = form.find("input[id^='recipient_email']").attr("readonly", true);
        var original_email = email.val();

        // Declare the buttons when overlay is editable
        var edit_buttons = { 'buttons': {
            'Reset': function(e) {
                textarea.val(original_message);
                from.val(original_from);
                to.val(original_to);
                email.val(original_email);
                e.preventDefault();
            },
            'Cancel': function(e) {
                overlay.dialog('close');
                e.preventDefault();
            },
            'Save': function(e) {
                form.submit();
            }
        }};

        // Declare the buttons when overlay is in preview mode
        var preview_buttons = { 'buttons': {
            "Edit": function(e) {
                e.preventDefault();
                textarea.removeAttr("readonly");
                from.removeAttr("readonly");
                to.removeAttr("readonly");
                email.removeAttr("readonly");
                overlay.dialog( "option", edit_buttons );
            }
        }};

        overlay.dialog({
                autoOpen:false,
                modal: true,
                width: 580,
                title: title,
                close: function() {
                    textarea.val(original_message);
                    from.val(original_from);
                    to.val(original_to);
                    email.val(original_email);
                }
        });
        if ( can_edit_messages || can_edit_recipient_email) {
            overlay.dialog( 'option', preview_buttons );
        }

        overlay.dialog('open');
    }

    popup_geolocation__dialog = $('#popup_geolocation__dialog').dialog({
            autoOpen: false,
            height: 100,
            width: 700,
            draggable: false,
            resizable: false,
            modal    : true,
            open     : function() {
                $('.ui-widget-overlay').prependTo($('#content')).css({
                    position: 'fixed',
                    top: 0,
                    right: 0
                });
            }
        });
    $('.ui-dialog').prependTo($('#content'));
    $('.ui-dialog-titlebar').remove();

    $("#popup_geolocation__href").click( function(e) {
        popup_with_geolocation_info(customer_ipaddress);
    });
    $("#geolocation_close__href").click( function(e) {
        popup_geolocation__dialog.dialog("close");
    })

});

function showCardHistory(){
    document.getElementById('orders_same_card').style.display = 'block';
}

function hideCardHistory(){
    document.getElementById('orders_same_card').style.display = 'none';
}

function toggle_view( section, type ) {
    var elem = document.getElementById( section );
    var link = document.getElementById("lnk"+section);

    if (elem.style.display=='none' || !elem.style.display){
        elem.style.display = "block";
        if (link.style){
            link.innerHTML="<img src='/images/icons/zoom_out.png' alt='Hide "+type+"'>";
        }
    }
    else {
        elem.style.display = "none";
        if (link.style){
            link.innerHTML="<img src='/images/icons/zoom_in.png' alt='View "+type+"'>";
        }
    }
}

function launchPopup( url) {
    window.open(url, 'NotesPop', 'location=0,status=0,toolbar=0,resizable=1,width=750,height=600,scrollbars=1');
    return false;
}


function popup_with_geolocation_info (ipaddress) {

    if (ipaddress) {
        $.ajax({ type    : 'GET',
             url         : '/AJAX/GeoLocationWS',
             cache       : 'true',
             dataType    : 'json',
             data        :  {ip_address   : ipaddress},
             success     : function(data, textStatus, jqXHR) {
                if(data.ok) {
                    $('#geolocation_country__td').text(data.country_name);
                    $('#geolocation_region__td').text(data.region_name);
                    $('#geolocation_city__td').text(data.city);
                    $('#geolocation_postcode__td').text(data.postal_code);
                      popup_geolocation__dialog.dialog("open");
                }
                else {
                    alert(data.errmsg);
                }
            },
            error: function(jqXHR, textStatus, errorThrown) {
                alert('ajax error with getting IP Address Information: '+textStatus);
                popup_geolocation__dialog.dialog("close");
            }

          });
    }
    else {
        popup_geolocation__dialog.dialog("open");
    }
}

function xui_popup_with_url ( id, url, wait_message ) {

    $(id).empty();

    var xui_popup = new xui_dialog(id, {
        autoOpen: false,
        height: 600,
        width: 800,
        modal    : true,
        resizable: false,
        draggable: true
    } );

    $(document).ready( function() {
        $("#xui_close_button").click( function(e) {
            xui_popup.close();
        } );

        if ( wait_message ) {
            $(id).append('<h3>'+wait_message+'</h3>');
        }
    } );

    xui_popup.open();

    $(id).load(url, function() {
        $("#xui_close_button").click( function(e) {
            xui_popup.close();
        } );
    } );
}
