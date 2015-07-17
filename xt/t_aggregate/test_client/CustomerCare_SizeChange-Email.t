#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

CustomerCare_SizeChange-Email.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /CustomerCare/CustomerSearch/SizeChange

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/CustomerCare/CustomerSearch/SizeChange?order_id=1300662&shipment_id=1379494',
    expected   => {
        size_change_form => {
            hidden_input => {
                name => 'status',
                value => '10'
            },
            action => '/CustomerCare/OrderSearch/ChangeShipmentItem?order_id=1300662&shipment_id=1379494',
            method => 'post',
            name => 'sizeChangeForm',
            select_items => [ {
                SKU => '77141-012',
                select_item => undef,
                change_to => undef,
                name => 'Crystal-embellished oversized T-shirt',
                size => 'small',
                stock_discrepancy => undef
            }
                          ]
        }
    }
);

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en"><head>


        <meta http-equiv="Content-type" content="text/html;
charset=UTF-8">

        <title>Order Search • Customer Care • XT-DC1</title>


        <link rel="shortcut icon"
href="http://xtdc1-frank:8529/favicon.ico">



        <!-- Core Javascript -->
        <script type="text/javascript" src="SizeChange-email_files/common.js"></script>
        <script type="text/javascript" src="SizeChange-email_files/xt_navigation.js"></script>
        <script type="text/javascript" src="SizeChange-email_files/form_validator.js"></script>
        <script type="text/javascript" src="SizeChange-email_files/validate.js"></script>
        <script type="text/javascript" src="SizeChange-email_files/comboselect.js"></script>
        <script type="text/javascript" src="SizeChange-email_files/date.js"></script>

        <!-- Custom Javascript -->





        <!-- YUI majik -->
        <script type="text/javascript" src="SizeChange-email_files/yahoo-dom-event.js"></script>
        <script type="text/javascript" src="SizeChange-email_files/container_core-min.js"></script>
        <script type="text/javascript" src="SizeChange-email_files/menu-min.js"></script>
        <script type="text/javascript" src="SizeChange-email_files/animation.js"></script>
        <!-- dialog dependencies -->
        <script type="text/javascript" src="SizeChange-email_files/element-min.js"></script>
        <!-- Scripts -->
        <script type="text/javascript" src="SizeChange-email_files/utilities.js"></script>
        <script type="text/javascript" src="SizeChange-email_files/container-min.js"></script>
        <script type="text/javascript" src="SizeChange-email_files/yahoo-min.js"></script>
        <script type="text/javascript" src="SizeChange-email_files/dom-min.js"></script>
        <script type="text/javascript" src="SizeChange-email_files/element-min.js"></script>

        <script type="text/javascript" src="SizeChange-email_files/datasource-min.js"></script>
        <script type="text/javascript" src="SizeChange-email_files/datatable-min.js"></script>
        <script type="text/javascript" src="SizeChange-email_files/tabview-min.js"></script>
        <script type="text/javascript" src="SizeChange-email_files/slider-min.js"></script>
        <!-- Connection Dependencies -->
        <script type="text/javascript" src="SizeChange-email_files/event-min.js"></script>
        <script type="text/javascript" src="SizeChange-email_files/connection-min.js"></script>
        <!-- YUI Autocomplete sources -->
        <script type="text/javascript" src="SizeChange-email_files/autocomplete-min.js"></script>

        <!-- calendar -->
        <script type="text/javascript" src="SizeChange-email_files/calendar.js"></script>
        <!-- Custom YUI widget -->
        <script type="text/javascript" src="SizeChange-email_files/Editable.js"></script>
        <!-- CSS -->
        <link rel="stylesheet" type="text/css"
href="SizeChange-email_files/grids-min.css">
        <link rel="stylesheet" type="text/css"
href="SizeChange-email_files/button.css">
        <link rel="stylesheet" type="text/css"
href="SizeChange-email_files/datatable.css">
        <link rel="stylesheet" type="text/css"
href="SizeChange-email_files/tabview.css">
        <link rel="stylesheet" type="text/css"
