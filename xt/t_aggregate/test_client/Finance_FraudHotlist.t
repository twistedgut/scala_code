#!/usr/bin/env perl
use NAP::policy "tt",     'test';

=head1 NAME

Finance_FraudHotlist.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /Finance/FraudHotlist

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/Finance/FraudHotlist',
    expected   => {
        page_data => {
            fraud_hotlist_list_cardnumber => [
            {
                Delete => {
                    input_name => 'delete-14878',
                    input_value => '1',
                    value => ''
                },
                'Order Number' => '-',
                'Sales Channel' => 'MRPORTER.COM',
                Value => '7564738485762'
            }
            ],
            fraud_hotlist_list_email => [
            {
                Delete => {
                    input_name => 'delete-14876',
                    input_value => '1',
                    value => ''
                },
                'Order Number' => '126',
                'Sales Channel' => 'JIMMYCHOO.COM',
                Value => 'thisisatest@hotmail.com'
            }
            ],
            fraud_hotlist_list_postcodezipcode => [
            {
                Delete => {
                    input_name => 'delete-14875',
                    input_value => '1',
                    value => ''
                },
                'Order Number' => '125',
                'Sales Channel' => 'MRPORTER.COM',
                Value => 'W12 1YZ'
            }
            ],
            fraud_hotlist_list_streetaddress => [
            {
                Delete => {
                    input_name => 'delete-14873',
                    input_value => '1',
                    value => ''
                },
                'Order Number' => '123',
                'Sales Channel' => 'NET-A-PORTER.COM',
                Value => '71 New Street'
            },
            {
                Delete => {
                    input_name => 'delete-14879',
                    input_value => '1',
                    value => ''
                },
                'Order Number' => '-',
                'Sales Channel' => 'NET-A-PORTER.COM',
                Value => '132 Evergreen Terrace'
            }
            ],
            fraud_hotlist_list_telephone => [
            {
                Delete => {
                    input_name => 'delete-14877',
                    input_value => '1',
                    value => ''
                },
                'Order Number' => '127',
                'Sales Channel' => 'NET-A-PORTER.COM',
                Value => '078364623745'
            }
            ],
            fraud_hotlist_list_towncity => [
            {
                Delete => {
                    input_name => 'delete-14874',
                    input_value => '1',
                    value => ''
                },
                'Order Number' => '124',
                'Sales Channel' => 'theOutnet.com',
                Value => 'Dover'
            }
            ],
            hotlist_add_entry => {
              Field => {
                select_name => 'field_id',
                select_selected => [
                  '1',
                  'Street Address'
                ],
                select_values => [
                  [
                    '1',
                    'Street Address'
                  ],
                  [
                    '2',
                    'Town/City'
                  ],
                  [
                    '3',
                    'County/State'
                  ],
                  [
                    '4',
                    'Postcode/Zipcode'
                  ],
                  [
                    '5',
                    'Country'
                  ],
                  [
                    '6',
                    'Email'
                  ],
                  [
                    '7',
                    'Telephone'
                  ],
                  [
                    '8',
                    'Card Number'
                  ]
                ],
                value => 'Street AddressTown/CityCounty/StatePostcode/ZipcodeCountryEmailTelephoneCard Number'
              },
              'Order Number' => {
                input_name => 'order_nr',
                input_value => '',
                value => ''
              },
              'Sales Channel' => {
                select_name => 'channel_id',
                select_selected => [
                  '1',
                  'NET-A-PORTER.COM'
                ],
                select_values => [
                  [
                    '1',
                    'NET-A-PORTER.COM'
                  ],
                  [
                    '3',
                    'theOutnet.com'
                  ],
                  [
                    '5',
                    'MRPORTER.COM'
                  ],
                  [
                    '7',
                    'JIMMYCHOO.COM'
                  ]
                ],
                value => 'NET-A-PORTER.COMtheOutnet.comMRPORTER.COMJIMMYCHOO.COM'
              },
              Value => {
                input_name => 'value',
                input_value => '',
                value => ''
              }
            }
        }
    }
);

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en">
    <head>
        <meta http-equiv="Content-type" content="text/html; charset=utf-8">

        <title>Fraud Hotlist &#8226; Finance &#8226; XT-DC1</title>


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
                <span class="operator_name">Emma Howson</span>
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
                                                <a href="/Admin/FraudRules" class="yuimenuitemlabel">Fraud Rules</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/ExchangeRates" class="yuimenuitemlabel">Exchange Rates</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/JobQueue" class="yuimenuitemlabel">Job Queue</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/Printers" class="yuimenuitemlabel">Printers</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/StickyPages" class="yuimenuitemlabel">Sticky Pages</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/SystemParameters" class="yuimenuitemlabel">System Parameters</a>
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


