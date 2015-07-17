#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

StockControl_Inventory_MoveAddStock.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /StockControl/Inventory/MoveAddStock

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/StockControl/Inventory/MoveAddStock?variant_id=12345',
    expected   => {
        'stock_by_location' => {
            'NET-A-PORTER.COM' => {
                'Stock by Location' => [ {
                    'Delete' => {
                        'input_name' => 'delete_151237_40498',
                        'value' => '',
                        'input_value' => undef
                    },
                    'New Quantity' => {
                        'input_name' => 'nquantity_151237_40498',
                        'value' => '*',
                        'input_value' => '0'
                    },
                    'New Location' => {
                        'input_name' => 'nlocation_151237_40498',
                        'value' => '*',
                        'input_value' => undef
                    },
                    'Designer Size' => '34DD',
                    'Location' => {
                        'input_name' => 'olocation_151237_40498',
                        'value' => '019Z996Z',
                        'input_value' => '019Z996Z'
                    },
                    'Quantity' => {
                        'input_name' => 'oquantity_151237_40498',
                        'value' => '187',
                        'input_value' => '187'
                    },
                    'SKU' => {
                        'input_name' => 'channel_151237_40498',
                        'value' => '32389-263',
                        'url' => 'MoveAddStock?variant_id=151237',
                        'input_value' => '1'
                    }
                }
           ] }
        }
    }
);

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en"><head>


        <meta http-equiv="Content-type" content="text/html;
charset=UTF-8">

        <title>Inventory • Stock Control • XT-DC1</title>


        <link rel="shortcut icon"
href="http://xtdc1-frank:8529/favicon.ico">



        <!-- Core Javascript -->
        <script type="text/javascript" src="MoveAddStock_files/common.js"></script>
        <script type="text/javascript" src="MoveAddStock_files/xt_navigation.js"></script>
        <script type="text/javascript" src="MoveAddStock_files/form_validator.js"></script>
        <script type="text/javascript" src="MoveAddStock_files/validate.js"></script>
        <script type="text/javascript" src="MoveAddStock_files/comboselect.js"></script>
        <script type="text/javascript" src="MoveAddStock_files/date.js"></script>

        <!-- Custom Javascript -->





        <!-- YUI majik -->
        <script type="text/javascript" src="MoveAddStock_files/yahoo-dom-event.js"></script>
        <script type="text/javascript" src="MoveAddStock_files/container_core-min.js"></script>
        <script type="text/javascript" src="MoveAddStock_files/menu-min.js"></script>
        <script type="text/javascript" src="MoveAddStock_files/animation.js"></script>
        <!-- dialog dependencies -->
        <script type="text/javascript" src="MoveAddStock_files/element-min.js"></script>
        <!-- Scripts -->
        <script type="text/javascript" src="MoveAddStock_files/utilities.js"></script>
        <script type="text/javascript" src="MoveAddStock_files/container-min.js"></script>
        <script type="text/javascript" src="MoveAddStock_files/yahoo-min.js"></script>
        <script type="text/javascript" src="MoveAddStock_files/dom-min.js"></script>
        <script type="text/javascript" src="MoveAddStock_files/element-min.js"></script>

        <script type="text/javascript" src="MoveAddStock_files/datasource-min.js"></script>
        <script type="text/javascript" src="MoveAddStock_files/datatable-min.js"></script>
        <script type="text/javascript" src="MoveAddStock_files/tabview-min.js"></script>
        <script type="text/javascript" src="MoveAddStock_files/slider-min.js"></script>
        <!-- Connection Dependencies -->
        <script type="text/javascript" src="MoveAddStock_files/event-min.js"></script>
        <script type="text/javascript" src="MoveAddStock_files/connection-min.js"></script>
        <!-- YUI Autocomplete sources -->
        <script type="text/javascript" src="MoveAddStock_files/autocomplete-min.js"></script>

        <!-- calendar -->
        <script type="text/javascript" src="MoveAddStock_files/calendar.js"></script>
        <!-- Custom YUI widget -->
        <script type="text/javascript" src="MoveAddStock_files/Editable.js"></script>
        <!-- CSS -->
        <link rel="stylesheet" type="text/css"
href="MoveAddStock_files/grids-min.css">
        <link rel="stylesheet" type="text/css"
href="MoveAddStock_files/button.css">
        <link rel="stylesheet" type="text/css"
href="MoveAddStock_files/datatable.css">
        <link rel="stylesheet" type="text/css"
href="MoveAddStock_files/tabview.css">
        <link rel="stylesheet" type="text/css"
href="MoveAddStock_files/menu.css">
        <link rel="stylesheet" type="text/css"
