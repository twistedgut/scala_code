#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;
no utf8;

=head1 NAME

CustomerCare_CheckPricing.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /CustomerCare/OrderSearch/ChangeCountryPricing

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    # Note: example HTML doesn't contain all possible options
    content    => (join '', (<DATA>)),
    uri        => '/CustomerCare/OrderSearch/ChangeCountryPricing?order_id=22&action=Check&shipment_id=11',
    expected   => {
           email_form       => {
                                 "Email Text" => {
                                   input_name => "email_content_type",
                                   input_value => "text",
                                   value => "Dear some, Thank you for shopping at NET-A-PORTER.COM. We have calculated the new costs in shipping your order to Mexico. Due to this change to the shipping destination, the total cost of your order has now increased, as itemized below: Previous Order Cost: GBP 110.00 Updated Order Cost for shipping to Mexico: GBP 120.00 Additional Charge: GBP 10.00 In order to dispatch your order, please authorize us to deduct the additional amount from the credit card used to make this purchase. Should you wish to use an alternative credit card, please let us know. Please be aware that any change to the shipping destination may require your order to undergo additional security checks which may result in delays to the delivery of your order. We look forward to hearing from you. Kind regards, Customer Care www.net-a-porter.com",
                                 },
                                 "From" => {
                                   input_name => "email_from",
                                   input_value => "customercare\@net-a-porter.com",
                                   value => "",
                                 },
                                 "Reply-To" => {
                                   input_name => "email_replyto",
                                   input_value => "customercare\@net-a-porter.com",
                                   value => "",
                                 },
                                 "Send Email" => { input_name => "send_email", input_value => "yes", value => "Yes No" },
                                 "Subject" => {
                                   input_name => "email_subject",
                                   input_value => "Your order - 1000000021",
                                   value => "",
                                 },
                                 "To" => {
                                   input_name => "email_to",
                                   input_value => "test.suite\@xtracker",
                                   value => "",
                                 },
                               },
           item_list        => {
                                 items => [
                                   {
                                     "Current Pricing_Duty" => "0.00",
                                     "Current Pricing_Price" => "100.00",
                                     "Current Pricing_Tax" => "0.00",
                                     "Designer" => "R\xc3\xa9publique \xe2\x9c\xaa Ceccarelli",
                                     "Name" => "Name",
                                     "New Pricing_Duty" => "0.00",
                                     "New Pricing_Price" => "100.00",
                                     "New Pricing_Tax" => "0.00",
                                     "PID" => "1-863",
                                     "Promotion" => "-",
                                     "restriction" => "Chinese origin product",
                                   },
                                 ],
                                 shipping_charge => { current_price => "10.00", new_price => "20.00" },
                               },
           shipment_details => {
                                 "Customer"              => "some one",
                                 "Order Number"          => '1000000021',
                                 "Shipment Number"       => '11',
                                 "Shipping Country"      => "United Kingdom",
                                 "Shipping State/County" => "",
                               },
    },
);

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en">
    <head>
        <meta http-equiv="Content-type" content="text/html; charset=utf-8">

        <title>Order Search &#8226; Customer Care &#8226; XT-DC1</title>


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





        <!-- Custom CSS -->

            <link rel="stylesheet" type="text/css" href="/css/shipping_restrictions.css">


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

                    <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="827%3AdDzS4Vb6xDeO4fA2oi5qmQ">


                </form>


                <span class="operator_name">Logged in as: Andrew Beech</span>

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

        <div id="contentLeftCol">


        <ul>





                    <li><a href="/CustomerCare/OrderSearch/OrderView?order_id=22" class="last">Back</a></li>


        </ul>

</div>



            <img id="channelTitle" src="/images/logo_NET-A-PORTER_INTL.gif" alt="NET-A-PORTER.COM">


        <div id="contentRight">













                    <div id="pageTitle">
                        <h1>Customer Care</h1>
                        <h5>&bull;</h5><h2>Order Search</h2>
                        <h5>&bull;</h5><h3>Check Country Pricing</h3>
                    </div>






                    <p class="bc-container">
  <ul class="breadcrumb">


  </ul>
