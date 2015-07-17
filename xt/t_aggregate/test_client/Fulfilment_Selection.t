#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use FindBin::libs;

=head1 NAME

Fulfilment_Selection.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /Fulfilment/Selection?selection_type=pick

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/Fulfilment/Selection?selection_type=pick',
    expected   => {
        'shipments' => [
        {
            'Items' => '1',
            'SLA Timer' => '',
            'Pick Now' => {
                'input_name' => 'pick-1324665',
                'value' => '',
                'input_value' => '1'
            },
            'Shipment Type' => 'Domestic - Standard -',
            'Channel' => 'NET-A-PORTER.COM',
            'Shipment Number' => {
                'value' => '1324665',
                'url' => '/Fulfilment/Selection/OrderView?order_id=1253607'
            }
        },
        {
            'Items' => '1',
            'SLA Timer' => '-3 days 17:16:37',
            'Pick Now' => {
                'input_name' => 'pick-1324304',
                'value' => '',
                'input_value' => '1'
            },
            'Shipment Type' => 'International - Standard - 13',
            'Channel' => 'theOutnet.com',
            'Shipment Number' => {
                'value' => '1324304',
                'url' => '/Fulfilment/Selection/OrderView?order_id=1253276'
            }
        }]
    }
);

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en">
    <head>
        <meta http-equiv="Content-type" content="text/html; charset=utf-8">

        <title>Selection &#8226; Fulfilment &#8226; XT-DC1</title>


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





        <!-- Custom CSS -->


        <!-- Core CSS
            Placing these here allows us to override YUI styles if we want
            to, but still have extra/custom CSS below to override the default XT
            styles
        -->
        <link rel="stylesheet" type="text/css" media="screen" href="/css/xtracker.css">
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
                Logged in as: <span>DISABLED: IT God</span>
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
                                                <a href="/Admin/UserAdmin" class="yuimenuitemlabel">User Admin</a>
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
                                                <a href="/GoodsIn/Putaway" class="yuimenuitemlabel">Putaway</a>
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
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Stock Control</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="/StockControl/Inventory" class="yuimenuitemlabel">Inventory</a>
                                            </li>


                                            <li class="menuitem">
                                                <a href="/StockControl/Quarantine" class="yuimenuitemlabel">Quarantine</a>
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





                    <li><a href="/Fulfilment/Selection?selection=transfer" class="last">Transfer Shipments</a></li>



        </ul>

</div>




        <div id="contentRight">











                    <div id="pageTitle">
                        <h1>Fulfilment</h1>
                        <h5>&bull;</h5><h2>Selection</h2>
                        <h5>&bull;</h5><h3>Priority List</h3>

                    </div>


                        <p class="display_msg">Shipments successfully selected</p>





            <script type="text/javascript">
                function select_first(){
                    var num = (document.getElementById("select_first").value*1) + 2 ;
                    var form= document.forms['f_select_shipment'];
                    if (form.elements.length<num){
                        num = form.elements.length;
                    }
                    var cName = "select_box";
                    for (i=0,n=form.elements.length;i<n;i++){
                        if (form.elements[i].className.indexOf(cName) !=-1) {
                            form.elements[i].checked = false;
                        }
                    }
                    for (i=0;i<num;i++) {
                        if (form.elements[i].className.indexOf(cName) !=-1) {
                            form.elements[i].checked = true;
                        }
                    }
                }
            </script>
        <div style="text-align:right;height:25px;">
              Select first:
              <select id="select_first" onchange="select_first()">
                  <option value="0">     ----</option>

                  <option value="1">     1   </option>
                  <option value="5">     5   </option>
                  <option value="10">    10  </option>
                  <option value="15">    15  </option>
                  <option value="20">    20  </option>

                  <option value="25">    25  </option>
                  <option value="30">    30  </option>
                  <option value="35">    35  </option>
                  <option value="40">    40  </option>
                  <option value="45">    45  </option>

                  <option value="50">    50  </option>
              </select>
        </div>



        <!-- Results Pager : Start -->
