#!/usr/bin/env perl
use NAP::policy "tt",     'test';

=head1 NAME

Admin_UserRoles.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /Admin/UserRoles

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/Admin/UserRoles',
    expected   => {
            available_roles => [
                {
                    name => 'app_canModifyFraudHotlist',
                    value => 'app_canModifyFraudHotlist'
                },
                {
                    name => 'app_testProcess',
                    value => 'app_testProcess'
                },
                {
                    name => 'app_testProcess1',
                    value => 'app_testProcess1'
                },
                {
                    name => 'app_testProcess2',
                    value => 'app_testProcess2'
                },
            ],
            new_roles => [
                {
                    name => 'app_canViewFraudHotlist',
                    value => 'app_canViewFraudHotlist'
                },
                {
                    name => 'APP_FIREFOX',
                    value => 'APP_FIREFOX'
                },
                {
                    name => 'app_testing',
                    value => 'app_testing'
                }
            ],
        },
);

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en">
    <head>
        <meta http-equiv="Content-type" content="text/html; charset=utf-8">

        <title>XT-DC1</title>


        <link rel="shortcut icon" href="/favicon.ico">



        <!-- Load jQuery -->
        <script type="text/javascript" src="/jquery/jquery-1.7.min.js"></script>
        <script type="text/javascript" src="/jquery-ui/js/jquery-ui.custom.min.js"></script>
        <!-- common jQuery date picker plugin -->
        <script type="text/javascript" src="/jquery/plugin/datepicker/date.js"></script>
        <script type="text/javascript" src="/javascript/datepicker.js"></script>

        <!-- jQuery CSS -->
        <link rel="stylesheet" type="text/css" href="/jquery-ui/css/smoothness/jquery-ui.custom.css">

        <!-- Core Javascript -->
        <script type="text/javascript" src="/javascript/common.js"></script>
        <script type="text/javascript" src="/javascript/xt_navigation.js"></script>
        <script type="text/javascript" src="/javascript/form_validator.js"></script>
        <script type="text/javascript" src="/javascript/validate.js"></script>
        <script type="text/javascript" src="/javascript/comboselect.js"></script>
        <script type="text/javascript" src="/javascript/date.js"></script>

        <!-- Custom Javascript -->




        <script type="text/javascript" src="/javascript/tooltip_popup.js"></script>
        <script type="text/javascript" src="/javascript/quick_search_help.js"></script>

        <!-- YUI majik -->
        <script type="text/javascript" src="/yui/yahoo-dom-event/yahoo-dom-event.js"></script>
        <script type="text/javascript" src="/yui/container/container_core-min.js"></script>
        <script type="text/javascript" src="/yui/menu/menu-min.js"></script>
        <script type="text/javascript" src="/yui/animation/animation.js"></script>
        <!-- dialog dependencies -->
        <script type="text/javascript" src="/yui/element/element-min.js"></script>
        <!-- Scripts -->
        <script type="text/javascript" src="/yui/utilities/utilities.js"></script>
        <script type="text/javascript" src="/yui/container/container-min.js"></script>
        <script type="text/javascript" src="/yui/yahoo/yahoo-min.js"></script>
        <script type="text/javascript" src="/yui/dom/dom-min.js"></script>
        <script type="text/javascript" src="/yui/element/element-min.js"></script>
        <script type="text/javascript" src="/yui/datasource/datasource-min.js"></script>
        <script type="text/javascript" src="/yui/datatable/datatable-min.js"></script>
        <script type="text/javascript" src="/yui/tabview/tabview-min.js"></script>
        <script type="text/javascript" src="/yui/slider/slider-min.js" ></script>
        <!-- Connection Dependencies -->
        <script type="text/javascript" src="/yui/event/event-min.js"></script>
        <script type="text/javascript" src="/yui/connection/connection-min.js"></script>
        <!-- YUI Autocomplete sources -->
        <script type="text/javascript" src="/yui/autocomplete/autocomplete-min.js"></script>
        <!-- calendar -->
        <script type="text/javascript" src="/yui/calendar/calendar.js"></script>
        <!-- Custom YUI widget -->
        <script type="text/javascript" src="/javascript/Editable.js"></script>
        <!-- CSS -->
        <link rel="stylesheet" type="text/css" href="/yui/grids/grids-min.css">
        <link rel="stylesheet" type="text/css" href="/yui/button/assets/skins/sam/button.css">
        <link rel="stylesheet" type="text/css" href="/yui/datatable/assets/skins/sam/datatable.css">
        <link rel="stylesheet" type="text/css" href="/yui/tabview/assets/skins/sam/tabview.css">
        <link rel="stylesheet" type="text/css" href="/yui/menu/assets/skins/sam/menu.css">
        <link rel="stylesheet" type="text/css" href="/yui/container/assets/skins/sam/container.css">
        <link rel="stylesheet" type="text/css" href="/yui/autocomplete/assets/skins/sam/autocomplete.css">
        <link rel="stylesheet" type="text/css" href="/yui/calendar/assets/skins/sam/calendar.css">

        <!-- (end) YUI majik -->




            <script>
    $(document).ready(function() {
        $('#userroles').submit( function(e) {
            if ( $('#newrole').val() ) {
                var aNewRole = $('#newrole').val();
                $('#newroles').append($('<option>', {
                    value: aNewRole,
                    text: aNewRole,
                } ) ).attr('selected', true);
            }
            $('#newroles > option').each( function() {
                $(this).attr('selected', true);
            } );
        } );
        $('#add').click( function() {
            $('#availableroles > option:selected').remove().appendTo('#newroles').attr('selected', true);
        } );
        $('#remove').click( function() {
            $('#newroles > option:selected').remove().appendTo('#availableroles').attr('selected', false);
        } );
    });
