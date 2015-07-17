#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

CustomerCare_ConfirmAddress_SelectShippingOption.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for Spec:

    CustomerCare/OrderSearch/ConfirmAddress_SelectShippingOption

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    # Note: example HTML doesn't contain all possible options
    content    => (join '', (<DATA>)),
    spec       => 'CustomerCare/OrderSearch/ConfirmAddress_SelectShippingOption',
    expected   => {
        current_address => {
            'Address Line 1'          => 'DC2, 725 Darlington Avenue',
            'Address Line 2'          => 'Mahwah',
            'Country'                 => 'United States',
            'County'                  => 'NY',
            'Current Address'         => '',
            'Current Shipping Option' => '',
            'Delivery Option'         => '',
            'First Name'              => 'some',
            'Nom Delivery Date'       => '',
            'Postcode'                => '11371',
            'Shipping Option'         => 'New York Metro Area Same Day',
            'Surname'                 => 'one',
            'Town/City'               => 'New Jersey',
            'Unknown'                 => [''],
        },
        new_address => {
            'Address Line 1'    => 'al1',
            'Address Line 2'    => 'al2',
            'Country'           => 'United States',
            'County'            => 'NY',
            'Delivery Option'   => '',
            'First Name'        => 'some',
            'Nom Delivery Date' => '',
            'Postcode'          => '10010',
            'Shipping Option'   => '',
            'Surname'           => 'one',
            'Town/City'         => 'New York',
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
        <script type="text/javascript" src="/jquery/jquery-1.7.min.js"></script>
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
                Logged in as: <span class="operator_name">Johan Lindstrom</span>
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
                                                <a href="/Fulfilment/InvalidShipments" class="yuimenuitemlabel">Invalid Shipments</a>
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





                    <li><a href="/CustomerCare/OrderSearch/OrderView?order_id=138" class="last">Back</a></li>


        </ul>

</div>



            <img id="channelTitle" src="/images/logo_NET-A-PORTER_AM.gif" alt="NET-A-PORTER.COM">



        <div id="contentRight">












                    <div id="pageTitle">
                        <h1>Customer Care</h1>
                        <h5>&bull;</h5><h2>Order Search</h2>
                        <h5>&bull;</h5><h3>Edit Shipping Address</h3>
                    </div>





                    <script type="text/javascript">
<!--
    function validateAddress(){

        var country = document.editAddress.country.options[document.editAddress.country.selectedIndex].value;
        var state   = document.editAddress.county.value;

        if ( country == 'United States' && state == '' ){
            alert("Please enter a State for all United States addresses to allow for the calculation of shipping costs.");
            return false;
        }
        else {
            return true;
        }
    }

//-->

</script>








            <table id="edit_address_form" width="100%" cellpadding="0" cellspacing="0" border="0" class="data">



                <form name="editAddress" action="/CustomerCare/OrderSearch/EditAddress" method="post" onSubmit="return validateAddress()">
                <input type="hidden" name="edit_address" value="1">



            <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1931%3AZ9vgxGgAX0CtLCVVrXSrdg">

            <input type="hidden" name="address_type" value="Shipping">
            <input type="hidden" name="order_id" value="138">

            <input type="hidden" name="shipment_id" value="69">

            <input type="hidden" name="first_name" value="some">
            <input type="hidden" name="last_name" value="one">
            <input type="hidden" name="address_line_1" value="al1">
            <input type="hidden" name="address_line_2" value="al2">
            <input type="hidden" name="address_line_3" value="al3">
            <input type="hidden" name="towncity" value="New York">
            <input type="hidden" name="county" value="NY">

            <input type="hidden" name="postcode" value="10010">
            <input type="hidden" name="country" value="United States">

                <tr>
                            <td colspan="2" class="blank"><span class="title title-NAP">Current Address</span></td>
                            <td class="blank" width="10%"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="blank"><span class="title title-NAP">New Address</span></td>
                 </tr>

                <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                 </tr>
                <tr>
                            <td width="15%" align="right"><b>First Name:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;some</td>

                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td width="15%" align="right"><b>First Name:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;some</td>
                    </tr>
                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>

                    </tr>
                <tr>
                            <td width="15%" align="right"><b>Surname:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;one</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td width="15%" align="right"><b>Surname:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;one</td>

                    </tr>
                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>
                <tr>
                            <td width="10%" align="right"><b>Address Line 1:&nbsp;&nbsp;</td>

                            <td width="30%">&nbsp;DC2, 725 Darlington Avenue</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td width="10%" align="right"><b>Address Line 1:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;al1</td>
                    </tr>
                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>

                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>
                    <tr>
                            <td width="10%" align="right"><b>Address Line 2:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;Mahwah</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td width="10%" align="right"><b>Address Line 2:&nbsp;&nbsp;</td>

                            <td width="30%">&nbsp;al2</td>
                     </tr>
                     <tr>
                        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                        <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                     </tr>
                <tr>

                            <td width="10%" align="right"><b>Town/City:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;New Jersey</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td width="10%" align="right"><b>Town/City:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;New York</td>
                    </tr>
                    <tr>

                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>
                <tr>
                            <td width="10%" align="right"><b>County:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;NY</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>

                            <td width="10%" align="right"><b>County:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;NY</td>
                    </tr>
                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>

                <tr>
                            <td width="10%" align="right"><b>Postcode:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;11371</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td width="10%" align="right"><b>Postcode:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;10010</td>
                        </tr>

                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>
                <tr>
                            <td width="10%" align="right"><b>Country:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;United States</td>

                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td width="10%" align="right"><b>Country:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;United States</td>
                    </tr>
                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>

                    </tr>



                    <tr>
                            <td class="blank" colspan="2"><img src="/images/blank.gif" width="1" height="8"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank" colspan="2"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>
                    <tr>
                            <td colspan="2" class="blank"><span class="title title-NAP">Current Shipping Option</span></td>

                            <td class="blank" width="10%"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="blank"><span class="title title-NAP">New Shipping Option</span></td>
                    </tr>

                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>

                    <tr>
                            <td width="15%" align="right"><b>Shipping Option:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;New York Metro Area Same Day</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>

                            <td width="15%" align="right"><b>Shipping Option:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;</td>
                    </tr>

                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>
                    <tr>
                            <td width="15%" align="right"><b>Nom Delivery Date:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;</td>

                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>

                            <td width="15%" align="right"><b>Nom Delivery Date:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;</td>
                    </tr>
                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>

                    </tr>
                    <tr>
                            <td width="15%" align="right"><b>Delivery Option:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>

                            <td width="15%" align="right"><b>Delivery Option:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;</td>

                    </tr>


            </table>




            <br><br>









            <br><br>

            <table width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>


                    <td align="right"><input type="submit" name="submit" class="button" value="Confirm Changes &raquo;">
</td>
                </tr>
            </table>
            <br><br>

            </form>





<br><br><br><br>



        </div>
    </div>

    <p id="footer">    xTracker-DC  (2012.03.00.53.g9932455 / IWS phase 0 / 2012-02-24 17:01:47). &copy; 2006 - 2012 NET-A-PORTER
</p>


</div>

    </body>

</html>