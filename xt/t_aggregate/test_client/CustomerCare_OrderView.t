#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

CustomerCare_OrderView.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /CustomerCare/CustomerSearch/OrderView

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/CustomerCare/CustomerSearch/OrderView?order_id=1592407',
    expected   => {
    'shipment_items' => [
            {
              "Designer"   => "James Perse",
              "Duties"     => "0.00",
              "MD"         => "-",
              "Name"       => "Loose-fit long-sleeve T-shirt",
              "PR"         => "-",
              "Size"       => '1',
              "SKU"        => "41089-024",
              "Status"     => "Cancelled",
              "Sub-Total"  => "100.00",
              "Tax"        => "0.00",
              "Unit Price" => "100.00",
            },
            {
              "Designer"   => "James Perse",
              "Duties"     => "0.00",
              "MD"         => "-",
              "Name"       => "Loose-fit short-sleeve T-shirt",
              "PR"         => "-",
              "Size"       => '1',
              "SKU"        => "41092-024",
              "Status"     => "Selected",
              "Sub-Total"  => "100.00",
              "Tax"        => "0.00",
              "Unit Price" => "100.00",
            },
            {
              "Designer"   => "James Perse",
              "Duties"     => "0.00",
              "MD"         => "-",
              "Name"       => "Loose-fit long-sleeve T-shirt",
              "PR"         => "-",
              "Size"       => '1',
              "SKU"        => "41088-024",
              "Status"     => "Selected",
              "Sub-Total"  => "100.00",
              "Tax"        => "0.00",
              "Unit Price" => "100.00",
            },
            {
              "Designer"   => "James Perse",
              "Duties"     => "0.00",
              "MD"         => "-",
              "Name"       => "Loose-fit long-sleeve T-shirt",
              "PR"         => "-",
              "Size"       => '1',
              "SKU"        => "41087-024",
              "Status"     => "Selected",
              "Sub-Total"  => "100.00",
              "Tax"        => "0.00",
              "Unit Price" => "100.00",
            },
            {
              "Designer"   => "James Perse",
              "Duties"     => "0.00",
              "MD"         => "-",
              "Name"       => "Loose-fit short-sleeve T-shirt",
              "PR"         => "-",
              "Size"       => '1',
              "SKU"        => "41090-024",
              "Status"     => "Selected",
              "Sub-Total"  => "100.00",
              "Tax"        => "0.00",
              "Unit Price" => "100.00",
            },
        ],
    'meta_data' =>
         {
            "Finance Data"     => {
                                    payment_card_details => {
                                        "3D Secure Response"         => "3DSecure is not supported",
                                        "Auth Code"                  => "000001",
                                        "Card Number"                => "9***********8765",
                                        "Card Type"                  => "American Impress",
                                        "CV2 Check"                  => "ALL MATCH",
                                        "Expiry Date"                => "01/01",
                                        "Fulfilled"                  => "No",
                                        "Internal Payment Reference" => "1234-SEEMSNICE",
                                        "IP Address"                 => "-",
                                        "Issuer"                     => "Bank of Gallifrey",
                                        "Issuing Country"            => "United Kingdom",
                                        "PSP"                        => "Provider Inc",
                                        "PSP Reference"              => "1234-HELLOSWEETIE",
                                        "Stored Card"                => "No",
                                        "Valid"                      => "Yes",
                                        "Value"                      => "GBP 9876.54",
                                    },
                                  },
            "Invoice Address"  => {
                                    "Country"        => "United Kingdom",
                                    "County/State"   => "",
                                    "Name"           => "some one",
                                    "Postcode"       => "W11",
                                    "Street Address" => "DC1, Unit 3, Charlton Gate Business Park Anchor and Hope Lane",
                                    "Telephone"      => "telephone",
                                    "Town/City"      => "London",
                                  },
            "Order Details"    => {
                                    "Customer"          => "michael martins",
                                    "Customer Category" => "Promotion",
                                    "Customer Number"   => {
                                                             url => "/CustomerCare/CustomerSearch/CustomerView?customer_id=460370",
                                                             value => '500064780',
                                                           },
                                    "Email"             => "test.suite\@xtracker",
                                    "Order Number"      => '1001592406',
                                    "Order Status"      => "Accepted",
                                    "Placed By"         => "Customer",
                                  },
            "Order Contact Options" => {
                                      "Premier Delivery/Collection Notification" => {
                                        inputs => [
                                          {
                                            input_name => 'csm_subject_1',
                                            input_type => 'hidden',
                                            input_value => '1',
                                            input_readonly => 0,
                                          },
                                          {
                                            input_checked => 1,
                                            input_name => 'csm_subject_method_1',
                                            input_type => 'checkbox',
                                            input_value => '1',
                                            input_readonly => 0,
                                          },
                                          {
                                            input_checked => 1,
                                            input_name => 'csm_subject_method_1',
                                            input_type => 'checkbox',
                                            input_value => '2',
                                            input_readonly => 0,
                                          },
                                          {
                                            input_checked => 0,
                                            input_name => 'csm_subject_method_1',
                                            input_type => 'checkbox',
                                            input_value => '3',
                                            input_readonly => 0,
                                          }
                                        ],
                                        value => 'SMS Email Phone'
                                      }
                                  },
            "Shipment Address" => {
                                    "Country"          => "United Kingdom",
                                    "County/State"     => "",
                                    "Mobile Telephone" => "",
                                    "Name"             => "some one",
                                    "Postcode"         => "W11",
                                    "Street Address"   => "DC1, Unit 3, Charlton Gate Business Park Anchor and Hope Lane LONDON, SE7 7RU",
                                    "Telephone"        => "telephone",
                                    "Town/City"        => "London",
                                  },
            "Shipment Details" => {
                                    "Date" => "28-06-2011 11:25",
                                    "Destination Code" => "LHR",
                                    "Email" => "test.suite\@xtracker",
                                    "Packing Instruction" => "",
                                    "Shipment Class" => "Domestic",
                                    "Shipment Number" => '1715594',
                                    "Shipment Type" => "Standard",
                                    "Shipping Account" => "DHL Express - Domestic",
                                    "Status" => "Hold",
                                  },
            "Shipment Hold"    => {
                                    "Comment"      => "The following items were missing: 41087-024 x 1; 41088-024 x 1; 41089-024 x 1; 41090-024 x 1; 41092-024 x 1",
                                    "Date Held"    => "28-06-2011 12:31",
                                    "Held By"      => "Application",
                                    "Reason"       => "Incomplete Pick",
                                    "Release Date" => "",
                                  },
            shipment_email_log => {
                                      '1715594' => [
                                            {
                                                'Date Sent' => '18-01-2012 10:24',
                                                'Sent By'   => 'Application',
                                                Type        => 'ReturnsQC-SLA-Breach-OUTNET-INTL'
                                            },
                                      ],
                                  },
            return_email_log => {
                                    '1715594' => [
                                        {
                                            'Date Sent' => '18-01-2012 10:24',
                                            RMA => 'R115-135',
                                            'Sent By' => 'Application',
                                            Type => 'Premier - Arrange Delivery'
                                        }
                                    ]
                                },
         },
        voucher_usage_history => [],
    }
);

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en">
    <head>
        <meta http-equiv="Content-type" content="text/html; charset=utf-8">

        <title>Customer Search &#8226; Customer Care &#8226; XT-DC1</title>


        <link rel="shortcut icon" href="/favicon.ico">



        <!-- Core Javascript -->
        <script type="text/javascript" src="/javascript/common.js"></script>
        <script type="text/javascript" src="/javascript/xt_navigation.js"></script>
        <script type="text/javascript" src="/javascript/form_validator.js"></script>
        <script type="text/javascript" src="/javascript/validate.js"></script>
        <script type="text/javascript" src="/javascript/comboselect.js"></script>
        <script type="text/javascript" src="/javascript/date.js"></script>

        <!-- Custom Javascript -->





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

        <!-- Load jQuery -->
        <script type="text/javascript" src="/jquery/jquery-1.4.2.min.js"></script>
        <script type="text/javascript" src="/jquery-ui/js/jquery-ui.custom.min.js"></script>
        <!-- jQuery CSS -->
        <link rel="stylesheet" type="text/css" href="/jquery-ui/css/smoothness/jquery-ui.custom.css">





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
           <img src="/images/logo_small.gif" alt="xTracker">
           <span>DISTRIBUTION</span><span class="dc">DC1</span>
        </div>

            <div id="headerControls">
                Logged in as: <span class="operator_name">Andrew Beech</span>
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
                                                <a href="/Admin/ProductSort" class="yuimenuitemlabel">Product Sort</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/JobQueue" class="yuimenuitemlabel">Job Queue</a>
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
                                                <a href="/Finance/StoreCredits" class="yuimenuitemlabel">Store Credits</a>
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
                                                <a href="/Reporting/StockConsistency" class="yuimenuitemlabel">Stock Consistency</a>
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





                    <li><a href="/CustomerCare/CustomerSearch/">Back</a></li>

                    <li><a href="javascript:void launchPopup('/CustomerCare/CustomerSearch/OrderAccessLog?order_id=1592407');">View Access Log</a></li>

                    <li><a href="/CustomerCare/CustomerSearch/OrderLog?orders_id=1592407" class="last">View Status Log</a></li>




                        <li><span>Order</span></li>



                    <li><a href="/CustomerCare/CustomerSearch/ChangeOrderStatus?order_id=1592407&action=Hold">Credit Hold</a></li>

                    <li><a href="/CustomerCare/CustomerSearch/EditOrder?orders_id=1592407">Edit Order</a></li>

                    <li><a href="/CustomerCare/CustomerSearch/EditAddress?address_type=Billing&order_id=1592407">Edit Billing Address</a></li>

                    <li><a href="/CustomerCare/CustomerSearch/CancelOrder?orders_id=1592407">Cancel Order</a></li>

                    <li><a href="/CustomerCare/CustomerSearch/AuthorisePayment?method=pre&orders_id=1592407">Pre-Authorise Order</a></li>

                    <li><a href="/CustomerCare/CustomerSearch/EditWatch?action=Add&watch_type=Finance&order_id=1592407&customer_id=460370">Add Watch</a></li>

                    <li><a href="/CustomerCare/CustomerSearch/SendEmail?order_id=1592407">Send Email</a></li>

                    <li><a href="/CustomerCare/CustomerSearch/Note?parent_id=1592407&note_category=Order&sub_id=1592407" class="last">Add Note</a></li>




                        <li><span>Customer</span></li>



                    <li><a href="javascript:void window.open('http://eg01-pr-dc1.london.net-a-porter.com/system/web/view/platform/agent/info/custhist/Custom_Customer_history_NAP/getCustomerCaseNap.jsp?email_address=EIc90NE4wQI@gmail.com');" class="last">Contact History</a></li>




                        <li><span>Shipment</span></li>



                    <li><a href="/CustomerCare/CustomerSearch/EditShipment?order_id=1592407&shipment_id=1715594">Edit Shipment</a></li>

                    <li><a href="/CustomerCare/CustomerSearch/EditAddress?address_type=Shipping&order_id=1592407&shipment_id=1715594">Edit Shipping Address</a></li>

                    <li><a href="/CustomerCare/CustomerSearch/HoldShipment?order_id=1592407&shipment_id=1715594">Hold Shipment</a></li>

                    <li><a href="/CustomerCare/CustomerSearch/ChangeCountryPricing?order_id=1592407&action=Check&shipment_id=1715594">Check Pricing</a></li>

                    <li><a href="/CustomerCare/CustomerSearch/Invoice?action=Create&order_id=1592407&shipment_id=1715594">Create Credit/Debit</a></li>

                    <li><a href="/CustomerCare/CustomerSearch/Note?parent_id=1592407&note_category=Shipment&sub_id=1715594" class="last">Add Note</a></li>


        </ul>

