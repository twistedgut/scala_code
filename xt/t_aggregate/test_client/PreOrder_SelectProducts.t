#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

PreOrder_SelectProducts.t

=head1 DESCRIPTION

Tests the contents of the Pre-Order Select Products page, URI:

    /StockControl/Reservation/PreOrder/SelectProducts

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/StockControl/Reservation/PreOrder/SelectProducts',
    expected   => {
      product_list => {
        '111' => {
          price => {
            price_parts => {
              duty => '0.00',
              tax => '0.00',
              unit_price => '100.00'
            },
            total_price => '100.00'
          },
          sku_table => [
            {
              DesignerSize => 'None/Unknown',
              Freestock => '0',
              Ordered => '10',
              'Pre Orderedby Customer' => '0',
              SKU => '111-863',
              'TotalPre Orders' => '0',
              'Waiting List' => '0'
            },
            {
              DesignerSize => 'None/Unknown',
              Freestock => '0',
              Ordered => '10',
              'Pre Orderedby Customer' => '0',
              SKU => '111-864',
              'TotalPre Orders' => '0',
              'Waiting List' => '0'
            },
            {
              DesignerSize => 'None/Unknown',
              Freestock => '0',
              Ordered => '10',
              'Pre Orderedby Customer' => '0',
              SKU => '111-865',
              'TotalPre Orders' => '0',
              'Waiting List' => '0'
            }
          ]
        },
        '112' => {
          price => {
            price_parts => {
              duty => '0.00',
              tax => '0.00',
              unit_price => '150.00'
            },
            total_price => '150.00'
          },
          sku_table => [
            {
              DesignerSize => 'None/Unknown',
              Freestock => '0',
              Ordered => '10',
              'Pre Orderedby Customer' => '0',
              SKU => '112-863',
              'TotalPre Orders' => '0',
              'Waiting List' => '0'
            },
            {
              DesignerSize => 'None/Unknown',
              Freestock => '0',
              Ordered => '10',
              'Pre Orderedby Customer' => '0',
              SKU => '112-864',
              'TotalPre Orders' => '0',
              'Waiting List' => '0'
            },
            {
              DesignerSize => 'None/Unknown',
              Freestock => '0',
              Ordered => '10',
              'Pre Orderedby Customer' => '0',
              SKU => '112-865',
              'TotalPre Orders' => '0',
              'Waiting List' => '0'
            }
          ]
        },
        '113' => {
          price => {
            price_parts => {
              duty => '0.00',
              tax => '0.00',
              unit_price => '200.00'
            },
            total_price => '200.00'
          },
          sku_table => [
            {
              DesignerSize => 'None/Unknown',
              Freestock => '0',
              Ordered => '10',
              'Pre Orderedby Customer' => '0',
              SKU => '113-863',
              'TotalPre Orders' => '0',
              'Waiting List' => '0'
            },
            {
              DesignerSize => 'None/Unknown',
              Freestock => '0',
              Ordered => '10',
              'Pre Orderedby Customer' => '0',
              SKU => '113-864',
              'TotalPre Orders' => '0',
              'Waiting List' => '0'
            },
            {
              DesignerSize => 'None/Unknown',
              Freestock => '0',
              Ordered => '10',
              'Pre Orderedby Customer' => '0',
              SKU => '113-865',
              'TotalPre Orders' => '0',
              'Waiting List' => '0'
            }
          ]
        },
        '114' => {
          price => {
            price_parts => {
              duty => '0.00',
              tax => '0.00',
              unit_price => '250.00'
            },
            total_price => '250.00'
          },
          sku_table => [
            {
              DesignerSize => 'None/Unknown',
              Freestock => '0',
              Ordered => '10',
              'Pre Orderedby Customer' => '0',
              SKU => '114-863',
              'TotalPre Orders' => '0',
              'Waiting List' => '0'
            },
            {
              DesignerSize => 'None/Unknown',
              Freestock => '0',
              Ordered => '10',
              'Pre Orderedby Customer' => '0',
              SKU => '114-864',
              'TotalPre Orders' => '0',
              'Waiting List' => '0'
            },
            {
              DesignerSize => 'None/Unknown',
              Freestock => '0',
              Ordered => '10',
              'Pre Orderedby Customer' => '0',
              SKU => '114-865',
              'TotalPre Orders' => '0',
              'Waiting List' => '0'
            }
          ]
        },
        '115' => {
          price => {
            price_parts => {
              duty => '0.00',
              tax => '0.00',
              unit_price => '300.00'
            },
            total_price => '300.00'
          },
          sku_table => [
            {
              DesignerSize => 'None/Unknown',
              Freestock => '0',
              Ordered => '10',
              'Pre Orderedby Customer' => '0',
              SKU => '115-863',
              'TotalPre Orders' => '0',
              'Waiting List' => '0'
            },
            {
              DesignerSize => 'None/Unknown',
              Freestock => '0',
              Ordered => '10',
              'Pre Orderedby Customer' => '0',
              SKU => '115-864',
              'TotalPre Orders' => '0',
              'Waiting List' => '0'
            },
            {
              DesignerSize => 'None/Unknown',
              Freestock => '0',
              Ordered => '10',
              'Pre Orderedby Customer' => '0',
              SKU => '115-865',
              'TotalPre Orders' => '0',
              'Waiting List' => '0'
            }
          ]
        }
      },
      product_search_box => {
        'Enter Products' => '111 112 113 114 115',
        'Select Discount' => {
          select_name => 'discount_percentage',
          select_selected => [
            '0',
            '0%'
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
        'Select currency' => {
          select_name => 'currency_id',
          select_selected => [
            '1',
            'GBP'
          ],
          select_values => [
            [
              '1',
              'GBP'
            ],
            [
              '3',
              'EUR'
            ]
          ],
          value => 'GBPEUR'
        },
        hidden_fields => {
          customer_id => '1',
          shipment_country_id => '87',
          shipment_country_subdivision_id => ''
        }
      },
      shipment_address_none => 'This customer has no previous shipping address to be used for a Pre-Order.'
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
                        <h5>&bull;</h5><h3>Pre Order</h3>
                    </div>






                    <p class="bc-container">
  <ul class="breadcrumb">


  </ul>
</p>



<div id="common__customer_details">
    <h3 class="title-NAP">Customer</h3>
    <b>Name:</b> Test-forename Test-surname<br>
    <b>Number:</b> 1<br>
    <br>
    <hr>
</div>


<div id="select_products__strap_area">
    <div id="select_products__product_shipment_block" class="faint_bordered_box">
        <h3 class="title-NAP">Shipment Address</h3>

        <span id="shipment_address__none">This customer has no previous shipping address to be used for a Pre-Order.</span>
        <br>
        <br>

        Products will be shipped to:

        <br>
        <br>
        <select id="select_products__shipment_country_selection">
            <option value="0">Select a country to ship to...</option>

            <option id=116 value="116" >Albania</option>

            <option id=128 value="128" >Algeria</option>

            <option id=191 value="191" >American Samoa</option>

            <option id=114 value="114" >Andorra</option>

            <option id=1 value="1" >Angola</option>

            <option id=115 value="115" >Anguilla</option>

            <option id=2 value="2" >Antigua and Barbuda</option>

            <option id=3 value="3" >Argentina</option>

            <option id=190 value="190" >Armenia</option>

            <option id=118 value="118" >Aruba</option>

            <option id=4 value="4" >Australia</option>

            <option id=5 value="5" >Austria</option>

            <option id=178 value="178" >Azerbaijan</option>

            <option id=6 value="6" >Bahamas</option>

            <option id=7 value="7" >Bahrain</option>

            <option id=119 value="119" >Bangladesh</option>

            <option id=101 value="101" >Barbados</option>

            <option id=184 value="184" >Belarus</option>

            <option id=8 value="8" >Belgium</option>

            <option id=123 value="123" >Belize</option>

            <option id=9 value="9" >Bermuda</option>

            <option id=121 value="121" >Bhutan</option>

            <option id=120 value="120" >Bolivia</option>

            <option id=10 value="10" >Bosnia-Herzegovina</option>

            <option id=122 value="122" >Botswana</option>

            <option id=11 value="11" >Brazil</option>

            <option id=12 value="12" >British Virgin Islands</option>

            <option id=13 value="13" >Brunei</option>

            <option id=14 value="14" >Bulgaria</option>

            <option id=141 value="141" >Cambodia</option>

            <option id=15 value="15" >Cameroon</option>

            <option id=16 value="16" >Canada</option>

            <option id=100 value="100" >Canary Islands</option>

            <option id=126 value="126" >Cape Verde Islands</option>

            <option id=17 value="17" >Cayman Islands</option>

            <option id=18 value="18" >Chile</option>

            <option id=19 value="19" >China</option>

            <option id=125 value="125" >Colombia</option>

            <option id=142 value="142" >Comoros Islands</option>

            <option id=124 value="124" >Cook Islands</option>

            <option id=110 value="110" >Costa Rica</option>

            <option id=20 value="20" >Croatia</option>

            <option id=91 value="91" >Cyprus</option>

            <option id=22 value="22" >Czech Republic</option>

            <option id=23 value="23" >Denmark</option>

            <option id=127 value="127" >Dominica</option>

            <option id=24 value="24" >Dominican Republic</option>

            <option id=167 value="167" >East Timor</option>

            <option id=129 value="129" >Ecuador</option>

            <option id=25 value="25" >Egypt</option>

            <option id=163 value="163" >El Salvador</option>

            <option id=26 value="26" >Estonia</option>

            <option id=187 value="187" >Ethiopia</option>

            <option id=131 value="131" >Falkland Islands</option>

            <option id=132 value="132" >Faroe Islands</option>

            <option id=192 value="192" >Federated States of Micronesia</option>

            <option id=130 value="130" >Fiji</option>

            <option id=27 value="27" >Finland</option>

            <option id=28 value="28" >France</option>

            <option id=135 value="135" >French Guiana</option>

            <option id=112 value="112" >French Polynesia</option>

            <option id=133 value="133" >Gabon</option>

            <option id=136 value="136" >Gambia</option>

            <option id=111 value="111" >Georgia</option>

            <option id=29 value="29" >Germany</option>

            <option id=180 value="180" >Ghana</option>

            <option id=108 value="108" >Gibraltar</option>

            <option id=30 value="30" >Greece</option>

            <option id=31 value="31" >Greenland</option>

            <option id=134 value="134" >Grenada</option>

            <option id=32 value="32" >Guadeloupe</option>

            <option id=138 value="138" >Guam</option>

            <option id=137 value="137" >Guatemala</option>

            <option id=182 value="182" >Guernsey</option>

            <option id=104 value="104" >Guyana</option>

            <option id=189 value="189" >Haiti</option>

            <option id=139 value="139" >Honduras</option>

            <option id=33 value="33" >Hong Kong</option>

            <option id=34 value="34" >Hungary</option>

            <option id=35 value="35" >Iceland</option>

            <option id=36 value="36" >India</option>

            <option id=37 value="37" >Indonesia</option>

            <option id=38 value="38" >Ireland</option>

            <option id=39 value="39" >Israel</option>

            <option id=40 value="40" >Italy</option>

            <option id=140 value="140" >Jamaica</option>

            <option id=41 value="41" >Japan</option>

            <option id=181 value="181" >Jersey</option>

            <option id=42 value="42" >Jordan</option>

            <option id=105 value="105" >Kazakhstan</option>

            <option id=107 value="107" >Kenya</option>

            <option id=45 value="45" >Kuwait</option>

            <option id=144 value="144" >Laos</option>

            <option id=46 value="46" >Latvia</option>

            <option id=47 value="47" >Lebanon</option>

            <option id=146 value="146" >Lesotho</option>

            <option id=48 value="48" >Liberia</option>

            <option id=96 value="96" >Liechtenstein</option>

            <option id=49 value="49" >Lithuania</option>

            <option id=50 value="50" >Luxembourg</option>

            <option id=94 value="94" >Macau</option>

            <option id=51 value="51" >Macedonia</option>

            <option id=93 value="93" >Madagascar</option>

            <option id=151 value="151" >Malawi</option>

            <option id=52 value="52" >Malaysia</option>

            <option id=150 value="150" >Maldives</option>

            <option id=53 value="53" >Malta</option>

            <option id=193 value="193" >Marshall Islands</option>

            <option id=148 value="148" >Martinique</option>

            <option id=106 value="106" >Mauritius</option>

            <option id=54 value="54" >Mexico</option>

            <option id=55 value="55" >Moldova</option>

            <option id=56 value="56" >Monaco</option>

            <option id=147 value="147" >Mongolia</option>

            <option id=186 value="186" >Montenegro</option>

            <option id=149 value="149" >Montserrat</option>

            <option id=102 value="102" >Morocco</option>

            <option id=97 value="97" >Mozambique</option>

            <option id=152 value="152" >Namibia</option>

            <option id=154 value="154" >Nepal</option>

            <option id=83 value="83" >Netherlands</option>

            <option id=117 value="117" >Netherlands Antilles</option>

            <option id=98 value="98" >New Caledonia</option>

            <option id=57 value="57" >New Zealand</option>

            <option id=153 value="153" >Nicaragua</option>

            <option id=43 value="43" >North Korea</option>

            <option id=59 value="59" >Norway</option>

            <option id=60 value="60" >Oman</option>

            <option id=61 value="61" >Pakistan</option>

            <option id=194 value="194" >Palau</option>

            <option id=155 value="155" >Panama</option>

            <option id=156 value="156" >Papua New Guinea</option>

            <option id=157 value="157" >Paraguay</option>

            <option id=103 value="103" >Peru</option>

            <option id=62 value="62" >Philippines</option>

            <option id=63 value="63" >Poland</option>

            <option id=64 value="64" >Portugal</option>

            <option id=65 value="65" >Puerto Rico</option>

            <option id=66 value="66" >Qatar</option>

            <option id=195 value="195" >Reunion Island</option>

            <option id=67 value="67" >Romania</option>

            <option id=68 value="68" >Russia</option>

            <option id=143 value="143" >Saint Kitts and Nevis</option>

            <option id=145 value="145" >Saint Lucia</option>

            <option id=172 value="172" >Saint Vincent and the Grenadines</option>

            <option id=177 value="177" >Saipan</option>

            <option id=174 value="174" >Samoa</option>

            <option id=69 value="69" >San Marino</option>

            <option id=162 value="162" >Sao Tome and Principe</option>

            <option id=70 value="70" >Saudi Arabia</option>

            <option id=71 value="71" >Senegal</option>

            <option id=185 value="185" >Serbia</option>

            <option id=159 value="159" >Seychelles</option>

            <option id=160 value="160" >Sierra Leone</option>

            <option id=73 value="73" >Singapore</option>

            <option id=74 value="74" >Slovakia</option>

            <option id=75 value="75" >Slovenia</option>

            <option id=196 value="196" >Solomon Islands</option>

            <option id=76 value="76" >South Africa</option>

            <option id=44 value="44" >South Korea</option>

            <option id=77 value="77" >Spain</option>

            <option id=78 value="78" >Sri Lanka</option>

            <option id=175 value="175" >St Barthelemy</option>

            <option id=161 value="161" >Suriname</option>

            <option id=164 value="164" >Swaziland</option>

            <option id=79 value="79" >Sweden</option>

            <option id=80 value="80" >Switzerland</option>

            <option id=188 value="188" >Syria</option>

            <option id=81 value="81" >Taiwan ROC</option>

            <option id=171 value="171" >Tanzania</option>

            <option id=82 value="82" >Thailand</option>

            <option id=166 value="166" >Togo</option>

            <option id=168 value="168" >Tonga</option>

            <option id=169 value="169" >Trinidad and Tobago</option>

            <option id=95 value="95" >Tunisia</option>

            <option id=84 value="84" >Turkey</option>

            <option id=165 value="165" >Turks and Caicos Islands</option>

            <option id=170 value="170" >Tuvalu</option>

            <option id=197 value="197" >Uganda</option>

            <option id=85 value="85" >Ukraine</option>

            <option id=86 value="86" >United Arab Emirates</option>

            <option id=87 value="87" selected>United Kingdom</option>

            <option id=88 value="88" >United States</option>

            <option id=92 value="92" >Uruguay</option>

            <option id=109 value="109" >US Virgin Islands</option>

            <option id=173 value="173" >Vanuatu</option>

            <option id=89 value="89" >Venezuela</option>

            <option id=99 value="99" >Vietnam</option>

            <option id=176 value="176" >Yemen</option>

        </select>
        <br>
        <select class="select_products__shipment_subdivision_lists" id="select_products__shipment_us_state">
            <option value="0">Select a state to ship to...</option>

        </select>
        <br>
        <br>
        <input type="button" id="select_products__update_shipping_country_button" class="button" value="Update Shipping Country">

    </div>
    <div id="select_products__product_search_block" class="faint_bordered_box">
        <h3 class="title-NAP">Product Search</h3>
        <form name="pid_search" method="post" id="select_products__search_form" action="SelectProducts">

            <div class="formrow divideabove dividebelow formrow_left-aligned">
                <label for="select_products__currency_dropdown">Select currency:</label>
                <select name="currency_id" id="select_products__currency_dropdown">

                    <option value="1" selected="selected">GBP</option>

                    <option value="3" >EUR</option>

                </select>
            </div>

                <div class="formrow dividebelow formrow_left-aligned">
                    <label for="discount_percentage">Select Discount:</label><select name="discount_percentage" id="discount_percentage">        <option value="0" >0%</option>
                <option value="5" >5%</option>
                <option value="10" >10%</option>
                <option value="15" >15%</option>
                <option value="20" >20%</option>
                <option value="25" >25%</option>
                <option value="30" >30%</option>
        </select>
                </div>


                <input type="hidden" name="customer_id" value="1">



            <input type="hidden" name="shipment_country_id" id="select_products__shipment_country_id" value="87">
            <input type="hidden" name="shipment_country_subdivision_id" id="select_products__shipment_country_subdivision_id" value="">


            <div class="formrow dividebelow formrow_input-under-label">
                <label for="select_products_product_textarea">Enter Products:</label>
                <textarea name="pids" id="select_products_product_textarea">111
112
113
114
115</textarea>
            </div>

            <br>
            <input name="button" class="button" type="submit" value="Search">
        </form>
    </div>
</div>

<div id="select_products__search_results_area">
    <hr>

    <form name="variant_select_products" id="select_products__variants_form" method="post" action="Basket">



        <input type="hidden" name="customer_id" value="1">


        <input type="hidden" name="shipment_option_id" value="">

        <input type="hidden" class="select_products__shipment_address_id" name="shipment_address_id" value="">
        <input type="hidden" class="select_products__invoice_address_id" name="invoice_address_id" value="">

        <input type="hidden" id="select_products__currency_id" name="currency_id" value="1">
        <input type="hidden" name="pids" value="">

        <div id="select_products__reservation_source_selection">
            Select the reservation source:
            <select name="reservation_source_id" id="select_products__reservation_source_dropdown">
                <option value="0">-------------------</option>

                <option value="1" >Notes</option>

                <option value="2" >Upload Preview</option>

                <option value="3" >LookBook</option>

                <option value="4" >Press</option>

                <option value="5" >Website</option>

                <option value="6" >Sold Out</option>

                <option value="7" >Reorder</option>

                <option value="8" >Recommendation</option>

                <option value="9" >Preview Files</option>

                <option value="10" >Event</option>

                <option value="12" >Stock Discrepancy</option>

                <option value="13" >Email</option>

                <option value="14" >Appointment</option>

                <option value="15" >Charge and Send</option>

                <option value="16" >Live Chat</option>

                <option value="17" >Limited Availability</option>

                <option value="18" >Sale</option>

                <option value="19" >Social Media</option>

                <option value="20" >PreOrder</option>

                <option value="11" >Unknown</option>

            </select>
        </div>

        <br>
        <br>
        <br>

        <div id="select_products__variants_list">

            <div class="select_products__variant_selection_box faint_bordered_box">
                <div class="select_products__variant_data" id="select_products__variant_data_111">
                    <div class="select_products__product_image">
                        <img width="50" src="http://cache.net-a-porter.com/images/products/111/111_in_m.jpg">
                    </div>
                    <div class="select_products__product_details">
                        <p class="select_products__description">République ✪ Ceccarelli - Name</p>

                        <p class="select_products__price">Price: &pound;100.00</p>

                            <p class="select_products__broken_price">
                                (unit price: &pound;100.00, tax: &pound;0.00, duty: &pound;0.00)
                            </p>


                    </div>
                </div>
                <div class="select_products__variant_table" id="select_products__variant_table_111">

                    <table class="data wide-data select_products__product_variants_table" id="select_products__product_table_111">
                        <thead>
                            <tr>
                                <th>&nbsp;&nbsp;&nbsp;SKU</th>
                                <th>Designer<br>Size</th>
                                <th>Freestock</th>
                                <th>Ordered</th>
                                <th>Waiting List</th>
                                <th>Total<br>Pre Orders</th>
                                <th>Pre Ordered<br>by Customer</th>
                                <th></th>
                            </tr>
                        </thead>
                        <tbody>

                            <tr class="dividebelow">
                                <td>&nbsp;&nbsp;&nbsp;111-863&nbsp;&nbsp;</td>
                                <td>None/Unknown</td>
                                <td>0</td>
                                <td>10</td>
                                <td>0</td>
                                <td>0</td>
                                <td>0</td>
                                <td>

                                    <input class="select_products__product_table_111_checkbox select_products__variants_checkbox" name="variants"  value="331" type="checkbox">

                                </td>
                            </tr>

                            <tr class="dividebelow">
                                <td>&nbsp;&nbsp;&nbsp;111-864&nbsp;&nbsp;</td>
                                <td>None/Unknown</td>
                                <td>0</td>
                                <td>10</td>
                                <td>0</td>
                                <td>0</td>
                                <td>0</td>
                                <td>

                                    <input class="select_products__product_table_111_checkbox select_products__variants_checkbox" name="variants"  value="332" type="checkbox">

                                </td>
                            </tr>

                            <tr class="dividebelow">
                                <td>&nbsp;&nbsp;&nbsp;111-865&nbsp;&nbsp;</td>
                                <td>None/Unknown</td>
                                <td>0</td>
                                <td>10</td>
                                <td>0</td>
                                <td>0</td>
                                <td>0</td>
                                <td>

                                    <input class="select_products__product_table_111_checkbox select_products__variants_checkbox" name="variants"  value="333" type="checkbox">

                                </td>
                            </tr>

                        </tbody>
                    </table>

                </div>
            </div>

            <div class="select_products__variant_selection_box faint_bordered_box">
                <div class="select_products__variant_data" id="select_products__variant_data_112">
                    <div class="select_products__product_image">
                        <img width="50" src="http://cache.net-a-porter.com/images/products/112/112_in_m.jpg">
                    </div>
                    <div class="select_products__product_details">
                        <p class="select_products__description">République ✪ Ceccarelli - Name</p>

                        <p class="select_products__price">Price: &pound;150.00</p>

                            <p class="select_products__broken_price">
                                (unit price: &pound;150.00, tax: &pound;0.00, duty: &pound;0.00)
                            </p>


                    </div>
                </div>
                <div class="select_products__variant_table" id="select_products__variant_table_112">

                    <table class="data wide-data select_products__product_variants_table" id="select_products__product_table_112">
                        <thead>
                            <tr>
                                <th>&nbsp;&nbsp;&nbsp;SKU</th>
                                <th>Designer<br>Size</th>
                                <th>Freestock</th>
                                <th>Ordered</th>
                                <th>Waiting List</th>
                                <th>Total<br>Pre Orders</th>
                                <th>Pre Ordered<br>by Customer</th>
                                <th></th>
                            </tr>
                        </thead>
                        <tbody>

                            <tr class="dividebelow">
                                <td>&nbsp;&nbsp;&nbsp;112-863&nbsp;&nbsp;</td>
                                <td>None/Unknown</td>
                                <td>0</td>
                                <td>10</td>
                                <td>0</td>
                                <td>0</td>
                                <td>0</td>
                                <td>

                                    <input class="select_products__product_table_112_checkbox select_products__variants_checkbox" name="variants"  value="334" type="checkbox">

                                </td>
                            </tr>

                            <tr class="dividebelow">
                                <td>&nbsp;&nbsp;&nbsp;112-864&nbsp;&nbsp;</td>
                                <td>None/Unknown</td>
                                <td>0</td>
                                <td>10</td>
                                <td>0</td>
                                <td>0</td>
                                <td>0</td>
                                <td>

                                    <input class="select_products__product_table_112_checkbox select_products__variants_checkbox" name="variants"  value="335" type="checkbox">

                                </td>
                            </tr>

                            <tr class="dividebelow">
                                <td>&nbsp;&nbsp;&nbsp;112-865&nbsp;&nbsp;</td>
                                <td>None/Unknown</td>
                                <td>0</td>
                                <td>10</td>
                                <td>0</td>
                                <td>0</td>
                                <td>0</td>
                                <td>

                                    <input class="select_products__product_table_112_checkbox select_products__variants_checkbox" name="variants"  value="336" type="checkbox">

                                </td>
                            </tr>

                        </tbody>
                    </table>

                </div>
            </div>

            <div class="select_products__variant_selection_box faint_bordered_box">
                <div class="select_products__variant_data" id="select_products__variant_data_113">
                    <div class="select_products__product_image">
                        <img width="50" src="http://cache.net-a-porter.com/images/products/113/113_in_m.jpg">
                    </div>
                    <div class="select_products__product_details">
                        <p class="select_products__description">République ✪ Ceccarelli - Name</p>

                        <p class="select_products__price">Price: &pound;200.00</p>

                            <p class="select_products__broken_price">
                                (unit price: &pound;200.00, tax: &pound;0.00, duty: &pound;0.00)
                            </p>


                    </div>
                </div>
                <div class="select_products__variant_table" id="select_products__variant_table_113">

                    <table class="data wide-data select_products__product_variants_table" id="select_products__product_table_113">
                        <thead>
                            <tr>
                                <th>&nbsp;&nbsp;&nbsp;SKU</th>
                                <th>Designer<br>Size</th>
                                <th>Freestock</th>
                                <th>Ordered</th>
                                <th>Waiting List</th>
                                <th>Total<br>Pre Orders</th>
                                <th>Pre Ordered<br>by Customer</th>
                                <th></th>
                            </tr>
                        </thead>
                        <tbody>

                            <tr class="dividebelow">
                                <td>&nbsp;&nbsp;&nbsp;113-863&nbsp;&nbsp;</td>
                                <td>None/Unknown</td>
                                <td>0</td>
                                <td>10</td>
                                <td>0</td>
                                <td>0</td>
                                <td>0</td>
                                <td>

                                    <input class="select_products__product_table_113_checkbox select_products__variants_checkbox" name="variants"  value="337" type="checkbox">

                                </td>
                            </tr>

                            <tr class="dividebelow">
                                <td>&nbsp;&nbsp;&nbsp;113-864&nbsp;&nbsp;</td>
                                <td>None/Unknown</td>
                                <td>0</td>
                                <td>10</td>
                                <td>0</td>
                                <td>0</td>
                                <td>0</td>
                                <td>

                                    <input class="select_products__product_table_113_checkbox select_products__variants_checkbox" name="variants"  value="338" type="checkbox">

                                </td>
                            </tr>

                            <tr class="dividebelow">
                                <td>&nbsp;&nbsp;&nbsp;113-865&nbsp;&nbsp;</td>
                                <td>None/Unknown</td>
                                <td>0</td>
                                <td>10</td>
                                <td>0</td>
                                <td>0</td>
                                <td>0</td>
                                <td>

                                    <input class="select_products__product_table_113_checkbox select_products__variants_checkbox" name="variants"  value="339" type="checkbox">

                                </td>
                            </tr>

                        </tbody>
                    </table>

                </div>
            </div>

            <div class="select_products__variant_selection_box faint_bordered_box">
                <div class="select_products__variant_data" id="select_products__variant_data_114">
                    <div class="select_products__product_image">
                        <img width="50" src="http://cache.net-a-porter.com/images/products/114/114_in_m.jpg">
                    </div>
                    <div class="select_products__product_details">
                        <p class="select_products__description">République ✪ Ceccarelli - Name</p>

                        <p class="select_products__price">Price: &pound;250.00</p>

                            <p class="select_products__broken_price">
                                (unit price: &pound;250.00, tax: &pound;0.00, duty: &pound;0.00)
                            </p>


                    </div>
                </div>
                <div class="select_products__variant_table" id="select_products__variant_table_114">

                    <table class="data wide-data select_products__product_variants_table" id="select_products__product_table_114">
                        <thead>
                            <tr>
                                <th>&nbsp;&nbsp;&nbsp;SKU</th>
                                <th>Designer<br>Size</th>
                                <th>Freestock</th>
                                <th>Ordered</th>
                                <th>Waiting List</th>
                                <th>Total<br>Pre Orders</th>
                                <th>Pre Ordered<br>by Customer</th>
                                <th></th>
                            </tr>
                        </thead>
                        <tbody>

                            <tr class="dividebelow">
                                <td>&nbsp;&nbsp;&nbsp;114-863&nbsp;&nbsp;</td>
                                <td>None/Unknown</td>
                                <td>0</td>
                                <td>10</td>
                                <td>0</td>
                                <td>0</td>
                                <td>0</td>
                                <td>

                                    <input class="select_products__product_table_114_checkbox select_products__variants_checkbox" name="variants"  value="340" type="checkbox">

                                </td>
                            </tr>

                            <tr class="dividebelow">
                                <td>&nbsp;&nbsp;&nbsp;114-864&nbsp;&nbsp;</td>
                                <td>None/Unknown</td>
                                <td>0</td>
                                <td>10</td>
                                <td>0</td>
                                <td>0</td>
                                <td>0</td>
                                <td>

                                    <input class="select_products__product_table_114_checkbox select_products__variants_checkbox" name="variants"  value="341" type="checkbox">

                                </td>
                            </tr>

                            <tr class="dividebelow">
                                <td>&nbsp;&nbsp;&nbsp;114-865&nbsp;&nbsp;</td>
                                <td>None/Unknown</td>
                                <td>0</td>
                                <td>10</td>
                                <td>0</td>
                                <td>0</td>
                                <td>0</td>
                                <td>

                                    <input class="select_products__product_table_114_checkbox select_products__variants_checkbox" name="variants"  value="342" type="checkbox">

                                </td>
                            </tr>

                        </tbody>
                    </table>

                </div>
            </div>

            <div class="select_products__variant_selection_box faint_bordered_box">
                <div class="select_products__variant_data" id="select_products__variant_data_115">
                    <div class="select_products__product_image">
                        <img width="50" src="http://cache.net-a-porter.com/images/products/115/115_in_m.jpg">
                    </div>
                    <div class="select_products__product_details">
                        <p class="select_products__description">République ✪ Ceccarelli - Name</p>

                        <p class="select_products__price">Price: &pound;300.00</p>

                            <p class="select_products__broken_price">
                                (unit price: &pound;300.00, tax: &pound;0.00, duty: &pound;0.00)
                            </p>


                    </div>
                </div>
                <div class="select_products__variant_table" id="select_products__variant_table_115">

                    <table class="data wide-data select_products__product_variants_table" id="select_products__product_table_115">
                        <thead>
                            <tr>
                                <th>&nbsp;&nbsp;&nbsp;SKU</th>
                                <th>Designer<br>Size</th>
                                <th>Freestock</th>
                                <th>Ordered</th>
                                <th>Waiting List</th>
                                <th>Total<br>Pre Orders</th>
                                <th>Pre Ordered<br>by Customer</th>
                                <th></th>
                            </tr>
                        </thead>
                        <tbody>

                            <tr class="dividebelow">
                                <td>&nbsp;&nbsp;&nbsp;115-863&nbsp;&nbsp;</td>
                                <td>None/Unknown</td>
                                <td>0</td>
                                <td>10</td>
                                <td>0</td>
                                <td>0</td>
                                <td>0</td>
                                <td>

                                    <input class="select_products__product_table_115_checkbox select_products__variants_checkbox" name="variants"  value="343" type="checkbox">

                                </td>
                            </tr>

                            <tr class="dividebelow">
                                <td>&nbsp;&nbsp;&nbsp;115-864&nbsp;&nbsp;</td>
                                <td>None/Unknown</td>
                                <td>0</td>
                                <td>10</td>
                                <td>0</td>
                                <td>0</td>
                                <td>0</td>
                                <td>

                                    <input class="select_products__product_table_115_checkbox select_products__variants_checkbox" name="variants"  value="344" type="checkbox">

                                </td>
                            </tr>

                            <tr class="dividebelow">
                                <td>&nbsp;&nbsp;&nbsp;115-865&nbsp;&nbsp;</td>
                                <td>None/Unknown</td>
                                <td>0</td>
                                <td>10</td>
                                <td>0</td>
                                <td>0</td>
                                <td>0</td>
                                <td>

                                    <input class="select_products__product_table_115_checkbox select_products__variants_checkbox" name="variants"  value="345" type="checkbox">

                                </td>
                            </tr>

                        </tbody>
                    </table>

                </div>
            </div>

        </div>
        <div id="select_products__variant_form_buttons">
            <input type="button" class="button" name="button" id="select_products__reset_variants_button" value="Clear Selection">
            <input type="button" class="button" name="button" id="select_products__submit_variants_button" value="Select Products">
        </div>
    </form>
</div>

<script language="javascript" type="text/javascript">
    var country_areas  = {};
    var current_county = "";
</script>
<!-- here be popups -->
<div id="popup_address__dialog">

<div id="address_popup__previous_address_section">
    <h3 class="title-NAP">Select Shipment Address</h3>
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

                        <td><input checked="checked" type="radio" id="address_popup__selected_address_id" name="address_id" value="23">
                             <input type="hidden" id="23_str" value="Test-forename,Test-surname
2321312++rrrr++United Kingdom++">
                        </td>
                        <td>Test-forename Test-surname</td>
                        <td>
                            2321312


                            ,<br>
                            rrrr

                        </td>
                        <td>United Kingdom</td>
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
    <h3 class="title-NAP">New Shipment Address</h3>
    <div class="address_popup__new_address_input_fields">
        <input type="hidden" class="new_address__form" id="new_address__pre_order_id" value="">
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
                <td><input type="text" class="new_address__form_input" value="" id="new_address__address_line_1" default_value=""></td>
            </tr>
            <tr class="dividebelow">
                <td>Address Line 2</td>
                <td><input type="text" class="new_address__form_input" value="" id="new_address__address_line_2" default_value=""></td>
            </tr>
            <tr class="dividebelow">
                <td><p class="new_address__field_required">City*</p></td>
                <td><input type="text" class="new_address__form_input" value="" id="new_address__towncity" default_value=""></td>
            </tr>
            <tr class="dividebelow">
                <td>
                    <p class="new_address__field_required">Postcode*</p>
                </td>
                <td><input type="text" class="new_address__form_input" value="" id="new_address__postcode" default_value=""></td>
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
                    <select class="new_address__form_input" id="new_address__country" default_value="">
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

                        <option id="80" value="Switzerland" >Switzerland</option>

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

                        <option id="87" value="United Kingdom"  selected >United Kingdom</option>

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
<!-- here be no popups -->





        </div>
    </div>

    <p id="footer">    xTracker-DC  (2014.07.00.10.gd7e18e5 / IWS phase 2 / PRL phase 0 / ). &copy; 2006 - 2014 NET-A-PORTER

</p>


</div>

    </body>
</html>