</div>



            <img id="channelTitle" src="/images/logo_THEOUTNET_INTL.gif" alt="THEOUTNET.COM">


        <div id="contentRight"class="noleftcol">













                    <div id="pageTitle">
                        <h1>Finance</h1>
                        <h5>&bull;</h5><h2>Fraud Hotlist</h2>

                    </div>






                    <p class="bc-container">
  <ul class="breadcrumb">


  </ul>
</p>



    <form name="add_form" action="/Finance/FraudHotlist/Add" method="post">
        <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="92129005%3AmkZYjhETs12fOK8daUeQwQ">

    <span class="title">Add New Entry</span><br>
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="fraud_hotlist_entry">
        <tr>
            <td colspan="8" class="divider"></td>
        </tr>
        <tr height="24">
            <td width="8%" align="right"><b>Field:&nbsp;&nbsp;&nbsp;</td>
            <td width="10%">
                <select name="field_id">

                        <option value="1">Street Address</option>

                        <option value="2">Town/City</option>

                        <option value="3">County/State</option>

                        <option value="4">Postcode/Zipcode</option>

                        <option value="5">Country</option>

                        <option value="6">Email</option>

                        <option value="7">Telephone</option>

                        <option value="8">Card Number</option>

                </select>
            </td>
            <td width="8%" align="right"><b>Value:&nbsp;&nbsp;&nbsp;</td>
            <td width="15%"><input type="text" name="value" value=""></td>
            <td width="15%" align="right"><b>Sales Channel:&nbsp;&nbsp;&nbsp;</td>
            <td width="15%">
                <select name="channel_id">

                        <option value="1">NET-A-PORTER.COM</option>

                        <option value="3">theOutnet.com</option>

                        <option value="5">MRPORTER.COM</option>

                        <option value="7">JIMMYCHOO.COM</option>

                </select>
            </td>
            <td width="15%" align="right"><b>Order Number:&nbsp;&nbsp;&nbsp;</td>
            <td width="12%"><input type="text" size="10" maxlength="30" name="order_nr" value=""></td>
        </tr>
        <tr>
            <td colspan="8" class="divider"></td>
        </tr>
        <tr>
            <td colspan="8" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
        </tr>
        <tr>
            <td colspan="8" class="blank" align="right"><input type="submit" name="submit" class="button" value="Add Entry &raquo;">
</td>
        </tr>
    </table>
    </form>
    <br />
    <br />
    <br />






    <form name="delete_form_cardnumber" id="delete_form_cardnumber" action="/Finance/FraudHotlist/Delete" method="post">
        <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="92129005%3AmkZYjhETs12fOK8daUeQwQ">

    <span class="title">Field Type:</span>&nbsp;&nbsp;<b>Card Number</b><br />
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="fraud_hotlist_list_cardnumber">
        <tr>
            <td colspan="4" class="dividerHeader"></td>
        </tr>
        <tr height="24">
            <td width="40%" class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;Value</td>
            <td width="20%" class="tableHeader">Sales Channel</td>
            <td width="20%" class="tableHeader">Order Number</td>
            <td width="20%" class="tableHeader">Delete</td>
        </tr>
        <tr>
            <td colspan="4" class="dividerHeader"></td>
        </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;7564738485762</td>
                <td><span class="title-MRP">MRPORTER.COM</span></td>
                <td>

                        -

                </td>
                <td><input type="checkbox" name="delete-14878" value="1"></td>
            </tr>
            <tr>
                <td colspan="4" class="divider"></td>
            </tr>



            <tr>
                <td colspan="4" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
            </tr>
            <tr>
                <td colspan="4" class="blank" align="right"><input type="submit" name="submit" class="button" value="Delete Entry &raquo;">