</div>



            <img id="channelTitle" src="/images/logo_NET-A-PORTER_INTL.gif" alt="NET-A-PORTER.COM">


        <div id="contentRight">











                    <div id="pageTitle">
                        <h1>Customer Care</h1>
                        <h5>&bull;</h5><h2>Customer Search</h2>
                        <h5>&bull;</h5><h3>Order View</h3>
                    </div>








<script type="text/javascript">
    var can_edit_messages = 0;
$(document).ready(function() {

    $('#edit_sticker').click(function() {
        $('#sticker_input').show();
        $('#sticker_text').hide();
        hide_feedback();
    });

    initialise_sticker_field();

    $('#submit_sticker').click(function() {
        var order_id        = 1592407;
        var sticker_text    = $('#sticker_input_value').val();
        $.ajax({
            url:        '/CustomerCare/Order/UpdateSticker',
            cache:      false,
            data:       {action: 'update', order_id: order_id, sticker_text: sticker_text},
            async:      false,
            dataType:   'json',
            success:    function(json) {
                if (json.status == 'OK') {
                    $('#ajax_feedback').removeClass('error_msg');
                    $('#ajax_feedback').addClass('display_msg');
                    initialise_sticker_field();
                }
                else {
                    $('#ajax_feedback').removeClass('display_msg');
                    $('#ajax_feedback').addClass('error_msg');
                }
                $('.sticker_value').html(sticker_text);
                show_feedback(json.message);
            }
        });
    });


    $('#reprint_sticker').click(function() {
        $('#sticker_select').show();
        $('#sticker_text').hide();
        alert("Select the correct printer then press the printer again to print");
    });


    $('#print_sticker').click(function(){
        toggle_print_spinner(true);
        setTimeout("print_sticker()",1000);
    });

});
    // THIS NEEDS TO BE OUTSIDE DOCUMENT>READY
    function show_feedback(feedback){
        $('#ajax_feedback').html(feedback);
        $('#ajax_feedback').show();
    }

    function initialise_sticker_field(){
        $('#sticker_select').hide();
        $('#sticker_input').hide();
        $('#sticker_text').show();
        hide_feedback();
    }

    function hide_feedback(){
        $('#ajax_feedback').html('');
        $('#ajax_feedback').hide();
    }

    function toggle_print_spinner(truth){
        if(truth==true){
            $('#print_sticker').attr("src","/images/ajax-loader.gif");
        }else{
            $('#print_sticker').attr("src","/images/icons/printer.png");
        }
    }

    function print_sticker(){
        var order_id        = 1592407;
        var packing_printer_value = $('#packing_printer').val();
        if(packing_printer_value.match(/^\w+/)){
            $.ajax({
                url:        '/CustomerCare/Order/ReprintSticker',
                cache:      false,
                data:       {order_id: order_id, packing_printer: packing_printer_value },
                async:      false,
                dataType:   'json',
                success:    function(json) {
                    if (json.status == 'SUCCESS') {
                        $('#ajax_feedback').removeClass('error_msg');
                        $('#ajax_feedback').addClass('display_msg');
                        initialise_sticker_field();
                    }
                    else {
                        $('#ajax_feedback').removeClass('display_msg');
                        $('#ajax_feedback').addClass('error_msg');
                    }
                    show_feedback(json.message);
                },
                complete:  function(){
                    toggle_print_spinner(false);
                }
            });
        }else{
            toggle_print_spinner(false);
            alert("Please select a valid printer");
        }
    };
