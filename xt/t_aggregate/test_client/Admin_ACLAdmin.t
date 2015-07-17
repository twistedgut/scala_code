#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

Admin_ACLAdmin.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /Admin/ACLAdmin

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/Admin/ACLAdmin',
    expected   => {
      page_data => {
        'Build Main Nav using LDAP' => '1',
        hidden_fields => {
          dbl_submit_token => '2265:OGpDhdp0deQCSt5UYwVF8A'
        }
      }
    }
);

__DATA__
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<!-- saved from url=(0038)http://10.5.16.161:8529/Admin/ACLAdmin -->
<html lang="en"><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">


        <title>ACL Admin • Admin • XT-DC1</title>


        <link rel="shortcut icon" href="http://10.5.16.161:8529/favicon.ico">



        <!-- Load jQuery -->
        <script type="text/javascript" src="./acl_admin_files/jquery-1.7.min.js"></script>
        <script type="text/javascript" src="./acl_admin_files/jquery-ui.custom.min.js"></script>
        <!-- common jQuery date picker plugin -->
        <script type="text/javascript" src="./acl_admin_files/date.js"></script>
        <script type="text/javascript" src="./acl_admin_files/datepicker.js"></script>

        <!-- jQuery CSS -->
        <link rel="stylesheet" type="text/css" href="./acl_admin_files/jquery-ui.custom.css">

        <!-- Core Javascript -->
        <script type="text/javascript" src="./acl_admin_files/common.js"></script>
        <script type="text/javascript" src="./acl_admin_files/xt_navigation.js"></script>
        <script type="text/javascript" src="./acl_admin_files/form_validator.js"></script>
        <script type="text/javascript" src="./acl_admin_files/validate.js"></script>
        <script type="text/javascript" src="./acl_admin_files/comboselect.js"></script>
        <script type="text/javascript" src="./acl_admin_files/date(1).js"></script>

        <!-- Custom Javascript -->




        <script type="text/javascript" src="./acl_admin_files/tooltip_popup.js"></script>
        <script type="text/javascript" src="./acl_admin_files/quick_search_help.js"></script>

        <!-- YUI majik -->
        <script type="text/javascript" src="./acl_admin_files/yahoo-dom-event.js"></script>
        <script type="text/javascript" src="./acl_admin_files/container_core-min.js"></script>
        <script type="text/javascript" src="./acl_admin_files/menu-min.js"></script>
        <script type="text/javascript" src="./acl_admin_files/animation.js"></script>
        <!-- dialog dependencies -->
        <script type="text/javascript" src="./acl_admin_files/element-min.js"></script>
        <!-- Scripts -->
        <script type="text/javascript" src="./acl_admin_files/utilities.js"></script>
        <script type="text/javascript" src="./acl_admin_files/container-min.js"></script>
        <script type="text/javascript" src="./acl_admin_files/yahoo-min.js"></script>
        <script type="text/javascript" src="./acl_admin_files/dom-min.js"></script>
        <script type="text/javascript" src="./acl_admin_files/element-min.js"></script>
        <script type="text/javascript" src="./acl_admin_files/datasource-min.js"></script>
        <script type="text/javascript" src="./acl_admin_files/datatable-min.js"></script>
        <script type="text/javascript" src="./acl_admin_files/tabview-min.js"></script>
        <script type="text/javascript" src="./acl_admin_files/slider-min.js"></script>
        <!-- Connection Dependencies -->
        <script type="text/javascript" src="./acl_admin_files/event-min.js"></script>
        <script type="text/javascript" src="./acl_admin_files/connection-min.js"></script>
        <!-- YUI Autocomplete sources -->
        <script type="text/javascript" src="./acl_admin_files/autocomplete-min.js"></script>
        <!-- calendar -->
        <script type="text/javascript" src="./acl_admin_files/calendar.js"></script>
        <!-- Custom YUI widget -->
        <script type="text/javascript" src="./acl_admin_files/Editable.js"></script>
        <!-- CSS -->
        <link rel="stylesheet" type="text/css" href="./acl_admin_files/grids-min.css">
        <link rel="stylesheet" type="text/css" href="./acl_admin_files/button.css">
        <link rel="stylesheet" type="text/css" href="./acl_admin_files/datatable.css">
        <link rel="stylesheet" type="text/css" href="./acl_admin_files/tabview.css">
        <link rel="stylesheet" type="text/css" href="./acl_admin_files/menu.css">
        <link rel="stylesheet" type="text/css" href="./acl_admin_files/container.css">
        <link rel="stylesheet" type="text/css" href="./acl_admin_files/autocomplete.css">
        <link rel="stylesheet" type="text/css" href="./acl_admin_files/calendar.css">

        <!-- (end) YUI majik -->





        <!-- Custom CSS -->



        <!-- Core CSS
            Placing these here allows us to override YUI styles if we want
            to, but still have extra/custom CSS below to override the default XT
            styles
        -->
        <link rel="stylesheet" type="text/css" media="screen" href="./acl_admin_files/xtracker.css">
        <link rel="stylesheet" type="text/css" media="screen" href="./acl_admin_files/xtracker_static.css">
        <link rel="stylesheet" type="text/css" media="screen" href="./acl_admin_files/customer.css">
        <link rel="stylesheet" type="text/css" media="print" href="./acl_admin_files/print.css">

        <!--[if lte IE 7]>
          <link rel="stylesheet" type="text/css" href="/css/xtracker_ie.css">
        <![endif]-->
        <!--[if lte IE 6]>
          <link rel="stylesheet" type="text/css" href="/css/xtracker_ie6.css">
        <![endif]-->




    </head>
    <body class="yui-skin-sam"><iframe id="_yuiResizeMonitor" title="Text Resize Monitor" style="position: absolute; visibility: visible; width: 2em; height: 2em; top: -37px; left: 0px; border-width: 0px;"></iframe>

        <div id="container">

    <div id="header">
    <div id="headerTop">
        <div id="headerLogo">
           <table>
              <tbody><tr>
                 <td valign="bottom"><img width="35px" height="35px" src="./acl_admin_files/flag_INTL.png"></td>
                 <td>
                    <img src="./acl_admin_files/logo_small.gif" alt="xTracker">
                    <span>DISTRIBUTION</span><span class="dc">DC1</span>
                 </td>
              </tr>
           </tbody></table>
        </div>



        <div id="headerControls">











                <form class="quick_search" name="quick_search" method="get" action="http://10.5.16.161:8529/QuickSearch">

                    <span class="helptooltip">
                        Quick Search:
                    </span>

                    <img id="quick_search_ext_help" src="./acl_admin_files/help.png">





                    <input name="quick_search" type="text" value="" accesskey="/">
                    <input type="submit" value="Search">

                    <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="2265:OGpDhdp0deQCSt5UYwVF8A">


                </form>


                <span class="operator_name">Logged in as: Andrew Beech</span>

                <a href="http://10.5.16.161:8529/My/Messages" class="messages"><img src="./acl_admin_files/email_open.png" width="16" height="16" alt="Messages" title="No New Messages"></a>

                <a href="http://10.5.16.161:8529/Logout">Logout</a>
        </div>



        <select onchange="location.href=this.options[this.selectedIndex].value">
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
        <img src="./acl_admin_files/model_INTL.jpg" width="157" height="87" alt="">
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
<div id="nav1" class="yuimenubar yuimenubarnav yui-module yui-overlay visible" style="z-index: 2; position: static; display: block; visibility: visible;">

        <div class="bd">
            <ul class="first-of-type">

                    <li class="yuimenubaritem first-of-type" id="yui-gen0" groupindex="0" index="0"><a href="http://10.5.16.161:8529/Home" class="yuimenubaritemlabel">Home</a></li>




                        <li class="yuimenubaritem yuimenubaritem-hassubmenu" id="yui-gen2" groupindex="0" index="1">
                            <a href="http://10.5.16.161:8529/Admin/ACLAdmin#yui-gen1" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Admin</a>
                            <div class="yuimenu yui-module yui-overlay yui-overlay-hidden" id="yui-gen1" style="z-index: 2; position: absolute; visibility: hidden;">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Admin/EmailTemplates" class="yuimenuitemlabel">Email Templates</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Admin/UserAdmin" class="yuimenuitemlabel">User Admin</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="./acl_admin_files/acl_admin.html" class="yuimenuitemlabel">ACL Admin</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Admin/ExchangeRates" class="yuimenuitemlabel">Exchange Rates</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Admin/Printers" class="yuimenuitemlabel">Printers</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Admin/SystemParameters" class="yuimenuitemlabel">System Parameters</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li class="yuimenubaritem yuimenubaritem-hassubmenu" id="yui-gen4" groupindex="0" index="2">
                            <a href="http://10.5.16.161:8529/Admin/ACLAdmin#yui-gen3" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Customer Care</a>
                            <div class="yuimenu yui-module yui-overlay yui-overlay-hidden" id="yui-gen3" style="z-index: 2; position: absolute; visibility: hidden;">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/CustomerCare/CustomerSearch" class="yuimenuitemlabel">Customer Search</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/CustomerCare/OrderSearch" class="yuimenuitemlabel">Order Search</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/CustomerCare/ReturnsPending" class="yuimenuitemlabel">Returns Pending</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li class="yuimenubaritem yuimenubaritem-hassubmenu" id="yui-gen6" groupindex="0" index="3">
                            <a href="http://10.5.16.161:8529/Admin/ACLAdmin#yui-gen5" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Finance</a>
                            <div class="yuimenu yui-module yui-overlay yui-overlay-hidden" id="yui-gen5" style="z-index: 2; position: absolute; visibility: hidden;">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Finance/ActiveInvoices" class="yuimenuitemlabel">Active Invoices</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Finance/CreditCheck" class="yuimenuitemlabel">Credit Check</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Finance/CreditHold" class="yuimenuitemlabel">Credit Hold</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Finance/InvalidPayments" class="yuimenuitemlabel">Invalid Payments</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Finance/PendingInvoices" class="yuimenuitemlabel">Pending Invoices</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Finance/StoreCredits" class="yuimenuitemlabel">Store Credits</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Finance/TransactionReporting" class="yuimenuitemlabel">Transaction Reporting</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Finance/FraudRules" class="yuimenuitemlabel">Fraud Rules</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Finance/FraudHotlist" class="yuimenuitemlabel">Fraud Hotlist</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Finance/Reimbursements" class="yuimenuitemlabel">Reimbursements</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li class="yuimenubaritem yuimenubaritem-hassubmenu" id="yui-gen8" groupindex="0" index="4">
                            <a href="http://10.5.16.161:8529/Admin/ACLAdmin#yui-gen7" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Fulfilment</a>
                            <div class="yuimenu yui-module yui-overlay yui-overlay-hidden" id="yui-gen7" style="z-index: 2; position: absolute; visibility: hidden;">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Fulfilment/Airwaybill" class="yuimenuitemlabel">Airwaybill</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Fulfilment/DDU" class="yuimenuitemlabel">DDU</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Fulfilment/Dispatch" class="yuimenuitemlabel">Dispatch</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Fulfilment/InvalidShipments" class="yuimenuitemlabel">Invalid Shipments</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Fulfilment/Labelling" class="yuimenuitemlabel">Labelling</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Fulfilment/Manifest" class="yuimenuitemlabel">Manifest</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Fulfilment/OnHold" class="yuimenuitemlabel">On Hold</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Fulfilment/Packing" class="yuimenuitemlabel">Packing</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Fulfilment/Picking" class="yuimenuitemlabel">Picking</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Fulfilment/Selection" class="yuimenuitemlabel">Selection</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Fulfilment/Pre-OrderHold" class="yuimenuitemlabel">Pre-Order Hold</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Fulfilment/PremierRouting" class="yuimenuitemlabel">Premier Routing</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Fulfilment/PackingException" class="yuimenuitemlabel">Packing Exception</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Fulfilment/Commissioner" class="yuimenuitemlabel">Commissioner</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li class="yuimenubaritem yuimenubaritem-hassubmenu" id="yui-gen10" groupindex="0" index="5">
                            <a href="http://10.5.16.161:8529/Admin/ACLAdmin#yui-gen9" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Goods In</a>
                            <div class="yuimenu yui-module yui-overlay yui-overlay-hidden" id="yui-gen9" style="z-index: 2; position: absolute; visibility: hidden;">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/GoodsIn/StockIn" class="yuimenuitemlabel">Stock In</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/GoodsIn/ItemCount" class="yuimenuitemlabel">Item Count</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/GoodsIn/QualityControl" class="yuimenuitemlabel">Quality Control</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/GoodsIn/BagAndTag" class="yuimenuitemlabel">Bag And Tag</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/GoodsIn/Putaway" class="yuimenuitemlabel">Putaway</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/GoodsIn/ReturnsArrival" class="yuimenuitemlabel">Returns Arrival</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/GoodsIn/ReturnsIn" class="yuimenuitemlabel">Returns In</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/GoodsIn/ReturnsQC" class="yuimenuitemlabel">Returns QC</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/GoodsIn/ReturnsFaulty" class="yuimenuitemlabel">Returns Faulty</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/GoodsIn/Barcode" class="yuimenuitemlabel">Barcode</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/GoodsIn/DeliveryCancel" class="yuimenuitemlabel">Delivery Cancel</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/GoodsIn/DeliveryHold" class="yuimenuitemlabel">Delivery Hold</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/GoodsIn/DeliveryTimetable" class="yuimenuitemlabel">Delivery Timetable</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/GoodsIn/RecentDeliveries" class="yuimenuitemlabel">Recent Deliveries</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/GoodsIn/Surplus" class="yuimenuitemlabel">Surplus</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/GoodsIn/VendorSampleIn" class="yuimenuitemlabel">Vendor Sample In</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li class="yuimenubaritem yuimenubaritem-hassubmenu" id="yui-gen12" groupindex="0" index="6">
                            <a href="http://10.5.16.161:8529/Admin/ACLAdmin#yui-gen11" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">NAP Events</a>
                            <div class="yuimenu yui-module yui-overlay yui-overlay-hidden" id="yui-gen11" style="z-index: 2; position: absolute; visibility: hidden;">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/NAPEvents/Manage" class="yuimenuitemlabel">Manage</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li class="yuimenubaritem yuimenubaritem-hassubmenu" id="yui-gen14" groupindex="0" index="7">
                            <a href="http://10.5.16.161:8529/Admin/ACLAdmin#yui-gen13" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Outnet Events</a>
                            <div class="yuimenu yui-module yui-overlay yui-overlay-hidden" id="yui-gen13" style="z-index: 2; position: absolute; visibility: hidden;">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/OutnetEvents/Manage" class="yuimenuitemlabel">Manage</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li class="yuimenubaritem yuimenubaritem-hassubmenu" id="yui-gen16" groupindex="0" index="8">
                            <a href="http://10.5.16.161:8529/Admin/ACLAdmin#yui-gen15" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Reporting</a>
                            <div class="yuimenu yui-module yui-overlay yui-overlay-hidden" id="yui-gen15" style="z-index: 2; position: absolute; visibility: hidden;">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Reporting/DistributionReports" class="yuimenuitemlabel">Distribution Reports</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Reporting/ShippingReports" class="yuimenuitemlabel">Shipping Reports</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li class="yuimenubaritem yuimenubaritem-hassubmenu" id="yui-gen18" groupindex="0" index="9">
                            <a href="http://10.5.16.161:8529/Admin/ACLAdmin#yui-gen17" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Retail</a>
                            <div class="yuimenu yui-module yui-overlay yui-overlay-hidden" id="yui-gen17" style="z-index: 2; position: absolute; visibility: hidden;">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Retail/AttributeManagement" class="yuimenuitemlabel">Attribute Management</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li class="yuimenubaritem yuimenubaritem-hassubmenu" id="yui-gen20" groupindex="0" index="10">
                            <a href="http://10.5.16.161:8529/Admin/ACLAdmin#yui-gen19" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">RTV</a>
                            <div class="yuimenu yui-module yui-overlay yui-overlay-hidden" id="yui-gen19" style="z-index: 2; position: absolute; visibility: hidden;">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/RTV/FaultyGI" class="yuimenuitemlabel">Faulty GI</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/RTV/InspectPick" class="yuimenuitemlabel">Inspect Pick</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/RTV/RequestRMA" class="yuimenuitemlabel">Request RMA</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/RTV/ListRMA" class="yuimenuitemlabel">List RMA</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/RTV/ListRTV" class="yuimenuitemlabel">List RTV</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/RTV/PickRTV" class="yuimenuitemlabel">Pick RTV</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/RTV/PackRTV" class="yuimenuitemlabel">Pack RTV</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/RTV/AwaitingDispatch" class="yuimenuitemlabel">Awaiting Dispatch</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/RTV/DispatchedRTV" class="yuimenuitemlabel">Dispatched RTV</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/RTV/NonFaulty" class="yuimenuitemlabel">Non Faulty</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li class="yuimenubaritem yuimenubaritem-hassubmenu" id="yui-gen22" groupindex="0" index="11">
                            <a href="http://10.5.16.161:8529/Admin/ACLAdmin#yui-gen21" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Sample</a>
                            <div class="yuimenu yui-module yui-overlay yui-overlay-hidden" id="yui-gen21" style="z-index: 2; position: absolute; visibility: hidden;">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Sample/ReviewRequests" class="yuimenuitemlabel">Review Requests</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Sample/SampleCart" class="yuimenuitemlabel">Sample Cart</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Sample/SampleTransfer" class="yuimenuitemlabel">Sample Transfer</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/Sample/SampleCartUsers" class="yuimenuitemlabel">Sample Cart Users</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li class="yuimenubaritem yuimenubaritem-hassubmenu" id="yui-gen24" groupindex="0" index="12">
                            <a href="http://10.5.16.161:8529/Admin/ACLAdmin#yui-gen23" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Stock Control</a>
                            <div class="yuimenu yui-module yui-overlay yui-overlay-hidden" id="yui-gen23" style="z-index: 2; position: absolute; visibility: hidden;">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/StockControl/DutyRates" class="yuimenuitemlabel">Duty Rates</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/StockControl/Inventory" class="yuimenuitemlabel">Inventory</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/StockControl/Measurement" class="yuimenuitemlabel">Measurement</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/StockControl/ProductApproval" class="yuimenuitemlabel">Product Approval</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/StockControl/PurchaseOrder" class="yuimenuitemlabel">Purchase Order</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/StockControl/Quarantine" class="yuimenuitemlabel">Quarantine</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/StockControl/Reservation" class="yuimenuitemlabel">Reservation</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/StockControl/Sample" class="yuimenuitemlabel">Sample</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/StockControl/StockCheck" class="yuimenuitemlabel">Stock Check</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/StockControl/ChannelTransfer" class="yuimenuitemlabel">Channel Transfer</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li class="yuimenubaritem yuimenubaritem-hassubmenu" id="yui-gen26" groupindex="0" index="13">
                            <a href="http://10.5.16.161:8529/Admin/ACLAdmin#yui-gen25" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Web Content</a>
                            <div class="yuimenu yui-module yui-overlay yui-overlay-hidden" id="yui-gen25" style="z-index: 2; position: absolute; visibility: hidden;">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/WebContent/DesignerLanding" class="yuimenuitemlabel">Designer Landing</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="http://10.5.16.161:8529/WebContent/Magazine" class="yuimenuitemlabel">Magazine</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>


            </ul>
        </div>