href="MoveAddStock_files/container.css">
        <link rel="stylesheet" type="text/css"
href="MoveAddStock_files/autocomplete.css">
        <link rel="stylesheet" type="text/css"
href="MoveAddStock_files/calendar.css">

        <!-- (end) YUI majik -->



            <script type="text/javascript" src="MoveAddStock_files/yahoo-dom-event.js"></script>

            <script type="text/javascript" src="MoveAddStock_files/element-min.js"></script>

            <script type="text/javascript" src="MoveAddStock_files/tabview-min.js"></script>




        <!-- Custom CSS -->

            <link rel="stylesheet" type="text/css"
href="MoveAddStock_files/tabview.css">


        <!-- Core CSS
            Placing these here allows us to override YUI styles if we want
            to, but still have extra/custom CSS below to override the default XT
            styles
        -->
        <link rel="stylesheet" type="text/css" media="screen"
href="MoveAddStock_files/xtracker.css">
        <link rel="stylesheet" type="text/css" media="screen"
href="MoveAddStock_files/customer.css">
        <link rel="stylesheet" type="text/css" media="print"
href="MoveAddStock_files/print.html">

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
           <img src="MoveAddStock_files/logo_small.gif" alt="xTracker">
           <span>DISTRIBUTION</span><span class="dc">DC1</span>
        </div>

            <div id="headerControls">
                Logged in as: <span>DISABLED: IT God</span>
                <a href="http://xtdc1-frank:8529/My/Messages"
class="messages"><img src="MoveAddStock_files/email_open.png"
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
        <img src="MoveAddStock_files/model_INTL.jpg" alt="" height="87"
width="157">
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





                                <li index="1" groupindex="0"
id="yui-gen1" class="yuimenubaritem"><a
href="http://xtdc1-frank:8529/StockControl/Inventory"
class="yuimenubaritemlabel">Inventory</a></li>



            </ul>
        </div>

</div>

</div>


    <div id="content">
        <div id="contentLeftCol">


        <ul>





                    <li><a
href="http://xtdc1-frank:8529/StockControl/Inventory/SearchForm"
class="last">New Search</a></li>




                        <li><span>Product</span></li>



                    <li><a
href="http://xtdc1-frank:8529/StockControl/Inventory/Overview?product_id=32389">Product
 Overview</a></li>

                    <li><a
href="http://xtdc1-frank:8529/StockControl/Inventory/ProductDetails?product_id=32389">Product
 Details</a></li>

                    <li><a
href="http://xtdc1-frank:8529/StockControl/Inventory/Pricing?product_id=32389">Pricing</a></li>

                    <li><a
href="http://xtdc1-frank:8529/StockControl/Inventory/Sizing?product_id=32389">Sizing</a></li>

                    <li><a
href="http://xtdc1-frank:8529/StockControl/PurchaseOrder/Search?variant_id=151237&amp;search=1"
 class="last">Purchase Orders</a></li>







                        <li><span>Product Logs</span></li>



                    <li><a
href="http://xtdc1-frank:8529/StockControl/Inventory/Log/Product/DeliveryLog?product_id=32389">Deliveries</a></li>

                    <li><a
href="http://xtdc1-frank:8529/StockControl/Inventory/Log/Product/AllocatedLog?variant_id=151237"
 class="last">Allocated</a></li>




                        <li><span>Variant Logs</span></li>



                    <li><a
href="http://xtdc1-frank:8529/StockControl/Inventory/Log/Variant/StockLog?variant_id=151237">Transaction
 Log</a></li>

                    <li><a
href="http://xtdc1-frank:8529/StockControl/Inventory/Log/Variant/PWSLog?variant_id=151237">PWS
 Log</a></li>

                    <li><a
href="http://xtdc1-frank:8529/StockControl/Inventory/Log/Variant/RTVLog?variant_id=151237">RTV
 Log</a></li>

                    <li><a
href="http://xtdc1-frank:8529/StockControl/Inventory/Log/Variant/ReservationLog?variant_id=151237">Reservation
 Log</a></li>

                    <li><a
href="http://xtdc1-frank:8529/StockControl/Inventory/Log/Variant/CancellationLog?variant_id=151237">Cancellation
 Log</a></li>

                    <li><a
href="http://xtdc1-frank:8529/StockControl/Inventory/Log/Variant/LocationLog?variant_id=151237"
 class="last">Location Log</a></li>


        </ul>