</script>




        <!-- Custom CSS -->



        <!-- Core CSS
            Placing these here allows us to override YUI styles if we want
            to, but still have extra/custom CSS below to override the default XT
            styles
        -->
        <link rel="stylesheet" type="text/css" media="screen" href="/css/xtracker.css">
        <link rel="stylesheet" type="text/css" media="screen" href="/css/xtracker_static.css">
        <link rel="stylesheet" type="text/css" media="screen" href="/css/customer.css">
        <link rel="stylesheet" type="text/css" media="print" href="/css/print.css">

        <!--[if lte IE 7]>
          <link rel="stylesheet" type="text/css" href="/css/xtracker_ie.css">
        <![endif]-->
        <!--[if lte IE 6]>
          <link rel="stylesheet" type="text/css" href="/css/xtracker_ie6.css">
        <![endif]-->




    </head>
    <body class="yui-skin-sam">

        <div id="container">

    <div id="header">
    <div id="headerTop">
        <div id="headerLogo">
           <table>
              <tr>
                 <td valign="bottom"><img width="35px" height="35px" src="/images/flag_INTL.png"></td>
                 <td>
                    <img src="/images/logo_small.gif" alt="xTracker">
                    <span>DISTRIBUTION</span><span class="dc">DC1</span>
                 </td>
              </tr>
           </table>
        </div>

        <div id="headerControls">
                <form class="quick_search" method="get" action="/QuickSearch">
                    <span class="helptooltip" title="<p>Type a key followed by an ID or number to search as follows:</p><br /><table><tr><th width='20%'>Key</th><th>Search Using</th></tr><tr><td>o</td><td>Order Number</td></tr><tr><td>c</td><td>Customer Number</td></tr><tr><td>s</td><td>Shipment Number</td></tr><tr><td>r</td><td>RMA Number</td></tr><tr><td></td><td>--------------------</td></tr><tr><td>p</td><td>Product ID / SKU</td><tr><td></td><td>--------------------</td></tr><tr><td>e</td><td>Customer Email</td></tr><tr><td>z</td><td>Postcode / Zip</td></tr></table><br /><p><b>Tip:</b> type 'Alt-/' to jump to the quick search box</p><p>Click on the blue ? for more help</p>">
                        Quick Search:
                    </span>

                    <img id="quick_search_ext_help" src="/images/icons/help.png" />
                                        <div id="quick_search_ext_help_content" title="Quick Search Extended Help">
                        <h1>Quick Search Extended Help</h1>
                        <p>Entering a number on its own will search customer number, order number and shipment number.</p>
                        <p>or just enter <i>an email address</i><br />
                        or <i>any text</i> to search customer names</p>
                        <p>Example:</p>
                        <p>12345 will search for orders, shipments and customers with that ID.</p>
                        <p>o 12345 will search for orders with that ID.</p>
                        <p>John Smith will search for a customer by that name.</p>
                        <table>
                            <tr><th width="20%">Key</th><th>Search Using</th></tr>
                            <tr><td colspan=2><hr></td></tr>
                            <tr><td colspan=2>Customer Search</td></tr>
                            <tr><td colspan=2><hr></td></tr>
                            <tr><td>c</td><td>Customer number / name</td></tr>
                            <tr><td>e</td><td>Email Address</td></tr>
                            <tr><td>f</td><td>First Name</td></tr>
                            <tr><td>l</td><td>Last Name</td></tr>
                            <tr><td>t</td><td>Telephone number</td></tr>
                            <tr><td colspan=2><hr></td></tr>
                            <tr><td colspan=2>Order / PreOrder Search</td></tr>
                            <tr><td colspan=2><hr></td></tr>
                            <tr><td>o</td><td>Order Number</td></tr>
                            <tr><td>op</td><td>Orders for Product ID</td></tr>
                            <tr><td>ok</td><td>Orders for SKU</td></tr>
                            <tr><td colspan=2><hr></td></tr>
                            <tr><td colspan=2>Product / SKU Search</td></tr>
                            <tr><td colspan=2><hr></td></tr>
                            <tr><td>p</td><td>Product ID / SKU</td></tr>
                            <tr><td colspan=2><hr></td></tr>
                            <tr><td colspan=2>Shipment / Return Search</td></tr>
                            <tr><td colspan=2><hr></td></tr>
                            <tr><td>s</td><td>Shipment Number</td></tr>
                            <tr><td>x</td><td>Box ID</td></tr>
                            <tr><td>w</td><td>Airwaybill Number</td></tr>
                            <tr><td>r</td><td>RMA Number</td></tr>
                            <tr><td colspan=2><hr></td></tr>
                            <tr><td colspan=2>Address Search</td></tr>
                            <tr><td colspan=2><hr></td></tr>
                            <tr><td>b</td><td>Billing Address</td></tr>
                            <tr><td>a</td><td>Shipping Address</td></tr>
                            <tr><td>z</td><td>Postcode / Zip Code</td></tr>
                            <tr><td colspan=2><hr></td></tr>
                        </table>
                        <button class="button" onclick="$(this).parent().dialog('close');">Close</button>
                    </div>


                    <input name="quick_search" type="text" value="" accesskey="/" />
                    <input type="submit" value="Search" />

                    <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="97489803:bUcl3aYzfz5oeT3co/Fn9Q">


                </form>

                <span class="operator_name">Logged in as: Jason Clifford</span>

                <a href="/My/Messages" class="messages"><img src="/images/icons/email_open.png" width="16" height="16" alt="Messages" title="No New Messages"></a>

                <a href="/Logout">Logout</a>
        </div>

        <select onChange="location.href=this.options[this.selectedIndex].value">
            <option value="">Go to...</option>
            <optgroup label="Management">
                <option value="http://fulcrum.net-a-porter.com/">Fulcrum</option>
            </optgroup>
            <optgroup label="Distribution">
                <option value="http://xtracker.net-a-porter.com">DC1</option>
                <option value="http://xt-us.net-a-porter.com">DC2</option>
                <option value="http://xt-hk.net-a-porter.com">DC3</option>
            </optgroup>
            <optgroup label="Other">
                <option value="http://xt-jchoo.net-a-porter.com">Jimmy Choo</option>
            </optgroup>
        </select>
    </div>

    <div id="headerBottom">
        <img src="/images/model_INTL.jpg" width="157" height="87" alt="">
    </div>

    <script type="text/javascript">
    (function(){
        // Initialize and render the menu bar when it is available in the DOM
        function over_menu(e){
            e = (e) ? e : event;
            var elem = (e.srcElement) ? e.srcElement : e.target
            var parent = elem.parentNode;

            // get parent list item, submenu container and submenu list
            // and return if this isn't a manu item with child lists
            if (elem.tagName != 'A' || parent.tagName != 'LI') return;
            var submenu_container = parent.getElementsByTagName('div')[0];
            if (!submenu_container) return;
            if (!submenu_container.getElementsByTagName('ul')[0]) return;

            // find the position to display the element
            var xy = YAHOO.util.Dom.getXY(parent);

            // hide all other visible menus
            hide_all_menus();

            // make submenu visible
            submenu_container.style.left = (xy[0] - 3) + 'px';
            submenu_container.style.top = (xy[1] + parent.offsetHeight) + 'px';
        }
        function out_menu(e){
            e = (e) ? e : event;
            var elem = (e.srcElement) ? e.srcElement : e.target
            var parent = elem.parentNode;

            // and return if this isn't a manu item with child lists
            if (parent.tagName != 'LI' || !parent.className.match(/yuimenubaritem/)) return;
            var submenu_container = parent.getElementsByTagName('div')[0];
            if (!submenu_container) return;
            if (!submenu_container.getElementsByTagName('ul')[0]) return;

            // return if we're hovering over exposed menu
            var xy = YAHOO.util.Dom.getXY(submenu_container);
            var pointer = mousepos(e);
            var tolerence = 5;
            if (pointer.x > xy[0] && pointer.x < xy[0] + submenu_container.offsetWidth &&
                pointer.y > (xy[1] - tolerence) && pointer.y < xy[1] + submenu_container.offsetHeight) return;

            hide_menu(submenu_container);
        }
        function mousepos(e){
            var pos = {x: 0, y: 0};
            if (e.pageX || e.pageY) {
                pos = {x: e.pageX, y: e.pageY};
            } else if (e.clientX || e.clientY)    {
                pos.x = e.clientX + document.body.scrollLeft + document.documentElement.scrollLeft;
                pos.y = e.clientY + document.body.scrollTop + document.documentElement.scrollTop;
            }
            return pos
        }
        function hide_menu(menu){
            menu.style.left = -9999 + 'px';
            menu.style.top = -9999 + 'px';
        }
        function hide_all_menus(){
            var menu = document.getElementById('nav1').getElementsByTagName('ul')[0].getElementsByTagName('ul');
            for (var i = menu.length - 1; i >= 0; i--){
                hide_menu(menu[i].parentNode.parentNode);
            }
        }

        YAHOO.util.Event.onContentReady("nav1", function () {
            if (YAHOO.env.ua.ie > 5 && YAHOO.env.ua.ie < 7) {
                // YUI menu too slow on thin clients and uses too much memory.
                // Going to have to write my own version for speed.
                // Yes really :-(
                var menu = document.getElementById('nav1').getElementsByTagName('ul')[0];
                if (!menu) return;
                menu.onmouseover = over_menu;
                menu.onmouseout = out_menu;
            } else {
                var oMenuBar = new YAHOO.widget.MenuBar("nav1", { autosubmenudisplay: false, hidedelay: 250, lazyload: true });
                oMenuBar.render();
            }
        });
    })();
