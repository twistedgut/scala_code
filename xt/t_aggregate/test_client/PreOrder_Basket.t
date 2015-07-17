#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

PreOrder_Basket.t

=head1 DESCRIPTION

Tests the contents of the Pre-Order Basket page, URI:

    /StockControl/Reservation/PreOrder/Basket

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/StockControl/Reservation/PreOrder/Basket',
    expected   => {
      pre_order_discount_drop_down => {
        select_name => 'discount_to_apply',
        select_selected => [
          '15',
          '15%'
        ],
        select_values => [
          [
            '0',
            '0%'
          ],
          [
            '5',
            '5%'
          ],
          [
            '10',
            '10%'
          ],
          [
            '15',
            '15%'
          ],
          [
            '20',
            '20%'
          ],
          [
            '25',
            '25%'
          ],
          [
            '30',
            '30%'
          ]
        ],
        value => '0%5%10%15%20%25%30%'
      },
      pre_order_items => [
        {
          Designer => "R\x{e9}publique \x{272a} Ceccarelli",
          DesignerSize => 'None/Unknown',
          Discount => '15.00%',
          Duty => '$3.00',
          Price => '$127.50',
          ProductName => "R\x{e9}publique \x{272a} Ceccarelli - Name",
          SKU => '14-864',
          Tax => '$10.44',
          Total => '$140.94'
        },
        {
          Designer => "R\x{e9}publique \x{272a} Ceccarelli",
          DesignerSize => 'None/Unknown',
          Discount => '15.00%',
          Duty => '$3.00',
          Price => '$170.00',
          ProductName => "R\x{e9}publique \x{272a} Ceccarelli - Name",
          SKU => '15-865',
          Tax => '$13.84',
          Total => '$186.84'
        },
        {
          Designer => "R\x{e9}publique \x{272a} Ceccarelli",
          DesignerSize => 'None/Unknown',
          Discount => '15.00%',
          Duty => '$3.00',
          Price => '$212.50',
          ProductName => "R\x{e9}publique \x{272a} Ceccarelli - Name",
          SKU => '16-863',
          Tax => '$17.24',
          Total => '$232.74'
        }
      ],
      pre_order_original_total => 'without 15.00% discount: $659.44',
      pre_order_total => 'Payment Due: $560.52'
    }
);

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en">
    <head>
        <meta http-equiv="Content-type" content="text/html; charset=utf-8">

        <title>Reservation &#8226; Stock Control &#8226; XT-DC1</title>


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


            <script type="text/javascript" src="/javascript/preorder.js"></script>




        <!-- Custom CSS -->


            <link rel="stylesheet" type="text/css" href="/css/preorder.css">


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











                <form class="quick_search" name="quick_search" method="post" action="/QuickSearch">

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
                                                <a href="/Admin/UserAdmin" class="yuimenuitemlabel">User Admin</a>
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

                                            <li class="menuitem">
                                                <a href="/Reporting/Migration" class="yuimenuitemlabel">Migration</a>
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


        <ul>




                                    <li><a href="/StockControl/Reservation" class="last">Summary</a></li>




                        <li><span>Overview</span></li>


                                    <li><a href="/StockControl/Reservation/Overview?view_type=Upload">Upload</a></li>
                                    <li><a href="/StockControl/Reservation/Overview?view_type=Pending">Pending</a></li>
                                    <li><a href="/StockControl/Reservation/Overview?view_type=Waiting" class="last">Waiting List</a></li>




                        <li><span>View</span></li>


                                    <li><a href="/StockControl/Reservation/Listing?list_type=Live&show=Personal">Live Reservations</a></li>
                                    <li><a href="/StockControl/Reservation/Listing?list_type=Pending&show=Personal">Pending Reservations</a></li>
                                    <li><a href="/StockControl/Reservation/Listing?list_type=Waiting&show=Personal">Waiting Lists</a></li>
                                    <li><a href="/StockControl/Reservation/PreOrder/PreOrderExported" class="last">Pending Pre-Orders</a></li>




                        <li><span>Search</span></li>


                                    <li><a href="/StockControl/Reservation/Product">Product</a></li>
                                    <li><a href="/StockControl/Reservation/Customer">Customer</a></li>
                                    <li><a href="/StockControl/Reservation/PreOrder/PreOrderSearch" class="last">Pre-Order</a></li>




                        <li><span>Email</span></li>


                                    <li><a href="/StockControl/Reservation/Email" class="last">Customer Notification</a></li>




                        <li><span>Reports</span></li>


                                    <li><a href="/StockControl/Reservation/Reports/Uploaded/P">Uploaded</a></li>
                                    <li><a href="/StockControl/Reservation/Reports/Purchased/P" class="last">Purchased</a></li>


        </ul>

