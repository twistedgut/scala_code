#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

GoodsIn_ReturnsIn_QC.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for Spec:

    GoodsIn/ReturnsQC/ProcessItem

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    spec       => 'GoodsIn/ReturnsQC/ProcessItem',
    expected   => {
        qc_results => [
            {
                Decision => {
                    input_name => 'qc_1229137',
                    input_value => 'pass',
                    value => 'Pass Fail'
                },
                Item => '',
                LargeLabels => {
                    input_name => 'large-1229137',
                    input_value => '1',
                    value => ''
                },
                Location => '011A001A',
                'Return Reason' => 'Just unsuitable',
                SmallLabels => {
                    input_name => 'small-1229137',
                    input_value => '0',
                    value => ''
                },
                'Storage Type' => '',
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

        <title>Returns QC &#8226; Goods In &#8226; XT-DC1</title>


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
        <script type="text/javascript" src="/jquery/jquery-1.7.min.js"></script>
        <script type="text/javascript" src="/jquery-ui/js/jquery-ui.custom.min.js"></script>
        <!-- common jQuery date picker plugin -->
        <script type="text/javascript" src="/jquery/plugin/datepicker/date.js"></script>
        <script type="text/javascript" src="/javascript/datepicker.js"></script>

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
                <span class="operator_name">DISABLED: IT God</span>
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



                                <li class="yuimenubaritem"><a href="/Fulfilment/Airwaybill" class="yuimenubaritemlabel">Airwaybill</a></li>

                                <li class="yuimenubaritem"><a href="/Fulfilment/Dispatch" class="yuimenubaritemlabel">Dispatch</a></li>

                                <li class="yuimenubaritem"><a href="/Fulfilment/Packing" class="yuimenubaritemlabel">Packing</a></li>

                                <li class="yuimenubaritem"><a href="/Fulfilment/Picking" class="yuimenubaritemlabel">Picking</a></li>

                                <li class="yuimenubaritem"><a href="/Fulfilment/Selection" class="yuimenubaritemlabel">Selection</a></li>



                                <li class="yuimenubaritem"><a href="/GoodsIn/ReturnsIn" class="yuimenubaritemlabel">Returns In</a></li>

                                <li class="yuimenubaritem"><a href="/GoodsIn/ReturnsQC" class="yuimenubaritemlabel">Returns QC</a></li>



            </ul>
        </div>

</div>

</div>


    <div id="content">

        <div id="contentLeftCol">


        <ul>





                    <li><a href="/GoodsIn/ReturnsQC">Back</a></li>

                    <li><a href="/GoodsIn/ReturnsQC/Note?parent_id=50&note_category=Return&sub_id=6">Add Note</a></li>

                    <li><a href="/GoodsIn/ReturnsQC/OrderView?order_id=50" class="last">Order Summary</a></li>


        </ul>

</div>



            <img id="channelTitle" src="/images/logo_NET-A-PORTER_INTL.gif" alt="NET-A-PORTER.COM">


        <div id="contentRight">












                    <div id="pageTitle">
                        <h1>Goods In</h1>
                        <h5>&bull;</h5><h2>Returns QC</h2>
                        <h5>&bull;</h5><h3>Process Return</h3>
                    </div>









    <form name="qcForm" action="/GoodsIn/ReturnsQC/SetReturnQC" method="POST" onSubmit="return validateForm(this)">
        <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="228%3ANJ3CpDYl7QsVvANL1Qro1w">

        <input type="hidden" name="delivery_id" value="3">
        <input type="hidden" name="return_id" value="6">
        <input type="hidden" name="decision" value="1">
    <h3 class="title title-NAP">Return Details</h3>
    <table width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            <td><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr>
            <td width="15%" align="right"><strong>RMA Number:</strong>&nbsp;&nbsp;</td>
            <td width="30%">&nbsp;R25-3</td>
            <td width="10%"><img src="/images/blank.gif" width="1" height="24"></td>

                <td width="15%" align="right"><strong>Order Number:</strong>&nbsp;&nbsp;</td>
                <td width="30%">&nbsp;1000000049</td>

        </tr>
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            <td><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr height="22">
            <td align="right"><strong>Date Created:</strong>&nbsp;&nbsp;</td>
            <td>&nbsp;30-07-2012  17:41</td>
            <td><img src="/images/blank.gif" width="1" height="24"></td>
            <td align="right"><strong>Shipment Number:</strong>&nbsp;&nbsp;</td>
            <td>&nbsp;25</td>
        </tr>
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            <td><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
        <tr height="22">
            <td align="right"><strong>Status:</strong>&nbsp;&nbsp;</td>
            <td>&nbsp;<span class="highlight">Processing</span></td>
            <td><img src="/images/blank.gif" width="1" height="24"></td>
            <td align="right"><strong>Comments:</strong>&nbsp;&nbsp;</td>
            <td>&nbsp;</td>
        </tr>
        <tr>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
            <td><img src="/images/blank.gif" width="1" height="1"></td>
            <td colspan="2" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>
    </table>





    <br/><br/>

    <h3 class="title title-NAP">Return Items</h3>
    <table class="wide-data divided-data data" id="return_items">
        <thead>
            <tr>
                <th>Item</th>
                <th>&nbsp;</th>
                <th>Return Reason</th>
                <th>Storage Type</th>
                <th>Location</th>
                <th>Decision</th>
                <th>Large<br />Labels</th>
                <th>Small<br />Labels</th>
            </tr>
        </thead>
        <tbody>
        <tr valign="top" id="stock_process_1229137">
            <td><br/><img src="http://cache.net-a-porter.com/images/products/13/13_in_m.jpg" width="120" hspace="5" vspace="5"></td>
            <td>
                <br/>
                <strong>13-863</strong><br/>
                (13-863)<br/>
                <br/>
                <strong>SIZE:</strong> None/Unknown<br/>
                <br/>
                <strong>République ✪ Ceccarelli</strong><br/>
                Long Description<br/>
                <br/>

            </td>
            <td><br/>Just unsuitable</td>
            <td><br/></td>

            <td><br/>

                    011A001A<br />


            </td>



                    <td><br/><input type="radio" name="qc_1229137" value="pass">&nbsp;Pass&nbsp;&nbsp;&nbsp;<input type="radio" name="qc_1229137" value="fail">&nbsp;Fail</td>
                    <td><br/><input type="text" name="large-1229137" size="2" value="1"></td>
                    <td><br/><input type="text" name="small-1229137" size="2" value="0"></td>




        </tr>

    </tbody>
    </table>
        <div class="formrow buttons aftertable">
            <input type="submit" name="submit" value="Submit &raquo;" class="button">
        </div>
    </form>
    <br/><br/><br/><br/>

    <script type="text/javascript" language="javascript">
        <!--

        function validateForm(form){

            var error = 0;




                        var radio_error = 1;

                        for (var i=0; i < form.qc_3.length; i++){
                            if (form.qc_3[i].checked){
                                radio_error = 0;
                            }
                        }

                        if (radio_error == 1){
                            error = 1;
                        }






            if( error == 1 ) {
                alert("Please select Pass or Fail for each item before submitting.");
                return false;
            }
            else {
                return double_submit();
            }

        }


        //-->
        </script>







        </div>
    </div>

    <p id="footer">    xTracker-DC  (2012.11.xx.whm.05.5.geabde52 / IWS phase 2 / PRL phase 0 / 2012-07-30 15:59:16). &copy; 2006 - 2012 NET-A-PORTER
</p>


</div>

    </body>
</html>
