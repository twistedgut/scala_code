#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

StockControl_ProductSearch_Reservation.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /StockControl/Reservation/Product

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/StockControl/Reservation/Product',

    expected   => {
          highlighted_customers => {
              'is_customer_number-22' => [
                { value => '1' },
                { value => '4e444f6 e3' },
                { value => '300786815' },
                { value => '' },
                {
                    span => {
                        title => 'Customer Category: EIP Premium'
                    },
                    value => 'Sarabjit Kaur'
                },
                { value => '' },
                { value => '10-05' },
                { value => '' },
                { value => '' },
                { value => 'Pending' },
                { value => '' },
                { value => 'Edit' },
                { value => 'Delete' },
            ],
              'is_customer_number-23' => [
                { value => '1' },
                { value => '4e444f6 e3' },
                { value => '300786815' },
                { value => '' },
                { value => 'Sarabjit Kaur' },
                { value => '' },
                { value => '10-05' },
                { value => '' },
                { value => '' },
                { value => 'Pending' },
                { value => '' },
                { value => 'Edit' },
                { value => 'Delete' },
            ],
          },
          reservation_list => {
            'NET-A-PORTER.COM' => {
              reservation => {
                '34553' => {
                  variant => [
                    {
                      'Designer Size' => '38',
                      'NAP Size' => 'xx small',
                      Ordered => '3',
                      Reservations => '0',
                      SKU => '10456-010',
                      'Stock on hand' => '100',
                      'Upload Date' => ''
                    }
                  ]
                },
                '34554' => {
                  variant => [
                    {
                      'Designer Size' => '40',
                      'NAP Size' => 'x small',
                      Ordered => '4',
                      Reservations => '0',
                      SKU => '10456-011',
                      'Stock on hand' => '0',
                      'Upload Date' => ''
                    }
                  ]
                },
                '34555' => {
                  variant => [
                    {
                      'Designer Size' => '42',
                      'NAP Size' => 'small',
                      Ordered => '4',
                      Reservations => '0',
                      SKU => '10456-012',
                      'Stock on hand' => '0',
                      'Upload Date' => ''
                    }
                  ]
                },
                '34556' => {
                  variant => [
                    {
                      'Designer Size' => '44',
                      'NAP Size' => 'medium',
                      Ordered => '3',
                      Reservations => '0',
                      SKU => '10456-013',
                      'Stock on hand' => '0',
                      'Upload Date' => ''
                    }
                  ]
                },
                '34557' => {
                  variant => [
                    {
                      'Designer Size' => '46',
                      'NAP Size' => 'large',
                      Ordered => '2',
                      Reservations => '0',
                      SKU => '10456-014',
                      'Stock on hand' => '0',
                      'Upload Date' => ''
                    }
                  ]
                },
                '34558' => {
                  variant => [
                    {
                      'Designer Size' => '48',
                      'NAP Size' => 'x large',
                      Ordered => '1',
                      Reservations => '0',
                      SKU => '10456-015',
                      'Stock on hand' => '0',
                      'Upload Date' => ''
                    }
                  ]
                }
              }
            },
            'THEOUTNET.COM' => {
              preorder => {
                '34553' => {
                  customers => [
                    {
                      ''      => '',
                      Created => '10-05-12',
                      Customer => 'michael martins',
                      'No.' => {
                        url => '/StockControl/Reservation/Customer?customer_id=560176',
                        value => '500108649'
                      },
                      Operator => 'Sarabjit Kaur',
                      Status => 'Incomplete'
                    }
                  ],
                  variant => [
                    {
                      ''              => '',
                      'Designer Size' => '38',
                      'NAP Size' => 'xx small',
                      'Ordered Qty' => '0',
                      'Pre Ordered Qty' => '1',
                      Reservations => '0',
                      SKU => '10456-010'
                    }
                  ]
                },
                '34554' => {
                  customers => [
                    {
                      ''      => '',
                      Created => '10-05-12',
                      Customer => 'michael martins',
                      'No.' => {
                        url => '/StockControl/Reservation/Customer?customer_id=560176',
                        value => '500108649'
                      },
                      Operator => 'Sarabjit Kaur',
                      Status => 'Incomplete'
                    }
                  ],
                  variant => [
                    {
                      ''              => '',
                      'Designer Size' => '40',
                      'NAP Size' => 'x small',
                      'Ordered Qty' => '0',
                      'Pre Ordered Qty' => '1',
                      Reservations => '0',
                      SKU => '10456-011'
                    }
                  ]
                },
                '34555' => {
                  customers => [
                    {
                      ''      => '',
                      Created => '10-05-12',
                      Customer => 'michael martins',
                      'No.' => {
                        url => '/StockControl/Reservation/Customer?customer_id=560176',
                        value => '500108649'
                      },
                      Operator => 'Sarabjit Kaur',
                      Status => 'Incomplete'
                    }
                  ],
                  variant => [
                    {
                      ''              => '',
                      'Designer Size' => '42',
                      'NAP Size' => 'small',
                      'Ordered Qty' => '0',
                      'Pre Ordered Qty' => '1',
                      Reservations => '0',
                      SKU => '10456-012'
                    }
                  ]
                }
              },
              reservation => {
                '34553' => {
                  customers => [
                     {
                        '' => {
                           url => 'javascript:deleteSubmit(\'updateForm373993\')',
                           value => 'Delete'
                        },
                      Created => '10-05',
                      Customer => '4e444f6 e3',
                      Expires => '',
                      'No.' => '300786815',
                      Operator => 'Sarabjit Kaur',
                      Source => '',
                      Status => 'Pending',
                      Uploaded => ''
                    }
                  ],
                  variant => [
                    {
                      'Designer Size' => '38',
                      'NAP Size' => 'xx small',
                      Ordered => '0',
                      Reservations => '0',
                      SKU => '10456-010',
                      'Stock on hand' => '0',
                      'Upload Date' => ''
                    }
                  ]
                },
                '34554' => {
                  customers => [
                    {
                      '' => {
                        url => 'javascript:deleteSubmit(\'updateForm373994\')',
                         value => 'Delete'
                      },
                      Created => '10-05',
                      Customer => '4e444f6 e3',
                      Expires => '',
                      'No.' => '300786815',
                      Operator => 'Sarabjit Kaur',
                      Source => '',
                      Status => 'Pending',
                      Uploaded => ''
                    }
                  ],
                  variant => [
                    {
                      'Designer Size' => '40',
                      'NAP Size' => 'x small',
                      Ordered => '0',
                      Reservations => '0',
                      SKU => '10456-011',
                      'Stock on hand' => '0',
                      'Upload Date' => ''
                    }
                  ]
                },
                '34555' => {
                  customers => [
                    {
                      '' => {
                        url => 'javascript:deleteSubmit(\'updateForm373995\')',
                        value => 'Delete'
                      },
                      Created => '10-05',
                      Customer => '4e444f6 e3',
                      Expires => '',
                      'No.' => '300786815',
                      Operator => 'Sarabjit Kaur',
                      Source => '',
                      Status => 'Pending',
                      Uploaded => ''
                    }
                  ],
                  variant => [
                    {
                      'Designer Size' => '42',
                      'NAP Size' => 'small',
                      Ordered => '0',
                      Reservations => '0',
                      SKU => '10456-012',
                      'Stock on hand' => '0',
                      'Upload Date' => ''
                    }
                  ]
                },
                '34556' => {
                  customers => [
                    {
                      '' => {
                        url => 'javascript:deleteSubmit(\'updateForm373996\')',
                        value => 'Delete'
                      },
                      Created => '10-05',
                      Customer => '4e444f6 e3',
                      Expires => '',
                      'No.' => '300786815',
                      Operator => 'Sarabjit Kaur',
                      Source => '',
                      Status => 'Pending',
                      Uploaded => ''
                    }
                  ],
                  variant => [
                    {
                      'Designer Size' => '44',
                      'NAP Size' => 'medium',
                      Ordered => '0',
                      Reservations => '0',
                      SKU => '10456-013',
                      'Stock on hand' => '0',
                      'Upload Date' => ''
                    }
                  ]
                },
                '34557' => {
                  customers => [
                    {
                      '' => {
                        url => 'javascript:deleteSubmit(\'updateForm373997\')',
                        value => 'Delete',
                      },
                      Created => '10-05',
                      Customer => '4e444f6 e3',
                      Expires => '',
                      'No.' => '300786815',
                      Operator => 'Sarabjit Kaur',
                      Source => '',
                      Status => 'Pending',
                      Uploaded => ''
                    }
                  ],
                  variant => [
                    {
                      'Designer Size' => '46',
                      'NAP Size' => 'large',
                      Ordered => '0',
                      Reservations => '0',
                      SKU => '10456-014',
                      'Stock on hand' => '0',
                      'Upload Date' => ''
                    }
                  ]
                },
                '34558' => {
                  customers => [
                    {
                      '' => {
                        url => 'javascript:deleteSubmit(\'updateForm373998\')',
                        value => 'Delete'
                      },
                      Created => '10-05',
                      Customer => '4e444f6 e3',
                      Expires => '',
                      'No.' => '300786815',
                      Operator => 'Sarabjit Kaur',
                      Source => '',
                      Status => 'Pending',
                      Uploaded => ''
                    }
                  ],
                  variant => [
                    {
                      'Designer Size' => '48',
                      'NAP Size' => 'x large',
                      Ordered => '0',
                      Reservations => '0',
                      SKU => '10456-015',
                      'Stock on hand' => '0',
                      'Upload Date' => ''
                    }
                  ]
                }
              }
            }
          }
    }
);

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en">
    <head>
        <meta http-equiv="Content-type" content="text/html; charset=utf-8">

        <title>Reservation &#8226; Stock Control &#8226; XT-DC1</title>


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
        <!-- jQuery CSS -->
        <link rel="stylesheet" type="text/css" href="/jquery-ui/css/smoothness/jquery-ui.custom.css">


            <script type="text/javascript" src="/yui/yahoo-dom-event/yahoo-dom-event.js"></script>

            <script type="text/javascript" src="/yui/element/element-min.js"></script>

            <script type="text/javascript" src="/yui/tabview/tabview-min.js"></script>




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
                <span class="operator_name">Sarabjit Kaur</span>
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
                                                <a href="/Admin/EmailTemplates" class="yuimenuitemlabel">Email Templates</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/UserAdmin" class="yuimenuitemlabel">User Admin</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/ExchangeRates" class="yuimenuitemlabel">Exchange Rates</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/ProductSort" class="yuimenuitemlabel">Product Sort</a>
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
                                                <a href="/NAPEvents/Manage" class="yuimenuitemlabel">Manage</a>
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

        <div id="contentLeftCol">


        <ul>





                    <li><a href="/StockControl/Reservation" class="last">Summary</a></li>




                        <li><span>Overview</span></li>



                    <li><a href="/StockControl/Reservation/Overview?view_type=Upload">Upload</a></li>

                    <li><a href="/StockControl/Reservation/Overview?view_type=Pending">Pending</a></li>

                    <li><a href="/StockControl/Reservation/Overview?view_type=Waiting" class="last">Waiting List</a></li>




                        <li><span>View</span></li>



                    <li><a href="/StockControl/Reservation/Listing?list_type=Live&show=Personal">Live Reservations</a></li>

                    <li><a href="/StockControl/Reservation/Listing?list_type=Pending&show=Personal">Pending Reservations</a></li>

                    <li><a href="/StockControl/Reservation/Listing?list_type=Waiting&show=Personal" class="last">Waiting Lists</a></li>




                        <li><span>Search</span></li>



                    <li><a href="/StockControl/Reservation/Product">Product</a></li>

                    <li><a href="/StockControl/Reservation/Customer" class="last">Customer</a></li>




                        <li><span>Email</span></li>



                    <li><a href="/StockControl/Reservation/Email" class="last">Customer Notification</a></li>




                        <li><span>Reports</span></li>



                    <li><a href="/StockControl/Reservation/Reports/Uploaded/P">Uploaded</a></li>

                    <li><a href="/StockControl/Reservation/Reports/Purchased/P" class="last">Purchased</a></li>


        </ul>

