$(document).ready(function() {

    $("#fraudscreen__login_form").submit( function( eventObj ) {
        eventObj.preventDefault();

        if ( page_has_submitted_login_request == 1 )
            return false;
        page_has_submitted_login_request = 1;

        var username   = $("#fraudscreen__login_username").val();
        var password   = $("#fraudscreen__login_password").val();
        // https://metacpan.org/module/Plack::Middleware::CSRFBlock#javascript
        var csrf_token = $("meta[name='csrf_token']").attr("content");

        if ( username && password ) {
            $.ajax({
                type    :   'POST',
                url     :   '/Login',
                cache   :   false,
                async   :   true,
                dataType:   'json',
                headers :   { "X-CSRF-Token": csrf_token },
                data    :   {
                    username    : username,
                    password    : password,
                    csrf_secret : csrf_token
                },
                success :   function(data, textStatus, jqXHR) {
                    successful_login( fraud_rules__loginPopup );
                    return false;
                },
                error   :   function(jqXHR, textStatus, errorThrown) {
                    if ( jqXHR.status == 0 || jqXHR.status == 200) {
                        successful_login( fraud_rules__loginPopup );
                    }
                    if ( jqXHR.status == 401 ) {
                        $("#fraudscreen__login_prompt").hide();
                        $("#fraudscreen__login_auth_failed").show();

                        $("#fraudscreen__login_password").val('');
                        $("#fraudscreen__login_username").val('');
                        $("#fraudscreen__login_username").focus();

                        page_has_submitted_login_request = 0;
                    }
                    return false;
                }
            });
        }
        else {
            page_has_submitted_login_request = 0;
            $("#fraudscreen__login_username").focus();
        }

        return false;
    });

} );


function getUserLogin( responseText ) {

    if ( responseText != null ) {
        var response;
        var errmsg = '';
        try {
            var response = jQuery.parseJSON( responseText );
        } catch (e) {
            errmsg = "\nerror: " + e;
        }
        if ( response != null && response.csrf_token != null )
            // replace the existing and now defunct CSRF Token
            // with a new one that was returned by the Response
            $("meta[name='csrf_token']").attr( "content", response.csrf_token );
        else
            alert(
                "Unexpected response returned, please contact Service Desk if this persists:\n" +
                responseText +
                errmsg
            );
    }

    page_has_submitted_login_request = 0;

    fraud_rules__loginPopup = new xui_dialog("#fraudrules__popup_login", {
        height: 160,
        width: 400,
        title: 'Your session has timed out',
        resizable: false,
        autoOpen: false
    });

    $("#fraudscreen__login_prompt").show();
    $("#fraudscreen__login_auth_failed").hide();

    $("#fraudscreen__login_password").val('');
    $("#fraudscreen__login_username").val('');

    fraud_rules__loginPopup.open();

    $("#fraudscreen__login_username").focus();

    return false;
}

function successful_login ( popup ) {
    page_has_submitted_login_request = 1;

    popup.close();
    fraud_rules__loginPopup = null;

    alert("You have successfully logged in. You can now retry the action that failed.");

    return false;
}
