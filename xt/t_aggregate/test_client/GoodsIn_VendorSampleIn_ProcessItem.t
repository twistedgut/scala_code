#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

GoodsIn_VendorSampleIn_ProcessItem.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for Spec:

    GoodsIn/VendorSampleIn/ProcessItem

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    spec       => 'GoodsIn/VendorSampleIn/ProcessItem',
    expected   => {
        'product_data' => {
            'ID' => '3014985',
            'Purchase Order' => {
                'value' => 'test po 15653',
                'url' => '/StockControl/PurchaseOrder/Overview?po_id=15653'
            },
            'Channels' => [
                {
                    'Upload Date' => '-',
                    'Status' => 'Non-Live',
                    'Arrival Date' => '-',
                    'Sales Channel' => 'NET-A-PORTER.COM'
                }
            ],
            'Style Number' => 'Test Style',
            'Size Scheme' => 'Shoes - Italian',
            'Season' => 'Continuity',
            'Description' => 'Rows - [ Name Required ] Test Description',
            'Classification' => 'Clothing / Dresses / Dress',
            'Colour' => 'Black (Black) Code: 102'
        },
        'qc_results' => [
            {
                'Faulty Reason' => {
                    'select_name' => 'fault_reason',
                    'value' => 'Specify a Reason for being Faulty: ---------------------unknownSample (not for re-sale)Marked/StainedTorn/Ripped/ScuffedMissing Part',
                    'select_selected' => [
                        '',
                        '---------------------'
                    ],
                    'select_values' => [
                        [
                            '',
                            '---------------------'
                        ],
                        [
                            '0',
                            'unknown'
                        ],
                        [
                            '1',
                            'Sample (not for re-sale)'
                        ],
                        [
                            '2',
                            'Marked/Stained'
                        ],
                        [
                            '3',
                            'Torn/Ripped/Scuffed'
                        ],
                        [
                            '4',
                            'Missing Part'
                        ]
                    ]
                },
                'Pass' => {
                    'input_name' => 'qc_shipment_item_id',
                    'value' => '',
                    'input_value' => '1'
                },
                'Large' => {
                    'input_name' => 'large_variant_id',
                    'value' => '',
                    'input_value' => undef
                },
                'Size' => 'One size',
                'Small' => {
                    'input_name' => 'small_variant_id',
                    'value' => '',
                    'input_value' => undef
                },
                'Faulty' => {
                    'input_name' => 'qc_shipment_item_id',
                    'value' => '',
                    'input_value' => '2'
                },
                'Quantity' => '1',
                'SKU' => '3014985-005'
            }
        ]
    }
);

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en">
    <head>
        <meta http-equiv="Content-type" content="text/html; charset=utf-8">

        <title>Vendor Sample In &#8226; Goods In &#8226; XT-DC1</title>


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
                Logged in as: <span class="operator_name">DISABLED: IT God</span>
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
                                                <a href="/StockControl/Location" class="yuimenuitemlabel">Location</a>
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
                                                <a href="/StockControl/ChannelTransfer" class="yuimenuitemlabel">Channel Transfer</a>
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





                    <li><a href="/GoodsIn/VendorSampleIn?show_channel=1" class="last">Back to List</a></li>


        </ul>

</div>



            <img id="channelTitle" src="/images/logo_NET-A-PORTER_INTL.gif" alt="NET-A-PORTER.COM">


        <div id="contentRight">











                    <div id="pageTitle">
                        <h1>Vendor Sample</h1>
                        <h5>&bull;</h5><h2>Quality Control</h2>

                    </div>





                    <script type="text/javascript" src="/javascript/showhide.js"></script>
<script language="Javascript">
function enlargeImage(image_path){
	document.getElementById('imagePlaceHolder').innerHTML = '<img src="'+image_path+'">';
	showLayer('enlargeImage', 30, -150, event);
}

function showhide(id) {
	if (document.getElementById) {
		obj = document.getElementById(id);

		if (obj.style.display == "none") {
			obj.style.display = "";
		}
		else {
			obj.style.display = "none";
		}
	}
}
</script>