</td>
            </tr>

    </table>
    </form><br />
    <br />
    <form name="delete_form_email" id="delete_form_email" action="/Finance/FraudHotlist/Delete" method="post">
        <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="92129005%3AmkZYjhETs12fOK8daUeQwQ">

    <span class="title">Field Type:</span>&nbsp;&nbsp;<b>Email</b><br />
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="fraud_hotlist_list_email">
        <tr>
            <td colspan="4" class="dividerHeader"></td>
        </tr>
        <tr height="24">
            <td width="40%" class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;Value</td>
            <td width="20%" class="tableHeader">Sales Channel</td>
            <td width="20%" class="tableHeader">Order Number</td>
            <td width="20%" class="tableHeader">Delete</td>
        </tr>
        <tr>
            <td colspan="4" class="dividerHeader"></td>
        </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;thisisatest@hotmail.com</td>
                <td><span class="title-JC">JIMMYCHOO.COM</span></td>
                <td>

                        126

                </td>
                <td><input type="checkbox" name="delete-14876" value="1"></td>
            </tr>
            <tr>
                <td colspan="4" class="divider"></td>
            </tr>



            <tr>
                <td colspan="4" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
            </tr>
            <tr>
                <td colspan="4" class="blank" align="right"><input type="submit" name="submit" class="button" value="Delete Entry &raquo;">
</td>
            </tr>

    </table>
    </form><br />
    <br />
    <form name="delete_form_postcodezipcode" id="delete_form_postcodezipcode" action="/Finance/FraudHotlist/Delete" method="post">
        <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="92129005%3AmkZYjhETs12fOK8daUeQwQ">

    <span class="title">Field Type:</span>&nbsp;&nbsp;<b>Postcode/Zipcode</b><br />
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="fraud_hotlist_list_postcodezipcode">
        <tr>
            <td colspan="4" class="dividerHeader"></td>
        </tr>
        <tr height="24">
            <td width="40%" class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;Value</td>
            <td width="20%" class="tableHeader">Sales Channel</td>
            <td width="20%" class="tableHeader">Order Number</td>
            <td width="20%" class="tableHeader">Delete</td>
        </tr>
        <tr>
            <td colspan="4" class="dividerHeader"></td>
        </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;W12 1YZ</td>
                <td><span class="title-MRP">MRPORTER.COM</span></td>
                <td>

                        125

                </td>
                <td><input type="checkbox" name="delete-14875" value="1"></td>
            </tr>
            <tr>
                <td colspan="4" class="divider"></td>
            </tr>



            <tr>
                <td colspan="4" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
            </tr>
            <tr>
                <td colspan="4" class="blank" align="right"><input type="submit" name="submit" class="button" value="Delete Entry &raquo;">
