function saveAction(ruleset) {
    var xwait = new xui_wait_dialog();

    xwait.setDialogMessage('Saving Fraud Rules to staging');
    xwait.open();

    $.ajax({
        type     : 'POST',
        async    : true,
        url      : '/Finance/FraudRules/Staging',
        cache    : false,
        dataType : 'json',
        // https://metacpan.org/module/Plack::Middleware::CSRFBlock#javascript
        headers  : { "X-CSRF-Token": $("meta[name='csrf_token']").attr("content") },
        data     : {
            force_commit    : $('#fraudscreen__force_commit').prop('checked'),
            action          : 'save',
            ruleset         : JSON.stringify(ruleset)
        },
        error    : function(jqXHR, textStatus, errorThrown) {
            if ( jqXHR.status == 401 ) {
                xwait.close();
                getUserLogin( jqXHR.responseText );
            }
            else {
                xlog.debug('Save to staging failed: Error '+textStatus);
                xwait.close();
                alert('Error Saving Fraud Rules : '+textStatus + errorThrown);
            }
        },
        success  : function(data, textStatus, jqXHR) {
            if(data.ok) {
                xwait.setDialogMessage('Reloading Fraud Rules');
                window.onbeforeunload = null;
                location.reload();
                xwait.close();
            }
            else {
                xwait.close();
                if(data.ruleset) {
                    alert("There were errors trying to save changes. These will be shown in red on the page.");
                    $.each(data.ruleset, function(idx, val) {
                        table.updateRule(val);
                    });
                } else {
                    alert(data.error_msg);
                }
            }
            xlog.debug('Save to staging '+textStatus);
        }
    });
}


function pullFromLiveAction() {

    var xwait = new xui_wait_dialog();

    if (!confirm('Are you sure you want to discard Staging rules and reset them from Live?')) {
        return false;
    }

    xwait.setDialogMessage('pulling from live');
    xwait.open();

    $.ajax({
        type     : 'POST',
        async    : true,
        url      : '/Finance/FraudRules/Staging',
        cache    : false,
        dataType : 'json',
        // https://metacpan.org/module/Plack::Middleware::CSRFBlock#javascript
        headers  : { "X-CSRF-Token": $("meta[name='csrf_token']").attr("content") },
        data     : {
           action: 'pull_from_live'
        },
        error    : function(jqXHR, textStatus, errorThrown) {
            if ( jqXHR.status == 401 ) {
                xwait.close();
                getUserLogin( jqXHR.responseText );
            }
            else {
                alert('Error Pulling Fraud Rules : '+textStatus + errorThrown);
                xwait.close();
            }
        },
        success  : function(data, textStatus, jqXHR) {
            xwait.close();
            if( data.ok) {
                alert( 'Fraud Rules were pulled successfully' );
                location.reload();
            }
            else {
                alert(data.error_msg);
                xwait.close();
            }
            xlog.debug('Pull from live '+textStatus);
        }
    });
}


function pushToLiveAction( change_log_message ) {

    if ( ! change_log_message ) {
        return;
    }

    var xwait = new xui_wait_dialog();

    xwait.setDialogMessage('pushing to live');
    xwait.open();

    $.ajax({
        type     : 'POST',
        async    : true,
        url      : '/Finance/FraudRules/Staging',
        cache    : false,
        dataType : 'json',
        // https://metacpan.org/module/Plack::Middleware::CSRFBlock#javascript
        headers  : { "X-CSRF-Token": $("meta[name='csrf_token']").attr("content") },
        data     : {
           action: 'push_to_live',
           log_message : change_log_message
        },
        error    : function(jqXHR, textStatus, errorThrown) {
            if ( jqXHR.status == 401 ) {
                xwait.close();
                getUserLogin( jqXHR.responseText );
            }
            else {
                alert('Error Pushing to Live : '+textStatus + errorThrown);
                xwait.close();
            }
        },
        success  : function(data, textStatus, jqXHR) {
            xwait.close();
            if( data.ok) {
                alert( 'Fraud Rules were pushed successfully' );
            }
            else {
                alert(data.error_msg);
                xwait.close();
            }
            xlog.debug('pushed to live '+textStatus);
        }
    });
}
