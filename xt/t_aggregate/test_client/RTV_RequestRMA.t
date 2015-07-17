#!/usr/bin/env perl

use NAP::policy "tt", 'test';
no utf8;
use FindBin::libs;

=head1 NAME

RTV_RequestRMA.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /RTV/RequestRMA

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/RTV/RequestRMA',
    expected   => {
        'items' => [
            {
                'Variant ID' => '574384',
                'PID' => '211139',
                'Quarantine Note' => 'Test QNote: 816348414',
                'Quantity ID' => '42549',
                'Delivery Date' => '05-Aug-2010 12:38',
                'Designer' => {
                    'ID' => '514',
                    'Name' => 'Kova & T'
                },
                'Date' => '05-Aug-2010 12:38',
                'Fault Name' => 'Unknown',
                'Style Ref' => 'KWL-2000',
                'Size' => '010',
                'Fault ID' => '0',
                'Origin' => 'GI',
                'Quantity' => '1',
                'SKU' => '211139-010'
            },
            {
                'Variant ID' => '574385',
                'PID' => '211139',
                'Quarantine Note' => 'Test QNote: 482381159',
                'Quantity ID' => '42550',
                'Delivery Date' => '05-Aug-2010 12:43',
                'Designer' => {
                    'ID' => '514',
                    'Name' => 'Kova & T'
                },
                'Date' => '05-Aug-2010 12:43',
                'Fault Name' => 'Unknown',
                'Style Ref' => 'KWL-2000',
                'Size' => '011',
                'Fault ID' => '0',
                'Origin' => 'GI',
                'Quantity' => '8',
                'SKU' => '211139-011'
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

        <title>Request RMA &#8226; RTV &#8226; XT-DC1</title>


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


            </ul>
        </div>

</div>

</div>


    <div id="content">
        <div id="contentLeftCol">


</div>



            <img id="channelTitle" src="/images/logo_theOutnet_INTL.gif" alt="theOutnet.com">


        <div id="contentRight">











                    <div id="pageTitle">
                        <h1>RTV</h1>
                        <h5>&bull;</h5><h2>Request RMA</h2>
                        <h5>&bull;</h5><h3>Search</h3>
                    </div>





                    <!-- TT BEGIN - stocktracker/rtv/rtv_stock.tt -->


<a name="top"></a>


    <script type="text/javascript" language="javascript">


    function expand( div ){

        var div_id = 'expand_' + div;
        var obj = document.getElementById( div_id );
        var display = obj.style.display;

		var toggle_id = div + '_toggle';
		var toggle_obj;
		if (typeof(document.getElementById( toggle_id ))) {
			toggle_obj	= document.getElementById( toggle_id );
		}

        if( display == 'block' ){
            obj.style.display = 'none';
			if (toggle_obj) {
				if (toggle_obj.tagName == "IMG") {
					toggle_obj.src	= "/images/plus.gif";
					toggle_obj.title= "Show";
					toggle_obj.alt	= "[+]";
				}
				else {
					toggle_obj.innerHTML	= expand.arguments[1];
				}
			}
        }
        if( display == 'none' ){
            obj.style.display = 'block';
			if (toggle_obj) {
				if (toggle_obj.tagName == "IMG") {
					toggle_obj.src	= "/images/minus.gif";
					toggle_obj.title= "Hide";
					toggle_obj.alt	= "[-]";
				}
				else {
					toggle_obj.innerHTML	= expand.arguments[2];
				}
			}
        }

        return false;
    }

</script>


    <!-- TT BEGIN - page_elements/javascript/columnsort.tt -->

<script type="text/javascript">
<!--

function selectSort(cookie_name, order_by) {

    cookie_name = 'xt_' + cookie_name + '_columnsort';

    var cookie_val = readCookie(cookie_name);

    if (!cookie_val) {
        createCookie(cookie_name, order_by + ':asc', 0);
    }

    var cookie_vals = cookie_val.split(':');

    if (cookie_vals[0] == order_by) {
        if (cookie_vals[1] == 'asc') {
            createCookie(cookie_name, order_by + ':desc', 0);
        }
        else if (cookie_vals[1] == 'desc') {
            createCookie(cookie_name, order_by + ':asc', 0);
        }
        else {
            createCookie(cookie_name, order_by + ':asc', 0);
        }
    }
    else {
        createCookie(cookie_name, order_by + ':asc', 0);
    }

}


function createCookie(name, value, days) {
	if (days) {
		var date = new Date();
		date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
		var expires = "; expires=" + date.toGMTString();
	}
	else var expires = "";
	document.cookie = name + "=" + value + expires + "; path=/";
}


function readCookie(name) {
	var nameEQ = name + "=";
	var ca = document.cookie.split(';');
	for(var i = 0; i < ca.length; i++) {
		var c = ca[i];
		while (c.charAt(0) == ' ') c = c.substring(1, c.length);
		if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length, c.length);
	}
	return null;
}


function eraseCookie(name) {
	createCookie(name, "", -1);
}

//  End -->
</script>

<!-- TT END - page_elements/javascript/columnsort.tt -->


    <!-- Selection Criteria -->

    <span class="title">Search Criteria</span><br />
    <form name="frm_rtv_stock_select" action="RequestRMA" method="post">
    <table width="100%" class="data" cellpadding="0" cellspacing="0" border="0">
        <tr>
            <td colspan="2" class="divider"></td>
        </tr>
        <tr>
            <td width="20%" align="right"><strong>Sales Channel:</strong>&nbsp;</td>
            <td width="80%">
                <select name="select_channel">

                        <option value="1__NET-A-PORTER.COM" >NET-A-PORTER.COM</option>

                        <option value="3__theOutnet.com" selected>theOutnet.com</option>

                </select>
            </td>
        </tr>
        <tr>
            <td colspan="2" class="divider"></td>
        </tr>
        <tr>
            <td width="20%" align="right"><strong>Designer:</strong>&nbsp;</td>
            <td width="80%">
































































































































































































































































































































































































































































































































<input type="hidden" id="edit_select_designer_id" name="edit_select_designer_id" value="off">
<select style="border: 1px solid grey;" id="select_designer_id" name="select_designer_id" onchange="editField(this);">



    <option value="" selected="selected" >-------------------</option>



    <option value="291" >3.1 Phillip Lim</option>



    <option value="498" >7 for all mankind</option>



    <option value="532" >Adam</option>



    <option value="438" >Adidas by Stella McCartney</option>



    <option value="609" >Alaïa</option>



    <option value="69" >Alberta Ferretti</option>



    <option value="538" >Albertus Swanepoel</option>



    <option value="250" >Alexander McQueen</option>



    <option value="340" >Alexander Wang</option>



    <option value="637" >ALICE by Temperley</option>



    <option value="134" >Alice + Olivia</option>



    <option value="400" >Allegra Hicks</option>



    <option value="670" >American Retro</option>



    <option value="692" >American Vintage</option>



    <option value="44" >Anna Sui</option>



    <option value="146" >Antik Batik</option>



    <option value="27" >Anya Hindmarch</option>



    <option value="473" >A.P.C.</option>



    <option value="654" >Armand Basi</option>



    <option value="660" >Aurélie Bidermann</option>



    <option value="211" >Azzaro</option>



    <option value="592" >Balenciaga</option>



    <option value="472" >Balmain</option>



    <option value="666" >Bantu</option>



    <option value="629" >Barbie by Christian Louboutin</option>



    <option value="603" >Bassike</option>



    <option value="893" >Beatrix Ong</option>



    <option value="442" >Belle by Sigerson Morrison</option>



    <option value="584" >Belstaff</option>



    <option value="636" >Bess</option>



    <option value="493" >Bijoux Heart</option>



    <option value="662" >Bindya</option>



    <option value="575" >Bird by Juicy Couture</option>



    <option value="542" >Bird Handbags</option>



    <option value="534" >Bloch</option>



    <option value="625" >Bodas</option>



    <option value="45" >Bottega Veneta</option>



    <option value="367" >Brian Atwood</option>



    <option value="271" >Burberry</option>



    <option value="220" >Burberry Prorsum</option>



    <option value="312" >By Malene Birger</option>



    <option value="161" >Calvin Klein</option>



    <option value="390" >Camilla and Marc</option>



    <option value="576" >Camilla Skovgaard</option>



    <option value="646" >Carven</option>



    <option value="251" >Catherine Malandrino</option>



    <option value="426" >Celestina</option>



    <option value="469" >Charlotte Olympia</option>



    <option value="122" >Chloé</option>



    <option value="72" >Christian Louboutin</option>



    <option value="510" >Christopher Kane</option>



    <option value="307" >Citizens of Humanity</option>



    <option value="885" >Coming Soon</option>



    <option value="499" >Crumpet</option>



    <option value="504" >Current/Elliott</option>



    <option value="558" >Dannijo</option>



    <option value="181" >DAY Birger et Mikkelsen</option>



    <option value="572" >Deepa Gurnani</option>



    <option value="325" >D &amp; G</option>



    <option value="42" >Diane von Furstenberg</option>



    <option value="444" >DKNY</option>



    <option value="449" >Dolce &amp; Gabbana</option>



    <option value="531" >Doma</option>



    <option value="433" >Donna Karan</option>



    <option value="647" >DRKSHDW by Rick Owens</option>



    <option value="407" >Earnest Sewn</option>



    <option value="474" >Elizabeth and James</option>



    <option value="482" >Elle Macpherson Intimates</option>



    <option value="652" >Emamó</option>



    <option value="471" >Emanuel Ungaro</option>



    <option value="888" >Emilio de la Morena</option>



    <option value="119" >Emilio Pucci</option>



    <option value="470" >Erdem</option>



    <option value="37" >Erickson Beamon</option>



    <option value="879" >Etoile Isabel Marant</option>



    <option value="541" >Eugenia Kim</option>



    <option value="623" >Falconiere</option>



    <option value="309" >Fendi</option>



    <option value="615" >Giambattista Valli</option>



    <option value="535" >Giles &amp; Brother</option>



    <option value="9" >Gina</option>



    <option value="406" >Giuseppe Zanotti</option>



    <option value="170" >Givenchy</option>



    <option value="323" >Goldsign</option>



    <option value="578" >Gucci</option>



    <option value="437" >Halston</option>



    <option value="627" >Halston Heritage</option>



    <option value="565" >Haute Hippie</option>



    <option value="376" >Helmut Lang</option>



    <option value="369" >Hervé Léger</option>



    <option value="551" >HTC</option>



    <option value="358" >Hunter</option>



    <option value="674" >IRO</option>



    <option value="869" >Irwin &amp; Jordan</option>



    <option value="661" >Isabel Marant</option>



    <option value="410" >Isharya</option>



    <option value="293" >Issa</option>



    <option value="756" >James Jeans</option>



    <option value="392" >James Perse</option>



    <option value="320" >J Brand</option>



    <option value="870" >J.Crew</option>



    <option value="650" >Jennifer Behr</option>



    <option value="608" >Jennifer Ouellette</option>



    <option value="523" >Jil Sander</option>



    <option value="4" >Jimmy Choo</option>



    <option value="658" >John Galliano</option>



    <option value="556" >John Hardy</option>



    <option value="35" >Jonathan Aston</option>



    <option value="381" >Jonathan Saunders</option>



    <option value="665" >Joseph</option>



    <option value="241" >Judith Leiber</option>



    <option value="114" >Juicy Couture</option>



    <option value="588" >Julien Macdonald</option>



    <option value="344" >Just Cavalli</option>



    <option value="480" >Kara by Kara Ross</option>



    <option value="52" >Karl Donoghue</option>



    <option value="221" >Kenneth Jay Lane</option>



    <option value="282" >K Jacques St Tropez</option>



    <option value="395" >K Karl Lagerfeld</option>



    <option value="514" >Kova &amp; T</option>



    <option value="595" >La Cerise Sur Le Chapeau</option>



    <option value="621" >L'Agence</option>



    <option value="502" >Lanvin</option>



    <option value="490" >La Perla</option>



    <option value="201" >La Petite S*****</option>



    <option value="227" >Lee Angel</option>



    <option value="630" >LemLem</option>



    <option value="540" >Loeffler Randall</option>



    <option value="632" >Lotta Stensson</option>



    <option value="567" >Louis Mariette</option>



    <option value="606" >Lutz &amp; Patmos</option>



    <option value="427" >Maison Martin Margiela</option>



    <option value="487" >Maje</option>



    <option value="166" >Maloles</option>



    <option value="346" >Manoush</option>



    <option value="88" >Marc by Marc Jacobs</option>



    <option value="370" >Marchesa</option>



    <option value="115" >Marc Jacobs</option>



    <option value="521" >Markus Lupfer</option>



    <option value="128" >Marni</option>



    <option value="29" >Matthew Williamson</option>



    <option value="364" >Mawi</option>



    <option value="635" >Max Azria</option>



    <option value="313" >McQ</option>



    <option value="175" >Melissa Odabash</option>



    <option value="140" >Michael Kors</option>



    <option value="443" >MiH Jeans</option>



    <option value="415" >Mike &amp; Chris</option>



    <option value="160" >Milly</option>



    <option value="914" >Mini for Many</option>



    <option value="913" >Minimarket</option>



    <option value="78" >Missoni</option>



    <option value="171" >Miu Miu</option>



    <option value="784" >M Missoni</option>



    <option value="425" >Monica Vinader</option>



    <option value="172" >Moschino</option>



    <option value="151" >Moschino Cheap and Chic</option>



    <option value="174" >Mou</option>



    <option value="891" >Muks</option>



    <option value="223" >Mulberry</option>



    <option value="236" >Musa</option>



    <option value="96" >Narciso Rodriguez</option>



    <option value="315" >Notify</option>



    <option value="360" >Notte by Marchesa</option>



    <option value="421" >Oliver Peoples</option>



    <option value="348" >Olivia Morris</option>



    <option value="530" >One Vintage</option>



    <option value="349" >Oscar de la Renta</option>



    <option value="557" >OTRERA</option>



    <option value="659" >Paloma Barceló</option>



    <option value="889" >Pamela Love</option>



    <option value="19" >Paul &amp; Joe</option>



    <option value="284" >Paul &amp; Joe Sister</option>



    <option value="383" >Pauric Sweeney</option>



    <option value="252" >Pedro Garcia</option>



    <option value="677" >Peter Pilotto</option>



    <option value="436" >Philippe Audibert</option>



    <option value="681" >Philip Treacy</option>



    <option value="141" >Philosophy di Alberta Ferretti</option>



    <option value="901" >Poltock &amp; Walsh</option>



    <option value="489" >Preen</option>



    <option value="500" >Preen Line</option>



    <option value="373" >Pringle 1815</option>



    <option value="260" >Proenza Schouler</option>



    <option value="484" >Rachel Gilbert</option>



    <option value="451" >Ray-Ban</option>



    <option value="336" >Rebecca Taylor</option>



    <option value="589" >Red Valentino</option>



    <option value="497" >Richard Nicoll</option>



    <option value="142" >Rick Owens</option>



    <option value="268" >Rick Owens Lilies</option>



    <option value="401" >RM by Roland Mouret</option>



    <option value="80" >Roberto Cavalli</option>



    <option value="414" >Roksanda Ilincic</option>



    <option value="110" >Rosa Chá</option>



    <option value="641" >Salvatore Ferragamo</option>



    <option value="882" >Sandro</option>



    <option value="638" >Sara Berman</option>



    <option value="131" >Sass &amp; Bide</option>



    <option value="593" >SCOSHA</option>



    <option value="153" >See by Chloé</option>



    <option value="452" >Shay Todd</option>



    <option value="476" >Sigerson Morrison</option>



    <option value="911" >Simeon Farrar</option>



    <option value="378" >Single</option>



    <option value="352" >Sonia by Sonia Rykiel</option>



    <option value="562" >Spanx</option>



    <option value="362" >Splendid</option>



    <option value="290" >Stella McCartney</option>



    <option value="257" >Tara Matthews</option>



    <option value="121" >T-Bags</option>



    <option value="590" >T by Alexander Wang</option>



    <option value="118" >Temperley London</option>



    <option value="191" >Thakoon</option>



    <option value="537" >Theory</option>



    <option value="873" >The Row</option>



    <option value="353" >Thomas Wylde</option>



    <option value="422" >Thurley</option>



    <option value="289" >Tibi</option>



    <option value="337" >Tom Binns</option>



    <option value="269" >Tory Burch</option>



    <option value="238" >True Religion</option>



    <option value="610" >Tucker</option>



    <option value="653" >Undrest</option>



    <option value="285" >Valentino</option>



    <option value="32" >Vanessa Bruno</option>



    <option value="286" >Vanessa Bruno Athé</option>



    <option value="607" >Vanessa Kandiyoti</option>



    <option value="649" >Versace</option>



    <option value="651" >Victoria Beckham Denim</option>



    <option value="143" >Viktor &amp; Rolf</option>



    <option value="402" >Vince</option>



    <option value="645" >Vionnet</option>



    <option value="505" >Vivienne Westwood</option>



    <option value="306" >Vivienne Westwood Anglomania</option>



    <option value="501" >Vivienne Westwood Gold Label</option>



    <option value="350" >Vivienne Westwood Red Label</option>



    <option value="622" >Vix</option>



    <option value="883" >VPL</option>



    <option value="851" >William Rast</option>



    <option value="580" >Willow</option>



    <option value="657" >Wolford</option>



    <option value="563" >Y-3</option>



    <option value="529" >Yummie Tummie</option>



    <option value="508" >Yves Saint Laurent</option>



    <option value="232" >Zac Posen</option>



    <option value="387" >Zimmermann</option>



    <option value="663" >Zoe Tees</option>

</select>

            </td>
        </tr>
        <tr>
            <td colspan="2" class="divider"></td>
        </tr>
        <tr>
            <td align="right"><strong>PID:</strong>&nbsp;</td>
            <td><input type="text" name="select_product_id" maxlength="10" /></td>
        </tr>
        <tr>
            <td colspan="2" class="divider"></td>
        </tr>
        <tr>
            <td colspan="2" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
        </tr>
        <tr>
            <td colspan="2" class="blank" align="right"><input type="submit" name="submit" class="button" value="Search &raquo;">
</td>
        </tr>
    </table>
	</form>
    <br /><br />







        <span class="title title-OUTNET">Search Results</span><br />


            <form name="frm_rtv_stock" id="frm_rtv_stock" action="/RTV/RequestRMA/SetRequest?select_channel=3__theOutnet.com&select_product_id=211139" method="post">
				<input type="hidden" name="channel_id" value="3">
            <table width="100%" class="data" cellpadding="0" cellspacing="0" border="0">
                <thead>
                    <tr>
                        <td colspan="11" class="dividerHeader"></td>
                    </tr>
                    <tr>
                        <td class="tableHeader" style="width: 15%;">Designer<br />&nbsp;</td>
                        <td class="tableHeader" style="width: 10%;">Origin<br />&nbsp;</td>
                        <td class="tableHeader" style="width: 5%;">SKU<br /><span style="font-weight: normal;">(PID </span></td>
                        <td class="tableHeader" style="width: 1%; font-weight: normal;"><br />-</td>
                        <td class="tableHeader" style="width: 5%; font-weight: normal;"><br />Size&nbsp;ID)</td>
                        <td class="tableHeader" style="width: 15%;">Type&nbsp;/<br />Colour</td>
                        <td class="tableHeader" style="width: 10%;">Style Ref.<br />&nbsp;</td>
                        <td class="tableHeader" style="width: 12%;">Date<br />&nbsp;</td>
                        <td class="tableHeader" style="width: 12%;">Delivery<br />Date</td>
                        <td class="tableHeader" style="width: 5%; text-align: right;">Qty.&nbsp;&nbsp;<br />&nbsp;</td>
                        <td class="tableHeader" style="width: 20%;">Fault Type&nbsp;/<br />Description</td>
                    </tr>
                    <tr>
                        <td colspan="11" class="dividerHeader"></td>
                    </tr>
                </thead>
                <tbody>

























                    <tr style="margin-top:20px">
                        <td style="vertical-align: top; border-top: 0;"><a name="42549"></a><a href="RequestRMA?select_designer_id=514&select_channel=3__theOutnet.com" style="text-decoration: none;">Kova &amp; T</a></td>
                        <td style="vertical-align: top;  border-top: 0;">GI</a></td>
                        <td style="vertical-align: top; border-top: 0;"><a href="../StockControl/Inventory/Overview?product_id=211139">211139</a></td>
                        <td style="vertical-align: top; border-top: 0;">-</td>
                        <td style="vertical-align: top; text-align: left; border-top: 0;"><a href="../StockControl/Inventory/Overview?variant_id=574384">010</a>&nbsp;&nbsp;&nbsp;</td>
                        <td style="vertical-align: top; border-top: 0;">Jackets&nbsp;/<br />Anthracite<br /><br />SS10</td>
                        <td style="vertical-align: top; border-top: 0;">KWL-2000</td>
                        <td style="vertical-align: top; border-top: 0;">05-Aug-2010 12:38</td>
                        <td style="vertical-align: top; border-top: 0;">05-Aug-2010 12:38</td>
                        <td style="vertical-align: top; text-align: right; border-top: 0;">
                            <span style="font-size: 120%; font-weight: bold;">1</span>&nbsp;&nbsp;&nbsp;&nbsp;<br />

                                &nbsp;

                            <br /><br />

                        </td>
                        <td style="vertical-align: top; border-top: 0;">
                            <table class="data" style="width: 100%;" cellpadding="2" cellspacing="0" border="0">
                                <tr>
                                    <td>




















































<input type="hidden" id="edit_ddl_item_fault_type_42549" name="edit_ddl_item_fault_type_42549" value="off">
<select style="border: 1px solid grey;" id="ddl_item_fault_type_42549" name="ddl_item_fault_type_42549" onchange="editField(this); editFaultFields(42549);">



    <option value="14" >Broken</option>



    <option value="16" >Chipped</option>



    <option value="13" >Discoloration</option>



    <option value="3" >Marked</option>



    <option value="7" >Missing Part</option>



    <option value="2" >None</option>



    <option value="8" >Pull in Fabric</option>



    <option value="9" >Sale or Return</option>



    <option value="12" >Scratched</option>



    <option value="5" >Scuffed</option>



    <option value="17" >Slow Seller</option>



    <option value="4" >Stained</option>



    <option value="15" >Stitching coming off</option>



    <option value="10" >Stock Swap</option>



    <option value="11" >Surplus</option>



    <option value="6" >Torn/Ripped</option>



    <option value="0" selected="selected" >Unknown</option>



    <option value="1" >Various</option>

</select>

                                    </td>

                                </tr>
                                <tr>
                                    <td>
                                        <input type="hidden" id="edit_fault_description_42549" name="edit_fault_description_42549" value="off" />
                                        <textarea rows="2" name="fault_description_42549" style="width: 100%; border: 1px solid grey; text-align: justify" onchange="editFaultFields(42549);">Test QNote: 816348414</textarea>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="border: 0; text-align: right;">

                                        <input type="submit" name="submit_update_fault_type" class="button" value="Update &raquo;" />

                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>

                        <tr>
                            <td colspan="11" align="right">
                                <table class="data" width="50%">
                                    <tr>
                                    <td colspan="11" class="dividerHeader"></td>
                                </tr>
                                    <tr>
                                        <td align="right"><strong>Request:</strong>&nbsp;</td>
                                        <td>
                                            <input type="checkbox" name="include_id_42549" value="1" />
                                        </td>
                                        <td align="right"><strong>Reason:</strong>&nbsp;</td>
                                        <td>






























<input type="hidden" id="edit_request_detail_type_42549" name="edit_request_detail_type_42549" value="off">
<select style="border: 1px solid grey;" id="request_detail_type_42549" name="request_detail_type_42549" onchange="editField(this);">



    <option value="1" >Credit</option>



    <option value="2" >Customer Repair</option>



    <option value="3" >Replacement</option>



    <option value="4" >Sale or Return</option>



    <option value="5" >Stock Swap</option>

</select>

                                        </td>
                                    </tr>
                                </table>
                            <td>
                        </tr>

                    <tr>
                        <td colspan="11" class="divider"></td>
                    </tr>
















                    <tr style="margin-top:20px">
                        <td style="vertical-align: top; border-top: 0;"><a name="42550"></a><a href="RequestRMA?select_designer_id=514&select_channel=3__theOutnet.com" style="text-decoration: none;">Kova &amp; T</a></td>
                        <td style="vertical-align: top;  border-top: 0;">GI</a></td>
                        <td style="vertical-align: top; border-top: 0;"><a href="../StockControl/Inventory/Overview?product_id=211139">211139</a></td>
                        <td style="vertical-align: top; border-top: 0;">-</td>
                        <td style="vertical-align: top; text-align: left; border-top: 0;"><a href="../StockControl/Inventory/Overview?variant_id=574385">011</a>&nbsp;&nbsp;&nbsp;</td>
                        <td style="vertical-align: top; border-top: 0;">Jackets&nbsp;/<br />Anthracite<br /><br />SS10</td>
                        <td style="vertical-align: top; border-top: 0;">KWL-2000</td>
                        <td style="vertical-align: top; border-top: 0;">05-Aug-2010 12:43</td>
                        <td style="vertical-align: top; border-top: 0;">05-Aug-2010 12:43</td>
                        <td style="vertical-align: top; text-align: right; border-top: 0;">
                            <span style="font-size: 120%; font-weight: bold;">8</span>&nbsp;&nbsp;&nbsp;&nbsp;<br />

                            [ <a href="javascript:#" onClick="return expand('split_line_42550')">Split</a> ]
                            <div id="expand_split_line_42550" style="display: none">
                                <table class="data" style="width: 99%; border: 0px solid lightgrey;" cellpadding="2" cellspacing="0" border="0">
                                    <tr style="height: 2px;"><td style="height: 2px;"></td></tr>
                                    <tr>
                                        <td style="border: 0; text-align: right;">
                                            <input type="hidden" id="edit_split_qty_42550" name="edit_split_qty_42550" value="off" />
                                            <input type="text" style="width:25px" id="split_qty_42550" name="split_qty_42550" maxlength="2" onchange="editField(this);" /><br />
                                            <input type="submit" name="submit_split_line" value="Submit &raquo;" class="button" />
                                        </td>
                                    </tr>
                                </table>
                            </div>

                            <br /><br />

                        </td>
                        <td style="vertical-align: top; border-top: 0;">
                            <table class="data" style="width: 100%;" cellpadding="2" cellspacing="0" border="0">
                                <tr>
                                    <td>




















































<input type="hidden" id="edit_ddl_item_fault_type_42550" name="edit_ddl_item_fault_type_42550" value="off">
<select style="border: 1px solid grey;" id="ddl_item_fault_type_42550" name="ddl_item_fault_type_42550" onchange="editField(this); editFaultFields(42550);">



    <option value="14" >Broken</option>



    <option value="16" >Chipped</option>



    <option value="13" >Discoloration</option>



    <option value="3" >Marked</option>



    <option value="7" >Missing Part</option>



    <option value="2" >None</option>



    <option value="8" >Pull in Fabric</option>



    <option value="9" >Sale or Return</option>



    <option value="12" >Scratched</option>



    <option value="5" >Scuffed</option>



    <option value="17" >Slow Seller</option>



    <option value="4" >Stained</option>



    <option value="15" >Stitching coming off</option>



    <option value="10" >Stock Swap</option>



    <option value="11" >Surplus</option>



    <option value="6" >Torn/Ripped</option>



    <option value="0" selected="selected" >Unknown</option>



    <option value="1" >Various</option>

</select>

                                    </td>

                                </tr>
                                <tr>
                                    <td>
                                        <input type="hidden" id="edit_fault_description_42550" name="edit_fault_description_42550" value="off" />
                                        <textarea rows="2" name="fault_description_42550" style="width: 100%; border: 1px solid grey; text-align: justify" onchange="editFaultFields(42550);">Test QNote: 482381159</textarea>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="border: 0; text-align: right;">

                                        <input type="submit" name="submit_update_fault_type" class="button" value="Update &raquo;" />

                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>

                        <tr>
                            <td colspan="11" align="right">
                                <table class="data" width="50%">
                                    <tr>
                                    <td colspan="11" class="dividerHeader"></td>
                                </tr>
                                    <tr>
                                        <td align="right"><strong>Request:</strong>&nbsp;</td>
                                        <td>
                                            <input type="checkbox" name="include_id_42550" value="1" />
                                        </td>
                                        <td align="right"><strong>Reason:</strong>&nbsp;</td>
                                        <td>






























<input type="hidden" id="edit_request_detail_type_42550" name="edit_request_detail_type_42550" value="off">
<select style="border: 1px solid grey;" id="request_detail_type_42550" name="request_detail_type_42550" onchange="editField(this);">



    <option value="1" >Credit</option>



    <option value="2" >Customer Repair</option>



    <option value="3" >Replacement</option>



    <option value="4" >Sale or Return</option>



    <option value="5" >Stock Swap</option>

</select>

                                        </td>
                                    </tr>
                                </table>
                            <td>
                        </tr>

                    <tr>
                        <td colspan="11" class="divider"></td>
                    </tr>




                </tbody>
                <tfoot>
                    <tr>
                        <td class="blank" style="height: 3; font-size: 10%;">&nbsp;</td>
                        <td class="blank" align="right" colspan="10">

                            <table cellpadding="5" cellspacing="0" border="0">
                                <tr valign="top">
                                    <td class="blank"><strong>RMA&nbsp;Request&nbsp;Comments:</strong></td>
                                    <td class="blank"><textarea rows="3" cols="45" name="rma_request_comments"></textarea>
                                </tr>
                                <tr>
                                    <td class="blank" colspan="2" align="right">
                                        <input type="submit" name="submit_rma_request" class="button" style="cursor: pointer" value="Create RMA Request &raquo;" />
                                    </td>
                                </tr>
                            </table>

                        </td>
                    </tr>
                </tfoot>
                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="22632386">

            </table>
            </form>

            <script type="text/javascript">
            <!--

                document.forms[0].select_product_id.focus();





                function editFaultFields(id) {

                    var fname_fault_type_id     = 'edit_ddl_item_fault_type_' + id;
                    var fname_fault_description = 'edit_fault_description_' + id;

                    document.getElementById(fname_fault_type_id).value      = 'on';
                    document.getElementById(fname_fault_description).value  = 'on';

                }


                function includeRow (checkbox) {

                    var id      = checkbox.value;
                    var checked = checkbox.checked;

                    var include_id      = document.getElementById('edit_include_id_' + id);
                    include_id.disabled = !checked;
                    include_id.value    = checked ? 'on' : 'off';
                    var list            = document.getElementById('request_detail_type_' + id);
                    var list_edit       = document.getElementById('edit_request_detail_type_' + id);

                    list.disabled       = !checked;
                    list_edit.disabled  = !checked;

                    list_edit.value     = checked ? 'on' : 'off';

                }


                // Enable "include" checkboxes
                var frm_rtv_stock = document.getElementById('frm_rtv_stock');

                for (var i = 0; i < frm_rtv_stock.length; i++) {
                    if (frm_rtv_stock[i].name == "include") {
                        frm_rtv_stock[i].disabled = false;
                    }
                }

            //-->
            </script>













<!-- TT END - stocktracker/rtv/rtv_stock.tt -->




        </div>
    </div>

    <p id="footer">    xTracker-DC (xt.2.18.02.356.g9b23ca9.dirty). &copy; 2006 - 2010 NET-A-PORTER
</p>


</div>

    </body>
</html>
