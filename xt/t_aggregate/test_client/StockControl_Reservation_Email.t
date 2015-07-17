#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

StockControl_Reservation_Email.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /StockControl/Reservation/Email

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/StockControl/Reservation/Email',
    expected   => {
        'customer_emails' => {
            "NET-A-PORTER.COM" => [
                {
                    customer_info => {
                            "Customer Name" => "2c68c7 35651b",
                            "Customer Number" => '243924'
                        },
                    email_info => {
                            "Addressee"  => { input_name => "addressee", input_value => "2c68c7", value => "" },
                            "From Email" => {
                            input_name => "from_email",
                            input_value => "MyShop\@net-a-porter.com",
                            value => "",
                        },
                        "To Email"   => {
                            input_name => "to_email",
                            input_value => "andrew.beech\@net-a-porter.com",
                            value => "",
                        },
                    },
                    list => [
                        {
                            Date    => "04-05",
                            Notify  => { input_name => "inc-278719", input_value => '1', value => "" },
                            Product => "Acne Brushed leather ankle boots",
                            SKU     => "96881-089",
                            Status  => "Uploaded",
                        },
                    ],
                },
            ],
            "THEOUTNET.COM"    => [
                {
                    customer_info => {
                        "Customer Name" => "0eb851 8abb252b84",
                        "Customer Number" => '300136818',
                    },
                    email_info => {
                        "Addressee"  => { input_name => "addressee", input_value => "0eb851", value => "" },
                        "From Email" => {
                            input_name => "from_email",
                            input_value => "MyShop\@theoutnet.com",
                            value => "",
                        },
                        "To Email"   => { input_name => "to_email", input_value => "cf5f382d85f63", value => "" },
                    },
                    list => [
                        {
                            Date    => "05-05",
                            Notify  => "",
                            Product => "Chloé Velvet mini skirt",
                            SKU     => "35661-010",
                            Status  => "Uploaded",
                        },
                    ],
                },
            ],
        }
    },
);

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en">
    <head>
        <meta http-equiv="Content-type" content="text/html; charset=utf-8">

        <title>Reservation &#8226; Stock Control &#8226; XT-DC1</title>


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


            <script type="text/javascript" src="/yui/yahoo-dom-event/yahoo-dom-event.js"></script>

            <script type="text/javascript" src="/yui/element/element-min.js"></script>

            <script type="text/javascript" src="/yui/tabview/tabview-min.js"></script>




        <!-- Custom CSS -->

            <link rel="stylesheet" type="text/css" href="/yui/tabview/assets/skins/sam/tabview.css">


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
                                                <a href="/StockControl/Cancellations" class="yuimenuitemlabel">Cancellations</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/DutyRates" class="yuimenuitemlabel">Duty Rates</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/FinalPick" class="yuimenuitemlabel">Final Pick</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/Inventory" class="yuimenuitemlabel">Inventory</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/Measurement" class="yuimenuitemlabel">Measurement</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/PerpetualInventory" class="yuimenuitemlabel">Perpetual Inventory</a>
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
                                                <a href="/StockControl/StockRelocation" class="yuimenuitemlabel">Stock Relocation</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/DeadStock" class="yuimenuitemlabel">Dead Stock</a>
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





                    <li><a href="/StockControl/Reservation" class="last">Summary</a></li>




                        <li><span>Overview</span></li>



                    <li><a href="/StockControl/Reservation/Overview?view_type=Upload">Upload</a></li>

                    <li><a href="/StockControl/Reservation/Overview?view_type=Pending">Pending</a></li>

                    <li><a href="/StockControl/Reservation/Overview?view_type=Waiting" class="last">Waiting List</a></li>




                        <li><span>View</span></li>



                    <li><a href="/StockControl/Reservation/Listing?list_type=Live&show=">Live Reservations</a></li>

                    <li><a href="/StockControl/Reservation/Listing?list_type=Pending&show=">Pending Reservations</a></li>

                    <li><a href="/StockControl/Reservation/Listing?list_type=Waiting&show=" class="last">Waiting Lists</a></li>




                        <li><span>Search</span></li>



                    <li><a href="/StockControl/Reservation/Product">Product</a></li>

                    <li><a href="/StockControl/Reservation/Customer" class="last">Customer</a></li>




                        <li><span>Email</span></li>



                    <li><a href="/StockControl/Reservation/Email" class="last">Customer Notification</a></li>




                        <li><span>Reports</span></li>



                    <li><a href="/StockControl/Reservation/Reports/Uploaded/P">Uploaded</a></li>

                    <li><a href="/StockControl/Reservation/Reports/Purchased/P" class="last">Purchased</a></li>


        </ul>