href="SizeChange-email_files/menu.css">
        <link rel="stylesheet" type="text/css"
href="SizeChange-email_files/container.css">
        <link rel="stylesheet" type="text/css"
href="SizeChange-email_files/autocomplete.css">
        <link rel="stylesheet" type="text/css"
href="SizeChange-email_files/calendar.css">

        <!-- (end) YUI majik -->






        <!-- Custom CSS -->


        <!-- Core CSS
            Placing these here allows us to override YUI styles if we want
            to, but still have extra/custom CSS below to override the default XT
            styles
        -->
        <link rel="stylesheet" type="text/css" media="screen"
href="SizeChange-email_files/xtracker.css">
        <link rel="stylesheet" type="text/css" media="screen"
href="SizeChange-email_files/xtracker_static.css">
        <link rel="stylesheet" type="text/css" media="screen"
href="SizeChange-email_files/customer.css">
        <link rel="stylesheet" type="text/css" media="print"
href="SizeChange-email_files/print.css">

        <!--[if lte IE 7]>
          <link rel="stylesheet" type="text/css" href="/css/xtracker_ie.css">
        <![endif]-->
        <!--[if lte IE 6]>
          <link rel="stylesheet" type="text/css" href="/css/xtracker_ie6.css">
        <![endif]-->




    </head><body class="yui-skin-sam"><iframe style="position: absolute;
 visibility: visible; width: 2em; height: 2em; top: -37px; left: 0pt;
border-width: 0pt;" title="Text Resize Monitor" id="_yuiResizeMonitor"></iframe>
        <div id="container">

    <div id="header">
    <div id="headerTop">
        <div id="headerLogo">
           <img src="SizeChange-email_files/logo_small.gif"
alt="xTracker">
           <span>DISTRIBUTION</span><span class="dc">DC1</span>
        </div>

            <div id="headerControls">
                Logged in as: <span>DISABLED: IT God</span>
                <a href="http://xtdc1-frank:8529/My/Messages"
class="messages"><img src="SizeChange-email_files/email_open.png"
alt="Messages" title="No New Messages" height="16" width="16"></a>
                <a href="http://xtdc1-frank:8529/Logout">Logout</a>
            </div>

        <select
onchange="location.href=this.options[this.selectedIndex].value">
            <option selected="selected" value="">Go to...</option>
            <optgroup label="Management">
                <option value="http://fulcrum.net-a-porter.com/">Fulcrum</option>
            </optgroup>
            <optgroup label="Distribution">
                <option value="http://xtracker.net-a-porter.com">DC1</option>
                <option value="http://xt-us.net-a-porter.com">DC2</option>
            </optgroup>
            <optgroup label="Other">
                <option value="http://xt-jchoo.net-a-porter.com">Jimmy
Choo</option>
            </optgroup>
        </select>
    </div>

    <div id="headerBottom">
        <img src="SizeChange-email_files/model_INTL.jpg" alt=""
height="87" width="157">
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
<div style="z-index: 2; position: static; display: block; visibility:
visible;" id="nav1" class="yuimenubar yuimenubarnav yui-module
yui-overlay visible">

        <div class="bd">
            <ul class="first-of-type">

                    <li index="0" groupindex="0" id="yui-gen0"
class="yuimenubaritem first-of-type"><a
href="http://xtdc1-frank:8529/Home" class="yuimenubaritemlabel">Home</a></li>




                        <li index="1" groupindex="0" id="yui-gen2"
class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#yui-gen1"
class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Admin</a>
                            <div style="z-index: 2; position: absolute;
visibility: hidden;" id="yui-gen1" class="yuimenu yui-module yui-overlay
 hide-scrollbars yui-overlay-hidden">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Admin/EmailTemplates"
class="yuimenuitemlabel">Email Templates</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Admin/UserAdmin" class="yuimenuitemlabel">User
 Admin</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Admin/ExchangeRates"
class="yuimenuitemlabel">Exchange Rates</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Admin/ProductSort"
class="yuimenuitemlabel">Product Sort</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Admin/JobQueue" class="yuimenuitemlabel">Job
 Queue</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li index="2" groupindex="0" id="yui-gen4"
