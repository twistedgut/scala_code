#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

CustomerCare_ConfirmAddress.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for Spec:

    CustomerCare/OrderSearch/ConfirmAddress

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    spec       => 'CustomerCare/OrderSearch/ConfirmAddress',
    expected   => {
        'customer_email' => {
            'Email Text' => 'Test Content',
            'From' => {
                'input_name'  => 'email_from',
                'input_value' => 'customercare@net-a-porter.com',
                'value'       => ''
            },
            'Reply-To' => {
                'input_name'  => 'email_replyto',
                'input_value' => 'customercare@net-a-porter.com',
                'value'       => ''
            },
            'Send Email' => {
                'input_name'  => 'send_email',
                'input_value' => 'yes',
                'value'       => 'Yes No'
            },
            'Subject' => {
                'input_name'  => 'email_subject',
                'input_value' => 'Your order - 1000000159',
                'value'       => ''
            },
            'To' => {
                'input_name'  => 'email_to',
                'input_value' => 'test.suite@xtracker',
                'value'       => ''
            },
        },
        current_address => {
          'Current Address' => '',
          'First Name'      => 'some',
          Surname           => 'one',
          'Address Line 1'  => 'al1',
          'Address Line 2'  => 'al2',
          'Town/City'       => 'twn',
          County            => '',
          Postcode          => 'd6a31',
          Country           => 'United Kingdom',
          Unknown           => [''],
          'Nom Delivery Date' => '',
          'Shipping Option' => 'Unknown',
          'Current Shipping Option' => '',
          'Delivery Option' => '',
        },
        new_address => {
          'First Name'      => 'some',
          Surname           => 'one',
          'Address Line 1'  => 'al1',
          'Address Line 2'  => 'al2',
          'Town/City'       => 'twn',
          County            => 'NY',
          Country           => 'United States',
          Postcode          => 'd6a31',
          'Delivery Option' => '',
          'Shipping Option' => {
              input_name  => 'selected_shipping_charge_id',
              input_value => '5',
              value       => 'North America'
          },
          'Nom Delivery Date' => {
              input_name  => 'selected_nominated_delivery_date',
              input_value => '',
              value       => ''
          },
        },
    },
);

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en">
    <head>
        <meta http-equiv="Content-type" content="text/html; charset=utf-8">

        <title>Order Search &#8226; Customer Care &#8226; XT-DC1</title>


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





        <!-- Custom CSS -->

            <link rel="stylesheet" type="text/css" href="/css/shipping_restrictions.css">

            <link rel="stylesheet" type="text/css" href="/css/breadcrumb.css">


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







                <form class="quick_search" method="get" action="/QuickSearch">

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

                    <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1631%3Ang%2FViKZ4GBgQrNevtYUL7A">


                </form>


                <span class="operator_name">Logged in as: DISABLED: IT God</span>

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





                                <li class="yuimenubaritem"><a href="/CustomerCare/OrderSearch" class="yuimenubaritemlabel">Order Search</a></li>



            </ul>
        </div>

</div>

</div>


    <div id="content">

        <div id="contentLeftCol">


        <ul>





                    <li><a href="/CustomerCare/OrderSearch/ChooseAddress?address_type=Shipping&shipment_id=80&order_id=160" class="last">Back</a></li>


        </ul>

</div>



            <img id="channelTitle" src="/images/logo_NET-A-PORTER_INTL.gif" alt="NET-A-PORTER.COM">


        <div id="contentRight">













                    <!-- No title - Customer Care/Order Search/Edit Shipping Address -->






                    <p class="bc-container">
  <ul class="breadcrumb">






      <li class="step-2"><a href="#">1. Change Address</a></li>





      <li class="step-3"><a href="#">2. Check Order</a></li>




      <li class="current-step"><a href="#">3. Confirmation</a></li>

  </ul>