</p>



    <span class="title title-NAP">Shipment Details</span><br>

    <table id="shipment_details" width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
            <tr>
                    <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
            <tr>
                    <td width="20%" align="right"><b>Shipment Number:&nbsp;&nbsp;</td>
                    <td width="80%">&nbsp;11</td>
            </tr>
            <tr>
                    <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
            <tr>
                    <td width="20%" align="right"><b>Order Number:&nbsp;&nbsp;</td>
                    <td width="80%">&nbsp;1000000021</td>
            </tr>
            <tr>
                    <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
            <tr>
                    <td width="20%" align="right"><b>Customer:&nbsp;&nbsp;</td>
                    <td width="80%">&nbsp;some&nbsp;one</td>
            </tr>
            <tr>
                    <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
            <tr>
                    <td width="20%" align="right"><b>Shipping State/County:&nbsp;&nbsp;</td>
                    <td width="80%">&nbsp;</td>
            </tr>
            <tr>
                    <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
            <tr>
                    <td width="20%" align="right"><b>Shipping Country:&nbsp;&nbsp;</td>
                    <td width="80%">&nbsp;United Kingdom</td>
            </tr>
            <tr>
                    <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
    </table>
    <br><br>


        <form name="newDestination" action="/CustomerCare/OrderSearch/ChangeCountryPricing?order_id=22&shipment_id=11&action=Check" method="post">
            <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="827%3AdDzS4Vb6xDeO4fA2oi5qmQ">

        <span class="title title-NAP">Select New Shipping Destination</span><br>
        <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
            <tr>
                <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
            <tr>
                <td width="20%" align="right"><b>State/County:&nbsp;&nbsp;</td>
                <td width="80%">&nbsp;&nbsp;<input type="text" size="30" name="county" value=""></td>
            </tr>
            <tr>
                <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
            <tr>
                <td width="20%" align="right"><b>Country:&nbsp;&nbsp;</td>
                <td width="80%">&nbsp;
                <select name="country">
                    <option value="0">------------</option>

                        <option value="Albania" >Albania</option>

                        <option value="Algeria" >Algeria</option>

                        <option value="American Samoa" >American Samoa</option>

                        <option value="Andorra" >Andorra</option>

                        <option value="Angola" >Angola</option>

                        <option value="Anguilla" >Anguilla</option>

                        <option value="Antigua and Barbuda" >Antigua and Barbuda</option>

                        <option value="Argentina" >Argentina</option>

                        <option value="Armenia" >Armenia</option>

                        <option value="Aruba" >Aruba</option>

                        <option value="Australia" >Australia</option>

                        <option value="Austria" >Austria</option>

                        <option value="Azerbaijan" >Azerbaijan</option>

                        <option value="Bahamas" >Bahamas</option>

                        <option value="Bahrain" >Bahrain</option>

                        <option value="Bangladesh" >Bangladesh</option>

                        <option value="Barbados" >Barbados</option>

                        <option value="Belarus" >Belarus</option>

                        <option value="Belgium" >Belgium</option>

                        <option value="Belize" >Belize</option>

                        <option value="Bermuda" >Bermuda</option>

                        <option value="Bhutan" >Bhutan</option>

                        <option value="Bolivia" >Bolivia</option>

                        <option value="Bosnia-Herzegovina" >Bosnia-Herzegovina</option>

                        <option value="Botswana" >Botswana</option>

                        <option value="Brazil" >Brazil</option>

                        <option value="British Virgin Islands" >British Virgin Islands</option>

                        <option value="Brunei" >Brunei</option>

                        <option value="Bulgaria" >Bulgaria</option>

                        <option value="Cambodia" >Cambodia</option>

                        <option value="Cameroon" >Cameroon</option>

                        <option value="Canada" >Canada</option>

                        <option value="Canary Islands" >Canary Islands</option>

                        <option value="Cape Verde Islands" >Cape Verde Islands</option>

                        <option value="Cayman Islands" >Cayman Islands</option>

                        <option value="Chile" >Chile</option>

                        <option value="China" >China</option>

                        <option value="Colombia" >Colombia</option>

                        <option value="Comoros Islands" >Comoros Islands</option>

                        <option value="Cook Islands" >Cook Islands</option>

                        <option value="Costa Rica" >Costa Rica</option>

                        <option value="Croatia" >Croatia</option>

                        <option value="Cyprus" >Cyprus</option>

                        <option value="Czech Republic" >Czech Republic</option>

                        <option value="Denmark" >Denmark</option>

                        <option value="Dominica" >Dominica</option>

                        <option value="Dominican Republic" >Dominican Republic</option>

                        <option value="East Timor" >East Timor</option>

                        <option value="Ecuador" >Ecuador</option>

                        <option value="Egypt" >Egypt</option>

                        <option value="El Salvador" >El Salvador</option>

                        <option value="Estonia" >Estonia</option>

                        <option value="Ethiopia" >Ethiopia</option>

                        <option value="Falkland Islands" >Falkland Islands</option>

                        <option value="Faroe Islands" >Faroe Islands</option>

                        <option value="Federated States of Micronesia" >Federated States of Micronesia</option>

                        <option value="Fiji" >Fiji</option>

                        <option value="Finland" >Finland</option>

                        <option value="France" >France</option>

                        <option value="French Guiana" >French Guiana</option>

                        <option value="French Polynesia" >French Polynesia</option>

                        <option value="Gabon" >Gabon</option>

                        <option value="Gambia" >Gambia</option>

                        <option value="Georgia" >Georgia</option>

                        <option value="Germany" >Germany</option>

                        <option value="Ghana" >Ghana</option>

                        <option value="Gibraltar" >Gibraltar</option>

                        <option value="Greece" >Greece</option>

                        <option value="Greenland" >Greenland</option>

                        <option value="Grenada" >Grenada</option>

                        <option value="Guadeloupe" >Guadeloupe</option>

                        <option value="Guam" >Guam</option>

                        <option value="Guatemala" >Guatemala</option>

                        <option value="Guernsey" >Guernsey</option>

                        <option value="Guyana" >Guyana</option>

                        <option value="Haiti" >Haiti</option>

                        <option value="Honduras" >Honduras</option>

                        <option value="Hong Kong" >Hong Kong</option>

                        <option value="Hungary" >Hungary</option>

                        <option value="Iceland" >Iceland</option>

                        <option value="India" >India</option>

                        <option value="Indonesia" >Indonesia</option>

                        <option value="Ireland" >Ireland</option>

                        <option value="Israel" >Israel</option>

                        <option value="Italy" >Italy</option>

                        <option value="Jamaica" >Jamaica</option>

                        <option value="Japan" >Japan</option>

                        <option value="Jersey" >Jersey</option>

                        <option value="Jordan" >Jordan</option>

                        <option value="Kazakhstan" >Kazakhstan</option>

                        <option value="Kenya" >Kenya</option>

                        <option value="Kuwait" >Kuwait</option>

                        <option value="Laos" >Laos</option>

                        <option value="Latvia" >Latvia</option>

                        <option value="Lebanon" >Lebanon</option>

                        <option value="Lesotho" >Lesotho</option>

                        <option value="Liberia" >Liberia</option>

                        <option value="Liechtenstein" >Liechtenstein</option>

                        <option value="Lithuania" >Lithuania</option>

                        <option value="Luxembourg" >Luxembourg</option>

                        <option value="Macau" >Macau</option>

                        <option value="Macedonia" >Macedonia</option>

                        <option value="Madagascar" >Madagascar</option>

                        <option value="Malawi" >Malawi</option>

                        <option value="Malaysia" >Malaysia</option>

                        <option value="Maldives" >Maldives</option>

                        <option value="Malta" >Malta</option>

                        <option value="Marshall Islands" >Marshall Islands</option>

                        <option value="Martinique" >Martinique</option>

                        <option value="Mauritius" >Mauritius</option>

                        <option value="Mexico" selected>Mexico</option>

                        <option value="Moldova" >Moldova</option>

                        <option value="Monaco" >Monaco</option>

                        <option value="Mongolia" >Mongolia</option>

                        <option value="Montenegro" >Montenegro</option>

                        <option value="Montserrat" >Montserrat</option>

                        <option value="Morocco" >Morocco</option>

                        <option value="Mozambique" >Mozambique</option>

                        <option value="Namibia" >Namibia</option>

                        <option value="Nepal" >Nepal</option>

                        <option value="Netherlands" >Netherlands</option>

                        <option value="Netherlands Antilles" >Netherlands Antilles</option>

                        <option value="New Caledonia" >New Caledonia</option>

                        <option value="New Zealand" >New Zealand</option>

                        <option value="Nicaragua" >Nicaragua</option>

                        <option value="North Korea" >North Korea</option>

                        <option value="Norway" >Norway</option>

                        <option value="Oman" >Oman</option>

                        <option value="Pakistan" >Pakistan</option>

                        <option value="Palau" >Palau</option>

                        <option value="Panama" >Panama</option>

                        <option value="Papua New Guinea" >Papua New Guinea</option>

                        <option value="Paraguay" >Paraguay</option>

                        <option value="Peru" >Peru</option>

                        <option value="Philippines" >Philippines</option>

                        <option value="Poland" >Poland</option>

                        <option value="Portugal" >Portugal</option>

                        <option value="Puerto Rico" >Puerto Rico</option>

                        <option value="Qatar" >Qatar</option>

                        <option value="Reunion Island" >Reunion Island</option>

                        <option value="Romania" >Romania</option>

                        <option value="Russia" >Russia</option>

                        <option value="Saint Kitts and Nevis" >Saint Kitts and Nevis</option>

                        <option value="Saint Lucia" >Saint Lucia</option>

                        <option value="Saint Vincent and the Grenadines" >Saint Vincent and the Grenadines</option>

                        <option value="Saipan" >Saipan</option>

                        <option value="Samoa" >Samoa</option>

                        <option value="San Marino" >San Marino</option>

                        <option value="Sao Tome and Principe" >Sao Tome and Principe</option>

                        <option value="Saudi Arabia" >Saudi Arabia</option>

                        <option value="Senegal" >Senegal</option>

                        <option value="Serbia" >Serbia</option>

                        <option value="Seychelles" >Seychelles</option>

                        <option value="Sierra Leone" >Sierra Leone</option>

                        <option value="Singapore" >Singapore</option>

                        <option value="Slovakia" >Slovakia</option>

                        <option value="Slovenia" >Slovenia</option>

                        <option value="Solomon Islands" >Solomon Islands</option>

                        <option value="South Africa" >South Africa</option>

                        <option value="South Korea" >South Korea</option>

                        <option value="Spain" >Spain</option>

                        <option value="Sri Lanka" >Sri Lanka</option>

                        <option value="St Barthelemy" >St Barthelemy</option>

                        <option value="Suriname" >Suriname</option>

                        <option value="Swaziland" >Swaziland</option>

                        <option value="Sweden" >Sweden</option>

                        <option value="Switzerland" >Switzerland</option>

                        <option value="Syria" >Syria</option>

                        <option value="Taiwan ROC" >Taiwan ROC</option>

                        <option value="Tanzania" >Tanzania</option>

                        <option value="Thailand" >Thailand</option>

                        <option value="Togo" >Togo</option>

                        <option value="Tonga" >Tonga</option>

                        <option value="Trinidad and Tobago" >Trinidad and Tobago</option>

                        <option value="Tunisia" >Tunisia</option>

                        <option value="Turkey" >Turkey</option>

                        <option value="Turks and Caicos Islands" >Turks and Caicos Islands</option>

                        <option value="Tuvalu" >Tuvalu</option>

                        <option value="Uganda" >Uganda</option>

                        <option value="Ukraine" >Ukraine</option>

                        <option value="United Arab Emirates" >United Arab Emirates</option>

                        <option value="United Kingdom" >United Kingdom</option>

                        <option value="United States" >United States</option>

                        <option value="Unknown" >Unknown</option>

                        <option value="Uruguay" >Uruguay</option>

                        <option value="US Virgin Islands" >US Virgin Islands</option>

                        <option value="Vanuatu" >Vanuatu</option>

                        <option value="Venezuela" >Venezuela</option>

                        <option value="Vietnam" >Vietnam</option>

                        <option value="Yemen" >Yemen</option>

                </select>
                </td>
            </tr>
            <tr>
                <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
            <tr>
                <td colspan="2" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
            </tr>
            <tr>
                <td colspan="2" align="right" class="blank"><input type="submit" name="submit" value="Check Pricing >" class="button"></td>
            </tr>
        </table>
        </form>
        <br><br>


    <form name="amendPricing" action="/CustomerCare/OrderSearch/ChangeCountryPricing?order_id=22&shipment_id=11&action=Check" method="post">
        <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="827%3AdDzS4Vb6xDeO4fA2oi5qmQ">

        <input type="hidden" name="amend" value="1">

    <span class="title title-NAP">Check Pricing</span><br>
    <table id="list_of_items" width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
        <tr>
            <td colspan="12" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td rowspan="2" class="tableHeader" width="10%">&nbsp;&nbsp;PID</td>
            <td rowspan="2" class="tableHeader" width="20%">Designer</td>
            <td rowspan="2" class="tableHeader" width="20%">Name</td>
            <td rowspan="2" class="tableHeader" width="12%">Promotion</td>
            <td rowspan="2" class="tableHeader" width="2%" style="border-left:1px dotted #999"></td>
            <td colspan="3" class="tableHeader">Current Pricing</td>
            <td rowspan="2" class="tableHeader" width="2%" style="border-left:1px dotted #999"></td>
            <td colspan="3" class="tableHeader">New Pricing</td>
        </tr>
        <tr>
            <td class="tableHeader" width="6%">Price</td>
            <td class="tableHeader" width="6%">Tax</td>
            <td class="tableHeader" width="6%">Duty</td>
            <td class="tableHeader" width="6%">Price</td>
            <td class="tableHeader" width="6%">Tax</td>
            <td class="tableHeader" width="6%">Duty</td>
        </tr>
        <tr>
            <td colspan="12" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>



                <tr>
                    <td>&nbsp;&nbsp;1-863</td>
                    <td>République ✪ Ceccarelli</td>
                    <td>Name</td>
                    <td>-</td>
                    <td style="border-left:1px dotted #999">&nbsp;</td>
                    <td>100.00</td>
                    <td>0.00</td>
                    <td>0.00</td>
                    <td style="border-left:1px dotted #999">&nbsp;</td>
                    <td><input type="hidden" name="price_11" value="100.00">100.00</td>
                    <td><input type="hidden" name="tax_11" value="0.00">0.00</td>
                    <td><input type="hidden" name="duty_11" value="0.00">0.00</td>

                </tr>
                                    <tr id="1-863-restricted" class="restricted_highlight" title="Can't Deliver">
                        <td colspan="4">
                            <img class="inline" style="vertical-align: middle; padding-left: 10px;" src="/images/icons/lorry_error.png">
                            <span style="vertical-align: middle; padding-left: 10px;">Chinese origin product                            </span>
                        </td>
                        <td style="border-left:1px dotted #999">&nbsp;</td>
                        <td colspan="3"></td>
                        <td style="border-left:1px dotted #999">&nbsp;</td>
                        <td colspan="3"></td>
                    </tr>


                <tr>
                    <td colspan="12" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                </tr>


        <tr>
            <td colspan="12" class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td colspan="12" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td>&nbsp;</td>
            <td>&nbsp;</td>
            <td>Shipping Charge</td>
            <td></td>
            <td style="border-left:1px dotted #999">&nbsp;</td>
            <td>10.00</td>
            <td></td>
            <td></td>
            <td style="border-left:1px dotted #999">&nbsp;</td>
            <td>
                    <input type="hidden" size="5" name="shipping" value="20.00">
                    <input type="hidden" size="5" name="diff_shipping" value="-10"><span class="highlight">20.00</td>
            <td></td>
            <td></td>
        </tr>
        <tr>
            <td colspan="12" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td colspan="12" class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td colspan="12" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td class="blank" colspan="2"><img src="/images/blank.gif" width="1" height="24"></td>
            <td colspan="8" class="blank" align="right"><b>Current Total:</td>
            <td class="blank" align="right"><b>110.00</td>
            <td class="blank"><b>&nbsp;&nbsp;GBP</td>
        </tr>
        <tr>
            <td colspan="7" class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="5" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td class="blank" colspan="2"><img src="/images/blank.gif" width="1" height="24"></td>
            <td colspan="8" class="blank" align="right"><b>New Total:</td>
            <td class="blank" align="right"><b>120.00</td>
            <td class="blank"><b>&nbsp;&nbsp;GBP</td>
        </tr>
        <tr>
            <td colspan="7" class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="5" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td class="blank" colspan="2"><img src="/images/blank.gif" width="1" height="24"></td>
            <td colspan="8" class="blank" align="right"><b>Difference:</td>
            <td class="blank" align="right"><b>10.00</td>
            <td class="blank"><b>&nbsp;&nbsp;GBP</td>
        </tr>
        <tr>
            <td colspan="7" class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="5" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>

    </table>
    <br><br>



        <span class="title title-NAP">Customer Email</span><br>
        <table id="customer_email" width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
            <tr>
                <td colspan="2" class="divider"></td>
            </tr>
            <tr height="24">
                <td width="149" align="right"><b>Send Email:</b>&nbsp;&nbsp;</td>
                <td width="570"><input type="radio" name="send_email" value="yes" checked>&nbsp;&nbsp;Yes&nbsp;&nbsp;&nbsp;&nbsp;<input type="radio" name="send_email" value="no">&nbsp;&nbsp;No</td>
            </tr>
            <tr>
                <td colspan="2" class="divider"></td>
            </tr>
            <tr height="30">
                <td align="right"><b>To:</b>&nbsp;&nbsp;</td>
                <td><input type="text" size="35" name="email_to" value="test.suite@xtracker"></td>
            </tr>
            <tr>
                <td colspan="2" class="divider"></td>
            </tr>
            <tr height="30">
                <td align="right"><b>From:</b>&nbsp;&nbsp;</td>
                <td><input type="text" size="35" name="email_from" value="customercare@net-a-porter.com"></td>
            </tr>
            <tr>
                <td colspan="2" class="divider"></td>
            </tr>
            <tr height="30">
                <td align="right"><b>Reply-To:</b>&nbsp;&nbsp;</td>
                <td><input type="text" size="35" name="email_replyto" value="customercare@net-a-porter.com"></td>
            </tr>
            <tr>
                <td colspan="2" class="divider"></td>
            </tr>
            <tr height="30">
                <td align="right"><b>Subject:</b>&nbsp;&nbsp;</td>
                <td><input type="text" size="35" name="email_subject" value="Your order - 1000000021"></td>
            </tr>
            <tr>
                <td colspan="2" class="divider"></td>
            </tr>
            <tr>
                <td colspan="2" height="10"></td>
            </tr>
            <tr valign="top">
                <td align="right"><b>Email Text:&nbsp;&nbsp;</b></td>
                <td>
                    <textarea name="email_body" rows="15" cols="80">Dear some,