<div style="padding: 5px 0px;">
    <form id="hyperjump_1" action="/Fulfilment/Selection" style="padding: 0px; margin: 0px;" method="post">


    <strong>Page</strong> 1 of 3.


    [


        <em>First</em>



        |


        <em>Previous</em>


        |


        <a href="/Fulfilment/Selection?page=2">Next</a>


        |


        <a href="/Fulfilment/Selection?page=3">Last</a>


    ].


    <!-- Showing 50 of 145 results. -->
    <strong>Showing shipments:</strong> 1 to 50 of 145. (50 results)

    &nbsp;&nbsp;Hyperjump&nbsp;


    <select name="page" onchange="javascript:document.getElementById('hyperjump_1').submit();">


        <option selected="selected">1</option>

        <option >2</option>

        <option >3</option>


    </select>


    </form>

</div>

<!-- Results Pager : End -->


		<form name="f_select_shipment" action="/Fulfilment/Selection/SelectShipments" method="post" onSubmit="return double_submit()">
			<input type="hidden" name="selection_type" value="pick">
        <table width="97%" cellpadding="0" cellspacing="0" border="0" class="data">
            <thead>
            <tr>
                <td colspan="8" class="dividerHeader"></td>
            </tr>

            <tr height="24">
                <td width="10%" class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;Shipment Number</td>
                <td width="5%" class="tableHeader">Items</td>
                <td width="15%" class="tableHeader">Shipment Type</td>
                <td width="15%" class="tableHeader">Channel</td>
                <td width="10%" class="tableHeader">SLA Timer</td>

                        <td align="center" width="5%" class="tableHeader">Pick Now</td>


            </tr>
            <tr>
                <td colspan="8" class="dividerHeader"></td>
            </tr>
            </thead>
            <tbody>













                <tr height="20">
                    <td >&nbsp;&nbsp;&nbsp;&nbsp;<a href="/Fulfilment/Selection/OrderView?order_id=1253607">1324665</a></td>
                    <td >1</td>

                    <td >Domestic - Standard<span style="display:none;"> - </span></td>
                    <td >NET-A-PORTER.COM</td>

                        <td  style='color:green'></td>


                        <td ><input class="select_box" name="pick-1324665" value="1" type="checkbox" /></td>

                </tr>
                <tr>
                    <td colspan="8" class="divider"></td>

                </tr>


                <tr height="20">
                    <td >&nbsp;&nbsp;&nbsp;&nbsp;<a href="/Fulfilment/Selection/OrderView?order_id=1253276">1324304</a></td>
                    <td >1</td>

                    <td >International - Standard<span style="display:none;"> - 13</span></td>
                    <td >theOutnet.com</td>

                        <td  style='color:red'>-3 days 17:16:37</td>


                        <td ><input class="select_box" name="pick-1324304" value="1" type="checkbox" /></td>

                </tr>
                <tr>

                    <td colspan="8" class="divider"></td>
                </tr>


            <tr>
                <td class="blank"><img src="/images/blank.gif" width="1" height="40"></td>
                <td colspan="8" class="blank" align="right" valign="bottom"><input type="submit" name="submit" class="button" value="Submit &raquo;">
</td>
            </tr>
        </table>
        <!-- Results Pager : Start -->

<div style="padding: 5px 0px;">
    <form id="hyperjump_2" action="/Fulfilment/Selection" style="padding: 0px; margin: 0px;" method="post">


    <strong>Page</strong> 1 of 3.


    [


        <em>First</em>


        |


        <em>Previous</em>


        |


        <a href="/Fulfilment/Selection?page=2">Next</a>



        |


        <a href="/Fulfilment/Selection?page=3">Last</a>


    ].


    <!-- Showing 50 of 145 results. -->
    <strong>Showing shipments:</strong> 1 to 50 of 145. (50 results)

    &nbsp;&nbsp;Hyperjump&nbsp;

    <select name="page" onchange="javascript:document.getElementById('hyperjump_2').submit();">


        <option selected="selected">1</option>


        <option >2</option>

        <option >3</option>


    </select>


</div>

<!-- Results Pager : End -->

		</form>


<br /><br /><br />






        </div>
    </div>

    <p id="footer">    xTracker-DC (2.20.04.21.g2af8a2d.dirty). &copy; 2006 - 2010 NET-A-PORTER
</p>

</div>

    </body>
</html>