</div>



            <img id="channelTitle" src="/images/logo_THEOUTNET_INTL.gif" alt="THEOUTNET.COM">


        <div id="contentRight">












                    <div id="pageTitle">
                        <h1>Reservation</h1>
                        <h5>&bull;</h5><h2>Product</h2>
                        <h5>&bull;</h5><h3>Search</h3>
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
                &nbsp;&nbsp;&nbsp;<a href="/StockControl/Inventory/Overview?product_id=10456">10456</a>&nbsp;&nbsp;:&nbsp;&nbsp;Narciso Rodriguez - Block-color silk dress
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

                <a href="javascript://" onClick="enlargeImage('http://cache.net-a-porter.com/images/products/10456/10456_in_dl.jpg')"><img class="product" width="120" src="http://cache.net-a-porter.com/images/products/10456/10456_in_m.jpg"></a>
            </td>
            <td class="blank"><img src="/images/blank.gif" width="10" height="1"></td>
            <td class="blank">
                <a href="javascript://" onClick="enlargeImage('http://cache.net-a-porter.com/images/products/10456/10456_bk_dl.jpg')"><img class="product" width="56" src="http://cache.net-a-porter.com/images/products/10456/10456_bk_xs.jpg"></a>
                <br clear="all">
                <a href="javascript://" onClick="enlargeImage('http://cache.net-a-porter.com/images/products/10456/10456_cu_dl.jpg')"><img class="product" width="56" src="http://cache.net-a-porter.com/images/products/10456/10456_cu_xs.jpg" style="margin-top:10px"></a>
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
                                    <td width="65%">A0423 1739</td>
                                    <td></td>
                                </tr>
                                <tr>
                                    <td colspan="3" class="divider"></td>
                                </tr>
                                <tr>
                                    <td align="right"><b>Season:</b>&nbsp;</td>
                                    <td colspan="2">SS05</td>
                                </tr>
                                <tr>
                                    <td colspan="3" class="divider"></td>
                                </tr>
                                <tr>
                                    <td align="right"><b>Colour:</b>&nbsp;</td>
                                    <td colspan="2">

                                            Sky blue

                                        &nbsp;

                                            (Blue)



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
                                    <td colspan="2">RTW - Italy</td>
                                </tr>
                                <tr>
                                    <td colspan="3" class="divider"></td>
                                </tr>
                                <tr>
                                    <td align="right"><b>Classification:</b>&nbsp;</td>
                                    <td colspan="2">Clothing / Dresses / Weekend</td>
                                </tr>
                                <tr>
                                    <td colspan="3" class="divider"></td>
                                </tr>
                                <tr>
                                    <td width="35%" align="right"><b>Purchase Order:</b>&nbsp;</td>
                                    <td width="65%" colspan="2">


                                            <a href="/StockControl/PurchaseOrder/Overview?po_id=557">NRSS05 - RTW 02</a> &nbsp; &nbsp; <br />



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

                                    <a href='http://www.net-a-porter.com/product/10456' target='livewindow'>Live</a> : Invisible



                                    &nbsp;&nbsp;&nbsp;&nbsp;<i>

                                        (Transferred)

                                    </i>

                            </td>
                            <td>11-04-2005</td>
                            <td>27-04-2005</td>
                            <td><img src="/images/icons/bullet_red.png" title="Inactive" alt="Inactive"></td>
                        </tr>
                        <tr>
                            <td colspan="5" class="divider"></td>
                        </tr>

                        <tr>
                            <td>&nbsp;&nbsp;<span class="title title-OUTNET" style="line-height: 1em;">theOutnet.com</span></td>
                            <td>

                                    <a href='http://www.theoutnet.com/product/10456' target='livewindow'>Live</a> : Invisible



                            </td>
                            <td>-</td>
                            <td>20-05-2010</td>
                            <td><img src="/images/icons/bullet_green.png" title="Active" alt="Active"></td>
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
    <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

    <input type="hidden" name="product_id" value="10456" />
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
                <td width="15%">&nbsp;&nbsp;<input type="text" name="op" value="Sarabjit Kaur" size="12" readonly="readonly" /></td>
                <td width="20%"><input type="text" name="dep" value="" size="20" readonly="readonly" /></td>
                <td width="20%"><input type="text" name="dat" value="16-05-2012 14:46" size="17" readonly="readonly" /></td>
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














<div id="tabContainer" class="yui-navset">
        <table width="100%" cellpadding="0" cellspacing="0" border="0" class="tabChannelTable">
        <tr>
            <td align="right"><span class="tab-label">Sales Channel:&nbsp;</span></td>
            <td width="5%" align="right" nowrap>
                <ul class="yui-nav">                        <li><a href="#tab1" class="contentTab-NAP" style="text-decoration: none;"><em>NET-A-PORTER.COM</em></a></li>                        <li class="selected"><a href="#tab2" class="contentTab-OUTNET" style="text-decoration: none;"><em>THEOUTNET.COM</em></a></li>                </ul>
            </td>
        </tr>
    </table>

        <div class="yui-content" class="tabWrapper-OUTNET">









               <div id="tab1" class="tabWrapper-NAP">
                <div class="tabInsideWrapper">

                        <div id="foo101" class="yui-navset yui-navset-top">
                            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="tabChannelTable">
                                <tbody><tr>
                                    <td align="right"><span class="tab-label"></span></td>
                                    <td align="right" nowrap="">
                                        <ul class="yui-nav">


                                            <li class="selected">
                                                <a href="#tabNET-A-PORTER.COM1236" class="contentTab-NAP" style="text-decoration: none;">
                                                    <em>Reservations </em>
                                                </a>
                                            </li>



                                            <li class="">
                                                <a href="#tabNET-A-PORTER.COM1236" class="contentTab-NAP" style="text-decoration: none;">
                                                    <em>Pre Orders </em>
                                                </a>
                                            </li>


                                    </ul>
                                </td>
                                </tr>
                                </tbody>
                           </table>

                        <div class="yui-content"  class="tabWrapper-NAP">


                                <div id="tabNET-A-PORTER.COM1236" class="tabWrapper-NAP">
                                    <div class="tabInsideWrapper">

        <div id="reservation_tabview-NAP">
            <span class="title title-NAP">Reservations</span><br />












            <a name="34553"></a>
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_34553">
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>
                <tr>

                    <td width="20%" class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
                    <td width="15%" class="tableHeader">Designer Size</td>
                    <td width="12%" class="tableHeader">NAP Size</td>
                    <td width="12%" class="tableHeader">Ordered</td>
                    <td width="14%" class="tableHeader">Stock on hand</td>
                    <td width="14%" class="tableHeader">Reservations</td>
                    <td width="20%" class="tableHeader">Upload Date</td>


                </tr>
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>

                <tr>
                    <td>&nbsp;&nbsp;&nbsp;10456-010&nbsp;&nbsp;</td>
                    <td>38</td>
                    <td>xx small</td>
                    <td>3</td>
                    <td>100</td>
                    <td>0</td>
                    <td></td>
                </tr>

                <tr>
                    <td colspan="7" class="divider"></td>
                </tr>
            </table>





            <form name="createReservation-1-34553" action="/StockControl/Reservation/Create" method="post">
                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                <input type="hidden" name="variant_id" value="34553">
                <input type="hidden" name="channel" value="NET-A-PORTER.COM">
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                <tr>
                    <td colspan="10" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
                </tr>
                <tr>

                        <td colspan="10" class="blank" align="right"><input type="submit" name="submit" class="button" value="Create Reservation &raquo;">
</td>

                </tr>
            </table>
            </form>


            <br>
            <br>











            <a name="34554"></a>
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_34554">
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>
                <tr>

                    <td width="20%" class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
                    <td width="15%" class="tableHeader">Designer Size</td>
                    <td width="12%" class="tableHeader">NAP Size</td>
                    <td width="12%" class="tableHeader">Ordered</td>
                    <td width="14%" class="tableHeader">Stock on hand</td>
                    <td width="14%" class="tableHeader">Reservations</td>
                    <td width="20%" class="tableHeader">Upload Date</td>


                </tr>
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>

                <tr>
                    <td>&nbsp;&nbsp;&nbsp;10456-011&nbsp;&nbsp;</td>
                    <td>40</td>
                    <td>x small</td>
                    <td>4</td>
                    <td>0</td>
                    <td>0</td>
                    <td></td>
                </tr>

                <tr>
                    <td colspan="7" class="divider"></td>
                </tr>
            </table>





            <form name="createReservation-1-34554" action="/StockControl/Reservation/Create" method="post">
                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                <input type="hidden" name="variant_id" value="34554">
                <input type="hidden" name="channel" value="NET-A-PORTER.COM">
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                <tr>
                    <td colspan="10" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
                </tr>
                <tr>

                        <td colspan="10" class="blank" align="right"><input type="submit" name="submit" class="button" value="Create Reservation &raquo;">
</td>

                </tr>
            </table>
            </form>


            <br>
            <br>











            <a name="34555"></a>
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_34555">
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>
                <tr>

                    <td width="20%" class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
                    <td width="15%" class="tableHeader">Designer Size</td>
                    <td width="12%" class="tableHeader">NAP Size</td>
                    <td width="12%" class="tableHeader">Ordered</td>
                    <td width="14%" class="tableHeader">Stock on hand</td>
                    <td width="14%" class="tableHeader">Reservations</td>
                    <td width="20%" class="tableHeader">Upload Date</td>


                </tr>
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>

                <tr>
                    <td>&nbsp;&nbsp;&nbsp;10456-012&nbsp;&nbsp;</td>
                    <td>42</td>
                    <td>small</td>
                    <td>4</td>
                    <td>0</td>
                    <td>0</td>
                    <td></td>
                </tr>

                <tr>
                    <td colspan="7" class="divider"></td>
                </tr>
            </table>





            <form name="createReservation-1-34555" action="/StockControl/Reservation/Create" method="post">
                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                <input type="hidden" name="variant_id" value="34555">
                <input type="hidden" name="channel" value="NET-A-PORTER.COM">
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                <tr>
                    <td colspan="10" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
                </tr>
                <tr>

                        <td colspan="10" class="blank" align="right"><input type="submit" name="submit" class="button" value="Create Reservation &raquo;">
</td>

                </tr>
            </table>
            </form>


            <br>
            <br>











            <a name="34556"></a>
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_34556">
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>
                <tr>

                    <td width="20%" class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
                    <td width="15%" class="tableHeader">Designer Size</td>
                    <td width="12%" class="tableHeader">NAP Size</td>
                    <td width="12%" class="tableHeader">Ordered</td>
                    <td width="14%" class="tableHeader">Stock on hand</td>
                    <td width="14%" class="tableHeader">Reservations</td>
                    <td width="20%" class="tableHeader">Upload Date</td>


                </tr>
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>

                <tr>
                    <td>&nbsp;&nbsp;&nbsp;10456-013&nbsp;&nbsp;</td>
                    <td>44</td>
                    <td>medium</td>
                    <td>3</td>
                    <td>0</td>
                    <td>0</td>
                    <td></td>
                </tr>

                <tr>
                    <td colspan="7" class="divider"></td>
                </tr>
            </table>





            <form name="createReservation-1-34556" action="/StockControl/Reservation/Create" method="post">
                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                <input type="hidden" name="variant_id" value="34556">
                <input type="hidden" name="channel" value="NET-A-PORTER.COM">
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                <tr>
                    <td colspan="10" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
                </tr>
                <tr>

                        <td colspan="10" class="blank" align="right"><input type="submit" name="submit" class="button" value="Create Reservation &raquo;">
</td>

                </tr>
            </table>
            </form>


            <br>
            <br>











            <a name="34557"></a>
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_34557">
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>
                <tr>

                    <td width="20%" class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
                    <td width="15%" class="tableHeader">Designer Size</td>
                    <td width="12%" class="tableHeader">NAP Size</td>
                    <td width="12%" class="tableHeader">Ordered</td>
                    <td width="14%" class="tableHeader">Stock on hand</td>
                    <td width="14%" class="tableHeader">Reservations</td>
                    <td width="20%" class="tableHeader">Upload Date</td>


                </tr>
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>

                <tr>
                    <td>&nbsp;&nbsp;&nbsp;10456-014&nbsp;&nbsp;</td>
                    <td>46</td>
                    <td>large</td>
                    <td>2</td>
                    <td>0</td>
                    <td>0</td>
                    <td></td>
                </tr>

                <tr>
                    <td colspan="7" class="divider"></td>
                </tr>
            </table>





            <form name="createReservation-1-34557" action="/StockControl/Reservation/Create" method="post">
                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                <input type="hidden" name="variant_id" value="34557">
                <input type="hidden" name="channel" value="NET-A-PORTER.COM">
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                <tr>
                    <td colspan="10" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
                </tr>
                <tr>

                        <td colspan="10" class="blank" align="right"><input type="submit" name="submit" class="button" value="Create Reservation &raquo;">
</td>

                </tr>
            </table>
            </form>


            <br>
            <br>











            <a name="34558"></a>
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_34558">
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>
                <tr>

                    <td width="20%" class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
                    <td width="15%" class="tableHeader">Designer Size</td>
                    <td width="12%" class="tableHeader">NAP Size</td>
                    <td width="12%" class="tableHeader">Ordered</td>
                    <td width="14%" class="tableHeader">Stock on hand</td>
                    <td width="14%" class="tableHeader">Reservations</td>
                    <td width="20%" class="tableHeader">Upload Date</td>


                </tr>
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>

                <tr>
                    <td>&nbsp;&nbsp;&nbsp;10456-015&nbsp;&nbsp;</td>
                    <td>48</td>
                    <td>x large</td>
                    <td>1</td>
                    <td>0</td>
                    <td>0</td>
                    <td></td>
                </tr>

                <tr>
                    <td colspan="7" class="divider"></td>
                </tr>
            </table>





            <form name="createReservation-1-34558" action="/StockControl/Reservation/Create" method="post">
                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                <input type="hidden" name="variant_id" value="34558">
                <input type="hidden" name="channel" value="NET-A-PORTER.COM">
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                <tr>
                    <td colspan="10" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
                </tr>
                <tr>

                        <td colspan="10" class="blank" align="right"><input type="submit" name="submit" class="button" value="Create Reservation &raquo;">
