#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

CustomerCare_OrderLog.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /CustomerCare/OrderSearch/OrderLog

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/CustomerCare/OrderSearch/OrderLog?orders_id=789955',
    expected   => {
        page_data => {
          792041 => {
                delivery_signature_log   => [
                                              {
                                                "Date"       => "08-08-2011 12:48",
                                                "Department" => "Customer Care Manager",
                                                "New State"  => "No",
                                                "Operator"   => "Andrew Beech",
                                              },
                                              {
                                                "Date"       => "08-08-2011 12:48",
                                                "Department" => "Customer Care Manager",
                                                "New State"  => "Yes",
                                                "Operator"   => "Andrew Beech",
                                              },
                                            ],
                shipment_item_status_log => [
                                              {
                                                Date => "23-02-11 15:53",
                                                Department => "Distribution Management",
                                                Item => "103420-012",
                                                Operator => "Karen Troast",
                                                Status => "Selected",
                                              },
                                              {
                                                Date => "23-02-11 15:53",
                                                Department => "Distribution Management",
                                                Item => "101264-024",
                                                Operator => "Karen Troast",
                                                Status => "Selected",
                                              },
                                            ],
                shipment_status          => {
                                              "Date" => "23-02-2011 11:40",
                                              "Shipment Class" => "Domestic",
                                              "Shipment Number" => '792041',
                                              "Shipment Type" => "Standard",
                                              "Status" => "Finance Hold",
                                            },
                shipment_status_log      => [
                                              {
                                                Date => "23-02-11 11:45",
                                                Department => "IT",
                                                Operator => "Application",
                                                Status => "Finance Hold",
                                              },
                                              {
                                                Date => "23-02-11 15:06",
                                                Department => "Finance",
                                                Operator => "Eduardo Caviedes",
                                                Status => "Processing",
                                              },
                                              {
                                                Date => "08-08-11 12:48",
                                                Department => "Customer Care Manager",
                                                Operator => "Andrew Beech",
                                                Status => "Finance Hold",
                                              },
                                            ],
          },
          order_status_log => [
            {
              Date => "23-02-11 11:45",
              Department => "IT",
              Operator => "Application",
              Status => "Credit Hold",
            },
            {
              Date => "23-02-11 12:04",
              Department => "Finance",
              Operator => "Teresa Brown",
              Status => "Credit Check",
            },
            {
              Date => "23-02-11 15:06",
              Department => "Finance",
              Operator => "Eduardo Caviedes",
              Status => "Accepted",
            },
            {
              Date => "08-08-11 12:48",
              Department => "Customer Care Manager",
              Operator => "Andrew Beech",
              Status => "Credit Hold",
            },
          ],
        },
    },
);

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en">
    <head>
        <meta http-equiv="Content-type" content="text/html; charset=utf-8">

        <title>Order Search &#8226; Customer Care &#8226; XT-DC2</title>


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
        <script type="text/javascript" src="/jquery/jquery-1.6.1.min.js"></script>
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
           <span>DISTRIBUTION</span><span class="dc">DC2</span>
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
        <img src="/images/model_AM.jpg" width="157" height="87" alt="">
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
                                                <a href="/Admin/ExchangeRates" class="yuimenuitemlabel">Exchange Rates</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/UserAdmin" class="yuimenuitemlabel">User Admin</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/EmailTemplates" class="yuimenuitemlabel">Email Templates</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/ProductSort" class="yuimenuitemlabel">Product Sort</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/JobQueue" class="yuimenuitemlabel">Job Queue</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/CarrierAutomation" class="yuimenuitemlabel">Carrier Automation</a>
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
                                                <a href="/CustomerCare/ReturnsPending" class="yuimenuitemlabel">Returns Pending</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/CustomerCare/OrderSearch" class="yuimenuitemlabel">Order Search</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/CustomerCare/CustomerSearch" class="yuimenuitemlabel">Customer Search</a>
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
                                                <a href="/Finance/CreditHold" class="yuimenuitemlabel">Credit Hold</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Finance/CreditCheck" class="yuimenuitemlabel">Credit Check</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Finance/TransactionReporting" class="yuimenuitemlabel">Transaction Reporting</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Finance/ActiveInvoices" class="yuimenuitemlabel">Active Invoices</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Finance/PendingInvoices" class="yuimenuitemlabel">Pending Invoices</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Finance/StoreCredits" class="yuimenuitemlabel">Store Credits</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Finance/InvalidPayments" class="yuimenuitemlabel">Invalid Payments</a>
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
                                                <a href="/Fulfilment/Selection" class="yuimenuitemlabel">Selection</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/Picking" class="yuimenuitemlabel">Picking</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/Packing" class="yuimenuitemlabel">Packing</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/Dispatch" class="yuimenuitemlabel">Dispatch</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/OnHold" class="yuimenuitemlabel">On Hold</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/DDU" class="yuimenuitemlabel">DDU</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/Airwaybill" class="yuimenuitemlabel">Airwaybill</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/Pre-OrderHold" class="yuimenuitemlabel">Pre-Order Hold</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/Manifest" class="yuimenuitemlabel">Manifest</a>
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
                                                <a href="/StockControl/Inventory" class="yuimenuitemlabel">Inventory</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/PurchaseOrder" class="yuimenuitemlabel">Purchase Order</a>
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
                                                <a href="/StockControl/Quarantine" class="yuimenuitemlabel">Quarantine</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/Cancellations" class="yuimenuitemlabel">Cancellations</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/Measurement" class="yuimenuitemlabel">Measurement</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/FinalPick" class="yuimenuitemlabel">Final Pick</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/DutyRates" class="yuimenuitemlabel">Duty Rates</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/PerpetualInventory" class="yuimenuitemlabel">Perpetual Inventory</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/Location" class="yuimenuitemlabel">Location</a>
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





                    <li><a href="/CustomerCare/OrderSearch/OrderView?order_id=789955" class="last">Back</a></li>


        </ul>

