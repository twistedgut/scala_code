#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

Fulfilment_Packing_CheckShipmentException.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /Fulfilment/Packing/CheckShipmentException

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/Fulfilment/Packing/CheckShipmentException',
    expected   => {

'shipment_id' => '1460332',
'shipment_items' => [
      {
        'Shipment Item ID' => '3333446',
        'Designer' => 'Ray-Ban',
        'QC' => "Failure reason: «Muppet fur is the wrong texture» Packer name: DISABLED: IT God",
        'Size' => 'n/a',
        'Actions' => '',
        'Name' => 'Wayfarer acetate sunglasses',
        'Container' => 'MXTEST900297',
        'SKU' => '32909-005'
      },
      {
        'Shipment Item ID' => '3333445',
        'Designer' => 'Stella McCartney',
        'QC' => 'Ok',
        'Size' => 'UK/US 34DD',
        'Actions' => 'This item has been cancelled and must be removed',
        'Name' => 'Dolly Snogging lace T-back bra',
        'Container' => 'MXTEST900297',
        'SKU' => '32389-263'
      },
      {
        'Shipment Item ID' => '3333448',
        'Designer' => 'J Brand',
        'QC' => 'Ok',
        'Size' => '26',
        'Actions' => '',
        'Name' => '912 low-rise skinny jeans',
        'Container' => 'MXTEST900297',
        'SKU' => '35074-073'
      },
      {
        'Shipment Item ID' => '3333447',
        'Designer' => 'Hunter',
        'QC' => 'Ok',
        'Size' => 'UK 3',
        'Actions' => 'This item has been cancelled and must be removed',
        'Name' => 'Original Tall Wellington boots',
        'Container' => 'MXTEST900297',
        'SKU' => '34300-027'
      }
    ],
'shipment_summary' => {
      'Other Info' => '',
      'Notes' => [],
      'Customer No.' => '251603',
      'Channel' => 'NET-A-PORTER.COM',
      'Shipment Number' => '1460332',
      'Type' => 'Domestic',
      'Class' => 'Customer Order',
      'Instructions' => '',
      'Shipment Date' => '06-12-2010 17:32',
      'Customer Name' => 'eada819 ae6d06'
    }

    }
);

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en">
    <head>
        <meta http-equiv="Content-type" content="text/html; charset=utf-8">

        <title>Packing &#8226; Fulfilment &#8226; XT-DC1</title>


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





                                <li class="yuimenubaritem"><a href="/CustomerCare/CustomerSearch" class="yuimenubaritemlabel">Customer Search</a></li>


                                <li class="yuimenubaritem"><a href="/CustomerCare/OrderSearch" class="yuimenubaritemlabel">Order Search</a></li>



                                <li class="yuimenubaritem"><a href="/Fulfilment/Packing" class="yuimenubaritemlabel">Packing</a></li>

                                <li class="yuimenubaritem"><a href="/Fulfilment/PackingException" class="yuimenubaritemlabel">Packing Exception</a></li>



            </ul>
        </div>

</div>

</div>


    <div id="content">
        <div id="contentLeftCol">


        <ul>





                    <li><a href="/Fulfilment/PackingException" class="last">Back</a></li>


        </ul>

</div>



            <img id="channelTitle" src="/images/logo_NET-A-PORTER_INTL.gif" alt="NET-A-PORTER.COM">


        <div id="contentRight">











                    <div id="pageTitle">
                        <h1>Fulfilment</h1>
                        <h5>&bull;</h5><h2>Packing</h2>
                        <h5>&bull;</h5><h3>Check Shipment Exception</h3>
                    </div>




















<h2 class="title title-NAP">Shipment Summary</h2>

<div class="formrow dividebelow divideabove">
  <span class="fakelabel">Shipment Number:</span>
  <p>1460332</p>
</div>
<div class="formrow dividebelow">
  <span class="fakelabel">Channel:</span>

  <p>NET-A-PORTER.COM</p>
</div>
<div class="formrow dividebelow">
  <span class="fakelabel">Class:</span>
  <p>Customer Order</p>
</div>
<div class="formrow dividebelow">
  <span class="fakelabel">Type:</span>
  <p>Domestic</p>

</div>
<div class="formrow dividebelow">
  <span class="fakelabel">Shipment Date:</span>
  <p>06-12-2010 17:32</p>
