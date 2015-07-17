#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

GoodsIn_Putaway_Admin.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /GoodsIn/PutawayPrepAdmin

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/GoodsIn/PutawayPrepAdmin',
    expected   => {
        container_table => [
          {
            '-' => '-',
            '0' => '1',
            'Emma Holmes' => 'David Sherry',
            T123444 => 'T123456'
          },
          {
            '-' => 'Sent',
            '0' => '45',
            'Emma Holmes' => 'David Sherry',
            T123444 => 'T123410'
          },
          {
            '-' => '-',
            '0' => '1',
            'Emma Holmes' => 'David Sherry',
            T123444 => 'T123411'
          },
          {
            '-' => 'Putaway',
            '0' => '14',
            'Emma Holmes' => 'David Sherry',
            T123444 => 'T123410'
          },
          {
            '-' => 'Putaway',
            '0' => '25',
            'Emma Holmes' => 'Dawn Fong',
            T123444 => 'T129874'
          },
          {
            '-' => '-',
            '0' => '25',
            'Emma Holmes' => 'Dawn Fong',
            T123444 => 'T129877'
          },
          {
            '-' => 'Sent',
            '0' => '50',
            'Emma Holmes' => 'David Sherry',
            T123444 => 'T123456'
          },
          {
            '-' => 'Overheight',
            '0' => '10',
            'Emma Holmes' => 'David Sherry',
            T123444 => 'T123456'
          },
          {
            '-' => 'Overheight',
            '0' => '35',
            'Emma Holmes' => 'David Sherry',
            T123444 => 'T123456'
          },
          {
            '-' => 'Sent',
            '0' => '2',
            'Emma Holmes' => 'Peter Sergeant',
            T123444 => 'T546871'
          },
          {
            '-' => 'Sent',
            '0' => '2',
            'Emma Holmes' => '',
            T123444 => 'M000000001'
          },
          {
            '-' => 'Sent',
            '0' => '2',
            'Emma Holmes' => '',
            T123444 => 'M000000001'
          },
          {
            '-' => '-',
            '0' => '0',
            'Emma Holmes' => 'Emma Holmes',
            T123444 => 'T523444'
          },
          {
            '-' => 'Sent',
            '0' => '1',
            'Emma Holmes' => 'David Sherry',
            T123444 => 'T523444'
          }
       ],
       'stock_process_table' => [
                {
                  'Qty Expected' => '10',
                  'PID' => '162534',
                  'Delivery Date' => '18-08-2012',
                  'Status' => 'In Progress',
                  'Designer' => 'Jil Sander',
                  'Group' => '1411971',
                  'Last Action' => '-',
                  'Upload Date' => '24-08-2012',
                  'Type' => 'Main',
                  'PRL' => 'Base',
                  'Delivery' => '913927',
                  'Qty Scanned' => '0'
                },
                {
                  'Qty Expected' => '10',
                  'PID' => '162555',
                  'Delivery Date' => '18-08-2012',
                  'Status' => 'In Progress',
                  'Designer' => 'Charvet',
                  'Group' => '1411972',
                  'Last Action' => '-',
                  'Upload Date' => '24-08-2012',
                  'Type' => 'Main',
                  'PRL' => 'Base',
                  'Delivery' => '913927',
                  'Qty Scanned' => '1'
                },
                {
                  'Qty Expected' => '50',
                  'PID' => '172275',
                  'Delivery Date' => '16-08-2012',
                  'Status' => 'Advice Sent',
                  'Designer' => 'Kain',
                  'Group' => '1309033',
                  'Last Action' => '16-08-2012 17:00',
                  'Upload Date' => '26-08-2012',
                  'Type' => 'Main',
                  'PRL' => 'Base',
                  'Delivery' => '341436',
                  'Qty Scanned' => '45'
                },
                {
                  'Qty Expected' => '15',
                  'PID' => '246782',
                  'Delivery Date' => '16-08-2012',
                  'Status' => 'Advice Sent',
                  'Designer' => 'Sunspel',
                  'Group' => '164978',
                  'Last Action' => '16-08-2012 14:00',
                  'Upload Date' => '26-08-2012',
                  'Type' => 'Main',
                  'PRL' => 'Base',
                  'Delivery' => '512678',
                  'Qty Scanned' => '14'
                },
                {
                  'Qty Expected' => '50',
                  'PID' => '124678',
                  'Delivery Date' => '16-08-2012',
                  'Status' => 'Advice Sent',
                  'Designer' => 'Converse',
                  'Group' => '1502121',
                  'Last Action' => '16-08-2012 19:00',
                  'Upload Date' => '26-08-2012',
                  'Type' => 'Main',
                  'PRL' => 'Base',
                  'Delivery' => '341436',
                  'Qty Scanned' => '25'
                },
                {
                  'Qty Expected' => '50',
                  'PID' => '327896',
                  'Delivery Date' => '16-08-2012',
                  'Status' => 'Awaiting Putaway',
                  'Designer' => 'Roland Mouret',
                  'Group' => '1234587',
                  'Last Action' => '16-08-2012 19:02',
                  'Upload Date' => '26-08-2012',
                  'Type' => 'Main',
                  'PRL' => 'Base',
                  'Delivery' => '341436',
                  'Qty Scanned' => '50'
                },
                {
                  'Qty Expected' => '10',
                  'PID' => '546784',
                  'Delivery Date' => '16-08-2012',
                  'Status' => 'Failed Advice',
                  'Designer' => 'Paul Smith',
                  'Group' => '1546746',
                  'Last Action' => '16-08-2012 19:12',
                  'Upload Date' => '26-08-2012',
                  'Type' => 'Main',
                  'PRL' => 'Base',
                  'Delivery' => '451678',
                  'Qty Scanned' => '10'
                },
                {
                  'Qty Expected' => '35',
                  'PID' => '124578',
                  'Delivery Date' => '16-08-2012',
                  'Status' => 'Failed Advice',
                  'Designer' => 'Balmain',
                  'Group' => '124589',
                  'Last Action' => '16-08-2012 20:05',
                  'Upload Date' => '26-08-2012',
                  'Type' => 'Main',
                  'PRL' => 'GOH',
                  'Delivery' => '245678',
                  'Qty Scanned' => '37'
                },
              ],
      'returns_table' => [
          {
            'Qty Expected' => '1',
            'Status' => 'In Progress',
            'Designer' => 'Jil Sander',
            'Group' => '3411971',
            'Last Action' => '-',
            'Type' => 'Main',
            'PRL' => 'GOH',
            'Delivery' => '8913927',
            'Qty Scanned' => '1',
            'SKU' => '162534-123',
            'RMA Number' => 'U1247704-475488'
          },
          {
            'Qty Expected' => '1',
            'Status' => 'Awaiting Putaway',
            'Designer' => 'Charvet',
            'Group' => '3411972',
            'Last Action' => '-',
            'Type' => 'Main',
            'PRL' => 'Base',
            'Delivery' => '8913927',
            'Qty Scanned' => '1',
            'SKU' => '162535-103',
            'RMA Number' => 'U1130878-423821'
          }
        ],
      'recodes_table' => [
          {
            'Qty Expected' => '5',
            'Status' => 'Failed Advice',
            'Designer' => 'Brooks Brothers',
            'Group' => 'r147',
            'Last Action' => '09-10-2012 16:53',
            'Type' => 'Recode',
            'PRL' => 'Full PRL',
            'Delivery' => '',
            'Qty Scanned' => '5',
            'PID' => '197360'
          },
          {
            'Qty Expected' => '3',
            'Status' => 'Part Complete',
            'Designer' => 'Sandro',
            'Group' => 'r143',
            'Last Action' => '07-09-2012 16:35',
            'Type' => 'Recode',
            'PRL' => 'Full PRL',
            'Delivery' => '',
            'Qty Scanned' => '2',
            'PID' => '193273'
          }
        ]
    },
);

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en">
    <head>
        <meta http-equiv="Content-type" content="text/html; charset=utf-8">

        <title>XT-DC2</title>


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


            <script type="text/javascript" src="/javascript/jquery.tablesorter.min.js"></script>




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
                 <td valign="bottom"><img width="35px" height="35px" src="/images/flag_AM.png"></td>
                 <td>
                    <img src="/images/logo_small.gif" alt="xTracker">
                    <span>DISTRIBUTION</span><span class="dc">DC2</span>
                 </td>
              </tr>
           </table>
        </div>

            <div id="headerControls">
                <span class="operator_name">Anne Thorniley</span>
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
                                                <a href="/Admin/EmailTemplates" class="yuimenuitemlabel">Email Templates</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/JobQueue" class="yuimenuitemlabel">Job Queue</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/CarrierAutomation" class="yuimenuitemlabel">Carrier Automation</a>
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
                                                <a href="/Finance/StoreCredits" class="yuimenuitemlabel">Store Credits</a>
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

                                            <li class="menuitem">
                                                <a href="/Fulfilment/Manifest" class="yuimenuitemlabel">Manifest</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/Labelling" class="yuimenuitemlabel">Labelling</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/PackingException" class="yuimenuitemlabel">Packing Exception</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/Commissioner" class="yuimenuitemlabel">Commissioner</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/PremierRouting" class="yuimenuitemlabel">Premier Routing</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/PremierDispatch" class="yuimenuitemlabel">Premier Dispatch</a>
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
                                                <a href="/StockControl/PerpetualInventory" class="yuimenuitemlabel">Perpetual Inventory</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/Location" class="yuimenuitemlabel">Location</a>
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

                                            <li class="menuitem">
                                                <a href="/StockControl/Recode" class="yuimenuitemlabel">Recode</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/StockAdjustment" class="yuimenuitemlabel">Stock Adjustment</a>
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




        <div id="contentRight"class="noleftcol">











                        <p class="error_msg">More than one group with the same Group ID is in progress. Page may not display correctly. Duplicate Group IDs: </p>


                    <div id="pageTitle">
                        <h1>Goods In</h1>
                        <h5>&bull;</h5><h2>Putaway</h2>
                        <h5>&bull;</h5><h3>Process Item</h3>
                    </div>