</script>
<script type="text/javascript" src="/javascript/order_view.js"></script>

<span id="ajax_feedback" style="display:none;"></span><br><br>



<table width="100%" cellpadding="0" cellspacing="0" border="0" id="order_details__invoice_address">
    <tr>
        <td colspan="2"><h3 class="title-NAP">Order Details</h3></td>
        <td><img src="/images/blank.gif" width="1" height="1"></td>
        <td colspan="2"><a href="/CustomerCare/CustomerSearch/AddressMap?order_id=1592407" border="0" target="_gmaps"><img class="gmaps" src="/images/google_pushpin_blank.png" title="Show Address in a Map" alt="Show Address in a Map" /></a><h3 style="display: inline !important;" class="title-NAP">Invoice Address</h3></td>
    </tr>
    <tr>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        <td><img src="/images/blank.gif" width="1" height="1"></td>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
    </tr>
    <tr>
        <td width="18%" align="right"><b>Order Number:</b>&nbsp;&nbsp;</td>
        <td width="27%">&nbsp;1001592406</td>
        <td width="10%"><img src="/images/blank.gif" width="1" height="24"></td>
        <td width="18%" align="right"><b>Name:</b>&nbsp;&nbsp;</td>
        <td width="27%">&nbsp;some&nbsp;one</td>
    </tr>
    <tr>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        <td><img src="/images/blank.gif" width="1" height="1"></td>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
    </tr>
    <tr>
        <td align="right"><b>Customer:</b>&nbsp;&nbsp;</td>
        <td>&nbsp;michael&nbsp;martins</td>
        <td><img src="/images/blank.gif" width="1" height="24"></td>
        <td align="right"><b>Street Address:</b>&nbsp;&nbsp;</td>
        <td>&nbsp;DC1, Unit 3, Charlton Gate Business Park<br>&nbsp;Anchor and Hope Lane</td>
    </tr>
    <tr>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        <td><img src="/images/blank.gif" width="1" height="1"></td>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
    </tr>
    <tr>
        <td align="right"><b>Customer Number:</b>&nbsp;&nbsp;</td>
        <td>&nbsp;<a href="/CustomerCare/CustomerSearch/CustomerView?customer_id=460370">500064780</a></td>
        <td><img src="/images/blank.gif" width="1" height="24"></td>
        <td align="right"><b>Town/City:</b>&nbsp;&nbsp;</td>
        <td>&nbsp;London</td>
    </tr>
    <tr>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        <td><img src="/images/blank.gif" width="1" height="1"></td>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
    </tr>
    <tr>
        <td align="right"><b>Customer Category:</b>&nbsp;&nbsp;</td>
        <td><span class="highlight">

                Promotion

            </span>
        </td>
        <td><img src="/images/blank.gif" width="1" height="24"></td>
        <td align="right"><b>County/State:</b>&nbsp;&nbsp;</td>
        <td>&nbsp;</td>
    </tr>
    <tr>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        <td><img src="/images/blank.gif" width="1" height="1"></td>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
    </tr>
    <tr>
        <td align="right"><b>Order Status:</b>&nbsp;&nbsp;</td>
        <td><span class="highlight">&nbsp;Accepted</span></td>
        <td><img src="/images/blank.gif" width="1" height="24"></td>
        <td align="right"><b>Postcode:</b>&nbsp;&nbsp;</td>
        <td>&nbsp;W11</td>
    </tr>
    <tr>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        <td><img src="/images/blank.gif" width="1" height="1"></td>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
    </tr>
    <tr>
        <td align="right"><b>Email:</b>&nbsp;&nbsp;</td>
        <td>&nbsp;test.suite@xtracker</td>
        <td><img src="/images/blank.gif" width="1" height="24"></td>
        <td align="right"><b>Country:</b>&nbsp;&nbsp;</td>
        <td>&nbsp;United Kingdom</td>
    </tr>
    <tr>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        <td><img src="/images/blank.gif" width="1" height="1"></td>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
    </tr>
    <tr>
        <td align="right"><b>Placed By:</b>&nbsp;&nbsp;</td>
        <td>&nbsp;Customer</td>
        <td><img src="/images/blank.gif" width="1" height="24"></td>
        <td align="right"><b>Telephone:</b>&nbsp;&nbsp;</td>
        <td>&nbsp;telephone</td>
    </tr>

    <tr>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        <td><img src="/images/blank.gif" width="1" height="1"></td>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
    </tr>

    <tr>


        <td align="right" colspan="2">&nbsp;</td>



        <td><img src="/images/blank.gif" width="1" height="24"></td>
        <td align="right"><b>Mobile Telephone:</b>&nbsp;&nbsp;</td>
        <td>&nbsp;</td>
    </tr>



    <tr>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        <td><img src="/images/blank.gif" width="1" height="1"></td>
        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
    </tr>