</p>







                <form name="editAddress" action="/CustomerCare/OrderSearch/UpdateAddress" method="post">


            <table id="edit_address_form" width="100%" cellpadding="0" cellspacing="0" border="0" class="data">

            <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1631%3Ang%2FViKZ4GBgQrNevtYUL7A">

            <input type="hidden" name="address_type" value="Shipping">
            <input type="hidden" name="order_id" value="160">
            <input type="hidden" name="shipment_id" value="80">
            <input type="hidden" name="base_address" value="155">



            <input type="hidden" name="title" value="">
            <input type="hidden" name="first_name" value="some">
            <input type="hidden" name="last_name" value="one">
            <input type="hidden" name="address_line_1" value="al1">
            <input type="hidden" name="address_line_2" value="al2">
            <input type="hidden" name="address_line_3" value="al3">
            <input type="hidden" name="towncity" value="twn">
            <input type="hidden" name="county" value="NY">
            <input type="hidden" name="postcode" value="d6a31">
            <input type="hidden" name="country" value="United States">

                <tr>
                            <td colspan="2" class="blank"><span class="title title-NAP">Current Address</span></td>
                            <td class="blank" width="10%"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="blank"><span class="title title-NAP">New Address</span></td>
                 </tr>
                <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                 </tr>
                <tr>
                            <td width="15%" align="right"><b>First Name:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;some</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td width="15%" align="right"><b>First Name:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;some</td>
                    </tr>
                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>
                <tr>
                            <td width="15%" align="right"><b>Surname:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;one</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td width="15%" align="right"><b>Surname:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;one</td>
                    </tr>
                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>
                <tr>
                            <td width="10%" align="right"><b>Address Line 1:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;al1</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td width="10%" align="right"><b>Address Line 1:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;al1</td>
                    </tr>
                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>
                    <tr>
                            <td width="10%" align="right"><b>Address Line 2:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;al2</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td width="10%" align="right"><b>Address Line 2:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;al2</td>
                     </tr>
                     <tr>
                        <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                        <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                     </tr>
                <tr>
                            <td width="10%" align="right"><b>Town/City:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;twn</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td width="10%" align="right"><b>Town/City:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;twn</td>
                    </tr>
                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>
                <tr>
                            <td width="10%" align="right"><b>County:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td width="10%" align="right"><b>County:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;NY</td>
                    </tr>
                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>
                <tr>
                            <td width="10%" align="right"><b>Postcode:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;d6a31</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td width="10%" align="right"><b>Postcode:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;d6a31</td>
                        </tr>
                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>
                <tr>
                            <td width="10%" align="right"><b>Country:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;United Kingdom</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td width="10%" align="right"><b>Country:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;United States</td>
                    </tr>
                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>





                    <tr>
                            <td class="blank" colspan="2"><img src="/images/blank.gif" width="1" height="8"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank" colspan="2"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>
                    <tr>
                            <td colspan="2" class="blank"><span class="title title-NAP">Current Shipping Option</span></td>
                            <td class="blank" width="10%"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="blank"><span class="title title-NAP">New Shipping Option</span></td>
                    </tr>

                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>
                    <tr>
                            <td width="15%" align="right"><b>Shipping Option:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;Unknown</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>

                            <td width="15%" align="right"><b>Shipping Option:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;


                                North America
                                <input
                                    type="hidden"
                                    name="selected_shipping_charge_id"
                                    id="shipping_charge_id"
                                    value="5"
                                >
                            </td>
                    </tr>

                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>
                    <tr>
                            <td width="15%" align="right"><b>Nom Delivery Date:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>

                            <td width="15%" align="right"><b>Nom Delivery Date:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;

                                <input
                                    type="hidden"
                                    name="selected_nominated_delivery_date"
                                    value=""
                                >
                            </td>
                    </tr>
                    <tr>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>
                            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                    </tr>
                    <tr>
                            <td width="15%" align="right"><b>Delivery Option:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;</td>
                            <td class="blank"><img src="/images/blank.gif" width="1" height="1"></td>

                            <td width="15%" align="right"><b>Delivery Option:&nbsp;&nbsp;</td>
                            <td width="30%">&nbsp;

                            </td>
                    </tr>



            </table>

            <br><br>





                    <input type="hidden" name="new_pricing" value="1">

                    <span class="title title-NAP">New Pricing</span><br>

                    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                            <tr>
                                    <td colspan="9" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
                            </tr>
                            <tr>
                                <td class="tableHeader" width="10%">&nbsp;&nbsp;PID</td>
                                <td class="tableHeader" width="16%">Designer</td>
                                <td class="tableHeader" width="19%">Name</td>
                                <td class="tableHeader" width="9%">Price</td>
                                <td class="tableHeader" width="9%">Tax</td>
                                <td class="tableHeader" width="9%">Duty</td>
                                <td class="tableHeader" width="9%">New Price</td>
                                <td class="tableHeader" width="9%">New Tax</td>
                                <td class="tableHeader" width="17%">New Duty</td>
                                </tr>
                                <tr>
                                        <td colspan="9" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
                                </tr>


                                    <tr>
                                        <td>&nbsp;1-863</td>
                                        <td>République ✪ Ceccarelli</td>
                                        <td>Name</td>
                                        <td>1.00</td>
                                        <td>1.00</td>
                                        <td>1.00</td>
                                        <td><span class="highlight">100.00</td>
                                        <td><span class="highlight">0.00</td>
                                        <td><span class="highlight">0.00</td>

                                        <input type="hidden" name="price_96" value="100.00">
                                        <input type="hidden" name="tax_96" value="0.00">
                                        <input type="hidden" name="duty_96" value="0.00">


                                    </tr>
                                    <tr>
                                            <td colspan="9" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                                    </tr>


                            <tr>
                                <td colspan="2">&nbsp;</td>
                                <td>Shipping</td>
                                <td>1.00</td>
                                <td></td>
                                <td></td>
                                <td>

                                            <input type="hidden" size="5" name="shipping" value="30.00">
                                            <input type="hidden" size="5" name="diff_shipping" value="-29">
                                            <span class="highlight">


                                        30.00
                                </td>
                                <td></td>
                                <td></td>
                                </tr>
                                <tr>
                                        <td colspan="9" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                                </tr>
                                <tr>
                                    <td class="blank"><img src="/images/blank.gif" width="1" height="24"></td>
                                    <td class="blank" colspan="7" align="right"><b>Current Total:</td>
                                    <td class="blank" align="right"><b>4.00&nbsp;GBP</b></td>
                                </tr>
                                <tr>
                                    <td colspan="9" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                                </tr>
                                <tr>
                                    <td class="blank"><img src="/images/blank.gif" width="1" height="24"></td>
                                    <td class="blank" colspan="7" align="right"><b>New Total:</td>
                                    <td class="blank" align="right"><b>130.00&nbsp;GBP</b></td>
                                </tr>
                                <tr>
                                        <td colspan="9" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                                </tr>
                                <tr>
                                    <td class="blank"><img src="/images/blank.gif" width="1" height="24"></td>
                                    <td class="blank" colspan="7" align="right"><b>Difference:</td>
                                    <td class="blank" align="right"><b>126.00&nbsp;GBP</b></td>
                                </tr>
                                <tr>
                                        <td colspan="9" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                                </tr>


                                    <tr>
                                        <td class="blank" colspan="2"><img src="/images/blank.gif" width="1" height="24"></td>
                                        <td class="blank"></td>
                                        <td class="blank"></td>
                                        <td class="blank"></td>
                                        <td class="blank" align="right"><b>Type:</td>
                                        <td class="blank" colspan="3"><b>

                                                &nbsp;&nbsp;Card Debit <input type="hidden" name="refund_type" value="3">

                                        </td>
                                    </tr>
                                    <tr>
                                            <td colspan="9" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
                                    </tr>

                        </table>
                        <br><br>



                            <input type="hidden" name="email_content_type" value="text">

                            <span class="title title-NAP">Customer Email</span><br>

                            <table id="table__customer_email" width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                                <tr>
                                    <td colspan="2" class="divider"></td>
                                </tr>
                                <tr height="24">
                                    <td width="149" align="right"><b>Send Email:</b>&nbsp;&nbsp;</td>
                                    <td width="570"><input type="radio" name="send_email" value="yes" checked>&nbsp;&nbsp;Yes&nbsp;&nbsp;&nbsp;&nbsp;<input type="radio" name="send_email" value="no">&nbsp;&nbsp;No</td>
                                </tr>
                                <tr>
                                    <td colspan="2" class="divider"></td>
                                </tr>
                                <tr height="30">
                                    <td align="right"><b>To:</b>&nbsp;&nbsp;</td>
                                    <td><input type="text" size="35" name="email_to" value="test.suite@xtracker"></td>
                                </tr>
                                <tr>
                                    <td colspan="2" class="divider"></td>
                                </tr>
                                <tr height="30">
                                    <td align="right"><b>From:</b>&nbsp;&nbsp;</td>
                                    <td><input type="text" size="35" name="email_from" value="customercare@net-a-porter.com"></td>
                                </tr>
                                <tr>
                                    <td colspan="2" class="divider"></td>
                                </tr>
                                <tr height="30">
                                    <td align="right"><b>Reply-To:</b>&nbsp;&nbsp;</td>
                                    <td><input type="text" size="35" name="email_replyto" value="customercare@net-a-porter.com"></td>
                                </tr>
                                <tr>
                                    <td colspan="2" class="divider"></td>
                                </tr>
                                <tr height="30">
                                    <td align="right"><b>Subject:</b>&nbsp;&nbsp;</td>
                                    <td><input type="text" size="35" name="email_subject" value="Your order - 1000000159"></td>
                                </tr>
                                <tr>
                                    <td colspan="2" class="divider"></td>
                                </tr>
                                <tr>
                                    <td colspan="2" height="10"></td>
                                </tr>
                                <tr valign="top">
                                    <td align="right"><b>Email Text:&nbsp;&nbsp;</b></td>
                                    <td><textarea name="email_body" rows="15" cols="80">Test Content</textarea></td>
                                </tr>
                                <tr>
                                    <td colspan="2" height="10"></td>
                                </tr>
                                <tr>
                                    <td colspan="2" class="divider"></td>
                                </tr>
                            </table>
                            <br><br>






            <br /><br />
            <table width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                    <td align="right">

                        <input type="submit" name="submit" class="button" value="Confirm Changes &raquo;">


                    </td>
                </tr>
            </table>
            </form>







        </div>
    </div>

    <p id="footer">    xTracker-DC  (2013.03.01.171.gc56d68a / IWS phase 2 / PRL phase 0 / 2013-04-02 16:17:49). &copy; 2006 - 2013 NET-A-PORTER
</p>


</div>

    </body>
</html>