</div>




        <div id="contentRight">











                    <div id="pageTitle">
                        <h1>Stock Control</h1>
                        <h5>•</h5><h2>Inventory</h2>
                        <h5>•</h5><h3>Move/Add Stock</h3>
                    </div>








    <!-- TT BEGIN - stocktracker/inventory/location.tt -->
    <div id="display_product">
        <script type="text/javascript" src="MoveAddStock_files/showhide.js"></script>
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

<span class="title">Product Summary</span><br>
<table class="data" border="0" cellpadding="0" cellspacing="0"
width="100%">
    <thead>
        <tr>
            <td class="divider" width="120"></td>
            <td class="divider" width="10"></td>
            <td class="divider" width="84"></td>
            <td class="divider" width="25"></td>
            <td class="divider" width="40%"></td>
            <td class="divider" width="25"></td>
            <td class="divider" width="40%"></td>
        </tr>
        <tr height="24">
            <td colspan="7" class="tableheader">
                &nbsp;&nbsp;&nbsp;<a
href="http://xtdc1-frank:8529/StockControl/Inventory/Overview?product_id=32389">32389</a>&nbsp;&nbsp;:&nbsp;&nbsp;Stella
 McCartney - Dolly Snogging T-back bra
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
                <a href="javascript://"
onclick="enlargeImage('http://cache.net-a-porter.com/images/products/32389/32389_in_dl.jpg')"><img
 class="product" src="MoveAddStock_files/32389_in_m.jpg" height="180"
width="120"></a>
            </td>
            <td class="blank"><img src="MoveAddStock_files/blank.gif"
height="1" width="10"></td>
            <td class="blank">
                <a href="javascript://"
onclick="enlargeImage('http://cache.net-a-porter.com/images/products/32389/32389_bk_dl.jpg')"><img
 class="product" src="MoveAddStock_files/32389_bk_xs.jpg" height="84"
width="56"></a>
                <br clear="all">
                <a href="javascript://"
onclick="enlargeImage('http://cache.net-a-porter.com/images/products/32389/32389_cu_dl.jpg')"><img
 class="product" src="MoveAddStock_files/32389_cu_xs.jpg"
style="margin-top: 10px;" height="84" width="56"></a>
            </td>
            <td class="blank"><img src="MoveAddStock_files/blank.gif"
height="1" width="25"></td>
            <td class="blank" colspan="3">

                <table style="margin-bottom: 17px;" cellpadding="0"
cellspacing="0" width="100%">
                    <tbody><tr>
                        <td class="blank" width="47%">
                            <table class="data" cellpadding="2"
cellspacing="0" width="100%">
                                <tbody><tr>
                                    <td colspan="3" class="divider"></td>
                                </tr>
                                <tr>
                                    <td align="right" width="35%"><b>Style
 Number:</b>&nbsp;</td>
                                    <td width="65%">S72-012</td>
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
                            </tbody></table>
                        </td>
                        <td class="blank" width="6%"></td>
                        <td class="blank" width="47%">
                            <table class="data" cellpadding="2"
cellspacing="0" width="100%">
                                <tbody><tr>
                                    <td colspan="3" class="divider"></td>
                                </tr>
                                <tr>
                                    <td align="right" nowrap="nowrap"><b>Size
 Scheme:</b>&nbsp;</td>
                                    <td colspan="2">Bra</td>
                                </tr>
                                <tr>
                                    <td colspan="3" class="divider"></td>
                                </tr>
                                <tr>
                                    <td align="right"><b>Classification:</b>&nbsp;</td>
                                    <td colspan="2">Clothing / Lingerie /
 Bras</td>
                                </tr>
                                <tr>
                                    <td colspan="3" class="divider"></td>
                                </tr>
                                <tr>
                                    <td align="right" width="35%"><b>Purchase
 Order:</b>&nbsp;</td>
                                    <td colspan="2" width="65%">


                                            <a
href="http://xtdc1-frank:8529/StockControl/PurchaseOrder/Overview?po_id=5881">SMLHS08K1</a>
 &nbsp; &nbsp; <br>



                                            <a
href="http://xtdc1-frank:8529/StockControl/PurchaseOrder/Overview?po_id=6508">SMLHS08ROK2</a>
 &nbsp; &nbsp; <br>



                                            <a
href="http://xtdc1-frank:8529/StockControl/PurchaseOrder/Overview?po_id=6613">SMLHS08ROK3</a>
 &nbsp; &nbsp; <br>

												…

                                    </td>
                                </tr>
                                <tr>
                                    <td colspan="3" class="divider"></td>
                                </tr>
                            </tbody></table>
                        </td>
                    </tr>
                </tbody></table>
                <br>

                <table class="data" cellpadding="2" cellspacing="0"
width="100%">
                    <tbody><tr>
                        <td colspan="5" class="divider"></td>
                    </tr>
                    <tr>
                        <td class="tableHeader">&nbsp;&nbsp;Sales
