#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

CustomerCare_CustomerView.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /CustomerCare/CustomerSearch/CustomerView

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/CustomerCare/CustomerSearch/CustomerView?customer_id=365260',
    expected   => {
        new_high_value => '',
        new_high_value_image => '/images/icons/tick.png',
        page_data => {
          contact_options => {
            data => {
              'Premier Delivery Notification' => {
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
            title => 'Order Contact Options'
          },
          customer_details => [
            {
              Category => 'None',
              'Customer Number' => '1',
              Email => 'perl@net-a-porter.com',
              Name => 'Test-forename Test-surname',
              Title => 'Ms'
            }
          ],
          customer_options => {
            data => {
              'New High Value' => [
                {
                  input_checked => 0,
                  input_name => 'marketing_high_value',
                  input_type => 'checkbox',
                  input_value => undef,
                  input_readonly => 0,
                  value => ''
                },
                ''
              ],
              'No Marketing Contact' => [
                {
                  input_checked => 0,
                  input_name => 'marketing_contact',
                  input_type => 'checkbox',
                  input_value => '2month',
                  input_readonly => 0,
                  value => 'For the next two months'
                },
                {
                  input_checked => 0,
                  input_name => 'marketing_contact',
                  input_type => 'checkbox',
                  input_value => 'forever',
                  input_readonly => 0,
                  value => 'Forever'
                }
              ]
            },
            title => 'Marketing Options'
          },
          customer_value => {
            data => [],
            title => 'Customer Value'
          },
          inv_address_history => {
            data => {
              Country => 'United Kingdom',
              'County/State' => '',
              'Order Number' => '1000000001',
              Postcode => 'd6a31',
              'Street Address' => 'al1',
              'Town/City' => 'twn'
            },
            title => 'Invoice Address History'
          },
          order_history => {
            data => [
              {
                Date => '21-12-2011 15:08',
                'Order Number' => {
                  url => '/CustomerCare/OrderSearch/OrderView?order_id=2',
                  value => '1000000001'
                },
                Status => 'Accepted',
                'Total Value' => 'GBP 360.000'
              }
            ],
            title => 'Order History'
          },
          returns_history => {
            data => [
              {
                Date => '21-12-2011 15:27',
                'Order Number' => {
                  url => '/CustomerCare/OrderSearch/OrderView?order_id=2',
                  value => '1000000001'
                },
                'RMA Number' => {
                  url => '/CustomerCare/OrderSearch/EditReturn/2/1/2',
                  value => 'R1-1'
                },
                'Shipment Number' => '1',
                Status => 'Complete'
              }
            ],
            title => 'Returns History'
          },
          ship_address_history => {
            data => {
              Country => 'United Kingdom',
              'County/State' => '',
              'Order Number' => '1000000001',
              Postcode => 'd6a31',
              'Shipment Number' => '1',
              'Street Address' => 'al1',
              'Town/City' => 'twn'
            },
            title => 'Shipping Address History'
          }
        }
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





                    <li><a href="javascript:history.go(-1)">Back</a></li>

                    <li><a href="/CustomerCare/OrderSearch/Note?parent_id=1&note_category=Customer&sub_id=1">Add Note</a></li>

                    <li><a href="javascript:void window.open('http://eg01-pr-dc1.london.net-a-porter.com/system/web/view/platform/agent/info/custhist/Custom_Customer_history_NAP/getCustomerCaseNap.jsp?email_address=perl@net-a-porter.com');" class="last">Contact History</a></li>




                        <li><span>View Type</span></li>



                    <li><a href="/CustomerCare/OrderSearch/CustomerView?customer_id=1">Summary</a></li>

                    <li><a href="/CustomerCare/OrderSearch/CustomerView?customer_id=1&view_type=Full" class="last">Full Details</a></li>


        </ul>

</div>



            <img id="channelTitle" src="/images/logo_NET-A-PORTER_INTL.gif" alt="NET-A-PORTER.COM">


        <div id="contentRight">











                        <p class="error_msg" style="white-space: pre">Unable to query website for store credit information: Error connecting to 127.0.0.1:61613: IO::Socket::INET: connect: Connection refused at /opt/xt/xt-perl/lib/site_perl/5.14.2/Net/Stomp.pm line 100.
                        </p>


                    <div id="pageTitle">
                        <h1>Customer Care</h1>
                        <h5>&bull;</h5><h2>Order Search</h2>
                        <h5>&bull;</h5><h3>Customer View</h3>
                    </div>








	<script language="javascript" type="text/javascript">

        function toggle_view( section ) {

            var elem = document.getElementById( section );
            var link = document.getElementById("lnk"+section);

            if (elem.style.display=='none' || !elem.style.display){
                elem.style.display = "block";
                if (link.style){
                    link.innerHTML="Hide";
                }
            }
            else {
                elem.style.display = "none";
                if (link.style){
                    link.innerHTML="View";
                }
            }
        }

	</script>

    <form name="marketingForm" action="/CustomerCare/OrderSearch/UpdateCustomer" method="post">
    <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="59%3Adz5yPrzXSmf6Q3%2B5a%2Bpruw">

    <input type="hidden" name="customer_id" value="1">
	<span class="title title-NAP">Customer Details</span><br />
	<table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="tbl_customer_details">
		<tr>
			<td colspan="5" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
		</tr>
		<tr>
			<td class="tableHeader" width="20%">&nbsp;&nbsp;&nbsp;Customer Number</td>
			<td class="tableHeader" width="10%">Title</td>
			<td class="tableHeader" width="20%">Name</td>
			<td class="tableHeader" width="30%">Email</td>
            <td class="tableHeader" width="20%">Category</td>
		</tr>
		<tr>
			<td colspan="5" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
		</tr>
		<tr>
			<td>&nbsp;&nbsp;&nbsp;1</td>
			<td>Ms</td>
			<td>Test-forename Test-surname</td>
			<td>perl@net-a-porter.com</td>
            <td>

					None

			</td>
		</tr>
		<tr>
			<td colspan="5" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
		</tr>

		<tr>
			<td colspan="5" class="blank"><img src="/images/blank.gif" width="1" height="7"></td>
		</tr>
	</table><br />
    </form>




	<table width="100%" cellpadding="0" cellspacing="0" border="0" id="tbl_customer_value">
		<tr>
			<td colspan="2" class="blank"><img src="/images/blank.gif" width="1" height="25"></td>
		</tr>
		<tr>
			<td class="blank"><span class="title title-NAP">Customer Value</span></td>
			<td class="blank" align="right"><a href="javascript:toggle_view('customer_value');"><span id="lnkcustomer_value">View</span></a></td>
		</tr>
		<tr>
			<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
		</tr>
	</table>

	<div id="customer_value" style="display:none; width: 94%; margin-left: 3%; margin-right: 3%;"></div>
    <br/>







        <table width="100%" cellpadding="0" cellspacing="0" border="0" id="tbl_contact_options">
            <tr>
                <td colspan="2" class="blank"><img src="/images/blank.gif" width="1" height="25"></td>
            </tr>
            <tr>
                <td class="blank"><span class="title title-NAP">Order Contact Options</span></td>
                <td class="blank" align="right"><a href="javascript:toggle_view('contact_options');"><span id="lnkcontact_options">View</span></a></td>
            </tr>
            <tr>
                <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            </tr>
        </table>

        <div id="contact_options" style="display:none">
        <form name="contactOptions" action="/CustomerCare/OrderSearch/UpdateCustomer" method="post">
            <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="59%3Adz5yPrzXSmf6Q3%2B5a%2Bpruw">

            <input type="hidden" name="customer_id" value="1" />
            <table class="data wide-data">
                <tr class="dividebelow">
    <td width="25%" valign="middle"><strong>Premier Delivery Notification:</strong></td>
    <td><input type="hidden" name="csm_subject_1" value="1" />                <input type="checkbox" name="csm_subject_method_1" value="1" checked="checked" />SMS&nbsp;&nbsp;&nbsp;                <input type="checkbox" name="csm_subject_method_1" value="2" checked="checked" />Email&nbsp;&nbsp;&nbsp;                <input type="checkbox" name="csm_subject_method_1" value="3"  />Phone&nbsp;&nbsp;&nbsp;    </td>
</tr>

                <tr>
                    <td colspan="2" class="blank">
                        <span><strong>Any changes to the above will also update the same options on any Un-Dispatched Orders for the Customer</strong></span>
                    </td>
                </tr>
                <tr>
                    <td class="blank" colspan="2" align="right"><input type="submit" name="update_contact_options" class="button" value="Submit &raquo;">
</td>
                </tr>

            </table>
        </form>
        <br/>
        </div>


	<table width="100%" cellpadding="0" cellspacing="0" border="0" id="tbl_customer_options">
		<tr>
			<td colspan="2" class="blank"><img src="/images/blank.gif" width="1" height="25"></td>
		</tr>
		<tr>
			<td class="blank"><span class="title title-NAP">Marketing Options</span></td>
			<td class="blank" align="right"><a
			href="javascript:toggle_view('customer_options');"><span id="lnkcustomer_options">View</span></a></td>
		</tr>
		<tr>
			<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
		</tr>
	</table>

	<div id="customer_options">
    <form name="customerOptions" action="/CustomerCare/OrderSearch/UpdateCustomer" method="post">
    <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="59%3Adz5yPrzXSmf6Q3%2B5a%2Bpruw">

    <input type="hidden" name="customer_id" value="1">
	<table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
		<tr>
			<td width="22%" align="right"><b>&nbsp;&nbsp;&nbsp;No Marketing Contact:&nbsp;&nbsp;&nbsp;</td>
			<td width="29%"><input type="checkbox" name="marketing_contact" value="2month" >For the next two months</td>
			<td width="49%"><input type="checkbox" name="marketing_contact" value="forever">Forever</td>
		</tr>
		<tr>
			<td width="22%" align="right"><b>&nbsp;&nbsp;&nbsp;New High Value:&nbsp;&nbsp;&nbsp;</td>
			<td width="29%">
				<img id="marketing_high_value_image" src="/images/icons/tick.png" alt="Yes" title="Yes" />
				<input type="checkbox" id="marketing_high_value" name="marketing_high_value">
			</td>
			<td width="49%"></td>
		</tr>
		<tr>
			<td colspan="3" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
		</tr>
		<tr>
			<td class="blank" colspan="3"><img src="/images/blank.gif" width="1" height="10"></td>
		</tr>
		<tr>
			<td class="blank" colspan="3" align="right"><input type="submit" name="update_marketing_options" class="button" value="Submit &raquo;">
</td>
		</tr>
	</table>
    </form>
	<br>
	</div>

	<table width="100%" cellpadding="0" cellspacing="0" border="0" id="tbl_order_history">
		<tr>
			<td colspan="2" class="blank"><img src="/images/blank.gif" width="1" height="25"></td>
		</tr>
		<tr>
			<td class="blank"><span class="title title-NAP">Order History</span></td>
			<td class="blank" align="right"><a href="javascript:toggle_view('order_history');"><span id="lnkorder_history">View</span></a></td>
		</tr>
		<tr>
			<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
		</tr>
	</table>

	<div id="order_history" style="display:none">




		<table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
			<tr>
				<td class="tableHeader" width="20%">&nbsp;&nbsp;&nbsp;Order Number</td>
				<!--<td class="tableHeader" width="20%">Sales Channel</td>-->
                <td class="tableHeader" width="20%">Date</td>
				<td class="tableHeader" width="20%">Total Value</td>
				<td class="tableHeader" width="20%">Status</td>
			</tr>
			<tr>
				<td colspan="4" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
			</tr>


				<tr>
					<td>&nbsp;&nbsp;&nbsp;<a href="/CustomerCare/OrderSearch/OrderView?order_id=2">1000000001</a></td>
					<!--<td>NET-A-PORTER.COM</td>-->
                    <td>21-12-2011  15:08</td>
					<td>GBP&nbsp;360.000</td>
					<td>Accepted</td>
				</tr>
				<tr>
					<td colspan="4" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
				</tr>

			<tr>
				<td colspan="4" class="blank"><img src="/images/blank.gif" width="1" height="20"></td>
			</tr>
		</table>



	</div>



	<table width="100%" cellpadding="0" cellspacing="0" border="0" id="tbl_returns_history">
		<tr>
			<td colspan="2" class="blank"><img src="/images/blank.gif" width="1" height="25"></td>
		</tr>
		<tr>
			<td class="blank"><span class="title title-NAP">Returns History</span></td>
			<td class="blank" align="right"><a href="javascript:toggle_view('returns_history');"><span id="lnkreturns_history">View</span></a></td>
		</tr>
		<tr>
			<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
		</tr>
	</table>

	<div id="returns_history" style="display:none">



		<table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
			<tr>
				<td class="tableHeader" width="17%">&nbsp;&nbsp;&nbsp;RMA Number</td>
				<td class="tableHeader" width="17%">Shipment Number</td>
				<td class="tableHeader" width="17%">Order Number</td>
                <!--<td class="tableHeader" width="17%">Sales Channel</td>-->
				<td class="tableHeader" width="17%">Date</td>
				<td class="tableHeader" width="17%">Status</td>
			</tr>
			<tr>
				<td colspan="5" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
			</tr>




						<tr>
							<td>&nbsp;&nbsp;&nbsp;<a href="/CustomerCare/OrderSearch/EditReturn/2/1/2">R1-1</a></td>
							<td>1</td>
							<td>&nbsp;&nbsp;&nbsp;<a href="/CustomerCare/OrderSearch/OrderView?order_id=2">1000000001</a></td>
							<!--<td>NET-A-PORTER.COM</td>-->
                            <td>21-12-2011  15:27</td>
							<td>Complete</td>
						</tr>
						<tr>
							<td colspan="5" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
						</tr>



			<tr>
				<td colspan="5" class="blank"><img src="/images/blank.gif" width="1" height="20"></td>
			</tr>
		</table>
		<br>
		<br>



	</div>


	<table width="100%" cellpadding="0" cellspacing="0" border="0" id="tbl_inv_address_history">
		<tr>
			<td colspan="2" class="blank"><img src="/images/blank.gif" width="1" height="25"></td>
		</tr>
		<tr>
			<td class="blank"><span class="title title-NAP">Invoice Address History</span></td>
			<td class="blank" align="right"><a href="javascript:toggle_view('inv_address_history');"><span id="lnkinv_address_history">View</span></a></td>
		</tr>
		<tr>
			<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
		</tr>
	</table>

	<div id="inv_address_history" style="display:none">


		<table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
			<tr>
				<td width="25%" align="right"><b>Order Number:&nbsp;&nbsp;</td>
				<td width="75%">&nbsp;1000000001</td>
			</tr>
			<tr>
				<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
			</tr>
			<tr height="22">
				<td align="right"><b>Street Address:&nbsp;&nbsp;</td>
				<td>&nbsp;al1</td>
			</tr>
			<tr>
				<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
			</tr>
			<tr height="22">
				<td align="right"><b>Town/City:&nbsp;&nbsp;</td>
				<td>&nbsp;twn</td>
			</tr>
			<tr>
				<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
			</tr>
			<tr height="22">
				<td align="right"><b>County/State:&nbsp;&nbsp;</td>
				<td>&nbsp;</td>
			</tr>
			<tr>
				<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
			</tr>
			<tr>
				<td align="right"><b>Postcode:&nbsp;&nbsp;</td>
				<td>&nbsp;d6a31</td>
			</tr>
			<tr>
				<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
			</tr>
			<tr>
				<td align="right"><b>Country:&nbsp;&nbsp;</td>
				<td>&nbsp;United Kingdom</td>
			</tr>
			<tr>
				<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
			</tr>
		</table><br>
		<br>

	</div>


	<table width="100%" cellpadding="0" cellspacing="0" border="0" id="tbl_ship_address_history">
		<tr>
			<td colspan="2" class="blank"><img src="/images/blank.gif" width="1" height="25"></td>
		</tr>
		<tr>
			<td class="blank"><span class="title title-NAP">Shipping Address History</span></td>
			<td class="blank" align="right"><a href="javascript:toggle_view('ship_address_history');"><span id="lnkship_address_history">View</span></a></td>
		</tr>
		<tr>
			<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
		</tr>
	</table>

	<div id="ship_address_history" style="display:none">


		<table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
			<tr>
				<td width="25%" align="right"><b>Order Number:&nbsp;&nbsp;</td>
				<td width="75%">&nbsp;1000000001</td>
			</tr>
			<tr>
				<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
			</tr>
			<tr>
				<td width="25%" align="right"><b>Shipment Number:&nbsp;&nbsp;</td>
				<td width="75%">&nbsp;1</td>
			</tr>
			<tr>
				<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
			</tr>
			<tr height="22">
				<td align="right"><b>Street Address:&nbsp;&nbsp;</td>
				<td>&nbsp;al1</td>
			</tr>
			<tr>
				<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
			</tr>
			<tr height="22">
				<td align="right"><b>Town/City:&nbsp;&nbsp;</td>
				<td>&nbsp;twn</td>
			</tr>
			<tr>
				<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
			</tr>
			<tr height="22">
				<td align="right"><b>County/State:&nbsp;&nbsp;</td>
				<td>&nbsp;</td>
			</tr>
			<tr>
				<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
			</tr>
			<tr>
				<td align="right"><b>Postcode:&nbsp;&nbsp;</td>
				<td>&nbsp;d6a31</td>
			</tr>
			<tr>
				<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
			</tr>
			<tr>
				<td align="right"><b>Country:&nbsp;&nbsp;</td>
				<td>&nbsp;United Kingdom</td>
			</tr>
			<tr>
				<td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
			</tr>
		</table><br>
		<br>

	</div>


	<br />
	<br />
	<br />


	<script language="Javascript" type="text/javascript">
	<!--
        var ajax_loaded = new Array();
        var ajax_funcs  = new Array();

        var channel_config  = new Array();
                channel_config['theOutnet.com'] = 'OUTNET';
                channel_config['JIMMYCHOO.COM'] = 'JC';
                channel_config['NET-A-PORTER.COM'] = 'NAP';
                channel_config['MRPORTER.COM'] = 'MRP';




        toggle_view('contact_options');

        toggle_view('customer_options');
        toggle_view('order_history');
        toggle_view('returns_history');

        var ajax_error_process  = function ( obj, textStatus, errorThrown ) {
                var msg = textStatus;
                if ( typeof(errorThrown) == 'string' ) {
                    if ( errorThrown.match(/error message set in session to: Login/i) ) {
                        alert("Couldn't get Data because your session has timed out.\nPlease Login again.");
                        return;
                    }
                    else {
                        msg += "\n" + errorThrown;
                    }
                }
                alert("Error Requesting Data:\n"+msg);
            };

        ajax_funcs["customer_value"] = function () {
                $.ajax( {
                    url: "/customercare/customer/customer_value",
                    type: "POST",
                    data: {
                        "customer_id"      : "1",
                        "dbl_submit_token" : dbl_submit_get_next_token(),
                        "format"           : "json"
                    },
                    dataType: "json",
                    success: function (data) {
                        /* denote that Customer Value has been loaded */
                        ajax_loaded['customer_value']   = 'LOADED';

                        var cv_div  = $("#customer_value");

                        /*
                           array to store a table of data for each channel
                           indexed by channel id so that it can be displayed
                           in the same order everytime, not ideal way of sorting
                        */
                        var channel = new Array();

                        /* see if there is an error */
                        if ( data == null || typeof(data) != 'object' || data.error ) {
                            var msg = "";
                            if ( data != null && typeof(data) == 'object' )
                                msg = data.error;
                            alert("Error with Request:\n"+msg);
                            cv_div.empty();
                            ajax_loaded['customer_value'] = '';
                            return;
                        }

                        /* no error so build up the data to be displayed in the div */
                        $.each( data, function (channel_id,data) {
                            /* first set up the table heading */
                            var channel_name = $("<span>").addClass("title")
                                                            .addClass("title-"+channel_config[data.sales_channel])
                                                            .text( data.sales_channel );

                            /* set-up table */
                            var table = $("<table>").addClass("wide-data")
                                                    .addClass("data")
                                                    .addClass("divided-data")
                                                    .css("margin-bottom","5px");

                            /*
                               if this is the first time through then draw
                               the Date Period heading and put it in element
                               zero of the channel array
                            */
                            if ( channel[0] == null ) {
                                var date_table  = $(table).clone();
                                var thead       = $("<thead>");
                                var row         = $("<tr>");
                                $("<th>").attr("colspan",5).text("Period: "+data.period.fancy).appendTo(row);
                                row.appendTo(thead);
                                thead.appendTo(date_table);
                                date_table.css("margin-top","5px");
                                channel[0]  = date_table;
                            }

                            /* draw headings */
                            var thead       = $("<thead>");
                            var head_row    = $("<tr>");
                            $("<th>").attr("width","20%").text("Currency").appendTo(head_row);
                            $("<th>").attr("width","20%").text("GROSS Spend").appendTo(head_row);
                            $("<th>").attr("width","20%").text("NET Spend").appendTo(head_row);
                            $("<th>").attr("width","20%").css("text-align","center").text("Unit Return Rate").appendTo(head_row);
                            $("<th>").attr("width","20%").css("text-align","center").text("Number of Orders").appendTo(head_row);
                            head_row.appendTo(thead);

                            /* draw data rows */
                            var tbody   = $("<tbody>");
                            if ( data.spend.length > 0 ) {
                                for ( var i = 0; i < data.spend.length; i++ ) {
                                    var rec = data.spend[i];
                                    var data_row    = $("<tr>");
                                    $("<td>").html( rec.currency + " ("+rec.html_entity+")" ).appendTo(data_row);
                                    $("<td>").text( rec.gross.formatted ).appendTo(data_row);
                                    $("<td>").text( rec.net.formatted ).appendTo(data_row);

                                    /* only do the following on the first pass */
                                    if ( i == 0 ) {
                                        var cell1 = $("<td>").attr("align","center").text( data.return_rate.unit_return_rate );
                                        var cell2 = $("<td>").attr("align","center").text( data.number_of_orders );
                                        if ( data.spend.length > 1 ) {
                                            cell1.attr("rowspan",data.spend.length);
                                            cell2.attr("rowspan",data.spend.length);
                                        }
                                        cell1.appendTo(data_row);
                                        cell2.appendTo(data_row);
                                    }
                                    data_row.appendTo(tbody);
                                }
                            }
                            else {
                                var data_row    = $("<tr>");
                                $("<td>").attr("colspan",5).text("No data available for the date period").appendTo(data_row);
                                data_row.appendTo(tbody);
                            }

                            /* add rows to the table */
                            thead.appendTo(table);
                            tbody.appendTo(table);

                            /* store all the nodes */
                            channel[channel_id] = channel_name.add(table);
                        } );

                        /* insert disclaimer */
                        channel.push( $("<span>").css("font-weight","bold")
                                                    .css("display","block")
                                                    .css("padding-top","5px")
                                                    .text("All values are indicative") );

                        /* add to the customer value div */
                        cv_div.empty();
                        for ( var i = 0; i < channel.length; i++ ) {
                            if ( channel[i] != null ) {
                                cv_div.append( channel[i] );
                            }
                        }
                    },
                    error: function ( obj, textStatus, errorThrown ) {
                        $("#customer_value").empty();
                        ajax_loaded['customer_value'] = '';
                        ajax_error_process( obj, textStatus, errorThrown );
                    }
                } );
            };

        var call_ajax_data_request  = function () {
                var label   = this.id.replace(/^lnk/,'');
                if ( ajax_loaded[label] != 'LOADED' ) {
                    show_ajax_loading_img(label);
                    if ( ajax_loaded[label] != 'LOADING' ) {
                        ajax_loaded[label]  = 'LOADING';
                        ajax_funcs[label]();
                    }
                }
            };

        function show_ajax_loading_img (div_id) {
            var div = $("#"+div_id);
            div.empty();
            var img = $("<img>").attr("src","/images/ajax-loader.gif").css("padding","5px");
            div.append(img);
        }

        $("#lnkcustomer_value").click( call_ajax_data_request );

	//-->
	</script>





        </div>
    </div>

    <p id="footer">    xTracker-DC  (2011.15.07.26.g085fa24 / IWS phase 2). &copy; 2006 - 2011 NET-A-PORTER
</p>


</div>

    </body>
</html>