</table>
<br /><br />


<table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
    <tr class="dividebelow">
        <td class="blank"><h3 class="title-NAP">Order Contact Options</h3></td>
        <td class="blank" align="right" style="padding-right:15px"><a href="javascript:toggle_view('OrderContactOptionsDiv', 'Order Contact Options');"><span id="lnkOrderContactOptionsDiv"><img src="/images/icons/zoom_in.png" alt="View Order Contact Options" /></span></a></td>
    </tr>
</table>
<div id="OrderContactOptionsDiv" style="display:none">

    <form name="OrderContactOptions" action="/CustomerCare/OrderSearch/OrderView?order_id=14" method="post">
        <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="92%3A2sGdFLskOTKEcyy1FJ7p8g">

        <table class="wide-data data" id="order_contact_options">
            <tr class="dividebelow">
    <td width="30%" valign="middle"><strong>Premier Delivery/Collection Notification:</strong></td>
    <td><input type="hidden" name="csm_subject_1" value="1" />                <input type="checkbox" name="csm_subject_method_1" value="1" checked="checked" />SMS&nbsp;&nbsp;&nbsp;                <input type="checkbox" name="csm_subject_method_1" value="2" checked="checked" />Email&nbsp;&nbsp;&nbsp;                <input type="checkbox" name="csm_subject_method_1" value="3"  />Phone&nbsp;&nbsp;&nbsp;    </td>

</tr>

            <tr>
                <td colspan="2" class="blank">
                    <span><strong>Any changes to the above will ONLY apply to this Order, go to the <a href="/CustomerCare/OrderSearch/CustomerView?customer_id=7">Customer View</a> page to make changes globally</strong></span>
                </td>
            </tr>
            <tr>

                <td class="blank" colspan="2" align="right"><input type="submit" name="update_order_contact_options" class="button" value="Submit &raquo;">
