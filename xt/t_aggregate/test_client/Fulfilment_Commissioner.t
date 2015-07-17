#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

Fulfilment_Commissioner.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /Fulfilment/Commissioner

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/Fulfilment/Commissioner',
    expected   => {
           'No Action' => [],
           'Shipment Cancelled' => [
                                     {
                                       'SLA' => '',
                                       'Staff' => '',
                                       'Container' => 'MXTEST900511',
                                       'Premier Shipment' => '',
                                       'Shipment Number' => '1460427'
                                     },
                                     {
                                       'SLA' => '',
                                       'Staff' => '',
                                       'Container' => 'MXTEST900519',
                                       'Premier Shipment' => '',
                                       'Shipment Number' => '1460431'
                                     }
                                   ],
           'Ready for Packing' => [],
           'Shipment On Hold' => []
    },
);

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en">
    <head>
        <meta http-equiv="Content-type" content="text/html; charset=utf-8">

        <title>Commissioner &#8226; Fulfilment &#8226; XT-DC1</title>


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

                                <li class="yuimenubaritem"><a href="/Fulfilment/Commissioner" class="yuimenubaritemlabel">Commissioner</a></li>



            </ul>
        </div>


</div>

</div>


    <div id="content">
        <div id="contentLeftCol">


</div>




        <div id="contentRight">











                    <div id="pageTitle">

                        <h1>Fulfilment</h1>
                        <h5>&bull;</h5><h2>Commissioner</h2>

                    </div>








<span class="title">Ready For Packing</span><br>
<table id="packing-ready" width="100%" cellpadding="0" cellspacing="0" border="0" class="data" style="padding-bottom: 20px;">
  <tr>
    <td class="dividerHeader" colspan="7"></td>

  </tr>
  <tr>
    <td class="tableHeader"></td>
    <td class="tableHeader">Container</td>
    <td class="tableHeader">Shipment Number</td>
    <td class="tableHeader">SLA</td>
    <td class="tableHeader">Premier Shipment</td>

    <td class="tableHeader">Staff</td>
  </tr>


  <tr>
    <td colspan="6">None</td>
  </tr>



</table>


<span class="title">Shipment Cancelled - scan at Packing Exception to enable putaway</span><br>
<table id="cancel-pending" width="100%" cellpadding="0" cellspacing="0" border="0" class="data" style="padding-bottom: 20px;">
  <tr>
    <td class="dividerHeader" colspan="7"></td>
  </tr>
  <tr>
    <td class="tableHeader"></td>
    <td class="tableHeader">Container</td>
    <td class="tableHeader">Shipment Number</td>

    <td class="tableHeader">SLA</td>
    <td class="tableHeader">Premier Shipment</td>
    <td class="tableHeader">Staff</td>
  </tr>




  <tr>
    <td></td>
    <td>MXTEST900511</td>

    <td>1460427</td>

    <td  style='color:green'></td>

    <td>&nbsp;</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td></td>
    <td>MXTEST900519</td>

    <td>1460431</td>

    <td  style='color:green'></td>

    <td>&nbsp;</td>
    <td>&nbsp;</td>
  </tr>

</table>


<span class="title">Shipment On Hold - no action required</span><br>

<table id="on-hold" width="100%" cellpadding="0" cellspacing="0" border="0" class="data" style="padding-bottom: 20px;">
  <tr>
    <td class="dividerHeader" colspan="7"></td>
  </tr>
  <tr>
    <td class="tableHeader"></td>
    <td class="tableHeader">Container</td>
    <td class="tableHeader">Shipment Number</td>

    <td class="tableHeader">SLA</td>
    <td class="tableHeader">Premier Shipment</td>
    <td class="tableHeader">Staff</td>
  </tr>


  <tr>
    <td colspan="6">None</td>

  </tr>



</table>


<span class="title">No action (a packer will collect)</span><br>
<table id="no-action-required" width="100%" cellpadding="0" cellspacing="0" border="0" class="data" style="padding-bottom: 20px;">
  <tr>
    <td class="dividerHeader" colspan="7"></td>
  </tr>
  <tr>

    <td class="tableHeader"></td>
    <td class="tableHeader">Container</td>
    <td class="tableHeader">Shipment Number</td>
    <td class="tableHeader">SLA</td>
    <td class="tableHeader">Premier Shipment</td>
    <td class="tableHeader">Staff</td>

  </tr>


  <tr>
    <td colspan="6">None</td>
  </tr>



</table>


</table>




        </div>
    </div>

    <p id="footer">    xTracker-DC (2010.25.03.22.gc779cc2.dirty). &copy; 2006 - 2010 NET-A-PORTER
</p>


</div>

    </body>

</html>