</td>
            </tr>

    </table>
    </form><br />
    <br />
    <form name="delete_form_streetaddress" id="delete_form_streetaddress" action="/Finance/FraudHotlist/Delete" method="post">
        <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="92129005%3AmkZYjhETs12fOK8daUeQwQ">

    <span class="title">Field Type:</span>&nbsp;&nbsp;<b>Street Address</b><br />
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="fraud_hotlist_list_streetaddress">
        <tr>
            <td colspan="4" class="dividerHeader"></td>
        </tr>
        <tr height="24">
            <td width="40%" class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;Value</td>
            <td width="20%" class="tableHeader">Sales Channel</td>
            <td width="20%" class="tableHeader">Order Number</td>
            <td width="20%" class="tableHeader">Delete</td>
        </tr>
        <tr>
            <td colspan="4" class="dividerHeader"></td>
        </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;71 New Street</td>
                <td><span class="title-NAP">NET-A-PORTER.COM</span></td>
                <td>

                        123

                </td>
                <td><input type="checkbox" name="delete-14873" value="1"></td>
            </tr>
            <tr>
                <td colspan="4" class="divider"></td>
            </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;132 Evergreen Terrace</td>
                <td><span class="title-NAP">NET-A-PORTER.COM</span></td>
                <td>

                        -

                </td>
                <td><input type="checkbox" name="delete-14879" value="1"></td>
            </tr>
            <tr>
                <td colspan="4" class="divider"></td>
            </tr>



            <tr>
                <td colspan="4" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
            </tr>
            <tr>
                <td colspan="4" class="blank" align="right"><input type="submit" name="submit" class="button" value="Delete Entry &raquo;">
</td>
            </tr>

    </table>
    </form><br />
    <br />
    <form name="delete_form_telephone" id="delete_form_telephone" action="/Finance/FraudHotlist/Delete" method="post">
        <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="92129005%3AmkZYjhETs12fOK8daUeQwQ">

    <span class="title">Field Type:</span>&nbsp;&nbsp;<b>Telephone</b><br />
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="fraud_hotlist_list_telephone">
        <tr>
            <td colspan="4" class="dividerHeader"></td>
        </tr>
        <tr height="24">
            <td width="40%" class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;Value</td>
            <td width="20%" class="tableHeader">Sales Channel</td>
            <td width="20%" class="tableHeader">Order Number</td>
            <td width="20%" class="tableHeader">Delete</td>
        </tr>
        <tr>
            <td colspan="4" class="dividerHeader"></td>
        </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;078364623745</td>
                <td><span class="title-NAP">NET-A-PORTER.COM</span></td>
                <td>

                        127

                </td>
                <td><input type="checkbox" name="delete-14877" value="1"></td>
            </tr>
            <tr>
                <td colspan="4" class="divider"></td>
            </tr>



            <tr>
                <td colspan="4" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
            </tr>
            <tr>
                <td colspan="4" class="blank" align="right"><input type="submit" name="submit" class="button" value="Delete Entry &raquo;">
</td>
            </tr>

    </table>
    </form><br />
    <br />
    <form name="delete_form_towncity" id="delete_form_towncity" action="/Finance/FraudHotlist/Delete" method="post">
        <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="92129005%3AmkZYjhETs12fOK8daUeQwQ">

    <span class="title">Field Type:</span>&nbsp;&nbsp;<b>Town/City</b><br />
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="fraud_hotlist_list_towncity">
        <tr>
            <td colspan="4" class="dividerHeader"></td>
        </tr>
        <tr height="24">
            <td width="40%" class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;Value</td>
            <td width="20%" class="tableHeader">Sales Channel</td>
            <td width="20%" class="tableHeader">Order Number</td>
            <td width="20%" class="tableHeader">Delete</td>
        </tr>
        <tr>
            <td colspan="4" class="dividerHeader"></td>
        </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;Dover</td>
                <td><span class="title-OUTNET">theOutnet.com</span></td>
                <td>

                        124

                </td>
                <td><input type="checkbox" name="delete-14874" value="1"></td>
            </tr>
            <tr>
                <td colspan="4" class="divider"></td>
            </tr>



            <tr>
                <td colspan="4" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
            </tr>
            <tr>
                <td colspan="4" class="blank" align="right"><input type="submit" name="submit" class="button" value="Delete Entry &raquo;">
</td>
            </tr>

    </table>
    </form><br />
    <br />




<br />
<br />
<br />





        </div>
    </div>

    <p id="footer">    xTracker-DC  (2013.09.xx.prodman.001 / IWS phase 2 / PRL phase 0 / 2013-07-23 15:52:37). &copy; 2006 - 2013 NET-A-PORTER
</p>


</div>

    </body>
</html>