</div>
<div class="formrow dividebelow">
  <span class="fakelabel">Customer No.:</span>
  <p>251603</p>
</div>

<div class="formrow dividebelow">
  <span class="fakelabel">Customer Name:</span>
  <p>eada819 ae6d06</p>
</div>
<div class="formrow dividebelow">
  <span class="fakelabel">Other Info:</span>
  <ul>



  </ul>

</div>
<div class="formrow dividebelow">
  <span class="fakelabel">Instructions:</span>
  <p></p>
</div>

<div class="formrow dividebelow">
    <span class="fakelabel">Notes:</span>
    <!-- Shipment Packing Exception Notes -->
        <div class="shipment-packing-exception-notes">

            <form method="POST" action="/Fulfilment/Packing/CreateNote" name="add_comments">
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="quality-control-notes">
                <tr><td colspan="5" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td></tr>
                <tr>
                    <td class="tableHeader" width="20%" style="padding-left: 1em">Date</td>
                    <td class="tableHeader" width="20%">Operator</td>
                    <td class="tableHeader" width="50%">Note</td>

                    <td class="tableHeader" width="5%">&nbsp;</td>
                    <td class="tableHeader" width="5%">&nbsp;</td>
                </tr>
                <tr><td colspan="5" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td></tr>


                <tr>
                    <td><input type="text" readonly="readonly" name="tainted-date" style="width: 90%" value="07-12-2010 11:10"></td>
                    <td><input type="text" readonly="readonly" name="tainted-name" style="width: 90%" value="DISABLED: IT God"></td>
                    <td><input type="text" style="width: 90%" name="note_text"></td>
                    <td colspan="2" align="center"><input type="submit" value="Add comment" style="min-width: 0px;"></td>

                </tr>
                <tr><td colspan="5" class="divider"><img src="/images/blank.gif" width="1" height="1"></td></tr>

                <input type="hidden" name="note_category" value="Quality Control">
                <input type="hidden" name="came_from"     value="packing_exception">
                <input type="hidden" name="shipment_id"   value="1460332">
                <input type="hidden" name="sub_id"        value="1460332">
                <input type="hidden" name="parent_id"     value="1371222">
                <input type="hidden" name="type_id"       value="11">
            </table>

            </form>
        </div>
    <!-- End Shipment Packing Exception Notes -->
</div>



                <h2 class="title title-NAP">Items to be Checked</h2>

            <table class="data wide-data">
                <thead>

                <tr>
                    <th></th>
                    <th>SKU</th>
                    <th>Designer</th>
                    <th width="20%">Name</th>
                    <th>Size</th>
                    <th>Container</th>

                    <th width="20%">QC</th>
                    <th>Actions</th>
                </tr>
                </thead>
                </tbody>




                        <tr class="divideabove">
                            <td rowspan="2"><img src="http://cache.net-a-porter.com/images/products/32909/32909_in_m.jpg" width="120" height="180"></td>
                            <td align="center">32909-005<br><br>(32909)</td>

                            <td>Ray-Ban</td>
                            <td>Wayfarer acetate sunglasses</td>
                            <td>n/a</td>
                            <td>MXTEST900297</td>
                            <td>

    Failure reason: &laquo;Muppet fur is the wrong texture&raquo;


        <br/>Packer name: <cite class="packerName">DISABLED: IT God</cite>


</td>
                            <td>

                                    <form name="faulty-item-3333446"
                                          action="/Fulfilment/PackingException/ScanOutPEItem"
                                          method="post"
                                          onsubmit="return double_submit()">
                                        <input type="hidden" name="shipment_id" value="1460332" />
                                        <input type="hidden" name="shipment_item_id" value="3333446" />
                                        <input type="hidden" name="situation" value="removeFaulty" />
                                        <input type="submit" name="faulty" value="This item is faulty &raquo;" class="bad">

                                    </form>
                                    <form name="missing-item-3333446"
                                          action="/Fulfilment/Packing/CheckShipmentException"
                                          method="post"
                                          onsubmit="return double_submit()">
                                        <input type="hidden" name="shipment_id" value="1460332" />
                                        <input type="hidden" name="shipment_item_id" value="3333446" />
                                        <input type="submit" name="missing" value="This item is missing &raquo;" class="bad">
                                        <input type="submit" name="item_ok" value="This item is OK! &raquo;" class="good">
                                    </form>

                            </td>
                        </tr>

                        <tr height="30">
                            <td colspan="7" align="center">
    <span class="highlight">&nbsp;</span>