<span class="title">Product Summary</span><br />
<table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
    <thead>
        <tr class="divideabove dividebelow">
            <td colspan="7" class="tableheader">
                &nbsp;&nbsp;&nbsp;<a href="/StockControl/Inventory/Overview?product_id=3014985">3014985</a>&nbsp;&nbsp;:&nbsp;&nbsp;Rows - [ <em>Name Required</em> ]&nbsp;&nbsp;&nbsp;<i>Test Description</i>
            </td>
        </tr>
    </thead>
    <tbody>
        <tr height="10">
            <td class="blank" colspan="7">&nbsp;</td>
        </tr>
        <tr height="100" valign="top">
            <td class="blank">

                <a href="javascript://" onClick="enlargeImage('http://cache.net-a-porter.com/images/products/3014985/3014985_in_dl.jpg')"><img class="product" width="120" src="http://cache.net-a-porter.com/images/products/3014985/3014985_in_m.jpg"></a>
            </td>
            <td class="blank"><img src="/images/blank.gif" width="10" height="1"></td>
            <td class="blank">
                <a href="javascript://" onClick="enlargeImage('http://cache.net-a-porter.com/images/products/3014985/3014985_bk_dl.jpg')"><img class="product" width="56" src="http://cache.net-a-porter.com/images/products/3014985/3014985_bk_xs.jpg"></a>
                <br clear="all">
                <a href="javascript://" onClick="enlargeImage('http://cache.net-a-porter.com/images/products/3014985/3014985_cu_dl.jpg')"><img class="product" width="56" src="http://cache.net-a-porter.com/images/products/3014985/3014985_cu_xs.jpg" style="margin-top:10px"></a>
            </td>
            <td class="blank"><img src="/images/blank.gif" width="25" height="1"></td>
            <td class="blank" colspan="3">

                <table cellpadding="0" cellspacing="0" width="100%" style="margin-bottom:17px">
                    <tr>
                        <td width="47%" class="blank">
                            <table class="data wide-data divided-data">
                                <tr>
                                    <td align="right"><b>Style Number:</b>&nbsp;</td>
                                    <td>Test Style</td>
                                </tr>
                                <tr>
                                    <td align="right"><b>Season:</b>&nbsp;</td>
                                    <td>Continuity</td>
                                </tr>
                                <tr>
                                    <td align="right"><b>Colour:</b>&nbsp;</td>
                                    <td>

                                            Black

                                        &nbsp;

                                            (Black)



                                            &nbsp;&nbsp;Code: 102

                                    </td>
                                </tr>
                            </table>
                        </td>
                        <td width="6%" class="blank"></td>
                        <td width="47%" class="blank">
                            <table class="data wide-data divided-data">
                                <tr>
                                    <td align="right"><b>Size Scheme:</b>&nbsp;</td>
                                    <td>Shoes - Italian</td>
                                </tr>
                                <tr>
                                    <td align="right"><b>Classification:</b>&nbsp;</td>
                                    <td>Clothing / Dresses / Dress</td>
                                </tr>
                                <tr>
                                    <td align="right"><b>Purchase Order:</b>&nbsp;</td>
                                    <td>


                                            <a href="/StockControl/PurchaseOrder/Overview?po_id=15653">test po 15653</a> &nbsp; &nbsp; <br />



                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>
                </table>
                <br />

                <table class="data wide-data divided-data">
                    <thead>
                        <tr>
                            <th>Sales Channel</th>
                            <th>Status</th>
                            <th>Arrival Date</th>
                            <th>Upload Date</th>
                            <th>&nbsp;</th>
                        </tr>
                    </thead>
                    <tbody>

                        <tr>
                            <td><span class="title title-NAP" style="line-height: 1em;">NET-A-PORTER.COM</span></td>
                            <td>

                                    <span class="lowlight">Non-Live</span>



                            </td>
                            <td>-</td>
                            <td>-</td>
                            <td><img src="/images/icons/bullet_green.png" title="Active" alt="Active"></td>
                        </tr>

                    </tbody>
                </table>

             </td>
        </tr>
        <tr height="10">
            <td class="blank" colspan="3" align="center"><span class="lowlight">Click on images to enlarge</span></td>
            <td class="blank" colspan="4" align="right" style="padding-top:3px">

<div style="width:90px">

        <a href="#" style="text-decoration: none" onclick="showhide('hideShow_new_comment'); return(false);">
            <img src="/images/icons/add.png" style="float:left; margin-right:3px">Add Comment
        </a>

</div></td>
        </tr>
    </tbody>
</table>

<br /><br />

<div id="enlargeImage" style="visibility:hidden; position:absolute; left:0px; top:0px; z-index:1000; padding-left:3px; padding-bottom:3px; background-color: #cccccc">

    <div style="border:1px solid #666666; background-color: #fff; padding: 10px; z-index:1001">

        <div align="right" style="margin-bottom:5px"><a href="javascript://" onClick="hideLayer('enlargeImage');">Close</a></div>
        <div id="imagePlaceHolder"></div>
    </div>
</div>


<div style="display:none; margin-top:5px;" id="hideShow_new_comment">
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
    <form method="post" action="/StockControl/Inventory/SetProductComments">
    <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="27580162">

    <input type="hidden" name="product_id" value="3014985" />
        <thead>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
            <tr height="24">
                <td width="15%" class="tableheader">&nbsp;&nbsp;Operator</td>
                <td width="20%" class="tableheader">Department</td>
                <td width="20%" class="tableheader">Date</td>
                <td width="40%" class="tableheader">Comment</td>
                <td width="5%" class="tableheader"></td>
            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
        </thead>
        <tbody>
            <tr height="24">
                <td width="15%">&nbsp;&nbsp;<input type="text" name="op" value="DISABLED: IT God" size="12" readonly="readonly" /></td>
                <td width="20%"><input type="text" name="dep" value="" size="20" readonly="readonly" /></td>
                <td width="20%"><input type="text" name="dat" value="05-01-2011 15:17" size="17" readonly="readonly" /></td>
                <td width="40%"><input type="text" name="comment" value="" size="50" /></a></td>
                <td width="5%"></td>
            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
            <tr>
                <td colspan="5" class="blank"><img src="/images/blank.gif" width="1" height="7"></td>
            </tr>
            <tr>
                <td colspan="5" class="blank" align="right"><input class="button" type="submit" name="submit" value="Submit &raquo;" /></td>
            </tr>

        </tbody>
    </form>
    </table>
    <br /><br />
