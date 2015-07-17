#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

CustomerCare_CancelItem.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /CustomerCare/CustomerSearch/CancelShipmentItem

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/CustomerCare/CustomerSearch/CancelShipmentItem?orders_id=2&shipment_id=1',
    expected   => {
        cancel_item_form => {
            action => '/CustomerCare/OrderSearch/CancelShipmentItem?orders_id=2&shipment_id=1',
            hidden_input => {
                name => 'select_item',
                value => '1'
            },
            method => 'post',
            name => 'cancelForm',
            select_items => [
                {
                    PID => '3-863',
                    name => 'Name',
                    reason_for_cancellation => [
                        {
                            group => undef,
                            name => 'Please select...',
                            value => 0
                        },
                        {
                            group => undef,
                            name => '----------------------------',
                            value => 0
                        },
                        {
                            value => '27',
                            name => 'Accidentally ordered twice',
                            group => undef,
                        },
                        {
                            value => '33',
                            name => 'Cancelled Exchange',
                            group => undef,
                        },
                        {
                            value => '32',
                            name => 'Card Blocked',
                            group => undef,
                        },
                        {
                            value => '19',
                            name => 'Customer changes mind',
                            group => undef,
                        },
                        {
                            value => '25',
                            name => 'Customer found the item somewhere else cheaper',
                            group => undef,
                        },
                        {
                            value => '23',
                            name => 'Customer never replied to email sent from Finance',
                            group => undef,
                        },
                        {
                            value => '21',
                            name => 'Did not accept the shipping DDU terms and conditions',
                            group => undef,
                        },
                        {
                            value => '22',
                            name => 'Fraud',
                            group => undef,
                        },
                        {
                            value => '38',
                            name => 'Multiple Item Policy',
                            group => undef,
                        },
                        {
                            value => '29',
                            name => 'Ordered twice because did not receive an order confirmation',
                            group => undef,
                        },
                        {
                            value => '44',
                            name => 'Order placed on wrong site',
                            group => undef,
                        },
                        {
                            value => '30',
                            name => 'Other',
                            group => undef,
                        },
                        {
                            value => '35',
                            name => 'Security Check Procedures',
                            group => undef,
                        },
                        {
                            value => '24',
                            name => 'Send order with unacceptable delay',
                            group => undef,
                        },
                        {
                            value => '37',
                            name => 'Shipment Containing Restricted Products',
                            group => undef,
                        },
                        {
                            value => '31',
                            name => 'Size Change',
                            group => undef,
                        },
                        {
                            value => '20',
                            name => 'Too expensive when converting pound to another currency',
                            group => undef,
                        },
                        {
                            value => '26',
                            name => 'Variable price is not explained on the site as it should',
                            group => undef,
                        },
                        {
                            value => '28',
                            name => 'Wants to place new order with new details',
                            group => undef,
                        },
                        {
                            value => '78',
                            name => 'Short pick (Item not in location)',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '79',
                            name => 'Faulty, last unit in stock',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '80',
                            name => 'Wrong item or size (mislabelled), last unit in stock',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '81',
                            name => 'Missing after pick',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '82',
                            name => 'System error',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '83',
                            name => 'Stock adjustment error',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '84',
                            name => 'Tote missing In process',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '85',
                            name => 'Oversell',
                            group => 'Stock Discrepancy',
                        },
                    ],
                    select_item => {
                        checked => '',
                        name => 'item-3',
                        value => '1'
                    }
                },
                {
                    PID => '2-863',
                    name => 'Name',
                    reason_for_cancellation => [
                        {
                            group => undef,
                            name => 'Please select...',
                            value => 0
                        },
                        {
                            group => undef,
                            name => '----------------------------',
                            value => 0
                        },
                        {
                            value => '27',
                            name => 'Accidentally ordered twice',
                            group => undef,
                        },
                        {
                            value => '33',
                            name => 'Cancelled Exchange',
                            group => undef,
                        },
                        {
                            value => '32',
                            name => 'Card Blocked',
                            group => undef,
                        },
                        {
                            value => '19',
                            name => 'Customer changes mind',
                            group => undef,
                        },
                        {
                            value => '25',
                            name => 'Customer found the item somewhere else cheaper',
                            group => undef,
                        },
                        {
                            value => '23',
                            name => 'Customer never replied to email sent from Finance',
                            group => undef,
                        },
                        {
                            value => '21',
                            name => 'Did not accept the shipping DDU terms and conditions',
                            group => undef,
                        },
                        {
                            value => '22',
                            name => 'Fraud',
                            group => undef,
                        },
                        {
                            value => '38',
                            name => 'Multiple Item Policy',
                            group => undef,
                        },
                        {
                            value => '29',
                            name => 'Ordered twice because did not receive an order confirmation',
                            group => undef,
                        },
                        {
                            value => '44',
                            name => 'Order placed on wrong site',
                            group => undef,
                        },
                        {
                            value => '30',
                            name => 'Other',
                            group => undef,
                        },
                        {
                            value => '35',
                            name => 'Security Check Procedures',
                            group => undef,
                        },
                        {
                            value => '24',
                            name => 'Send order with unacceptable delay',
                            group => undef,
                        },
                        {
                            value => '37',
                            name => 'Shipment Containing Restricted Products',
                            group => undef,
                        },
                        {
                            value => '31',
                            name => 'Size Change',
                            group => undef,
                        },
                        {
                            value => '20',
                            name => 'Too expensive when converting pound to another currency',
                            group => undef,
                        },
                        {
                            value => '26',
                            name => 'Variable price is not explained on the site as it should',
                            group => undef,
                        },
                        {
                            value => '28',
                            name => 'Wants to place new order with new details',
                            group => undef,
                        },
                        {
                            value => '78',
                            name => 'Short pick (Item not in location)',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '79',
                            name => 'Faulty, last unit in stock',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '80',
                            name => 'Wrong item or size (mislabelled), last unit in stock',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '81',
                            name => 'Missing after pick',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '82',
                            name => 'System error',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '83',
                            name => 'Stock adjustment error',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '84',
                            name => 'Tote missing In process',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '85',
                            name => 'Oversell',
                            group => 'Stock Discrepancy',
                        },
                    ],
                    select_item => {
                        checked => '',
                        name => 'item-2',
                        value => '1'
                    }
                },
                {
                    PID => '4-863',
                    name => 'Name',
                    reason_for_cancellation => [
                        {
                            group => undef,
                            name => 'Please select...',
                            value => 0
                        },
                        {
                            group => undef,
                            name => '----------------------------',
                            value => 0
                        },
                        {
                            value => '27',
                            name => 'Accidentally ordered twice',
                            group => undef,
                        },
                        {
                            value => '33',
                            name => 'Cancelled Exchange',
                            group => undef,
                        },
                        {
                            value => '32',
                            name => 'Card Blocked',
                            group => undef,
                        },
                        {
                            value => '19',
                            name => 'Customer changes mind',
                            group => undef,
                        },
                        {
                            value => '25',
                            name => 'Customer found the item somewhere else cheaper',
                            group => undef,
                        },
                        {
                            value => '23',
                            name => 'Customer never replied to email sent from Finance',
                            group => undef,
                        },
                        {
                            value => '21',
                            name => 'Did not accept the shipping DDU terms and conditions',
                            group => undef,
                        },
                        {
                            value => '22',
                            name => 'Fraud',
                            group => undef,
                        },
                        {
                            value => '38',
                            name => 'Multiple Item Policy',
                            group => undef,
                        },
                        {
                            value => '29',
                            name => 'Ordered twice because did not receive an order confirmation',
                            group => undef,
                        },
                        {
                            value => '44',
                            name => 'Order placed on wrong site',
                            group => undef,
                        },
                        {
                            value => '30',
                            name => 'Other',
                            group => undef,
                        },
                        {
                            value => '35',
                            name => 'Security Check Procedures',
                            group => undef,
                        },
                        {
                            value => '24',
                            name => 'Send order with unacceptable delay',
                            group => undef,
                        },
                        {
                            value => '37',
                            name => 'Shipment Containing Restricted Products',
                            group => undef,
                        },
                        {
                            value => '31',
                            name => 'Size Change',
                            group => undef,
                        },
                        {
                            value => '20',
                            name => 'Too expensive when converting pound to another currency',
                            group => undef,
                        },
                        {
                            value => '26',
                            name => 'Variable price is not explained on the site as it should',
                            group => undef,
                        },
                        {
                            value => '28',
                            name => 'Wants to place new order with new details',
                            group => undef,
                        },
                        {
                            value => '78',
                            name => 'Short pick (Item not in location)',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '79',
                            name => 'Faulty, last unit in stock',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '80',
                            name => 'Wrong item or size (mislabelled), last unit in stock',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '81',
                            name => 'Missing after pick',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '82',
                            name => 'System error',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '83',
                            name => 'Stock adjustment error',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '84',
                            name => 'Tote missing In process',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '85',
                            name => 'Oversell',
                            group => 'Stock Discrepancy',
                        },
                    ],
                    select_item => {
                        checked => '',
                        name => 'item-4',
                        value => '1'
                    }
                },
                {
                    PID => '1-863',
                    name => 'Name',
                    reason_for_cancellation => [
                        {
                            group => undef,
                            name => 'Please select...',
                            value => 0
                        },
                        {
                            group => undef,
                            name => '----------------------------',
                            value => 0
                        },
                        {
                            value => '27',
                            name => 'Accidentally ordered twice',
                            group => undef,
                        },
                        {
                            value => '33',
                            name => 'Cancelled Exchange',
                            group => undef,
                        },
                        {
                            value => '32',
                            name => 'Card Blocked',
                            group => undef,
                        },
                        {
                            value => '19',
                            name => 'Customer changes mind',
                            group => undef,
                        },
                        {
                            value => '25',
                            name => 'Customer found the item somewhere else cheaper',
                            group => undef,
                        },
                        {
                            value => '23',
                            name => 'Customer never replied to email sent from Finance',
                            group => undef,
                        },
                        {
                            value => '21',
                            name => 'Did not accept the shipping DDU terms and conditions',
                            group => undef,
                        },
                        {
                            value => '22',
                            name => 'Fraud',
                            group => undef,
                        },
                        {
                            value => '38',
                            name => 'Multiple Item Policy',
                            group => undef,
                        },
                        {
                            value => '29',
                            name => 'Ordered twice because did not receive an order confirmation',
                            group => undef,
                        },
                        {
                            value => '44',
                            name => 'Order placed on wrong site',
                            group => undef,
                        },
                        {
                            value => '30',
                            name => 'Other',
                            group => undef,
                        },
                        {
                            value => '35',
                            name => 'Security Check Procedures',
                            group => undef,
                        },
                        {
                            value => '24',
                            name => 'Send order with unacceptable delay',
                            group => undef,
                        },
                        {
                            value => '37',
                            name => 'Shipment Containing Restricted Products',
                            group => undef,
                        },
                        {
                            value => '31',
                            name => 'Size Change',
                            group => undef,
                        },
                        {
                            value => '20',
                            name => 'Too expensive when converting pound to another currency',
                            group => undef,
                        },
                        {
                            value => '26',
                            name => 'Variable price is not explained on the site as it should',
                            group => undef,
                        },
                        {
                            value => '28',
                            name => 'Wants to place new order with new details',
                            group => undef,
                        },
                        {
                            value => '78',
                            name => 'Short pick (Item not in location)',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '79',
                            name => 'Faulty, last unit in stock',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '80',
                            name => 'Wrong item or size (mislabelled), last unit in stock',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '81',
                            name => 'Missing after pick',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '82',
                            name => 'System error',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '83',
                            name => 'Stock adjustment error',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '84',
                            name => 'Tote missing In process',
                            group => 'Stock Discrepancy',
                        },
                        {
                            value => '85',
                            name => 'Oversell',
                            group => 'Stock Discrepancy',
                        },
                    ],
                    select_item => {
                        checked => '',
                        name => 'item-1',
                        value => '1'
                    }
                },
            ]
        }
    }
);

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en">
    <head>
        <meta http-equiv="Content-type" content="text/html; charset=utf-8">

        <title>Customer Search &#8226; Customer Care &#8226; XT-DC1</title>


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















                <form class="quick_search" name="quick_search" action="/QuickSearch">

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



                </form>


                <span class="operator_name">Logged in as: Andrew Benson</span>

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




                        <li class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Admin</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="/Admin/EmailTemplates" class="yuimenuitemlabel">Email Templates</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/UserAdmin" class="yuimenuitemlabel">User Admin</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/FraudRules" class="yuimenuitemlabel">Fraud Rules</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/ExchangeRates" class="yuimenuitemlabel">Exchange Rates</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/JobQueue" class="yuimenuitemlabel">Job Queue</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/StickyPages" class="yuimenuitemlabel">Sticky Pages</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/SystemParameters" class="yuimenuitemlabel">System Parameters</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/ACLMainNavInfo" class="yuimenuitemlabel">ACL Main Nav Info</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/ACLAdmin" class="yuimenuitemlabel">ACL Admin</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/ShippingConfig" class="yuimenuitemlabel">Shipping Config</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/TruckDepartures" class="yuimenuitemlabel">Truck Departures</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/PackingBoxAdmin" class="yuimenuitemlabel">Packing Box Admin</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/CarrierAutomation" class="yuimenuitemlabel">Carrier Automation</a>
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

                                            <li class="menuitem">
                                                <a href="/CustomerCare/CustomerCategory" class="yuimenuitemlabel">Customer Category</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/CustomerCare/OrderSearchbyDesigner" class="yuimenuitemlabel">Order Search by Designer</a>
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
                                                <a href="/Finance/FraudRules" class="yuimenuitemlabel">Fraud Rules</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Finance/FraudHotlist" class="yuimenuitemlabel">Fraud Hotlist</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Finance/Reimbursements" class="yuimenuitemlabel">Reimbursements</a>
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

                                            <li class="menuitem">
                                                <a href="/Fulfilment/PackingException" class="yuimenuitemlabel">Packing Exception</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/Commissioner" class="yuimenuitemlabel">Commissioner</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/PremierDispatch" class="yuimenuitemlabel">Premier Dispatch</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/PackLaneActivity" class="yuimenuitemlabel">Pack Lane Activity</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Fulfilment/FulfilmentOverview" class="yuimenuitemlabel">Fulfilment Overview</a>
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
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">NAP Events</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="/NAPEvents/WelcomePacks" class="yuimenuitemlabel">Welcome Packs</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/NAPEvents/Manage" class="yuimenuitemlabel">Manage</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/NAPEvents/InTheBox" class="yuimenuitemlabel">In The Box</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Outnet Events</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="/OutnetEvents/Manage" class="yuimenuitemlabel">Manage</a>
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

                                            <li class="menuitem">
                                                <a href="/Reporting/Migration" class="yuimenuitemlabel">Migration</a>
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
                                                <a href="/StockControl/DutyRates" class="yuimenuitemlabel">Duty Rates</a>
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
                                                <a href="/StockControl/ChannelTransfer" class="yuimenuitemlabel">Channel Transfer</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/Recode" class="yuimenuitemlabel">Recode</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/StockAdjustment" class="yuimenuitemlabel">Stock Adjustment</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/StockControl/SampleAdjustment" class="yuimenuitemlabel">Sample Adjustment</a>
                                            </li>

                                    </ul>
                                </div>
                            </div>
                        </li>

                        <li class="yuimenubaritem yuimenubaritem-hassubmenu">
                            <a href="#" class="yuimenubaritemlabel yuimenubaritemlabel-hassubmenu">Web Content</a>
                            <div class="yuimenu">
                                <div class="bd">
                                    <ul>

                                            <li class="menuitem">
                                                <a href="/WebContent/DesignerLanding" class="yuimenuitemlabel">Designer Landing</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/WebContent/Magazine" class="yuimenuitemlabel">Magazine</a>
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


            <div id="contentLeftCol" >


        <ul>




                                    <li><a href="javascript:history.go(-1)" class="last">Back</a></li>


        </ul>