</td>
            </tr>

        </table>
    </form>
</div>
<br /><br />






    <h3 class="title-NAP">Customer Warnings</h3>
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td width="20%" align="right"><b>Customer Watch:</b>&nbsp;&nbsp;</td>
            <td width="80%">
                <span class="highlight">


                </span>
                 -
            </td>
        </tr>
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td align="right"><b>Warning Flags:</b>&nbsp;&nbsp;</td>
            <td>



            </td>
        </tr>
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td align="right"><b>CV2/AVS Check:</b>&nbsp;&nbsp;</td>
            <td></td>
        </tr>
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>


            <form name="creditCheckFlags" action="/CustomerCare/CustomerSearch/OrderView?order_id=1592407" method="post">
            <input type="hidden" name="ccheck_flags" value="1">
            <tr>
                <td align="right"><b>Name Check:</b>&nbsp;&nbsp;</td>
                <td><input type="radio" name="checkname" value="yes" >&nbsp;OK&nbsp;&nbsp;&nbsp;<input type="radio" name="checkname" value="no" >&nbsp;Incorrect</td>
            </tr>
            <tr>
                <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
            <tr>
                <td align="right"><b>Address Check:</b>&nbsp;&nbsp;</td>
                <td><input type="radio" name="checkaddr" value="yes" >&nbsp;OK&nbsp;&nbsp;&nbsp;<input type="radio" name="checkaddr" value="no" >&nbsp;Incorrect</td>
            </tr>
            <tr>
                <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
            <tr>
                <td align="right"><b>Possible Fraud:</b>&nbsp;&nbsp;</td>
                <td><input type="checkbox" name="possible_fraud" value="yes" ></td>
            </tr>
            <tr>
                <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
            <tr>
                <td colspan="2" class="blank"><img src="/images/blank.gif" width="1" height="5"></td>
            </tr>
            <tr>
                <td class="blank" colspan="2" align="right"><input class="button" type="submit" name="" value="Save Changes &raquo;"></td>
            </tr>
            </form>


    </table>
    <br><br>






    <!-- hidden div to display orders placed with the same card -->
    <div id="orders_same_card" style="display:none; position:absolute; left:220px; top:500px; z-index:1000; padding-left:3px; padding-bottom:3px; background-color: #cccccc">
        <div style="border:1px solid #666666; background-color: #fff; padding: 10px; z-index:1001">
            <div id="cardHistory" style="width:800px">
                <table style="width: 100%; border: 1px solid #cfcfcf;" cellspacing="1" cellpadding="4" class="data">
                    <thead>
                        <tr>
                            <td colspan="8" align="right"><a href="javascript://" onClick="hideCardHistory();"><img src="/images/icons/cancel.png" style="display: inline;" alt="Hide" border="0"></a></td>
                        </tr>
                        <tr>
                            <td class="tableHeader" style="width: 8%; text-align: center;">Order</td>
                            <td class="tableHeader" style="width: 10%; text-align: center;">Date</td>
                            <td class="tableHeader" style="width: 8%; text-align: center;">Status</td>
                            <td class="tableHeader" style="width: 8%; text-align: center;">Value</td>
                            <td class="tableHeader" style="width: 8%; text-align: center;">Curr.</td>
                            <td class="tableHeader" style="width: 10%; text-align: center;">Stored&nbsp;Card</td>
                            <td class="tableHeader" style="width: 16%; text-align: center;">CV2&nbsp;Response</td>
                            <td class="tableHeader" style="width: 14%; text-align: center;">Payment Fulfilled</td>
                        </tr>
                    </thead>
                    <tbody>

                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <h3 class="title-NAP">Payment Card Details</h3>
    <table class="wide-data divided-data" id="order_details__payment_card_details">
        <tr>
            <td width="20%" align="right"><b>PSP:</b>&nbsp;&nbsp;</td>
            <td align="left">Provider Inc</td>
            <td width="25%" align="right"><b>Issuing Country:</b>&nbsp;&nbsp;</td>
            <td width="30%" align="left">United Kingdom</td>
        </tr>

        <tr>
            <td align="right"><b>PSP Reference:</b>&nbsp;&nbsp;</td>
            <td align="left">1234-HELLOSWEETIE</td>
            <td align="right"><b>Issuer:</b>&nbsp;&nbsp;</td>
            <td align="left">Bank of Gallifrey</td>
        </tr>

        <tr>
            <td align="right"><b>Value:</b>&nbsp;&nbsp;</td>
            <td align="left">GBP&nbsp;9876.54</td>
            <td align="right"><b>IP Address:</b>&nbsp;&nbsp;</td>
            <td align="left">-</td>
        </tr>

        <tr>
            <td align="right"><b>Card Number:</b>&nbsp;&nbsp;</td>
            <td style="vertical-align: middle;">
                9***********8765&nbsp;&nbsp;&nbsp;&nbsp;


            </td>
            <td align="right"><b>3D Secure Response:</b>&nbsp;&nbsp;</td>
            <td aligh="left">3DSecure is not supported</td>
        </tr>

        <tr>
            <td align="right"><b>Expiry Date:</b>&nbsp;&nbsp;</td>
            <td align="left">01/01</td>
            <td align="right"><b>Stored Card:</b>&nbsp;&nbsp;</td>
            <td align="left">

                    No

            </td>
        </tr>

        <tr>
            <td align="right"><b>Card Type:</b>&nbsp;&nbsp;</td>
            <td align="left">American Impress </td>
            <td align="right"><b>Internal Payment Reference:</b>&nbsp;&nbsp;</td>
            <td align="left">1234-SEEMSNICE</td>
        </tr>

        <tr>
            <td align="right"><b>CV2 Check:</b>&nbsp;&nbsp;</td>
            <td align="left">ALL MATCH</td>
            <td align="right"><b>Valid:</b>&nbsp;&nbsp;</td>
            <td align="left">Yes</td>
        </tr>

        <tr>
            <td align="right"><b>Auth Code:</b>&nbsp;&nbsp;</td>
            <td aligh="left">000001</td>
            <td align="right"><b>Fulfilled:</b>&nbsp;&nbsp;</td>
            <td align="left">No</td>
        </tr>



    </table>

    <br /><br />




    <h3 class="title-NAP">Payment Details Store Credit</h3>
    <table class="wide-data data divided-data">
        <thead>
        </thead>
        <tbody>
            <tr>
                <td width="20%" align="right"><b>Value Used:</b></td>
                <td width="80%">510.000 GBP</td>
            </tr>
        </tbody>
    </table>
    <br /><br />







    <h3 class="title-NAP">Customer Notes</h3>
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
        <tr>
            <td colspan="8" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td class="tableHeader" width="17%">&nbsp;&nbsp;&nbsp;Date</td>
            <td class="tableHeader" width="33%">Note</td>
            <td class="tableHeader" width="9%">Type</td>
            <td class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;</td>
            <td class="tableHeader" width="18%">Operator</td>
            <td class="tableHeader" width="7%"></td>
            <td class="tableHeader" width="7%"></td>
        </tr>
        <tr>
            <td colspan="7" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>

            <tr>
                <td>&nbsp;&nbsp;&nbsp;28-06-11 14:01</td>
                <td>Example Note</td>
                <td>Finance</td>
                <td>&nbsp;&nbsp;&nbsp;&nbsp;</td>
                <td>Andrew Beech<br /><span class="lowlight">Finance</span></td>
                <td><a href="/CustomerCare/CustomerSearch/Note?parent_id=460370&note_category=Customer&sub_id=460370&note_id=107801"><img src="/images/icons/page_edit.png" alt="Edit Note"></a></td>
                <td><a href="/CustomerCare/CustomerSearch/EditNote?note_category=Customer&action=Delete&parent_id=460370&note_id=107801"><img src="/images/icons/cross.png" alt="Delete Note"></a></td>
            </tr>
            <tr>
                <td colspan="7" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>

    </table>
    <br><br>