</div>




        <div id="contentRight">











                    <div id="pageTitle">
                        <h1>Reservation</h1>
                        <h5>&bull;</h5><h2>Customer Notification</h2>

                    </div>






    <table width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr>
            <td width="80%" align="right"><b>Alternative Operator:&nbsp;</b></td>
            <td>
                <select name="operator" onChange="location.href=this[this.selectedIndex].value">
                        <option value="/StockControl/Reservation/Email">---------------------</option>

                        <option value="/StockControl/Reservation/Email?operator_id=8">Matt Ryall</option>

                        <option value="/StockControl/Reservation/Email?operator_id=23">DISABLED: Nicola Snow</option>

                        <option value="/StockControl/Reservation/Email?operator_id=26">DISABLED: Daniel Harrington</option>

                        <option value="/StockControl/Reservation/Email?operator_id=50">DISABLED: Joanna Mullins</option>

                        <option value="/StockControl/Reservation/Email?operator_id=53">Disabled:  Nicola Snow</option>

                        <option value="/StockControl/Reservation/Email?operator_id=61">DISABLED: Jill Amiri</option>

                        <option value="/StockControl/Reservation/Email?operator_id=72">DISABLED: Aktar Miah</option>

                        <option value="/StockControl/Reservation/Email?operator_id=116">DISABLED: Monika Ziedani</option>

                        <option value="/StockControl/Reservation/Email?operator_id=152">Matthew Atherfold</option>

                        <option value="/StockControl/Reservation/Email?operator_id=169">Stephen Connolly</option>

                        <option value="/StockControl/Reservation/Email?operator_id=192">Ana Popovic</option>

                        <option value="/StockControl/Reservation/Email?operator_id=194">Maria Mrowczynska</option>

                        <option value="/StockControl/Reservation/Email?operator_id=242">Ieva Putrimaite</option>

                        <option value="/StockControl/Reservation/Email?operator_id=264">DISABLED: Tim Gagen</option>

                        <option value="/StockControl/Reservation/Email?operator_id=296">Joanna Dermont</option>

                        <option value="/StockControl/Reservation/Email?operator_id=470">DISABLED: Stock Move</option>

                        <option value="/StockControl/Reservation/Email?operator_id=481">Maria Chladna</option>

                        <option value="/StockControl/Reservation/Email?operator_id=544">Andrea Branisova</option>

                        <option value="/StockControl/Reservation/Email?operator_id=550">Paul James</option>

                        <option value="/StockControl/Reservation/Email?operator_id=632">Joanna Pintscher</option>

                        <option value="/StockControl/Reservation/Email?operator_id=671">Danuta Badan</option>

                        <option value="/StockControl/Reservation/Email?operator_id=849">Sinead Kenny</option>

                        <option value="/StockControl/Reservation/Email?operator_id=890">Izabela Lucinska</option>

                        <option value="/StockControl/Reservation/Email?operator_id=922">Tracey Martin</option>

                        <option value="/StockControl/Reservation/Email?operator_id=997">Shemima Chinery</option>

                        <option value="/StockControl/Reservation/Email?operator_id=1023">Loga Jegede</option>

                        <option value="/StockControl/Reservation/Email?operator_id=1810">DISABLED: Jorge Aponte</option>

                        <option value="/StockControl/Reservation/Email?operator_id=1842">Tommy Michaelopoulos</option>

                        <option value="/StockControl/Reservation/Email?operator_id=2273">Claudia Urena</option>

                        <option value="/StockControl/Reservation/Email?operator_id=5001">Andrew Beech</option>

                        <option value="/StockControl/Reservation/Email?operator_id=5141">Jamie Cook</option>

                        <option value="/StockControl/Reservation/Email?operator_id=5147">Golan Frydman</option>

                        <option value="/StockControl/Reservation/Email?operator_id=5333">Monika Zeidani</option>

                        <option value="/StockControl/Reservation/Email?operator_id=5352">Andrew Solomon</option>

                        <option value="/StockControl/Reservation/Email?operator_id=5373">Fahad Khan</option>

                        <option value="/StockControl/Reservation/Email?operator_id=5376">Jennifer Hunt</option>

                        <option value="/StockControl/Reservation/Email?operator_id=5562">David Wilson-Weight</option>

                        <option value="/StockControl/Reservation/Email?operator_id=5601">Luana Michaels</option>

                        <option value="/StockControl/Reservation/Email?operator_id=5771">Louis Difinizio</option>

                        <option value="/StockControl/Reservation/Email?operator_id=5843">Daniel O'Dina</option>

                        <option value="/StockControl/Reservation/Email?operator_id=5878">Viki Elson</option>

                        <option value="/StockControl/Reservation/Email?operator_id=5981">Danny King</option>

                        <option value="/StockControl/Reservation/Email?operator_id=6055">Emma Humphrey</option>

                        <option value="/StockControl/Reservation/Email?operator_id=6117">Imie Augier</option>

                        <option value="/StockControl/Reservation/Email?operator_id=6146">Elizabeth Goldstein</option>

                        <option value="/StockControl/Reservation/Email?operator_id=6166">Magda Krol</option>

                        <option value="/StockControl/Reservation/Email?operator_id=6308">Lesley-Anne Hinds</option>

                        <option value="/StockControl/Reservation/Email?operator_id=6906">Danielle Corbin</option>

                        <option value="/StockControl/Reservation/Email?operator_id=6915">Aaron Hartgrove</option>

                        <option value="/StockControl/Reservation/Email?operator_id=7124">Goobi Kyazze</option>

                        <option value="/StockControl/Reservation/Email?operator_id=7138">Antonio Michael</option>

                </select>

            </td>
        </tr>
    </table><br />
    <br />