class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#yui-gen3"
class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Customer Care</a>
                            <div style="z-index: 2; position: absolute;
visibility: hidden;" id="yui-gen3" class="yuimenu yui-module yui-overlay
 hide-scrollbars yui-overlay-hidden">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/CustomerCare/CustomerSearch"
class="yuimenuitemlabel">Customer Search</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/CustomerCare/OrderSearch"
class="yuimenuitemlabel">Order Search</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/CustomerCare/ReturnsPending"
class="yuimenuitemlabel">Returns Pending</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li index="3" groupindex="0" id="yui-gen6"
class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#yui-gen5"
class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Finance</a>
                            <div style="z-index: 2; position: absolute;
visibility: hidden;" id="yui-gen5" class="yuimenu yui-module yui-overlay
 hide-scrollbars yui-overlay-hidden">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Finance/ActiveInvoices"
class="yuimenuitemlabel">Active Invoices</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Finance/CreditCheck"
class="yuimenuitemlabel">Credit Check</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Finance/CreditHold"
class="yuimenuitemlabel">Credit Hold</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Finance/InvalidPayments"
class="yuimenuitemlabel">Invalid Payments</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Finance/PendingInvoices"
class="yuimenuitemlabel">Pending Invoices</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Finance/StoreCredits"
class="yuimenuitemlabel">Store Credits</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Finance/TransactionReporting"
class="yuimenuitemlabel">Transaction Reporting</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Finance/FraudHotlist"
class="yuimenuitemlabel">Fraud Hotlist</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li index="4" groupindex="0" id="yui-gen8"
class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#yui-gen7"
class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Fulfilment</a>
                            <div style="z-index: 2; position: absolute;
visibility: hidden;" id="yui-gen7" class="yuimenu yui-module yui-overlay
 hide-scrollbars yui-overlay-hidden">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Fulfilment/Airwaybill"
class="yuimenuitemlabel">Airwaybill</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Fulfilment/DDU" class="yuimenuitemlabel">DDU</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Fulfilment/Dispatch"
class="yuimenuitemlabel">Dispatch</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Fulfilment/InvalidShipments"
class="yuimenuitemlabel">Invalid Shipments</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Fulfilment/Labelling"
class="yuimenuitemlabel">Labelling</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Fulfilment/Manifest"
class="yuimenuitemlabel">Manifest</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Fulfilment/OnHold"
class="yuimenuitemlabel">On Hold</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Fulfilment/Packing"
class="yuimenuitemlabel">Packing</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Fulfilment/Picking"
class="yuimenuitemlabel">Picking</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Fulfilment/Selection"
class="yuimenuitemlabel">Selection</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Fulfilment/Pre-OrderHold"
class="yuimenuitemlabel">Pre-Order Hold</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Fulfilment/PremierRouting"
class="yuimenuitemlabel">Premier Routing</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Fulfilment/PackingException"
class="yuimenuitemlabel">Packing Exception</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li index="5" groupindex="0" id="yui-gen10"
class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#yui-gen9"
class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Goods In</a>
                            <div style="z-index: 2; position: absolute;
visibility: hidden;" id="yui-gen9" class="yuimenu yui-module yui-overlay
 hide-scrollbars yui-overlay-hidden">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/GoodsIn/StockIn" class="yuimenuitemlabel">Stock
 In</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/GoodsIn/ItemCount"