</td>
                        </tr>





                        <tr class="divideabove">
                            <td rowspan="2"><img src="http://cache.net-a-porter.com/images/products/32389/32389_in_m.jpg" width="120" height="180"></td>
                            <td align="center">32389-263<br><br>(32389_13)</td>

                            <td>Stella McCartney</td>
                            <td>Dolly Snogging lace T-back bra </td>
                            <td>UK/US 34DD</td>
                            <td>MXTEST900297</td>
                            <td>

    Ok


</td>
                            <td>

                                    <strong style="display:block; margin: 5px">This item has been cancelled and must be removed</strong>
                                    <form name="faulty-item-3333445"
                                          action="/Fulfilment/PackingException/ScanOutPEItem"
                                          method="post"
                                          onsubmit="return double_submit()">
                                        <input type="hidden" name="shipment_id" value="1460332" />
                                        <input type="hidden" name="shipment_item_id" value="3333445" />
                                        <input type="hidden" name="situation" value="removeCancelPending" />
                                        <input type="submit" name="remove" value="Remove Item &raquo;" class="bad">
                                    </form>


                            </td>
                        </tr>
                        <tr height="30">
                            <td colspan="7" align="center">
    <span class="highlight">&nbsp;</span>
</td>
                        </tr>





                        <tr class="divideabove">
                            <td rowspan="2"><img src="http://cache.net-a-porter.com/images/products/35074/35074_in_m.jpg" width="120" height="180"></td>

                            <td align="center">35074-073<br><br>(35074_2)</td>
                            <td>J Brand</td>
                            <td>912 low-rise skinny jeans </td>
                            <td>26</td>
                            <td>MXTEST900297</td>
                            <td>

    Ok

</td>
                            <td>

                                    <form name="faulty-item-3333448"
                                          action="/Fulfilment/PackingException/ScanOutPEItem"
                                          method="post"
                                          onsubmit="return double_submit()">
                                        <input type="hidden" name="shipment_id" value="1460332" />
                                        <input type="hidden" name="shipment_item_id" value="3333448" />
                                        <input type="hidden" name="situation" value="removeFaulty" />
                                        <input type="submit" name="faulty" value="This item is faulty &raquo;" class="bad">
                                    </form>

                                    <form name="missing-item-3333448"
                                          action="/Fulfilment/Packing/CheckShipmentException"
                                          method="post"
                                          onsubmit="return double_submit()">
                                        <input type="hidden" name="shipment_id" value="1460332" />
                                        <input type="hidden" name="shipment_item_id" value="3333448" />
                                        <input type="submit" name="missing" value="This item is missing &raquo;" class="bad">

                                    </form>

                            </td>
                        </tr>
                        <tr height="30">
                            <td colspan="7" align="center">

    <span class="highlight">&nbsp;</span>
</td>
                        </tr>





                        <tr class="divideabove">
                            <td rowspan="2"><img src="http://cache.net-a-porter.com/images/products/34300/34300_in_m.jpg" width="120" height="180"></td>
                            <td align="center">34300-027<br><br>(34300)</td>
                            <td>Hunter</td>
                            <td>Original Tall Wellington boots</td>

                            <td>UK 3</td>
                            <td>MXTEST900297</td>
                            <td>

    Ok

</td>
                            <td>

                                    <strong style="display:block; margin: 5px">This item has been cancelled and must be removed</strong>

                                    <form name="faulty-item-3333447"
                                          action="/Fulfilment/PackingException/ScanOutPEItem"
                                          method="post"
                                          onsubmit="return double_submit()">
                                        <input type="hidden" name="shipment_id" value="1460332" />
                                        <input type="hidden" name="shipment_item_id" value="3333447" />
                                        <input type="hidden" name="situation" value="removeCancelPending" />
                                        <input type="submit" name="remove" value="Remove Item &raquo;" class="bad">
                                    </form>

                            </td>
                        </tr>
                        <tr height="30">

                            <td colspan="7" align="center">
    <span class="highlight">&nbsp;</span>
</td>
                        </tr>


                </tbody>
            </table>















        </div>
    </div>

    <p id="footer">    xTracker-DC (2010.25.03.22.gc779cc2.dirty). &copy; 2006 - 2010 NET-A-PORTER
</p>


</div>

    </body>
</html>

