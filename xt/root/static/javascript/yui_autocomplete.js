/* factored out YUI auto-complete into a separate file toi be included */

/* In your template:
 
    <div id="ac_search">
        <input id="ac_input" type="text" size="20" value="">
        <input id="ac_input_id" type="hidden" name="MY_USEFUL_FORM_ELEMENT_NAME" value=""/>
        <div id="ac_container"></div>
    </div>
*/

/* In your handler/code:
 
    $handler->{data}{yui_enabled} = 1;
    $handler->{data}{js} = [
        '/javascript/yui_autocomplete.js',
    ];
*/

function init_autocomplete() {
    get_users    = "/json/operators";
    users_schema = [
        "ResultSet.Result",
        "name",
        "id",
        "department",
        "email_address"
    ];

    // Set up autocomplete stuff
    ac_source              = new YAHOO.widget.DS_XHR(get_users, users_schema);
    ac_source.responseType = YAHOO.widget.DS_XHR.TYPE_JSON;
    ac                     = new YAHOO.widget.AutoComplete("ac_input","ac_container", ac_source);

    // something to format the results in a nicer/different way
    ac.formatResult = function(oResultItem, sQuery) {
        // order defined in users_schema above
        var sName           = oResultItem[0];
        var sID             = oResultItem[1];
        var sDepartment     = oResultItem[2];
        var sEmail          = oResultItem[3];

        var sMarkup = '<div><b>'
            + oResultItem[0]
            + '</b> ('
            + sDepartment
            + ')</div>'
        ;

        // if they have an email address
        if ('' != sEmail) {
            sMarkup = sMarkup
                + '<div>'
                + '&nbsp;&nbsp;&nbsp;-&nbsp;'
                + (sEmail || '<em>email not set</em>')
                + '</div>'
            ;
        }

        return sMarkup;
    };

    // Check that operator entered existing user
    function validate_form(arg) {
        if (!arg) {
            alert('Please enter an existing user');
            return false;
        }
        else return true;
    };

    // Pass id to browser
    ac.itemSelectEvent.subscribe(fnCallback);
    function fnCallback(e, args) {
        YAHOO.util.Dom.get("ac_input_id").value = args[2][1];
        console.log(YAHOO.util.Dom.get("ac_input_id").value);
    };

    // Draw container in correct place
    ac.doBeforeExpandContainer = function(oTextbox, oContainer, sQuery, aResults) {
        var pos = YAHOO.util.Dom.getXY(oTextbox);
        pos[1] += YAHOO.util.Dom.get(oTextbox).offsetHeight + 2;
        YAHOO.util.Dom.setXY(oContainer,pos);
        return true;
    };

    // Options
    ac.useShadow                = true;
    ac.forceSelection           = true; // Script will not work properly if this is off
    ac.autoHighlight            = true;
    // ac.typeAhead                = true;
    ac.allowBrowserAutocomplete = false;
    ac.animSpeed                = 0.1;
}
YAHOO.util.Event.onDOMReady(init_autocomplete);