class="yuimenuitemlabel">Item Count</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/GoodsIn/QualityControl"
class="yuimenuitemlabel">Quality Control</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/GoodsIn/BagAndTag"
class="yuimenuitemlabel">Bag And Tag</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/GoodsIn/Putaway" class="yuimenuitemlabel">Putaway</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/GoodsIn/ReturnsArrival"
class="yuimenuitemlabel">Returns Arrival</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/GoodsIn/ReturnsIn"
class="yuimenuitemlabel">Returns In</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/GoodsIn/ReturnsQC"
class="yuimenuitemlabel">Returns QC</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/GoodsIn/ReturnsFaulty"
class="yuimenuitemlabel">Returns Faulty</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/GoodsIn/Barcode" class="yuimenuitemlabel">Barcode</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/GoodsIn/DeliveryCancel"
class="yuimenuitemlabel">Delivery Cancel</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/GoodsIn/DeliveryHold"
class="yuimenuitemlabel">Delivery Hold</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/GoodsIn/DeliveryTimetable"
class="yuimenuitemlabel">Delivery Timetable</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/GoodsIn/RecentDeliveries"
class="yuimenuitemlabel">Recent Deliveries</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/GoodsIn/Surplus" class="yuimenuitemlabel">Surplus</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/GoodsIn/VendorSampleIn"
class="yuimenuitemlabel">Vendor Sample In</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li index="6" groupindex="0" id="yui-gen12"
class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#yui-gen11"
class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">NAP Events</a>
                            <div style="z-index: 2; position: absolute;
visibility: hidden;" id="yui-gen11" class="yuimenu yui-module
yui-overlay hide-scrollbars yui-overlay-hidden">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/NAPEvents/Manage" class="yuimenuitemlabel">Manage</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li index="7" groupindex="0" id="yui-gen14"
class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#yui-gen13"
class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Outnet Events</a>
                            <div style="z-index: 2; position: absolute;
visibility: hidden;" id="yui-gen13" class="yuimenu yui-module
yui-overlay hide-scrollbars yui-overlay-hidden">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/OutnetEvents/Manage"
class="yuimenuitemlabel">Manage</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li index="8" groupindex="0" id="yui-gen16"
class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#yui-gen15"
class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Reporting</a>
                            <div style="z-index: 2; position: absolute;
visibility: hidden;" id="yui-gen15" class="yuimenu yui-module
yui-overlay hide-scrollbars yui-overlay-hidden">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Reporting/DistributionReports"
class="yuimenuitemlabel">Distribution Reports</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Reporting/StockConsistency"
class="yuimenuitemlabel">Stock Consistency</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Reporting/ShippingReports"
class="yuimenuitemlabel">Shipping Reports</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li index="9" groupindex="0" id="yui-gen18"
class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#yui-gen17"
class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Retail</a>
                            <div style="z-index: 2; position: absolute;
visibility: hidden;" id="yui-gen17" class="yuimenu yui-module
yui-overlay hide-scrollbars yui-overlay-hidden">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Retail/AttributeManagement"
class="yuimenuitemlabel">Attribute Management</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li index="10" groupindex="0" id="yui-gen20"
class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#yui-gen19"
class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">RTV</a>
                            <div style="z-index: 2; position: absolute;
visibility: hidden;" id="yui-gen19" class="yuimenu yui-module
yui-overlay hide-scrollbars yui-overlay-hidden">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/RTV/FaultyGI" class="yuimenuitemlabel">Faulty
 GI</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/RTV/InspectPick" class="yuimenuitemlabel">Inspect
 Pick</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/RTV/RequestRMA" class="yuimenuitemlabel">Request
 RMA</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/RTV/ListRMA" class="yuimenuitemlabel">List
 RMA</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/RTV/ListRTV" class="yuimenuitemlabel">List
 RTV</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/RTV/PickRTV" class="yuimenuitemlabel">Pick
 RTV</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/RTV/PackRTV" class="yuimenuitemlabel">Pack
 RTV</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/RTV/AwaitingDispatch"
class="yuimenuitemlabel">Awaiting Dispatch</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/RTV/DispatchedRTV"
class="yuimenuitemlabel">Dispatched RTV</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/RTV/NonFaulty" class="yuimenuitemlabel">Non
 Faulty</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li index="11" groupindex="0" id="yui-gen22"
class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#yui-gen21"
class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Sample</a>
                            <div style="z-index: 2; position: absolute;