</div>




            <img id="channelTitle" src="/images/logo_NET-A-PORTER_INTL.gif" alt="NET-A-PORTER.COM">


        <div id="contentRight" >













                    <div id="pageTitle">
                        <h1>Reservation</h1>
                        <h5>&bull;</h5><h2>Customer</h2>
                        <h5>&bull;</h5><h3>Pre Order Basket</h3>
                    </div>






                    <p class="bc-container">
  <ul class="breadcrumb">


  </ul>
</p>

                    <div id="common__customer_details">
    <h3 class="title-NAP">Customer</h3>
    <b>Name:</b> Test-forename Test-surname<br>
    <b>Number:</b> 31<br>
    <br>
    <hr>
</div>

<div id="basket__page_options_secton">
    <form name="basket__page_options_form" id="basket__page_options_form" action="Basket" method="post">

        <input type="hidden" id="basket__page_options__pre_order_id" name="pre_order_id" value="125">
        <input class="basket__options_form_input" type="hidden" id="basket__page_options__shipment_address_id" name="shipment_address_id" value="104">
        <input class="basket__options_form_input" type="hidden" id="basket__page_options__invoice_address_id" name="invoice_address_id" value="103">
        <input type="hidden" name="reservation_source_id" value="2">

        <input type="hidden" name="variants" value="39">

        <input type="hidden" name="variants" value="43">

        <input type="hidden" name="variants" value="44">

        <div id="basket__shipment_details_box" class="faint_bordered_box">
            <h3 class="title-NAP">Shipment Details</h3>
            <div id="shipment_address__on_screen_text">
                 <b>Address:</b><br>
                Test-forename Test-surname,<br>
                line 1,<br>


                town,<br>
                ddd<br>

                Switzerland<br>
            </div>
            <br>
            <button type="button" id="basket__shipment_address_button" class="button address_popup__shipment_address_button">Use Different Address</button>
            <br>
            <br>
            <strong>Select the shipment option:</strong><br>
            <select class="basket__options_form_input" name="shipment_option_id" id="packaging_type">

                    <option  value="" >Select Shipment option......</option>


                <option  value="58" >European Standard</option>

                <option  value="7" selected="selected">European Express</option>

            </select>
            <br><br>

        </div>
        <div id="basket__invoice_address_box" class="faint_bordered_box">
            <h3 class="title-NAP">Invoice Details</h3>
            <div id="basket__invoice_address">
                <div id="invoice_address__on_screen_text">
                    <b>Address:</b><br>
                    Test-forename Test-surname,<br>
                    line 1,<br>


                    town,<br>
                    ddd<br>

                    Thailand<br>
                </div>
            </div>
            <br>
            <button type="button" id="basket__invoice_address_button" class="button address_popup__invoice_address_button">Use Different Address</button>
            <br>
            <br>
            <strong>Select currency:</strong><br>
            <select class="basket__options_form_input" name="currency_id" id="select_products__currency_dropdown">

                <option value="1" selected="selected">USD</option>

            </select>

                <br><br>
                <strong>Select discount:</strong><br><select name="discount_to_apply" id="discount_to_apply" class="basket__options_form_input">        <option value="0" >0%</option>
                <option value="5" >5%</option>
                <option value="10" >10%</option>
                <option value="15" selected="selected">15%</option>
                <option value="20" >20%</option>
                <option value="25" >25%</option>
                <option value="30" >30%</option>
        </select>

        </div>
        <div id="basket__contact_details_box" class="faint_bordered_box">
            <h3 class="title-NAP">Contact Details</h3>
            <div id="basket__contact_details">
                <strong>Phone day:&nbsp;</strong><br>
                <input type="text" value="" name="telephone_day">
                <br>
                <br>
                <strong>Phone evening:&nbsp;</strong><br>
                <input type="text" value="" name="telephone_eve">
            </div>
            <br>
            <button type="button" id="basket__contact_details_button" class="button">Save Contact Details</button>
        </div>
    </form>