</script>
<div id="nav1" class="yuimenubar yuimenubarnav">
        <div class="bd">
            <ul class="first-of-type">
                    <li class="yuimenubaritem first-of-type"><a href="/Home" class="yuimenubaritemlabel">Home</a></li>
                        <li class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Admin</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>
                                            <li class="menuitem">
                                                <a href="/Admin/EmailTemplates" class="yuimenuitemlabel">Email Templates</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Admin/ExchangeRates" class="yuimenuitemlabel">Exchange Rates</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Admin/Printers" class="yuimenuitemlabel">Printers</a>
                                            </li>
                                    </ul>
                                </div>
                            </div>
                        </li>
                        <li class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Customer Care</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>
                                            <li class="menuitem">
                                                <a href="/CustomerCare/CustomerSearch" class="yuimenuitemlabel">Customer Search</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/CustomerCare/OrderSearch" class="yuimenuitemlabel">Order Search</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/CustomerCare/ReturnsPending" class="yuimenuitemlabel">Returns Pending</a>
                                            </li>
                                    </ul>
                                </div>
                            </div>
                        </li>
                        <li class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Finance</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>
                                            <li class="menuitem">
                                                <a href="/Finance/ActiveInvoices" class="yuimenuitemlabel">Active Invoices</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Finance/CreditCheck" class="yuimenuitemlabel">Credit Check</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Finance/CreditHold" class="yuimenuitemlabel">Credit Hold</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Finance/InvalidPayments" class="yuimenuitemlabel">Invalid Payments</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Finance/PendingInvoices" class="yuimenuitemlabel">Pending Invoices</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Finance/TransactionReporting" class="yuimenuitemlabel">Transaction Reporting</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Finance/FraudHotlist" class="yuimenuitemlabel">Fraud Hotlist</a>
                                            </li>
                                    </ul>
                                </div>
                            </div>
                        </li>
                        <li class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Fulfilment</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>
                                            <li class="menuitem">
                                                <a href="/Fulfilment/Airwaybill" class="yuimenuitemlabel">Airwaybill</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Fulfilment/DDU" class="yuimenuitemlabel">DDU</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Fulfilment/Dispatch" class="yuimenuitemlabel">Dispatch</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Fulfilment/InvalidShipments" class="yuimenuitemlabel">Invalid Shipments</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Fulfilment/Labelling" class="yuimenuitemlabel">Labelling</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Fulfilment/Manifest" class="yuimenuitemlabel">Manifest</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Fulfilment/OnHold" class="yuimenuitemlabel">On Hold</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Fulfilment/Packing" class="yuimenuitemlabel">Packing</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Fulfilment/Picking" class="yuimenuitemlabel">Picking</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Fulfilment/Selection" class="yuimenuitemlabel">Selection</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Fulfilment/Pre-OrderHold" class="yuimenuitemlabel">Pre-Order Hold</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Fulfilment/PremierRouting" class="yuimenuitemlabel">Premier Routing</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Fulfilment/PackingException" class="yuimenuitemlabel">Packing Exception</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Fulfilment/Commissioner" class="yuimenuitemlabel">Commissioner</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Fulfilment/PremierDispatch" class="yuimenuitemlabel">Premier Dispatch</a>
                                            </li>
                                    </ul>
                                </div>
                            </div>
                        </li>
                        <li class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Goods In</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>
                                            <li class="menuitem">
                                                <a href="/GoodsIn/StockIn" class="yuimenuitemlabel">Stock In</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/GoodsIn/ItemCount" class="yuimenuitemlabel">Item Count</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/GoodsIn/QualityControl" class="yuimenuitemlabel">Quality Control</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/GoodsIn/BagAndTag" class="yuimenuitemlabel">Bag And Tag</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/GoodsIn/Putaway" class="yuimenuitemlabel">Putaway</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/GoodsIn/ReturnsArrival" class="yuimenuitemlabel">Returns Arrival</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/GoodsIn/ReturnsIn" class="yuimenuitemlabel">Returns In</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/GoodsIn/ReturnsQC" class="yuimenuitemlabel">Returns QC</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/GoodsIn/ReturnsFaulty" class="yuimenuitemlabel">Returns Faulty</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/GoodsIn/Barcode" class="yuimenuitemlabel">Barcode</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/GoodsIn/DeliveryCancel" class="yuimenuitemlabel">Delivery Cancel</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/GoodsIn/DeliveryHold" class="yuimenuitemlabel">Delivery Hold</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/GoodsIn/DeliveryTimetable" class="yuimenuitemlabel">Delivery Timetable</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/GoodsIn/RecentDeliveries" class="yuimenuitemlabel">Recent Deliveries</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/GoodsIn/Surplus" class="yuimenuitemlabel">Surplus</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/GoodsIn/VendorSampleIn" class="yuimenuitemlabel">Vendor Sample In</a>
                                            </li>
                                    </ul>
                                </div>
                            </div>
                        </li>
                        <li class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">NAP Events</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>
                                            <li class="menuitem">
                                                <a href="/NAPEvents/Manage" class="yuimenuitemlabel">Manage</a>
                                            </li>
                                    </ul>
                                </div>
                            </div>
                        </li>
                        <li class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Outnet Events</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>
                                            <li class="menuitem">
                                                <a href="/OutnetEvents/Manage" class="yuimenuitemlabel">Manage</a>
                                            </li>
                                    </ul>
                                </div>
                            </div>
                        </li>
                        <li class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Reporting</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>
                                            <li class="menuitem">
                                                <a href="/Reporting/DistributionReports" class="yuimenuitemlabel">Distribution Reports</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Reporting/ShippingReports" class="yuimenuitemlabel">Shipping Reports</a>
                                            </li>
                                    </ul>
                                </div>
                            </div>
                        </li>
                        <li class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Retail</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>
                                            <li class="menuitem">
                                                <a href="/Retail/AttributeManagement" class="yuimenuitemlabel">Attribute Management</a>
                                            </li>
                                    </ul>
                                </div>
                            </div>
                        </li>
                        <li class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">RTV</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>
                                            <li class="menuitem">
                                                <a href="/RTV/FaultyGI" class="yuimenuitemlabel">Faulty GI</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/RTV/InspectPick" class="yuimenuitemlabel">Inspect Pick</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/RTV/RequestRMA" class="yuimenuitemlabel">Request RMA</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/RTV/ListRMA" class="yuimenuitemlabel">List RMA</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/RTV/ListRTV" class="yuimenuitemlabel">List RTV</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/RTV/PickRTV" class="yuimenuitemlabel">Pick RTV</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/RTV/PackRTV" class="yuimenuitemlabel">Pack RTV</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/RTV/AwaitingDispatch" class="yuimenuitemlabel">Awaiting Dispatch</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/RTV/DispatchedRTV" class="yuimenuitemlabel">Dispatched RTV</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/RTV/NonFaulty" class="yuimenuitemlabel">Non Faulty</a>
                                            </li>
                                    </ul>
                                </div>
                            </div>
                        </li>
                        <li class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Sample</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>
                                            <li class="menuitem">
                                                <a href="/Sample/ReviewRequests" class="yuimenuitemlabel">Review Requests</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Sample/SampleCart" class="yuimenuitemlabel">Sample Cart</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Sample/SampleTransfer" class="yuimenuitemlabel">Sample Transfer</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/Sample/SampleCartUsers" class="yuimenuitemlabel">Sample Cart Users</a>
                                            </li>
                                    </ul>
                                </div>
                            </div>
                        </li>
                        <li class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Stock Control</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>
                                            <li class="menuitem">
                                                <a href="/StockControl/DutyRates" class="yuimenuitemlabel">Duty Rates</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/StockControl/Inventory" class="yuimenuitemlabel">Inventory</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/StockControl/Measurement" class="yuimenuitemlabel">Measurement</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/StockControl/ProductApproval" class="yuimenuitemlabel">Product Approval</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/StockControl/PurchaseOrder" class="yuimenuitemlabel">Purchase Order</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/StockControl/Quarantine" class="yuimenuitemlabel">Quarantine</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/StockControl/Reservation" class="yuimenuitemlabel">Reservation</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/StockControl/Sample" class="yuimenuitemlabel">Sample</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/StockControl/StockCheck" class="yuimenuitemlabel">Stock Check</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/StockControl/ChannelTransfer" class="yuimenuitemlabel">Channel Transfer</a>
                                            </li>
                                    </ul>
                                </div>
                            </div>
                        </li>
                        <li class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Web Content</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>
                                            <li class="menuitem">
                                                <a href="/WebContent/DesignerLanding" class="yuimenuitemlabel">Designer Landing</a>
                                            </li>
                                            <li class="menuitem">
                                                <a href="/WebContent/Magazine" class="yuimenuitemlabel">Magazine</a>
                                            </li>
                                    </ul>
                                </div>
                            </div>
                        </li>
            </ul>
        </div>
