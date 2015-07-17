#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

GoodsIn_StockIn_PackingSlip_mostly_blank.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /GoodsIn/StockIn/PackingSlip

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/GoodsIn/StockIn/PackingSlip?so_id=115323',
    expected   => {
           'product_data' => {
                               'ID' => '',
                               'Purchase Order' => {
                                                     'value' => 'test po 17',
                                                     'url' => '/StockControl/PurchaseOrder/Overview?po_id=17'
                                                   },
                               'Channels' => [
                                               {
                                                 'Upload Date' => '-',
                                                 'Status' => {
                                                               'value' => 'Live : Visible',
                                                               'url' => 'http://www.mrporter.com/product/'
                                                             },
                                                 'Arrival Date' => '26-01-2011',
                                                 'Sales Channel' => 'MRPORTER.COM'
                                               }
                                             ],
                               'Style Number' => '',
                               'Size Scheme' => '',
                               'Season' => '',
                               'Description' => '- [ Name Required ]',
                               'Classification' => '- / - / -',
                               'Colour' => 'Unknown'
                             },
           'variants' => [
                           {
                             'Delivered' => '0',
                             'Ordered' => '40',
                             'Packing Slip Value' => {
                                                       'input_name' => 'count_1',
                                                       'value' => '',
                                                       'input_value' => '0'
                                                     },
                             'Designer Size' => 'IT None/Unknown',
                             'Sku' => '14-001'
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

        <title>XT-DC1</title>


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
        <script type="text/javascript" src="/jquery/jquery-1.4.2.min.js"></script>
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
                Logged in as: <span class="operator_name">DISABLED: IT God</span>
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





                                <li class="yuimenubaritem"><a href="/GoodsIn/StockIn" class="yuimenubaritemlabel">Stock In</a></li>


                                <li class="yuimenubaritem"><a href="/GoodsIn/ItemCount" class="yuimenubaritemlabel">Item Count</a></li>

                                <li class="yuimenubaritem"><a href="/GoodsIn/QualityControl" class="yuimenubaritemlabel">Quality Control</a></li>

                                <li class="yuimenubaritem"><a href="/GoodsIn/BagAndTag" class="yuimenubaritemlabel">Bag And Tag</a></li>

                                <li class="yuimenubaritem"><a href="/GoodsIn/Putaway" class="yuimenubaritemlabel">Putaway</a></li>

                                <li class="yuimenubaritem"><a href="/GoodsIn/Surplus" class="yuimenubaritemlabel">Surplus</a></li>



                                <li class="yuimenubaritem"><a href="/StockControl/Inventory" class="yuimenubaritemlabel">Inventory</a></li>


                                <li class="yuimenubaritem"><a href="/StockControl/Location" class="yuimenubaritemlabel">Location</a></li>



            </ul>
        </div>

</div>

</div>


    <div id="content">
        <div id="contentLeftCol">



        <ul>





                    <li><a href="/GoodsIn/StockIn" class="last">Back</a></li>


        </ul>

</div>



            <img id="channelTitle" src="/images/logo_MRPORTER_INTL.gif" alt="MRPORTER.COM">


        <div id="contentRight">











                    <div id="pageTitle">

                        <h1>Goods In</h1>
                        <h5>&bull;</h5><h2>Stock In</h2>
                        <h5>&bull;</h5><h3>Packing Slip</h3>
                    </div>





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
        <tr class="divideabove dividebelow">
            <td colspan="7" class="tableheader">
                &nbsp;&nbsp;&nbsp;<a href="/StockControl/Inventory/Overview?product_id="></a>&nbsp;&nbsp;:&nbsp;&nbsp; - [ <em>Name Required</em> ]
            </td>
        </tr>
    </thead>
    <tbody>
        <tr height="10">
            <td class="blank" colspan="7">&nbsp;</td>
        </tr>
        <tr height="100" valign="top">
            <td class="blank">

                <a href="javascript://" onClick="enlargeImage('http://cache.net-a-porter.com/images/products//_in_dl.jpg')"><img class="product" width="120" src="http://cache.net-a-porter.com/images/products/14/14.jpg"></a>
            </td>
            <td class="blank"><img src="/images/blank.gif" width="10" height="1"></td>
            <td class="blank">
                <a href="javascript://" onClick="enlargeImage('http://cache.net-a-porter.com/images/products//_bk_dl.jpg')"><img class="product" width="56" src="http://cache.net-a-porter.com/images/products/14/14_bk_xs.jpg"></a>
                <br clear="all">
                <a href="javascript://" onClick="enlargeImage('http://cache.net-a-porter.com/images/products//_cu_dl.jpg')"><img class="product" width="56" src="http://cache.net-a-porter.com/images/products/14/14_cu_xs.jpg" style="margin-top:10px"></a>
            </td>
            <td class="blank"><img src="/images/blank.gif" width="25" height="1"></td>
            <td class="blank" colspan="3">

                <table cellpadding="0" cellspacing="0" width="100%" style="margin-bottom:17px">
                    <tr>
                        <td width="47%" class="blank">
                            <table class="data wide-data divided-data">
                                <tr>
                                    <td align="right"><b>Style Number:</b>&nbsp;</td>
                                    <td></td>
                                </tr>
                                <tr>
                                    <td align="right"><b>Season:</b>&nbsp;</td>
                                    <td></td>
                                </tr>
                                <tr>
                                    <td align="right"><b>Colour:</b>&nbsp;</td>
                                    <td>

                                            Unknown

                                        &nbsp;



                                    </td>
                                </tr>
                            </table>
                        </td>
                        <td width="6%" class="blank"></td>
                        <td width="47%" class="blank">
                            <table class="data wide-data divided-data">
                                <tr>
                                    <td align="right"><b>Size Scheme:</b>&nbsp;</td>
                                    <td></td>
                                </tr>
                                <tr>
                                    <td align="right"><b>Classification:</b>&nbsp;</td>
                                    <td>- / - / -</td>
                                </tr>
                                <tr>
                                    <td align="right"><b>Purchase Order:</b>&nbsp;</td>
                                    <td>


                                            <a href="/StockControl/PurchaseOrder/Overview?po_id=17">test po 17</a> &nbsp; &nbsp; <br />



                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>
                </table>
                <br />

                <table class="data wide-data divided-data">
                    <thead>
                        <tr>
                            <th>Sales Channel</th>
                            <th>Status</th>
                            <th>Arrival Date</th>
                            <th>Upload Date</th>
                            <th>&nbsp;</th>
                        </tr>
                    </thead>
                    <tbody>

                        <tr>
                            <td><span class="title title-MRP" style="line-height: 1em;">MRPORTER.COM</span></td>
                            <td>

                                    <a href='http://www.mrporter.com/product/' target='livewindow'>Live</a> : Visible



                            </td>
                            <td>26-01-2011</td>
                            <td>-</td>
                            <td><img src="/images/icons/bullet_green.png" title="Active" alt="Active"></td>
                        </tr>

                    </tbody>
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
    <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="2">

    <input type="hidden" name="product_id" value="" />
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
                <td width="20%"><input type="text" name="dep" value="" size="20" readonly="readonly" /></td>

                <td width="20%"><input type="text" name="dat" value="26-01-2011 17:26" size="17" readonly="readonly" /></td>
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


<div id="main_form">
    <span class="title title-MRP">Enter Packing Slip Values</span>

    <br />

    <form action='CreateStockDelivery' method='post' name='create_stock_delivery'>
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
        <thead>
            <tr>
                <td colspan="5" class="dividerHeader"></td>
            </tr>
            <tr height="24">

                <td width="20%" class="tableHeader">&nbsp;&nbsp;&nbsp;&nbsp;
Sku</td>
                <td width="20%" class="tableHeader">Designer Size</td>
                <td width="15%" class="tableHeader">Ordered</td>
                <td width="15%" class="tableHeader">Delivered</td>
                <td width="20%" class="tableHeader">Packing Slip Value</td>
            </tr>

            <tr>
                <td colspan="5" class="dividerHeader"></td>
            </tr>
        </thead>
        <tbody>

                <tr height="20">
                    <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
14-001</td>
                    <td>IT None/Unknown</td>

                    <td>40</td>
                    <td>
                        0
                    </td>
                    <td>

                            <input type='text' size='5' name='count_1' value='0' />

                    </td>
                </tr>
                <tr>

                    <td colspan="5" class="divider"></td>
                </tr>

        </tbody>
    </table>
    <br />

    <input type="hidden" name="stock_order_id" value="6">

    <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="2">
<table width="100%" cellpadding="0" cellspacing="0" border="0">

    <tbody>
        <tr height="24">
            <td align="right"><input type="submit" name="submit" class="button" value="Submit &raquo;"></td>
        </tr>
    </tbody>
</table>


    </form>
</div>



        </div>
    </div>

    <p id="footer">    xTracker-DC (2010.27.02.170.g3aed870.dirty). &copy; 2006 - 2011 NET-A-PORTER
</p>


</div>

    </body>

</html>