<script type="text/javascript">

// Actually expand a row, with all the UI cruft that goes with it
function expandGroup (group) {

    // Close any other that are open
    stripRows();

    // Expand the relevant group
    decorateRow( group );

    var link = $('#expand-' + group);

    // Flip the appropriate icon
    link.find('img').attr( 'src', '/images/minus.gif' );

    // Add a handler to the icon to close it
    link.unbind('click');
    link.click( function () { stripRows(); return false; });
}

/* Add container data below a group row */
function decorateRow (group) {
    // Find the row we're talking about
    var targetRow = $('#group-' + group).first();

    // If we didn't find anything, silently return
    if ( targetRow.length < 1 ) { return; }

    // First we need to create the gaudy bauble we're displaying to the user
    var table = $('<table></table>');
    var tbody = $('<tbody></tbody>')
    table.append( tbody );

    // It'll need a header row
    table.append( $('#container-table thead').clone() );

    // How many columns does the target row have?
    var cols = targetRow.find('td').length;

    // Create the target row and put it in
    var displayRow =
        $('<tr class="group-containers"></tr>').append(
            $('<td colspan="' + cols + '"></td>').append(
                table
            )
        );

    // Add the relevant container rows
    $('#container-table tr[data-group="' + group + '"]').each( function (i,o) {
        tbody.append( $(o).clone() );
    });

    // Add that after the target row
    targetRow.after( displayRow );
}

/* Remove all container data from group rows and flip the icons back to normal */
function stripRows () {
    $('.group-table .group-containers').remove();

    // Make sure that all the icons have a plus sign and the correct handler
    $('.expand-link').each( function (i,o) {

        // The group we're working with
        var group = $(o).attr('data-group');

        // Make sure we're showing the plus icon
        $(o).find('img').attr('src', '/images/plus.gif');

        // Set the onclick handler
        $(o).unbind('click');
        $(o).click( function () { expandGroup( group ); return false; } );
    });
}

/* Build the PRL filter */
function buildPRLFilter() {
    var countPRL = {};
    var allPRL   = [];

    // Loop through all group rows
    $('.group-row').each( function (i,o) {
        var PRL = $(o).attr('data-prl');
        if ( PRL in countPRL ) {
            countPRL[PRL]++
        } else {
            countPRL[PRL] = 1;
            allPRL.push( PRL );
        }
    });

    // Alphabetically sort the PRL names
    allPRL.sort();

    // Add the drop-down values for each available PRL
    jQuery.each( allPRL, function(i,o) {
        $('#prl-filter').append('<option value="'+o+'">'+o+' ('+countPRL[o]+')</option>');
    });

    // Filter PRLs when the drop-down is changed
    $('#prl-filter').bind( 'change', function (e) {
        revealPRLs();
        var filterTo = $('#prl-filter').val();
        if ( filterTo ) {
            filterPRLs( filterTo );
        }
    });
}

// Shows groups from all PRLs
function revealPRLs () {
    stripRows(); // Don't want any hanging container data
    $('.group-row').show();
}
// Show groups only for a given PRL
function filterPRLs ( targetPRL ) {
    $('.group-row').each( function (i,o) {
        var PRL = $(o).attr('data-prl');
        if ( PRL != targetPRL ) {
            $(o).hide();
        }
    });
}

$(document).ready( function() {

    // Allow us to sort dates properly
    $.tablesorter.addParser({
        id: 'dd-mm-yyyy hh:mm',
        // Don't auto-match (as it could be '-' in the top row)
        is: function (s) { return false },
        format: function (s) {
            // The value we're turning the date in to
            var sort = 0;

            // Split in to date and time
            var parts = s.split(' ');
            var date = parts[0];
            var time = parts[1];

            var date_parts = date.match(/(\d{2})-(\d{2})-(\d{4})/);

            // If it's not a date, return 0
            if (! date_parts) {
                return sort;
            }
            sort += parseInt(date_parts[3] + date_parts[2] + date_parts[1] + '0000');

            // Was there a time part?
            if ( ! time ) {
                return sort;
            }

            var time_parts = time.match(/(\d{2})\:(\d{2})/);
            sort += parseInt(time_parts[1] + time_parts[2]);
            return sort;
        },
        // set type, either numeric or text
        type: 'numeric'
    });

    // Setup the sortable columns for table with extra rows
    $(".group-tablesorter-with-delivery").tablesorter({

        // Don't sort by the far-left expand column
        headers: {
            0: { sorter: false },
            7: { sorter: 'dd-mm-yyyy hh:mm' },
            8: { sorter: 'dd-mm-yyyy hh:mm' },
            11: { sorter: 'dd-mm-yyyy hh:mm' }
        }
    });
    $(".group-tablesorter-without-delivery").tablesorter({

        // Don't sort by the far-left expand column
        headers: {
            0: { sorter: false },
            9: { sorter: 'dd-mm-yyyy hh:mm' }
        }
    });

    // Clear all subrows before sorting
    $(".group-tablesorter").bind("sortStart",function() { stripRows() });

    // Add the expand parts to each row
    stripRows();

    // Build the PRL filter box
    buildPRLFilter();
});

</script>