</div>




            <img id="channelTitle" src="/images/logo_NET-A-PORTER_INTL.gif" alt="NET-A-PORTER.COM">


        <div id="contentRight" >













                    <div id="pageTitle">
                        <h1>Customer Care</h1>
                        <h5>&bull;</h5><h2>Customer Search</h2>
                        <h5>&bull;</h5><h3>Cancel Shipment Item</h3>
                    </div>













<span class="title title-NAP">Select Item(s)</span><br>

<form name="cancelForm" action="/CustomerCare/OrderSearch/CancelShipmentItem?orders_id=2&shipment_id=1" method="post" onSubmit="validate()">

<input type="hidden" name="select_item" value="1">
<table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="cancel_items">
    <tr>
        <td colspan="5" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
    </tr>
    <tr height="24">
        <td width="15%" class="tableHeader">&nbsp;&nbsp;&nbsp;PID</td>
        <td width="15%" class="tableHeader">Name</td>

            <td width="15%" class="tableHeader">Inc.Pick</td>

        <td width="15%" class="tableHeader">Select Item(s)</td>
        <td width="40%" class="tableHeader">Reason for Cancellation</td>
    </tr>
    <tr>
        <td colspan="5" class="dividerHeader"><img src="/images/blank.gif" width="1" height="1"></td>
    </tr>



            <tr height="24" id="3-863">
                <td>&nbsp;&nbsp;&nbsp;<a href="javascript://" onClick="window.open('http://cache.net-a-porter.com/images/products/3/3_in_m.jpg','viewimage','width=230,height=345,scrollbars=no');" class="noline">3-863</a></td>
                <td>Name</td>

                    <td>0</td>

                    <td><input type="checkbox" name="item-3" value="1" onClick="if (this.checked) { checkIP('3-863',0,0);}"></td>

                <td>

    <select id="reason-3" name="reason-3">
        <option value="0">Please select...</option>
        <option value="0">----------------------------</option>


                    <option value="27">Accidentally ordered twice</option>



                    <option value="33">Cancelled Exchange</option>



                    <option value="32">Card Blocked</option>



                    <option value="19">Customer changes mind</option>



                    <option value="25">Customer found the item somewhere else cheaper</option>



                    <option value="23">Customer never replied to email sent from Finance</option>



                    <option value="21">Did not accept the shipping DDU terms and conditions</option>



                    <option value="22">Fraud</option>



                    <option value="38">Multiple Item Policy</option>



                    <option value="29">Ordered twice because did not receive an order confirmation</option>



                    <option value="44">Order placed on wrong site</option>



                    <option value="30">Other</option>



                    <option value="35">Security Check Procedures</option>



                    <option value="24">Send order with unacceptable delay</option>



                    <option value="37">Shipment Containing Restricted Products</option>



                    <option value="31">Size Change</option>



                    <option value="20">Too expensive when converting pound to another currency</option>



                    <option value="26">Variable price is not explained on the site as it should</option>



                    <option value="28">Wants to place new order with new details</option>



                    <optgroup label="Stock Discrepancy">



                    <option value="78">Short pick (Item not in location)</option>



                    <option value="79">Faulty, last unit in stock</option>



                    <option value="80">Wrong item or size (mislabelled), last unit in stock</option>



                    <option value="81">Missing after pick</option>



                    <option value="82">System error</option>



                    <option value="83">Stock adjustment error</option>



                    <option value="84">Tote missing In process</option>



                    <option value="85">Oversell</option>



                    </optgroup>


    </select>


                </td>
            </tr>

        <tr>
            <td colspan="5" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>


            <tr height="24" id="2-863">
                <td>&nbsp;&nbsp;&nbsp;<a href="javascript://" onClick="window.open('http://cache.net-a-porter.com/images/products/2/2_in_m.jpg','viewimage','width=230,height=345,scrollbars=no');" class="noline">2-863</a></td>
                <td>Name</td>

                    <td>0</td>

                    <td><input type="checkbox" name="item-2" value="1" onClick="if (this.checked) { checkIP('2-863',0,0);}"></td>

                <td>

    <select id="reason-2" name="reason-2">
        <option value="0">Please select...</option>
        <option value="0">----------------------------</option>


                    <option value="27">Accidentally ordered twice</option>



                    <option value="33">Cancelled Exchange</option>



                    <option value="32">Card Blocked</option>



                    <option value="19">Customer changes mind</option>



                    <option value="25">Customer found the item somewhere else cheaper</option>



                    <option value="23">Customer never replied to email sent from Finance</option>



                    <option value="21">Did not accept the shipping DDU terms and conditions</option>



                    <option value="22">Fraud</option>



                    <option value="38">Multiple Item Policy</option>



                    <option value="29">Ordered twice because did not receive an order confirmation</option>



                    <option value="44">Order placed on wrong site</option>



                    <option value="30">Other</option>



                    <option value="35">Security Check Procedures</option>



                    <option value="24">Send order with unacceptable delay</option>



                    <option value="37">Shipment Containing Restricted Products</option>



                    <option value="31">Size Change</option>



                    <option value="20">Too expensive when converting pound to another currency</option>



                    <option value="26">Variable price is not explained on the site as it should</option>



                    <option value="28">Wants to place new order with new details</option>



                    <optgroup label="Stock Discrepancy">



                    <option value="78">Short pick (Item not in location)</option>



                    <option value="79">Faulty, last unit in stock</option>



                    <option value="80">Wrong item or size (mislabelled), last unit in stock</option>



                    <option value="81">Missing after pick</option>



                    <option value="82">System error</option>



                    <option value="83">Stock adjustment error</option>



                    <option value="84">Tote missing In process</option>



                    <option value="85">Oversell</option>



                    </optgroup>


    </select>


                </td>
            </tr>

        <tr>
            <td colspan="5" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>


            <tr height="24" id="4-863">
                <td>&nbsp;&nbsp;&nbsp;<a href="javascript://" onClick="window.open('http://cache.net-a-porter.com/images/products/4/4_in_m.jpg','viewimage','width=230,height=345,scrollbars=no');" class="noline">4-863</a></td>
                <td>Name</td>

                    <td>0</td>

                    <td><input type="checkbox" name="item-4" value="1" onClick="if (this.checked) { checkIP('4-863',0,0);}"></td>

                <td>

    <select id="reason-4" name="reason-4">
        <option value="0">Please select...</option>
        <option value="0">----------------------------</option>


                    <option value="27">Accidentally ordered twice</option>



                    <option value="33">Cancelled Exchange</option>



                    <option value="32">Card Blocked</option>



                    <option value="19">Customer changes mind</option>



                    <option value="25">Customer found the item somewhere else cheaper</option>



                    <option value="23">Customer never replied to email sent from Finance</option>



                    <option value="21">Did not accept the shipping DDU terms and conditions</option>



                    <option value="22">Fraud</option>



                    <option value="38">Multiple Item Policy</option>



                    <option value="29">Ordered twice because did not receive an order confirmation</option>



                    <option value="44">Order placed on wrong site</option>



                    <option value="30">Other</option>



                    <option value="35">Security Check Procedures</option>



                    <option value="24">Send order with unacceptable delay</option>



                    <option value="37">Shipment Containing Restricted Products</option>



                    <option value="31">Size Change</option>



                    <option value="20">Too expensive when converting pound to another currency</option>



                    <option value="26">Variable price is not explained on the site as it should</option>



                    <option value="28">Wants to place new order with new details</option>



                    <optgroup label="Stock Discrepancy">



                    <option value="78">Short pick (Item not in location)</option>



                    <option value="79">Faulty, last unit in stock</option>



                    <option value="80">Wrong item or size (mislabelled), last unit in stock</option>



                    <option value="81">Missing after pick</option>



                    <option value="82">System error</option>



                    <option value="83">Stock adjustment error</option>



                    <option value="84">Tote missing In process</option>



                    <option value="85">Oversell</option>



                    </optgroup>


    </select>


                </td>
            </tr>

        <tr>
            <td colspan="5" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>


            <tr height="24" id="1-863">
                <td>&nbsp;&nbsp;&nbsp;<a href="javascript://" onClick="window.open('http://cache.net-a-porter.com/images/products/1/1_in_m.jpg','viewimage','width=230,height=345,scrollbars=no');" class="noline">1-863</a></td>
                <td>Name</td>

                    <td>0</td>

                    <td><input type="checkbox" name="item-1" value="1" onClick="if (this.checked) { checkIP('1-863',0,0);}"></td>

                <td>

    <select id="reason-1" name="reason-1">
        <option value="0">Please select...</option>
        <option value="0">----------------------------</option>


                    <option value="27">Accidentally ordered twice</option>



                    <option value="33">Cancelled Exchange</option>



                    <option value="32">Card Blocked</option>



                    <option value="19">Customer changes mind</option>



                    <option value="25">Customer found the item somewhere else cheaper</option>



                    <option value="23">Customer never replied to email sent from Finance</option>



                    <option value="21">Did not accept the shipping DDU terms and conditions</option>



                    <option value="22">Fraud</option>



                    <option value="38">Multiple Item Policy</option>



                    <option value="29">Ordered twice because did not receive an order confirmation</option>



                    <option value="44">Order placed on wrong site</option>



                    <option value="30">Other</option>



                    <option value="35">Security Check Procedures</option>



                    <option value="24">Send order with unacceptable delay</option>



                    <option value="37">Shipment Containing Restricted Products</option>



                    <option value="31">Size Change</option>



                    <option value="20">Too expensive when converting pound to another currency</option>



                    <option value="26">Variable price is not explained on the site as it should</option>



                    <option value="28">Wants to place new order with new details</option>



                    <optgroup label="Stock Discrepancy">



                    <option value="78">Short pick (Item not in location)</option>



                    <option value="79">Faulty, last unit in stock</option>



                    <option value="80">Wrong item or size (mislabelled), last unit in stock</option>



                    <option value="81">Missing after pick</option>



                    <option value="82">System error</option>



                    <option value="83">Stock adjustment error</option>



                    <option value="84">Tote missing In process</option>



                    <option value="85">Oversell</option>



                    </optgroup>


    </select>


                </td>
            </tr>

        <tr>
            <td colspan="5" class="divider"><img src="/images/blank.gif" width="1" height="1"></td>
        </tr>




        <input type="hidden" name="refund_type_id" value="0">


    <tr>
        <td class="blank" colspan="5"><img src="/images/blank.gif" width="1" height="20"></td>
    </tr>
    <tr>
        <td class="blank" colspan="5" align="right"><input type="submit" name="submit" class="button" value="Submit &raquo;">