Thank you for shopping at NET-A-PORTER.COM.

We have calculated the new costs in shipping your order to Mexico.

Due to this change to the shipping destination, the total cost of your order has now increased, as itemized below:

Previous Order Cost: GBP 110.00
Updated Order Cost for shipping to Mexico: GBP 120.00
Additional Charge: GBP 10.00

In order to dispatch your order, please authorize us to deduct the additional amount from the credit card used to make this purchase. Should you wish to use an alternative credit card, please let us know.

Please be aware that any change to the shipping destination may require your order to undergo additional security checks which may result in delays to the delivery of your order.

We look forward to hearing from you.

Kind regards,

Customer Care
www.net-a-porter.com




</textarea>
                    <input type="hidden" name="email_content_type" value="text"/>
                </td>
            </tr>
            <tr>
                <td colspan="2" height="10"></td>
            </tr>
            <tr>
                <td colspan="2" class="divider"></td>
            </tr>
        </table>
        <br><br>

        <table width="100%" cellpadding="0" cellspacing="0" border="0">
            <tr>
                <td align="right"><input type="submit" name="submit" value="Send Email >" class="button"></td>
            </tr>
        </table>
        <br><br>

    </form>







        </div>
    </div>

    <p id="footer">    xTracker-DC  (2013.03.01.265.ge63981d / IWS phase 2 / PRL phase 0 / 2013-04-03 12:12:50). &copy; 2006 - 2013 NET-A-PORTER
</p>


</div>

    </body>
</html>