visibility: hidden;" id="yui-gen21" class="yuimenu yui-module
yui-overlay hide-scrollbars yui-overlay-hidden">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Sample/ReviewRequests"
class="yuimenuitemlabel">Review Requests</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Sample/SampleCart"
class="yuimenuitemlabel">Sample Cart</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Sample/SampleTransfer"
class="yuimenuitemlabel">Sample Transfer</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/Sample/SampleCartUsers"
class="yuimenuitemlabel">Sample Cart Users</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li index="12" groupindex="0" id="yui-gen24"
class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#yui-gen23"
class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Stock Control</a>
                            <div style="z-index: 2; position: absolute;
visibility: hidden;" id="yui-gen23" class="yuimenu yui-module
yui-overlay hide-scrollbars yui-overlay-hidden">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/StockControl/Cancellations"
class="yuimenuitemlabel">Cancellations</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/StockControl/DutyRates"
class="yuimenuitemlabel">Duty Rates</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/StockControl/FinalPick"
class="yuimenuitemlabel">Final Pick</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/StockControl/Inventory"
class="yuimenuitemlabel">Inventory</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/StockControl/Location"
class="yuimenuitemlabel">Location</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/StockControl/Measurement"
class="yuimenuitemlabel">Measurement</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/StockControl/PerpetualInventory"
class="yuimenuitemlabel">Perpetual Inventory</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/StockControl/ProductApproval"
class="yuimenuitemlabel">Product Approval</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/StockControl/PurchaseOrder"
class="yuimenuitemlabel">Purchase Order</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/StockControl/Quarantine"
class="yuimenuitemlabel">Quarantine</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/StockControl/Reservation"
class="yuimenuitemlabel">Reservation</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/StockControl/Sample"
class="yuimenuitemlabel">Sample</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/StockControl/StockCheck"
class="yuimenuitemlabel">Stock Check</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/StockControl/StockRelocation"
class="yuimenuitemlabel">Stock Relocation</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/StockControl/ChannelTransfer"
class="yuimenuitemlabel">Channel Transfer</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/StockControl/DeadStock"
class="yuimenuitemlabel">Dead Stock</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li index="13" groupindex="0" id="yui-gen26"
class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#yui-gen25"
class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Web Content</a>
                            <div style="z-index: 2; position: absolute;
visibility: hidden;" id="yui-gen25" class="yuimenu yui-module
yui-overlay hide-scrollbars yui-overlay-hidden">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/WebContent/DesignerLanding"
class="yuimenuitemlabel">Designer Landing</a>
                                            </li>

                                            <li class="menuitem">
                                                <a
href="http://xtdc1-frank:8529/WebContent/Magazine"
class="yuimenuitemlabel">Magazine</a>
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





                    <li><a
href="http://xtdc1-frank:8529/CustomerCare/OrderSearch/OrderView?order_id=1300662"
 class="last">Back</a></li>


        </ul>

</div>



            <img id="channelTitle"
src="SizeChange-email_files/logo_NET-A-PORTER_INTL.gif"
alt="NET-A-PORTER.COM">


        <div id="contentRight">











                    <div id="pageTitle">
                        <h1>Customer Care</h1>
                        <h5>•</h5><h2>Order Search</h2>
                        <h5>•</h5><h3>Size Change</h3>
                    </div>







    <span class="title title-NAP">Changed Item(s)</span><br>

    <form name="sizeChangeForm"
action="/CustomerCare/OrderSearch/ChangeShipmentItem?order_id=1300662&amp;shipment_id=1379494"
 method="post">
    <input name="status" value="10" type="hidden">
    <input name="channel_config" value="NAP" type="hidden">
    <table class="data" width="100%" border="0" cellpadding="0"
cellspacing="0">
    <input id="dbl_submit_token" name="dbl_submit_token" value="24799755" type="hidden">

        <tbody><tr>
            <td colspan="5" class="dividerHeader"><img
src="SizeChange-email_files/blank.gif" height="1" width="1"></td>
        </tr>
        <tr height="24">
            <td class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
            <td class="tableHeader">Name</td>
            <td class="tableHeader">Size</td>
            <td class="tableHeader">New SKU</td>
            <td class="tableHeader">New Size</td>
        </tr>
        <tr>
            <td colspan="5" class="dividerHeader"><img