Channel</td>
                        <td class="tableHeader">Status</td>
                        <td class="tableHeader">Arrival Date</td>
                        <td class="tableHeader">Upload Date</td>
                        <td class="tableHeader" width="16">&nbsp;</td>
                    </tr>
                    <tr>
                        <td colspan="5" class="divider"></td>
                    </tr>

                        <tr>
                            <td>&nbsp;&nbsp;<span class="title
title-NAP" style="line-height: 1em;">NET-A-PORTER.COM</span></td>
                            <td>

                                    <a
href="http://www.net-a-porter.com/product/32389" target="livewindow">Live</a>
 : Visible



                            </td>
                            <td>12-05-2008</td>
                            <td>21-05-2008</td>
                            <td><img
src="MoveAddStock_files/bullet_green.png" alt="Active"></td>
                        </tr>
                        <tr>
                            <td colspan="5" class="divider"></td>
                        </tr>


                </tbody></table>

             </td>
        </tr>
        <tr height="10">
            <td class="blank" colspan="3" align="center"><span
class="lowlight">Click on images to enlarge</span></td>
            <td class="blank" colspan="4" style="padding-top: 3px;"
align="right">

<div style="width: 90px;">

</div></td>
        </tr>
    </tbody>
</table>

<br><br>

<div id="enlargeImage" style="visibility: hidden; position: absolute;
left: 0px; top: 0px; z-index: 1000; padding-left: 3px; padding-bottom:
3px; background-color: rgb(204, 204, 204);">

    <div style="border: 1px solid rgb(102, 102, 102); background-color:
rgb(255, 255, 255); padding: 10px; z-index: 1001;">

        <div style="margin-bottom: 5px;" align="right"><a
href="javascript://" onclick="hideLayer('enlargeImage');">Close</a></div>
        <div id="imagePlaceHolder"></div>
    </div>
</div>


<div style="display: none; margin-top: 5px;" id="hideShow_new_comment">
    <table class="data" border="0" cellpadding="0" cellspacing="0"
width="100%">
    <form method="post"
action="/StockControl/Inventory/SetProductComments"></form>
    <input id="dbl_submit_token" name="dbl_submit_token" value="24798690" type="hidden">

    <input name="product_id" value="32389" type="hidden">
        <thead>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
            <tr height="24">
                <td class="tableheader" width="15%">&nbsp;&nbsp;Operator</td>
                <td class="tableheader" width="20%">Department</td>
                <td class="tableheader" width="20%">Date</td>
                <td class="tableheader" width="40%">Comment</td>
                <td class="tableheader" width="5%"></td>
            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
        </thead>
        <tbody>
            <tr height="24">
                <td width="15%">&nbsp;&nbsp;<input name="op"
value="DISABLED: IT God" size="12" readonly="readonly" type="text"></td>
                <td width="20%"><input name="dep" size="20"
readonly="readonly" type="text"></td>
                <td width="20%"><input name="dat" value="07-10-2010
13:55" size="17" readonly="readonly" type="text"></td>
                <td width="40%"><input name="comment" size="50"
type="text"></td>
                <td width="5%"></td>
            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
            <tr>
                <td colspan="5" class="blank"><img
src="MoveAddStock_files/blank.gif" height="7" width="1"></td>
            </tr>
            <tr>
                <td colspan="5" class="blank" align="right"><input
class="button" name="submit" value="Submit »" type="submit"></td>
            </tr>

        </tbody>

    </table>
    <br><br>
</div>

<div id="productComments" style="margin-bottom: 15px; display: none;">
    <table class="data" border="0" cellpadding="0" cellspacing="0"
width="100%">
        <tbody><tr>
            <td class="blank"><span class="title">Product Comments (0)</span></td>
            <td class="blank" align="right"></td>
        </tr>
        <tr>
            <td colspan="5" class="divider"></td>
        </tr>
    </tbody></table>

    <div style="display: none;" id="hideShow_comments">
        <table class="data" border="0" cellpadding="0" cellspacing="0"
width="100%">
            <thead>
            <tr height="24">
                <td class="tableheader" width="15%">&nbsp;&nbsp;Operator</td>
                <td class="tableheader" width="20%">Department</td>
                <td class="tableheader" width="20%">Date</td>
                <td class="tableheader" width="40%">Comment</td>
                <td class="tableheader" width="5%"></td>
            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
            </thead>
            <tbody>

            </tbody>
        </table>
    </div>
    <br><br>
</div>

    </div>






    <div id="tabContainer" class="yui-navset yui-navset-top">
		    <table class="tabChannelTable" border="0" cellpadding="0"