<br>



    <table width="100%" cellpadding="0" cellspacing="0" border="0" id="shipment_details__shipment_address_1">
        <tr>
            <td colspan="2"><h3 class="title-NAP">Shipment Details</h3></td>
            <td><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="2"><a href="/CustomerCare/CustomerSearch/AddressMap?shipment_id=1715594" border="0" target="_gmaps"><img class="gmaps" src="/images/google_pushpin_blank.png" title="Show Address in a Map" alt="Show Address in a Map" /></a><h3 style="display: inline !important;" class="title-NAP">Shipment Address</h3></td>
        </tr>
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            <td><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td width="18%" align="right"><b>Shipment Number:</b>&nbsp;&nbsp;</td>
            <td width="27%">&nbsp;1715594</td>
            <td width="10%"><img src="/images/blank.gif" width="1" height="24"></td>
            <td width="18%" align="right"><b>Name:</b>&nbsp;&nbsp;</td>
            <td width="27%">&nbsp;some one</td>
        </tr>
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            <td><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr height="22">
            <td align="right"><b>Date:</b>&nbsp;&nbsp;</td>
            <td>&nbsp;28-06-2011  11:25</td>
            <td><img src="/images/blank.gif" width="1" height="24"></td>
            <td align="right"><b>Street Address:</b>&nbsp;&nbsp;</td>
            <td>&nbsp;DC1, Unit 3, Charlton Gate Business Park<br>&nbsp;Anchor and Hope Lane<br>&nbsp;LONDON, SE7 7RU</td>
        </tr>
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            <td><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr height="22">
            <td align="right"><b>Shipment Type:</b>&nbsp;&nbsp;</td>
            <td>&nbsp;Standard</td>
            <td><img src="/images/blank.gif" width="1" height="24"></td>
            <td align="right"><b>Town/City:</b>&nbsp;&nbsp;</td>
            <td>&nbsp;London</td>
        </tr>
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            <td><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr height="22">
            <td align="right"><b>Shipment Class:</b>&nbsp;&nbsp;</td>
            <td>
                Domestic


            </td>
            <td><img src="/images/blank.gif" width="1" height="24"></td>
            <td align="right"><b>County/State:</b>&nbsp;&nbsp;</td>
            <td>&nbsp;</td>
        </tr>
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            <td><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td align="right"><b>Packing Instruction:</b>&nbsp;&nbsp;</td>
            <td>&nbsp;</td>
            <td><img src="/images/blank.gif" width="1" height="24"></td>
            <td align="right"><b>Postcode:</b>&nbsp;&nbsp;</td>
            <td>&nbsp;W11</td>
        </tr>
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            <td><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td align="right"><b>Status:</b>&nbsp;&nbsp;</td>
            <td>&nbsp;<span class="highlight">Hold</span></td>
            <td><img src="/images/blank.gif" width="1" height="24"></td>
            <td align="right"><b>Country:</b>&nbsp;&nbsp;</td>
            <td>&nbsp;United Kingdom</td>
        </tr>
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            <td><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td align="right"><b>Email:</b>&nbsp;&nbsp;</td>
            <td>&nbsp;test.suite@xtracker</td>
            <td><img src="/images/blank.gif" width="1" height="24"></td>
            <td align="right"><b>Telephone:</b>&nbsp;&nbsp;</td>
            <td>&nbsp;telephone</td>
        </tr>
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            <td><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>

            <td align="right"><b>Destination Code:</b>&nbsp;</td>
                <td>&nbsp;LHR</td>

            <td><img src="/images/blank.gif" width="1" height="24"></td>
            <td align="right"><b>Mobile Telephone:</b>&nbsp;&nbsp;</td>
            <td>&nbsp;</td>
        </tr>
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            <td><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td align="right"><b>Shipping Account:</b>&nbsp;</td>
            <td>&nbsp;DHL Express - Domestic</td>
            <td><img src="/images/blank.gif" width="1" height="24"></td>
            <td align="right">&nbsp;</td>
            <td>&nbsp;</td>
        </tr>
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            <td><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>


    </table>






    <br><br>


        <h3 class="title-NAP">Shipment Hold</h3>
        <table width="100%" cellpadding="0" cellspacing="0" border="0" id="shipment_hold">
            <tr>
                <td colspan="3" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
            <tr>
                <td align="right" width="15%"><b>Held By:</b>&nbsp;&nbsp;</td>
                <td>Application</td>
                <td><img src="/images/blank.gif" width="1" height="24"></td>
            </tr>
            <tr>
                <td colspan="3" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
            <tr>
                <td align="right" width="15%"><b>Date Held:</b>&nbsp;&nbsp;</td>
                <td>28-06-2011 12:31</td>
                <td><img src="/images/blank.gif" width="1" height="24"></td>
            </tr>
            <tr>
                <td colspan="3" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
            <tr>
                <td align="right" width="15%"><b>Reason:</b>&nbsp;&nbsp;</td>
                <td>Incomplete Pick</td>
                <td><img src="/images/blank.gif" width="1" height="24"></td>
            </tr>
            <tr>
                <td colspan="3" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
            <tr>
                <td align="right" width="15%"><b>Comment:</b>&nbsp;&nbsp;</td>
                <td>The following items were missing:

41087-024 x 1; 41088-024 x 1; 41089-024 x 1; 41090-024 x 1; 41092-024 x 1</td>
                <td><img src="/images/blank.gif" width="1" height="24"></td>
            </tr>
            <tr>
                <td colspan="3" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
            <tr>
                <td align="right" width="15%"><b>Release Date:</b>&nbsp;&nbsp;</td>
                <td></td>
                <td><img src="/images/blank.gif" width="1" height="24"></td>
            </tr>
            <tr>
                <td colspan="3" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
        </table>
        <br>
        <br>


    <h3 class="title-NAP">Shipment Items</h3>
    <table class="order_view_shipment_item wide-data data">
        <thead>
            <tr>
                <th>&nbsp;</th>
                <th>&nbsp;&nbsp;SKU</th>
                <th>Name</th>
                <th>Designer</th>
                <th>Size</th>
                <th>Status</th>
                <th>MD</th>
                <th>PR</th>
                <th>Unit Price</th>
                <th>Tax</th>
                <th>Duties</th>
                <th>Sub-Total&nbsp;&nbsp;</th>
            </tr>
        </thead>
        <tbody>





                <tr class="dividebelow">
                    <td class="light" style="white-space:nowrap;">
                        <img class="link_cursor inline" onClick="javascript:enlargeImage('http://cache.net-a-porter.com/images/products/41089/41089_in_l.jpg');" src="/images/icons/image.png" alt="View Product Image" border="0" />
                    </td>
                    <td class="light">&nbsp;&nbsp;41089-024&nbsp;</td>
                    <td class="light">Loose-fit long-sleeve T-shirt </td>
                    <td class="light">James Perse</td>
                    <td class="light">
                            1
                                                </td>
                    <td class="light"><b>Cancelled</b></td>
                    <td class="light">-</td>
                    <td class="light">-</td>
                    <td class="light" align="right">100.00</td>
                    <td class="light" align="right">0.00</td>
                    <td class="light" align="right">0.00</td>
                    <td class="light" align="right">100.00&nbsp;&nbsp;</td>
                </tr>



                <tr class="dividebelow">
                    <td style="white-space:nowrap;">
                        <img class="link_cursor inline" onClick="javascript:enlargeImage('http://cache.net-a-porter.com/images/products/41092/41092_in_l.jpg');" src="/images/icons/image.png" alt="View Product Image" border="0" />
                    </td>
                    <td>&nbsp;&nbsp;41092-024&nbsp;</td>
                    <td>Loose-fit short-sleeve T-shirt</td>
                    <td>James Perse</td>
                    <td>
                            1
                                                </td>
                    <td><b>Selected</b></td>
                    <td>-</td>
                    <td>-</td>
                    <td align="right">100.00</td>
                    <td align="right">0.00</td>
                    <td align="right">0.00</td>
                    <td align="right">100.00&nbsp;&nbsp;</td>
                </tr>



                <tr class="dividebelow">
                    <td style="white-space:nowrap;">
                        <img class="link_cursor inline" onClick="javascript:enlargeImage('http://cache.net-a-porter.com/images/products/41088/41088_in_l.jpg');" src="/images/icons/image.png" alt="View Product Image" border="0" />
                    </td>
                    <td>&nbsp;&nbsp;41088-024&nbsp;</td>
                    <td>Loose-fit long-sleeve T-shirt</td>
                    <td>James Perse</td>
                    <td>
                            1
                                                </td>
                    <td><b>Selected</b></td>
                    <td>-</td>
                    <td>-</td>
                    <td align="right">100.00</td>
                    <td align="right">0.00</td>
                    <td align="right">0.00</td>
                    <td align="right">100.00&nbsp;&nbsp;</td>
                </tr>



                <tr class="dividebelow">
                    <td style="white-space:nowrap;">
                        <img class="link_cursor inline" onClick="javascript:enlargeImage('http://cache.net-a-porter.com/images/products/41087/41087_in_l.jpg');" src="/images/icons/image.png" alt="View Product Image" border="0" />
                    </td>
                    <td>&nbsp;&nbsp;41087-024&nbsp;</td>
                    <td>Loose-fit long-sleeve T-shirt </td>
                    <td>James Perse</td>
                    <td>
                            1
                                                </td>
                    <td><b>Selected</b></td>
                    <td>-</td>
                    <td>-</td>
                    <td align="right">100.00</td>
                    <td align="right">0.00</td>
                    <td align="right">0.00</td>
                    <td align="right">100.00&nbsp;&nbsp;</td>
                </tr>



                <tr class="dividebelow">
                    <td style="white-space:nowrap;">
                        <img class="link_cursor inline" onClick="javascript:enlargeImage('http://cache.net-a-porter.com/images/products/41090/41090_in_l.jpg');" src="/images/icons/image.png" alt="View Product Image" border="0" />
                    </td>
                    <td>&nbsp;&nbsp;41090-024&nbsp;</td>
                    <td>Loose-fit short-sleeve T-shirt</td>
                    <td>James Perse</td>
                    <td>
                            1
                                                </td>
                    <td><b>Selected</b></td>
                    <td>-</td>
                    <td>-</td>
                    <td align="right">100.00</td>
                    <td align="right">0.00</td>
                    <td align="right">0.00</td>
                    <td align="right">100.00&nbsp;&nbsp;</td>
                </tr>



            <tr class="dividebelow">
                <td class="blank" colspan="8">&nbsp;</td>
                <td class="blank" colspan="3" align="right"><b>Shipping</b>&nbsp;</td>
                <td class="blank" align="right" style="white-space:nowrap;"><b>10.00&nbsp;&nbsp;</b></td>
            </tr>

                <tr class="dividebelow">
                <td class="blank" colspan="8">&nbsp;</td>
                <td class="blank" colspan="3" align="right"><b>Store Credit</b>&nbsp;</td>
                <td class="blank" align="right" style="white-space:nowrap;"><b>- 510.000&nbsp;&nbsp;</b></td>
                </tr>


            <tr class="dividebelow">
                <td class="blank" colspan="8">&nbsp;</td>
                <td class="blank" colspan="3" align="right"><b>Shipment Total</b>&nbsp;</td>
                <td class="blank" align="right" style="white-space:nowrap;"><b>GBP 410.00&nbsp;&nbsp;</b></td>
            </tr>
        </tbody>
    </table>



    <br /><br /><br />



    <h3 class="title-NAP">Shipment Email Log</h3>
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="email_log_shipment_1715594">
        <tr>
            <td colspan="4" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>

            <td class="tableHeader">&nbsp;&nbsp;&nbsp;Type</td>
            <td class="tableHeader">&nbsp;&nbsp;&nbsp;Date Sent</td>
            <td class="tableHeader">&nbsp;&nbsp;&nbsp;Sent By</td>
        </tr>
        <tr>
            <td colspan="4" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>



        <tr>
            <td>&nbsp;&nbsp;&nbsp;ReturnsQC-SLA-Breach-OUTNET-INTL</td>
            <td>&nbsp;&nbsp;&nbsp;18-01-2012  10:24</td>
            <td>&nbsp;&nbsp;&nbsp;Application</td>
        </tr>
        <tr>
            <td colspan="4" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>

        </tr>


    </table>
    <br><br><br>

    <h3 class="title-NAP" id="print_log">Return Email Log</h3>
    <table class="data wide-data divided-data" id="email_log_return_1715594">
        <thead>
            <tr>
                <th>RMA</th>

                <th>Type</th>
                <th>Date Sent</th>
                <th>Sent By</th>
            </tr>
        </thead>
        <tbody>

            <tr>

                <td>R115-135</td>
                <td>Premier - Arrange Delivery</td>
                <td>18-01-2012  10:24</td>
                <td>Application</td>
            </tr>

        </tbody>
    </table>

    <br/><br/><br/>



















<div id="enlargeImage" style="visibility:hidden; position:absolute; left:0px; top:0px; z-index:1000; padding-left:3px; padding-bottom:3px; background-color: #cccccc">

    <div style="border:1px solid #666666; background-color: #fff; padding: 10px; z-index:1001">

        <div align="right" style="margin-bottom:5px"><a href="javascript://" onClick="hideLayer('enlargeImage');">Close</a></div>
        <div id="imagePlaceHolder"></div>
    </div>
</div>





        </div>
    </div>

    <p id="footer">    xTracker-DC  (2011.07.04.16.g55d0af5 / IWS phase 1). &copy; 2006 - 2011 NET-A-PORTER
</p>


</div>

    </body>
</html>