</td>

                </tr>
            </table>
            </form>


            <br>
            <br>







        </div>

                                    </div>
                                </div>



                                <div id="tabNET-A-PORTER.COM1236" class="tabWrapper-NAP">
                                    <div class="tabInsideWrapper">

        <div id="preorder_tabview-NAP">


                 <span class="title title-NAP">Pre-order</span><br />
















































            No pre-order data for this product




     </div>

                                    </div>
                                </div>


                    </div> <!-- yui-content -->
               </div> <!-- Tabcontainer foo loopcount +100 -->

                 </div>
           </div> <!-- unn divs -->










               <div id="tab2" class="tabWrapper-OUTNET">
                <div class="tabInsideWrapper">

                        <div id="foo102" class="yui-navset yui-navset-top">
                            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="tabChannelTable">
                                <tbody><tr>
                                    <td align="right"><span class="tab-label"></span></td>
                                    <td align="right" nowrap="">
                                        <ul class="yui-nav">


                                            <li class="selected">
                                                <a href="#tabtheOutnet.com1236" class="contentTab-OUTNET" style="text-decoration: none;">
                                                    <em>Reservations </em>
                                                </a>
                                            </li>



                                            <li class="">
                                                <a href="#tabtheOutnet.com1236" class="contentTab-OUTNET" style="text-decoration: none;">
                                                    <em>Pre Orders </em>
                                                </a>
                                            </li>


                                    </ul>
                                </td>
                                </tr>
                                </tbody>
                           </table>

                        <div class="yui-content"  class="tabWrapper-OUTNET">


                                <div id="tabtheOutnet.com1236" class="tabWrapper-OUTNET">
                                    <div class="tabInsideWrapper">

        <div id="reservation_tabview-OUTNET">
            <span class="title title-OUTNET">Reservations</span><br />












            <a name="34553"></a>
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_34553">
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>
                <tr>

                    <td width="20%" class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
                    <td width="15%" class="tableHeader">Designer Size</td>
                    <td width="12%" class="tableHeader">NAP Size</td>
                    <td width="12%" class="tableHeader">Ordered</td>
                    <td width="14%" class="tableHeader">Stock on hand</td>
                    <td width="14%" class="tableHeader">Reservations</td>
                    <td width="20%" class="tableHeader">Upload Date</td>


                </tr>
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>

                <tr>
                    <td>&nbsp;&nbsp;&nbsp;10456-010&nbsp;&nbsp;</td>
                    <td>38</td>
                    <td>xx small</td>
                    <td>0</td>
                    <td>0</td>
                    <td>0</td>
                    <td></td>
                </tr>

                <tr>
                    <td colspan="7" class="divider"></td>
                </tr>
            </table>



                <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_customers_34553">
                    <tr>
                        <td colspan="13" class="blank"><img src="/images/blank.gif" width="1" height="15"></td>
                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>
                    <tr>

                        <td width="4%" class="tableHeader">&nbsp;</td>
                        <td width="15%" class="tableHeader">Customer</td>
                        <td width="4%" class="tableHeader">No.</td>
                        <td width="2%" class="tableHeader"></td>
                        <td width="15%" class="tableHeader">Operator</td>
                        <td width="10%" class="tableHeader">Source&nbsp;</td>
                        <td width="8%" class="tableHeader">Created</td>
                        <td width="8%" class="tableHeader">Uploaded</td>
                        <td width="8%" class="tableHeader">Expires</td>
                        <td width="8%" class="tableHeader">Status</td>
                        <td width="8%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>

                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>





                            <tr>
                                <td>&nbsp;&nbsp;1  </td>
                                <td>4e444f6 e3</td>
                                <td>300786815</td>
                                <td></td>
                                <td>Sarabjit Kaur</td>
                                <td>&nbsp;&nbsp;</td>
                                <td>10-05</td>
                                <td></td>
                                <td></td>
                                <td>Pending</td>
                                <td valign="middle">
                                <form name="updateForm373993" action="/StockControl/Reservation/Update" method="post">
                                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                                <input type="hidden" name="special_order_id" value="373993">
                                <input type="hidden" name="action" value="">
                                <input type="hidden" name="redirect_url" value="/StockControl/Reservation/Product?product_id=10456">


                                    </form>
                                    </td>


                                    <td><a href="javascript://" onClick="showEditLayer('3','34553','373993', '00', '00', '00', '1', '', '8514', '1', 0, event);">Edit</a></td>
                                    <td><a href="javascript:deleteSubmit('updateForm373993')">Delete</a></td>

                            </tr>
                            <tr>
                                <td colspan="13" class="divider"></td>
                            </tr>



                </table>



            <form name="createReservation-3-34553" action="/StockControl/Reservation/Create" method="post">
                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                <input type="hidden" name="variant_id" value="34553">
                <input type="hidden" name="channel" value="theOutnet.com">
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                <tr>
                    <td colspan="10" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
                </tr>
                <tr>

                        <td colspan="10" class="blank" align="right"><input type="submit" name="submit" class="button" value="Create Reservation &raquo;">
</td>

                </tr>
            </table>
            </form>


            <br>
            <br>











            <a name="34554"></a>
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_34554">
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>
                <tr>

                    <td width="20%" class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
                    <td width="15%" class="tableHeader">Designer Size</td>
                    <td width="12%" class="tableHeader">NAP Size</td>
                    <td width="12%" class="tableHeader">Ordered</td>
                    <td width="14%" class="tableHeader">Stock on hand</td>
                    <td width="14%" class="tableHeader">Reservations</td>
                    <td width="20%" class="tableHeader">Upload Date</td>


                </tr>
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>

                <tr>
                    <td>&nbsp;&nbsp;&nbsp;10456-011&nbsp;&nbsp;</td>
                    <td>40</td>
                    <td>x small</td>
                    <td>0</td>
                    <td>0</td>
                    <td>0</td>
                    <td></td>
                </tr>

                <tr>
                    <td colspan="7" class="divider"></td>
                </tr>
            </table>



                <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_customers_34554">
                    <tr>
                        <td colspan="13" class="blank"><img src="/images/blank.gif" width="1" height="15"></td>
                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>
                    <tr>

                        <td width="4%" class="tableHeader">&nbsp;</td>
                        <td width="15%" class="tableHeader">Customer</td>
                        <td width="4%" class="tableHeader">No.</td>
                        <td width="2%" class="tableHeader"></td>
                        <td width="15%" class="tableHeader">Operator</td>
                        <td width="10%" class="tableHeader">Source&nbsp;</td>
                        <td width="8%" class="tableHeader">Created</td>
                        <td width="8%" class="tableHeader">Uploaded</td>
                        <td width="8%" class="tableHeader">Expires</td>
                        <td width="8%" class="tableHeader">Status</td>
                        <td width="8%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>

                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>





                            <tr id="is_customer_number-22" class="highlight">
                                <td>&nbsp;&nbsp;1  </td>
                                <td>4e444f6 e3</td>
                                <td>300786815</td>
                                <td></td>
                                <td><span title="Customer Category: EIP Premium">Sarabjit Kaur</span></td>
                                <td>&nbsp;&nbsp;</td>
                                <td>10-05</td>
                                <td></td>
                                <td></td>
                                <td>Pending</td>
                                <td valign="middle">
                                <form name="updateForm373994" action="/StockControl/Reservation/Update" method="post">
                                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                                <input type="hidden" name="special_order_id" value="373994">
                                <input type="hidden" name="action" value="">
                                <input type="hidden" name="redirect_url" value="/StockControl/Reservation/Product?product_id=10456">


                                    </form>
                                    </td>


                                    <td><a href="javascript://" onClick="showEditLayer('3','34554','373994', '00', '00', '00', '1', '', '8514', '1', 0, event);">Edit</a></td>
                                    <td><a href="javascript:deleteSubmit('updateForm373994')">Delete</a></td>

                            </tr>
                            <tr>
                                <td colspan="13" class="divider"></td>
                            </tr>



                </table>



            <form name="createReservation-3-34554" action="/StockControl/Reservation/Create" method="post">
                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                <input type="hidden" name="variant_id" value="34554">
                <input type="hidden" name="channel" value="theOutnet.com">
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                <tr>
                    <td colspan="10" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
                </tr>
                <tr>

                        <td colspan="10" class="blank" align="right"><input type="submit" name="submit" class="button" value="Create Reservation &raquo;">
</td>

                </tr>
            </table>
            </form>


            <br>
            <br>











            <a name="34555"></a>
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_34555">
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>
                <tr>

                    <td width="20%" class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
                    <td width="15%" class="tableHeader">Designer Size</td>
                    <td width="12%" class="tableHeader">NAP Size</td>
                    <td width="12%" class="tableHeader">Ordered</td>
                    <td width="14%" class="tableHeader">Stock on hand</td>
                    <td width="14%" class="tableHeader">Reservations</td>
                    <td width="20%" class="tableHeader">Upload Date</td>


                </tr>
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>

                <tr>
                    <td>&nbsp;&nbsp;&nbsp;10456-012&nbsp;&nbsp;</td>
                    <td>42</td>
                    <td>small</td>
                    <td>0</td>
                    <td>0</td>
                    <td>0</td>
                    <td></td>
                </tr>

                <tr>
                    <td colspan="7" class="divider"></td>
                </tr>
            </table>



                <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_customers_34555">
                    <tr>
                        <td colspan="13" class="blank"><img src="/images/blank.gif" width="1" height="15"></td>
                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>
                    <tr>

                        <td width="4%" class="tableHeader">&nbsp;</td>
                        <td width="15%" class="tableHeader">Customer</td>
                        <td width="4%" class="tableHeader">No.</td>
                        <td width="2%" class="tableHeader"></td>
                        <td width="15%" class="tableHeader">Operator</td>
                        <td width="10%" class="tableHeader">Source&nbsp;</td>
                        <td width="8%" class="tableHeader">Created</td>
                        <td width="8%" class="tableHeader">Uploaded</td>
                        <td width="8%" class="tableHeader">Expires</td>
                        <td width="8%" class="tableHeader">Status</td>
                        <td width="8%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>

                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>





                            <tr>
                                <td>&nbsp;&nbsp;1  </td>
                                <td>4e444f6 e3</td>
                                <td>300786815</td>
                                <td></td>
                                <td>Sarabjit Kaur</td>
                                <td>&nbsp;&nbsp;</td>
                                <td>10-05</td>
                                <td></td>
                                <td></td>
                                <td>Pending</td>
                                <td valign="middle">
                                <form name="updateForm373995" action="/StockControl/Reservation/Update" method="post">
                                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                                <input type="hidden" name="special_order_id" value="373995">
                                <input type="hidden" name="action" value="">
                                <input type="hidden" name="redirect_url" value="/StockControl/Reservation/Product?product_id=10456">


                                    </form>
                                    </td>


                                    <td><a href="javascript://" onClick="showEditLayer('3','34555','373995', '00', '00', '00', '1', '', '8514', '1', 0, event);">Edit</a></td>
                                    <td><a href="javascript:deleteSubmit('updateForm373995')">Delete</a></td>

                            </tr>
                            <tr>
                                <td colspan="13" class="divider"></td>
                            </tr>



                </table>



            <form name="createReservation-3-34555" action="/StockControl/Reservation/Create" method="post">
                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                <input type="hidden" name="variant_id" value="34555">
                <input type="hidden" name="channel" value="theOutnet.com">
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                <tr>
                    <td colspan="10" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
                </tr>
                <tr>

                        <td colspan="10" class="blank" align="right"><input type="submit" name="submit" class="button" value="Create Reservation &raquo;">
</td>

                </tr>
            </table>
            </form>


            <br>
            <br>











            <a name="34556"></a>
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_34556">
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>
                <tr>

                    <td width="20%" class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
                    <td width="15%" class="tableHeader">Designer Size</td>
                    <td width="12%" class="tableHeader">NAP Size</td>
                    <td width="12%" class="tableHeader">Ordered</td>
                    <td width="14%" class="tableHeader">Stock on hand</td>
                    <td width="14%" class="tableHeader">Reservations</td>
                    <td width="20%" class="tableHeader">Upload Date</td>


                </tr>
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>

                <tr>
                    <td>&nbsp;&nbsp;&nbsp;10456-013&nbsp;&nbsp;</td>
                    <td>44</td>
                    <td>medium</td>
                    <td>0</td>
                    <td>0</td>
                    <td>0</td>
                    <td></td>
                </tr>

                <tr>
                    <td colspan="7" class="divider"></td>
                </tr>
            </table>



                <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_customers_34556">
                    <tr>
                        <td colspan="13" class="blank"><img src="/images/blank.gif" width="1" height="15"></td>
                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>
                    <tr>

                        <td width="4%" class="tableHeader">&nbsp;</td>
                        <td width="15%" class="tableHeader">Customer</td>
                        <td width="4%" class="tableHeader">No.</td>
                        <td width="2%" class="tableHeader"></td>
                        <td width="15%" class="tableHeader">Operator</td>
                        <td width="10%" class="tableHeader">Source&nbsp;</td>
                        <td width="8%" class="tableHeader">Created</td>
                        <td width="8%" class="tableHeader">Uploaded</td>
                        <td width="8%" class="tableHeader">Expires</td>
                        <td width="8%" class="tableHeader">Status</td>
                        <td width="8%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>

                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>





                            <tr id="is_customer_number-23" class="highlight">
                                <td>&nbsp;&nbsp;1  </td>
                                <td>4e444f6 e3</td>
                                <td>300786815</td>
                                <td></td>
                                <td>Sarabjit Kaur</td>
                                <td>&nbsp;&nbsp;</td>
                                <td>10-05</td>
                                <td></td>
                                <td></td>
                                <td>Pending</td>
                                <td valign="middle">
                                <form name="updateForm373996" action="/StockControl/Reservation/Update" method="post">
                                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                                <input type="hidden" name="special_order_id" value="373996">
                                <input type="hidden" name="action" value="">
                                <input type="hidden" name="redirect_url" value="/StockControl/Reservation/Product?product_id=10456">


                                    </form>
                                    </td>


                                    <td><a href="javascript://" onClick="showEditLayer('3','34556','373996', '00', '00', '00', '1', '', '8514', '1', 0, event);">Edit</a></td>
                                    <td><a href="javascript:deleteSubmit('updateForm373996')">Delete</a></td>

                            </tr>
                            <tr>
                                <td colspan="13" class="divider"></td>
                            </tr>



                </table>



            <form name="createReservation-3-34556" action="/StockControl/Reservation/Create" method="post">
                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                <input type="hidden" name="variant_id" value="34556">
                <input type="hidden" name="channel" value="theOutnet.com">
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                <tr>
                    <td colspan="10" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
                </tr>
                <tr>

                        <td colspan="10" class="blank" align="right"><input type="submit" name="submit" class="button" value="Create Reservation &raquo;">