</div>
<hr>
<div id="basket__variants_section">
    <h3 class="title-NAP">Selected Products</h3>
    <div id="basket__variants_table">
        <table class="data wide-data" id="basket__variants_table">
            <thead>
                <tr>
                    <th></th>
                    <th>SKU</th>
                    <th>Product<br>Name</th>
                    <th>Designer</th>
                    <th>Designer<br>Size</th>
                    <th>Discount</th>
                    <th>Price</th>
                    <th>Duty</th>
                    <th>Tax</th>
                    <th>Total</th>
                </tr>
            </thead>
            <tbody>

                <tr class="dividebelow">
                    <td align="center"><img width="50" src="http://cache.net-a-porter.com/images/products/14/14_in_m.jpg"></td>
                    <td>14-864</td>
                    <td>République ✪ Ceccarelli - Name</td>
                    <td>République ✪ Ceccarelli</td>
                    <td>None/Unknown</td>

                    <td>15.00%</td>
                    <td class="item_cost">$127.50</td>
                    <td class="item_cost">$3.00</td>
                    <td class="item_cost">$10.44</td>
                    <td class="item_cost">$140.94</td>

                </tr>

                <tr class="dividebelow">
                    <td align="center"><img width="50" src="http://cache.net-a-porter.com/images/products/15/15_in_m.jpg"></td>
                    <td>15-865</td>
                    <td>République ✪ Ceccarelli - Name</td>
                    <td>République ✪ Ceccarelli</td>
                    <td>None/Unknown</td>

                    <td>15.00%</td>
                    <td class="item_cost">$170.00</td>
                    <td class="item_cost">$3.00</td>
                    <td class="item_cost">$13.84</td>
                    <td class="item_cost">$186.84</td>

                </tr>

                <tr class="dividebelow">
                    <td align="center"><img width="50" src="http://cache.net-a-porter.com/images/products/16/16_in_m.jpg"></td>
                    <td>16-863</td>
                    <td>République ✪ Ceccarelli - Name</td>
                    <td>République ✪ Ceccarelli</td>
                    <td>None/Unknown</td>

                    <td>15.00%</td>
                    <td class="item_cost">$212.50</td>
                    <td class="item_cost">$3.00</td>
                    <td class="item_cost">$17.24</td>
                    <td class="item_cost">$232.74</td>

                </tr>

            </tbody>
        </table>
    </div>
    <br>
    <div id="basket__payment_due_status">
        Payment Due: $560.52
    </div>

        <div id="basket__payment_without_discount" class="payment_without_discount">
            without 15.00% discount: $659.44
        </div>

    <div id="basket__action_forms">
        <div id="basket__confirm_variants_form">
            <form id="basket__complete_pre_order_form" name="basket__complete_pre_order_form" method="post" action="Payment">

                <input type="hidden" name="pre_order_id" value="125">
                <input type="hidden" name="org_telephone_day" value="">
                <input type="hidden" name="org_telephone_eve" value="">
                <input type="hidden" name="shipment_option_id" value="7">
                <button type="button" class="button" id="basket__take_payment_button">Pre Order Items</button>
            </form>
        </div>
        <div id="basket__edit_selection_form">
            <form id="basket__edit_item_selection" name="edit_item_selection" method="post" action="SelectProducts">


                <input type="hidden" name="pre_order_id" value="125">

                <input type="hidden" name="discount_percentage" value="15" />

                <input type="hidden" name="reservation_source_id" value="2">
                <input type="hidden" name="org_telephone_day" value="">
                <input type="hidden" name="org_telephone_eve" value="">
                <input type="hidden" name="shipment_option_id" value="7">
                <input type="hidden" name="currency_id" value="1">


                <input type="hidden" name="variants" value="39">

                <input type="hidden" name="variants" value="43">

                <input type="hidden" name="variants" value="44">


                <button type="button" class="button" id="basket__edit_items_button">Edit Items</button>
            </form>
        </div>
    </div>
</div>
<script language="javascript" type="text/javascript">
    var country_areas  = {};
    var current_county = "";
</script>
<!-- here be popups -->
<div id="popup_address__dialog">

<div id="address_popup__previous_address_section">
    <h3 class="title-NAP">Select  Address</h3>
    <div id="address_popup__previous_address_list">
        <form>
            <table class="wide-data data" name="shipment_address_table" id="shipment_address_table">
                <thead>
                    <tr>
                        <th width="5%"></th>
                        <th width="25%">Name</th>
                        <th width="60%">Address</th>
                        <th width="10%">Country</th>
                    </tr>
                </thead>
                <tbody>

                    <tr class="dividebelow">

                        <td><input  type="radio" id="address_popup__selected_address_id" name="address_id" value="104">
                             <input type="hidden" id="104_str" value="Test-forename,Test-surname