</div>



            <img id="channelTitle" src="/images/logo_NET-A-PORTER_AM.gif" alt="NET-A-PORTER.COM">


        <div id="contentRight">











                    <div id="pageTitle">
                        <h1>Customer Care</h1>
                        <h5>&bull;</h5><h2>Order Search</h2>
                        <h5>&bull;</h5><h3>Order Log</h3>
                    </div>








<span class="title title-NAP">Order Status Log</span><br>
<table id="tbl_order_status_log" width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
	<tr>
		<td colspan="4" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>
	<tr>
		<td class="tableHeader" width="20%">&nbsp;&nbsp;&nbsp;Date</td>
		<td class="tableHeader" width="20%">Status</td>
		<td class="tableHeader" width="20%">Operator</td>
		<td class="tableHeader" width="40%">Department</td>
	</tr>
	<tr>
		<td colspan="4" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>

	<tr>
		<td>&nbsp;&nbsp;&nbsp;23-02-11 11:45</td>
		<td>Credit Hold</td>
		<td>Application</td>
		<td>IT</td>
	</tr>
	<tr>
		<td colspan="4" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>

	<tr>
		<td>&nbsp;&nbsp;&nbsp;23-02-11 12:04</td>
		<td>Credit Check</td>
		<td>Teresa Brown</td>
		<td>Finance</td>
	</tr>
	<tr>
		<td colspan="4" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>

	<tr>
		<td>&nbsp;&nbsp;&nbsp;23-02-11 15:06</td>
		<td>Accepted</td>
		<td>Eduardo Caviedes</td>
		<td>Finance</td>
	</tr>
	<tr>
		<td colspan="4" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>

	<tr>
		<td>&nbsp;&nbsp;&nbsp;08-08-11 12:48</td>
		<td>Credit Hold</td>
		<td>Andrew Beech</td>
		<td>Customer Care Manager</td>
	</tr>
	<tr>
		<td colspan="4" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>

</table>
<br><br>

<span class="title title-NAP">Shipment Status Log</span><br>