<!-- This will get centralized when we've had this UAT'd and it settles down -->
<style>
    /* Header rows are dark grey and bold */
    .group-table thead tr th {
        background: #ccc;
        text-align: center;
        font-weight: bold;
        padding: 4px;
        cursor: pointer;
    }

    .group-table thead tr th:hover {
        background: #666;
    }

    /* Normal rows are centered, and have a border at the top */
    .group-table tbody tr td {
        text-align: center;
        border-top: 1px solid #ccc;
        padding: 4px;
    }

    /* Status colours */
    .group-table tr.highlight-cream { background: #ffff99; }
    .group-table tr.highlight-green { background: #66ff66; }
    .group-table tr.highlight-red   { background: #ff6666; }

    /* The expand button */
    .group-table div {
        height: 20px;
        width: 20px;
    }
    .group-table img {
        background: #ffffff;
        margin: auto;
        margin-top: 12px;
    }

    /* Container table indent */
    .group-table table { margin-left: 60px; }

    .group-tablesorter .headerSortDown { background: #999; }
    .group-tablesorter .headerSortUp { background: #999; }
</style>

<!-- We have two tables to show, a customer returns one and a normal putaway
     one. We reuse the same table structure for both, only the former has the
     upload and delivery dates hidden. We will look and claim to display either
     'pid' or 'sku' depending on the value of 'item_by'
-->


<p><i>Click on a column heading to sort in ascending order, and click again to
reverse the sort.</i></p>

<!-- Filtering PRL box -->
<form style="text-align: right">
    <select id="prl-filter" name="prl-filter">
        <option value="">All PRLs</option>
    </select>
</form>

<h2>Process Groups in Putaway Preparation</h2>

<!--
    This table structure contains just the group data. We marry this with the
    container data when the user wants it via JS. This makes our markup,
    parsing, and general sanity quite a lot better.
-->
<table class="group-table group-tablesorter group-tablesorter-with-delivery-without-rma" id="groups-for-stock-process">
    <thead>
        <tr>
            <th><!-- Expand Button --></th>
            <th>Group</th>
            <th>Type</th>
            <th>PRL</th>
            <th>Delivery</th>

            <th>PID</th>

            <th>Designer</th>

            <th>Delivery Date</th>
            <th>Upload Date</th>

            <th>Qty Expected</th>
            <th>Qty Scanned</th>
            <th>Last Action</th>
            <th>Status</th>
        </tr>
    </thead>
    <tbody>

        <tr id="group-1411971" class="group-row highlight-white" data-prl="Base">
            <!--
                Expand and hide containers link
                    The onclick action for this link, and the URL for its image
                    are set by the reset action of stripRows(), which is also
                    called on document.ready.
            -->
            <td style="padding: 0px;"><a
                id        = "expand-1411971"
                data-group = "1411971"
                class     = "expand-link"
                href      = "#"
                title     = "View containers associated with this group"
            ><div><img alt="Expand Row" border="0" valign="middle"/></div></a></td>

            <!-- Actual data fields -->
            <td>1411971</td>
            <td>Main</td>
            <td>Base</td>
            <td>913927</td>

            <td>162534</td>

            <td>Jil Sander</td>

            <td>18-08-2012</td>
            <td>24-08-2012</td>

            <td>10</td>
            <td>0</td>
            <td>-</td>
            <td>In Progress</td>
        </tr>

        <tr id="group-1411972" class="group-row highlight-white" data-prl="Base">
            <!--
                Expand and hide containers link
                    The onclick action for this link, and the URL for its image
                    are set by the reset action of stripRows(), which is also
                    called on document.ready.
            -->
            <td style="padding: 0px;"><a
                id        = "expand-1411972"
                data-group = "1411972"
                class     = "expand-link"
                href      = "#"
                title     = "View containers associated with this group"
            ><div><img alt="Expand Row" border="0" valign="middle"/></div></a></td>

            <!-- Actual data fields -->
            <td>1411972</td>
            <td>Main</td>
            <td>Base</td>
            <td>913927</td>

            <td>162555</td>

            <td>Charvet</td>

            <td>18-08-2012</td>
            <td>24-08-2012</td>

            <td>10</td>
            <td>1</td>
            <td>-</td>
            <td>In Progress</td>
        </tr>

        <tr id="group-1309033" class="group-row highlight-cream" data-prl="Base">
            <!--
                Expand and hide containers link
                    The onclick action for this link, and the URL for its image
                    are set by the reset action of stripRows(), which is also
                    called on document.ready.
            -->
            <td style="padding: 0px;"><a
                id        = "expand-1309033"
                data-group = "1309033"
                class     = "expand-link"
                href      = "#"
                title     = "View containers associated with this group"
            ><div><img alt="Expand Row" border="0" valign="middle"/></div></a></td>

            <!-- Actual data fields -->
            <td>1309033</td>
            <td>Main</td>
            <td>Base</td>
            <td>341436</td>

            <td>172275</td>

            <td>Kain</td>

            <td>16-08-2012</td>
            <td>26-08-2012</td>

            <td>50</td>
            <td>45</td>
            <td>16-08-2012 17:00</td>
            <td>Advice Sent</td>
        </tr>

        <tr id="group-164978" class="group-row highlight-cream" data-prl="Base">
            <!--
                Expand and hide containers link
                    The onclick action for this link, and the URL for its image
                    are set by the reset action of stripRows(), which is also
                    called on document.ready.
            -->
            <td style="padding: 0px;"><a
                id        = "expand-164978"
                data-group = "164978"
                class     = "expand-link"
                href      = "#"
                title     = "View containers associated with this group"
            ><div><img alt="Expand Row" border="0" valign="middle"/></div></a></td>

            <!-- Actual data fields -->
            <td>164978</td>
            <td>Main</td>
            <td>Base</td>
            <td>512678</td>

            <td>246782</td>

            <td>Sunspel</td>

            <td>16-08-2012</td>
            <td>26-08-2012</td>

            <td>15</td>
            <td>14</td>
            <td>16-08-2012 14:00</td>
            <td>Advice Sent</td>
        </tr>

        <tr id="group-1502121" class="group-row highlight-cream" data-prl="Base">
            <!--
                Expand and hide containers link
                    The onclick action for this link, and the URL for its image
                    are set by the reset action of stripRows(), which is also
                    called on document.ready.
            -->
            <td style="padding: 0px;"><a
                id        = "expand-1502121"
                data-group = "1502121"
                class     = "expand-link"
                href      = "#"
                title     = "View containers associated with this group"
            ><div><img alt="Expand Row" border="0" valign="middle"/></div></a></td>

            <!-- Actual data fields -->
            <td>1502121</td>
            <td>Main</td>
            <td>Base</td>
            <td>341436</td>

            <td>124678</td>

            <td>Converse</td>

            <td>16-08-2012</td>
            <td>26-08-2012</td>

            <td>50</td>
            <td>25</td>
            <td>16-08-2012 19:00</td>
            <td>Advice Sent</td>
        </tr>

        <tr id="group-1234587" class="group-row highlight-green" data-prl="Base">
            <!--
                Expand and hide containers link
                    The onclick action for this link, and the URL for its image
                    are set by the reset action of stripRows(), which is also
                    called on document.ready.
            -->
            <td style="padding: 0px;"><a
                id        = "expand-1234587"
                data-group = "1234587"
                class     = "expand-link"
                href      = "#"
                title     = "View containers associated with this group"
            ><div><img alt="Expand Row" border="0" valign="middle"/></div></a></td>

            <!-- Actual data fields -->
            <td>1234587</td>
            <td>Main</td>
            <td>Base</td>
            <td>341436</td>

            <td>327896</td>

            <td>Roland Mouret</td>

            <td>16-08-2012</td>
            <td>26-08-2012</td>

            <td>50</td>
            <td>50</td>
            <td>16-08-2012 19:02</td>
            <td>Awaiting Putaway</td>
        </tr>

        <tr id="group-1546746" class="group-row highlight-red" data-prl="Base">
            <!--
                Expand and hide containers link
                    The onclick action for this link, and the URL for its image
                    are set by the reset action of stripRows(), which is also
                    called on document.ready.
            -->
            <td style="padding: 0px;"><a
                id        = "expand-1546746"
                data-group = "1546746"
                class     = "expand-link"
                href      = "#"
                title     = "View containers associated with this group"
            ><div><img alt="Expand Row" border="0" valign="middle"/></div></a></td>

            <!-- Actual data fields -->
            <td>1546746</td>
            <td>Main</td>
            <td>Base</td>
            <td>451678</td>

            <td>546784</td>

            <td>Paul Smith</td>

            <td>16-08-2012</td>
            <td>26-08-2012</td>

            <td>10</td>
            <td>10</td>
            <td>16-08-2012 19:12</td>
            <td>Failed Advice</td>
        </tr>

        <tr id="group-124589" class="group-row highlight-red" data-prl="GOH">
            <!--
                Expand and hide containers link
                    The onclick action for this link, and the URL for its image
                    are set by the reset action of stripRows(), which is also
                    called on document.ready.
            -->
            <td style="padding: 0px;"><a
                id        = "expand-124589"
                data-group = "124589"
                class     = "expand-link"
                href      = "#"
                title     = "View containers associated with this group"
            ><div><img alt="Expand Row" border="0" valign="middle"/></div></a></td>

            <!-- Actual data fields -->
            <td>124589</td>
            <td>Main</td>
            <td>GOH</td>
            <td>245678</td>

            <td>124578</td>

            <td>Balmain</td>

            <td>16-08-2012</td>
            <td>26-08-2012</td>

            <td>35</td>
            <td>37</td>
            <td>16-08-2012 20:05</td>
            <td>Failed Advice</td>
        </tr>

    </tbody>
</table>

<h2 class="section-title">Stock Recodes in Putaway Preparation</h2>

<!--
    This table structure contains just the group data. We marry this with the
    container data when the user wants it via JS. This makes our markup,
    parsing, and general sanity quite a lot better.
-->
<table class="group-table group-tablesorter group-tablesorter-without-delivery-without-rma" id="groups-for-stock-recode">
    <thead>
        <tr>
            <th><!-- Expand Button --></th>
            <th>Group</th>
            <th>Type</th>
            <th>PRL</th>
            <th>Delivery</th>

            <th>PID</th>

            <th>Designer</th>

            <th>Qty Expected</th>
            <th>Qty Scanned</th>
            <th>Last Action</th>
            <th>Status</th>
        </tr>
    </thead>
    <tbody>

     <tr id="group-216" class="group-row highlight-group-status-failed-advice" data-prl="Full PRL">
            <!--
                Expand and hide containers link
                    The onclick action for this link, and the URL for its image
                    are set by the reset action of stripRows(), which is also
                    called on document.ready.
            -->
            <td style="padding: 0px;"><a
                id        = "expand-216"
                data-group = "216"
                class     = "expand-link"
                href      = "#"
                title     = "View containers associated with this group"
            ><div><img alt="Expand Row" border="0" valign="middle"/></div></a></td>

            <!-- Actual data fields -->
            <td>r147</td>
            <td>Recode</td>
            <td>Full PRL</td>
            <td></td>

            <td>197360</td>

            <td>Brooks Brothers</td>

            <td>5</td>
            <td>5</td>
            <td><span class="nobr">09-10-2012 16:53</span></td>
            <td>Failed Advice</td>
        </tr>

      <tr id="group-147" class="group-row highlight-group-status-part-complete" data-prl="Full PRL">
            <!--
                Expand and hide containers link
                    The onclick action for this link, and the URL for its image
                    are set by the reset action of stripRows(), which is also
                    called on document.ready.
            -->
            <td style="padding: 0px;"><a
                id        = "expand-147"
                data-group = "147"
                class     = "expand-link"
                href      = "#"
                title     = "View containers associated with this group"
            ><div><img alt="Expand Row" border="0" valign="middle"/></div></a></td>

            <!-- Actual data fields -->
            <td>r143</td>
            <td>Recode</td>
            <td>Full PRL</td>
            <td></td>

            <td>193273</td>

            <td>Sandro</td>

            <td>3</td>
            <td>2</td>
            <td><span class="nobr">07-09-2012 16:35</span></td>
            <td>Part Complete</td>
        </tr>

   </tbody>
</table>


<h2>Customer Returns in Putaway Preparation</h2>

<!--
    This table structure contains just the group data. We marry this with the
    container data when the user wants it via JS. This makes our markup,
    parsing, and general sanity quite a lot better.
-->
<table class="group-table group-tablesorter group-tablesorter-without-delivery-with-rma" id="groups-for-returns">
    <thead>
        <tr>
            <th><!-- Expand Button --></th>
            <th>Group</th>
            <th>Type</th>
            <th>PRL</th>
            <th>Delivery</th>

            <th>SKU</th>

            <th>Designer</th>
            <th>RMA Number</th>

            <th>Qty Expected</th>
            <th>Qty Scanned</th>
            <th>Last Action</th>
            <th>Status</th>
        </tr>
    </thead>
    <tbody>

        <tr id="group-3411971" class="group-row highlight-white" data-prl="GOH">
            <!--
                Expand and hide containers link
                    The onclick action for this link, and the URL for its image
                    are set by the reset action of stripRows(), which is also
                    called on document.ready.
            -->
            <td style="padding: 0px;"><a
                id        = "expand-3411971"
                data-group = "3411971"
                class     = "expand-link"
                href      = "#"
                title     = "View containers associated with this group"
            ><div><img alt="Expand Row" border="0" valign="middle"/></div></a></td>

            <!-- Actual data fields -->
            <td>3411971</td>
            <td>Main</td>
            <td>GOH</td>
            <td>8913927</td>

            <td>162534-123</td>

            <td>Jil Sander</td>


            <td>U1247704-475488</td>

            <td>1</td>
            <td>1</td>
            <td>-</td>
            <td>In Progress</td>
        </tr>

        <tr id="group-3411972" class="group-row highlight-green" data-prl="Base">
            <!--
                Expand and hide containers link
                    The onclick action for this link, and the URL for its image
                    are set by the reset action of stripRows(), which is also
                    called on document.ready.
            -->
            <td style="padding: 0px;"><a
                id        = "expand-3411972"
                data-group = "3411972"
                class     = "expand-link"
                href      = "#"
                title     = "View containers associated with this group"
            ><div><img alt="Expand Row" border="0" valign="middle"/></div></a></td>

            <!-- Actual data fields -->
            <td>3411972</td>
            <td>Main</td>
            <td>Base</td>
            <td>8913927</td>

            <td>162535-103</td>

            <td>Charvet</td>


            <td>U1130878-423821</td>

            <td>1</td>
            <td>1</td>
            <td>-</td>
            <td>Awaiting Putaway</td>
        </tr>

    </tbody>
</table>



<!--
    This contains the container ID. We don't ever show this directly to the
    user - instead we just steal data from it when we need it. This is handy,
    because it means we can isolate all the craziness in to the display layer.
-->
<table style="display: none" id="container-table">
    <thead>
        <th>Container ID</th>
        <th>Qty Scanned</th>
        <th>Operator</th>
        <th>Last Scan Time</th>
        <th>Advice Status</th>
    </thead>
    <tbody>


        <tr data-group="1411971">
            <td>T123444</td>
            <td>0</td>
            <td>Emma Holmes</td>
            <td>-</td>
            <td>-</td>
        </tr>



        <tr data-group="1411972">
            <td>T123456</td>
            <td>1</td>
            <td>David Sherry</td>
            <td>18-08-2012 19:00</td>
            <td>-</td>
        </tr>



        <tr data-group="1309033">
            <td>T123410</td>
            <td>45</td>
            <td>David Sherry</td>
            <td>16-08-2012 16:58</td>
            <td>Sent</td>
        </tr>

        <tr data-group="1309033">
            <td>T123411</td>
            <td>1</td>
            <td>David Sherry</td>
            <td>16-08-2012 17:02</td>
            <td>-</td>
        </tr>



        <tr data-group="164978">
            <td>T123410</td>
            <td>14</td>
            <td>David Sherry</td>
            <td>16-08-2012 13:58</td>
            <td>Putaway</td>
        </tr>



        <tr data-group="1502121">
            <td>T129874</td>
            <td>25</td>
            <td>Dawn Fong</td>
            <td>16-08-2012 19:00</td>
            <td>Putaway</td>
        </tr>

        <tr data-group="1502121">
            <td>T129877</td>
            <td>25</td>
            <td>Dawn Fong</td>
            <td>16-08-2012 19:10</td>
            <td>-</td>
        </tr>



        <tr data-group="1234587">
            <td>T123456</td>
            <td>50</td>
            <td>David Sherry</td>
            <td>16-08-2012 19:00</td>
            <td>Sent</td>
        </tr>



        <tr data-group="1546746">
            <td>T123456</td>
            <td>10</td>
            <td>David Sherry</td>
            <td>16-08-2012 19:09</td>
            <td>Overheight</td>
        </tr>



        <tr data-group="124589">
            <td>T123456</td>
            <td>35</td>
            <td>David Sherry</td>
            <td>16-08-2012 20:01</td>
            <td>Overheight</td>
        </tr>

        <tr data-group="124589">
            <td>T546871</td>
            <td>2</td>
            <td>Peter Sergeant</td>
            <td>16-08-2012 20:30</td>
            <td>Sent</td>
        </tr>



        <tr data-group="p1">
            <td>M000000001</td>
            <td>2</td>
            <td></td>
            <td>13-09-2012 16:18</td>
            <td>Sent</td>
        </tr>

        <tr data-group="p1">
            <td>M000000001</td>
            <td>2</td>
            <td></td>
            <td>13-09-2012 16:18</td>
            <td>Sent</td>
        </tr>



        <tr data-group="3411971">
            <td>T523444</td>
            <td>0</td>
            <td>Emma Holmes</td>
            <td>-</td>
            <td>-</td>
        </tr>



        <tr data-group="3411972">
            <td>T523444</td>
            <td>1</td>
            <td>David Sherry</td>
            <td>-</td>
            <td>Sent</td>
        </tr>


    </tbody>
</table>

<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>

<pre>
for debug:<br>

$VAR1 = [
          {
            'containers' => [
                              {
                                'advice_status' => '-',
                                'operator' => 'Emma Holmes',
                                'last_scan_time' => '',
                                'id' => 'T123444',
                                'quantity_scanned' => 0
                              }
                            ],
            'status' => 'In Progress',
            'last_advice_send' => '',
            'delivery' => 913927,
            'quantity_expected' => 10,
            'quantity_scanned' => 0,
            'designer' => 'Jil Sander',
            'delivery_date' => bless( {
                                        'local_rd_secs' => 43200,
                                        'local_rd_days' => 734733,
                                        'rd_nanosecs' => 0,
                                        'locale' => bless( {
                                                             'default_time_format_length' => 'medium',
                                                             'native_territory' => 'United States',
                                                             'native_language' => 'English',
                                                             'native_complete_name' => 'English United States',
                                                             'en_language' => 'English',
                                                             'id' => 'en_US',
                                                             'default_date_format_length' => 'medium',
                                                             'en_complete_name' => 'English United States',
                                                             'en_territory' => 'United States'
                                                           }, 'DateTime::Locale::en_US' ),
                                        'local_c' => {
                                                       'hour' => 12,
                                                       'second' => 0,
                                                       'month' => 8,
                                                       'quarter' => 3,
                                                       'day_of_year' => 231,
                                                       'day_of_quarter' => 49,
                                                       'minute' => 0,
                                                       'day' => 18,
                                                       'day_of_week' => 6,
                                                       'year' => 2012
                                                     },
                                        'utc_rd_secs' => 64800,
                                        'formatter' => undef,
                                        'tz' => bless( {
                                                         'name' => '-0600',
                                                         'offset' => -21600
                                                       }, 'DateTime::TimeZone::OffsetOnly' ),
                                        'utc_year' => 2013,
                                        'utc_rd_days' => 734733,
                                        'offset_modifier' => 0
                                      }, 'DateTime' ),
            'group_id' => 1411971,
            'pid' => 162534,
            'class' => 'white',
            'type' => 'Main',
            'upload_date' => bless( {
                                      'local_rd_secs' => 43200,
                                      'local_rd_days' => 734739,
                                      'rd_nanosecs' => 0,
                                      'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                      'local_c' => {
                                                     'hour' => 12,
                                                     'second' => 0,
                                                     'month' => 8,
                                                     'quarter' => 3,
                                                     'day_of_year' => 237,
                                                     'day_of_quarter' => 55,
                                                     'minute' => 0,
                                                     'day' => 24,
                                                     'day_of_week' => 5,
                                                     'year' => 2012
                                                   },
                                      'utc_rd_secs' => 64800,
                                      'formatter' => undef,
                                      'tz' => bless( {
                                                       'name' => '-0600',
                                                       'offset' => -21600
                                                     }, 'DateTime::TimeZone::OffsetOnly' ),
                                      'utc_year' => 2013,
                                      'utc_rd_days' => 734739,
                                      'offset_modifier' => 0
                                    }, 'DateTime' ),
            'prl' => 'Base'
          },
          {
            'containers' => [
                              {
                                'advice_status' => '-',
                                'operator' => 'David Sherry',
                                'last_scan_time' => bless( {
                                                             'local_rd_secs' => 43200,
                                                             'local_rd_days' => 734733,
                                                             'rd_nanosecs' => 0,
                                                             'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                                             'local_c' => {
                                                                            'hour' => 12,
                                                                            'second' => 0,
                                                                            'month' => 8,
                                                                            'quarter' => 3,
                                                                            'day_of_year' => 231,
                                                                            'day_of_quarter' => 49,
                                                                            'minute' => 0,
                                                                            'day' => 18,
                                                                            'day_of_week' => 6,
                                                                            'year' => 2012
                                                                          },
                                                             'utc_rd_secs' => 64800,
                                                             'formatter' => undef,
                                                             'tz' => bless( {
                                                                              'name' => '-0600',
                                                                              'offset' => -21600
                                                                            }, 'DateTime::TimeZone::OffsetOnly' ),
                                                             'utc_year' => 2013,
                                                             'utc_rd_days' => 734733,
                                                             'offset_modifier' => 0
                                                           }, 'DateTime' ),
                                'id' => 'T123456',
                                'quantity_scanned' => 1
                              }
                            ],
            'status' => 'In Progress',
            'last_advice_send' => '',
            'delivery' => 913927,
            'quantity_expected' => 10,
            'quantity_scanned' => 1,
            'designer' => 'Charvet',
            'delivery_date' => bless( {
                                        'local_rd_secs' => 43200,
                                        'local_rd_days' => 734733,
                                        'rd_nanosecs' => 0,
                                        'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                        'local_c' => {
                                                       'hour' => 12,
                                                       'second' => 0,
                                                       'month' => 8,
                                                       'quarter' => 3,
                                                       'day_of_year' => 231,
                                                       'day_of_quarter' => 49,
                                                       'minute' => 0,
                                                       'day' => 18,
                                                       'day_of_week' => 6,
                                                       'year' => 2012
                                                     },
                                        'utc_rd_secs' => 64800,
                                        'formatter' => undef,
                                        'tz' => bless( {
                                                         'name' => '-0600',
                                                         'offset' => -21600
                                                       }, 'DateTime::TimeZone::OffsetOnly' ),
                                        'utc_year' => 2013,
                                        'utc_rd_days' => 734733,
                                        'offset_modifier' => 0
                                      }, 'DateTime' ),
            'group_id' => 1411972,
            'pid' => 162555,
            'class' => 'white',
            'type' => 'Main',
            'upload_date' => bless( {
                                      'local_rd_secs' => 43200,
                                      'local_rd_days' => 734739,
                                      'rd_nanosecs' => 0,
                                      'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                      'local_c' => {
                                                     'hour' => 12,
                                                     'second' => 0,
                                                     'month' => 8,
                                                     'quarter' => 3,
                                                     'day_of_year' => 237,
                                                     'day_of_quarter' => 55,
                                                     'minute' => 0,
                                                     'day' => 24,
                                                     'day_of_week' => 5,
                                                     'year' => 2012
                                                   },
                                      'utc_rd_secs' => 64800,
                                      'formatter' => undef,
                                      'tz' => bless( {
                                                       'name' => '-0600',
                                                       'offset' => -21600
                                                     }, 'DateTime::TimeZone::OffsetOnly' ),
                                      'utc_year' => 2013,
                                      'utc_rd_days' => 734739,
                                      'offset_modifier' => 0
                                    }, 'DateTime' ),
            'prl' => 'Base'
          },
          {
            'containers' => [
                              {
                                'advice_status' => 'Sent',
                                'operator' => 'David Sherry',
                                'last_scan_time' => bless( {
                                                             'local_rd_secs' => 35880,
                                                             'local_rd_days' => 734731,
                                                             'rd_nanosecs' => 0,
                                                             'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                                             'local_c' => {
                                                                            'hour' => 9,
                                                                            'second' => 0,
                                                                            'month' => 8,
                                                                            'quarter' => 3,
                                                                            'day_of_year' => 229,
                                                                            'day_of_quarter' => 47,
                                                                            'minute' => 58,
                                                                            'day' => 16,
                                                                            'day_of_week' => 4,
                                                                            'year' => 2012
                                                                          },
                                                             'utc_rd_secs' => 57480,
                                                             'formatter' => undef,
                                                             'tz' => bless( {
                                                                              'name' => '-0600',
                                                                              'offset' => -21600
                                                                            }, 'DateTime::TimeZone::OffsetOnly' ),
                                                             'utc_year' => 2013,
                                                             'utc_rd_days' => 734731,
                                                             'offset_modifier' => 0
                                                           }, 'DateTime' ),
                                'id' => 'T123410',
                                'quantity_scanned' => 45
                              },
                              {
                                'advice_status' => '-',
                                'operator' => 'David Sherry',
                                'last_scan_time' => bless( {
                                                             'local_rd_secs' => 36120,
                                                             'local_rd_days' => 734731,
                                                             'rd_nanosecs' => 0,
                                                             'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                                             'local_c' => {
                                                                            'hour' => 10,
                                                                            'second' => 0,
                                                                            'month' => 8,
                                                                            'quarter' => 3,
                                                                            'day_of_year' => 229,
                                                                            'day_of_quarter' => 47,
                                                                            'minute' => 2,
                                                                            'day' => 16,
                                                                            'day_of_week' => 4,
                                                                            'year' => 2012
                                                                          },
                                                             'utc_rd_secs' => 57720,
                                                             'formatter' => undef,
                                                             'tz' => bless( {
                                                                              'name' => '-0600',
                                                                              'offset' => -21600
                                                                            }, 'DateTime::TimeZone::OffsetOnly' ),
                                                             'utc_year' => 2013,
                                                             'utc_rd_days' => 734731,
                                                             'offset_modifier' => 0
                                                           }, 'DateTime' ),
                                'id' => 'T123411',
                                'quantity_scanned' => 1
                              }
                            ],
            'status' => 'Advice Sent',
            'last_advice_send' => bless( {
                                           'local_rd_secs' => 36000,
                                           'local_rd_days' => 734731,
                                           'rd_nanosecs' => 0,
                                           'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                           'local_c' => {
                                                          'hour' => 10,
                                                          'second' => 0,
                                                          'month' => 8,
                                                          'quarter' => 3,
                                                          'day_of_year' => 229,
                                                          'day_of_quarter' => 47,
                                                          'minute' => 0,
                                                          'day' => 16,
                                                          'day_of_week' => 4,
                                                          'year' => 2012
                                                        },
                                           'utc_rd_secs' => 57600,
                                           'formatter' => undef,
                                           'tz' => bless( {
                                                            'name' => '-0600',
                                                            'offset' => -21600
                                                          }, 'DateTime::TimeZone::OffsetOnly' ),
                                           'utc_year' => 2013,
                                           'utc_rd_days' => 734731,
                                           'offset_modifier' => 0
                                         }, 'DateTime' ),
            'delivery' => 341436,
            'quantity_expected' => 50,
            'quantity_scanned' => 45,
            'designer' => 'Kain',
            'delivery_date' => bless( {
                                        'local_rd_secs' => 43200,
                                        'local_rd_days' => 734731,
                                        'rd_nanosecs' => 0,
                                        'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                        'local_c' => {
                                                       'hour' => 12,
                                                       'second' => 0,
                                                       'month' => 8,
                                                       'quarter' => 3,
                                                       'day_of_year' => 229,
                                                       'day_of_quarter' => 47,
                                                       'minute' => 0,
                                                       'day' => 16,
                                                       'day_of_week' => 4,
                                                       'year' => 2012
                                                     },
                                        'utc_rd_secs' => 64800,
                                        'formatter' => undef,
                                        'tz' => bless( {
                                                         'name' => '-0600',
                                                         'offset' => -21600
                                                       }, 'DateTime::TimeZone::OffsetOnly' ),
                                        'utc_year' => 2013,
                                        'utc_rd_days' => 734731,
                                        'offset_modifier' => 0
                                      }, 'DateTime' ),
            'group_id' => 1309033,
            'pid' => 172275,
            'class' => 'cream',
            'type' => 'Main',
            'upload_date' => bless( {
                                      'local_rd_secs' => 43200,
                                      'local_rd_days' => 734741,
                                      'rd_nanosecs' => 0,
                                      'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                      'local_c' => {
                                                     'hour' => 12,
                                                     'second' => 0,
                                                     'month' => 8,
                                                     'quarter' => 3,
                                                     'day_of_year' => 239,
                                                     'day_of_quarter' => 57,
                                                     'minute' => 0,
                                                     'day' => 26,
                                                     'day_of_week' => 7,
                                                     'year' => 2012
                                                   },
                                      'utc_rd_secs' => 64800,
                                      'formatter' => undef,
                                      'tz' => bless( {
                                                       'name' => '-0600',
                                                       'offset' => -21600
                                                     }, 'DateTime::TimeZone::OffsetOnly' ),
                                      'utc_year' => 2013,
                                      'utc_rd_days' => 734741,
                                      'offset_modifier' => 0
                                    }, 'DateTime' ),
            'prl' => 'Base'
          },
          {
            'containers' => [
                              {
                                'advice_status' => 'Putaway',
                                'operator' => 'David Sherry',
                                'last_scan_time' => bless( {
                                                             'local_rd_secs' => 25080,
                                                             'local_rd_days' => 734731,
                                                             'rd_nanosecs' => 0,
                                                             'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                                             'local_c' => {
                                                                            'hour' => 6,
                                                                            'second' => 0,
                                                                            'month' => 8,
                                                                            'quarter' => 3,
                                                                            'day_of_year' => 229,
                                                                            'day_of_quarter' => 47,
                                                                            'minute' => 58,
                                                                            'day' => 16,
                                                                            'day_of_week' => 4,
                                                                            'year' => 2012
                                                                          },
                                                             'utc_rd_secs' => 46680,
                                                             'formatter' => undef,
                                                             'tz' => bless( {
                                                                              'name' => '-0600',
                                                                              'offset' => -21600
                                                                            }, 'DateTime::TimeZone::OffsetOnly' ),
                                                             'utc_year' => 2013,
                                                             'utc_rd_days' => 734731,
                                                             'offset_modifier' => 0
                                                           }, 'DateTime' ),
                                'id' => 'T123410',
                                'quantity_scanned' => 14
                              }
                            ],
            'status' => 'Advice Sent',
            'last_advice_send' => bless( {
                                           'local_rd_secs' => 25200,
                                           'local_rd_days' => 734731,
                                           'rd_nanosecs' => 0,
                                           'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                           'local_c' => {
                                                          'hour' => 7,
                                                          'second' => 0,
                                                          'month' => 8,
                                                          'quarter' => 3,
                                                          'day_of_year' => 229,
                                                          'day_of_quarter' => 47,
                                                          'minute' => 0,
                                                          'day' => 16,
                                                          'day_of_week' => 4,
                                                          'year' => 2012
                                                        },
                                           'utc_rd_secs' => 46800,
                                           'formatter' => undef,
                                           'tz' => bless( {
                                                            'name' => '-0600',
                                                            'offset' => -21600
                                                          }, 'DateTime::TimeZone::OffsetOnly' ),
                                           'utc_year' => 2013,
                                           'utc_rd_days' => 734731,
                                           'offset_modifier' => 0
                                         }, 'DateTime' ),
            'delivery' => 512678,
            'quantity_expected' => 15,
            'quantity_scanned' => 14,
            'designer' => 'Sunspel',
            'delivery_date' => bless( {
                                        'local_rd_secs' => 43200,
                                        'local_rd_days' => 734731,
                                        'rd_nanosecs' => 0,
                                        'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                        'local_c' => {
                                                       'hour' => 12,
                                                       'second' => 0,
                                                       'month' => 8,
                                                       'quarter' => 3,
                                                       'day_of_year' => 229,
                                                       'day_of_quarter' => 47,
                                                       'minute' => 0,
                                                       'day' => 16,
                                                       'day_of_week' => 4,
                                                       'year' => 2012
                                                     },
                                        'utc_rd_secs' => 64800,
                                        'formatter' => undef,
                                        'tz' => bless( {
                                                         'name' => '-0600',
                                                         'offset' => -21600
                                                       }, 'DateTime::TimeZone::OffsetOnly' ),
                                        'utc_year' => 2013,
                                        'utc_rd_days' => 734731,
                                        'offset_modifier' => 0
                                      }, 'DateTime' ),
            'group_id' => 164978,
            'pid' => 246782,
            'class' => 'cream',
            'type' => 'Main',
            'upload_date' => bless( {
                                      'local_rd_secs' => 43200,
                                      'local_rd_days' => 734741,
                                      'rd_nanosecs' => 0,
                                      'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                      'local_c' => {
                                                     'hour' => 12,
                                                     'second' => 0,
                                                     'month' => 8,
                                                     'quarter' => 3,
                                                     'day_of_year' => 239,
                                                     'day_of_quarter' => 57,
                                                     'minute' => 0,
                                                     'day' => 26,
                                                     'day_of_week' => 7,
                                                     'year' => 2012
                                                   },
                                      'utc_rd_secs' => 64800,
                                      'formatter' => undef,
                                      'tz' => bless( {
                                                       'name' => '-0600',
                                                       'offset' => -21600
                                                     }, 'DateTime::TimeZone::OffsetOnly' ),
                                      'utc_year' => 2013,
                                      'utc_rd_days' => 734741,
                                      'offset_modifier' => 0
                                    }, 'DateTime' ),
            'prl' => 'Base'
          },
          {
            'containers' => [
                              {
                                'advice_status' => 'Putaway',
                                'operator' => 'Dawn Fong',
                                'last_scan_time' => bless( {
                                                             'local_rd_secs' => 43200,
                                                             'local_rd_days' => 734731,
                                                             'rd_nanosecs' => 0,
                                                             'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                                             'local_c' => {
                                                                            'hour' => 12,
                                                                            'second' => 0,
                                                                            'month' => 8,
                                                                            'quarter' => 3,
                                                                            'day_of_year' => 229,
                                                                            'day_of_quarter' => 47,
                                                                            'minute' => 0,
                                                                            'day' => 16,
                                                                            'day_of_week' => 4,
                                                                            'year' => 2012
                                                                          },
                                                             'utc_rd_secs' => 64800,
                                                             'formatter' => undef,
                                                             'tz' => bless( {
                                                                              'name' => '-0600',
                                                                              'offset' => -21600
                                                                            }, 'DateTime::TimeZone::OffsetOnly' ),
                                                             'utc_year' => 2013,
                                                             'utc_rd_days' => 734731,
                                                             'offset_modifier' => 0
                                                           }, 'DateTime' ),
                                'id' => 'T129874',
                                'quantity_scanned' => 25
                              },
                              {
                                'advice_status' => '-',
                                'operator' => 'Dawn Fong',
                                'last_scan_time' => bless( {
                                                             'local_rd_secs' => 43800,
                                                             'local_rd_days' => 734731,
                                                             'rd_nanosecs' => 0,
                                                             'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                                             'local_c' => {
                                                                            'hour' => 12,
                                                                            'second' => 0,
                                                                            'month' => 8,
                                                                            'quarter' => 3,
                                                                            'day_of_year' => 229,
                                                                            'day_of_quarter' => 47,
                                                                            'minute' => 10,
                                                                            'day' => 16,
                                                                            'day_of_week' => 4,
                                                                            'year' => 2012
                                                                          },
                                                             'utc_rd_secs' => 65400,
                                                             'formatter' => undef,
                                                             'tz' => bless( {
                                                                              'name' => '-0600',
                                                                              'offset' => -21600
                                                                            }, 'DateTime::TimeZone::OffsetOnly' ),
                                                             'utc_year' => 2013,
                                                             'utc_rd_days' => 734731,
                                                             'offset_modifier' => 0
                                                           }, 'DateTime' ),
                                'id' => 'T129877',
                                'quantity_scanned' => 25
                              }
                            ],
            'status' => 'Advice Sent',
            'last_advice_send' => bless( {
                                           'local_rd_secs' => 43200,
                                           'local_rd_days' => 734731,
                                           'rd_nanosecs' => 0,
                                           'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                           'local_c' => {
                                                          'hour' => 12,
                                                          'second' => 0,
                                                          'month' => 8,
                                                          'quarter' => 3,
                                                          'day_of_year' => 229,
                                                          'day_of_quarter' => 47,
                                                          'minute' => 0,
                                                          'day' => 16,
                                                          'day_of_week' => 4,
                                                          'year' => 2012
                                                        },
                                           'utc_rd_secs' => 64800,
                                           'formatter' => undef,
                                           'tz' => bless( {
                                                            'name' => '-0600',
                                                            'offset' => -21600
                                                          }, 'DateTime::TimeZone::OffsetOnly' ),
                                           'utc_year' => 2013,
                                           'utc_rd_days' => 734731,
                                           'offset_modifier' => 0
                                         }, 'DateTime' ),
            'delivery' => 341436,
            'quantity_expected' => 50,
            'quantity_scanned' => 25,
            'designer' => 'Converse',
            'delivery_date' => bless( {
                                        'local_rd_secs' => 43200,
                                        'local_rd_days' => 734731,
                                        'rd_nanosecs' => 0,
                                        'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                        'local_c' => {
                                                       'hour' => 12,
                                                       'second' => 0,
                                                       'month' => 8,
                                                       'quarter' => 3,
                                                       'day_of_year' => 229,
                                                       'day_of_quarter' => 47,
                                                       'minute' => 0,
                                                       'day' => 16,
                                                       'day_of_week' => 4,
                                                       'year' => 2012
                                                     },
                                        'utc_rd_secs' => 64800,
                                        'formatter' => undef,
                                        'tz' => bless( {
                                                         'name' => '-0600',
                                                         'offset' => -21600
                                                       }, 'DateTime::TimeZone::OffsetOnly' ),
                                        'utc_year' => 2013,
                                        'utc_rd_days' => 734731,
                                        'offset_modifier' => 0
                                      }, 'DateTime' ),
            'group_id' => 1502121,
            'pid' => 124678,
            'class' => 'cream',
            'type' => 'Main',
            'upload_date' => bless( {
                                      'local_rd_secs' => 43200,
                                      'local_rd_days' => 734741,
                                      'rd_nanosecs' => 0,
                                      'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                      'local_c' => {
                                                     'hour' => 12,
                                                     'second' => 0,
                                                     'month' => 8,
                                                     'quarter' => 3,
                                                     'day_of_year' => 239,
                                                     'day_of_quarter' => 57,
                                                     'minute' => 0,
                                                     'day' => 26,
                                                     'day_of_week' => 7,
                                                     'year' => 2012
                                                   },
                                      'utc_rd_secs' => 64800,
                                      'formatter' => undef,
                                      'tz' => bless( {
                                                       'name' => '-0600',
                                                       'offset' => -21600
                                                     }, 'DateTime::TimeZone::OffsetOnly' ),
                                      'utc_year' => 2013,
                                      'utc_rd_days' => 734741,
                                      'offset_modifier' => 0
                                    }, 'DateTime' ),
            'prl' => 'Base'
          },
          {
            'containers' => [
                              {
                                'advice_status' => 'Sent',
                                'operator' => 'David Sherry',
                                'last_scan_time' => bless( {
                                                             'local_rd_secs' => 43200,
                                                             'local_rd_days' => 734731,
                                                             'rd_nanosecs' => 0,
                                                             'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                                             'local_c' => {
                                                                            'hour' => 12,
                                                                            'second' => 0,
                                                                            'month' => 8,
                                                                            'quarter' => 3,
                                                                            'day_of_year' => 229,
                                                                            'day_of_quarter' => 47,
                                                                            'minute' => 0,
                                                                            'day' => 16,
                                                                            'day_of_week' => 4,
                                                                            'year' => 2012
                                                                          },
                                                             'utc_rd_secs' => 64800,
                                                             'formatter' => undef,
                                                             'tz' => bless( {
                                                                              'name' => '-0600',
                                                                              'offset' => -21600
                                                                            }, 'DateTime::TimeZone::OffsetOnly' ),
                                                             'utc_year' => 2013,
                                                             'utc_rd_days' => 734731,
                                                             'offset_modifier' => 0
                                                           }, 'DateTime' ),
                                'id' => 'T123456',
                                'quantity_scanned' => 50
                              }
                            ],
            'status' => 'Awaiting Putaway',
            'last_advice_send' => bless( {
                                           'local_rd_secs' => 43320,
                                           'local_rd_days' => 734731,
                                           'rd_nanosecs' => 0,
                                           'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                           'local_c' => {
                                                          'hour' => 12,
                                                          'second' => 0,
                                                          'month' => 8,
                                                          'quarter' => 3,
                                                          'day_of_year' => 229,
                                                          'day_of_quarter' => 47,
                                                          'minute' => 2,
                                                          'day' => 16,
                                                          'day_of_week' => 4,
                                                          'year' => 2012
                                                        },
                                           'utc_rd_secs' => 64920,
                                           'formatter' => undef,
                                           'tz' => bless( {
                                                            'name' => '-0600',
                                                            'offset' => -21600
                                                          }, 'DateTime::TimeZone::OffsetOnly' ),
                                           'utc_year' => 2013,
                                           'utc_rd_days' => 734731,
                                           'offset_modifier' => 0
                                         }, 'DateTime' ),
            'delivery' => 341436,
            'quantity_expected' => 50,
            'quantity_scanned' => 50,
            'designer' => 'Roland Mouret',
            'delivery_date' => bless( {
                                        'local_rd_secs' => 43200,
                                        'local_rd_days' => 734731,
                                        'rd_nanosecs' => 0,
                                        'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                        'local_c' => {
                                                       'hour' => 12,
                                                       'second' => 0,
                                                       'month' => 8,
                                                       'quarter' => 3,
                                                       'day_of_year' => 229,
                                                       'day_of_quarter' => 47,
                                                       'minute' => 0,
                                                       'day' => 16,
                                                       'day_of_week' => 4,
                                                       'year' => 2012
                                                     },
                                        'utc_rd_secs' => 64800,
                                        'formatter' => undef,
                                        'tz' => bless( {
                                                         'name' => '-0600',
                                                         'offset' => -21600
                                                       }, 'DateTime::TimeZone::OffsetOnly' ),
                                        'utc_year' => 2013,
                                        'utc_rd_days' => 734731,
                                        'offset_modifier' => 0
                                      }, 'DateTime' ),
            'group_id' => 1234587,
            'pid' => 327896,
            'class' => 'green',
            'type' => 'Main',
            'upload_date' => bless( {
                                      'local_rd_secs' => 43200,
                                      'local_rd_days' => 734741,
                                      'rd_nanosecs' => 0,
                                      'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                      'local_c' => {
                                                     'hour' => 12,
                                                     'second' => 0,
                                                     'month' => 8,
                                                     'quarter' => 3,
                                                     'day_of_year' => 239,
                                                     'day_of_quarter' => 57,
                                                     'minute' => 0,
                                                     'day' => 26,
                                                     'day_of_week' => 7,
                                                     'year' => 2012
                                                   },
                                      'utc_rd_secs' => 64800,
                                      'formatter' => undef,
                                      'tz' => bless( {
                                                       'name' => '-0600',
                                                       'offset' => -21600
                                                     }, 'DateTime::TimeZone::OffsetOnly' ),
                                      'utc_year' => 2013,
                                      'utc_rd_days' => 734741,
                                      'offset_modifier' => 0
                                    }, 'DateTime' ),
            'prl' => 'Base'
          },
          {
            'containers' => [
                              {
                                'advice_status' => 'Overheight',
                                'operator' => 'David Sherry',
                                'last_scan_time' => bless( {
                                                             'local_rd_secs' => 43740,
                                                             'local_rd_days' => 734731,
                                                             'rd_nanosecs' => 0,
                                                             'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                                             'local_c' => {
                                                                            'hour' => 12,
                                                                            'second' => 0,
                                                                            'month' => 8,
                                                                            'quarter' => 3,
                                                                            'day_of_year' => 229,
                                                                            'day_of_quarter' => 47,
                                                                            'minute' => 9,
                                                                            'day' => 16,
                                                                            'day_of_week' => 4,
                                                                            'year' => 2012
                                                                          },
                                                             'utc_rd_secs' => 65340,
                                                             'formatter' => undef,
                                                             'tz' => bless( {
                                                                              'name' => '-0600',
                                                                              'offset' => -21600
                                                                            }, 'DateTime::TimeZone::OffsetOnly' ),
                                                             'utc_year' => 2013,
                                                             'utc_rd_days' => 734731,
                                                             'offset_modifier' => 0
                                                           }, 'DateTime' ),
                                'id' => 'T123456',
                                'quantity_scanned' => 10
                              }
                            ],
            'status' => 'Failed Advice',
            'last_advice_send' => bless( {
                                           'local_rd_secs' => 43920,
                                           'local_rd_days' => 734731,
                                           'rd_nanosecs' => 0,
                                           'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                           'local_c' => {
                                                          'hour' => 12,
                                                          'second' => 0,
                                                          'month' => 8,
                                                          'quarter' => 3,
                                                          'day_of_year' => 229,
                                                          'day_of_quarter' => 47,
                                                          'minute' => 12,
                                                          'day' => 16,
                                                          'day_of_week' => 4,
                                                          'year' => 2012
                                                        },
                                           'utc_rd_secs' => 65520,
                                           'formatter' => undef,
                                           'tz' => bless( {
                                                            'name' => '-0600',
                                                            'offset' => -21600
                                                          }, 'DateTime::TimeZone::OffsetOnly' ),
                                           'utc_year' => 2013,
                                           'utc_rd_days' => 734731,
                                           'offset_modifier' => 0
                                         }, 'DateTime' ),
            'delivery' => 451678,
            'quantity_expected' => 10,
            'quantity_scanned' => 10,
            'designer' => 'Paul Smith',
            'delivery_date' => bless( {
                                        'local_rd_secs' => 43200,
                                        'local_rd_days' => 734731,
                                        'rd_nanosecs' => 0,
                                        'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                        'local_c' => {
                                                       'hour' => 12,
                                                       'second' => 0,
                                                       'month' => 8,
                                                       'quarter' => 3,
                                                       'day_of_year' => 229,
                                                       'day_of_quarter' => 47,
                                                       'minute' => 0,
                                                       'day' => 16,
                                                       'day_of_week' => 4,
                                                       'year' => 2012
                                                     },
                                        'utc_rd_secs' => 64800,
                                        'formatter' => undef,
                                        'tz' => bless( {
                                                         'name' => '-0600',
                                                         'offset' => -21600
                                                       }, 'DateTime::TimeZone::OffsetOnly' ),
                                        'utc_year' => 2013,
                                        'utc_rd_days' => 734731,
                                        'offset_modifier' => 0
                                      }, 'DateTime' ),
            'group_id' => 1546746,
            'pid' => 546784,
            'class' => 'red',
            'type' => 'Main',
            'upload_date' => bless( {
                                      'local_rd_secs' => 43200,
                                      'local_rd_days' => 734741,
                                      'rd_nanosecs' => 0,
                                      'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                      'local_c' => {
                                                     'hour' => 12,
                                                     'second' => 0,
                                                     'month' => 8,
                                                     'quarter' => 3,
                                                     'day_of_year' => 239,
                                                     'day_of_quarter' => 57,
                                                     'minute' => 0,
                                                     'day' => 26,
                                                     'day_of_week' => 7,
                                                     'year' => 2012
                                                   },
                                      'utc_rd_secs' => 64800,
                                      'formatter' => undef,
                                      'tz' => bless( {
                                                       'name' => '-0600',
                                                       'offset' => -21600
                                                     }, 'DateTime::TimeZone::OffsetOnly' ),
                                      'utc_year' => 2013,
                                      'utc_rd_days' => 734741,
                                      'offset_modifier' => 0
                                    }, 'DateTime' ),
            'prl' => 'Base'
          },
          {
            'containers' => [
                              {
                                'advice_status' => 'Overheight',
                                'operator' => 'David Sherry',
                                'last_scan_time' => bless( {
                                                             'local_rd_secs' => 46860,
                                                             'local_rd_days' => 734731,
                                                             'rd_nanosecs' => 0,
                                                             'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                                             'local_c' => {
                                                                            'hour' => 13,
                                                                            'second' => 0,
                                                                            'month' => 8,
                                                                            'quarter' => 3,
                                                                            'day_of_year' => 229,
                                                                            'day_of_quarter' => 47,
                                                                            'minute' => 1,
                                                                            'day' => 16,
                                                                            'day_of_week' => 4,
                                                                            'year' => 2012
                                                                          },
                                                             'utc_rd_secs' => 68460,
                                                             'formatter' => undef,
                                                             'tz' => bless( {
                                                                              'name' => '-0600',
                                                                              'offset' => -21600
                                                                            }, 'DateTime::TimeZone::OffsetOnly' ),
                                                             'utc_year' => 2013,
                                                             'utc_rd_days' => 734731,
                                                             'offset_modifier' => 0
                                                           }, 'DateTime' ),
                                'id' => 'T123456',
                                'quantity_scanned' => 35
                              },
                              {
                                'advice_status' => 'Sent',
                                'operator' => 'Peter Sergeant',
                                'last_scan_time' => bless( {
                                                             'local_rd_secs' => 48600,
                                                             'local_rd_days' => 734731,
                                                             'rd_nanosecs' => 0,
                                                             'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                                             'local_c' => {
                                                                            'hour' => 13,
                                                                            'second' => 0,
                                                                            'month' => 8,
                                                                            'quarter' => 3,
                                                                            'day_of_year' => 229,
                                                                            'day_of_quarter' => 47,
                                                                            'minute' => 30,
                                                                            'day' => 16,
                                                                            'day_of_week' => 4,
                                                                            'year' => 2012
                                                                          },
                                                             'utc_rd_secs' => 70200,
                                                             'formatter' => undef,
                                                             'tz' => bless( {
                                                                              'name' => '-0600',
                                                                              'offset' => -21600
                                                                            }, 'DateTime::TimeZone::OffsetOnly' ),
                                                             'utc_year' => 2013,
                                                             'utc_rd_days' => 734731,
                                                             'offset_modifier' => 0
                                                           }, 'DateTime' ),
                                'id' => 'T546871',
                                'quantity_scanned' => 2
                              }
                            ],
            'status' => 'Failed Advice',
            'last_advice_send' => bless( {
                                           'local_rd_secs' => 47100,
                                           'local_rd_days' => 734731,
                                           'rd_nanosecs' => 0,
                                           'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                           'local_c' => {
                                                          'hour' => 13,
                                                          'second' => 0,
                                                          'month' => 8,
                                                          'quarter' => 3,
                                                          'day_of_year' => 229,
                                                          'day_of_quarter' => 47,
                                                          'minute' => 5,
                                                          'day' => 16,
                                                          'day_of_week' => 4,
                                                          'year' => 2012
                                                        },
                                           'utc_rd_secs' => 68700,
                                           'formatter' => undef,
                                           'tz' => bless( {
                                                            'name' => '-0600',
                                                            'offset' => -21600
                                                          }, 'DateTime::TimeZone::OffsetOnly' ),
                                           'utc_year' => 2013,
                                           'utc_rd_days' => 734731,
                                           'offset_modifier' => 0
                                         }, 'DateTime' ),
            'delivery' => 245678,
            'quantity_expected' => 35,
            'quantity_scanned' => 37,
            'designer' => 'Balmain',
            'delivery_date' => bless( {
                                        'local_rd_secs' => 43200,
                                        'local_rd_days' => 734731,
                                        'rd_nanosecs' => 0,
                                        'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                        'local_c' => {
                                                       'hour' => 12,
                                                       'second' => 0,
                                                       'month' => 8,
                                                       'quarter' => 3,
                                                       'day_of_year' => 229,
                                                       'day_of_quarter' => 47,
                                                       'minute' => 0,
                                                       'day' => 16,
                                                       'day_of_week' => 4,
                                                       'year' => 2012
                                                     },
                                        'utc_rd_secs' => 64800,
                                        'formatter' => undef,
                                        'tz' => bless( {
                                                         'name' => '-0600',
                                                         'offset' => -21600
                                                       }, 'DateTime::TimeZone::OffsetOnly' ),
                                        'utc_year' => 2013,
                                        'utc_rd_days' => 734731,
                                        'offset_modifier' => 0
                                      }, 'DateTime' ),
            'group_id' => 124589,
            'pid' => 124578,
            'class' => 'red',
            'type' => 'Main',
            'upload_date' => bless( {
                                      'local_rd_secs' => 43200,
                                      'local_rd_days' => 734741,
                                      'rd_nanosecs' => 0,
                                      'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                      'local_c' => {
                                                     'hour' => 12,
                                                     'second' => 0,
                                                     'month' => 8,
                                                     'quarter' => 3,
                                                     'day_of_year' => 239,
                                                     'day_of_quarter' => 57,
                                                     'minute' => 0,
                                                     'day' => 26,
                                                     'day_of_week' => 7,
                                                     'year' => 2012
                                                   },
                                      'utc_rd_secs' => 64800,
                                      'formatter' => undef,
                                      'tz' => bless( {
                                                       'name' => '-0600',
                                                       'offset' => -21600
                                                     }, 'DateTime::TimeZone::OffsetOnly' ),
                                      'utc_year' => 2013,
                                      'utc_rd_days' => 734741,
                                      'offset_modifier' => 0
                                    }, 'DateTime' ),
            'prl' => 'GOH'
          },
          {
            'containers' => [
                              {
                                'advice_status' => 'Sent',
                                'last_scan_time' => bless( {
                                                             'local_rd_secs' => 58685,
                                                             'local_rd_days' => 734759,
                                                             'rd_nanosecs' => 15286000,
                                                             'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                                             'local_c' => {
                                                                            'hour' => 16,
                                                                            'second' => 5,
                                                                            'month' => 9,
                                                                            'quarter' => 3,
                                                                            'day_of_year' => 257,
                                                                            'day_of_quarter' => 75,
                                                                            'minute' => 18,
                                                                            'day' => 13,
                                                                            'day_of_week' => 4,
                                                                            'year' => 2012
                                                                          },
                                                             'utc_rd_secs' => 55085,
                                                             'formatter' => undef,
                                                             'tz' => bless( {
                                                                              'name' => '+0100',
                                                                              'offset' => 3600
                                                                            }, 'DateTime::TimeZone::OffsetOnly' ),
                                                             'utc_year' => 2013,
                                                             'utc_rd_days' => 734759,
                                                             'offset_modifier' => 0
                                                           }, 'DateTime' ),
                                'destination' => 'Full PRL',
                                'id' => 'M000000001',
                                'quantity_scanned' => '2'
                              },
                              {
                                'advice_status' => 'Sent',
                                'last_scan_time' => bless( {
                                                             'local_rd_secs' => 58685,
                                                             'local_rd_days' => 734759,
                                                             'rd_nanosecs' => 15286000,
                                                             'locale' => $VAR1->[0]{'delivery_date'}{'locale'},
                                                             'local_c' => {
                                                                            'hour' => 16,
                                                                            'second' => 5,
                                                                            'month' => 9,
                                                                            'quarter' => 3,
                                                                            'day_of_year' => 257,
                                                                            'day_of_quarter' => 75,
                                                                            'minute' => 18,
                                                                            'day' => 13,
                                                                            'day_of_week' => 4,
                                                                            'year' => 2012
                                                                          },
                                                             'utc_rd_secs' => 55085,
                                                             'formatter' => undef,
                                                             'tz' => bless( {
                                                                              'name' => '+0100',
                                                                              'offset' => 3600
                                                                            }, 'DateTime::TimeZone::OffsetOnly' ),
                                                             'utc_year' => 2013,
                                                             'utc_rd_days' => 734759,
                                                             'offset_modifier' => 0
                                                           }, 'DateTime' ),
                                'destination' => 'Full PRL',
                                'id' => 'M000000001',
                                'quantity_scanned' => '2'
                              }
                            ],
            'sku' => '2-591',
            'delivery' => 2,
            'status' => 'Part Complete',
            'quantity_expected' => '20',
            'designer' => 'République ✪ Ceccarelli',
            'quantity_scanned' => '2',
            'delivery_date' => undef,
            'pid' => 2,
            'group_id' => 'p1',
            'type' => 'Main',
            'class' => 'white',
            'upload_date' => undef,
            'prl' => 'Full PRL'
          }
        ];

</pre>





        </div>
    </div>

    <p id="footer">    xTracker-DC  (2012.13.xx.prodman.3.2.gff13357 / IWS phase 0 / PRL phase 1 / 2012-09-13 16:12:25). &copy; 2006 - 2012 NET-A-PORTER
</p>


</div>

    </body>
</html>