</div>

</div>


    <div id="content">
        <div id="contentLeftCol" >
</div>
        <div id="contentRight" >
                    <div id="pageTitle">
                        <h1>Admin</h1>
                        <h5>&bull;</h5><h2>User Roles</h2>
                    </div>
                        <p class="display_msg">Roles Updated</p>
                    <p class="bc-container">
  <ul class="breadcrumb">
  </ul>
</p>
<form method="POST" id="userroles">
<input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="97489803:bUcl3aYzfz5oeT3co/Fn9Q">

<table id="update_roles">
    <tr>
        <th>Available Roles</th>
        <th></th>
        <th>Current Operator Roles</th>
    </tr>
    <tr>
        <td id="available_roles">
            <select id="availableroles" size="30" multiple="multiple">
                <option value="app_canModifyFraudHotlist">app_canModifyFraudHotlist</option>
                <option value="app_testProcess">app_testProcess</option>
                <option value="app_testProcess1">app_testProcess1</option>
                <option value="app_testProcess2">app_testProcess2</option>
            </select>
        </td>
        <td align="center" valign="middle">
            <input id="add" type="button" value="Add to Current Roles --&gt;" /><br />
            <br />
            <input id="remove" type="button" value="&lt;-- Remove from Current Roles" />
        </td>
        <td id="new_roles">
            <select id="newroles" name="newroles" size="30" multiple="multiple">
                <option value="app_canViewFraudHotlist" selected>app_canViewFraudHotlist</option>
                <option value="APP_FIREFOX" selected>APP_FIREFOX</option>
                <option value="app_testing" selected>app_testing</option>
            </select>
        </td>
    </tr>
</table>

<p>To add a new role that is not listed under Available Roles enter the role name (must start with "app_" ): <input type="text" id="newrole"></p>

<input id="userrolessubmit" value="Update My Roles" type="submit">

</form>
        </div>
    </div>

    <p id="footer">    xTracker-DC  (2013.11.00.00.38.gc6e81e0 / IWS phase 2 / PRL phase 0 / 2013-09-02 10:14:50). &copy; 2006 - 2013 NET-A-PORTER
</p>


</div>

    </body>
</html>