<table id="tbl_shipment_status_792041" width="719" cellpadding="0" cellspacing="0" border="0">
	<tr>
		<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>
	<tr height="26">
		<td width="130" align="right"><b>Shipment Number:&nbsp;&nbsp;</td>
		<td width="170">&nbsp;792041</td>
	</tr>
	<tr>
		<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>
	<tr height="26">
		<td align="right"><b>Date:&nbsp;&nbsp;</td>
		<td>&nbsp;23-02-2011  11:40</td>
	</tr>
	<tr>
		<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>
	<tr height="26">
		<td align="right"><b>Shipment Type:&nbsp;&nbsp;</td>
		<td>&nbsp;Standard</td>
	</tr>
	<tr>
		<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>
	<tr height="26">
		<td align="right"><b>Shipment Class:&nbsp;&nbsp;</td>
		<td>Domestic</td>
	</tr>
	<tr>
		<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
		<td><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>
	<tr>
		<td height="26" align="right"><b>Status:&nbsp;&nbsp;</td>
		<td>&nbsp;<span class="highlight">Finance Hold</td>
	</tr>
	<tr>
		<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>
</table>
<br><br>

<table id="tbl_shipment_status_log_792041" width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
	<tr>
		<td colspan="4" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>
	<tr>
		<td class="tableHeader" width="20%">&nbsp;&nbsp;&nbsp;Date</td>
		<td class="tableHeader" width="20%">Status</td>
		<td class="tableHeader" width="20%">Operator</td>
		<td class="tableHeader" width="40%">Department</td>
	</tr>
	<tr>
		<td colspan="4" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>

	<tr>
		<td>&nbsp;&nbsp;&nbsp;23-02-11 11:45</td>
		<td>Finance Hold</td>
		<td>Application</td>
		<td>IT</td>
	</tr>
	<tr>
		<td colspan="4" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>

	<tr>
		<td>&nbsp;&nbsp;&nbsp;23-02-11 15:06</td>
		<td>Processing</td>
		<td>Eduardo Caviedes</td>
		<td>Finance</td>
	</tr>
	<tr>
		<td colspan="4" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>

	<tr>
		<td>&nbsp;&nbsp;&nbsp;08-08-11 12:48</td>
		<td>Finance Hold</td>
		<td>Andrew Beech</td>
		<td>Customer Care Manager</td>
	</tr>
	<tr>
		<td colspan="4" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>

</table>
<br><br>
<span class="highlight"><b>Shipment Item Log</b></span><br>
<br>
<table id="tbl_shipment_item_status_log_792041" width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
	<tr>
		<td colspan="5" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>
	<tr>
		<td class="tableHeader" width="15%">&nbsp;&nbsp;&nbsp;Date</td>
		<td class="tableHeader" width="15%">Item</td>
		<td class="tableHeader" width="20%">Status</td>
		<td class="tableHeader" width="25%">Operator</td>
		<td class="tableHeader" width="25%">Department</td>
	</tr>
	<tr>
		<td colspan="5" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>

	<tr>
		<td>&nbsp;&nbsp;&nbsp;23-02-11 15:53</td>
		<td>103420-012</td>
		<td>Selected</td>
		<td>Karen Troast</td>
		<td>Distribution Management</td>
	</tr>
	<tr>
		<td colspan="5" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>

	<tr>
		<td>&nbsp;&nbsp;&nbsp;23-02-11 15:53</td>
		<td>101264-024</td>
		<td>Selected</td>
		<td>Karen Troast</td>
		<td>Distribution Management</td>
	</tr>
	<tr>
		<td colspan="5" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
	</tr>

</table>
<br />
<br />

<span class="highlight"><strong>Delivery Signature Required Change Log</strong></span><br /><br />
<table id="tbl_delivery_signature_log_792041" width="100%" cellpadding="0" cellspacing="0" border="0" class="wide-data data divided-data">
<thead>
    <tr>
        <th width="25%">Date</th>
        <th width="25%">New State</th>
        <th width="25%">Operator</th>
        <th width="25%">Department</th>
    </tr>
</thead>

    <tr>
        <td>08-08-2011 12:48</td>
        <td>No</td>
        <td>Andrew Beech</td>
        <td>Customer Care Manager</td>
    </tr>

    <tr>
        <td>08-08-2011 12:48</td>
        <td>Yes</td>
        <td>Andrew Beech</td>
        <td>Customer Care Manager</td>
    </tr>

<tbody>
</tbody>
</table>
<br /><br />














        </div>
    </div>

    <p id="footer">    xTracker-DC  (2011.09.04.19.gbc7a087 / IWS phase 0). &copy; 2006 - 2011 NET-A-PORTER
</p>


</div>

    </body>
</html>