</td>

                </tr>
            </table>
            </form>


            <br>
            <br>











            <a name="34557"></a>
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_34557">
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>
                <tr>

                    <td width="20%" class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
                    <td width="15%" class="tableHeader">Designer Size</td>
                    <td width="12%" class="tableHeader">NAP Size</td>
                    <td width="12%" class="tableHeader">Ordered</td>
                    <td width="14%" class="tableHeader">Stock on hand</td>
                    <td width="14%" class="tableHeader">Reservations</td>
                    <td width="20%" class="tableHeader">Upload Date</td>


                </tr>
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>

                <tr>
                    <td>&nbsp;&nbsp;&nbsp;10456-014&nbsp;&nbsp;</td>
                    <td>46</td>
                    <td>large</td>
                    <td>0</td>
                    <td>0</td>
                    <td>0</td>
                    <td></td>
                </tr>

                <tr>
                    <td colspan="7" class="divider"></td>
                </tr>
            </table>



                <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_customers_34557">
                    <tr>
                        <td colspan="13" class="blank"><img src="/images/blank.gif" width="1" height="15"></td>
                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>
                    <tr>

                        <td width="4%" class="tableHeader">&nbsp;</td>
                        <td width="15%" class="tableHeader">Customer</td>
                        <td width="4%" class="tableHeader">No.</td>
                        <td width="2%" class="tableHeader"></td>
                        <td width="15%" class="tableHeader">Operator</td>
                        <td width="10%" class="tableHeader">Source&nbsp;</td>
                        <td width="8%" class="tableHeader">Created</td>
                        <td width="8%" class="tableHeader">Uploaded</td>
                        <td width="8%" class="tableHeader">Expires</td>
                        <td width="8%" class="tableHeader">Status</td>
                        <td width="8%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>

                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>





                            <tr>
                                <td>&nbsp;&nbsp;1  </td>
                                <td>4e444f6 e3</td>
                                <td>300786815</td>
                                <td></td>
                                <td>Sarabjit Kaur</td>
                                <td>&nbsp;&nbsp;</td>
                                <td>10-05</td>
                                <td></td>
                                <td></td>
                                <td>Pending</td>
                                <td valign="middle">
                                <form name="updateForm373997" action="/StockControl/Reservation/Update" method="post">
                                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                                <input type="hidden" name="special_order_id" value="373997">
                                <input type="hidden" name="action" value="">
                                <input type="hidden" name="redirect_url" value="/StockControl/Reservation/Product?product_id=10456">


                                    </form>
                                    </td>


                                    <td><a href="javascript://" onClick="showEditLayer('3','34557','373997', '00', '00', '00', '1', '', '8514', '1', 0, event);">Edit</a></td>
                                    <td><a href="javascript:deleteSubmit('updateForm373997')">Delete</a></td>

                            </tr>
                            <tr>
                                <td colspan="13" class="divider"></td>
                            </tr>



                </table>



            <form name="createReservation-3-34557" action="/StockControl/Reservation/Create" method="post">
                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                <input type="hidden" name="variant_id" value="34557">
                <input type="hidden" name="channel" value="theOutnet.com">
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                <tr>
                    <td colspan="10" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
                </tr>
                <tr>

                        <td colspan="10" class="blank" align="right"><input type="submit" name="submit" class="button" value="Create Reservation &raquo;">
</td>

                </tr>
            </table>
            </form>


            <br>
            <br>











            <a name="34558"></a>
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_34558">
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>
                <tr>

                    <td width="20%" class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
                    <td width="15%" class="tableHeader">Designer Size</td>
                    <td width="12%" class="tableHeader">NAP Size</td>
                    <td width="12%" class="tableHeader">Ordered</td>
                    <td width="14%" class="tableHeader">Stock on hand</td>
                    <td width="14%" class="tableHeader">Reservations</td>
                    <td width="20%" class="tableHeader">Upload Date</td>


                </tr>
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>

                <tr>
                    <td>&nbsp;&nbsp;&nbsp;10456-015&nbsp;&nbsp;</td>
                    <td>48</td>
                    <td>x large</td>
                    <td>0</td>
                    <td>0</td>
                    <td>0</td>
                    <td></td>
                </tr>

                <tr>
                    <td colspan="7" class="divider"></td>
                </tr>
            </table>



                <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_customers_34558">
                    <tr>
                        <td colspan="13" class="blank"><img src="/images/blank.gif" width="1" height="15"></td>
                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>
                    <tr>

                        <td width="4%" class="tableHeader">&nbsp;</td>
                        <td width="15%" class="tableHeader">Customer</td>
                        <td width="4%" class="tableHeader">No.</td>
                        <td width="2%" class="tableHeader"></td>
                        <td width="15%" class="tableHeader">Operator</td>
                        <td width="10%" class="tableHeader">Source&nbsp;</td>
                        <td width="8%" class="tableHeader">Created</td>
                        <td width="8%" class="tableHeader">Uploaded</td>
                        <td width="8%" class="tableHeader">Expires</td>
                        <td width="8%" class="tableHeader">Status</td>
                        <td width="8%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>

                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>





                            <tr>
                                <td>&nbsp;&nbsp;1  </td>
                                <td>4e444f6 e3</td>
                                <td>300786815</td>
                                <td></td>
                                <td>Sarabjit Kaur</td>
                                <td>&nbsp;&nbsp;</td>
                                <td>10-05</td>
                                <td></td>
                                <td></td>
                                <td>Pending</td>
                                <td valign="middle">
                                <form name="updateForm373998" action="/StockControl/Reservation/Update" method="post">
                                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                                <input type="hidden" name="special_order_id" value="373998">
                                <input type="hidden" name="action" value="">
                                <input type="hidden" name="redirect_url" value="/StockControl/Reservation/Product?product_id=10456">


                                    </form>
                                    </td>


                                    <td><a href="javascript://" onClick="showEditLayer('3','34558','373998', '00', '00', '00', '1', '', '8514', '1', 0, event);">Edit</a></td>
                                    <td><a href="javascript:deleteSubmit('updateForm373998')">Delete</a></td>

                            </tr>
                            <tr>
                                <td colspan="13" class="divider"></td>
                            </tr>



                </table>



            <form name="createReservation-3-34558" action="/StockControl/Reservation/Create" method="post">
                <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

                <input type="hidden" name="variant_id" value="34558">
                <input type="hidden" name="channel" value="theOutnet.com">
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data">
                <tr>
                    <td colspan="10" class="blank"><img src="/images/blank.gif" width="1" height="10"></td>
                </tr>
                <tr>

                        <td colspan="10" class="blank" align="right"><input type="submit" name="submit" class="button" value="Create Reservation &raquo;">
</td>

                </tr>
            </table>
            </form>


            <br>
            <br>







        </div>

                                    </div>
                                </div>



                                <div id="tabtheOutnet.com1236" class="tabWrapper-OUTNET">
                                    <div class="tabInsideWrapper">

        <div id="preorder_tabview-OUTNET">


                 <span class="title title-OUTNET">Pre-order</span><br />














            <a name="34553"></a>
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_34553">
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>
                <tr>

                    <td width="20%" class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
                    <td width="15%" class="tableHeader">Designer Size</td>
                    <td width="12%" class="tableHeader">NAP Size</td>
                    <td width="12%" class="tableHeader">Ordered Qty</td>
                    <td width="14%" class="tableHeader">Pre Ordered Qty</td>
                    <td width="14%" class="tableHeader">Reservations</td>
                    <td width="20%" class="tableHeader">&nbsp;</td>


                </tr>
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>

                <tr>
                    <td>&nbsp;&nbsp;&nbsp;10456-010&nbsp;&nbsp;</td>
                    <td>38</td>
                    <td>xx small</td>
                    <td>0</td>
                    <td>1</td>
                    <td>0</td>
                    <td></td>
                </tr>

                <tr>
                    <td colspan="7" class="divider"></td>
                </tr>
            </table>



                <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_customers_34553">
                    <tr>
                        <td colspan="13" class="blank"><img src="/images/blank.gif" width="1" height="15"></td>
                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>
                    <tr>

                        <td width="15%" class="tableHeader">Customer</td>
                        <td width="4%" class="tableHeader">No.</td>
                        <td width="2%" class="tableHeader"></td>
                        <td width="15%" class="tableHeader">Operator</td>
                        <td width="8%" class="tableHeader">Created</td>
                        <td width="8%" class="tableHeader">Status</td>
                        <td width="8%" class="tableHeader"></td>
                        <td width="8%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>
                        <td width="8%" class="tableHeader">&nbsp;</td>
                        <td width="8%" class="tableHeader">&nbsp;</td>
                        <td width="8%" class="tableHeader">&nbsp;</td>

                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>





                            <tr>
                                <td>michael martins</td>
                                <td><a href="/StockControl/Reservation/Customer?customer_id=560176">500108649</a></td>
                                <td></td>
                                <td>Sarabjit Kaur</td>
                                <td>10-05-12</td>
                                <td>Incomplete</td>
                                <td>&nbsp;&nbsp; </td>

                                    <td><a href="#">Cancel</a></td>

                                <td></td>
                                <td></td>
                                <td>&nbsp;</td>
                                <td>&nbsp;</td>
                                <td>&nbsp;</td>

                            </tr>
                            <tr>
                                <td colspan="13" class="divider"></td>
                            </tr>




                </table>




            <br>
            <br>













            <a name="34554"></a>
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_34554">
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>
                <tr>

                    <td width="20%" class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
                    <td width="15%" class="tableHeader">Designer Size</td>
                    <td width="12%" class="tableHeader">NAP Size</td>
                    <td width="12%" class="tableHeader">Ordered Qty</td>
                    <td width="14%" class="tableHeader">Pre Ordered Qty</td>
                    <td width="14%" class="tableHeader">Reservations</td>
                    <td width="20%" class="tableHeader">&nbsp;</td>


                </tr>
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>

                <tr>
                    <td>&nbsp;&nbsp;&nbsp;10456-011&nbsp;&nbsp;</td>
                    <td>40</td>
                    <td>x small</td>
                    <td>0</td>
                    <td>1</td>
                    <td>0</td>
                    <td></td>
                </tr>

                <tr>
                    <td colspan="7" class="divider"></td>
                </tr>
            </table>



                <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_customers_34554">
                    <tr>
                        <td colspan="13" class="blank"><img src="/images/blank.gif" width="1" height="15"></td>
                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>
                    <tr>

                        <td width="15%" class="tableHeader">Customer</td>
                        <td width="4%" class="tableHeader">No.</td>
                        <td width="2%" class="tableHeader"></td>
                        <td width="15%" class="tableHeader">Operator</td>
                        <td width="8%" class="tableHeader">Created</td>
                        <td width="8%" class="tableHeader">Status</td>
                        <td width="8%" class="tableHeader"></td>
                        <td width="8%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>
                        <td width="8%" class="tableHeader">&nbsp;</td>
                        <td width="8%" class="tableHeader">&nbsp;</td>
                        <td width="8%" class="tableHeader">&nbsp;</td>

                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>





                            <tr>
                                <td>michael martins</td>
                                <td><a href="/StockControl/Reservation/Customer?customer_id=560176">500108649</a></td>
                                <td></td>
                                <td>Sarabjit Kaur</td>
                                <td>10-05-12</td>
                                <td>Incomplete</td>
                                <td>&nbsp;&nbsp; </td>

                                    <td><a href="#">Cancel</a></td>

                                <td></td>
                                <td></td>
                                <td>&nbsp;</td>
                                <td>&nbsp;</td>
                                <td>&nbsp;</td>

                            </tr>
                            <tr>
                                <td colspan="13" class="divider"></td>
                            </tr>




                </table>




            <br>
            <br>













            <a name="34555"></a>
            <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_34555">
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>
                <tr>

                    <td width="20%" class="tableHeader">&nbsp;&nbsp;&nbsp;SKU</td>
                    <td width="15%" class="tableHeader">Designer Size</td>
                    <td width="12%" class="tableHeader">NAP Size</td>
                    <td width="12%" class="tableHeader">Ordered Qty</td>
                    <td width="14%" class="tableHeader">Pre Ordered Qty</td>
                    <td width="14%" class="tableHeader">Reservations</td>
                    <td width="20%" class="tableHeader">&nbsp;</td>


                </tr>
                <tr>
                    <td colspan="7" class="dividerHeader"></td>
                </tr>

                <tr>
                    <td>&nbsp;&nbsp;&nbsp;10456-012&nbsp;&nbsp;</td>
                    <td>42</td>
                    <td>small</td>
                    <td>0</td>
                    <td>1</td>
                    <td>0</td>
                    <td></td>
                </tr>

                <tr>
                    <td colspan="7" class="divider"></td>
                </tr>
            </table>



                <table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="variant_customers_34555">
                    <tr>
                        <td colspan="13" class="blank"><img src="/images/blank.gif" width="1" height="15"></td>
                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>
                    <tr>

                        <td width="15%" class="tableHeader">Customer</td>
                        <td width="4%" class="tableHeader">No.</td>
                        <td width="2%" class="tableHeader"></td>
                        <td width="15%" class="tableHeader">Operator</td>
                        <td width="8%" class="tableHeader">Created</td>
                        <td width="8%" class="tableHeader">Status</td>
                        <td width="8%" class="tableHeader"></td>
                        <td width="8%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>
                        <td width="5%" class="tableHeader"></td>
                        <td width="8%" class="tableHeader">&nbsp;</td>
                        <td width="8%" class="tableHeader">&nbsp;</td>
                        <td width="8%" class="tableHeader">&nbsp;</td>

                    </tr>
                    <tr>
                        <td colspan="13" class="dividerHeader"></td>
                    </tr>





                            <tr>
                                <td>michael martins</td>
                                <td><a href="/StockControl/Reservation/Customer?customer_id=560176">500108649</a></td>
                                <td></td>
                                <td>Sarabjit Kaur</td>
                                <td>10-05-12</td>
                                <td>Incomplete</td>
                                <td>&nbsp;&nbsp; </td>

                                    <td><a href="#">Cancel</a></td>

                                <td></td>
                                <td></td>
                                <td>&nbsp;</td>
                                <td>&nbsp;</td>
                                <td>&nbsp;</td>

                            </tr>
                            <tr>
                                <td colspan="13" class="divider"></td>
                            </tr>




                </table>




            <br>
            <br>





























     </div>

                                    </div>
                                </div>


                    </div> <!-- yui-content -->
               </div> <!-- Tabcontainer foo loopcount +100 -->

                 </div>
           </div> <!-- unn divs -->

           <!-- Foreach channel -->
     </div> <!-- yui-content -->
    </div> <!-- tabContainer -->

    <script type="text/javascript" language="javascript">
    (function() {
        var tabView = new YAHOO.widget.TabView('tabContainer');
    })();