line 1++ddd++Switzerland++">
                        </td>
                        <td>Test-forename Test-surname</td>
                        <td>
                            line 1


                            ,<br>
                            ddd

                        </td>
                        <td>Switzerland</td>
                    </tr>

                    <tr class="dividebelow">

                        <td><input checked="checked" type="radio" id="address_popup__selected_address_id" name="address_id" value="103">
                             <input type="hidden" id="103_str" value="Test-forename,Test-surname
line 1++ddd++Thailand++">
                        </td>
                        <td>Test-forename Test-surname</td>
                        <td>
                            line 1


                            ,<br>
                            ddd

                        </td>
                        <td>Thailand</td>
                    </tr>

                </tbody>
            </table>
        </form>
    </div>


    <div id="address_popup__previous_address_options">
        <input type="checkbox" id="address_popup__select_address_use_for_both" name="use_for_both"> Use for both Shipment and Invoice.
    </div>

    <div id="address_popup__previous_address_buttons">
        <input type="submit" id="address_popup__select_address_cancel_button" class="address_popup__cancel_button button" value="Cancel">
        <input type="submit" id="address_popup__select_address_submit_button" class=" button" value="Select Address">
    </div>
</div>
<hr>


<script>
// Create an array of countries which requires postcode
var postcode_check=new Array();

    postcode_check.push("United States");

    postcode_check.push("United Kingdom");

</script>