</div>

<div id="productComments" style="margin-bottom:15px; display:none">
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
        <tr>
            <td class="blank"><span class="title">Product Comments (0)</span></td>
            <td class="blank" align="right"></td>
        </tr>
        <tr>
            <td colspan="5" class="divider"></td>
        </tr>
    </table>

    <div style="display: none;" id="hideShow_comments">
        <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
            <thead>
            <tr height="24">
                <td width="15%" class="tableheader">&nbsp;&nbsp;Operator</td>
                <td width="20%" class="tableheader">Department</td>
                <td width="20%" class="tableheader">Date</td>
                <td width="40%" class="tableheader">Comment</td>
                <td width="5%" class="tableheader"></td>
            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
            </thead>
            <tbody>

            </tbody>
        </table>
    </div>
    <br /><br />
</div>


<div id="main_form">
<span class="title title-NAP">Return Product</span>
<form name="f_form" action="/GoodsIn/VendorSampleIn/BookIn" method="post">
	<input type="hidden" name="psku" value="3014985-005" />
	<input type="hidden" name="channel_id" value="1" />

    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
        <thead>
            <tr>
                <td colspan="7" class="dividerHeader"></td>
            </tr>
			<tr>
				<td colspan="3" class="tableHeader">&nbsp;</td>
				<td colspan="2" align="center" class="tableHeader">Product Quality</td>
				<td colspan="2" align="center" class="tableHeader">Print Labels</td>
			</tr>
            <tr height="24">
                <td width="20%" class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;
SKU</td>
                <td width="15%" class="tableHeader">Size</td>
                <td width="15%" class="tableHeader" align="center">Quantity</td>
                <td width="8%" class="tableHeader" align="center">Pass</td>
                <td width="8%" class="tableHeader" align="center">Faulty</td>
                <td width="8%" class="tableHeader" align="center">Large</td>
                <td width="8%" class="tableHeader" align="center">Small</td>
            </tr>
            <tr>
                <td colspan="7" class="dividerHeader"></td>
            </tr>
        </thead>
        <tbody>
            <tr height="20">
                <td class="">&nbsp;&nbsp;&nbsp;&nbsp;
3014985-005</td>
                <td>One size</td>
                <td align="center">1</td>
                <td align="center"><input type='radio' name='qc_shipment_item_id' value='1' onclick='javascript:switch_fault_reasons(this.value);' /></td>
                <td align="center"><input type='radio' name='qc_shipment_item_id' value='2' onclick='javascript:switch_fault_reasons(this.value);' /></td>
                <td align="center"><input type='checkbox' name='large_variant_id' checked='checked' /></td>
                <td align="center"><input type='checkbox' name='small_variant_id' checked='checked' /></td>
            </tr>
			<tr height="34" id="faulty_reason" style="display: none;">
				<td colspan="5" align="right"><strong>Specify a Reason for being Faulty:&nbsp;</strong>
					<select name="fault_reason">
						<option value="">---------------------</option>

						<option value="0">unknown</option>

						<option value="1">Sample (not for re-sale)</option>

						<option value="2">Marked/Stained</option>

						<option value="3">Torn/Ripped/Scuffed</option>

						<option value="4">Missing Part</option>

					</select>
				</td>
				<td colspan="2">&nbsp;</td>
			</tr>
            <tr><td colspan="7" class="dividerHeader"></td></tr>
        </tbody>
    </table>
	<br/>
	<table width="100%" cellpadding="0" cellspacing="0" border="0">
    <tbody>
        <tr height="24">
            <td align="right"><input type="submit" name="submit" class="button" value="Submit &raquo;"></td>
        </tr>
    </tbody>
</table>



	<input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="27580162">

</form>
</div>
<script language="javascript" type="text/javascript">

	function switch_fault_reasons (xvalue) {

		if ( xvalue == 2 ) {
			document.getElementById('faulty_reason').style.display	= '';
		}
		else {
			document.getElementById('faulty_reason').style.display	= 'none';
		}
	}

</script>




        </div>
    </div>

    <p id="footer">    xTracker-DC (2010.26.03.10.gb08c4a0). &copy; 2006 - 2011 NET-A-PORTER
</p>


</div>

    </body>
</html>