</script>

    <script type="text/javascript" language="javascript">

            var tabView = new YAHOO.widget.TabView("tab1");

            var tabView = new YAHOO.widget.TabView("tab2");

    </script>

    <div id="editLayer" style="position:absolute; left:0px; top:0px; visibility:hidden; z-index:1000; background-color:#ccc; z-index:1000; padding-left:3px; padding-bottom:3px;">
        <div style="border:1px solid #666666; background-color: #fff; padding: 10px; z-index:1001">
        <form name="editForm" action="/StockControl/Reservation/Update" method="post">
        <input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value="1538024%3AffulI0lFxNaQRUzRLZEHvQ">

        <input type="hidden" name="action" value="Edit">
        <input type="hidden" name="redirect_url" value="/StockControl/Reservation/Product?product_id=10456">
        <input type="hidden" name="special_order_id">
        <input type="hidden" name="variant_id">
        <input type="hidden" name="current_position">
        <input type="hidden" name="operator_id" value="8514">
        <table width="265" cellpadding="5" cellspacing="0" border="0">
            <tr>
                <td colspan="2"><b>Edit Special Order</b></td>
                <td valign="top" align="right"><a href="javascript://" onClick="hideDiv('editLayer')">Close</a></td>
            <tr>
            <tr>
                <td colspan="3"><img src="/images/blank.gif" width="1" height="5"></td>
            <tr>
            <tr height="22">
                <td align="right">&nbsp;&nbsp;Expiry&nbsp;Date:</td>
                <td align="left" colspan="2">

                    <select name="expireDay" class="date">
                        <option value="00">00</option>
                        <option value="0"></option>


                                <option value="01">1</option>




                                <option value="02">2</option>




                                <option value="03">3</option>




                                <option value="04">4</option>




                                <option value="05">5</option>




                                <option value="06">6</option>




                                <option value="07">7</option>




                                <option value="08">8</option>




                                <option value="09">9</option>




                                <option value="10">10</option>




                                <option value="11">11</option>




                                <option value="12">12</option>




                                <option value="13">13</option>




                                <option value="14">14</option>




                                <option value="15">15</option>




                                <option value="16">16</option>




                                <option value="17">17</option>




                                <option value="18">18</option>




                                <option value="19">19</option>




                                <option value="20">20</option>




                                <option value="21">21</option>




                                <option value="22">22</option>




                                <option value="23">23</option>




                                <option value="24">24</option>




                                <option value="25">25</option>




                                <option value="26">26</option>




                                <option value="27">27</option>




                                <option value="28">28</option>




                                <option value="29">29</option>




                                <option value="30">30</option>




                                <option value="31">31</option>



                        <option value="">----</option>
                    </select>&nbsp;


                    <select name="expireMonth" class="date">
                        <option value="00">00</option>
                        <option value="0"></option>


                                <option value="01">1</option>




                                <option value="02">2</option>




                                <option value="03">3</option>




                                <option value="04">4</option>




                                <option value="05">5</option>




                                <option value="06">6</option>




                                <option value="07">7</option>




                                <option value="08">8</option>




                                <option value="09">9</option>




                                <option value="10">10</option>




                                <option value="11">11</option>




                                <option value="12">12</option>



                    <option value="">----</option>
                    </select>&nbsp;


                    <select name="expireYear" class="date">
                        <option value="0000">----</option>

                            <option value="2009">2009</option>


                            <option value="2010">2010</option>


                            <option value="2011">2011</option>


                            <option value="2012">2012</option>


                            <option value="2013">2013</option>


                    </select>&nbsp;
                    </td>
                </tr>
                <tr>
                    <td colspan="3"><img src="/images/blank.gif" width="1" height="2"></td>
                <tr>
                <tr height="22">
                    <td align="right">&nbsp;&nbsp;Size:</td>
                    <td align="left" colspan="2">
                        <select name="changeSize" class="date">

                                <option value="34553">10456-010</option>

                                <option value="34554">10456-011</option>

                                <option value="34555">10456-012</option>

                                <option value="34556">10456-013</option>

                                <option value="34557">10456-014</option>

                                <option value="34558">10456-015</option>

                        </select>
                    </td>
                </tr>
                <tr>
                    <td>&nbsp;</td>
                    <td colspan="2"><strong>NB.</strong> Any other changes made when changing the Size <strong>will not</strong> be applied to the new Reservation.</td>
                </tr>
                <tr>
                    <td colspan="3"></td>
                <tr>
                <tr height="22">
                    <td align="right">&nbsp;&nbsp;Position:</td>
                    <td align="left" colspan="2">
                        <select name="ordering" class="date">
                            <option></option>
                        </select>
                    </td>
                </tr>

                <tr height="22">
                    <td align="right">&nbsp;&nbsp;Operator:</td>
                    <td align="left" colspan="2">

                        <select name="newOperator" class="date">

                                <option value="7872">Aaliyah Bilal</option>

                                <option value="5351">Aarti Bajaj</option>

                                <option value="712">Abi Ayodeji</option>

                                <option value="7659">Adam Pico</option>

                                <option value="5975">Adam Taylor</option>

                                <option value="6790">Adren Hart</option>

                                <option value="5301">Adren Hart</option>

                                <option value="6789">Afiya Clarke</option>

                                <option value="6406">Afiya Clarke</option>

                                <option value="386">Agne Vaicaityte</option>

                                <option value="5289">Agnieska Buch-Andersen</option>

                                <option value="7372">Aimee McCorkindale</option>

                                <option value="5708">Aisha Massey</option>

                                <option value="5163">Alaah Ali Adetuyi</option>

                                <option value="6503">Alastair Nunez</option>

                                <option value="7841">Alexandra Francois</option>

                                <option value="193">Alexandre Favorito</option>

                                <option value="5011">Alexia Jordan</option>

                                <option value="962">Alex Monney</option>

                                <option value="484">Alex Mulas</option>

                                <option value="7662">Alex Norton</option>

                                <option value="7674">Alex Rigby</option>

                                <option value="861">Alice Currie</option>

                                <option value="7373">Alice Wall</option>

                                <option value="5557">Ali Shah</option>

                                <option value="8070">Alison Squire</option>

                                <option value="6884">Alvaro Garcia</option>

                                <option value="6565">Alys McMahon</option>

                                <option value="8308">Amanda Gilfilan</option>

                                <option value="7223">Amanda Lawrence</option>

                                <option value="5162">Amanda Skinner</option>

                                <option value="6861">Amarjeet Chumber</option>

                                <option value="8013">Amer Basic</option>

                                <option value="7661">Amil Hardy</option>

                                <option value="5741">Amy Bale</option>

                                <option value="8460">Anastacia Sprague</option>

                                <option value="6122">Anastasia Gerasimova</option>

                                <option value="314">Andrea McCullum</option>

                                <option value="8211">Andreas Pavlou</option>

                                <option value="5001">Andrew Beech</option>

                                <option value="7725">Andrew Benson</option>

                                <option value="6522">Andrew Black</option>

                                <option value="581">Andrew Collins</option>

                                <option value="8012">Andrew Justice</option>

                                <option value="7099">Andrew McDonald</option>

                                <option value="738">Andrew Millar</option>

                                <option value="5352">Andrew Solomon</option>

                                <option value="6405">Andrew Williams</option>

                                <option value="5561">Anita Agyemang</option>

                                <option value="7402">Anita Chan</option>

                                <option value="5729">Anna Carter</option>

                                <option value="5563">Anna Cunningham</option>

                                <option value="7671">Anna Karlstrom</option>

                                <option value="7379">Annalisa Spilletti</option>

                                <option value="6234">Anne Glackin</option>

                                <option value="6418">Anne-Marie Scammel</option>

                                <option value="6007">Anne Thorniley</option>

                                <option value="6247">Anthony Burger</option>

                                <option value="414">Antoinette Cohen</option>

                                <option value="7138">Antonio Michael</option>

                                <option value="5607">Arlette Davis</option>

                                <option value="963">Ash Berlin</option>

                                <option value="814">Ashleigh Cochrane</option>

                                <option value="7994">Ashley Bridgefarmer</option>

                                <option value="7241">Ashley Nelson</option>

                                <option value="8494">Ayana Rainford</option>

                                <option value="7726">Azizur Khan</option>

                                <option value="5946">Babatunde Dada</option>

                                <option value="5830">Basheera Khan</option>

                                <option value="7904">Becky Martin</option>

                                <option value="33">Benedicte Montagnier</option>

                                <option value="4">Ben Galbraith</option>

                                <option value="751">Ben Parsonson</option>

                                <option value="7898">Bethan Preston</option>

                                <option value="5268">Bhavic Nana</option>

                                <option value="6813">Bill Duffy</option>

                                <option value="5867">Blake Wilson</option>

                                <option value="7771">Blessie Morelli</option>

                                <option value="7663">Brian Whitenstall</option>

                                <option value="5590">Brooke Halley</option>

                                <option value="945">Bruno Almeida</option>

                                <option value="7088">Cameron Rollins</option>

                                <option value="897">Camille Deluge</option>

                                <option value="5108">Carolyn Mason</option>

                                <option value="6570">Cassandra Bergsland</option>

                                <option value="5038">Cate Williams</option>

                                <option value="6504">Catherine Mensah</option>

                                <option value="7672">Cezanne Gramson</option>

                                <option value="6057">Chantelle Akwei</option>

                                <option value="8122">Chante Palmer-Brown</option>

                                <option value="6520">Charles Njoteh</option>

                                <option value="817">Charlie Travers</option>

                                <option value="7565">Charlotte Copping</option>

                                <option value="6415">Cheney Hoareau</option>

                                <option value="399">Chisel Wright</option>

                                <option value="7907">Chloe Noble</option>

                                <option value="5458">Chris Feeney</option>

                                <option value="7528">Chris Ganderton</option>

                                <option value="838">Chris Groves</option>

                                <option value="7900">Christie Oke</option>

                                <option value="7723">Christina Costello</option>

                                <option value="8346">Christina Hartmann</option>

                                <option value="5111">Christine Havill</option>

                                <option value="7407">Christine Oramar</option>

                                <option value="7424">Christine Oramas</option>

                                <option value="740">Ciara Flood</option>

                                <option value="6096">Clair Benett</option>

                                <option value="802">Claire Devantier</option>

                                <option value="5012">Claire Fairbrace</option>

                                <option value="6816">Clare Kwon</option>

                                <option value="5393">Claudia Mejia</option>

                                <option value="937">Cobbie Yates</option>

                                <option value="5181">Corey Cerrato</option>

                                <option value="7489">Courtney Hanson</option>

                                <option value="6417">Craig Thompson</option>

                                <option value="7592">Cristina Del Rio</option>

                                <option value="7085">Crystal Malik</option>

                                <option value="86">Cuong Nguyen</option>

                                <option value="6077">Daegal Brian</option>

                                <option value="6076">Daegal Brian</option>

                                <option value="786">Daisy Marlow</option>

                                <option value="7763">Dana LoPiccolo</option>

                                <option value="5788">Danelle Barugh</option>

                                <option value="5526">Danielle Chetcuti</option>

                                <option value="674">Danielle Grundy</option>

                                <option value="748">Daniel Martinez</option>

                                <option value="5843">Daniel O'Dina</option>

                                <option value="5997">Daniel Robinson</option>

                                <option value="5709">Daniel Thompson</option>

                                <option value="5382">Danni Osborne</option>

                                <option value="613">Darius Jokilehto</option>

                                <option value="8425">Dave Cross</option>

                                <option value="8249">David Adedoyin</option>

                                <option value="916">David Cleaves</option>

                                <option value="180">David Del Egido</option>

                                <option value="1007">David Hallett</option>

                                <option value="1005">David Hallett </option>

                                <option value="7635">Dawn Cirone</option>

                                <option value="7382">Dawn Fong</option>

                                <option value="5285">Dean King</option>

                                <option value="6310">Dean Wilson</option>

                                <option value="6445">Declan O'Reilly</option>

                                <option value="7678">Deneisha Ross</option>

                                <option value="6822">Denis Todorovic</option>

                                <option value="845">Deniz Elmaz</option>

                                <option value="8209">Desi Day</option>

                                <option value="504">Diana Pruteanu</option>

                                <option value="5596">Dilpreet Kaur</option>

                                <option value="6523">Dinnie Muslihat</option>

                                <option value="5016">DISABELD: Kimberly Bryer</option>

                                <option value="841">Disabled: Adele O'Brien</option>

                                <option value="5795">DISABLED: Adrian McPherson</option>

                                <option value="64">DISABLED: Aiasha Junaid</option>

                                <option value="716">DISABLED: Ainsley McCabe</option>

                                <option value="398">DISABLED: Alessandra Rebello</option>

                                <option value="397">Disabled: Alexander Kirkup</option>

                                <option value="31">DISABLED: Alya Saleem</option>

                                <option value="843">DISABLED: Amanda Lindsay</option>

                                <option value="5105">DISABLED: Amber Gleeson</option>

                                <option value="274">DISABLED: Andrea Robinson</option>

                                <option value="181">Disabled: Andressa Rando</option>

                                <option value="639">DISABLED: Andrew Hylton</option>

                                <option value="230">Disabled: Andrew McGregor</option>

                                <option value="102">Disabled: Andy Johnson</option>

                                <option value="311">Disabled: Angela White</option>

                                <option value="385">DISABLED: Angelina Cecchetto</option>

                                <option value="30">Disabled: Anne-Marie Allen</option>

                                <option value="660">DISABLED: Annita Sung</option>

                                <option value="5250">DISABLED: Anthony Zahri</option>

                                <option value="768">DISABLED: Anum Pervez</option>

                                <option value="239">DISABLED: Benjamin Vacher</option>

                                <option value="870">DISABLED: Ben Test</option>

                                <option value="96">DISABLED: Bianca Faber</option>

                                <option value="739">Disabled: Brian Lock</option>

                                <option value="111">DISABLED: Carly Temple</option>

                                <option value="240">DISABLED: Chantelle Perkins</option>

                                <option value="7899">DISABLED: Chante Pamer-Brown</option>

                                <option value="700">DISABLED: Chardine Taylor-Stone</option>

                                <option value="737">DISABLED: Christopher Von Eitzen</option>

                                <option value="5817">DISABLED: Criselda Garde</option>

                                <option value="184">DISABLED: Cristina Ubbizzoni</option>

                                <option value="755">DISABLED: Dalton Hippolyte</option>

                                <option value="5042">DISABLED: Daniela Rueffel</option>

                                <option value="5037">DISABLED: Daniela Rueffel</option>

                                <option value="5041">DISABLED: Daniela Rueffel</option>

                                <option value="7">DISABLED: David Lindsay</option>

                                <option value="5816">DISABLED: Dillon Ludick</option>

                                <option value="5704">DISABLED: Dillon Ludik</option>

                                <option value="599">DISABLED: Donna Durrant</option>

                                <option value="5064">DISABLE: Dean King</option>

                                <option value="291">DISABLED: Edson Sarabia</option>

                                <option value="7595">disabled Elena Elfe</option>

                                <option value="6344">DISABLED: Elise Temp</option>

                                <option value="6341">DISABLED: Elise tempAcc</option>

                                <option value="289">DISABLED: Erica Chang</option>

                                <option value="5722">DISABLED: Erin Darrigan</option>

                                <option value="5796">DISABLED: Francesca Ginnett</option>

                                <option value="256">DISABLED: Francine Dove</option>

                                <option value="628">DISABLED: Gizell Naylor</option>

                                <option value="451">DISABLED: Heather Ross</option>

                                <option value="155">DISABLED: Helen Nisbet</option>

                                <option value="338">DISABLED: Holly Rosenberg</option>

                                <option value="5916">DISABLED: Imran Majid</option>

                                <option value="7756">DISABLED:Iqbal A. Buttar</option>

                                <option value="5009">DISABLED: IT God</option>

                                <option value="5337">DISABLED: Jacinta Greenwell</option>

                                <option value="756">DISABLED: Jason Joseph</option>

                                <option value="210">DISABLED: Jason Ying</option>

                                <option value="706">DISABLED: Jaspar Goodman</option>

                                <option value="851">DISABLED: Jean-Louis Etienne</option>

                                <option value="6723">DISABLED: Jennifer K. Oloafe</option>

                                <option value="5317">DISABLED: J Laporte</option>

                                <option value="310">DISABLED: Joana Spiess</option>

                                <option value="5194">DISABLED: Joel Bernstein</option>

                                <option value="5335">DISABLED: Jonalyn Aganon</option>

                                <option value="5727">DISABLED: Julie Millar</option>

                                <option value="5814">DISABLED: Julie Millar</option>

                                <option value="460">DISABLED: Julie Wallace</option>

                                <option value="5710">DISABLED: Justin Avinger</option>

                                <option value="437">DISABLED: Kellam Bimai</option>

                                <option value="1029">DISABLED: Kiara Ruxton</option>

                                <option value="5769">DISABLED: Lee Goddard</option>

                                <option value="5625">DISABLED: Liz Hoffman-Rothe</option>

                                <option value="6484">DISABLED: Louis Crust</option>

                                <option value="5602">DISABLED: Luke Alexander</option>

                                <option value="384">DISABLED: Marcus West</option>

                                <option value="7655">Disabled Margaret Desavino</option>

                                <option value="627">DISABLED: Maria Rosello</option>

                                <option value="8210">DISABLED: Maria Rusyeva</option>

                                <option value="262">DISABLED: Maria Urquia</option>

                                <option value="5334">DISABLED: Marissa Saucis</option>

                                <option value="5303">DISABLED: Marjon Carlos</option>

                                <option value="306">DISABLED: Marta Messias</option>

                                <option value="331">DISABLED: Marta Ortiz</option>

                                <option value="5053">DISABLED: Meredith Atkinson</option>

                                <option value="5109">DISABLED: Merryn Lamond</option>

                                <option value="758">DISABLED: Miguel Da Silva</option>

                                <option value="406">DISABLED: Misha Gale</option>

                                <option value="588">DISABLED: Mitchell Marion</option>

                                <option value="307">DISABLED: Nadia Akindes</option>

                                <option value="5206">DISABLED: Natasha Davis</option>

                                <option value="540">DISABLED: Natasha Davis</option>

                                <option value="466">DISABLED: Nora Chiriseri</option>

                                <option value="389">DISABLED: Paul Burton</option>

                                <option value="27">DISABLED: Precious Araneta</option>

                                <option value="887">DISABLED: QAXTcustomercare</option>

                                <option value="886">DISABLED: QAXTcustomercaremanager</option>

                                <option value="1003">DISABLED: Rebecca Grant</option>

                                <option value="605">DISABLED: Richard Lloyd-Williams</option>

                                <option value="75">DISABLED: Saho Hatae</option>

                                <option value="231">DISABLED: Salima Saadi</option>

                                <option value="826">DISABLED: Sally Lawrence</option>

                                <option value="5106">DISABLED: Sarah MacDonald</option>

                                <option value="6075">DISABLED: Seun Fajolu</option>

                                <option value="5226">DISABLED: Shantalaye Belle</option>

                                <option value="553">DISABLED: Shirley Wong</option>

                                <option value="1015">DISABLED: Simerdeep Padda</option>

                                <option value="5884">DISABLED: Sophie Bolingbroke</option>

                                <option value="661">DISABLED: Stacy Seabourne</option>

                                <option value="5153">DISABLED: Stephanie Richards</option>

                                <option value="858">DISABLED: Sunny Kalley</option>

                                <option value="787">DISABLED: Sven Gaede</option>

                                <option value="5057">DISABLED: Taigan Viera</option>

                                <option value="264">DISABLED: Tim Gagen</option>

                                <option value="497">DISABLED: Tunika Mkahanana</option>

                                <option value="5604">DISABLED: Wael Eltanikhy</option>

                                <option value="452">DISABLED: Yanni Slavov</option>

                                <option value="778">DISABLED: Yoka Sola</option>

                                <option value="582">DISABLED: Yuko Kobayashi</option>

                                <option value="7720">disable Jessica Sarfirstein</option>

                                <option value="584">DISBALED: Sheila Kearney</option>

                                <option value="5514">Dominika Dudek</option>

                                <option value="5584">Dominique Lecchi</option>

                                <option value="6564">Dominique Rollins</option>

                                <option value="7554">Donna Goncharov</option>

                                <option value="2299">Dustin Eastwood</option>

                                <option value="6134">Duytan Hoang</option>

                                <option value="7887">Ebony Duncan</option>

                                <option value="795">Eduardo Caviedes</option>

                                <option value="7184">Edward Simpson</option>

                                <option value="8527">Edwin Crockfords</option>

                                <option value="6460">Elissa Desani</option>

                                <option value="6146">Elizabeth Goldstein</option>

                                <option value="754">Elizabeth Russell</option>

                                <option value="5306">Ellis Gayton</option>

                                <option value="5142">Elysha McMahon</option>

                                <option value="6068">Emanuela Aru</option>

                                <option value="5610">Emilio Belem</option>

                                <option value="7682">Emily Day</option>

                                <option value="7544">Emily Grant</option>

                                <option value="7908">Emily Skinner</option>

                                <option value="7349">Emma Holmes</option>

                                <option value="830">Emma Marcombe</option>

                                <option value="831">Emma Marcombe</option>

                                <option value="6505">Emmanuel Croffie</option>

                                <option value="7909">Emma Sullivan</option>

                                <option value="125">Emperatriz M. Roque</option>

                                <option value="5049">Eric Kutsoati</option>

                                <option value="7104">Erin An</option>

                                <option value="803">Eskinder Ousman</option>

                                <option value="7564">Esther Akinwale</option>

                                <option value="7657">Evelis Fernandez</option>

                                <option value="5327">Ewa Larsen</option>

                                <option value="5373">Fahad Khan</option>

                                <option value="7911">Fallon Toomey</option>

                                <option value="7087">Fanny Herrera</option>

                                <option value="834">Faye Brothers</option>

                                <option value="5629">Fehran Rehman</option>

                                <option value="5409">Felix Hawkins-Ozer</option>

                                <option value="5322">Felix Rodriguez</option>

                                <option value="6170">Felix. Rodriguez</option>

                                <option value="5107">Fiona McCarthy</option>

                                <option value="856">Fiona Suarez</option>

                                <option value="6167">Frank Wales</option>

                                <option value="7086">Fred Lapolla</option>

                                <option value="7912">Gareth Daly</option>

                                <option value="5949">Gareth Griffiths</option>

                                <option value="8289">Gavin Peacock</option>

                                <option value="5979">Gawain Hammond</option>

                                <option value="6340">Gawayne Forbes</option>

                                <option value="7260">Gemma Connolly</option>

                                <option value="7871">Gennifer Stribling</option>

                                <option value="7107">Georgina Brown</option>

                                <option value="5759">Giacomo Capuana</option>

                                <option value="7483">Gianni Ceccarelli</option>

                                <option value="5656">Giedre Lukauskaite</option>

                                <option value="7071">Gilroy Gapare</option>

                                <option value="7406">Gina Ferrara</option>

                                <option value="5277">Giuseppe Vaninetti</option>

                                <option value="637">Glynn Perkin</option>

                                <option value="7124">Goobi Kyazze</option>

                                <option value="5144">Grace McNamara</option>

                                <option value="7094">Gregory Strangman</option>

                                <option value="8493">Gresmari Jimenez</option>

                                <option value="7913">Gurraj Bhachu</option>

                                <option value="294">Hanan Miloudi</option>

                                <option value="5063">Hannah Cately</option>

                                <option value="710">Hannah Stevenson</option>

                                <option value="8311">Hardeep Rayat</option>

                                <option value="6217">Hayley Martin</option>

                                <option value="5583">Hayley Owen</option>

                                <option value="6444">Heather Gibson</option>

                                <option value="101">Helen Baynes</option>

                                <option value="6182">Hoiyan Hoang</option>

                                <option value="952">Hollie Wilmot</option>

                                <option value="7787">Ian Mardon</option>

                                <option value="508">Ian Tansley</option>

                                <option value="510">Iman Leslie</option>

                                <option value="5917">Imran Majid</option>

                                <option value="7721">Ingrid Dalal</option>

                                <option value="7932">Iqbal Ahmed</option>

                                <option value="7806">Isaac Metlitsky</option>

                                <option value="7901">Isabelle Jouanine</option>

                                <option value="7139">ivan Chauveau De Quercize</option>

                                <option value="5515">Jacinta Clark</option>

                                <option value="7607">Jackie Smith</option>

                                <option value="7097">Jaco Dempsey</option>

                                <option value="5476">Jacqueline Chelliah</option>

                                <option value="7803">Jacqueline Vanderveer</option>

                                <option value="7574">Jacqui Brady-Chapman</option>

                                <option value="7358">Jacqui Roberts</option>

                                <option value="6156">James Laver</option>

                                <option value="6241">James Reynolds</option>

                                <option value="7645">James Robinson</option>

                                <option value="5450">James Witter</option>

                                <option value="7433">James Wyllie</option>

                                <option value="5559">Janae Donnelly</option>

                                <option value="6230">Jana McBride</option>

                                <option value="7805">Janelle Alfonso</option>

                                <option value="5676">Janel Molton</option>

                                <option value="5276">Janice Cornwall</option>

                                <option value="5114">Janzia Fiet</option>

                                <option value="7082">Jared Vian</option>

                                <option value="6534">Jason Lifshin</option>

                                <option value="547">Jason Tang</option>

                                <option value="5793">Jeffrey Farrell</option>

                                <option value="6416">Jenelle Boully</option>

                                <option value="7631">Jenna Peles</option>

                                <option value="7675">Jennifer Greenwood</option>

                                <option value="6819">Jennifer-Kemi Olaofe</option>

                                <option value="312">Jennifer Maugeri</option>

                                <option value="7695">Jennifer Vasquez</option>

                                <option value="5594">Jeremy Gentry</option>

                                <option value="6825">Jessica Cuk</option>

                                <option value="8076">Jessica D'Cruze</option>

                                <option value="6419">Jessica Jepson</option>

                                <option value="7743">Jessica Molina</option>

                                <option value="7797">Jessica Safirstein</option>

                                <option value="7902">Jessica West</option>

                                <option value="5718">Jill Ruthenberg</option>

                                <option value="6114">Jim Prendergast</option>

                                <option value="7101">Jim Reynolds</option>

                                <option value="8492">Jiten Mistry</option>

                                <option value="5305">Joana Oliveira Pinto</option>

                                <option value="6089">Joanna Kelly</option>

                                <option value="7910">Joanne Trotter</option>

                                <option value="533">Joelle Fagnon</option>

                                <option value="8341">Joel Oeiras</option>

                                <option value="5964">Joe Sullivan</option>

                                <option value="8080">Johan Lindstrom</option>

                                <option value="141">Jo Heller</option>

                                <option value="6724">John Buckley</option>

                                <option value="6605">John Kruchinsky</option>

                                <option value="5831">Jonathan Howells</option>

                                <option value="2054">Jorge Chavez</option>

                                <option value="5954">Josh Brito</option>

                                <option value="7562">Joshua Mendros</option>

                                <option value="7914">Josie Peach</option>

                                <option value="8312">Jot Grewal</option>

                                <option value="7490">Judit Lovasz</option>

                                <option value="7915">Judy Zhu</option>

                                <option value="5591">Julia Atkins</option>

                                <option value="7478">Junaid Shah</option>

                                <option value="7370">Justine Craig</option>

                                <option value="343">Kam Chovet</option>

                                <option value="5636">Karina Donnelly</option>

                                <option value="6656">Karina Rivasplata</option>

                                <option value="7660">Kassan Shaw</option>

                                <option value="7741">Kate Johanson</option>

                                <option value="8310">Kate O'Neill</option>

                                <option value="6815">Katherine Lees</option>

                                <option value="7807">Kathleen Ancheta</option>

                                <option value="5585">Kathryn Leithhead</option>

                                <option value="8206">Katia Ngaibino</option>

                                <option value="6710">Katie Green</option>

                                <option value="6098">Katie Sainsbury</option>

                                <option value="7812">Katy Blay</option>

                                <option value="6193">Kavita Verma</option>

                                <option value="7873">Keidra Hoskins</option>

                                <option value="8213">Kelly Dare</option>

                                <option value="261">Kelly Ijomanta</option>

                                <option value="5945">Kelvin Poon</option>

                                <option value="583">Kemi Osoliki</option>

                                <option value="8504">Kimberly Sels</option>

                                <option value="5255">Kim Byers</option>

                                <option value="8218">Kirstie Eells</option>

                                <option value="6655">Kirsty Attwood</option>

                                <option value="7679">Konstantia Anastasiou</option>

                                <option value="7238">Kristian Flint</option>

                                <option value="5424">Kristina Bobalova</option>

                                <option value="7916">Krystna Mailer</option>

                                <option value="537">L'Aire Omegna</option>

                                <option value="511">Lakeisha Williams</option>

                                <option value="6847">Lance Hayley</option>

                                <option value="7677">Lani Lam</option>

                                <option value="402">Latoya Medley</option>

                                <option value="74">Laura Taylor</option>

                                <option value="836">Laura Woodley</option>

                                <option value="5098">Lauren Bendeich</option>

                                <option value="816">Lauren Bibby</option>

                                <option value="543">Lauren Elrick</option>

                                <option value="7096">Lauren Kane</option>

                                <option value="7098">Lauren Moore</option>

                                <option value="7596">Lauren Page</option>

                                <option value="8397">Laurent Bananier</option>

                                <option value="8344">Lauretta Peterson</option>

                                <option value="7717">Leigh Ortiz</option>

                                <option value="6753">Leisl Amon</option>

                                <option value="5113">Letteisha Ramsey</option>

                                <option value="855">Lewis Buttress</option>

                                <option value="723">Leyla Pillai</option>

                                <option value="6463">Liana Gray</option>

                                <option value="8501">Lina Naim</option>

                                <option value="6727">Lina Piacquadio</option>

                                <option value="8069">Linh Ta</option>

                                <option value="6823">Lisa Brown</option>

                                <option value="7330">Lisa Heidemanns</option>

                                <option value="5513">Lisa Hemmings</option>

                                <option value="7095">Lisa Wilkinson</option>

                                <option value="6521">Lis Cashin</option>

                                <option value="5635">Liz Hoffmann-Rothe</option>

                                <option value="1023">Loga Jegede</option>

                                <option value="7842">Lorren Magee</option>

                                <option value="6720">Loryann Sanchez</option>

                                <option value="7371">Louise Monsour</option>

                                <option value="8377">Louise Nicola</option>

                                <option value="7374">Lou Von Booth</option>

                                <option value="7414">Lou Von Both</option>

                                <option value="5905">Lucelia Siqueira</option>

                                <option value="5619">Lucia Petek</option>

                                <option value="45">Lucie Cannon</option>

                                <option value="6558">Luis Buriola</option>

                                <option value="100">Lupe Puerta</option>

                                <option value="6735">Lydia Koukou</option>

                                <option value="6508">Lyzz Jones</option>

                                <option value="5600">Mahwish Ahmed</option>

                                <option value="7640">Manuel Suero</option>

                                <option value="7566">Maria Marami</option>

                                <option value="509">Marianna Satanas</option>

                                <option value="7078">Mariano Charquero</option>

                                <option value="8301">Maria Rusyaeva</option>

                                <option value="5338">Marie-Christel Gunga</option>

                                <option value="717">Marie Purcell</option>

                                <option value="224">Mario Muttenthaler</option>

                                <option value="188">Marisa Capaldi</option>

                                <option value="792">Mark Cheetham</option>

                                <option value="6174">Mark Harrison</option>

                                <option value="5597">Mark Knoop</option>

                                <option value="24">Mark Sebba</option>

                                <option value="6004">Marta Lagut</option>

                                <option value="6025">Martin Robertson</option>

                                <option value="6099">Mary-Lisa Fitzgerald</option>

                                <option value="7103">Marzena Majewska</option>

                                <option value="5170">Matt Dowson</option>

                                <option value="5662">Matt Doyle</option>

                                <option value="152">Matthew Atherfold</option>

                                <option value="8">Matt Ryall</option>

                                <option value="7921">Max Dudley</option>

                                <option value="7636">May Pierre</option>

                                <option value="7808">Meaghann shafer</option>

                                <option value="7785">Megan Evans</option>

                                <option value="7919">Megan Jackson</option>

                                <option value="5800">Melinda Smith</option>

                                <option value="854">Melinda Smith</option>

                                <option value="8518">Melissa Corbett</option>

                                <option value="5612">Melissa Friedman</option>

                                <option value="7758">Melissa Hartman</option>

                                <option value="2298">Melissa O'Neal</option>

                                <option value="5007">Melissa O'Neal</option>

                                <option value="757">Meliza Brink</option>

                                <option value="752">Meliza Brint</option>

                                <option value="6726">Merisha Bennett</option>

                                <option value="5511">Mia Biagio</option>

                                <option value="299">Michaela Vancova</option>

                                <option value="8257">Michael Gargano</option>

                                <option value="850">Michael Martins</option>

                                <option value="7722">Michael Monte</option>

                                <option value="593">Michael Moshiri </option>

                                <option value="7669">Mikel Smith</option>

                                <option value="853">Mike Matania</option>

                                <option value="7180">Mike Smith</option>

                                <option value="7653">Minesh Patel</option>

                                <option value="7506">Ming Sun</option>

                                <option value="7656">Mirna Bolanos</option>

                                <option value="7903">Missica Ewans</option>

                                <option value="7654">Mizra Azad</option>

                                <option value="5992">Mohammed Asif</option>

                                <option value="753">Mohammed Said</option>

                                <option value="7316">Molly Monroe</option>

                                <option value="6824">Monique Di Paola</option>

                                <option value="5546">Nadine Joyce</option>

                                <option value="313">Naomi Jordan</option>

                                <option value="5336">Natalie Cross</option>

                                <option value="857">Natalie Hunt</option>

                                <option value="7710">Natalie La Torre</option>

                                <option value="7676">Natalie La Toure</option>

                                <option value="301">Nathalie Thomson</option>

                                <option value="6195">Natisha Liversidge</option>

                                <option value="5960">Neil Micallef</option>

                                <option value="5036">Nicola Dunn</option>

                                <option value="7090">Nicola Goodwin Reynolds</option>

                                <option value="869">Nicole Butler</option>

                                <option value="8256">Nicole Doebel</option>

                                <option value="32">Nigel Stephens</option>

                                <option value="99">Nikki Irvine</option>

                                <option value="6179">Norah Thenn</option>

                                <option value="93">Nuno Vidal</option>

                                <option value="5323">Olga Orellana</option>

                                <option value="7643">Oliver Miller</option>

                                <option value="711">Olivia Morton</option>

                                <option value="330">Olivia Young</option>

                                <option value="7136">Orla Scanlan</option>

                                <option value="6005">Patricia Li</option>

                                <option value="6694">Patrick Akosim</option>

                                <option value="6535">Patrick Flynn</option>

                                <option value="7276">Patrick Flynn</option>

                                <option value="5217">Patti Worth</option>

                                <option value="7032">Paul Jones</option>

                                <option value="19">Paul Layton</option>

                                <option value="5131">Paulo Castro</option>

                                <option value="5048">Paul Page</option>

                                <option value="677">Perla Rodriguez</option>

                                <option value="779">Peta Dunne</option>

                                <option value="6244">Peter Corlett</option>

                                <option value="529">Peter Donald</option>

                                <option value="5695">Peter Norval</option>

                                <option value="6143">Peter Reading</option>

                                <option value="5900">Peter Sergeant</option>

                                <option value="6433">Peter Smith</option>

                                <option value="7011">Petra Clark</option>

                                <option value="7479">Phil Bebbington</option>

                                <option value="7651">Phil Taylor</option>

                                <option value="8059">Pip Mckee</option>

                                <option value="5616">Pooja Sachdeva</option>

                                <option value="5608">Priscilla Lopez</option>

                                <option value="7146">Qiana Davis</option>

                                <option value="6420">Rachael Scully</option>

                                <option value="5725">Rachel Cartmail</option>

                                <option value="629">Rakhee Shori</option>

                                <option value="8336">Rana Hasan</option>

                                <option value="896">Rasha McMillon</option>

                                <option value="5673">Rebecca Davies</option>

                                <option value="6378">Reece Crisp</option>

                                <option value="7092">Reece Johnson</option>

                                <option value="7948">Reecha Kaher</option>

                                <option value="7102">Rhiannon Thomas</option>

                                <option value="7680">Ricardo Vierra</option>

                                <option value="5974">Richard Clamp</option>

                                <option value="8516">Richard Eaton</option>

                                <option value="5073">Richard Jones</option>

                                <option value="667">Richard Lloyd-Williams</option>

                                <option value="7179">Richard Manley</option>

                                <option value="5232">Richard Patterson</option>

                                <option value="5218">Rita Braby</option>

                                <option value="6083">Rita Manning</option>

                                <option value="7147">Roberta Farrar</option>

                                <option value="6734">Roberto Parraga-Sanchez</option>

                                <option value="5428">Robin Edwards</option>

                                <option value="6814">Rochelle Mackey</option>

                                <option value="5717">Roman Ripoll</option>

                                <option value="7744">Ronisha Vannoy</option>

                                <option value="808">Rosanna Saunders</option>

                                <option value="5422">Rosemary Gow</option>

                                <option value="7905">Rose Rossiter</option>

                                <option value="718">Ross Mason</option>

                                <option value="178">Rotimi Akinyemiju</option>

                                <option value="160">Roy Mohanan</option>

                                <option value="5545">Ruhana Begum</option>

                                <option value="6073">Russell Blandamer</option>

                                <option value="5197">Russell Bonifay</option>

                                <option value="8486">Ryan Wilson</option>

                                <option value="7906">Saba Trew</option>

                                <option value="6380">sagal Suleiman</option>

                                <option value="7567">Salma Zannath</option>

                                <option value="7326">Samantha Homer</option>

                                <option value="7917">Sam Cardy</option>

                                <option value="7093">Sam Gray</option>

                                <option value="8008">Sam Lobban</option>

                                <option value="703">Sammie Nguyen</option>

                                <option value="8048">Samuel Vrech</option>

                                <option value="8514">Sarabjit Kaur</option>

                                <option value="898">Sarah Apodaca</option>

                                <option value="5358">Sarah Camp</option>

                                <option value="7100">Sarah Carter</option>

                                <option value="7091">Sarah English</option>

                                <option value="5421">Sarah Hopwood</option>

                                <option value="5714">Sarah-Jane Thomson</option>

                                <option value="6809">Sarah Lilley</option>

                                <option value="750">Sara Robinson</option>

                                <option value="7918">Sarina Mcmahon</option>

                                <option value="5243">Sasha Kaila</option>

                                <option value="5508">Scarlett Haynes</option>

                                <option value="6034">Sean Byrne</option>

                                <option value="6560">Sean O'Keefe</option>

                                <option value="732">Sebastian Mitchell</option>

                                <option value="6712">Sebastian Ostman</option>

                                <option value="6902">Selina Kantepudi</option>

                                <option value="6149">Sendy Atenda</option>

                                <option value="7658">Serena Robinson</option>

                                <option value="5565">Sey Ylimaz</option>

                                <option value="6733">Shabe Ravzi</option>

                                <option value="5896">Shadarevian Kayane</option>

                                <option value="6258">Shamanie Terrelonge</option>

                                <option value="7708">Shari Morales</option>

                                <option value="8214">Sharlayne Flanders</option>

                                <option value="8465">Sheila Jackson</option>

                                <option value="5533">Shelley Bailey</option>

                                <option value="5611">Sherry Alexander</option>

                                <option value="6120">Shina Ameen</option>

                                <option value="6827">Shrikanth Nimmakayala</option>

                                <option value="6883">Sian Meadowcroft</option>

                                <option value="5579">Siannon Nelson</option>

                                <option value="5234">Silvia Gomez</option>

                                <option value="6205">Simon Franklin</option>

                                <option value="8205">Sofia Kontogianni</option>

                                <option value="6506">Sonia Silva</option>

                                <option value="6228">Sonya Cameron</option>

                                <option value="5887">Sophie Bolingbroke</option>

                                <option value="257">Stephane Royer</option>

                                <option value="8426">Stephanie Grech</option>

                                <option value="8404">Stephanie Grech</option>

                                <option value="5251">Stephanie Phillips</option>

                                <option value="7664">Stephen Rowland</option>

                                <option value="458">Steve Brador</option>

                                <option value="43">Steve Crease</option>

                                <option value="18">Steven Russell</option>

                                <option value="931">Steve Purkis</option>

                                <option value="813">Steve Zaluski</option>

                                <option value="6086">Suma Binger</option>

                                <option value="7555">Susan Morgan</option>

                                <option value="5509">Susannah Young</option>

                                <option value="5815">Suzanne Mathews</option>

                                <option value="5253">Suzie McKeever</option>

                                <option value="8273">Suzy Rosser</option>

                                <option value="796">Sylvain Michel</option>

                                <option value="847">Tajinder KhunKhun</option>

                                <option value="7140">Tamer Zaky</option>

                                <option value="686">Tanisha Harley</option>

                                <option value="6231">Tarryn Abel</option>

                                <option value="7761">Taylor Leone</option>

                                <option value="315">Teresa Brown</option>

                                <option value="7896">Tesheema Cooper</option>

                                <option value="5980">Tessa Hayden</option>

                                <option value="957">Theresa Austin</option>

                                <option value="8495">Tiara Slade</option>

                                <option value="935">Tim Fenner</option>

                                <option value="7177">Tim Quayle</option>

                                <option value="624">Tom Taylor</option>

                                <option value="5957">Tony Filbert</option>

                                <option value="8441">Tony Gilks</option>

                                <option value="5439">Tony Hoang</option>

                                <option value="7770">Tyshona Wiley</option>

                                <option value="555">Urata Qehaja</option>

                                <option value="8212">Vanessa Muir</option>

                                <option value="8347">Varsha Maharaj</option>

                                <option value="8475">Vas Donbosco</option>

                                <option value="7698">Verletta McCutchen</option>

                                <option value="5054">Victoria Bradshaw</option>

                                <option value="6706">Vinay Patil</option>

                                <option value="875">Vincent Kurutza</option>

                                <option value="7920">Vivian Walker</option>

                                <option value="6229">Vivien Doumouliakas</option>

                                <option value="6446">Warren Yu</option>

                                <option value="5055">Wayne Hoang</option>

                                <option value="6071">Wintom Temesgen</option>

                                <option value="5628">Yana Yarutska</option>

                                <option value="5210">Yasmin Lashley</option>

                                <option value="6461">Yessenia San Miguel</option>

                                <option value="7673">Ylva Julihn</option>

                                <option value="7317">Yoko Honda</option>

                                <option value="7141">zainab raja</option>

                                <option value="863">Zoe Ryszewski</option>

                        </select>
                    </td>
                </tr>
                <tr>
                    <td>&nbsp;</td>
                    <td colspan="2">Operator change will be completely ignored when changing the Size.</td>
                </tr>
                <tr>
                    <td colspan="3"></td>
                <tr>

                <tr height="22">
                    <td align="right">&nbsp;&nbsp;Source:</td>
                    <td align="left" colspan="2">
                        <select id="new_reservation_source_id" name="new_reservation_source_id" class="date">
                            <option value="0">-------------------</option>

                                <option value="1">Notes</option>

                                <option value="2">Upload Preview</option>

                                <option value="3">LookBook</option>

                                <option value="4">Press</option>

                                <option value="5">Website</option>

                                <option value="6">Sold Out</option>

                                <option value="7">Reorder</option>

                                <option value="8">Recommendation</option>

                                <option value="9">Preview Files</option>

                                <option value="10">Event</option>

                                <option value="12">Email</option>

                                <option value="13">Appointment</option>

                                <option value="14">Charge and Send</option>

                                <option value="11">Unknown</option>

                        </select>
                    </td>
                </tr>

                <tr>
                    <td colspan="3"></td>
                <tr>
                <tr height="22" valign="top">
                    <td align="right">&nbsp;&nbsp;Note:</td>
                    <td align="left" colspan="2">
                        <textarea name="notes" rows="4" cols="25">

                        </textarea>
                    </td>
                </tr>
                <tr>
                    <td colspan="3"></td>
                <tr>
                <tr>
                    <td width="90"></td>
                    <td width="145"></td>
                    <td width="10"></td>
                <tr>
                <tr>
                    <td align="right" colspan="3"><input type="submit" name="submit" value="Submit &raquo;" class="button"></td>
                <tr>
            </form>
            </table>
            </div>
        </div>

        <div id="historyLayer" style="position:absolute; left:0px; top:0px; visibility:hidden; z-index:1000; background-color:#ccc; z-index:1000; padding-left:3px; padding-bottom:3px;">

            <div id="historyLayerContent" style="border:1px solid #666666; background-color: #fff; padding: 10px; z-index:1001"></div>

        </div>

        <script type="text/javascript">

        var formsubmit = 0;

        function uploadSubmit(which){
            if (formsubmit == 0){
                formsubmit = 1;
                document[which].action.value = "Upload";
                document[which].submit();
            }
        }

        function deleteSubmit(which){
            if (formsubmit == 0){
                formsubmit = 1;
                document[which].action.value = "Delete";
                document[which].submit();
            }
        }

        function showDiv(which){

    layobj = new layObj(type,which);

    layobj.ref.visibility = "visible";

}