</div>

</div>


    <div id="content"><div class="ui-dialog ui-widget ui-widget-content ui-corner-all" tabindex="-1" role="dialog" aria-labelledby="ui-dialog-title-quick_search_ext_help_content" style="display: none; z-index: 1000; outline: 0px;"><div id="quick_search_ext_help_content" class="ui-dialog-content ui-widget-content" style="display: block;">
                        <h1>Quick Search Extended Help</h1>
                        <p>Entering a number on its own will search customer number, order number and shipment number.</p>
                        <p>or just enter <i>an email address</i><br>
                        or <i>any text</i> to search customer names</p>
                        <p>Example:</p>
                        <p>12345 will search for orders, shipments and customers with that ID.</p>
                        <p>o 12345 will search for orders with that ID.</p>
                        <p>John Smith will search for a customer by that name.</p>
                        <table>
                            <tbody><tr><th width="20%">Key</th><th>Search Using</th></tr>
                            <tr><td colspan="2"><hr></td></tr>
                            <tr><td colspan="2">Customer Search</td></tr>
                            <tr><td colspan="2"><hr></td></tr>
                            <tr><td>c</td><td>Customer number / name</td></tr>
                            <tr><td>e</td><td>Email Address</td></tr>
                            <tr><td>f</td><td>First Name</td></tr>
                            <tr><td>l</td><td>Last Name</td></tr>
                            <tr><td>t</td><td>Telephone number</td></tr>
                            <tr><td colspan="2"><hr></td></tr>
                            <tr><td colspan="2">Order / PreOrder Search</td></tr>
                            <tr><td colspan="2"><hr></td></tr>
                            <tr><td>o</td><td>Order Number</td></tr>
                            <tr><td>op</td><td>Orders for Product ID</td></tr>
                            <tr><td>ok</td><td>Orders for SKU</td></tr>
                            <tr><td colspan="2"><hr></td></tr>
                            <tr><td colspan="2">Product / SKU Search</td></tr>
                            <tr><td colspan="2"><hr></td></tr>
                            <tr><td>p</td><td>Product ID / SKU</td></tr>
                            <tr><td colspan="2"><hr></td></tr>
                            <tr><td colspan="2">Shipment / Return Search</td></tr>
                            <tr><td colspan="2"><hr></td></tr>
                            <tr><td>s</td><td>Shipment Number</td></tr>
                            <tr><td>x</td><td>Box ID</td></tr>
                            <tr><td>w</td><td>Airwaybill Number</td></tr>
                            <tr><td>r</td><td>RMA Number</td></tr>
                            <tr><td colspan="2"><hr></td></tr>
                            <tr><td colspan="2">Address Search</td></tr>
                            <tr><td colspan="2"><hr></td></tr>
                            <tr><td>b</td><td>Billing Address</td></tr>
                            <tr><td>a</td><td>Shipping Address</td></tr>
                            <tr><td>z</td><td>Postcode / Zip Code</td></tr>
                            <tr><td colspan="2"><hr></td></tr>
                        </tbody></table>
                        <button class="button" onclick="$(this).parent().dialog(&#39;close&#39;);">Close</button>
                    </div></div>

        <div id="contentLeftCol">