cellspacing="0" width="100%">
        <tbody><tr>
            <td align="right"><span class="tab-label">Sales
Channel:&nbsp;</span></td>
            <td align="right" nowrap="nowrap" width="5%">
                <ul class="yui-nav">						                <li
title="active" class="selected"><a href="#tab1" class="contentTab-NAP"
style="text-decoration: none;"><em>NET-A-PORTER.COM</em></a></li></ul>
            </td>
        </tr>
    </tbody></table>

        <div class="yui-content">







                <div id="tab1" class="tabWrapper-NAP">
				<div class="tabInsideWrapper">

                    <form name="location_1" action="SetStockLocation"
method="post" onsubmit="return v_location_1.exec()">
                        <input id="dbl_submit_token" name="dbl_submit_token" value="24798690"
type="hidden">
                        <input name="view_channel"
value="NET-A-PORTER.COM" type="hidden">
                    <span class="title title-NAP">Stock by Location</span><br>
                    <table class="data" border="0" cellpadding="0"
cellspacing="0" width="100%">
                        <thead>
                            <tr>
                                <td colspan="8" class="dividerHeader"></td>
                            </tr>
                            <tr height="24">
                                <td class="tableHeader" width="10%">&nbsp;&nbsp;&nbsp;&nbsp;
SKU</td>
                                <td class="tableHeader" width="15%">Designer
 Size</td>
                                <td class="tableHeader" width="10%">Location</td>
                                <td class="tableHeader" width="10%">Quantity</td>
                                <td class="tableHeader" width="13%">New
Location</td>
                                <td class="tableHeader" width="10%">New
Quantity</td>
                                <td class="tableHeader" width="10%">Delete</td>
                            </tr>
                            <tr>
                                <td colspan="8" class="dividerHeader"></td>
                            </tr>
                            </thead>
                            <tbody>








                                            <tr height="20">
                                                <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;


                                                    <a
href="MoveAddStock?variant_id=151237">32389-263</a>
                                                    <input
name="channel_151237_40498" value="1" type="hidden">
                                                    <input
name="vid_151237_40498" value="151237" type="hidden">
                                                </td>
                                                <td>34DD</td>
                                                <td>019Z996Z<input
name="olocation_151237_40498" value="019Z996Z" type="hidden"></td>
                                                <td>187
                                                    <input
name="oquantity_151237_40498" value="187" type="hidden"></td>
                                                <td>

                                                    <input size="10"
name="nlocation_151237_40498" type="text">&nbsp;<span
id="nlocation_151237_40498" class="tfvNormal">*</span>

                                                </td>
                                                <td>

                                                    <input
name="nquantity_151237_40498" size="2" value="0" type="text">&nbsp;<span
 id="nquantity_151237_40498" class="tfvNormal">*</span>

                                                </td>
                                                <td><input
name="delete_151237_40498" disabled="disabled" type="checkbox"></td>
                                            </tr>
                                            <tr>
                                                <td colspan="8"
class="divider"></td>
                                            </tr>





                        </tbody>
                    </table>


                        <input name="variant_id" value="151237"
type="hidden">


                    <table border="0" cellpadding="0" cellspacing="0"
width="100%">
                        <tbody>
                            <tr height="24">
                                <td align="right"><input name="submit"
class="button" value="Submit »" type="submit">
</td>
                            </tr>
                        </tbody>
                    </table>



                    </form>

				</div>
                </div>

    </div>
</div>

<script language="Javascript">
<!--

    // form fields description structure
    var a_fields_1 = {


        'nlocation_151237_40498' : { 'l': 'New Location', 'r': false, 'f': 'nap_location', 't': 'nlocation_151237_40498', 'm': null, 'mn': 1, 'mx': 16 },

        'nquantity_151237_40498' : { 'l': 'Quantity', 'r': true, 'f': 'unsigned', 't': 'nquantity_151237_40498', 'm': null, 'mn': 1, 'mx': 3 }

    };

    // validator configuration
    o_config_1 = { 'to_disable': ['Submit'], 'alert': 1 };

    // validator constructor call
    var v_location_1 = new validator('location_1', a_fields_1, o_config_1);

//-->
</script>

<script type="text/javascript" language="javascript">
    (function() {
        var tabView = new YAHOO.widget.TabView('tabContainer');
    })();
</script>




<!-- TT END - stocktracker/inventory/location.tt -->





        </div>
    </div>

    <p id="footer">    xTracker-DC (2010.21.10.247.g9341632). © 2006 -
2010 NET-A-PORTER
</p>


</div>

    </body></html>