function hideDiv(which){

    layobj = new layObj(type,which);

    layobj.ref.visibility = "hidden";

}

        function init() {type = chk();}



function chk(){

   var brow = 0;



   if (document.getElementById){ brow = 0; } // dom

   else if (document.all) { brow = 2; } // ie < 6 + quirks

   else if (document.layers) { brow = 1; } // ns < 6 quirks

   else { brow = 0; }

   return brow;

}

init();

        function MM_findObj(n, d) { // v4.01

  var p,i,x;  if(!d) d=document;

if((p=n.indexOf("?"))>0&&parent.frames.length) {

    d=parent.frames[n.substring(p+1)].document; n=n.substring(0,p);}

  if(!(x=d[n])&&d.all) x=d.all[n]; for (i=0;!x&&i<d.forms.length;i++)

x=d.forms[i][n];

  for(i=0;!x&&d.layers&&i<d.layers.length;i++)

x=MM_findObj(n,d.layers[i].document);

  if(!x && d.getElementById) x=d.getElementById(n); return x;

}

function layObj(type,div,nest,nest2){

   if (type == 2) {this.ref = eval('document.all.' + div + '.style');}

   else if (type == 1) {

        if (nest!=null){

         if (nest2!=null){this.ref = eval('document.layers.'+nest2+'.document.layers.'+nest+'.document.'+div);}

         else{this.ref = eval('document.layers.' + nest + '.document.' + div);}

        }

        else{this.ref = eval('document.' + div);}

    } // eval('document.layers[div]');} seems to be wrong??

   else { this.ref = document.getElementById(div).style;} // default to dom

}

        function loadCategories(channel_id, whatToChangeTo){

            theForm = document.editForm;

            if (whatToChangeTo != ""){
                toPrices= eval(olist[channel_id][whatToChangeTo]);

                for(i=theForm.ordering.options.length;i>=0;i--){
                theForm.ordering.options[i]=null;
                }
                for(i=0;i<toPrices.length;i++){
                theForm.ordering.options[theForm.ordering.options.length]=new Option(toPrices[i][1], toPrices[i][1],false, false);
                }
            }
        }

        function showMoveLayer(channel_id, varid, specialorderid, curpos){

            loadCategories(channel_id, varid);

            document.moveForm.special_order_id.value = specialorderid;
            document.moveForm.variant_id.value = varid;
            document.moveForm.current_position.value = curpos;

            layobj = new layObj(type,"moveLayer");

            var leftpos = window.event.clientX + document.body.scrollLeft;
            var toppos =  window.event.clientY + document.body.scrollTop;


            layobj.ref.left = leftpos - 400;
            layobj.ref.top = toppos - 130;


            layobj.ref.visibility = "visible";
        }


        function showEditLayer(channel_id, varid, specialorderid, expday, expmonth, expyear, curpos, notes, operator, can_update_operator, source_id, e){

            var evt = window.event ? window.event : e;

            expyear = (expyear * 100) / 100;
            expday = (expday * 100) / 100;
            expmonth = (expmonth * 100) / 100;

            ben = expyear - 2003;

            //alert(ben);

            loadCategories(channel_id, varid);

            document.editForm.special_order_id.value = specialorderid;
            document.editForm.variant_id.value = varid;
            document.editForm.current_position.value = curpos;

            document.editForm.notes.value = notes;

            document.editForm.ordering.options[''+(curpos-1)+''].selected = true;


            document.editForm.expireDay.options[''+(expday+1)+''].selected = true;
            document.editForm.expireMonth.options[''+(expmonth+1)+''].selected = true;

            if (expyear > 0) {
                document.editForm.expireYear.options[''+(expyear - 2008)+''].selected = true;
            }
            else {
                document.editForm.expireYear.options[0].selected = true;
            }


            whichone = sizes[channel_id][varid];
            document.editForm.changeSize.options[whichone].selected = true;

            document.editForm.newOperator.value = operator;
            document.editForm.newOperator.disabled = can_update_operator == 1 ? false : true;

            document.editForm.special_order_id.value = specialorderid;
            document.editForm.variant_id.value = varid;

            // find the position for the Reservation Source in the list
            var reservation_sources = document.getElementById('new_reservation_source_id').options;
            for ( var idx = 0; idx < reservation_sources.length; idx++ ) {
                if ( reservation_sources[idx].value == source_id ) {
                    reservation_sources[idx].selected   = true;
                    break;
                }
            }

            layobj = new layObj(type,"editLayer");

            var leftpos = evt.clientX + document.body.scrollLeft;
            var toppos =  evt.clientY + document.body.scrollTop;


            layobj.ref.left = leftpos - 440;
            layobj.ref.top = toppos - 130;


            layobj.ref.visibility = "visible";
        }

        var olist = new Array();
        var sizes = new Array();

        olist[1] = new Array();
        sizes[1] = new Array();
        olist[2] = new Array();
        sizes[2] = new Array();
        olist[3] = new Array();
        sizes[3] = new Array();
        olist[4] = new Array();
        sizes[4] = new Array();
        olist[5] = new Array();
        sizes[5] = new Array();
        olist[6] = new Array();
        sizes[6] = new Array();





                olist[1][34553] = [[0,"   "]];

                sizes[1][34553] = 0;



                olist[1][34554] = [[0,"   "]];

                sizes[1][34554] = 1;



                olist[1][34555] = [[0,"   "]];

                sizes[1][34555] = 2;



                olist[1][34556] = [[0,"   "]];

                sizes[1][34556] = 3;



                olist[1][34557] = [[0,"   "]];

                sizes[1][34557] = 4;



                olist[1][34558] = [[0,"   "]];

                sizes[1][34558] = 5;






                olist[3][34553] = [[1,"1"],[2,"2"],[3,"3"],[4,"4"],[0,"   "]];

                sizes[3][34553] = 0;



                olist[3][34554] = [[1,"1"],[2,"2"],[3,"3"],[4,"4"],[0,"   "]];

                sizes[3][34554] = 1;



                olist[3][34555] = [[1,"1"],[2,"2"],[3,"3"],[4,"4"],[0,"   "]];

                sizes[3][34555] = 2;



                olist[3][34556] = [[1,"1"],[2,"2"],[0,"   "]];

                sizes[3][34556] = 3;



                olist[3][34557] = [[1,"1"],[2,"2"],[0,"   "]];

                sizes[3][34557] = 4;



                olist[3][34558] = [[1,"1"],[2,"2"],[0,"   "]];

                sizes[3][34558] = 5;




        function showOperatorHistory(reservation_id, top, left) {

            layobj                  = new layObj(type,"historyLayer");
            layobj.ref.left         = ( left - 158 ) + 'px';
            layobj.ref.top          = ( top - 162 ) + 'px';
            layobj.ref.visibility   = "visible";

            $('#historyLayerContent')[0].innerHTML = '<img src="/images/bigrotation2.gif">';
            var response_html = '';

            $.ajax({
                'url':        '/AJAX/ReservationOperatorLog',
                'data':       {
                    'reservation_id': reservation_id
                },
                'async':      false,
                'type':       'GET',
                'success':    function(response){
                    json = eval("(" + response + ")");

                    if ( json.result == 'OK' ) {

                        response_html = '<table class="data" cellpadding="0" cellspacing="0" border="0"><tr style="background-color: #fff"><td colspan="4"><b>Operator History</b></td><td valign="top" align="right"><a href="javascript://" onClick="hideDiv(\'historyLayer\')">Close</a></td></tr><tr><td class="tableHeader" style="padding-left:5px; padding-right: 5px">Operator</td><td class="tableHeader" style="padding-left:5px; padding-right: 5px">Date/Time</td><td class="tableHeader" style="padding-left:5px; padding-right: 5px">From</td><td class="tableHeader" style="padding-left:5px; padding-right: 5px">To</td><td class="tableHeader" style="padding-left:5px; padding-right: 5px">Status</td></tr><tr><td colspan="5" class="dividerHeader"></td></tr>';

                        for ( row in json.data ) {

                            response_html = response_html
                                + '<tr>'
                                + '<td style="padding-left:5px; padding-right: 5px">' + json.data[row].operator + '</td>'
                                + '<td style="padding-left:5px; padding-right: 5px">' + json.data[row].created_timestamp + '</td>'
                                + '<td style="padding-left:5px; padding-right: 5px">' + json.data[row].from_operator + '</td>'
                                + '<td style="padding-left:5px; padding-right: 5px">' + json.data[row].to_operator + '</td>'
                                + '<td style="padding-left:5px; padding-right: 5px">' + json.data[row].reservation_status + '</td>'
                                + '</tr>'
                                + '<tr><td colspan="5" class="divider"></td></tr>';

                        }

                        response_html = response_html + '</table>';
                    }

                }
            });

            if ( response_html != '' ) {
                $('#historyLayerContent')[0].innerHTML = response_html;
            } else {
                layobj.ref.visibility = "hidden";
                alert( 'There was a problem loading the history, please try again.' );
            }

        }

        jQuery(document).ready(function(){
           $(".classOperatorHistory").click(function(e){
              showOperatorHistory( e.target.id, e.pageY, e.pageX );
           });
        })

    </script>






        </div>
    </div>

    <p id="footer">    xTracker-DC  (2012.06.01.41.gc0e8ddc / IWS phase 2 / 2012-05-16 09:43:31). &copy; 2006 - 2012 NET-A-PORTER
</p>


</div>

    </body>
</html>

