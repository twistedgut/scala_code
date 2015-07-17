#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

StockControl_Inventory_StockQuarantine.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for Spec:

    StockControl/Inventory/StockQuarantine

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    spec       => 'StockControl/Inventory/StockQuarantine',
    expected   => {
    'nap_table' => {
        'NET-A-PORTER.COM' => {
            'Stock Overview - Main Stock' => [
                {
                    'Total'         => '0',
                    'Allocated'     => '0',
                    'Free'          => '0',
                    'Loc Qty'       => '0',
                    'Size'          => 'xx small',
                    'Designer Size' => 'xx small',
                    'Location'      => 'None',
                    'SKU'           => {
                        'value' => '99640-010',
                        'url'   => 'Overview?variant_id=559670'
                    }
                },
                {
                    'Total'         => '0',
                    'Allocated'     => '0',
                    'Free'          => '0',
                    'Loc Qty'       => '0',
                    'Size'          => 'x small',
                    'Designer Size' => 'x small',
                    'Location'      => 'None',
                    'SKU'           => {
                        'value' => '99640-011',
                        'url'   => 'Overview?variant_id=559671'
                    }
                },
                {
                    'Total'         => '19',
                    'Allocated'     => '0',
                    'Free'          => '19',
                    'Loc Qty'       => '19',
                    'Size'          => 'small',
                    'Designer Size' => 'small',
                    'Location'      => '012H218C',
                    'SKU'           => {
                        'value' => '99640-012',
                        'url'   => 'Overview?variant_id=559672'
                    }
                },
                {
                    'Total'         => '22',
                    'Allocated'     => '0',
                    'Free'          => '22',
                    'Loc Qty'       => '22',
                    'Size'          => 'medium',
                    'Designer Size' => 'medium',
                    'Location'      => '012H218C',
                    'SKU'           => {
                        'value' => '99640-013',
                        'url'   => 'Overview?variant_id=559673'
                    }
                },
                {
                    'Total'         => '6',
                    'Allocated'     => '0',
                    'Free'          => '6',
                    'Loc Qty'       => '6',
                    'Size'          => 'large',
                    'Designer Size' => 'large',
                    'Location'      => '012H218C',
                    'SKU'           => {
                        'value' => '99640-014',
                        'url'   => 'Overview?variant_id=559674'
                    }
                },
                {
                    'Total'         => '0',
                    'Allocated'     => '0',
                    'Free'          => '0',
                    'Loc Qty'       => '0',
                    'Size'          => 'x large',
                    'Designer Size' => 'x large',
                    'Location'      => 'None',
                    'SKU'           => {
                        'value' => '99640-015',
                        'url'   => 'Overview?variant_id=559675'
                    }
                },
                {
                    'Total'         => '0',
                    'Allocated'     => '0',
                    'Free'          => '0',
                    'Loc Qty'       => '0',
                    'Size'          => 'xx large',
                    'Designer Size' => 'xx large',
                    'Location'      => 'None',
                    'SKU'           => {
                        'value' => '99640-016',
                        'url'   => 'Overview?variant_id=559676'
                    }
                }
            ],
            'Stock Overview - Other Locations' => [
                {
                    'Loc Qty'       => '1',
                    'Size'          => 'small',
                    'Designer Size' => 'small',
                    'Location'      => 'Editorial(Creative)',
                    'SKU'           => {
                        'value' => '99640-012',
                        'url'   => 'Overview?variant_id=559672'
                    }
                }
            ]
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

        <title>Inventory &#8226; Stock Control &#8226; XT-DC1</title>


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


            <script type="text/javascript" src="/yui/yahoo-dom-event/yahoo-dom-event.js"></script>

            <script type="text/javascript" src="/yui/element/element-min.js"></script>

            <script type="text/javascript" src="/yui/tabview/tabview-min.js"></script>



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




        <!-- Custom CSS -->


            <link rel="stylesheet" type="text/css" href="/yui/tabview/assets/skins/sam/tabview.css">


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
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Fulfilment</a>

                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/Picking" class="yuimenuitemlabel">Picking</a>
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
                                                <a href="/StockControl/Inventory" class="yuimenuitemlabel">Inventory</a>
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





                    <li><a href="/StockControl/Inventory/SearchForm" class="last">New Search</a></li>




                        <li><span>Product</span></li>



                    <li><a href="/StockControl/Inventory/Overview?product_id=99640">Product Overview</a></li>

                    <li><a href="/StockControl/Inventory/ProductDetails?product_id=99640">Product Details</a></li>

                    <li><a href="/StockControl/Inventory/Pricing?product_id=99640">Pricing</a></li>


                    <li><a href="/StockControl/Inventory/Sizing?product_id=99640">Sizing</a></li>

                    <li><a href="/StockControl/PurchaseOrder/Search?product_id=99640&search=1" class="last">Purchase Orders</a></li>







                        <li><span>Stock Actions</span></li>



                    <li><a href="/StockControl/Inventory/MoveAddStock?product_id=99640">Move/Add Stock</a></li>

                    <li><a href="/StockControl/Inventory/StockQuarantine?product_id=99640">Quarantine Stock</a></li>

                    <li><a href="/StockControl/StockAdjustment/AdjustStock?product_id=99640" class="last">Adjust Stock</a></li>





                        <li><span>Product Logs</span></li>



                    <li><a href="/StockControl/Inventory/Log/Product/DeliveryLog?product_id=99640">Deliveries</a></li>

                    <li><a href="/StockControl/Inventory/Log/Product/AllocatedLog?product_id=99640" class="last">Allocated</a></li>


        </ul>

</div>




        <div id="contentRight">












                    <div id="pageTitle">
                        <h1>Stock Control</h1>
                        <h5>&bull;</h5><h2>Inventory</h2>
                        <h5>&bull;</h5><h3>Product Overview</h3>
                    </div>





                    <!-- TT BEGIN - stocktracker/inventory/overview.tt -->









<div id='display_product'>
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
        <tr>
            <td width="120" class="divider"></td>
            <td width="10" class="divider"></td>
            <td width="84" class="divider"></td>
            <td width="25" class="divider"></td>
            <td width="40%" class="divider"></td>
            <td width="25" class="divider"></td>

            <td width="40%" class="divider"></td>
        </tr>
        <tr height="24">
            <td colspan="7" class="tableheader">
                &nbsp;&nbsp;&nbsp;<a href="/StockControl/Inventory/Overview?product_id=99640">99640</a>&nbsp;&nbsp;:&nbsp;&nbsp;Bodas - Sheer Tactel underskirt
            </td>
        </tr>
        <tr>

            <td colspan="7" class="divider"></td>
        </tr>
    </thead>
    <tbody>
        <tr height="10">
            <td class="blank" colspan="7">&nbsp;</td>
        </tr>
        <tr height="100" valign="top">
            <td class="blank">

                <a href="javascript://" onClick="enlargeImage('http://cache.net-a-porter.com/images/products/99640/99640_in_dl.jpg')"><img class="product" height="180" width="120" src="http://cache.net-a-porter.com/images/products/99640/99640_in_m.jpg"></a>
            </td>
            <td class="blank"><img src="/images/blank.gif" width="10" height="1"></td>
            <td class="blank">
                <a href="javascript://" onClick="enlargeImage('http://cache.net-a-porter.com/images/products/99640/99640_bk_dl.jpg')"><img class="product" height="84" width="56" src="http://cache.net-a-porter.com/images/products/99640/99640_bk_xs.jpg"></a>
                <br clear="all">
                <a href="javascript://" onClick="enlargeImage('http://cache.net-a-porter.com/images/products/99640/99640_cu_dl.jpg')"><img class="product" height="84" width="56" src="http://cache.net-a-porter.com/images/products/99640/99640_cu_xs.jpg" style="margin-top:10px"></a>
            </td>
            <td class="blank"><img src="/images/blank.gif" width="25" height="1"></td>

            <td class="blank" colspan="3">

                <table cellpadding="0" cellspacing="0" width="100%" style="margin-bottom:17px">
                    <tr>
                        <td width="47%" class="blank">
                            <table cellpadding="2" cellspacing="0" class="data" width="100%">
                                <tr>
                                    <td colspan="3" class="divider"></td>
                                </tr>

                                <tr>
                                    <td width="35%" align="right"><b>Style Number:</b>&nbsp;</td>
                                    <td width="65%">HEL016</td>
                                    <td></td>
                                </tr>
                                <tr>
                                    <td colspan="3" class="divider"></td>
                                </tr>

                                <tr>
                                    <td align="right"><b>Season:</b>&nbsp;</td>
                                    <td colspan="2">Continuity</td>
                                </tr>
                                <tr>
                                    <td colspan="3" class="divider"></td>
                                </tr>
                                <tr>

                                    <td align="right"><b>Colour:</b>&nbsp;</td>
                                    <td colspan="2">

                                            Black

                                        &nbsp;

                                            (Black)



                                    </td>
                                </tr>
                                <tr>
                                    <td colspan="3" class="divider"></td>

                                </tr>
                            </table>
                        </td>
                        <td width="6%" class="blank"></td>
                        <td width="47%" class="blank">
                            <table cellpadding="2" cellspacing="0" class="data" width="100%">
                                <tr>
                                    <td colspan="3" class="divider"></td>
                                </tr>

                                <tr>
                                    <td align="right" nowrap><b>Size Scheme:</b>&nbsp;</td>
                                    <td colspan="2">RTW XXS - XXL</td>
                                </tr>
                                <tr>
                                    <td colspan="3" class="divider"></td>
                                </tr>
                                <tr>

                                    <td align="right"><b>Classification:</b>&nbsp;</td>
                                    <td colspan="2">Clothing / Lingerie / Chemises</td>
                                </tr>
                                <tr>
                                    <td colspan="3" class="divider"></td>
                                </tr>
                                <tr>
                                    <td width="35%" align="right"><b>Purchase Order:</b>&nbsp;</td>

                                    <td width="65%" colspan="2">


                                            <a href="/StockControl/PurchaseOrder/Overview?po_id=13096">BSDLNGCONT1020K</a> &nbsp; &nbsp; <br />



                                    </td>
                                </tr>
                                <tr>
                                    <td colspan="3" class="divider"></td>
                                </tr>

                            </table>
                        </td>
                    </tr>
                </table>
                <br />

                <table cellpadding="2" cellspacing="0" class="data" width="100%">
                    <tr>
                        <td colspan="5" class="divider"></td>

                    </tr>
                    <tr>
                        <td class="tableHeader">&nbsp;&nbsp;Sales Channel</td>
                        <td class="tableHeader">Status</td>
                        <td class="tableHeader">Arrival Date</td>
                        <td class="tableHeader">Upload Date</td>
                        <td class="tableHeader" width="16">&nbsp;</td>

                    </tr>
                    <tr>
                        <td colspan="5" class="divider"></td>
                    </tr>

                        <tr>
                            <td>&nbsp;&nbsp;<span class="title title-NAP" style="line-height: 1em;">NET-A-PORTER.COM</span></td>
                            <td>

                                    <a href='http://www.net-a-porter.com/product/99640' target='livewindow'>Live</a> : Visible



                            </td>

                            <td>03-07-2010</td>
                            <td>12-07-2010</td>
                            <td><img src="/images/icons/bullet_green.png" alt="Active"></td>
                        </tr>
                        <tr>
                            <td colspan="5" class="divider"></td>
                        </tr>


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
    <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="22381646">

    <input type="hidden" name="product_id" value="99640" />
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
                <td width="20%"><input type="text" name="dep" value="Stock Control" size="20" readonly="readonly" /></td>
                <td width="20%"><input type="text" name="dat" value="29-07-2010 13:56" size="17" readonly="readonly" /></td>
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

</div>

<div id="tabContainer" class="yui-navset">
	    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="tabChannelTable">
        <tr>
            <td align="right"><span class="tab-label">Sales Channel:&nbsp;</span></td>
            <td width="5%" align="right" nowrap>
                <ul class="yui-nav">						<li class="selected"><a href="#tab1" class="contentTab-NAP" style="text-decoration: none;"><em>NET-A-PORTER.COM</em></a></li>                </ul>

            </td>
        </tr>
    </table>

    <div class="yui-content">



            <div id="tab1" class="tabWrapper-NAP">
			<div class="tabInsideWrapper">

                <span class="title title-NAP">Stock Overview - Main Stock</span><br />


                  <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                        <thead>
                            <tr>
                                <td colspan="10" class="dividerHeader"></td>
                            </tr>
                            <tr height="24">
                                <td width="15%" class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;
SKU</td>

                                <td width="12%" class="tableHeader">Size</td>
                                <td width="16%" class="tableHeader">Designer Size</td>
                                <td width="14%" class="tableHeader">Location</td>
                                <td width="8%" class="tableHeader">

                                        &nbsp;

                                        </td>
                                        <td width="10%" class="tableHeader">


                                        Loc Qty

                                </td>

                                <td width="8%" class="tableHeader">Total</td>
                                <td width="10%" class="tableHeader">Allocated</td>
                                <td width="7%" class="tableHeader">Free</td>
                            </tr>
                        </thead>
                        <tbody>









































                            <tr>
                                <td colspan="10" class="divider"></td>
                            </tr>
                            <tr height="20">
                                <td>&nbsp;&nbsp;&nbsp;&nbsp;
<a href="Overview?variant_id=559670">99640-010</a></td>
                                <td>xx small</td>
                                <td>xx small</td>

                                <td>
                                None

                                </td>

                                <td>

                                    &nbsp;

                                </td>
                                <td>

                                    0

                                </td>

                                <td>0</td>

                                <td>0 </td>
                                <td>0</td>
                            </tr>
                            <tr>
                                <td colspan="3" class="none"></td>
                                <td colspan="7" class="none">
                                    <div id="expand_NAP_010_stock_dc1" style="display:none; margin-top:5px; margin-bottom:5px">
                                        <table width="100%" cellpadding="1" cellspacing="0" border="0" class="data">

                                            <thead>
                                                <tr>
                                                    <td colspan="2" class="dividerHeader"></td>
                                                </tr>
                                                <tr height="24">
                                                    <td class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;
Location</td>
                                                    <td class="tableHeader">Quantity</td>
                                                </tr>

                                                <tr>
                                                    <td colspan="2" class="dividerHeader"></td>
                                                </tr>
                                            </thead>
                                            <tbody>

                                            </tbody>
                                        </table>
                                    </div>
                                </td>

                            </tr>



























                            <tr>
                                <td colspan="10" class="divider"></td>
                            </tr>
                            <tr height="20">
                                <td>&nbsp;&nbsp;&nbsp;&nbsp;
<a href="Overview?variant_id=559671">99640-011</a></td>
                                <td>x small</td>

                                <td>x small</td>
                                <td>
                                None

                                </td>

                                <td>

                                    &nbsp;

                                </td>
                                <td>

                                    0

                                </td>


                                <td>0</td>
                                <td>0 </td>
                                <td>0</td>
                            </tr>
                            <tr>
                                <td colspan="3" class="none"></td>
                                <td colspan="7" class="none">

                                    <div id="expand_NAP_011_stock_dc1" style="display:none; margin-top:5px; margin-bottom:5px">
                                        <table width="100%" cellpadding="1" cellspacing="0" border="0" class="data">
                                            <thead>
                                                <tr>
                                                    <td colspan="2" class="dividerHeader"></td>
                                                </tr>
                                                <tr height="24">
                                                    <td class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;
Location</td>

                                                    <td class="tableHeader">Quantity</td>
                                                </tr>
                                                <tr>
                                                    <td colspan="2" class="dividerHeader"></td>
                                                </tr>
                                            </thead>
                                            <tbody>

                                            </tbody>

                                        </table>
                                    </div>
                                </td>
                            </tr>










































                            <tr>
                                <td colspan="10" class="divider"></td>
                            </tr>
                            <tr height="20">
                                <td>&nbsp;&nbsp;&nbsp;&nbsp;

<a href="Overview?variant_id=559672">99640-012</a></td>
                                <td>small</td>
                                <td>small</td>
                                <td>
                                012H218C

                                </td>

                                <td>

                                    &nbsp;


                                </td>
                                <td>

                                    19

                                </td>

                                <td>19</td>
                                <td>0 </td>
                                <td>19</td>
                            </tr>

                            <tr>
                                <td colspan="3" class="none"></td>
                                <td colspan="7" class="none">
                                    <div id="expand_NAP_012_stock_dc1" style="display:none; margin-top:5px; margin-bottom:5px">
                                        <table width="100%" cellpadding="1" cellspacing="0" border="0" class="data">
                                            <thead>
                                                <tr>
                                                    <td colspan="2" class="dividerHeader"></td>
                                                </tr>

                                                <tr height="24">
                                                    <td class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;
Location</td>
                                                    <td class="tableHeader">Quantity</td>
                                                </tr>
                                                <tr>
                                                    <td colspan="2" class="dividerHeader"></td>
                                                </tr>
                                            </thead>

                                            <tbody>






                                                <tr>
                                                    <td width="30%">&nbsp;&nbsp;&nbsp;&nbsp;
012H218C</td>
                                                    <td width="70%">19</td>
                                                </tr>
                                                <tr>
                                                    <td colspan="2" class="divider"></td>

                                                </tr>

                                            </tbody>
                                        </table>
                                    </div>
                                </td>
                            </tr>
































































                            <tr>
                                <td colspan="10" class="divider"></td>
                            </tr>

                            <tr height="20">
                                <td>&nbsp;&nbsp;&nbsp;&nbsp;
<a href="Overview?variant_id=559673">99640-013</a></td>
                                <td>medium</td>
                                <td>medium</td>
                                <td>
                                012H218C

                                </td>


                                <td>

                                    &nbsp;

                                </td>
                                <td>

                                    22

                                </td>

                                <td>22</td>
                                <td>0 </td>

                                <td>22</td>
                            </tr>
                            <tr>
                                <td colspan="3" class="none"></td>
                                <td colspan="7" class="none">
                                    <div id="expand_NAP_013_stock_dc1" style="display:none; margin-top:5px; margin-bottom:5px">
                                        <table width="100%" cellpadding="1" cellspacing="0" border="0" class="data">
                                            <thead>

                                                <tr>
                                                    <td colspan="2" class="dividerHeader"></td>
                                                </tr>
                                                <tr height="24">
                                                    <td class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;
Location</td>
                                                    <td class="tableHeader">Quantity</td>
                                                </tr>
                                                <tr>

                                                    <td colspan="2" class="dividerHeader"></td>
                                                </tr>
                                            </thead>
                                            <tbody>






                                                <tr>
                                                    <td width="30%">&nbsp;&nbsp;&nbsp;&nbsp;
012H218C</td>
                                                    <td width="70%">22</td>

                                                </tr>
                                                <tr>
                                                    <td colspan="2" class="divider"></td>
                                                </tr>

                                            </tbody>
                                        </table>
                                    </div>
                                </td>
                            </tr>

































































                            <tr>
                                <td colspan="10" class="divider"></td>
                            </tr>
                            <tr height="20">
                                <td>&nbsp;&nbsp;&nbsp;&nbsp;
<a href="Overview?variant_id=559674">99640-014</a></td>
                                <td>large</td>
                                <td>large</td>

                                <td>
                                012H218C

                                </td>

                                <td>

                                    &nbsp;

                                </td>
                                <td>

                                    6

                                </td>

                                <td>6</td>

                                <td>0 </td>
                                <td>6</td>
                            </tr>
                            <tr>
                                <td colspan="3" class="none"></td>
                                <td colspan="7" class="none">
                                    <div id="expand_NAP_014_stock_dc1" style="display:none; margin-top:5px; margin-bottom:5px">
                                        <table width="100%" cellpadding="1" cellspacing="0" border="0" class="data">

                                            <thead>
                                                <tr>
                                                    <td colspan="2" class="dividerHeader"></td>
                                                </tr>
                                                <tr height="24">
                                                    <td class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;
Location</td>
                                                    <td class="tableHeader">Quantity</td>
                                                </tr>

                                                <tr>
                                                    <td colspan="2" class="dividerHeader"></td>
                                                </tr>
                                            </thead>
                                            <tbody>






                                                <tr>
                                                    <td width="30%">&nbsp;&nbsp;&nbsp;&nbsp;
012H218C</td>
                                                    <td width="70%">6</td>

                                                </tr>
                                                <tr>
                                                    <td colspan="2" class="divider"></td>
                                                </tr>

                                            </tbody>
                                        </table>
                                    </div>
                                </td>
                            </tr>




























                            <tr>
                                <td colspan="10" class="divider"></td>
                            </tr>
                            <tr height="20">
                                <td>&nbsp;&nbsp;&nbsp;&nbsp;
<a href="Overview?variant_id=559675">99640-015</a></td>
                                <td>x large</td>
                                <td>x large</td>

                                <td>
                                None

                                </td>

                                <td>

                                    &nbsp;

                                </td>
                                <td>

                                    0

                                </td>

                                <td>0</td>

                                <td>0 </td>
                                <td>0</td>
                            </tr>
                            <tr>
                                <td colspan="3" class="none"></td>
                                <td colspan="7" class="none">
                                    <div id="expand_NAP_015_stock_dc1" style="display:none; margin-top:5px; margin-bottom:5px">
                                        <table width="100%" cellpadding="1" cellspacing="0" border="0" class="data">

                                            <thead>
                                                <tr>
                                                    <td colspan="2" class="dividerHeader"></td>
                                                </tr>
                                                <tr height="24">
                                                    <td class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;
Location</td>
                                                    <td class="tableHeader">Quantity</td>
                                                </tr>

                                                <tr>
                                                    <td colspan="2" class="dividerHeader"></td>
                                                </tr>
                                            </thead>
                                            <tbody>

                                            </tbody>
                                        </table>
                                    </div>
                                </td>

                            </tr>



























                            <tr>
                                <td colspan="10" class="divider"></td>
                            </tr>
                            <tr height="20">
                                <td>&nbsp;&nbsp;&nbsp;&nbsp;
<a href="Overview?variant_id=559676">99640-016</a></td>
                                <td>xx large</td>

                                <td>xx large</td>
                                <td>
                                None

                                </td>

                                <td>

                                    &nbsp;

                                </td>
                                <td>

                                    0

                                </td>


                                <td>0</td>
                                <td>0 </td>
                                <td>0</td>
                            </tr>
                            <tr>
                                <td colspan="3" class="none"></td>
                                <td colspan="7" class="none">

                                    <div id="expand_NAP_016_stock_dc1" style="display:none; margin-top:5px; margin-bottom:5px">
                                        <table width="100%" cellpadding="1" cellspacing="0" border="0" class="data">
                                            <thead>
                                                <tr>
                                                    <td colspan="2" class="dividerHeader"></td>
                                                </tr>
                                                <tr height="24">
                                                    <td class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;
Location</td>

                                                    <td class="tableHeader">Quantity</td>
                                                </tr>
                                                <tr>
                                                    <td colspan="2" class="dividerHeader"></td>
                                                </tr>
                                            </thead>
                                            <tbody>

                                            </tbody>

                                        </table>
                                    </div>
                                </td>
                            </tr>

                            <tr>
                                <td colspan="10" class="divider"></td>
                            </tr>
                            <tr class='blank'>
                                <td class="blank"><img src="/images/blank.gif" width="1" height="25"></td>

                                <td class="blank"></td>
                                <td class="blank"></td>
                                <td class="blank"></td>
                                <td class="blank"><strong>

                                    &nbsp;

									</strong>
                                </td>
                                <td class="blank"><strong>

                                    47

									</strong>

                                </td>

                                <td class="blank"><strong>47</strong></td>
                                <td class="blank"><strong>0</strong></td>
                                <td class="blank"><strong>47</strong></td>
                            </tr>
                            <tr>
                                <td colspan="10" class="divider"></td>

                            </tr>
                    </table>





                <br />




                    <span class="title title-NAP">Stock Overview - Other Locations</span><br />

                      <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                        <thead>
                            <tr>
                            <td colspan="9" class="dividerHeader"></td>
                            </tr>
                            <tr height="24">
                            <td width="15%" class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;
SKU</td>
                            <td width="12%" class="tableHeader">Size</td>

                            <td width="16%" class="tableHeader">Designer Size</td>
                            <td width="14%" class="tableHeader">Location</td>
                            <td width="8%"  class="tableHeader"></td>
                            <td width="10%" class="tableHeader">Loc Qty</td>
                            <td width="9%"  class="tableHeader">&nbsp;</td>
                            <td width="9%"  class="tableHeader">&nbsp;</td>
                            <td width="7%"  class="tableHeader">&nbsp;</td>

                            </tr>
                        </thead>
                        <tbody>














































                                <tr>
                                    <td colspan="9" class="divider"></td>
                                </tr>
                                <tr height="20">
                                    <td>&nbsp;&nbsp;&nbsp;&nbsp;
<a href="Overview?variant_id=559672">99640-012</a></td>

                                    <td>small</td>
                                    <td>small</td>
                                    <td>
                                    Editorial<br />(Creative)

                                    </td>
                                    <td></td>
                                    <td>1</td>

                                    <td>&nbsp;</td>
                                    <td>&nbsp;</td>
                                    <td>&nbsp;</td>
                                </tr>
                                <tr>
                                    <td colspan="3" class="none"></td>
                                    <td colspan="6" class="none">
                                        <div id="expand_NAP_012_stock_other" style="display:none; margin-top:5px; margin-bottom:5px">
                                            <table width="100%" cellpadding="1" cellspacing="0" border="0" class="data">

                                                <thead>
                                                    <tr>
                                                        <td colspan="5" class="dividerHeader"></td>
                                                    </tr>
                                                    <tr height="24">
                                                        <td class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;
Location</td>
                                                        <td class="tableHeader">Qty.</td>
                                                        <td class="tableHeader">&nbsp;</td>

                                                        <td class="tableHeader">&nbsp;</td>
                                                        <td class="tableHeader">&nbsp;</td>
                                                    </tr>
                                                    <tr>
                                                        <td colspan="5" class="dividerHeader"></td>
                                                    </tr>
                                                </thead>
                                                <tbody>


















                                                    <tr>

                                                        <td style="width: 35%;">&nbsp;&nbsp;&nbsp;&nbsp;
Editorial&nbsp;(Creative)</td>
                                                        <td style="width: 5%; text-align: center;">1</td>
                                                        <td style="width: 8%; text-align: center;">

                                                        </td>
                                                        <td style="width: 8%; text-align: center;">


                                                        </td>
							<td style="width: 20%; text-align: right;">

<!--

-->
                                                        </td>
                                                        <td style="text-align: center; vertical-align: middle; background-color: white;">&nbsp;</td>
                                                    </tr>
                                                    <tr>
                                                        <td colspan="5" class="dividerHeader"></td>
                                                    </tr>

                                                </tbody>
                                            </table>

                                        </div>
                                    </td>
                                </tr>

                                <tr>
                                <td colspan="9" class="divider"></td>
                                </tr>
                                <tr class='blank'>
                                <td class="blank"><img src="/images/blank.gif" width="1" height="25"></td>
                                <td class="blank"></td>

                                <td class="blank"></td>
                                <td class="blank"></td>
                                <td class="blank"></td>
                                <td class="blank"><b>1</b></td>
                                <td class="blank"></td>
                                <td class="blank"></td>
                                <td class="blank"></td>
                                </tr>

                                <tr>
                                <td colspan="9" class="divider"></td>
                                </tr>
                            </table>

                        <br />












			</div>
            </div>

    </div>

</div>

<script type="text/javascript" language="javascript">
    (function() {
        var tabView = new YAHOO.widget.TabView('tabContainer');
    })();
</script>


<script language="Javascript">

function confirmDelete(form){

    var use_response = confirm("Are you sure you want to delete this item from sample stock?")

    if(use_response){
	return double_submit();
    }
    else {
	return false;
    }
}



</script>

<!-- TT END - stocktracker/inventory/overview.tt -->




        </div>
    </div>

    <p id="footer">    xTracker-DC (xt.2.18.02.356.g9b23ca9.dirty). &copy; 2006 - 2010 NET-A-PORTER
</p>


</div>

    </body>
</html>
