#!/usr/bin/env perl

use NAP::policy "tt", 'test';
# TODO: find a way of getting this test to
#       pass with 'utf8' left on
no utf8;

=head1 NAME

CustomerCare_PreOrderSummary.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /StockControl/Reservation/PreOrder/Summary

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/StockControl/Reservation/PreOrder/Summary?pre_order_id=2',
    expected   => {
        cancel_pre_order_button => 'Cancel All Items',
        cancel_pre_order_item_button => 'Cancel Selected Items',
        log_pre_order_item_status => [
          {
            Date => '2012-05-18 @ 16:25:40',
            Department => 'IT',
            Operator => 'Application',
            SKU => '1-863',
            Status => 'Complete'
          },
          {
            Date => '2012-05-18 @ 16:25:40',
            Department => 'IT',
            Operator => 'Application',
            SKU => '2-863',
            Status => 'Complete'
          },
          {
            Date => '2012-05-18 @ 16:25:40',
            Department => 'IT',
            Operator => 'Application',
            SKU => '3-863',
            Status => 'Complete'
          },
          {
            Date => '2012-05-18 @ 16:25:40',
            Department => 'IT',
            Operator => 'Application',
            SKU => '4-863',
            Status => 'Complete'
          },
          {
            Date => '2012-05-18 @ 16:25:40',
            Department => 'IT',
            Operator => 'Application',
            SKU => '5-863',
            Status => 'Complete'
          },
          {
            Date => '2012-05-18 @ 16:25:43',
            Department => 'IT',
            Operator => 'Application',
            SKU => '2-863',
            Status => 'Cancelled'
          },
          {
            Date => '2012-05-18 @ 16:25:43',
            Department => 'IT',
            Operator => 'Application',
            SKU => '4-863',
            Status => 'Exported'
          },
          {
            Date => '2012-05-18 @ 16:25:43',
            Department => 'IT',
            Operator => 'Application',
            SKU => '5-863',
            Status => 'Exported'
          }
        ],
        log_pre_order_status => [
          {
            Date => '2012-05-18 @ 16:25:41',
            Department => 'IT',
            Operator => 'Application',
            Status => 'Complete'
          },
          {
            Date => '2012-05-18 @ 16:25:43',
            Department => 'IT',
            Operator => 'Application',
            Status => 'Part Exported'
          }
        ],
        pre_order_item_list => [
          {
            CancelItem => {
              input_name => 'item_to_cancel_6',
              input_value => '1',
              value => ''
            },
            Designer => "R\xc3\xa9publique \xe2\x9c\xaa Ceccarelli",
            DesignerSize => 'None/Unknown',
            Duty => "\xa310.00",
            Price => "\xa3100.00",
            ProductName => 'Name',
            SKU => '1-863',
            Status => 'Complete',
            Tax => "\xa35.00",
            Total => "\xa3115.00"
          },
          {
            CancelItem => '',
            Designer => "R\xc3\xa9publique \xe2\x9c\xaa Ceccarelli",
            DesignerSize => 'None/Unknown',
            Duty => "\xa320.00",
            Price => "\xa3200.00",
            ProductName => 'Name',
            SKU => '2-863',
            Status => 'Cancelled',
            Tax => "\xa310.00",
            Total => "\xa3230.00"
          },
          {
            CancelItem => {
              input_name => 'item_to_cancel_8',
              input_value => '1',
              value => ''
            },
            Designer => "R\xc3\xa9publique \xe2\x9c\xaa Ceccarelli",
            DesignerSize => 'None/Unknown',
            Duty => "\xa330.00",
            Price => "\xa3300.00",
            ProductName => 'Name',
            SKU => '3-863',
            Status => 'Complete',
            Tax => "\xa315.00",
            Total => "\xa3345.00"
          },
          {
            CancelItem => '',
            Designer => "R\xc3\xa9publique \xe2\x9c\xaa Ceccarelli",
            DesignerSize => 'None/Unknown',
            Duty => "\xa340.00",
            Price => "\xa3400.00",
            ProductName => 'Name',
            SKU => '4-863',
            Status => 'Exported',
            Tax => "\xa320.00",
            Total => "\xa3460.00"
          },
          {
            CancelItem => '',
            Designer => "R\xc3\xa9publique \xe2\x9c\xaa Ceccarelli",
            DesignerSize => 'None/Unknown',
            Duty => "\xa350.00",
            Price => "\xa3500.00",
            ProductName => 'Name',
            SKU => '5-863',
            Status => 'Exported',
            Tax => "\xa325.00",
            Total => "\xa3575.00"
          }
        ],
        pre_order_total => '1,495.00'
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


            <script type="text/javascript" src="/javascript/reservations.js"></script>




        <!-- Custom CSS -->

            <link rel="stylesheet" type="text/css" href="/css/reservations.css">


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
                <span class="operator_name">Andrew Beech</span>
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

                                            <li class="menuitem">
                                                <a href="/Finance/Reimbursements" class="yuimenuitemlabel">Reimbursements</a>
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





                    <li><a href="/StockControl/Reservation" class="last">Summary</a></li>




                        <li><span>Overview</span></li>



                    <li><a href="/StockControl/Reservation/Overview?view_type=Upload">Upload</a></li>

                    <li><a href="/StockControl/Reservation/Overview?view_type=Pending">Pending</a></li>

                    <li><a href="/StockControl/Reservation/Overview?view_type=Waiting" class="last">Waiting List</a></li>




                        <li><span>View</span></li>



                    <li><a href="/StockControl/Reservation/Listing?list_type=Live&show=Personal">Live Reservations</a></li>

                    <li><a href="/StockControl/Reservation/Listing?list_type=Pending&show=Personal">Pending Reservations</a></li>

                    <li><a href="/StockControl/Reservation/Listing?list_type=Waiting&show=Personal" class="last">Waiting Lists</a></li>




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



            <img id="channelTitle" src="/images/logo_NET-A-PORTER_INTL.gif" alt="NET-A-PORTER.COM">


        <div id="contentRight">












                    <div id="pageTitle">
                        <h1>Reservation</h1>
                        <h5>&bull;</h5><h2>Customer</h2>
                        <h5>&bull;</h5><h3>Pre Order Summary</h3>
                    </div>





                    <div id="common__customer_details">
    <h3 class="title-NAP">Customer</h3>
    <b>Name:</b> Joe Bloggs<br>
    <b>Number:</b> 2<br>
    <br>
    <hr>
</div>

<div id="summary__page_options_secton">
    <form id="summary__page_options_form" action="Basket" method="get">
        <input type="hidden" id="summary__page_options__pre_order_id" name="pre_order_id" value="2">
        <input class="summary__options_form_input" type="hidden" id="summary__page_options__shipment_address_id" name="shipment_address_id" value="2">
        <input class="summary__options_form_input" type="hidden" id="summary__page_options__invoice_address_id" name="invoice_address_id" value="2">
        <input type="hidden" name="reservation_source_id" value="">

        <input type="hidden" name="variants" value="9">

        <input type="hidden" name="variants" value="1">

        <input type="hidden" name="variants" value="3">

        <input type="hidden" name="variants" value="5">

        <input type="hidden" name="variants" value="7">

        <div id="summary__shipment_details_box" class="faint_bordered_box">
            <h3 class="title-NAP">Shipment Details</h3>
            <div id="summary__shipment_option">
                Select the shipment option:
                <select class="summary__options_form_input" name="shipment_option_id" id="packaging_type">

                    <option  value="4">UK Express</option>

                </select>
            </div>
            <div id="shipment_address__on_screen_text">
                some one,<br>
                DC1, Unit 3, Charlton Gate Business Park,<br>
                Anchor and Hope Lane,<br>
                LONDON, SE7 7RU,<br>
                London,<br>
                BN1 9RF<br>
                United Kingdom<br>
            </div>
            <button type="button" id="summary__shipment_address_button" class="button address_popup__shipment_address_button">Use Different Address</button>
        </div>
        <div id="summary__invoice_address_box" class="faint_bordered_box">
            <h3 class="title-NAP">Invoice Address</h3>
            <div id="summary__invoice_address">
                <div id="invoice_address__on_screen_text">
                    some one,<br>
                    DC1, Unit 3, Charlton Gate Business Park,<br>
                    Anchor and Hope Lane,<br>
                    LONDON, SE7 7RU,<br>
                    London,<br>
                    BN1 9RF<br>
                    United Kingdom<br>
                </div>
            </div>
        </div>
        <div id="basket__contact_details_box" class="faint_bordered_box">
            <h3 class="title-NAP">Contact Details</h3>
            <div id="basket__contact_details" style="display: inline-block;">
                <table>
                    <tr>
                        <td><strong>Phone day:&nbsp;</strong></td>
                        <td>+44 (0) 20 7255 4590</td>
                    </tr>
                    <tr>
                        <td><strong>Phone evening:&nbsp;</strong></td>
                        <td></td>
                    </tr>
                </table>
            </div>
            <br clear="all" />
        </div>
    </form>
    <hr>
</div>
<div id="summary__variants_section">
    <form name="summary__complete_pre_order_form" id="summary__complete_pre_order_form" method="post" action="CancelPreOrder">
        <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="73%3Ah6UaYFOY2gos%2FPoB4QERLA">

        <input type="hidden" name="pre_order_id" value="2">
        <h3 class="title-NAP">Selected Products</h3>
        <div id="summary__variants_table">
            <table class="data wide-data" id="summary__variants_table">
                <thead>
                    <tr>
                        <th></th>
                        <th>SKU</th>
                        <th>Product<br>Name</th>
                        <th>Designer</th>
                        <th>Designer<br>Size</th>
                        <th>Price</th>
                        <th>Duty</th>
                        <th>Tax</th>
                        <th>Total</th>
                        <th>Status</th>
                        <th>Cancel<br>Item</th>
                    </tr>
                </thead>
                <tbody>
                                    <tr class="dividebelow">
                        <td  align="center"><img width="50" src="http://cache.net-a-porter.com/images/products/1/1_in_m.jpg"></td>
                        <td >1-863</td>
                        <td >Name</td>
                        <td >République ✪ Ceccarelli</td>
                        <td >None/Unknown</td>
                        <td class="item_cost">&pound;100.00</td>
                        <td class="item_cost">&pound;10.00</td>
                        <td class="item_cost">&pound;5.00</td>
                        <td class="item_cost">&pound;115.00</td>
                        <td >Complete</td>
                        <td  align="center"><input name="item_to_cancel_6" type="checkbox" value="1"></td>
                    </tr>
                                    <tr class="dividebelow">
                        <td class='show_cancelled' align="center"><img width="50" src="http://cache.net-a-porter.com/images/products/2/2_in_m.jpg"></td>
                        <td class='show_cancelled'>2-863</td>
                        <td class='show_cancelled'>Name</td>
                        <td class='show_cancelled'>République ✪ Ceccarelli</td>
                        <td class='show_cancelled'>None/Unknown</td>
                        <td class='show_cancelled'>&pound;200.00</td>
                        <td class='show_cancelled'>&pound;20.00</td>
                        <td class='show_cancelled'>&pound;10.00</td>
                        <td class='show_cancelled'>&pound;230.00</td>
                        <td class='show_cancelled'>Cancelled</td>
                        <td class='show_cancelled' align="center"></td>
                    </tr>
                                    <tr class="dividebelow">
                        <td  align="center"><img width="50" src="http://cache.net-a-porter.com/images/products/3/3_in_m.jpg"></td>
                        <td >3-863</td>
                        <td >Name</td>
                        <td >République ✪ Ceccarelli</td>
                        <td >None/Unknown</td>
                        <td class="item_cost">&pound;300.00</td>
                        <td class="item_cost">&pound;30.00</td>
                        <td class="item_cost">&pound;15.00</td>
                        <td class="item_cost">&pound;345.00</td>
                        <td >Complete</td>
                        <td  align="center"><input name="item_to_cancel_8" type="checkbox" value="1"></td>
                    </tr>
                                    <tr class="dividebelow">
                        <td  align="center"><img width="50" src="http://cache.net-a-porter.com/images/products/4/4_in_m.jpg"></td>
                        <td >4-863</td>
                        <td >Name</td>
                        <td >République ✪ Ceccarelli</td>
                        <td >None/Unknown</td>
                        <td class="item_cost">&pound;400.00</td>
                        <td class="item_cost">&pound;40.00</td>
                        <td class="item_cost">&pound;20.00</td>
                        <td class="item_cost">&pound;460.00</td>
                        <td >Exported</td>
                        <td  align="center"></td>
                    </tr>
                                    <tr class="dividebelow">
                        <td  align="center"><img width="50" src="http://cache.net-a-porter.com/images/products/5/5_in_m.jpg"></td>
                        <td >5-863</td>
                        <td >Name</td>
                        <td >République ✪ Ceccarelli</td>
                        <td >None/Unknown</td>
                        <td class="item_cost">&pound;500.00</td>
                        <td class="item_cost">&pound;50.00</td>
                        <td class="item_cost">&pound;25.00</td>
                        <td class="item_cost">&pound;575.00</td>
                        <td >Exported</td>
                        <td  align="center"></td>
                    </tr>

                </tbody>
            </table>
        </div>
        <br>
        <div id="summary__payment_due_status">
            Total Value: &pound;<span id="payment_due__current__text">1,495.00</span>
        </div>
        <div id="summary__action_forms">

            <button type="submit" class="button" name="cancel_pre_order" id="summary__cancel_pre_order_button" value="1">Cancel All Items</button>
            <button type="submit" class="button" name="cancel_items" id="summary__cancel_pre_order_item_button" value="1">Cancel Selected Items</button>

        </div>
    </form>
    <hr>
</div>


<div id="summary__status_logs_wrapper">
    <table class="data wide-data">
        <tr class="dividebelow">
            <td style="padding-left: 0px; margin-left: 0px;"><h3 class="title-NAP">Status Logs</h3></td>
            <td align="right" style="padding-right:15px"><img class="summary__toggle" id="summary__status_logs_toggle" src="/images/icons/zoom_in.png" alt="Status Logs" /></td>
        </tr>
    </table>
    <div id="summary__status_logs" style="display:none;">

        <h3>Pre-Order Status Log</h3>
        <table id="summary__status_log_pre_order" class="data wide-data">
        <thead>
            <tr>
                <th></th>
                <th>Date</th>
                <th>Status</th>
                <th>Operator</th>
                <th>Department</th>
            </tr>
        </thead>
        <tbody>

            <tr class="dividebelow">
                <td></td>
                <td>2012-05-18 @ 16:25:41</td>
                <td>Complete</td>
                <td>Application</td>
                <td>IT</td>
            </tr>

            <tr class="dividebelow">
                <td></td>
                <td>2012-05-18 @ 16:25:43</td>
                <td>Part Exported</td>
                <td>Application</td>
                <td>IT</td>
            </tr>

        </tbody>
        </table>
        <br/>


        <h3>Pre-Order Items Status Log</h3>
        <table id="summary__status_log_pre_order_items" class="data wide-data">
        <thead>
            <tr>
                <th></th>
                <th>Date</th>
                <th>SKU</th>
                <th>Status</th>
                <th>Operator</th>
                <th>Department</th>
            </tr>
        </thead>
        <tbody>

            <tr class="dividebelow">
                <td></td>
                <td>2012-05-18 @ 16:25:40</td>
                <td>1-863</td>
                <td>Complete</td>
                <td>Application</td>
                <td>IT</td>
            </tr>

            <tr class="dividebelow">
                <td></td>
                <td>2012-05-18 @ 16:25:40</td>
                <td>2-863</td>
                <td>Complete</td>
                <td>Application</td>
                <td>IT</td>
            </tr>

            <tr class="dividebelow">
                <td></td>
                <td>2012-05-18 @ 16:25:40</td>
                <td>3-863</td>
                <td>Complete</td>
                <td>Application</td>
                <td>IT</td>
            </tr>

            <tr class="dividebelow">
                <td></td>
                <td>2012-05-18 @ 16:25:40</td>
                <td>4-863</td>
                <td>Complete</td>
                <td>Application</td>
                <td>IT</td>
            </tr>

            <tr class="dividebelow">
                <td></td>
                <td>2012-05-18 @ 16:25:40</td>
                <td>5-863</td>
                <td>Complete</td>
                <td>Application</td>
                <td>IT</td>
            </tr>

            <tr class="dividebelow">
                <td></td>
                <td>2012-05-18 @ 16:25:43</td>
                <td>2-863</td>
                <td>Cancelled</td>
                <td>Application</td>
                <td>IT</td>
            </tr>

            <tr class="dividebelow">
                <td></td>
                <td>2012-05-18 @ 16:25:43</td>
                <td>4-863</td>
                <td>Exported</td>
                <td>Application</td>
                <td>IT</td>
            </tr>

            <tr class="dividebelow">
                <td></td>
                <td>2012-05-18 @ 16:25:43</td>
                <td>5-863</td>
                <td>Exported</td>
                <td>Application</td>
                <td>IT</td>
            </tr>

        </tbody>
        </table>

    <hr>
    </div>
</div>


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
<div id="address_popup__new_address_section">
    <h3 class="title-NAP">New  Address</h3>
    <div class="address_popup__new_address_input_fields">
        <input type="hidden" class="new_address__form" id="new_address__pre_order_id" value="2">
        <table class="data wide-data" name="new_address">
            <tr class="dividebelow divideabove">
                <td><p class="new_address__field_required">First Name*</p></td>
                <td><input type="text" class="new_address__form" value="" id="new_address__first_name"></td>
            </tr>
            <tr class="dividebelow">
                <td><p class="new_address__field_required">Last Name*</p></td>
                <td><input type="text" class="new_address__form" value="" id="new_address__last_name"></td>
            </tr>
            <tr class="dividebelow">
                <td><p class="new_address__field_required">Address Line 1*</p></td>
                <td><input type="text" class="new_address__form" value="" id="new_address__address_line_1"></td>
            </tr>
            <tr class="dividebelow">
                <td>Address Line 2</td>
                <td><input type="text" class="new_address__form" value="" id="new_address__address_line_2"></td>
            </tr>
            <tr class="dividebelow">
                <td><p class="new_address__field_required">City*</p></td>
                <td><input type="text" class="new_address__form" value="" id="new_address__towncity"></td>
            </tr>
            <tr class="dividebelow">
                <td><p class="new_address__field_required">Postcode*</p></td>
                <td><input type="text" class="new_address__form" value="" id="new_address__postcode"></td>
            </tr>
            <tr class="dividebelow">
                <td>County</td>
                <td><input type="text" class="new_address__form" value="" id="new_address__county"></td>
            </tr>
            <tr class="dividebelow">
                <td><p class="new_address__field_required">Country*</p></td>
                <td>
                    <select class="new_address__form" id="new_address__country">

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

                        <option value="Mexico" >Mexico</option>

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
        </table>
        <p>
        * These fields are required
        </p>
    </div>
    <div id="address_popup__new_address_options">
        <input type="checkbox" class="new_address__form" id="new_address__use_for_both"> Use for both Shipment and Invoice.
    </div>
    <div id="address_popup__new_address_buttons">
        <input type="submit" id="address_popup__new_address_cancel_button" class="address_popup__cancel_button button" value="Cancel">
        <input type="submit" id="address_popup__new_address_save_button" class="button" value="Add New Address">
    </div>
</div>

</div>
<!-- here be no popups -->




        </div>
    </div>

    <p id="footer">    xTracker-DC  (2012.06.01.52.g5e4d26b / IWS phase 2 / 2012-05-18 16:02:36). &copy; 2006 - 2012 NET-A-PORTER
</p>


</div>

    </body>
</html>