<div id="address_popup__new_address_section">
    <h3 class="title-NAP">New  Address</h3>
    <div class="address_popup__new_address_input_fields">
        <input type="hidden" class="new_address__form" id="new_address__pre_order_id" value="125">
        <table class="data wide-data" name="new_address">
            <tr class="dividebelow divideabove">
                <td><p class="new_address__field_required">First Name*</p></td>
                <td><input type="text" class="new_address__form_input" value="Test-forename" id="new_address__first_name" default_value="Test-forename"></td>
            </tr>
            <tr class="dividebelow">
                <td><p class="new_address__field_required">Last Name*</p></td>
                <td><input type="text" class="new_address__form_input" value="Test-surname" id="new_address__last_name" default_value="Test-surname"></td>
            </tr>
            <tr class="dividebelow">
                <td><p class="new_address__field_required">Address Line 1*</p></td>
                <td><input type="text" class="new_address__form_input" value="line 1" id="new_address__address_line_1" default_value="line 1"></td>
            </tr>
            <tr class="dividebelow">
                <td>Address Line 2</td>
                <td><input type="text" class="new_address__form_input" value="" id="new_address__address_line_2" default_value=""></td>
            </tr>
            <tr class="dividebelow">
                <td><p class="new_address__field_required">City*</p></td>
                <td><input type="text" class="new_address__form_input" value="town" id="new_address__towncity" default_value="town"></td>
            </tr>
            <tr class="dividebelow">
                <td>
                    <p class="new_address__field_required">Postcode*</p>
                </td>
                <td><input type="text" class="new_address__form_input" value="ddd" id="new_address__postcode" default_value="ddd"></td>
            </tr>
            <tr class="dividebelow" id="new_address__county_row">
                <td>County</td>
                <td>
                    <select id="new_address__country_area_dropdown" name="county"></select>
                    <input type="text" class="new_address__form_input" value="" id="new_address__county"  default_value="" >
                </td>
            </tr>
            <tr class="dividebelow" id="new_address__state_row">
                <td>State</td>
                <td>
                    <select class="new_address__form_input" id="new_address__us_state"   default_value="">
                        <option id='state_unknown'  value="" >Please Select State</option>

                    </select>
                </td>
            </tr>
            <tr class="dividebelow">
                <td><p class="new_address__field_required">Country*</p></td>
                <td>
                    <select class="new_address__form_input" id="new_address__country" default_value="Switzerland">
                        <option id='country_unknown'  value="" >Please Select Country</option>

                        <option id="116" value="Albania" >Albania</option>

                        <option id="128" value="Algeria" >Algeria</option>

                        <option id="191" value="American Samoa" >American Samoa</option>

                        <option id="114" value="Andorra" >Andorra</option>

                        <option id="1" value="Angola" >Angola</option>

                        <option id="115" value="Anguilla" >Anguilla</option>

                        <option id="2" value="Antigua and Barbuda" >Antigua and Barbuda</option>

                        <option id="3" value="Argentina" >Argentina</option>

                        <option id="190" value="Armenia" >Armenia</option>

                        <option id="118" value="Aruba" >Aruba</option>

                        <option id="4" value="Australia" >Australia</option>

                        <option id="5" value="Austria" >Austria</option>

                        <option id="178" value="Azerbaijan" >Azerbaijan</option>

                        <option id="6" value="Bahamas" >Bahamas</option>

                        <option id="7" value="Bahrain" >Bahrain</option>

                        <option id="119" value="Bangladesh" >Bangladesh</option>

                        <option id="101" value="Barbados" >Barbados</option>

                        <option id="184" value="Belarus" >Belarus</option>

                        <option id="8" value="Belgium" >Belgium</option>

                        <option id="123" value="Belize" >Belize</option>

                        <option id="9" value="Bermuda" >Bermuda</option>

                        <option id="121" value="Bhutan" >Bhutan</option>

                        <option id="120" value="Bolivia" >Bolivia</option>

                        <option id="10" value="Bosnia-Herzegovina" >Bosnia-Herzegovina</option>

                        <option id="122" value="Botswana" >Botswana</option>

                        <option id="11" value="Brazil" >Brazil</option>

                        <option id="12" value="British Virgin Islands" >British Virgin Islands</option>

                        <option id="13" value="Brunei" >Brunei</option>

                        <option id="14" value="Bulgaria" >Bulgaria</option>

                        <option id="141" value="Cambodia" >Cambodia</option>

                        <option id="15" value="Cameroon" >Cameroon</option>

                        <option id="16" value="Canada" >Canada</option>

                        <option id="100" value="Canary Islands" >Canary Islands</option>

                        <option id="126" value="Cape Verde Islands" >Cape Verde Islands</option>

                        <option id="17" value="Cayman Islands" >Cayman Islands</option>

                        <option id="18" value="Chile" >Chile</option>

                        <option id="19" value="China" >China</option>

                        <option id="125" value="Colombia" >Colombia</option>

                        <option id="142" value="Comoros Islands" >Comoros Islands</option>

                        <option id="124" value="Cook Islands" >Cook Islands</option>

                        <option id="110" value="Costa Rica" >Costa Rica</option>

                        <option id="20" value="Croatia" >Croatia</option>

                        <option id="91" value="Cyprus" >Cyprus</option>

                        <option id="22" value="Czech Republic" >Czech Republic</option>

                        <option id="23" value="Denmark" >Denmark</option>

                        <option id="127" value="Dominica" >Dominica</option>

                        <option id="24" value="Dominican Republic" >Dominican Republic</option>

                        <option id="167" value="East Timor" >East Timor</option>

                        <option id="129" value="Ecuador" >Ecuador</option>

                        <option id="25" value="Egypt" >Egypt</option>

                        <option id="163" value="El Salvador" >El Salvador</option>

                        <option id="26" value="Estonia" >Estonia</option>

                        <option id="187" value="Ethiopia" >Ethiopia</option>

                        <option id="131" value="Falkland Islands" >Falkland Islands</option>

                        <option id="132" value="Faroe Islands" >Faroe Islands</option>

                        <option id="192" value="Federated States of Micronesia" >Federated States of Micronesia</option>

                        <option id="130" value="Fiji" >Fiji</option>

                        <option id="27" value="Finland" >Finland</option>

                        <option id="28" value="France" >France</option>

                        <option id="135" value="French Guiana" >French Guiana</option>

                        <option id="112" value="French Polynesia" >French Polynesia</option>

                        <option id="133" value="Gabon" >Gabon</option>

                        <option id="136" value="Gambia" >Gambia</option>

                        <option id="111" value="Georgia" >Georgia</option>

                        <option id="29" value="Germany" >Germany</option>

                        <option id="180" value="Ghana" >Ghana</option>

                        <option id="108" value="Gibraltar" >Gibraltar</option>

                        <option id="30" value="Greece" >Greece</option>

                        <option id="31" value="Greenland" >Greenland</option>

                        <option id="134" value="Grenada" >Grenada</option>

                        <option id="32" value="Guadeloupe" >Guadeloupe</option>

                        <option id="138" value="Guam" >Guam</option>

                        <option id="137" value="Guatemala" >Guatemala</option>

                        <option id="182" value="Guernsey" >Guernsey</option>

                        <option id="104" value="Guyana" >Guyana</option>

                        <option id="189" value="Haiti" >Haiti</option>

                        <option id="139" value="Honduras" >Honduras</option>

                        <option id="33" value="Hong Kong" >Hong Kong</option>

                        <option id="34" value="Hungary" >Hungary</option>

                        <option id="35" value="Iceland" >Iceland</option>

                        <option id="36" value="India" >India</option>

                        <option id="37" value="Indonesia" >Indonesia</option>

                        <option id="38" value="Ireland" >Ireland</option>

                        <option id="39" value="Israel" >Israel</option>

                        <option id="40" value="Italy" >Italy</option>

                        <option id="140" value="Jamaica" >Jamaica</option>

                        <option id="41" value="Japan" >Japan</option>

                        <option id="181" value="Jersey" >Jersey</option>

                        <option id="42" value="Jordan" >Jordan</option>

                        <option id="105" value="Kazakhstan" >Kazakhstan</option>

                        <option id="107" value="Kenya" >Kenya</option>

                        <option id="45" value="Kuwait" >Kuwait</option>

                        <option id="144" value="Laos" >Laos</option>

                        <option id="46" value="Latvia" >Latvia</option>

                        <option id="47" value="Lebanon" >Lebanon</option>

                        <option id="146" value="Lesotho" >Lesotho</option>

                        <option id="48" value="Liberia" >Liberia</option>

                        <option id="96" value="Liechtenstein" >Liechtenstein</option>

                        <option id="49" value="Lithuania" >Lithuania</option>

                        <option id="50" value="Luxembourg" >Luxembourg</option>

                        <option id="94" value="Macau" >Macau</option>

                        <option id="51" value="Macedonia" >Macedonia</option>

                        <option id="93" value="Madagascar" >Madagascar</option>

                        <option id="151" value="Malawi" >Malawi</option>

                        <option id="52" value="Malaysia" >Malaysia</option>

                        <option id="150" value="Maldives" >Maldives</option>

                        <option id="53" value="Malta" >Malta</option>

                        <option id="193" value="Marshall Islands" >Marshall Islands</option>

                        <option id="148" value="Martinique" >Martinique</option>

                        <option id="106" value="Mauritius" >Mauritius</option>

                        <option id="54" value="Mexico" >Mexico</option>

                        <option id="55" value="Moldova" >Moldova</option>

                        <option id="56" value="Monaco" >Monaco</option>

                        <option id="147" value="Mongolia" >Mongolia</option>

                        <option id="186" value="Montenegro" >Montenegro</option>

                        <option id="149" value="Montserrat" >Montserrat</option>

                        <option id="102" value="Morocco" >Morocco</option>

                        <option id="97" value="Mozambique" >Mozambique</option>

                        <option id="152" value="Namibia" >Namibia</option>

                        <option id="154" value="Nepal" >Nepal</option>

                        <option id="83" value="Netherlands" >Netherlands</option>

                        <option id="117" value="Netherlands Antilles" >Netherlands Antilles</option>

                        <option id="98" value="New Caledonia" >New Caledonia</option>

                        <option id="57" value="New Zealand" >New Zealand</option>

                        <option id="153" value="Nicaragua" >Nicaragua</option>

                        <option id="43" value="North Korea" >North Korea</option>

                        <option id="59" value="Norway" >Norway</option>

                        <option id="60" value="Oman" >Oman</option>

                        <option id="61" value="Pakistan" >Pakistan</option>

                        <option id="194" value="Palau" >Palau</option>

                        <option id="155" value="Panama" >Panama</option>

                        <option id="156" value="Papua New Guinea" >Papua New Guinea</option>

                        <option id="157" value="Paraguay" >Paraguay</option>

                        <option id="103" value="Peru" >Peru</option>

                        <option id="62" value="Philippines" >Philippines</option>

                        <option id="63" value="Poland" >Poland</option>

                        <option id="64" value="Portugal" >Portugal</option>

                        <option id="65" value="Puerto Rico" >Puerto Rico</option>

                        <option id="66" value="Qatar" >Qatar</option>

                        <option id="195" value="Reunion Island" >Reunion Island</option>

                        <option id="67" value="Romania" >Romania</option>

                        <option id="68" value="Russia" >Russia</option>

                        <option id="143" value="Saint Kitts and Nevis" >Saint Kitts and Nevis</option>

                        <option id="145" value="Saint Lucia" >Saint Lucia</option>

                        <option id="172" value="Saint Vincent and the Grenadines" >Saint Vincent and the Grenadines</option>

                        <option id="177" value="Saipan" >Saipan</option>

                        <option id="174" value="Samoa" >Samoa</option>

                        <option id="69" value="San Marino" >San Marino</option>

                        <option id="162" value="Sao Tome and Principe" >Sao Tome and Principe</option>

                        <option id="70" value="Saudi Arabia" >Saudi Arabia</option>

                        <option id="71" value="Senegal" >Senegal</option>

                        <option id="185" value="Serbia" >Serbia</option>

                        <option id="159" value="Seychelles" >Seychelles</option>

                        <option id="160" value="Sierra Leone" >Sierra Leone</option>

                        <option id="73" value="Singapore" >Singapore</option>

                        <option id="74" value="Slovakia" >Slovakia</option>

                        <option id="75" value="Slovenia" >Slovenia</option>

                        <option id="196" value="Solomon Islands" >Solomon Islands</option>

                        <option id="76" value="South Africa" >South Africa</option>

                        <option id="44" value="South Korea" >South Korea</option>

                        <option id="77" value="Spain" >Spain</option>

                        <option id="78" value="Sri Lanka" >Sri Lanka</option>

                        <option id="175" value="St Barthelemy" >St Barthelemy</option>

                        <option id="161" value="Suriname" >Suriname</option>

                        <option id="164" value="Swaziland" >Swaziland</option>

                        <option id="79" value="Sweden" >Sweden</option>

                        <option id="80" value="Switzerland"  selected >Switzerland</option>

                        <option id="188" value="Syria" >Syria</option>

                        <option id="81" value="Taiwan ROC" >Taiwan ROC</option>

                        <option id="171" value="Tanzania" >Tanzania</option>

                        <option id="82" value="Thailand" >Thailand</option>

                        <option id="166" value="Togo" >Togo</option>

                        <option id="168" value="Tonga" >Tonga</option>

                        <option id="169" value="Trinidad and Tobago" >Trinidad and Tobago</option>

                        <option id="95" value="Tunisia" >Tunisia</option>

                        <option id="84" value="Turkey" >Turkey</option>

                        <option id="165" value="Turks and Caicos Islands" >Turks and Caicos Islands</option>

                        <option id="170" value="Tuvalu" >Tuvalu</option>

                        <option id="197" value="Uganda" >Uganda</option>

                        <option id="85" value="Ukraine" >Ukraine</option>

                        <option id="86" value="United Arab Emirates" >United Arab Emirates</option>

                        <option id="87" value="United Kingdom" >United Kingdom</option>

                        <option id="88" value="United States" >United States</option>

                        <option id="92" value="Uruguay" >Uruguay</option>

                        <option id="109" value="US Virgin Islands" >US Virgin Islands</option>

                        <option id="173" value="Vanuatu" >Vanuatu</option>

                        <option id="89" value="Venezuela" >Venezuela</option>

                        <option id="99" value="Vietnam" >Vietnam</option>

                        <option id="176" value="Yemen" >Yemen</option>

                    </select>
                </td>
            </tr>
        </table>
        <p>
        * These fields are required
        </p>
    </div>


    <div id="address_popup__new_address_options">
        <input type="checkbox" class="new_address__form" id="new_address__use_for_both"> Use for both Shipment and Invoice.
    </div>

    <div id="address_popup__new_address_buttons">
        <input type="submit" id="address_popup__new_address_reset_button" class="button" value="Reset">
        <input type="submit" id="address_popup__new_address_cancel_button" class="address_popup__cancel_button button" value="Cancel">
        <input type="submit" id="address_popup__new_address_save_button" class="button" value="Add New Address">
    </div>
</div>

</div>
<div id="basket__updating_basket_dialog">
    <img class="bigrotation_icon" src="/images/bigrotation2.gif" align="center"><br>
    Updating Basket
</div>
<!-- here be no popups -->





        </div>
    </div>

    <p id="footer">    xTracker-DC  (2014.07.00.25.g5c4075e / IWS phase 2 / PRL phase 0 / ). &copy; 2006 - 2014 NET-A-PORTER

</p>


</div>

    </body>
</html>