</td>
    </tr>
</table>

</form>

    <script language="Javascript">

        function validate(){

            frmLength = document.cancelForm.length;
            isEmpty = false;

            for (i=0; i<frmLength;i++){
                if(document.cancelForm[i].options) {
                    if (document.cancelForm[i].options[document.cancelForm[i].selectedIndex].value == 0){
                        field_nm = document.cancelForm[i].name;
                        arr = field_nm.split("-");

                        field_nm2 = "item-"+arr[1];

                        if (document.cancelForm["item-"+arr[1]].checked ) {
                            isEmpty = true;  //one element is empty
                        }
                    }
                }
            }

            if(isEmpty){
                alert("Please select the reason for return before submitting.");
                return false;
            }
            else {
                return true;
            }

        }


    // function to check if wrong item is cancelled

    function checkIP( id, ip, quantity ){

        if ($("#display_message").length > 0) {
            $("#display_message").remove();
        }

        if (ip == 1) {
            //check if there is available quantity for this item
            var count = $('table#cancel_items').find('tr[id="'+id+'"]').length;
            var count_checked_ip_items = 0;

            $('table#cancel_items').find('tr[id="'+id+'"]').each(function(i,o){
                var columns = $(o).find('td');

                if (columns[2].innerHTML === '1'){
                    var checkbox = $(columns[3]).find('input')[0];
                    if (checkbox.checked == false ) {
                        count_checked_ip_items++;
                    }
                }
            });
            var available_quantity = quantity - count_checked_ip_items;
            if (available_quantity > 0 ){
                var  message = 'Please note that there is now some available stock for the product previously marked as incomplete pick, so please double check before cancelling.';
                $('<p id="display_message" class="display_msg">'+message+'</p></div>').insertAfter($("#pageTitle"));
            }
        }
        else {

            $('table#cancel_items').find('tr[id="'+id+'"]').each(function(i,o){
                var columns = $(o).find('td');
                var j;

                if (columns[2].innerHTML === '1') {
                    var checkbox = $(columns[3]).find('input')[0];
                    if (checkbox.checked == false ) {
                        alert(' Please note that there is another unit of the same product that has been marked as incomplete pick, and could possibly be the one that should be cancelled instead.');
                    }
                }

            });
        }
    }

    </script>





<br><br><br><br>






        </div>
    </div>

    <p id="footer">    xTracker-DC  (2015.08.02.79.g05b3fb3 / IWS phase 2 / PRL phase 0 / ). &copy; 2006 - 2015 NET-A-PORTER
</p>


</div>

    <script type="text/javascript" charset="utf-8">
    // When jQuery is sourced, it's going to overwrite whatever might be in the
    // '$' variable, so store a reference of it in a temporary variable...
    var _$ = window.$;
    if (typeof jQuery == 'undefined') {
        var jquery_url = '/debug_toolbar/jquery.js';
        document.write(unescape('%3Cscript src="' + jquery_url + '" type="text/javascript"%3E%3C/script%3E'));
    }
</script>
<script type="text/javascript" src="/debug_toolbar/toolbar.min.js"></script>
<script type="text/javascript" charset="utf-8">
    // Now that jQuery is done loading, put the '$' variable back to what it was...
    var $ = _$;
</script>
<style type="text/css">
    @import url(/debug_toolbar/toolbar.min.css);
</style>
</body>
</html>