<div id="tabContainer" class="yui-navset">
        <table width="100%" cellpadding="0" cellspacing="0" border="0" class="tabChannelTable">
        <tr>
            <td align="right"><span class="tab-label">Sales Channel:&nbsp;</span></td>
            <td width="5%" align="right" nowrap>
                <ul class="yui-nav">						<li class="selected"><a href="#tab1" class="contentTab-NAP" style="text-decoration: none;"><em>NET-A-PORTER.COM</em></a></li>						<li><a href="#tab2" class="contentTab-OUTNET" style="text-decoration: none;"><em>THEOUTNET.COM</em></a></li>                </ul>
            </td>
        </tr>
    </table>

    <div class="yui-content">



            <div id="tab1" class="tabWrapper-NAP">
            <div class="tabInsideWrapper">

                <span class="title title-NAP">Customer Emails</span><br />



                    <form name="emailCustomer-201367" action="/StockControl/Reservation/SendReservationEmail" method="post">
                        <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="32369295">

                        <input type="hidden" name="customer_id" value="201367">
                        <input type="hidden" name="channel_id" value="1">
                        <input type="hidden" name="operator_id" value="5001">

                    <table width="100%" cellpadding="0" cellspacing="0" border="0">
                        <tr>
                            <td colspan="2" class="divider"></td>
                        </tr>
                        <tr height="26">
                            <td width="20%" align="right"><b>Customer Number:&nbsp;&nbsp;</td>
                            <td width="80%">243924</td>
                        </tr>
                        <tr>
                            <td colspan="2" class="divider"></td>
                        </tr>
                        <tr height="26">
                            <td align="right"><b>Customer Name:&nbsp;&nbsp;</td>
                            <td>2c68c7&nbsp;35651b</td>
                        </tr>
                        <tr>
                            <td colspan="2" class="divider"></td>
                        </tr>
                    </table><br />
                    <br />
                    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                        <tr>
                            <td colspan="2" class="divider"></td>
                        </tr>
                        <tr height="26">
                            <td width="20%" align="right"><b>From Email:&nbsp;&nbsp;</td>
                            <td width="80%"><input type="text" name="from_email" value="MyShop@net-a-porter.com" size="30"></td>
                        </tr>
                        <tr>
                            <td colspan="2" class="divider"></td>
                        </tr>
                        <tr height="26">
                            <td align="right"><b>To Email:&nbsp;&nbsp;</td>
                            <td><input type="text" name="to_email" value="andrew.beech@net-a-porter.com" size="30"></td>
                        </tr>
                        <tr>
                            <td colspan="2" class="divider"></td>
                        </tr>
                        <tr height="26">
                            <td align="right"><b>Addressee:&nbsp;&nbsp;</td>
                            <td><input type="text" name="addressee" value="2c68c7" size="15"></td>
                        </tr>
                        <tr>
                            <td colspan="2" class="divider"></td>
                        </tr>
                    </table>
                    <br>
                    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                        <tr>
                            <td colspan="9" class="dividerHeader"></td>
                        </tr>
                        <tr>
                            <td width="10%" class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
                            <td width="50%" class="tableHeader">Product</td>
                            <td width="15%" class="tableHeader">Status</td>
                            <td width="10%" class="tableHeader">Date</td>
                            <td width="15%" align="center" class="tableHeader">Notify</td>
                        </tr>
                        <tr>
                            <td colspan="9" class="dividerHeader"></td>
                        </tr>


                        <tr>
                            <td>&nbsp;&nbsp;&nbsp;96881-089</td>
                            <td>Acne&nbsp;Brushed leather ankle boots</td>
                            <td>Uploaded</td>
                            <td>04-05</td>
                            <td align="center"><input type="checkbox" name="inc-278719" value="1"></td>
                        </tr>
                        <tr>
                            <td colspan="9" class="divider"></td>
                        </tr>

                        <tr>
                            <td colspan="10" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
                        </tr>
                        <tr>
                            <td colspan="10" class="blank" align="right"><input type="submit" name="submit" value="Send Email >" class="button"></td>
                        </tr>
                    </table>
                    </form>
                    <br>
                    <br>
                    <br>



                <br><br><br>
                <br><img src="/images/blank.gif" width="1" height="100">

            </div>
            </div>


            <div id="tab2" class="tabWrapper-OUTNET">
            <div class="tabInsideWrapper">

                <span class="title title-OUTNET">Customer Emails</span><br />



                    <form name="emailCustomer-251475" action="/StockControl/Reservation/SendReservationEmail" method="post">
                        <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="32369295">

                        <input type="hidden" name="customer_id" value="251475">
                        <input type="hidden" name="channel_id" value="3">
                        <input type="hidden" name="operator_id" value="5001">

                    <table width="100%" cellpadding="0" cellspacing="0" border="0">
                        <tr>
                            <td colspan="2" class="divider"></td>
                        </tr>
                        <tr height="26">
                            <td width="20%" align="right"><b>Customer Number:&nbsp;&nbsp;</td>
                            <td width="80%">300136818</td>
                        </tr>
                        <tr>
                            <td colspan="2" class="divider"></td>
                        </tr>
                        <tr height="26">
                            <td align="right"><b>Customer Name:&nbsp;&nbsp;</td>
                            <td>0eb851&nbsp;8abb252b84</td>
                        </tr>
                        <tr>
                            <td colspan="2" class="divider"></td>
                        </tr>
                    </table><br />
                    <br />
                    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                        <tr>
                            <td colspan="2" class="divider"></td>
                        </tr>
                        <tr height="26">
                            <td width="20%" align="right"><b>From Email:&nbsp;&nbsp;</td>
                            <td width="80%"><input type="text" name="from_email" value="MyShop@theoutnet.com" size="30"></td>
                        </tr>
                        <tr>
                            <td colspan="2" class="divider"></td>
                        </tr>
                        <tr height="26">
                            <td align="right"><b>To Email:&nbsp;&nbsp;</td>
                            <td><input type="text" name="to_email" value="cf5f382d85f63" size="30"></td>
                        </tr>
                        <tr>
                            <td colspan="2" class="divider"></td>
                        </tr>
                        <tr height="26">
                            <td align="right"><b>Addressee:&nbsp;&nbsp;</td>
                            <td><input type="text" name="addressee" value="0eb851" size="15"></td>
                        </tr>
                        <tr>
                            <td colspan="2" class="divider"></td>
                        </tr>
                    </table>
                    <br>
                    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                        <tr>
                            <td colspan="9" class="dividerHeader"></td>
                        </tr>
                        <tr>
                            <td width="10%" class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
                            <td width="50%" class="tableHeader">Product</td>
                            <td width="15%" class="tableHeader">Status</td>
                            <td width="10%" class="tableHeader">Date</td>
                            <td width="15%" align="center" class="tableHeader">Notify</td>
                        </tr>
                        <tr>
                            <td colspan="9" class="dividerHeader"></td>
                        </tr>


                        <tr>
                            <td>&nbsp;&nbsp;&nbsp;35661-010</td>
                            <td>Chloé&nbsp;Velvet mini skirt </td>
                            <td>Uploaded</td>
                            <td>05-05</td>
                            <td align="center"><img src="/images/icons/tick.png"></td>
                        </tr>
                        <tr>
                            <td colspan="9" class="divider"></td>
                        </tr>

                        <tr>
                            <td colspan="10" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
                        </tr>
                        <tr>
                            <td colspan="10" class="blank" align="right"><input type="submit" name="submit" value="Send Email >" class="button"></td>
                        </tr>
                    </table>
                    </form>
                    <br>
                    <br>
                    <br>



                <br><br><br>
                <br><img src="/images/blank.gif" width="1" height="100">

            </div>
            </div>

    </div>
</div>

<script type="text/javascript" language="javascript">
    (function() {
        var tabView = new YAHOO.widget.TabView('tabContainer');
    })();
</script>







        </div>
    </div>

    <p id="footer">    xTracker-DC  (2011.04.05.65.g8b2f68a.dirty / IWS phase 0). &copy; 2006 - 2011 NET-A-PORTER
</p>


</div>

    </body>
</html>