src="SizeChange-email_files/blank.gif" height="1" width="1"></td>
        </tr>




                <tr height="24">
                    <td>&nbsp;&nbsp;&nbsp;<a href="javascript://"
onclick="window.open('/OrderTracker/ViewImages/11861','viewimage','width=230,height=345,scrollbars=no');"
 class="noline">77141-012</a></td>
                    <td>Crystal-embellished oversized T-shirt</td>
                    <td>small</td>
                    <td>77141-011</td>
                    <td>x small</td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"><img
src="SizeChange-email_files/blank.gif" height="1" width="1"></td>
                </tr>
                <input name="item-3175481" value="1" type="hidden">
                <input name="exch-3175481" value="484496_x
small_77141-011" type="hidden">
                <input name="discrep-3175481" value="0" type="hidden">





    </tbody></table>

    <br><br>

    <span class="title title-NAP">Customer Email</span><br>

    <table class="data" width="100%" border="0" cellpadding="0"
cellspacing="0">
        <tbody><tr>
            <td colspan="2" class="divider"></td>
        </tr>
        <tr height="24">
            <td width="149" align="right"><b>Send Email:</b>&nbsp;&nbsp;</td>
            <td width="570"><input name="send_email" value="yes"
type="radio">&nbsp;&nbsp;Yes&nbsp;&nbsp;&nbsp;&nbsp;<input
checked="checked" name="send_email" value="no" type="radio">&nbsp;&nbsp;No</td>
        </tr>
        <tr>
            <td colspan="2" class="divider"></td>
        </tr>
        <tr height="30">
            <td align="right"><b>To:</b>&nbsp;&nbsp;</td>
            <td><input size="35" name="email_to"
value="d63343ae7061ed60f6c0c5607a" type="text"></td>
        </tr>
        <tr>
            <td colspan="2" class="divider"></td>
        </tr>
        <tr height="30">
            <td align="right"><b>From:</b>&nbsp;&nbsp;</td>
            <td><input size="35" name="email_from"
value="customercare@net-a-porter.com" type="text"></td>
        </tr>
        <tr>
            <td colspan="2" class="divider"></td>
        </tr>
        <tr height="30">
            <td align="right"><b>Reply-To:</b>&nbsp;&nbsp;</td>
            <td><input size="35" name="email_replyto"
value="customercare@net-a-porter.com" type="text"></td>
        </tr>
        <tr>
            <td colspan="2" class="divider"></td>
        </tr>
        <tr height="30">
            <td align="right"><b>Subject:</b>&nbsp;&nbsp;</td>
            <td><input size="35" name="email_subject" value="Your order -
 1168979" type="text"></td>
        </tr>
        <tr>
            <td colspan="2" class="divider"></td>
        </tr>
        <tr>
            <td colspan="2" height="10"></td>
        </tr>
        <tr valign="top">
            <td align="right"><b>Email Text:&nbsp;&nbsp;</b></td>
            <td><textarea name="email_body" rows="15" cols="80">Dear
28e008c,

Thank you for your email requesting a size change for the following
items(s):

MICHAEL Michael Kors Crystal-embellished oversized T-shirt Size: small


We have now amended the size(s) as follows:

MICHAEL Michael Kors Crystal-embellished oversized T-shirt Size: x small


Kind regards,

Customer Care
www.net-a-porter.com</textarea></td>
        </tr>
        <tr>
            <td colspan="2" height="10"></td>
        </tr>
        <tr>
            <td colspan="2" class="divider"></td>
        </tr>
        <tr>
            <td class="blank" colspan="2"><img
src="SizeChange-email_files/blank.gif" height="15" width="1"></td>
        </tr>
        <tr>
            <td class="blank" colspan="2" align="right"><input
name="submit" value="SUBMIT &gt;" class="button" type="submit"></td>
        </tr>

    </tbody></table>
    </form>


<br>
<br>





        </div>
    </div>

    <p id="footer">    xTracker-DC (2010.23.01.71.g1e3ce1a). © 2006 -
2010 NET-A-PORTER
</p>


</div>

    </body></html>