</div>




        <div id="contentRight">













                    <div id="pageTitle">
                        <h1>Admin</h1>
                        <h5>•</h5><h2>ACL Admin</h2>

                    </div>






                    <p class="bc-container">
  </p><ul class="breadcrumb">


  </ul>
<p></p>

                    <h3 class="title">ACL Settings</h3>
<form id="acl_admin_setting" name="acl_admin_setting" method="post" action="./acl_admin_files/acl_admin.html">
    <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="2265:OGpDhdp0deQCSt5UYwVF8A">


    <p class="spaced">
        This is a <strong>System Wide</strong> setting which will control whether the Main Navigation is built using an Operator's LDAP Roles or the values in the 'operator_authorisation' table for the Operator. If '<strong>On</strong>' then an attempt to build the Main Navigation will be done for an Operator if they have been assigned Roles else it will fall back to using the 'operator_authorisation' table. If '<strong>Off</strong>' then no attempt will be made to build the Main Navigation using an Operator's LDAP Roles.
    </p>
    <div class="formrow divideabove dividebelow">
        <label for="setting_build_main_nav">Build Main Nav using LDAP:</label>
        <input id="setting_build_main_nav" name="setting_build_main_nav" type="checkbox" value="1" checked="checked">
    </div>

    <div class="formrow aftertable buttons formend">
        <input class="button" name="submit" type="submit" value="Submit »">
    </div>
</form>





        </div>
    </div>

    <p id="footer">    xTracker-DC  (2013.11.00.00.51.g7bb44a1 / IWS phase 2 / PRL phase 0 / 2013-08-29 09:23:12). © 2006 - 2013 NET-A-PORTER
</p>


</div>



<div id="anchorTitle"></div></body></html>
