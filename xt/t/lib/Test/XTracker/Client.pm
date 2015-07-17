package Test::XTracker::Client;

=head1 NAME

Test::XTracker::Client - Test::XTracker::Mechanize role to return pages as data

=head1 DESCRIPTION

Test::XTracker::Mechanize role to return pages as data

=head1 SYNOPSIS

 # Do your mechanize stuff
 my $mech = Test::XTracker::Mechanize->new;
 $mech->do_login;
 $mech->get_ok( '/GoodsIn/Putaway?process_group_id=740969' );

 # And use the as_data() method on pages that support it...
 my $data = $mech->as_data();

=cut

use NAP::policy qw ( test role tt );

use List::MoreUtils qw(first_index);

use JSON;

use Test::XTracker::LoadTestConfig;
use XTracker::Config::Local qw(config_var);
my $dc_name = config_var('DistributionCentre','name');

use Test::XT::Rules::Solve;

use XTracker::Database qw( schema_handle );
my $schema = schema_handle();


=head1 OVERVIEW

If you're writing Mechanize based tests for XTracker, you're probably going to
want to use information from a page in your test. This might be which items are
being displayed on a product page, it might be an error or status message after
an action, or it might be retrieval of a difficult-to-find-via-the-DB process ID
- of which XTracker has many.

Existing code in the DB uses a combination of XPath commands and regular
expressions to parse pages. Which is not a bad approach, but many tests reinvent
the wheel. If a page, that several tests access, changes then you need to change the
parsing code in several places. If you're trying to parse a given page, you may
not be aware of existing parsing code, or know how to find it in the codebase.
Many pages incorporate very similar elements, but it may not be obvious to you
that parsing code for an entirely different page can be reused.

Basically then: we keep reinventing the wheel and wasting everyone's time.

L<Test::XTracker::Client> provides parsing of XTracker pages in one place, with
a simple interface and lots of opportunity for code reuse. It allows a developer
to use existing element-parsing routines to quickly create parsing templates,
which in turn allows someone writing a test around a page to pull out data
quickly and reliably from a page.

=head1 HOW IT WORKS

This class is a role which is consumed by L<Test::XTracker::Mechanize>. It
provides an C<as_data> method which attempts to parse the output of
C<<$mech->content>> using XPath, into a Perl data structure.

C<as_data()> parses pages according to B<specifications>. These specifications
live in C<%page_definitions> in this class. Specifications are either specified
by matching the URL, or you can specify them directly:

 $mech->get('/GoodsIn/Putaway');

 my $data = $mech->as_data(); # Picks 'GoodsIn/Putaway/List' by URL matching
 my $data = $mech->as_data('GoodsIn/Putaway/List'); # Equivalent

Specifications provide a set of hash-keys that the data will be laid out using,
with each of those having an XPath location from which the data is retrieved,
and a method that provides the transform. eg:

    # Specification name
    'GoodsIn/Putaway/List' => {

        # URL matching
        auto_match    => qr!^/GoodsIn/Putaway/?$!,

        # Actual specification...
        specification => {

            # Put the following data in the key 'nap_table'
            nap_table => {

                # Select this XPath address
                location  => '//div[@class="tabInsideWrapper"]ervations => {
                location  => '//div[@id="tabContainer"]',
                transform => 'reservation_view_live_reservations',
            }
table[1]',

                # And pass it to 'multi_table' (_xclient_multi_table)
                transform => 'multi_table',
            }
        }
    }

=head1 PUBLIC METHODS

=cut

# Here we define which pages we can parse, and how we can parse them. The key
# here is both a description, and can be used as as_data()'s sole argument to
# force a certain parsing of a page.
#
# main structure:
#   auto_match    - match against path_query for guessing appropriate spec
#   specification - each key represents a key of the returned hashref
#
# specification:
#   Each key represents a key that will be passed in to the returned hashref.
#   Inside that, 'location' is the XPath of the node you want to extract data
#   from, and 'transform' is the method that pulls the data out of that node.
#   The method name in 'transform' will have '_xclient_' prefixed to it, and
#   the method itself expects the node as its argument
#

# HEY!!!!
# IF YOU ADD A NEW PAGE SPEC, ADD A SIMPLE TEST IN t/20-units/test_client/.
# IT WILL TAKE YOU 20 SECONDS AND HELP STOP THE EVENTUAL HEAT DEATH OF THE
# UNIVERSE. LOOK AT THE EXAMPLE TESTS ALREADY THERE AND CONSIDER READING THE
# DOCUMENTATION FOR t/lib/Test/XTracker/Client/SelfTest.

# Please keep me in alphabetical order
our %page_definitions = (
    '/-/-/OrderView' => {
        auto_match    => qr!^/(\w+)/(\w+)/OrderView\?order_id=!,
        specification => {
            meta_data => {
                location  => "id('contentRight')",
                transform => 'customer_care_order',
            },
            shipment_items => {
                location  => '//table[starts-with(@class,"order_view_shipment_item")]',
                transform => 'customer_care_order_shipment_items',
            },
            voucher_usage_history => {
                location  => '//table[starts-with(@class,"order_view_shipment_item")]',
                transform => 'customer_care_order_voucher_history',
                optional  => 1
            },
        }
    },
    '/-/-/CustomerView' => {
        auto_match    => qr!^/(\w+)/(\w+)/CustomerView\?customer_id=!,
        specification => {
            page_data => {
                location  => "id('contentRight')",
                transform => 'customer_view',
            },
            new_high_value => {
                location  => "id('marketing_high_value')",
                transform => 'parse_cell',
                optional  => 1,
            },
            new_high_value_image => {
                location  => "id('marketing_high_value_image')",
                transform => 'src_attribute',
                optional  => 1,
            },
        }
    },
    '/-/-/OrderLog' => {
        auto_match    => qr!^/(\w+)/(\w+)/OrderLog\?orders_id=!,
        specification => {
            page_data => {
                location  => "id('contentRight')",
                transform => 'order_status_log',
            },
        }
    },
    '/-/-/AuthorisePayment' => {
        auto_match    => qr!^/(\w+)/(\w+)/AuthorisePayment\??.*!,
        specification => {
            billing_details => {
                location  => "id('billing_details')",
                transform => 'parse_vertical_table',
            },
            payment_details => {
                location  => "id('payment_details')",
                transform => 'parse_vertical_table',
            },
            pre_auth_details=> {
                location  => "id('existing_pre_auth_details')",
                transform => 'parse_vertical_table',
                optional  => 1,
            },
            cancelled_pre_auth_log => {
                location  => "id('cancelled_pre_auth_log')",
                transform => 'parse_table',
                optional  => 1,
            },
            replacement_cancelled_pre_auth_log => {
                location  => "id('cancelled_pre_auth_log_replacement')",
                transform => 'parse_table',
                optional  => 1,
            },
            psp_form_payment_session_id => {
                location  => '//form[@id="editPayment"]//input[@name="paymentSessionId"]/@value',
                transform => 'get_value',
            },
            psp_form_redirect_url => {
                location  => '//form[@id="editPayment"]//input[@name="redirectUrl"]/@value',
                transform => 'get_value',
            },
            psp_form_customer_id => {
                location  => '//form[@id="editPayment"]//input[@name="customerId"]/@value',
                transform => 'get_value',
            },
            psp_form_site => {
                location  => '//form[@id="editPayment"]//input[@name="site"]/@value',
                transform => 'get_value',
            },
            psp_form_admin_id => {
                location  => '//form[@id="editPayment"]//input[@name="adminId"]/@value',
                transform => 'get_value',
            },
            psp_form_keep_card => {
                location  => '//form[@id="editPayment"]//input[@name="keepCard"]/@value',
                transform => 'get_value',
            },
            psp_form_saved_card => {
                location  => '//form[@id="editPayment"]//input[@name="savedCard"]/@value',
                transform => 'get_value',
            },
        }
    },
    '/Admin/EmailTemplates' => {
        auto_match     => qr{^/Admin/EmailTemplates$},
        specification => {
            email_templates => {
                location  => '//table[@id="admin_email_templates"][1]',
                transform => 'parse_table',
            },
        },
    },
    '/Admin/EmailTemplates/Edit' => {
        auto_match     => qr{^/Admin/EmailTemplates/Edit/\d+$},
        specification => {
            template_log => {
                location => "id('template_log')",
                transform => 'parse_table',
            },
            template_content => {
                location  => "id('template_edit_textbox')",
                transform => 'get_value',
            },
        },
    },
    '/Admin/StickyPages' => {
        auto_match     => qr{^/Admin/StickyPages$},
        specification => {
            sticky_pages => {
                location => q{//form[@name='remove_sticky_pages']/table[1]},
                transform => 'parse_table',
            },
        },
    },

    '/Admin/FraudRules' => {
        auto_match     => qr{^/Admin/FraudRules$},
        specification => {
            switches => {
                location => "id('fraud_rules_switch')",
                transform => 'parse_table',
            },
            switch_log => {
                location => "id('fraud_rules_switch_log')",
                transform => 'parse_table',
            },
        },
    },

    '/Admin/UserAdmin/Profile' => {
        auto_match      => qr{^/Admin/UserAdmin/Profile},
        specification   => {
            account_details => {
                location    => 'id("user_account_details")',
                transform   => 'parse_vertical_table',
            },
            authorisation   => {
                location    => 'id("user_profile_authorisation")',
                transform   => 'parse_user_profile_authorisation',
            },
        },
    },

    '/Admin/ACLAdmin' => {
        auto_match      => qr{^/Admin/ACLAdmin},
        specification   => {
            page_data => {
                location    => 'id("acl_admin_setting")',
                transform   => 'parse_formrow_fields',
            },
        },
    },

    '/Admin/UserRoles'  => {
        auto_match  => qr{^/Admin/UserRoles$},
        specification   => {
            available_roles => {
                location    => '//form[@id="userroles"]//select[@id="availableroles"]',
                transform   => 'parse_select_element',
            },
            new_roles   => {
                location    => '//form[@id="userroles"]//select[@id="newroles"]',
                transform   => 'parse_select_element',
            },
        },
    },

    '/Admin/ACLMainNavInfo' => {
        auto_match      => qr{^/Admin/ACLMainNavInfo},
        specification   => {
            page_data => {
                location    =>"id('tree__node')",
                transform   => 'acl_tree_node',
            },
        },
    },

    'CustomerCare/CustomerSearch/HoldShipment' => {
        auto_match => qr!^/CustomerCare/CustomerSearch/HoldShipment\?order_id=\d+(\&shipment_id=\d+|)$!,
        specification => {
            error_page => {
                location  => "id('shipment_on_hold_error_id')",
                transform => 'get_value',
                optional  => 1,
            },
            multi_shipment_table => {
                location   => "id('select_shipment_table')",
                transform  => 'parse_table',
                optional   => 1,
            },
            hold_details => {
                location    => "id('shipment_hold_details')",
                transform   => 'parse_first_vertical_table',
                optional    => 1,
            },
        },
    },


    'CustomerCare/OrderSearch/Results' => {
        auto_match    => qr!^/CustomerCare/OrderSearch/Results!,
        specification => {
            results => {
                location  => 'id("order_search_results")',
                transform => 'parse_table',
            }
        }
    },
    'CustomerCare/OrderSearch/CancelShipmentItem' => {
        auto_match    => qr!^/CustomerCare/(Customer|Order)Search/CancelShipmentItem\?orders_id=\d+\&shipment_id=\d+$!,
        specification => {
            cancel_item_form => {
                location  => '//form[@name="cancelForm"]',
                transform => 'customercare_cancel_item_form',
            },
            email_form => {
                location  => 'id("customer_email")',
                transform => 'parse_vertical_table',
                optional  => 1,
            },
        },
    },
    'CustomerCare/OrderSearch/CancelOrder' => {
        auto_match    => qr!^/CustomerCare/(Customer|Order)Search/CancelOrder(\?orders_id=\d+)?$!,
        specification => {
            order_details => {
                location  => 'id("order_details")',
                transform => 'parse_vertical_table',
            },
            reason_for_cancellation => {
                location  => 'id("cancellation_reason")',
                transform => 'parse_vertical_table',
            },
            email_form => {
                location  => 'id("customer_email")',
                transform => 'parse_vertical_table',
                optional  => 1,
            },
            reason_dropdown => {
                location  => 'id("cancel_reason_id")',
                transform => 'parse_select_element_with_groups',
                optional  => 1,
            },
        },
    },
    'CustomerCare/OrderSearch/ChangeCountryPricing' => {
        auto_match    => qr!^/CustomerCare/(Customer|Order)Search/ChangeCountryPricing\?.*!,
        specification => {
            shipment_details => {
                location  => 'id("shipment_details")',
                transform => 'parse_vertical_table',
            },
            item_list => {
                location  => 'id("list_of_items")',
                transform => 'parse_check_pricing_product_list_table',
            },
            email_form => {
                location  => 'id("customer_email")',
                transform => 'parse_vertical_table',
                optional  => 1,
            },
        },
    },
    'CustomerCare/OrderSearch/SizeChangeConfirmation' => {
        auto_match    => qr!^/CustomerCare/(Customer|Order)Search/CancelShipmentItem\?orders_id=\d+\&shipment_id=\d+\&status=1!,
        specification => {
        change_result => {
            location  => 'id("contentRight")',
        transform => 'customer_care_confirmation_message'
        }
        }
    },
    'CustomerCare/OrderSearch/SizeChange' => {
        auto_match    => qr!^/CustomerCare/(Customer|Order)Search/SizeChange\?order_id=\d+\&shipment_id=\d+$!,
        specification => {
            size_change_form => {
                location  => '//form[@name="sizeChangeForm"]',
                transform => 'customercare_size_change_form',
            },
            email_form => {
                location  => 'id("size_change_email_form")',
                transform => 'parse_vertical_table',
                optional  => 1
            }
        }
    },
    'CustomerCare/OrderSearch/SizeChangeConfirmation' => {
        auto_match    => qr!^/CustomerCare/(Customer|Order)Search/SizeChange\?order_id=\d+\&shipment_id=\d+\&status=1!,
        specification => {
        change_result => {
            location  => 'id("contentRight")',
        transform => 'customer_care_confirmation_message'
        }
        }
    },
    'CustomerCare/OrderSearch/EditShipment' => {
        auto_match    => qr!^/CustomerCare/OrderSearch/EditShipment!,
        specification => {
            shipment_details => {
                location  => '//table[@id="shipment_details"]',
                transform => 'parse_vertical_table',
                optional  => 1,
            },
            dhl_destination_code => {
                location  => '//table[@id="dhl_destination_code"]',
                transform => 'parse_vertical_table',
                optional  => 1,
            },
            gift_status => {
                location  => '//table[@id="gift_status"]',
                transform => 'parse_vertical_table',
                optional  => 1,
            },
            shipping_option => {
                location  => '//table[@id="shipping_option"]',
                transform => 'parse_vertical_table',
                optional  => 1,
            },
            shipping_input_form => {
                location  => '//table[@id="shipping_input_form"]',
                transform => 'parse_vertical_table',
                optional  => 1,
            },
            premier_paperwork => {
                location  => '//table[@id="premier_paperwork"]',
                transform => 'parse_vertical_table',
                optional  => 1,
            },
            shipment_carrier_automation => {
                location  => '//table[@id="shipment_carrier_automation"]',
                transform => 'parse_vertical_table',
                optional  => 1,
            },
            shipment_carrier_automation_change_log => {
                location  => '//table[@id="shipment_carrier_automation_change_log"]',
                transform => 'parse_vertical_table',
                optional  => 1,
            },
        },
    },
    'CustomerCare/OrderSearch/EditAddress' => {
        auto_match    => qr!^/CustomerCare/(Customer|Order)Search/EditAddress!,
        specification => {
            address_form => {
                location  => '//form[@name="use_address"]/table[1]',
                transform => 'parse_vertical_table',
            },
            country => {
                location    => 'id("select_country_selection")',
                transform   => 'parse_select_element_with_all_attributes',
                optional    => 0,
            },
        },
    },
    'CustomerCare/OrderSearch/ConfirmAddress' => {
        auto_match    => qr!^/CustomerCare/(Customer|Order)Search/ConfirmAddress!,
        specification => {
            current_address => {
                location  => '//table[@id="edit_address_form"]',
                transform => 'parse_first_vertical_table',
                optional  => 0,
            },
            new_address => {
                location  => '//table[@id="edit_address_form"]',
                transform => 'parse_second_vertical_table',
                optional  => 0,
            },
            customer_email => {
                location  => 'id("table__customer_email")',
                transform => 'parse_vertical_table',
                optional  => 1,
            },
        },
    },
    'CustomerCare/OrderSearch/ConfirmAddress_SelectShippingOption' => {
        # Won't match anything, you need to provide the parser name in as_data
        auto_match    => qr!^/CustomerCare/OrderSearch/ConfirmAddress_SelectShippingOption!,
        specification => {
            current_address => {
                location  => '//table[@id="edit_address_form"]',
                transform => 'parse_first_vertical_table',
                optional  => 0,
            },
            new_address => {
                location  => '//table[@id="edit_address_form"]',
                transform => 'parse_second_vertical_table',
                optional  => 0,
            },
        },
     },
    'CustomerCare/CustomerSearch/Invoice' => {
        auto_match  => qr!
            ^/CustomerCare/CustomerSearch/(
                (Invoice\?action=Create\&order_id=\d+\&shipment_id=\d+) |
                (Invoice\?order_id=\d+\&shipment_id=\d+\&action=View\&invoice_id=\d+) |
                (ConfirmInvoice\?action=Confirm\&order_id=\d+\&shipment_id=\d+)
            )$
        !x,
        specification => {
            refund_value => {
                location  => 'id("refund_value")',
                transform => 'parse_invoice_item_table',
                optional => 1
            },
            invoice_details => {
                location  => 'id("invoice_details")',
                transform => 'parse_first_vertical_table',
            },
        }
    },
    'CustomerCare/OrderSearch/Returns/Create' => {
        auto_match    => qr!^/CustomerCare/(Customer|Order)Search/Returns/Create\?order_id=\d+\&shipment_id=\d+$!,
        specification => {
            returns_items => {
                location  => '//form[@name="createRetForm"]/table[1]',
                transform => 'parse_table',
            },
            returns_create => {
                location  => 'id("contentRight")',
                transform => 'customercare_returns_create',
            },
        }
    },
    'CustomerCare/OrderSearch/Returns/View' => {
        auto_match    => qr!^/CustomerCare/(Customer|Order)Search/Returns/View\?order_id=\d+\&shipment_id=\d+\&return_id=\d+$!,
        specification => {
            return_details => {
                location    => 'id("return_details")',
                transform   => 'parse_vertical_table',
            },
            return_notes => {
                location    => 'id("return_notes")',
                transform   => 'parse_table',
                optional    => 1,
            },
            return_items => {
                location    => 'id("return_items")',
                transform   => 'parse_return_view_items',
            },
            return_log => {
                location    => 'id("return_log")',
                transform   => 'parse_table',
            },
            return_items_log => {
                location    => 'id("return_items_log")',
                transform   => 'parse_table',
            },
            return_email_log => {
                location    => 'id("return_email_log")',
                transform   => 'parse_table',
                optional    => 1,
            },
        }
    },
    'CustomerCare/OrderSearch/SendEmail/Template' => {
        auto_match    => qr{^/CustomerCare/.*Search/SendEmail},
        specification => {
            email_form  => {
                location    => 'id("sendEmail")',
                transform   => 'parse_formrow_fields',
                optional    => 1,
            },
            success_msg => {
                location    => 'id("sent_success_msg")',
                transform   => 'parse_cell',
                optional    => 1,
            },
            error_msg => {
                location    => 'id("sent_error_msg")',
                transform   => 'parse_cell',
                optional    => 1,
            },
        }
    },
    'CustomerCare/OrderSearch/ManualReturnAlteration' => {
        auto_match    => qr{^/CustomerCare/.*Search/ManualReturnAlteration},
        specification => {
            items => {
                location    => '//form[@name="manual_alteration"]/table[1]',
                transform   => 'parse_table',
            },
        }
    },
    'CustomerCare/CustomerCategory' => {
        auto_match => qr{^/CustomerCare/CustomerCategory},
        specification => {
            success => {
                location    => 'id("tbl_category_success")',
                transform   => 'parse_table',
                optional    => 1,
            },
            failure => {
                location        => 'id("tbl_category_failure")',
                transform       => 'parse_table',
                transform_args  => ['do_not_ignore_single_column' => '1'],
                optional    => 1,
            },
            retry_customer_list => {
                location  => '//textarea[@id="customers"]',
                transform => 'parse_cell',
                optional    => 1,
            },
            first_page => {
                location    => 'id("bulk_category_update")',
                transform   => 'parse_formrow_fields',
                optional    => 1,
            },
        }
    },
    '/CustomerCare/OrderSearchbyDesigner' => {
        auto_match => qr!^/CustomerCare/OrderSearchbyDesigner!,
        specification => {
            search_result_list => {
                location  => 'id("search_by_designer_results")',
                transform => 'parse_table',
                optional  => 1,
            },
        },
    },
    'Finance/ActiveInvoices' => {
        auto_match  => qr!^/Finance/ActiveInvoices$!,
        specification => {
            invoice_headers => {
                location =>'//div[@id="tabContainer"]/table[1]',
                transform => 'active_invoices',
                optional  => 1
            },

        }
    },
    'Finance/ActiveInvoices/Invoice' => {
        auto_match  => qr!^/Finance/ActiveInvoices/Invoice\?((order_id=\d+\&shipment_id=\d+\&action=Edit\&invoice_id=\d+)|(invoice_id=\d+\&order_id=\d+\&shipment_id=\d+\&action=View))$!,
        specification => {
            order_details => {
                location  => '//table[@id="order_details"][1]',
                transform => 'parse_vertical_table'
            },
            invoice_details => {
                location  => '//table[@id="invoice_details"][1]',
                transform => 'parse_vertical_table'
            },
            invoice_items => {
                location  => '//table[@id="invoice_items"][1]',
                transform => 'parse_vertical_table'
            },
            invoice_status_log => {
                location  => '//table[@id="invoice_status_log"][1]',
                transform => 'parse_table',
                optional  => 1
            },
            invoice_change_log => {
                location  => '//table[@id="invoice_change_log"][1]',
                transform => 'parse_table',
                optional => 1
            },
        }
    },

    'Finance/ActiveInvoices/PreOrderInvoice' => {
        auto_match  => qr!^/Finance/ActiveInvoices/PreOrderInvoice\?((preorder_id=\d+\&action=Edit\&invoice_id=\d+)|(invoice_id=\d+\&preorder_id=\d+\&action=View))$!,
        specification => {
            preorder_details => {
                location  => '//table[@id="preorder_details_form"][1]',
                transform => 'parse_vertical_table'
            },
            invoice_details => {
                location  => '//table[@id="invoice_details"][1]',
                transform => 'parse_vertical_table'
            },
            invoice_items => {
                location  => '//table[@id="invoice_items"][1]',
                transform => 'parse_vertical_table'
            },
            invoice_status_log => {
                location  => '//table[@id="invoice_status_log"][1]',
                transform => 'parse_table',
                optional  => 1
            },
            invoice_failed_log => {
                location  => '//table[@id="invoice_failed_log"][1]',
                transform => 'parse_table',
                optional => 1
            },
        }
    },

    'Finance/CreditHold' => {
        auto_match  => qr!^/Finance/CreditHold$!,
        specification => {
            credit_hold => {
                location  => '//div[@id="tabContainer"]',
                transform => 'credit_hold_list',
                optional  => 1,
            },

        }
    },

    'Finance/FraudHotList' => {
        auto_match      => qr!^/Finance/FraudHotlist!,
        specification   => {
            page_data   => {
                location    => 'id("contentRight")',
                transform   => 'get_fraud_hotlist_tables',
                optional    => 1,
            },
        },
    },

    'Finance/FraudRules/Outcome' => {
        auto_match      => qr!^/Finance/FraudRules/Outcome\?order_id=!,
        specification   => {
            fraudrule__outcome_order_id => {
                location    => '//div[@id="fraudrules__outcome"]/span[@id="fraudrules__outcome_order_id"]',
                transform   => 'get_value',
            },
        },
    },

    'Finance/FraudRules/Test' => {
        auto_match      => qr!^/Finance/FraudRules/Test\?order_id=\d+\&rule_set=!,
        specification   => {
            fraudrules__test_order_id => {
                location    => '//div[@id="fraudrules__test"]/span[@id="fraudrules__test_order_id"]',
                transform   => 'get_value',
            },
        },
    },

    'Finance/FraudRules/ListManager' => {
        auto_match      => qr!^/Finance/FraudRules/ListManager!,
        specification   => {
            lists => {
                location    => 'id("fraud_lists__list_manager__lists")',
                transform   => 'parse_table',
            },
        },
    },

    'Finance/Reimbursements' => {
        auto_match    => qr!^/Finance/Reimbursements$!,
        specification => {
            channels => {
                location    => 'id("channel")',
                transform   => 'parse_select_element',
            },
            invoice_reasons => {
                location    => 'id("invoice_reason")',
                transform   => 'parse_select_element',
            },
        }
    },

    'Finance/Reimbursements/BulkConfirm' => {
        auto_match    => qr!^/Finance/Reimbursements/BulkConfirm!,
        specification => {
            email_subject   => {
                location    => '//input[@name="email_subject"]/@value',
                transform   => 'get_value',
                optional    => 1,
            },
            email_message   => {
                location    => 'id("email_message")',
                transform   => 'get_value',
                optional    => 1,
            },
            channel_name   => {
                location    => 'id("channel_name")',
                transform   => 'get_value',
            },
            invoice_reason  => {
                location    => 'id("invoice_reason")',
                transform   => 'get_value',
            },
            notes    => {
                location    => 'id("reason")',
                transform   => 'get_value',
            },
            orders => {
                location    => 'id("orders")',
                transform   => 'multi_table_by_id',
            },
        }
    },

    'Finance/Reimbursements/BulkDone' => {
        auto_match    => qr!^/Finance/Reimbursements/BulkDone!,
        specification => {
            bulk_reimbursement_result => {
                location    => '//div[@id="bulk_reimbursement_result"]/h2[1]',
                transform   => 'get_value',
            },
            bulk_reimbursement_id => {
                location    => '//div[@id="bulk_reimbursement_result"]/span[@id="bulk_reimbursement_id"]',
                transform   => 'get_value',
            },
        }
    },
    'Finance/StoreCredit' => {
        auto_match      => qr!^/Finance/StoreCredits$!,
        specification   => {
            page_data => {
                location  => '//div[@id="content"]',
                transform => 'parse_table',
            },
        },
    },
    'Finance/StoreCredits/Create' => {
        auto_match      => qr!^/Finance/StoreCredits/Create!,
        specification   => {
            page_data   => {
                location    => '//form[@name="create_store_credit"]',
                transform   => 'parse_formrow_table',
            },
        },
    },
    'Finance/FraudRules/BulkTest' => {
        auto_match    => qr!^/Finance/FraudRules/BulkTest!,
        specification => {
            invalid_order_numbers => {
                location    => 'id("table_invalid_order_numbers")',
                transform   => 'parse_table',
                optional    => 1,
            },
            all_passed => {
                location    => 'id("td_all_passed")',
                transform   => 'get_value',
                optional    => 1,
            },
            all_failed => {
                location    => 'id("td_all_failed")',
                transform   => 'get_value',
                optional    => 1,
            },
            order_passes => {
                location    => 'id("td_order_passes")',
                transform   => 'get_value',
                optional    => 1,
            },
            order_failures => {
                location    => 'id("td_order_failures")',
                transform   => 'get_value',
                optional    => 1,
            },
            order_failure_list => {
                location    => 'id("table_order_failures")',
                transform   => 'parse_table',
                optional    => 1,
            },
            order_pass_list => {
                location    => 'id("table_order_passes")',
                transform   => 'parse_table',
                optional    => 1,
            },
        },
    },

    'Fulfilment/Commissioner' => {
        auto_match    => qr!^/Fulfilment/Commissioner!,
        specification => {
            'Ready for Packing'  => { location => 'id("packing-ready")',      transform => 'commissioner' },
            'Shipment Cancelled' => { location => 'id("cancel-pending")',     transform => 'commissioner' },
            'Shipment On Hold'   => { location => 'id("on-hold")',            transform => 'commissioner' },
            'No Action'          => { location => 'id("no-action-required")', transform => 'commissioner' },
        }
    },

    'Fulfilment/DDU' => {
        auto_match    => qr!^/Fulfilment/DDU!,
        specification => {
            page_data => {
                location  => '//div[@id="tabContainer"]/table[1]',
                transform => 'channel_multi_table_by_id',
            },
        }
    },

    'Fulfilment/Induction' => {
        auto_match    => qr!^/Fulfilment/Induction!,
        specification => {
            can_be_conveyed_answers => {
                location  => 'id("can_be_conveyed_answers")',
                transform => "parse_simple_list",
                optional  => 1,
            },
            containers_ready_for_packing => {
                location  => 'id("containers_ready_for_packing")',
                transform => 'parse_table',
                optional  => 1,
            },
        }
    },

    'Fulfilment/Packing' => {
        auto_match    => qr!^/Fulfilment/Packing$!,
        specification => {
            map {
                'shipments_ready_for_packing_'.$_ => {
                    location  => 'id("shipments-ready-for-packing-'.$_.'")',
                    transform => 'parse_table',
                    optional  => 1,
                }
            } $schema->resultset('Public::Business')->get_column('config_section')->all,
        }
    },

    '/Fulfilment/Packing/Accumulator' => {
        auto_match    => qr!^/Fulfilment/Packing/Accumulator!,
        specification => {
            primary_tote => { location => 'id("accumulator-primary")', transform => 'get_value' },
            scanned      => { location => "id('contentRight')", transform => 'accumulator_scanned' },
            outstanding  => { location => "id('contentRight')", transform => 'accumulator_outstanding' }
        }
    },

    'Fulfilment/PackingException' => {
        auto_match    => qr!^/Fulfilment/PackingException$!,
        specification => {
            exceptions => {
                location  => '//div[@class="tabInsideWrapper"]/table[1]',
                transform => 'multi_table',
                optional  => 1
            }
        }
    },
    'Fulfilment/PackingException/ViewContainer' => {
        auto_match    => qr!^/Fulfilment/PackingException/ViewContainer\?container_id=[[:upper:]]\d+[[:upper:]]?$!,
        specification => {
            orphaned_items => {
                location  => 'id("orphaned_items")',
                transform => 'parse_table',
                optional  => 1,
            },
            shipment_items => {
                location  => 'id("shipment_items")',
                transform => 'parse_table',
                optional  => 1,
            },
            cancelled_items => {
                location  => 'id("cancelled_items")',
                transform => 'parse_table',
                optional  => 1,
            },
        }
    },
    'Fulfilment/PackingException/ScanOutPEItem' => {
        auto_match    => qr!^/Fulfilment/PackingException/ScanOutPEItem$!,
        specification => {
            item_to_be_scanned => {
                location  => 'id("item-list")',
                transform => 'parse_table',
                optional  => 1,
            },
            shipment_id => {
                location => '//input[@type="hidden" and @name="shipment_id"]/@value',
                transform => 'get_value',
                optional => 1,
            },
            scan_form => {
                location  => '//form[@name="scan_faulty_items"]',
                transform => 'parse_formrow_table',
                optional => 1,
            }
        }
    },
    'Fulfilment/Packing/CheckShipment' => {
        auto_match    => qr!^/Fulfilment/Packing/CheckShipment(?:[?/]|$)!,
        specification => {
            shipment_id => {
                location => '//input[@type="hidden" and @name="shipment_id"]/@value',
                transform => 'get_value',
                optional => 1,
            },
            shipment_items => {
                location  => 'id("contentRight")/form/table[1]',
                transform => 'packing_check_shipment_item_table',
            },
            shipment_extra_items => {
                location  => 'id("contentRight")/form/table[2]',
                transform => 'packing_check_shipment_extra_item_table',
                optional => 1,
            },
            shipment_summary => {
                location  => 'id("contentRight")',
                transform => 'packing_common_template'
            },
        }
    },
    'Fulfilment/Packing/CheckShipmentException' => {
        auto_match    => qr!^/Fulfilment/Packing/CheckShipmentException/?!,
        specification => {
            shipment_id => {
                location => '//input[@type="hidden" and @name="shipment_id"]/@value',
                transform => 'get_value',
            },
            shipment_summary => {
                location  => 'id("contentRight")',
                transform => 'packing_common_template'
            },
            shipment_items => {
                location  => 'id("contentRight")/table[1]',
                transform => 'packing_check_shipment_exception_table',
            },
            shipment_extra_items => {
                location  => 'id("contentRight")/table[2]',
                transform => 'packing_check_shipment_extra_item_table',
                optional => 1,
            },
        }
    },
    'Fulfilment/Packing/PlaceInPEtote' => {
        auto_match    => qr!^/Fulfilment/Packing/PlaceInPEtote!,
        specification => {
            items_pending => {
                location  => 'id("source-items")',
                transform => 'parse_table',
            },
            items_handled => {
                location  => 'id("dest-items")',
                transform => 'parse_table'
            },
        }
    },
    'Fulfilment/Packing/PlaceInPEOrphan' => {
        auto_match    => qr!^/Fulfilment/Packing/PlaceInPEOrphan!,
        specification => {
            items_handled => {
                location  => 'id("item-list")',
                transform => 'parse_table'
            },
        }
    },
    'Fulfilment/Packing/EmptyTote' => {
        auto_match => qr!^/Fulfilment/Packing/EmptyTote!,
        specification => {
            totes => {
                location => 'id("totes")',
                transform => 'split_comma_string',
            },
        },
    },
    'Fulfilment/Packing/PackShipment' => {
        auto_match => qr!^/Fulfilment/Packing/PackShipment!,
        specification => {
            packer_messages => {
                location  => 'id("contentRight")',
                transform => 'get_messages_for_packers',
            },
        },
    },
    'Fulfilment/Selection' => {
        auto_match    => qr!^/Fulfilment/Selection(\?.+)?!,
        specification => {
            shipments => {
                location  => '//form[@name="f_select_shipment"]/table',
                transform => 'parse_table',
            }
        }
    },
    'Fulfilment/OnHold' => {
        auto_match    => qr!^/Fulfilment/OnHold!,
        specification => {
            shipments => {
                location  => '//div[@class="tabInsideWrapper"]/table[1]',
                transform => 'multi_table'
            }
        }
    },
    'Fulfilment/Manifest' => {
        auto_match    => qr!^/Fulfilment/Manifest!,
        specification => {
            manifest_details => {
                location  => 'id("manifest_details")',
                transform => 'parse_formrow_table'
            },
            status_log => {
                location  => 'id("status_log")',
                transform => 'parse_table'
            },
            manifest_shipments => {
                location  => 'id("manifest_shipments")',
                transform => 'parse_table'
            },
        }
    },
    'Fulfilment/GOHIntegration' => {
        auto_match => qr!^/Fulfilment/GOHIntegration(\?ignore_cookies=1)?$!,
        specification => {
            integration_lane_button => {
                location => '//button[@id="select_integration_lane"]',
                transform => 'none',
            },
            direct_lane_button => {
                location => '//button[@id="select_direct_lane"]',
                transform => 'none',
            },
            direct_lane_content => {
                location => '//div[@id="group_direct_lane"]',
                transform => 'parse_goh_integration_group_of_skus',
            },
            integration_lane_content => {
                location => '//div[@id="group_integration_lane"]',
                transform => 'parse_goh_integration_group_of_skus',
            },
        },
    },
    'Fulfilment/GOHIntegration/Integration' => {
        auto_match => qr!^/Fulfilment/GOHIntegration/\d+/(container/\w+/)?view$!,
        specification => {
            working_station_name => {
                location  => '//span[@id="station_name"]',
                transform => 'none',
            },
            integration_lane_content => {
                location  => '//div[@id="group_integration_lane"]',
                transform => 'parse_goh_integration_group_of_skus',
                optional  => 1,
            },
            direct_lane_content => {
                location  => '//div[@id="group_direct_lane"]',
                transform => 'parse_goh_integration_group_of_skus',
                optional  => 1,
            },
            container_content => {
                location  => '//div[@id="group_integration_container"]',
                transform => 'parse_goh_integration_group_of_skus',
                optional  => 1,
            },
            upcoming_dcd_containers => {
                location  => '//div[@id="upcoming_dcd_containers"]',
                transform => 'parse_goh_integration_dcd_containers',
                optional  => 1,
            },
            user_error_message => {
                location  => '//div[@class="alert alert-danger"]',
                transform => 'none',
                optional  => 1,
            },
            user_prompt_message => {
                location  => '//div[@class="alert alert-info"]',
                transform => 'none',
                optional  => 1,
            },
        },
    },
    # This is only expecting one search result - any more will confuse it. If
    # you need more to be matched, create a NEW controller that works similarly
    # rather than changing the data out of this one...
    'GoodsIn/ItemCount/List' => {
        auto_match => qr!Not Possible!,
        specification => {
            nap_table => {
                location  => '//div[@class="tabInsideWrapper"]/table[1]',
                transform => 'multi_table',
            }
        }
    },
    'GoodsIn/ItemCount/SingleResult' => {
        auto_match => qr!Not Possible!,
        specification => {
            product_data => {
                location  => 'id(\'contentRight\')/table[1]',
                transform => 'product_summary',
            },
            counts_form => {
                location  => 'id(\'main_form\')/table',
                transform => 'parse_table',
            }
        }
    },
    'GoodsIn/PutawayPrepAdmin' => {
        auto_match    => qr!^/GoodsIn/PutawayPrepAdmin$!,
        specification => {
            stock_process_table => {
                location  => '//table[@id="groups-for-stock-process"]',
                transform => 'parse_table',
            },
            recodes_table => {
                location  => '//table[@id="groups-for-stock-recode"]',
                transform => 'parse_table',
            },
            returns_table => {
                location  => '//table[@id="groups-for-returns"]',
                transform => 'parse_table',
            },
            container_table => {
                location  => '//table[@id="container-table"]',
                transform => 'parse_table',
            },
        }
    },
    'GoodsIn/Putaway/List' => {
        auto_match    => qr!^/GoodsIn/Putaway/?$!,
        specification => {
            nap_table => {
                location  => '//div[@class="tabInsideWrapper"]/table[1]',
                transform => 'multi_table',
            }
        }
    },
    'GoodsIn/Putaway/Product' => {
        auto_match    => qr!^/GoodsIn/Putaway(?:/Book/?)\?process_group_id=\d+$!,
        specification => {
            product_data => {
                location  => 'id(\'contentRight\')/table[1]',
                transform => 'product_summary',
            },
            product_list => {
                location  => 'id(\'contentRight\')/form/table[1]',
                transform => 'product_list',
            }
        }
    },
    'GoodsIn/QualityControl/ProcessItem' => {
        auto_match => qr!Not Possible!,
        specification => {
            product_data => {
                location  => 'id(\'contentRight\')/table[1]',
                transform => 'product_summary',
            },
            qc_results => {
                location  => 'id(\'main_form\')/form/table[1]',
                transform => 'parse_table'
            }
        }
    },
    'GoodsIn/QualityControl/FastTrack' => {
        auto_match => qr!^/GoodsIn/QualityControl/FastTrack!,
        specification => {
            product_data => {
                location  => 'id(\'contentRight\')/table[1]',
                transform => 'product_summary',
            },
            fast_track => {
                location  => 'id(\'main_form\')/form/table[1]',
                transform => 'parse_table'
            }
        }
    },
    'GoodsIn/RecentDeliveries' => {
        auto_match    => qr!^/GoodsIn/RecentDeliveries!,
        specification => {
            deliveries => {
                location  => 'id(\'recent_deliveries\')/table',
                transform => 'parse_table',
            },
        }
    },
    'GoodsIn/StockIn/SingleResult' => {
        auto_match    => qr!^/GoodsIn/StockIn?.*search=1!,
        specification => {
            products => {
                location  => 'id(\'contentRight\')/table/tbody/tr/td/div/table',
                transform => 'purchase_order_search',
            },
        }
    },
    'GoodsIn/StockIn/PackingSlip' => {
        auto_match    => qr!^/GoodsIn/StockIn/PackingSlip\?so_id=\d+$!,
        specification => {
            product_data => {
                location  => 'id(\'contentRight\')/table[1]',
                transform => 'product_summary',
            },
            variants => {
                location  => '//form[@name="create_stock_delivery"]/table',
                transform => 'parse_table',
            }
        }
    },
    'GoodsIn/Surplus/ProcessItem' => {
        auto_match => qr!Not Possible!,
        specification => {
            process_units => {
                location  => 'id(\'contentRight\')/form/table[1]',
                transform => 'parse_table'
            }
        }
    },

    '/Home' => {
        auto_match    => qr!^/Home$!,
        specification => {
        }
    },

    '/NAPEvents/InTheBox' => {
        auto_match  => qr !^/NAPEvents/InTheBox\?show_channel=\d+$!,
        specification => {
            data  => {
                location  => '//div[@class="tabInsideWrapper"]',
                transform => 'multi_table'
            }
        }
    },

    '/NAPEvents/InTheBox/Edit' => {
        auto_match => qr!^/NAPEvents/InTheBox/Edit!,
        specification => {
            details => {
                location    => 'id("marketing_promotion_main")',
                transform   => 'inthebox_promotion_details',
            },
            options_assigned => {
                location    => 'id("marketing_promotion_main")',
                transform   => 'inthebox_promotion_options',
            },
        }
    },

    '/NAPEvents/InTheBox/CustomerSegment' => {
        auto_match  => qr !^/NAPEvents/InTheBox/CustomerSegment\?show_channel=\d+$!,
        specification => {
            data  => {
                location  => '//div[@class="tabInsideWrapper"]',
                transform => 'multi_table'
            }
        }
    },
    '/NAPEvents/WelcomePacks' => {
        auto_match  => qr !^/NAPEvents/WelcomePacks.*!,
        specification => {
            data  => {
                location  => 'id("contentRight")/form',
                transform => 'welcome_pack_page',
            },
        },
    },

    'printdoc/giftmessagewarning' => {
        auto_match => qr'^printdoc/giftmessagewarning',
        specification => {
            barcode  => {
                location  => "id('barcode')",
                transform => 'parse_barcode'
            },
            message  => {
                location  => "id('msg')",
                transform => 'get_value'
            },
            order_nr => {
                location  => "id('order-nr')",
                transform => 'get_value'
            }
        }
    },
    'printdoc/shippingform' => {
        auto_match => qr!^printdoc/shippingform!,
        specification => {
            shipment_items => {
                location  => '/html/body/table[2]',
                transform => 'shippingform_shipment_items',
            },
            document_title => {
                location  => '/html/body/table[1]/tr[1]/td[1]/font',
                transform => 'parse_cell',
            },
            shipment_details => {
                location  => '/html/body/table[1]',
                transform => 'parse_vertical_table',
            },
        }
    },
    'printdoc/outpro' => {
        auto_match => qr!^printdoc/outpro!,
        specification => {
            shipment_items => {
                location  => '/html/body/table[3]',
                transform => 'outbound_proforma_shipment_items',
            },
            document_heading => {
                location  => '/html/body/table[1]/tr[1]/td[1]/font',
                transform => 'parse_cell',
            },
            document_title => {
                location  => '/html/body/table[1]/tr[2]/td[1]/font/b',
                transform => 'parse_cell',
            },
            shipment_details => {
                location  => '/html/body/table[2]',
                transform => 'parse_vertical_table',
            },
            footer => {
                location  => '/html/body/font',
                transform => 'get_value',
            }
        }
    },
    'printdoc/retpro' => {
        auto_match => qr!^printdoc/retpro!,
        specification => {
            shipment_items => {
                location  => '/html/body/table[3]',
                transform => 'retpro_proforma_shipment_items',
            },
            document_heading => {
                location  => '/html/body/table[1]/tr[1]/td[1]/font',
                transform => 'parse_cell',
            },
            document_title => {
                location  => '/html/body/table[1]/tr[2]/td/font/b',
                transform => 'parse_cell',
            },
            currency => {
                location  => '/html/body/table[4]/tr/td[3]/font',
                transform => 'parse_cell',
            },
            shipment_details => {
                location  => '/html/body/table[2]',
                transform => 'dual_tables',
            },
            export_reason   => {
                location    => '/html/body/table[5]/tr/td[1]/font',
                transform   => 'parse_cell',
            },
            footer => {
                location  => '/html/body/table[last()]//font',
                transform => 'get_value',
            }
        }
    },
    'printdoc/invoice' => {
        auto_match => qr!^printdoc/invoice!,
        specification => {
            shipment_items => {
                location  => '/html/body',
                transform => 'invoice_shipment_items',
            },
            document_heading => {
                location  => '/html/body/table[1]/tr[1]/td[1]/font',
                transform => 'parse_cell',
            },
            document_title => {
                location  => '/html/body/table/tr[2]/td/font/b',
                transform => 'parse_cell',
            },
            invoice_details => {
                location  => '/html/body',
                transform => 'invoice_details',
            },
            duties_and_taxes => {
                location  => '/html/body/table[6]/tr[2]/td/font',
                transform => 'invoice_duties_and_taxes',
                optional => 1,
            },
            footer => {
                location  => '/html/body/table[last()]//font',
                transform => 'get_value',
            }
        }
    },
    'printdoc/pickinglist' => {
        auto_match => qr!^printdoc/pickinglist!,
        specification => {
            shipment_data => {
                location  => '/html/body',
                transform => 'printdoc_pickinglist_shipment_data',
            },
            item_list => {
               location  => '/html/body/font/table[3]/tbody',
               transform => 'printdoc_table',
            }
        }
    },
    'printdoc/matchup_sheet' => {
        auto_match => qr!^printdoc/matchup_sheet!,
        specification => {
            shipment_id => {
                location  => '/html/body//table[1]/tbody/tr[1]/td[2]/h1',
                transform => 'none',
            },
            customer_name => {
                location  => '/html/body//table[1]/tbody/tr[2]/td[2]/h1',
                transform => 'none',
            },
            shipment_class => {
                location  => '/html/body//table[1]/tbody/tr[3]/td[2]/h1',
                transform => 'none',
            },
            channel => {
                location  => '/html/body//table[1]/tbody/tr[4]/td[2]/h1',
                transform => 'none',
            },
        }
    },

    # don't want to rely on auto url match as different sets of assets rely on the same finenames.
    'printdoc/putaway' => {
        auto_match => qr!Not Possible!,
        specification => {
            item_list => {
                location  => '/html/body//table[3]/tbody',
                transform => 'printdoc_putaway_item_table',
            },
            metadata => {
                location  => '/html/body',
                transform => 'printdoc_putaway_metadata',
            },
        }
    },

    'printdoc/shippinglist' => {
        auto_match => qr!^printdoc/shippinglist!,
        specification => {
            metadata => {
                location  => '/html/body/table[1]',
                transform => 'printdoc_shippinglist_shipment_data',
            },
            items => {
                location  => '/html/body/table[2]',
                transform => 'printdoc_shippinglist_shipment_items',
            },
        }
    },
    'Reporting/StockConsistency' => {
        auto_match => qr!^/Reporting/StockConsistency!,
        specification => {
            consistency => {
                location  => '//div[@id="tabContainer"]/table[1]',
                transform => 'consistency_report',
                optional  => 1
            }
        }
    },
    'RTV/RequestRMA/List' => {
        auto_match => qr!^/RTV/RequestRMA$!,
        specification => {
            items => {
                location  => 'id(\'contentRight\')/form[2]/table',
                transform => 'rma_request_results_table',
            }
        }
    },
    'StockControl/Inventory/Search' => {
        auto_match => qr!^/StockControl/Inventory/Search($|\?)!,
        specification => {
            products => {
                location  => 'id(\'search_results\')/table',
                transform => 'parse_table',
            }
        }
    },
    'StockControl/Inventory/MoveAddStock' => {
        auto_match => qr!^/StockControl/Inventory/MoveAddStock\?variant_id=\d+$!,
        specification => {
            stock_by_location => {
                location  => '//div[@id="tabContainer"]/table[1]',
                transform => 'multi_table',
                optional  => 1
            }
        }
    },
    'StockControl/Inventory/StockQuarantine' => {
        auto_match => qr!^/StockControl/Inventory/StockQuarantine\?product_id=\d+$!,
        specification => {
            nap_table => {
                location  => '//div[@id="tabContainer"]/table[1]',
                transform => 'multi_table',
                optional  => 1
            }
        }
    },
    'StockControl/Measurement' => {
        auto_match    => qr!^/StockControl/(Measurement/Edit|Inventory/Measurement)!,
        specification => {
            measurements => {
                location  => 'id("editMeasurements")',
                transform => 'parse_stockcontrol_measurement',
            },
        }
    },
    'StockControl/PurchaseOrder/StockOrder' => {
        auto_match    => qr!^/StockControl/PurchaseOrder/StockOrder\?so_id=\d+$!,
        specification => {
            product_data => {
                location  => 'id(\'contentRight\')/table[1]',
                transform => 'product_summary',
            },
        }
    },
    'StockControl/Sample/ReturnStock' => {
        auto_match => qr!^/StockControl/Sample/ReturnStock(\?|$)!,
        specification => {
            stock_table => {
                location  => '//form[@name="return_stock"]/table[@class="data"]',
                transform => 'parse_table',
            }
        }
    },
    'StockControl/Sample/SamplesIn' => {
        auto_match => qr!^/StockControl/Sample/SamplesIn!,
        specification => {
            product_data => {
                location  => 'id(\'contentRight\')/table[1]',
                transform => 'product_summary',
            },
            goods_in => {
                location  => 'id(\'main_form\')/form/table[1]',
                transform => 'parse_table'
            }
        }
    },
    'StockControl/Sample/GoodsOut' => {
        auto_match => qr!^/StockControl/Sample/GoodsOut!,
        specification => {
            product_data => {
                location  => 'id(\'contentRight\')/table[1]',
                transform => 'product_summary',
            },
            goods_out => {
                location  => 'id(\'main_form\')/form/table[1]',
                transform => 'parse_table'
            }
        }
    },
    'StockControl/Recode' => {
        auto_match => qr!^/StockControl/Recode(\?variant_id=.+)?$!,
        specification => {
            source => {
                location => 'id("transit_items")',
                transform => 'parse_table',
            },
        },
    },
    'StockControl/Reservation/Customer' => {
        auto_match => qr!^/StockControl/Reservation/Customer.*$!,
        specification => {
            reservation_list => {
                location  => '//table[@id="reservation_list"]',
                transform => 'parse_table',
                optional  => 1,
            },
            pre_order_list => {
                location    => 'id("preorder_tabview")',
                transform   => 'multi_table_by_id',
                optional    => 1,
            },
            create_buttons  => {
                location    => 'id("contentRight")',
                transform   => 'customer_reservation_create_buttons',
            },
        }
    },
    'StockControl/Reservation/Email' => {
        auto_match => qr!^/StockControl/Reservation/Email.*$!,
        specification => {
            customer_emails => {
                location  => '//div[@id="tabContainer"]/table[1]',
                transform => 'reservation_email',
                optional  => 1
            }
        }
    },
    'StockControl/Reservation/Listing/Live' => {
        auto_match => qr!^/StockControl/Reservation/Listing(\?list_type=Live.*)?$!,
        specification => {
            operator_list => {
                location    => 'id("operator_dropdown")',
                transform   => 'parse_select_element',
                optional    => 1,
            },
            reservations => {
                location  => '//div[@id="tabContainer"]',
                transform => 'reservation_view_live_reservations',
            },
            reservations_by_operator => {
                location  => '//div[@id="tabContainer"]',
                transform => 'live_reservations_by_operator',
            }
        }
    },
    'StockControl/Reservation/Product' => {
        auto_match => qr!^/StockControl/Reservation/Product.*$!,
        specification => {
            reservation_list => {
                location  => '//div[@id="tabContainer"]/table[1]',
                transform => 'product_reservation_list',
            },
            highlighted_customers => {
                location  => 'id("reservation_tabview-NAP")',
                # location  => '//div[@id="tabContainer"]/table[1]',
                transform => 'parse_highlighted_rows',
                optional  => 1
            }
        }
    },
   'StockControl/Reservation/Reports/Uploaded/P' => {
        auto_match => qr!^/StockControl/Reservation/Reports/Uploaded/P$!,
        specification => {
            operator_list => {
                location    => 'id("operator_dropdown")',
                transform   => 'parse_select_element',
                optional    => 1,
            },
            report => {
                location  => '//table[@id="ContentTable"]',
                transform => 'parse_table',
                optional  => 1,
            }
        }
    },
    'StockControl/Reservation/Overview/Upload' => {
        auto_match => qr!^/StockControl/Reservation/Overview\?view_type=Upload.*$!,
        specification => {
            page_data => {
                location  => '//div[@id="tabContainer"]/table[1]',
                transform => 'reservation_overview_upload',
            }
        }
    },
    'StockControl/Reservation/Overview/Upload/Filter' => {
        auto_match => qr!^/StockControl/Reservation/Overview/Upload/Filter!,
        specification => {
            designer_list => {
                location  => '//div[@id="designer_list"]/table[1]',
                transform => 'parse_vertical_table',
            },
            product_id_entry => {
                location  => '//div[@id="product_id_entry"]/table[1]',
                transform => 'parse_vertical_table',
            },
        }
    },
    'StockControl/Reservation/Overview/Upload/ApplyFilter' => {
        auto_match => qr!^/StockControl/Reservation/Overview/Upload/ApplyFilter!,
        specification => {
            excluded => {
                location  => '//form[@id="re_apply_filter"]',
                transform => 'reservation_upload_filtered',
            },
        }
    },
    'StockControl/Reservation/Overview/Pending' => {
        auto_match => qr!^/StockControl/Reservation/Overview\?view_type=Pending.*$!,
        specification => {
            page_data => {
                location  => '//div[@id="tabContainer"]/table[1]',
                transform => 'reservation_overview_pending',
            }
        }
    },
    'StockControl/Reservation/Overview/Waiting' => {
        auto_match => qr!^/StockControl/Reservation/Overview\?view_type=Waiting.*$!,
        specification => {
            page_data => {
                location  => '//div[@id="tabContainer"]/table[1]',
                transform => 'reservation_overview_waiting',
            }
        }
    },
    'StockControl/Reservation/Listing/Waiting' => {
        auto_match => qr!^/StockControl/Reservation/Listing\?list_type=Waiting!,
        specification => {
            page_data => {
                location  => '//div[@id="tabContainer"]/table[1]',
                transform => 'reservation_view_waiting_lists',
            }
        }
    },

    'StockControl/Reservation/PreOrder/PreOrderList' => {
        auto_match => qr!^/StockControl/Reservation/PreOrder/PreOrderList$!,
        specification => {
            operator_list => {
                location    => 'id("operator_dropdown")',
                transform   => 'parse_select_element',
                optional    => 1,
            },

            preorder_list => {
                location  => '//div[@id="pre_order_list__div"]',
                transform => 'preorder_list'
            }
        }
    },

    'StockControl/Reservation/PreOrder/SelectProducts' => {
        auto_match => qr!^/StockControl/Reservation/PreOrder/SelectProducts.*$!,
        specification => {
            product_search_box => {
                location  => '//form[@id="select_products__search_form"]',
                transform => 'parse_formrow_fields',
            },
            product_list => {
                location  => '//form[@id="select_products__variants_form"]',
                transform => 'pre_order_product_list',
                optional  => 1,
            },
            shipment_address_text => {
                location  => '//div[@id="shipment_address__on_screen_text"]',
                transform => 'parse_cell',
                optional  => 1,
            },
            shipment_address_none => {
                location  => '//span[@id="shipment_address__none"]',
                transform => 'parse_cell',
                optional  => 1,
            },
        },
    },
    'StockControl/Reservation/PreOrder/Basket' => {
        auto_match => qr!^/StockControl/Reservation/PreOrder/Basket.*$!,
        specification => {
            pre_order_items => {
                location  => '//table[@id="basket__variants_table"]',
                transform => 'parse_table',
            },
            pre_order_total => {
                location  => '//div[@id="basket__payment_due_status"]',
                transform => 'parse_cell',
            },
            pre_order_original_total => {
                location  => '//div[@id="basket__payment_without_discount"]',
                transform => 'parse_cell',
                optional  => 1,
            },
            pre_order_discount_drop_down => {
                location  => '//select[@id="discount_to_apply"]',
                transform => 'parse_cell',
                optional  => 1,
            },
        },
    },
    'StockControl/Reservation/PreOrder/Payment' => {
        auto_match => qr!^/StockControl/Reservation/PreOrder/Payment.*$!,
        specification => {
            payment_total => {
                location  => 'id("payment__total_due")',
                transform => 'parse_cell',
            },
            payment_total_discount => {
                location  => 'id("payment__total_due__discount")',
                transform => 'parse_cell',
                optional  => 1,
            },
            payment_total_zero_discount => {
                location  => 'id("payment__total_due__zero_discount")',
                transform => 'parse_cell',
                optional  => 1,
            },
        },
    },

    'StockControl/Reservation/PreOrder/Summary' => {
        auto_match => qr!^/StockControl/Reservation/PreOrder/Summary.*$!,
        specification => {
            pre_order_item_list => {
                location  => '//table[@id="summary__variants_table"]',
                transform => 'parse_table',
            },
            pre_order_total     => {
                location  => '//span[@id="payment_due__current__text"]',
                transform => 'parse_cell',
            },
            pre_order_original_total => {
                location  => '//div[@id="summary__payment_without_discount"]',
                transform => 'parse_cell',
                optional  => 1,
            },
            discount_operator => {
                location  => '//div[@id="summary__payment_discount_operator"]',
                transform => 'parse_cell',
                optional  => 1,
            },
            cancel_pre_order_button => {
                location  => '//button[@id="summary__cancel_pre_order_button"]',
                transform => 'parse_cell',
                optional  => 1,
            },
            cancel_pre_order_item_button => {
                location  => '//button[@id="summary__cancel_pre_order_item_button"]',
                transform => 'parse_cell',
                optional  => 1,
            },
            refund_list => {
                location  => '//table[@id="summary__refunds_table"]',
                transform => 'parse_table',
                optional  => 1,
            },
            log_pre_order_status => {
                location  => '//table[@id="summary__status_log_pre_order"]',
                transform => 'parse_table',
                optional  => 1,
            },
            log_pre_order_item_status => {
                location  => '//table[@id="summary__status_log_pre_order_items"]',
                transform => 'parse_table',
                optional  => 1,
            },
            change_size_link    => {
                location    => 'id("summary__change_size_link")',
                transform   => 'parse_cell',
                optional    => 1,
            },
            payment_details => {
                location  => '//table[@id="order_details__payment_card_details"][1]',
                transform => 'parse_vertical_table',
                optional  => 1,
            }
        }
    },
    'StockControl/Reservation/PreOrder/PreOrderOnhold' => {
        auto_match => qr!^/StockControl/Reservation/PreOrder/PreOrderOnhold.*$!,
        specification => {
            pre_order_list  => {
                location    => '//table[@id="pre_order_list"]',
                transform   => 'parse_table',
                optional    => 1,
            },
        },
    },
    'StockControl/Reservation/PreOrder/SendCancelEmail' => {
        auto_match => qr!^/StockControl/Reservation/PreOrder/SendCancelEmail.*$!,
        specification => {
            email_form => {
                location  => '//form[@id="cancel_email_form"]',
                transform => 'parse_formrow_fields',
            },
        },
    },


    'StockControl/Reservation/PreOrder/Completed' => {
        auto_match => qr!^/StockControl/Reservation/PreOrder/Completed.*$!,
        specification => {
            email_form => {
                location  => '//form[@id="email_form"]',
                transform => 'parse_formrow_fields',
            },
        },
    },

    'StockControl/Reservation/PreOrder/ChangeItemSize' => {
        auto_match => qr!^/StockControl/Reservation/PreOrder/ChangeItemSize.*$!,
        specification => {
            item_list => {
                location  => '//table[@id="sizechange_pre_order_items"]',
                transform => 'parse_table',
            },
        },
    },

    'StockControl/Reservation/PreOrder/ActionChangeItemSize' => {
        auto_match => qr!^/StockControl/Reservation/PreOrder/ActionChangeItemSize.*$!,
        specification => {
            item_list => {
                location  => '//table[@id="sizechange_pre_order_items"]',
                transform => 'parse_table',
            },
            email_form => {
                location  => '//form[@id="pre_order_size_change_email_form"]',
                transform => 'parse_formrow_fields',
            },
        },
    },

    'StockControl/Reservation/PreOrder/PreOrderSearch' => {
        auto_match => qr!^/StockControl/Reservation/PreOrder/PreOrderSearch.*!,
        specification => {
            search_results => {
                location  => 'id("preorder_tabview")',
                transform => 'multi_table_by_id',
                optional  => 1,
            },
        },
    },

    'GoodsIn/ReturnsArrival/Delivery' => {
        auto_match => qr!^/GoodsIn/ReturnsArrival/Delivery/\d+!,
        specification => {
            details => {
                location  => 'id("delivery_details")',
                transform => 'parse_vertical_table',
            },
            arrivals => {
                location  => 'id("return_arrivals_table")',
                transform => 'parse_table',
            },
            total_packages => {
                location  => 'id("total_packages")',
                transform => 'int_from_text',
            },
        },
    },

    'StockControl/Reservation/BulkReassign' => {
        auto_match => qr!^/StockControl/Reservation/BulkReassign.*!,
        specification => {
            reservation_list => {
                location  => 'id("reservation_list")',
                transform => 'parse_table',
            },
        },
    },

    'GoodsIn/ReturnsQC/ProcessItem' => {
        auto_match => qr!Not Possible!,
        specification => {
            qc_results => {
                location  => 'id("return_items")',
                transform => 'parse_table'
            }
        }
    },
    'GoodsIn/VendorSampleIn/ProcessItem' => {
        auto_match => qr!Not Possible!,
        specification => {
            product_data => {
                location  => 'id(\'contentRight\')/table[1]',
                transform => 'product_summary',
            },
            qc_results => {
                location  => 'id("main_form")//table[@class="data"]',
                transform => 'parse_vendor_sample_qc_table'
            }
        }
    },
    'SelectPrinterStation' => {
        auto_match => qr!^/My/SelectPrinterStation\?!,
        specification => {
            stations => {
                location => '//form[@name="SelectPrinterStation"]//select[@name="ps_name"]',
                transform => 'parse_select_element',
            },
        },
    },
    'GoodsIn/PutawayPrep' => {
        auto_match => qr!GoodsIn/PutawayPrep\b!,
        specification => {
            form => {
                location => '//form[@name="putaway_prep"]',
                transform => 'parse_putaway_prep',
            },
        },
    },
    'GoodsIn/PutawayProblemResolution' => {
        auto_match => qr!GoodsIn/PutawayProblemResolution!,
        specification => {
            container => {
                location  => '//div[@id="container_info"]',
                transform => 'parse_putaway_problem_resolution',
                optional  => 1,
            },
            re_putaway_prep => {
                location  => '//div[@id="re_putaway_prep_block"]',
                transform => 'parse_putaway_prep_on_problem_resolution',
                optional  => 1,
            }
        },
    },
    'GoodsIn/PutawayPrepPackingException' => {
        auto_match => qr!GoodsIn/PutawayPrepPackingException!,
        specification => {
            form => {
                location  => '//form[@name="putaway_prep_packing_exception"]',
                transform => 'parse_putaway_prep_packing_exception',
                optional  => 1,
            },
        },
    },
);

our $LAST_PARSER_SELECTED_BY_REGEX = '';

=head2 client_parse_cell_deeply

    my $boolean = $mech->client_parse_cell_deeply( BOOLEAN );

This instructs the 'parse_cell' method to give more information when it encounters
INPUT statements so that it gives the 'Type' and in the case of checkboxes and radio
buttons whether they have been 'checked' or not. If multiple INPUT statements are
encountered in the same cell then an array ref of 'inputs' is returned.

This is here for backward compatibilty so that previous tests don't fail.

=cut

has client_parse_cell_deeply => (
    is => 'rw',
    isa => 'Bool',
    lazy => 1,
    default => 0,
);

=head2 client_parse_cell_deeply

    $boolean = $mech->client_with_raw_rows( BOOLEAN );

Will allow the 'with_raw_rows' flag to be set by the caller rather
than just methods in this Class so that access can be got to the 'raw'
node at any time.

Implemented for:
    * parse_table

=cut

has client_with_raw_rows => (
    is  => 'rw',
    isa => 'Bool',
    lazy=> 1,
    default => 0,
);


=head2 as_data

Returns C<<$mech->content>> as parsed data, assuming we recognize the page type.
New page types can be added in the C<Test::XTracker::Client> source.

We will attempt to work out the page type automatically from
C<<$mech->query_path>>, but you can also specify a page type that matches one
of those defined in the source as the sole argument. If we guessed what page
type you were using, you can find our guess in C<$LAST_PARSER_SELECTED_BY_REGEX>
which might be useful for debugging.

=cut

sub as_data {
    my ( $mech, $page ) = @_;

    # if the content type is JSON then parse and return it
    if ( $mech && $mech->can('content_type') && $mech->content_type =~ m/json/i ) {
        my $decoded;
        try {
            $decoded = JSON->new->utf8->decode( $mech->content( format => 'text' ) );
        }
        catch {
            my $err = $_;
            diag "*** The resulting content from the last request is";
            diag "*** JSON & we're having problems parsing using the";
            diag "*** as_data() method, for the following reason:";
            diag "***";
            diag "*** ${err}";
            diag "***";
            diag "*** Content Found:";
            diag "*** " . ( $mech->content // 'undef' );
            diag "***";
            diag "*** TRANSMISSION ENDS ***";
            fail("Couldn't parse JSON content; test will now die. See diag output");
            croak "as_data() failed fatally. See diag() output for details";
        };
        return $decoded;
    }

    my $specification;
    my $parser_name;
    # If they specified the page type, we can just read it from a hash
    if ($page) {
        $parser_name = $page;
        $specification = $page_definitions{$page}->{'specification'}
          || $mech->_xclient_noisy_die( 0, $page );
    }
    # Otherwise we look for it using the URL
    else {
        my $url = (
            $mech->can('uri_without_overrides') ?
                $mech->uri_without_overrides
              : $mech->uri )->path_query;
        for my $key ( keys %page_definitions ) {
            my $regex = $page_definitions{$key}->{'auto_match'};
            if ( $url =~ m/$regex/ ) {
                $parser_name = $key;
                $LAST_PARSER_SELECTED_BY_REGEX = $key;
                $specification = $page_definitions{$key}->{'specification'};
                last;
            }
        }
        $mech->_xclient_noisy_die( 1 ) unless $parser_name;
    }

    my %return_data;
    # Process each page part
    for my $key ( keys %$specification ) {
        my $node =
          $mech->find_xpath( $specification->{$key}->{'location'} )
          ->get_node(1);
        if (!$node) {
            if (!$specification->{$key}->{'optional'}) {
                $mech->_xclient_noisy_die( 1, $parser_name,
                    $key, $specification->{$key}->{'location'} );
            } else {
                next;
            }
        }

        my $method = '_xclient_' . $specification->{$key}->{'transform'};
        $return_data{$key} = $mech->$method($node,@{$specification->{$key}->{'transform_args'} //[]});
    }
    return \%return_data;
}

sub _xclient_noisy_die {
    my ( $mech, $url_match, $parser_name, $section, $address ) = @_;
    diag "*** We're having problems parsing the page using the";
    diag "*** as_data() method. If you haven't recently changed";
    diag "*** the parser for the page in Test::XTracker::Client,";
    diag "*** then the test has probably gotten a different page";
    diag "*** than it expected. For this reason, we're also going";
    diag "*** to try and show you errors in the Mechanize object.";
    diag "*** Let's start off with details about the failed parse:";
    diag "***";
    diag "*** Parser diagnostics:";
    if (! $url_match ) {
        diag "***   Specified Parser: [$parser_name]";
        diag "***   -> We couldn't find this parser";
    } elsif (! $parser_name ) {
        diag "***   URL:     [" . $mech->uri->path_query . "]";
        diag "***   -> We couldn't find a parser for this URL";
    } else {
        diag "***   Parser:  [$parser_name]";
        diag "***   Section: [$section]";
        diag "***   Address: [$address]";
        diag "***   -> The listed xpath address can't be found by the parser.";
    }
    diag "***";
    diag "*** Mechanize diagnostics:";
    diag "***   Error messages:   [" . ($mech->app_error_message || 'None') . "]";
    diag "***   Warning messages: [" . ($mech->app_warning_message || 'None') . "]";
    diag "***   Status messages:  [" . ($mech->app_status_message || 'None') . "]";
    diag "***";
    diag "*** Regardless, if we expected to be able to parse a page";
    diag "*** and we can't, running any more tests seems like a bad";
    diag "*** idea, so now we bail. Good luck, commander!";
    diag "*** TRANSMISSION ENDS ***";
    fail("Couldn't parse target page; test will now die. See diag output");
    croak "as_data() failed fatally. See diag() output for details";
}

=head2 as_data_trimmed

As with C<as_data>, but removes all but the first element of each array (and
tells you how many it trimmed). This is useful if you're developing a test and
don't remember what the page's data output looks like.

=cut

sub as_data_trimmed {
    my $mech = shift;
    my $data = $mech->as_data(@_);
    return $mech->_xclient_trim_tree($data);
}

=head2 app_error_message

Returns the contents of the first error message it finds, or undef, if none was
found. It's looking for C<p[@class="error_msg"]>.

=head2 app_warning_message

Returns the contents of the first warning message it finds, or undef, if none was
found. It's looking for C<p[@class="warning_msg"]>.

=head2 app_status_message

Returns the contents of the first error message it finds, or undef, if none was
found. It's looking for C<p[@class="display_msg"]>.

=head2 app_info_message

Returns the contents of the first info message it finds, or undef, if none was
found. It's looking for C<p[@class="info"]>.

=head2 app_operator_name

Returns the contents of the first operator name it finds, or undef, if none was
found. It's looking for C<p[@class="operator_name"]>.

=cut

sub app_error_message {
    my $mech = shift();
    return $mech->_find_message('error_msg') ||
        $mech->_find_message('warning');
}
sub app_warning_message {
    my $mech = shift();
    return $mech->_find_message('warning_msg');
}
sub app_status_message {
    my $mech = shift();
    return $mech->_find_message('display_msg');
}
sub app_info_message {
    my $mech = shift();
    return $mech->_find_message('info');
}
sub app_operator_name {
    my $mech = shift();
    my $op = $mech->_find_message('operator_name');
    $op =~ s/Logged in as: //;
    return $op;
}
sub _find_message {
    my ( $mech, $type ) = @_;
    my $node = $mech->find_xpath('//*[@class="' . $type . '"]')->get_node(1);
    return undef unless $node;

    # Don't collapse whitespace on preformatted error chunks
    if ( $node->attr('style') && $node->attr('style') =~ m/white\-space/ ) {
        note "Message [$type] is preformatted, so reparsing page";
        # It's not pretty, clever, or right, but it should work...
        my $tree = HTML::TreeBuilder->new();
        $tree->no_space_compacting(1);
        $tree->parse( $mech->content );
        $node = $tree->find_xpath('//*[@class="' . $type . '"]')->get_node(1);
    }

    my $text = $node->as_text || '[blank]';
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return $text;
}

#
# ---------------------------------------- #
# Some general notes on what comes next... #
# ---------------------------------------- #
#
# Remember that each method we're adding here will be added to the Mechanize
# class. To avoid any chance of namespace collissions, we're going to prepend
# '_xclient_' to each method name, and you should do that if you add any new
# ones.
#
# If you're trying to build up XPath expressions, consider the excellent
# "XPath Checker" plugin for Firefox. Beware that FF adds in tbody's to tables
# though, and so the output you get from the plugin may have extra tbody nodes
# being matched that don't appear when you're retrieved the content via LWP.
#
# When we're parsing elements that contain a URL or an input element, we'll
# return a hashref with the URI or input value and the element 'as_text'.
# See _xclient_parse_cell for more details.
#
# .
#

=head2 PRIVATE METHODS

These methods are for use in the C<transform> part of specifications. Only the
most useful are shown.

=cut

# Debugging method
sub _xclient_dump_content {
    my ( $mech, $node ) = @_;
    die $node->as_HTML;
}

# don't do any transform, just return the node contents
sub _xclient_none {
    my ( $mech, $node ) = @_;
    return $node->as_text;
}

# Extract the first integer from the node contents
sub _xclient_int_from_text {
    my ( $mech, $node ) = @_;
    my ($int) = ($node->as_text//q{}) =~ m{(\d+)};
    return $int;
}

# Get the src attribute from the node.
sub _xclient_src_attribute {
    my ( $mech, $node ) = @_;

    return $node->attr( 'src' );

}

# Trim a nested hash-ref down for easier understanding of structure. This is
# recursive. This is used exclusively by as_data_trimmed()
sub _xclient_trim_tree {
    my ( $mech, $data ) = @_;

    # When the incoming data is an array, remove all but the first row, and then
    # add a row saying how many rows we trimmed
    if ( ref($data) eq 'ARRAY' ) {
        my $row_count = @$data;
        my $important = [ $mech->_xclient_trim_tree( $data->[0] ) ];
        if ( ( $row_count - 1 ) > 0 ) {
            push( @$important, ( $row_count - 1 ) . " rows hidden" );
        }
        return $important;

        # When the incoming data is a hash, push each key through this sub
    }
    elsif ( ref($data) eq 'HASH' ) {
        for my $key ( keys %$data ) {
            $data->{$key} = $mech->_xclient_trim_tree( $data->{$key} );
        }
    }
    return $data;
}

sub _xclient_customer_care_order_shipment_items {
    my ( $mech, $node ) = @_;
    my $table = $mech->_xclient_parse_table( $node );
    for my $row (@$table) {
        if ( $row->{'Status'} =~ s/( [[:upper:]] \d+ )//x ) { # E.g. M340349
            $row->{'Container'} = $1;
        }
    }
    return $table;
}

sub _xclient_customer_care_order_voucher_history {
    my ( $mech, $node ) = @_;

    my @list = $node->find_xpath("//img[\@name='voucher_usage']" )->get_nodelist();
    my @return_val;

    # Return ids of img as confirmation
    for my $row ( @list) {
        push(@return_val, $row->attr('id'));
    }

    return \@return_val;
}

sub _xclient_parse_barcode {
    my ( $mech, $node ) = @_;
    my $src = $node->attr('src');
    $src =~ s!.+/!!;
    return $src;
}

# Commissioner
sub _xclient_commissioner {
    my ( $mech, $node ) = @_;
    return $mech->_xclient_parse_table( $node );
}

# Accumulator totes
sub _accumulator_totes {
    my ( $mech, $node, $div ) = @_;
    my $class_name = 'accumulator-' . $div;

     my @rows = map {
        my $div = $_;
        my $tote_id = $mech->_xclient_get_value( $div->find_xpath('p')->get_node(0) );
        $tote_id =~ s/ \(Primary\)//;
        my $tote_type = $mech->_xclient_get_value( $div->find_xpath('span')->get_node(0) );
        $tote_type =~ s/\:$//;
        [ $tote_type, $tote_id ];
    } $node->find_xpath("//div[contains(\@class,'$class_name')]")->get_nodelist();

    return \@rows;
}

sub _xclient_accumulator_outstanding { my $self = shift; return $self->_accumulator_totes(@_, 'outstanding'); }
sub _xclient_accumulator_scanned { my $self = shift; return $self->_accumulator_totes(@_, 'scanned'); }

# Sometimes two data tables are shoved in the same HTML table, separated by a
# blank row. As nasty as that is, it's not too hard to parse...
sub _xclient_dual_tables {
    my ( $mech, $node ) = @_;

    my @rows = grep {
        ! ( $_->find_xpath('td[@class="divider"]')->get_node(0) )
    } $node->find_xpath('tr')->get_nodelist();

    my @names =
            map { ref $_ ? $_->{'value'} : $_ }
            map { $mech->_xclient_parse_cell( $_ ) }
            shift(@rows)->find_xpath('td')->get_nodelist();
    my @tables = ( {}, {} );

    for my $row ( @rows ) {
        my ( $key1, $val1, $divider, $key2, $val2 ) =
            map { $mech->_xclient_parse_cell( $_ ) }
            $row->find_xpath('td')->get_nodelist();
        $key1 =~ s/:$//         if ( defined $key1 );
        $key2 =~ s/:$//         if ( defined $key2 );
        $tables[0]->{$key1} = $val1 if $key1;
        $tables[1]->{$key2} = $val2 if $key2;
    }

    return {
        $names[0] => $tables[0],
        $names[2] => $tables[1],
    };
}

my @shippingform_key_transform = (
    [ 'SKU', 'sku' ],
    [ 'DESCRIPTION', 'description' ],
    [ 'WEIGHT', 'weight' ],
    [ 'COUNTRY OFORIGIN', 'country_of_origin'],
    [ 'FABRICCONTENT', 'fabric_content' ],
    [ 'HS CODE', 'hs_code' ],
    [ 'QTY', 'qty' ],
    [ 'UNITPRICE', 'unit_price' ],
    [ 'SUBTOTAL', 'sub_total' ],
);

sub _xclient_shippingform_shipment_items {
    my ( $mech, $node ) = @_;

    # Take a stab at parsing the table
    my $table = $mech->_xclient_parse_table( $node );

    # Make the hash keys a bit more readable
    my @transformed_rows;
    for my $row ( @$table ) {

        my $new = {};
        for (@shippingform_key_transform) {
            my ( $from, $to ) = @$_;
            $new->{$to} = $row->{$from};
        }

        push( @transformed_rows, $new );

    }

    my $args;

    # sort out the totals at the bottom of the table
    # and discard these rows as they are found
    foreach my $idx ( 0..$#transformed_rows ) {
        my $row = $transformed_rows[$idx];
        if ( $row->{country_of_origin} && $row->{country_of_origin} =~ qr/TOTAL PRICE/ ) {
            $args->{total_price}    = $row->{fabric_content};
            $args->{total_weight}   = $row->{weight};
            delete $transformed_rows[$idx];
        }
        if ( $row->{sku} && $row->{sku} =~ qr/TOTAL TAX/ ) {
            $args->{total_tax}      = $row->{description};
            delete $transformed_rows[$idx];
        }
        if ( $row->{sku} && $row->{sku} =~ qr/SHIPPING/ ) {
            $args->{shipping}       = $row->{description};
            delete $transformed_rows[$idx];
        }
        if ( $row->{sku} && $row->{sku} =~ qr/SHIPPING TAX/ ) {
            $args->{shipping_tax}   = $row->{description};
            delete $transformed_rows[$idx];
        }
        if ( $row->{sku} && $row->{sku} =~ qr/GRAND TOTAL/ ) {
            $args->{grand_total}    = $row->{description};
            delete $transformed_rows[$idx];
        }
    }

    # get the items less any of the totals at the bottom which are now 'undef'
    $args->{items}  = [ grep { defined $_ } @transformed_rows ];

    return $args;
}

my @outbound_key_transform = (
    [ 'SUB TOTAL', 'subtotal' ],
    [ 'COUNTRY OF MFG', 'country' ],
    [ 'COMPLETE DETAILED DESCRIPTION OF GOODS', 'description' ],
    [ 'UNITS', 'units'],
    [ 'CUSTOMS COMMODITY CODE', 'customs code' ],
    [ 'UNIT VALUE', 'value' ],
    [ 'UNIT TYPE', 'type' ]
);

sub _xclient_outbound_proforma_shipment_items {
    my ( $mech, $node ) = @_;

    # Take a stab at parsing the table
    my $table = $mech->_xclient_parse_table( $node );

    my $total = pop( @$table );
    my $real_total = $total->{'UNIT TYPE'};

    # Make the hash keys a bit more readable
    my @transformed_rows;
    for my $row ( @$table ) {

        my $new = {};
        for (@outbound_key_transform) {
            my ( $from, $to ) = @$_;
            $new->{$to} = $row->{$from};
        }

        push( @transformed_rows, $new );

    }

    return {
        items => \@transformed_rows,
        total => $real_total
    };
}

my @retpro_key_transform = (
    [ 'TICK', 'tick' ],
    [ 'FULL DESCRIPTION OF GOODSINCLUDING FABRICATION', 'description' ],
    [ 'QTY','qty' ],
    [ qr/(UNIT VALUE).*(GBP)/, '_unit_value' ],
    [ qr/(UNIT VALUE).*(USD)/, '_unit_value' ],
    [ qr/(UNIT VALUE).*(EUR)/, '_unit_value' ],
    [ qr/(UNIT VALUE).*(AUD)/, '_unit_value' ],
    [ qr/(UNIT VALUE).*(HKD)/, '_unit_value' ],
    [ qr/(SUBTOTAL).*(GBP)/, '_subtotal' ],
    [ qr/(SUBTOTAL).*(USD)/, '_subtotal' ],
    [ qr/(SUBTOTAL).*(EUR)/, '_subtotal' ],
    [ qr/(SUBTOTAL).*(AUD)/, '_subtotal' ],
    [ qr/(SUBTOTAL).*(HKD)/, '_subtotal' ],
    [ 'UNIT NETWEIGHT', 'net_weight' ],
    [ 'COUNTRY OFMANUFACTURE', 'manufacture_country' ],
    [ 'HS CODE', 'hs_code' ],
);

sub _xclient_retpro_proforma_shipment_items {
    my ( $mech, $node ) = @_;

    # Take a stab at parsing the table
    my $table       = $mech->_xclient_parse_table( $node );
    my $last_row    = pop( @{ $table } );

    my %totals;

    # Make the hash keys a bit more readable
    my @transformed_rows;
    for my $row ( @$table ) {

        my $new = {};
        for (@retpro_key_transform) {
            my ( $from, $to ) = @{ $_ };
            if ( ref($from) && ref($from) eq 'Regexp' ) {

                # for UNIT VALUE or SUBTOTAL get the currency
                # used and then prefix this to form the hash key
                my ($tmp)   = grep { $_ =~ $from } keys %{ $row };
                next        if ( !defined $tmp );

                $tmp        =~ $from;
                my $prefix  = $1;
                my $currency= lc($2);
                $new->{ $currency.$to }    = $row->{$tmp};

                # if it's the unit value use it to get the total
                # value for the currency from the last row
                if ( $prefix eq "UNIT VALUE" && !exists( $totals{ $currency.'_total' } ) ) {
                    $last_row->{$tmp}   =~ s/[^\d\.\-\+,]//g;
                    $totals{ $currency.'_total' }   = $last_row->{$tmp};
                }
            }
            else {
                $new->{$to} = $row->{$from};
            }
        }

        push( @transformed_rows, $new );

    }

    return {
        items => \@transformed_rows,
        totals => \%totals,
    };
}

my @invoice_key_transform = (
    [ 'DESCRIPTION', 'description' ],
    [ 'QUANTITY', 'qty' ],
    [ 'UNIT PRICE', 'unit_price' ],
    [ 'GST RATE', 'gst_rate'],
    [ 'GST', 'gst code' ],
    [ 'VAT RATE', 'vat_rate' ],
    [ 'VAT', 'vat' ],
    [ 'DUTIES', 'duties' ],
    [ 'PRICE', 'price' ]
);

sub _xclient_invoice_shipment_items {
    my ( $mech, $node ) = @_;

    # get the heading row from a separate table
    my $heading_row = $node->find_xpath( 'table[3]/tr' )->get_node;

    # get the table of items
    my $item_table  = $node->find_xpath( 'table[4]' )->get_node;
    # add the heading into the item table so it can be parsed normally
    $item_table->unshift_content( $heading_row );

    # parse the table
    my $table = $mech->_xclient_parse_table( $item_table );

    # Make the hash keys a bit more readable
    my @transformed_rows;
    for my $row ( @$table ) {

        my $new = {};
        for (@invoice_key_transform) {
            my ( $from, $to ) = @$_;
            if ( exists( $row->{$from} ) ) {
                $new->{$to} = $row->{$from};
            }
        }

        push( @transformed_rows, $new );

    }

    # get the table totals
    my $total_table = $node->find_xpath( 'table[5]' )->get_node;
    $table  = $mech->_xclient_parse_vertical_table( $total_table );
    # clean-up the data
    my $totals;
    foreach my $label ( 'GRAND TOTAL', 'SHIPPING', 'TOTAL PRICE' ) {
        $table->{ $label }[1]  =~ s/[^0-9,.+-]//g;
        $totals->{ $label } = $table->{ $label }[1];
    }

    return {
        items => \@transformed_rows,
        totals => $totals,
    };
}

sub _xclient_invoice_details {
    my ( $mech, $node ) = @_;

    my %details;

    # get the Order/Shipment/Customer Numbers
    my $overview;
    my $detail  = $node->find_xpath( '/html/body/table[2]/tr/td/font' )->get_node;
    my $value   = $mech->_xclient_parse_cell( $detail );
    $value      =~ m/
                        (?<order_number_label>\w+\s\w+):\s(?<order_number>\d+)\s?           # Order Number
                        (?<shipment_number_label>\w+\s\w+):\s(?<shipment_number>\d+)\s?     # Shipment Number
                        (?<customer_number_label>\w+\s\w+):\s(?<customer_number>\d+)\s?     # Customer Number
                    /x;
    $overview->{ $+{order_number_label} }   = $+{order_number};
    $overview->{ $+{shipment_number_label} }= $+{shipment_number};
    $overview->{ $+{customer_number_label} }= $+{customer_number};

    # get the Invoice Number & Date
    foreach my $detail (
                            $node->find_xpath( '/html/body/table[1]/tr[3]/td/font[1]' )->get_node,
                            $node->find_xpath( '/html/body/table[1]/tr[3]/td/font[2]' )->get_node,
                    ) {
        $value  = $mech->_xclient_parse_cell( $detail );
        $value  =~ m/(?<label>.*):\s(?<value>.*)/;
        $overview->{ $+{label} }  = $+{value};
    }

    # get the Billing and Delivery Addresses
    my $addresses;
    foreach my $row ( $node->find_xpath( '/html/body/table[1]/tr[position()>3]' )->get_nodelist ) {
        next        if ( $row->find_xpath('td[1]/img[@src="/images/blank.gif"]') );     # blank row

        # get the value for each '<FONT>' tag in the row
        my @values  = map { $mech->_xclient_parse_cell( $_ ) } $row->find_xpath('td/font')->get_nodelist();

        # Array should contain an even number and should be in
        # the 'Key,Pair' format so increase the iterator twice.
        # Also first half should be for 'Invoice To' section
        # and second half should be for 'Deliver To' section.
        for ( my $i = 0; $i < @values; $i += 2 ) { ## no critic(ProhibitCStyleForLoops)
            my $section = ( $i < ( $#values / 2 ) ? 'invoice_to' : 'deliver_to' );
            $addresses->{ $section }{ $values[ $i ] } = $values[ $i+1 ];
        }
    }

    $details{overview}  = $overview;
    $details{addresses} = $addresses;

    return \%details;
}

sub _xclient_invoice_duties_and_taxes {
    my ( $mech, $node ) = @_;

    my $retval  = $mech->_xclient_parse_cell( $node ) || '';

    if ( $retval !~ /DUTIES \& TAXES INFORMATION/ ) {
        # if the table didn't contain this phrase then
        # it doesn't contain what we think
        $retval = undef;
    }

    return $retval;
}

sub _xclient_customer_care_order {
    my ( $mech, $node ) = @_;

    # Grab a list of tables that aren't the Premier Customer notes
    my @tables = grep {
        ! $_->find_xpath('tr/td/form')->get_node(0)
    } $node->find_xpath('table')->get_nodelist();

    # This grabs "Order Details", "Invoice Address", "Shipment Details" and
    # "Shipment Address"  (and ignores "Customer Notes" if it's there)
    my %data = (
        map { %{ $mech->_xclient_dual_tables( $_ ) } }
            grep { $_->find_xpath('tr')->get_nodelist() > 1 }   # exclude tables with only one row as these should be header tables
                grep { $_->find_xpath('tr/td/h3')->get_node(0) }    # only get tables with 'h3' title tags in them
                    @tables
    );

    # if there's a Pre-Order split out any Discount mentioned
    if ( my $pre_order = $data{'Order Details'}{'Pre-Order Number'} ) {
        if ( $pre_order->{value} =~ m/(?<pre_order_number>P\d+)\D+(?<discount>\d+?\.?\d+?)\%/ ) {
            $pre_order->{value}    = $+{pre_order_number};
            $pre_order->{discount} = $+{discount};
        }
    }

    # Adjust the 'Signature upon Delivery Required'
    # field to make more sense, if it's present
    if ( exists $data{'Shipment Details'}{'Signature upon Delivery Required'} ) {
        my $shipment_id = $data{'Shipment Details'}{'Shipment Number'};
        my $value_node  = $node->find_xpath("id('signature_value_${shipment_id}')")->get_node(1);
        my $edit_node   = $node->find_xpath("id('signature_edit_${shipment_id}')")->get_node(1);
        my $img         = $value_node->find_xpath("img[1]")->get_node(1);
        # replace the existing value
        $data{'Shipment Details'}{'Signature upon Delivery Required'}   = {
                    editable    => ( defined $edit_node ? 1 : 0 ),
                    value       => ( $img->attr('alt') eq 'Signature Required' ? 1 : 0 ),
                    icon        => $img->attr('src'),
            };
    }

    # get the Payments & Refunds table if there is one
    if ( $node->find_xpath('//table[starts-with(@id, "order_view_payment_refunds")]')->get_nodelist ) {
        my $shipment_id = $data{'Shipment Details'}{'Shipment Number'};
        my $paym_table  = $node->find_xpath("id('order_view_payment_refunds_${shipment_id}')")->get_node;
        $data{'payments_and_refunds'}   = $mech->_xclient_parse_table( $paym_table )        if ( $paym_table );

        # get a message that appears if the Order was paid using a Third Party (PayPal)
        my $message = $node->find_xpath("id('third_party_payment_message_" . $shipment_id . "')")->get_node;
        $data{'third_party_payment_message__for_payment'} = $mech->_xclient_parse_cell( $message )
                            if ( $message );
    }

    # The rather more challenging "Shipment Hold"
    if ( my $ship_hold_node = $node->find_xpath("id('shipment_hold')")->get_node(0) ) {
        my %shipment_hold;
        my @rows = map {
            my $row = $_;
            my @cells = $row->find_xpath('td')->get_nodelist();
            my $key = $mech->_xclient_parse_cell( $cells[0] );
            $key =~ s/:$//;
            my $val = $mech->_xclient_parse_cell( $cells[1] );
            $shipment_hold{ $key } = $val;
        } grep {
            ! ( $_->find_xpath('td[@class="divider"]')->get_node(0) )
        } $ship_hold_node->find_xpath('tr')->get_nodelist();

        $data{'Shipment Hold'} = \%shipment_hold;
    }

    # get the Delivery/Collection Routing Information tables
    # which are present if the Shipment is Premier
    my @route_nodes = $node->find_xpath( '//table[starts_with(@id,"rout_sched_")]' )->get_nodelist;
    foreach my $route ( @route_nodes ) {
        my $id  = $route->attr('id');
        $id =~ s/^rout_sched_//;        # get the actual Id prefixed by either 's'hipment or 'r'eturn

        my $table   = $mech->_xclient_parse_table( $route );
        if ( @{ $table } ) {
            # if there were rows
            $data{'routing_information'}{ $id } = $mech->_xclient_parse_table( $route, with_raw_rows => 1 );
        }
        else {
            # else show the 'not ready' message
            $data{'routing_information'}{ $id } = $mech->_xclient_parse_cell( $route->find_xpath("tbody/tr/td")->get_node );
        }
    }

    # get Return and/or Shipment Email Logs
    my @log_nodes   = $node->find_xpath( '//table[starts_with(@id,"email_log_")]' )->get_nodelist;
    foreach my $log ( @log_nodes ) {
        my $id  = $log->attr('id');
        $id     =~ m/^email_log_(?<type>shipment|return)_(?<id>\d+$)/;      # get the actual Id and whether it is the return or shipment logs
        $id     = $+{id};
        my $type= $+{type};

        my $table   = $mech->_xclient_parse_table( $log );
        if ( @{ $table } ) {
            # if there were rows
            $data{"${type}_email_log"}{ $id } = $mech->_xclient_parse_table( $log );
        }
    }

    # get Payment Card Details which you
    # see if you are a Finance user
    if ( my $card_details_node = $node->find_xpath('//table[@id="order_details__payment_card_details"][1]')->get_node(0) ) {
        $data{'Finance Data'}{'payment_card_details'}   =
                                $mech->_xclient_parse_vertical_table( $card_details_node );

    }

    # get payment details for store credit
    if( my $store_credit_node = $node->find_xpath("id('order_details__payment_store_credit_details')")->get_node(0) ) {
        $data{'Finance Data'}{'payment_store_credit_details'}   =
             $mech->_xclient_parse_vertical_table( $store_credit_node);
    }

    # get the Customer Information table if it's there
    if ( my $cust_info = $node->find_xpath("id('customer_information')")->get_node ) {
        $data{'Customer Information'}   = $mech->_xclient_parse_vertical_table( $cust_info );
    }

    # get the Contact Options out of the page
    if ( my $contact_options = $node->find_xpath("id('order_contact_options')")->get_node ) {
        my $deeply_setting  = $mech->client_parse_cell_deeply;
        $mech->client_parse_cell_deeply(1);
        $data{'Order Contact Options'}  = $mech->_xclient_parse_vertical_table( $contact_options );
        $mech->client_parse_cell_deeply( $deeply_setting );
    }

    if( my $preorder_notes_node = $node->find_xpath('//table[@id="preorder_notes"][1]')->get_node(0) ) {
        $data{'preorder_notes'} = $mech->_xclient_parse_table( $preorder_notes_node );
    }

    if ( my $order_notes_node = $node->find_xpath('//table[@id="order_notes"][1]')->get_node(0) ) {
        $data{'order_notes'} = $mech->_xclient_parse_table( $order_notes_node );
    }

    #get Marketing Promotion
    if( my $marketing_promotion_node = $node->find_xpath('//table[@id="marketing_promotion"][1]')->get_node(0)) {
        $data{'marketing_promotion'} = $mech->_xclient_parse_table( $marketing_promotion_node );
    }

    # get a message that appears with the Order Details if
    # the Order was paid with using a Third Party (PayPal)
    my $message = $node->find_xpath('id("third_party_payment_message")')->get_node;
    $data{'third_party_payment_message__for_order'} = $mech->_xclient_parse_cell( $message )
                        if ( $message );

    # get Order Status Message Button
    if ( my $order_status_message_button = $node->find_xpath('id("order_status_message_wrapper")')->get_node(0) ) {
        $data{'order_status_message_button'} = $mech->_xclient_parse_cell( $order_status_message_button );
    }

    # get the Payment 'Fulfilled' Log table, if present
    if ( my $payfulfill_node = $node->find_xpath('id("payment_fulfill_log")')->get_node ) {
        $data{'payment_fulfill_log'} = $mech->_xclient_parse_table( $payfulfill_node );
    }

    return \%data;
}

sub _xclient_customer_view {
    my ( $mech, $node ) = @_;

    my %data;

    my $deeply_setting  = $mech->client_parse_cell_deeply;
    $mech->client_parse_cell_deeply(1);

    # process a list of the fixed tables
    foreach my $table_id ( qw(
                                tbl_customer_details
                                tbl_alternative_accounts
                                tbl_customer_notes
                                tbl_store_credit )
                        ) {
        my $tbl_node    = $node->find_xpath("//table[\@id='$table_id']")->get_node;
        if ( defined $tbl_node ) {
            my $label   = $table_id;
            $label  =~ s/^tbl_//;
            $data{ $label } = $mech->_xclient_parse_table( $tbl_node );
        }
    }

    # list of Vertical Tables that appear in
    # the Form and so get parsed differently
    my @vertical_tables = ( qw(
                tbl_inv_address_history
                tbl_ship_address_history
                tbl_customer_options
                tbl_contact_options
            ) );

    # process a list of the expandable tables
    foreach my $table_id ( qw(
                                tbl_customer_options
                                tbl_customer_value
                                tbl_store_credit_log
                                tbl_order_history
                                tbl_returns_history
                                tbl_inv_address_history
                                tbl_ship_address_history
                                tbl_contact_options
                            )
                        ) {
        # the table id's are for the heading tables that
        # contain the Table title with the View/Hide option,
        # the data is usually in a div with the id without
        # the 'tbl_' prefix
        my $tbl_node    = $node->find_xpath("table[\@id='$table_id']")->get_node;

        if ( defined $tbl_node ) {
            my $label   = $table_id;
            $label  =~ s/^tbl_//;
            $data{ $label } = {
                    title   => $mech->_xclient_parse_cell( $tbl_node->find_xpath("tr[2]/td[1]/span")->get_node ),
                    data    => [],       # store an empty table first
                };

            # try and parse the div tag
            my $div_node    = $node->find_xpath("div[\@id='$label']//table[1]")->get_node;
            if ( defined $div_node ) {
                if ( grep { $_ eq $table_id } @vertical_tables ) {
                    # these are vertical tables
                    $data{ $label }{data}   = $mech->_xclient_parse_vertical_table( $div_node );
                }
                else {
                    $data{ $label }{data}   = $mech->_xclient_parse_table( $div_node );
                }
            }
        }
    }

    $mech->client_parse_cell_deeply( $deeply_setting );

    return \%data;
}

sub _xclient_order_status_log {
    my ( $mech, $node )     = @_;

    my %data;

    # there is only one Order Status Log table
    $data{order_status_log} = $mech->_xclient_parse_table( $node->find_xpath('//table[@id="tbl_order_status_log"]')->get_node );

    # get all of the Shipment Status tables
    my @shipments   = $node->find_xpath('//table[@id=~/tbl_shipment_status_\d+/]')->get_nodelist;
    foreach my $shiptbl ( @shipments ) {
        my ($ship_id) = ($shiptbl->attr('id') =~ m/tbl_shipment_status_(\d+)/);

        # parse the Shipment Status table first
        $data{$ship_id}{shipment_status}    = $mech->_xclient_parse_vertical_table( $shiptbl );

        # get all the tables for the Shipment
        my $ship_status_log = $node->find_xpath("//table[\@id='tbl_shipment_status_log_${ship_id}']")->get_node;
        my $ship_item_log   = $node->find_xpath("//table[\@id='tbl_shipment_item_status_log_${ship_id}']")->get_node;
        my $deliv_sig_log   = $node->find_xpath("//table[\@id='tbl_delivery_signature_log_${ship_id}']")->get_node;
        my $ship_hold_log   = $node->find_xpath("//table[\@id='tbl_shipment_hold_log_${ship_id}']")->get_node;

        # now parse them if they exist
        $data{$ship_id}{shipment_status_log}        = $mech->_xclient_parse_table( $ship_status_log )
                                                                    if ( $ship_status_log );
        $data{$ship_id}{shipment_item_status_log}   = $mech->_xclient_parse_table( $ship_item_log )
                                                                    if ( $ship_item_log );
        $data{$ship_id}{delivery_signature_log}     = $mech->_xclient_parse_table( $deliv_sig_log )
                                                                    if ( $deliv_sig_log );
        $data{$ship_id}{shipment_hold_log}          = $mech->_xclient_parse_table( $ship_hold_log )
                                                                    if ( $ship_hold_log );
    }

    return \%data;
}

# Takes /Fulfilment/Packing/CheckShipment URL, cleans the SKU and parses out the shipment_item_id for each item.
sub _xclient_packing_check_shipment_item_table {
    my ( $mech, $node ) = @_;
    return [map {
                my $item = $_;
                ($item->{shipment_item_id}) = ( $item->{QC}->{input_name} // '' ) =~ m/(\d+)/;
                $item->{SKU} =~ s/\(.+\)//;
                $item;
            } @{$mech->_xclient_parse_table( $node )}];
}

# Takes /Fulfilment/Packing/CheckShipment URL, cleans the SKU and parses out the shipment_item_id for each item.
sub _xclient_packing_check_shipment_extra_item_table {
    my ( $mech, $node ) = @_;
    return [map {
                my $item = $_;
                $item->{id} = $item->{'Item type'};
                $item->{id} =~ s/\s//g;
                $item;
            } @{$mech->_xclient_parse_table( $node )}];
}

=head2 customercare_cancel_item_form

Parse the whole form in C</CustomerCare/CustomerSearch/CancelShipmentItem>,
extracting any hidden fields, the form attributes I<action>, I<method> and
I<name>, and also parsing the table using C<customercare_cancel_item_table>.

=cut

sub _xclient_customercare_cancel_item_form {
    my ( $mech, $node ) = @_;

    my %form_data=();

    # I'd expect to be able to hand this off to _xclient_parse_cell, but
    # it doesn't work, just returning emptiness.
    my $input=$node->find_xpath('input[@type="hidden"]')->get_node(1);

    if(defined $input){
        $form_data{hidden_input}={ name  => $input->attr('name'),
                                   value => $input->attr('value') };
    }

    foreach my $attr (qw(action method name)) {
        $form_data{$attr}=$node->attr($attr);
    }

    $form_data{select_items}=$mech->_xclient_customercare_cancel_item_table($node->find_xpath('table[1]')->get_node(1));

    if ( my $refund_option_tbl = $node->find_xpath('id("customer_refund_option")')->get_node(1) ) {
        $form_data{refund_option}   = $mech->_xclient_parse_vertical_table( $refund_option_tbl );
    }

    return \%form_data;
}

=head2 simplify_labelled_checkbox

Helper function for following C<customercare...table> subs.

=cut

sub _simplify_labelled_checkbox {
    my ($item,$name) = @_;

    return undef          unless exists $item->{$name};
    return $item->{$name} unless    ref $item->{$name} eq 'HASH';

    return { name    => $item->{$name}->{input_name},
         value   => $item->{$name}->{input_value},
         checked => $item->{$name}->{value} };
}

=head2 customercare_cancel_item_table

Takes the table on C</CustomerCare/CustomerSearch/CancelShipmentItem>,
loses the 'Choose ...' prompt values and tidies up the select
list so that it is an array of hashes of this form:

    {
       PID => '12345-678',
       name => 'The Cancellable Item Name',
       select_item => {
       name    => 'form name for checkbox',
       value   => 'form value for checkbox',
       checked => 'current value for checkbox',
       },
       reason_for_cancellation => {
           name        => 'form name for selection',
           selected    => 'index of value selected, -1 otherwise',
           values => [
               { name => 'form name for option 1',
                value => 'form value for option 1',
               },
               { name => 'form name for option 2',
                value => 'form value for option 2',
               },
               [...]
           ]
       }
    }

Or, when there is no control to select a different size for
an item:

    {
       PID => '12345-679',
       name => 'The Uncancellable Item Name',
       select_item => 'text in place of checkbox',
       reason_for_cancellation => 'text in place of select list',
    }

Note that it's not a hash indexed by PID, because PID isn't
guaranteed to be unique in the list.

Note also that it doesn't return the E-mail form, if it's present.

=cut

sub _xclient_customercare_cancel_item_table {
        my ( $mech, $node ) = @_;

    return [ map {
            my $item = $_;
        my $props;

        if (ref $item->{PID} eq 'HASH') {
            $props->{PID}  = $item->{PID}->{value};
        }
        else {
            $props->{PID}  = $item->{PID};
        }

        $props->{name} = $item->{Name};

        $props->{select_item}=_simplify_labelled_checkbox(
                                      $item,
                      'Select Item(s)'
                  );

        if ( ref( $item->{'Reason for Cancellation'} ) eq 'HASH' ) {

            my $name    = $item->{'Reason for Cancellation'}->{select_name};
            my $select  = $node->find_xpath('.//select[@name="' . $name . '"]')->get_node(1);

            $props->{reason_for_cancellation} = $mech->_xclient_parse_select_element_with_groups( $select );

        } else {

            $props->{reason_for_cancellation} = $item->{'Reason for Cancellation'};

        }

        $props;
    } @{$mech->_xclient_parse_table( $node )}];
}


=head2 customercare_size_change_form

Parse the whole form in C</CustomerCare/CustomerSearch/SizeChange>,
extracting any hidden fields, the form attributes I<action>, I<method> and
I<name>, and also parsing the table using C<customercare_size_change_table>.

=cut

sub _xclient_customercare_size_change_form {
    my ( $mech, $node ) = @_;

    my %form_data=();

    # I'd expect to be able to hand this off to _xclient_parse_cell, but
    # it doesn't work, just returning emptiness.
    my $input=$node->find_xpath('input[@type="hidden"]')->get_node(1);

    if(defined $input){
        $form_data{hidden_input}={ name  => $input->attr('name'),
                                   value => $input->attr('value') };
    }

    foreach my $attr (qw(action method name)) {
        $form_data{$attr}=$node->attr($attr);
    }

    $form_data{select_items}=$mech->_xclient_customercare_size_change_table($node->find_xpath('table[1]')->get_node(1));

    return \%form_data;
}

# Parses fake tables created using 'formrow' divs
sub _xclient_parse_formrow_table {
    my ( $mech, $node ) = @_;
    my %table = map {
        my $div = $_;
        my $key = $div->find_xpath('span[contains(@class,"fakelabel")]')->get_node(1)
                        // $div->find_xpath('label')->get_node(1);
        $key = $key ? $mech->_xclient_parse_cell( $key ) : '';
        $key =~ s/\:$//;

        my $value = $div->find_xpath('p')->get_node(1);

        # Value might be a list
        if( ! defined $value ){
            $value = $div->find_xpath('ul')->get_node(1);
        }

        $value = $value ? $mech->_xclient_parse_cell( $value ) : '';

        ( $key, $value );
    } $node->find_xpath('.//div[contains(@class,"formrow")]')->get_nodelist();
    return \%table;
}

# Parses Input forms which have used the 'formrow' divs and '<label>' tags
# parse the Id of the '<form>' tag.
sub _xclient_parse_formrow_fields {
    my ( $mech, $node ) = @_;
    my %table = map {
        my $div = $_;
        my $key = $div->find_xpath('label')->get_node(1);
        my $field_name  = $key->attr('for');
        $key = $key ? $mech->_xclient_parse_cell( $key ) : '';
        $key =~ s/\:$//;

        my $value = $div->find_xpath('*[contains(@name,"' . $field_name . '")]')->get_node(1);
        # can't find it under the 'name' then search using the 'id'
        # which is what the 'for' on a label tag should point to anyway
        $value  //= $div->find_xpath('*[contains(@id,"' . $field_name . '")]')->get_node(1);

        if ( $value && $value->tag eq 'input' ) {
            given ( $value->attr('type') ) {
                when ( 'checkbox' ) {
                    my $checked = $value->attr('checked');
                    $value = (
                        $checked
                        ? $mech->_xclient_trim_cell( $value->attr('value') )
                        : undef
                    );
                }
                default {
                    $value  = $mech->_xclient_trim_cell( $value->attr('value') );
                }
            }
        }
        else {
            $value = $value ? $mech->_xclient_parse_cell( $value ) : '';
        }

        ( $key, $value );
    } $node->find_xpath('div[contains(@class,"formrow")]/label/..')->get_nodelist();

    # now find any hidden fields
    my %hidden  = map {
            my $input   = $_;
            my $key     = $input->attr('name');
            my $value   = $input->attr('value');
            ( $key, $value );
        } $node->find_xpath('input[contains(@type,"hidden")]')->get_nodelist();

    $table{hidden_fields}   = \%hidden;

    return \%table;
}

# Parse the shipment summary table from packing_common.tt
sub _xclient_packing_common_template {
    my ( $mech, $node ) = @_;
    my $base_table = $mech->_xclient_parse_formrow_table( $node );

    # Get QC notes
    my $notes_node = $node->find_xpath('id(\'quality-control-notes\')')->get_node(0);
    my $notes_table = $mech->_xclient_parse_table( $notes_node, allow_blank_rows => 1 );
    # Remove the editor note
    pop(@$notes_table);
    # Fix ID
    for my $note ( @$notes_table ) {
        my $url = $note->{''}->{'url'};
        delete $note->{''};
        my ($id) = $url =~ m/note_id=(\d+)/;
        $note->{'ID'} = $id;
    }

    $base_table->{'Notes'} = $notes_table;

    return $base_table;
}

=head2 customercare_size_change_table

Takes the table on C</CustomerCare/CustomerSearch/SizeChange>,
loses the 'Choose ...' prompt values and tidies up the select
list so that it is an array of hashes of this form:

    {
       SKU => '12345-678',
       name => 'The Changeable Item Name',
       size => '34DD',
       select_item => {
       name    => 'form name for checkbox',
       value   => 'form value for checkbox',
       checked => 'current value for checkbox',
       },
       change_to => {
           name        => 'form name for selection',
           selected    => 'index of value selected, -1 otherwise',
           values => [
               { name => 'form name for option 1',
                value => 'form value for option 1',
               },
               { name => 'form name for option 2',
                value => 'form value for option 2',
               },
               [...]
           ]
       },
       stock_discrepancy => {
           name    => 'form name for checkbox',
           value   => 'form value for checkbox',
           checked => 'current value of checkbox'
       }
    }

Or, when there is no control to select a different size for
an item:

    {
       SKU => '12345-679',
       name => 'The Unchangeable Item Name',
       size => '34DD',
       select_item => 'text in place of checkbox',
       change_to => 'text in place of select list',
       stock_discrepancy => 'text in place of checkbox'
    }

Note that it's not a hash indexed by SKU, because SKU isn't
guaranteed to be unique in the list.

Note also that it doesn't return the E-mail form, if it's present.

=cut

sub _xclient_customercare_size_change_table {
        my ( $mech, $node ) = @_;

    return [ map {
            my $item = $_;
        my $props;

        if (ref $item->{SKU} eq 'HASH') {
            $props->{SKU}  = $item->{SKU}->{value};
        }
        else {
            $props->{SKU}  = $item->{SKU};
        }

        $props->{name} = $item->{Name};
        $props->{size} = $item->{Size};

        $props->{select_item}=_simplify_labelled_checkbox(
                                      $item,
                      'Select Item(s)'
                  );

        $props->{stock_discrepancy}=_simplify_labelled_checkbox(
                                        $item,
                        'Stock Discrepancy'
                    );

        if (ref $item->{'Change To'} eq 'HASH') {
        $props->{change_to}->{name}   = $item->{'Change To'}->{select_name};

        # extract option elements 2 onwards because the first two option elements
        # are a prompt, and a bunch of dashes, neither of which are actually data,
        # but merely part of the user interface stuffed into the select list
        my $end_element=scalar(@{$item->{'Change To'}->{select_values}})-1;
        my @select_items=@{$item->{'Change To'}->{select_values}}[2..$end_element];

        push @{$props->{change_to}->{values}}, map { { value => $_->[0], name  => $_->[1] } } @select_items;

        my $selected_name=$item->{'Change To'}->{select_selected}->[1];

            $props->{change_to}->{selected} = first_index { $_->[1] eq $selected_name } @select_items;
        }
        else {
        $props->{change_to} = $item->{'Change To'};
        }

        $props;
    } @{$mech->_xclient_parse_table( $node )}];
}

sub _xclient_packing_check_shipment_exception_table {
    my ( $mech, $node ) = @_;
    return [
        map {
            my $item = $_;
            $item->{SKU} = $item->{SKU}->{value} if ref $item->{SKU} eq 'HASH';
            $item->{SKU} =~ s/.*?([-0-9]+).*/$1/;
            my $raw = delete $item->{'raw'};
            my $shipment_item_node =
                $raw->find_xpath('td/form/input[@name="shipment_item_id"]')->get_node(1);
            $item->{'Shipment Item ID'} = $shipment_item_node?
                $shipment_item_node->attr('value') : undef;
            $item;
        }
        @{$mech->_xclient_parse_table( $node, with_raw_rows => 1 )}
    ];
}

=head2 get_messages_for_packers

Get Messages for Packers out of the 'PackShipment' page.

=cut

sub _xclient_get_messages_for_packers {
    my ( $mech, $node )     = @_;

    my %messages;

    # get Marketing Promotion Messages
    my @nodes   = $node->find_xpath('//*[starts-with(@id,"marketing_promotion_")]')->get_nodelist();
    foreach my $node ( @nodes ) {
        my $id  = $node->attr('id');
        $id =~ s/^marketing_promotion_//;
        $messages{marketing_promotion}{ $id } = $mech->_xclient_parse_cell( $node );
    }

    return \%messages;
}

sub _xclient_purchase_order_search {
        my ( $mech, $node ) = @_;
        return [map {
            my $item = $_;
            delete $item->{''};
            my $stock_order_url = $item->{'PID'}->{'url'};
            $item->{'PID'} = $item->{'PID'}->{'value'};
            ($item->{'Stock Order ID'}) = $stock_order_url =~ m/=(\d+)/g;
            $item->{'Stock In URL'} = $stock_order_url;
            $item;
        } @{$mech->_xclient_parse_table( $node )}];
}

# This is the putaway sheet generated by GoodsIn/QualityControl
sub _xclient_printdoc_putaway_metadata {
    my ($mech, $node) = @_;

    my %metadata;
    $metadata{page_type} = $mech->_xclient_parse_cell(
                               $node->find_xpath('font/table[1]/tbody/tr[1]/td[2]/table/tr[2]/td/h1')
                                    ->get_node(1)
                           );
    @metadata{qw/delivery_number process_group_id/} =
        map { s/.+: //r; } # Get the part after the colon
        map { $mech->_xclient_parse_cell( $_ ) } # Parse the cell
        $node->find_xpath('font/table[1]/tbody/tr[2]/td')->get_nodelist();

    # Add keys to metadata based on what's in the bordered table...
    %metadata = (%metadata,
        map { split(/: /) } # Split in to key value
        map { $mech->_xclient_parse_cell( $_ ) } # Parse the cell
        $node->find_xpath('font/table[2]/tbody/tr/td')->get_nodelist()
    );

    return \%metadata;
}

sub _xclient_printdoc_putaway_item_table {
    my ( $mech, $node ) = @_;

    # Get the data rows ... we're looking for rows that have a 3rd column
    my @table = map {
        my $row = $_;
        my @cols = map {
            $mech->_xclient_parse_cell($_)
        } $row->find_xpath('td')->get_nodelist();
        \@cols;
    } $node->find_xpath('tr[td[2]]')->get_nodelist();

    # Match column headers to rows
    @table = @{ $mech->_xclient_map_table( \@table ) };

    return \@table;
}

sub _xclient_printdoc_table {
    my ( $mech, $node ) = @_;

    # Get the data rows ... we're looking for rows that have a 3rd column
    my @table = map {
        my $row = $_;
        my @cols = map {
            $mech->_xclient_parse_cell($_)
        } $row->find_xpath('td')->get_nodelist();
        \@cols;
    } $node->find_xpath('tr[td[4]]')->get_nodelist();

    # Match column headers to rows
    @table = @{ $mech->_xclient_map_table( \@table ) };

    # Adjust locations
    @table = map {
        my $row = $_;
        $row->{'Display Location'} = $row->{'Location'};
        $row->{'Location'} = $mech->_xclient_translate_location(
            $row->{'Location'}
        );
        $row;
    } @table;

    return \@table;
}

sub _xclient_printdoc_pickinglist_shipment_data {
    my ( $mech, $node ) = @_;
    my $data = {};
    for (
        [ 'Printed Date',    'font/table[1]/tbody/tr[1]/td[1]/h4' ],
        [ 'Shipment Number', 'font/table[1]/tbody/tr[1]/td[1]/h3/b' ],
        [ 'Shipment Date',   'font/table[1]/tbody/tr[2]/td/table/tr[1]/td[2]/font' ],
        [ 'Customer Number', 'font/table[1]/tbody/tr[2]/td/table/tr[1]/td[5]/font' ],
        [ 'Customer Name',   'font/table[1]/tbody/tr[2]/td/table/tr[2]/td[5]/font/b' ],
        [ 'SLA Cut-Off',     'font/table[1]/tbody/tr[2]/td/table/tr[3]/td[2]/font' ],
    ) {
        my ( $key, $xpath ) = @$_;
        $data->{$key} = $mech->_xclient_parse_cell(
            $node->find_xpath( $xpath )->get_node(1)
        );
    }
    for ( 'Printed Date', 'Shipment Number' ) {
        $data->{$_} =~ s/^.+?\: //;
    }
    return $data;
}

my @_xclient_printdoc_shippinglist_shipment_items_remap = (
    [ 'HS CODE'       => 'HS Code'  ],
    [ 'QTY'           => 'Quantity' ],
    [ 'WEIGHT'        => 'Weight'   ],
    [ 'SUBTOTAL'      => 'Subtotal' ],
    [ 'FABRICCONTENT' => 'Fabric'   ],
    [ 'DESCRIPTION'   => 'Description' ],
    [ 'UNITPRICE'     => 'Unit Price'  ],
    [ 'SKU'           => 'Product ID'  ],
    [ 'COUNTRY OFORIGIN' => 'Country'  ]
);

sub _xclient_printdoc_shippinglist_shipment_items {
    my ( $mech, $node ) = @_;
    my @rows;

    for my $row ( $node->find_xpath('tr[@bgcolor!="#ffffff"]')->get_nodelist ) {
        my @cols = map {
            $mech->_xclient_parse_cell( $_ )
        } $row->find_xpath('td')->get_nodelist();
        push( @rows, \@cols );
    }

    @rows = map {
        my $old_hash = $_;
        my $new_hash = {};
        $new_hash->{ $_->[1] } = $old_hash->{ $_->[0] } for
            @_xclient_printdoc_shippinglist_shipment_items_remap;
        $new_hash;
    } @{$mech->_xclient_map_table( \@rows )};

    return \@rows;
}

sub _xclient_printdoc_shippinglist_shipment_data {
    my ( $mech, $node ) = @_;
    my $data = {};

    # This table is a real damn mess. Our containment strategy for that is to
    # loop through all the non-divider nodes, and use anything with a bold tag
    # as a key, and concat the rest as values... :-/
    my $cursor = "";

    for my $cell ( $node->find_xpath( 'tr/td' )->get_nodelist ) {
        my $value = $mech->_xclient_parse_cell( $cell );

        if ( $cell->find_xpath( 'descendant::b' ) ) {
            $value =~ s/\:$//;
            $cursor = $value;
        } else {
            next unless length $value;
            if ( exists $data->{$cursor} ) {
                $data->{$cursor} .= "\n" . $value;
            } else {
                $data->{$cursor} = $value;
            }
        }
    }

    delete $data->{''};
    $data;
}

# RMA tables have all sorts of extra data on them that stop us doing a general
# table parse on them...
sub _xclient_rma_request_results_table {
    my ( $mech, $node ) = @_;

    # First pass
    my @rows =
        # Big clean
        map {
            my $old_row = $_;
            my $new_row = {};

            # Clean up Designer info
            $new_row->{'Designer'}->{'Name'} =
                $old_row->{'Designer'}->{'value'};
            ($new_row->{'Designer'}->{'ID'}) =
                $old_row->{'Designer'}->{'url'} =~ m/id=(\d+)/;

            # Clean up PIDs
            $new_row->{'PID'}  = $old_row->{'SKU(PID'}->{'value'};
            $new_row->{'Size'} = $old_row->{'Size ID)'}->{'value'};
            $new_row->{'SKU'} = $new_row->{'PID'} . '-' . $new_row->{'Size'};
            ($new_row->{'Variant ID'}) =
                $old_row->{'Size ID)'}->{'url'} =~ m/id=(\d+)/;

            # Quantity
            if ( ref($old_row->{'Qty.'}) ) {
                ($new_row->{'Quantity'}) =
                    $old_row->{'Qty.'}->{'value'} =~ m/^(\d+)/;
            } else {
                $new_row->{'Quantity'} = $old_row->{'Qty.'};
            }

            # Dates
            for (
                'Date',
                ['Delivery Date', 'DeliveryDate'],
                ['Style Ref', 'Style Ref.' ],
                'Origin'
            ) {
                my ($to, $from) = ref($_) ? @$_ : ($_, $_);
                $new_row->{$to} = $old_row->{$from};
            }

            $new_row;
        }
        # Only real rows (strip out the ones to house checkboxes)
        grep { $_->{'DeliveryDate'} }
        # Start with a basic table parse
        @{ $mech->_xclient_parse_table($node) };

    # Second pass - get the fault type, quarantine note, and the quantity id
    my $row_i = 0;
    for my $row ( $node->find_xpath('tbody/tr[@style]')->get_nodelist() ) {

        # Parse the fault_type and description cells
        my ( $fault_type, $description ) =
            map { $mech->_xclient_parse_cell($_) }
            $row->find_xpath('td/table/tr/td')->get_nodelist();

        # Quantity Row this is representing
        ($rows[ $row_i ]->{'Quantity ID'}) =
            $fault_type->{'select_name'} =~ m/(\d+)$/;

        # Information about the fault
        ($rows[ $row_i ]->{'Fault ID'}, $rows[ $row_i ]->{'Fault Name'}) =
            @{$fault_type->{'select_selected'}};

        # Quarantine note
        $rows[ $row_i ]->{'Quarantine Note'} = $description->{'value'};
        $row_i++;
    }

    return \@rows;
}

# This performs the magic needed for stock counts in a process group. Extra
# information ('hints') about locations are inserted in to the formerly
# well-structured table. This routine does a basic table parse, and then merges
# the 'hint' rows in to the row that follows them.
sub _xclient_product_list {
    my ( $mech, $node ) = @_;
    my @rows = @{ $mech->_xclient_parse_table($node) };
    my @merged_rows;
    while (@rows) {
        my $hint   = shift(@rows);
        my $target = shift(@rows);

        # Extract data from the bogusly labelled columns into the correct place
        $target->{'Hint'}->{'Quantity'} = $hint->{'Designer Size'};
        $target->{'Hint'}->{'Type'}     = $hint->{'PID'};
        $target->{'Hint'}->{'Location'} = $hint->{'Type'};

        push( @merged_rows, $target );
    }
    return \@merged_rows;
}

# Transforms product summary tables in to data
sub _xclient_product_summary {
    my ( $mech, $node ) = @_;

    # This is where we build the data in to
    my $product = {};

    # Retrieve the ID and description
    my $summary =
      $mech->_xclient_parse_cell(
        $node->find_xpath('thead/tr/td')->get_node(1) )->{'value'};
    ( $product->{'ID'}, $product->{'Description'} ) =
      split( /\s*\:\s*/, $summary );

    # Try and parse out the funny horizontal tables. This is necessarily a
    # little fragile as they're not semantically marked out.
    %$product = (
        %$product,
        map {
            my $val = $mech->_xclient_parse_cell($_) || '';
            $val =~ s/\:$//;
            $val
          } $node->find_xpath('tbody//table[1]//table//td')
          ->get_nodelist()
    );

    # Sales channel
    $product->{'Channels'} =
      $mech->_xclient_parse_channel_table(
        $node->find_xpath('tbody/tr/td/table[2]')->get_node(1) );

    return $product;
}

=head2 customer_reservation_create_buttons

Will parse the Create Buttons found on the 'Customer Reservations & Pre Order' page.

=cut

sub _xclient_customer_reservation_create_buttons {
    my ( $mech, $node ) = @_;

    my %buttons;

    my @wrapper_nodes    = $node->find_xpath( 'span[starts_with(@id,"customer__create_")]' )->get_nodelist;
    foreach my $wrapper ( @wrapper_nodes ) {
        my $id  = $wrapper->attr('id');
        $id     =~ s/customer__create_(.*)_button_wrapper/$1/;

        # find the button else just parse the wrapper
        my $button  = $wrapper->find_xpath( 'form/input[contains(@type,"submit")]' )->get_node(1);
        $buttons{ $id } = (
                            $button
                            ? { found => 1 }
                            : { found => 0, message => $mech->_xclient_parse_cell( $wrapper ) }
                        );
    }

    return \%buttons;
}

=head2 reservation_email

Parses the Reservation/Email page which has Mutli Channel Tabs which have different sets of tables in them.
For each customer there are 3 tables:
* The First Table contains the Customer Info
* The Second the Details used to send the Email
* The Third lists all the Products that have been reserved for them

=cut

sub _xclient_reservation_email {
    my ( $mech, $node ) = @_;

    my $tables;

    # Get the Sales Channel Tabs
    my @tabs    = map {
                    my $tab = $_;
                    my $url = $tab->attr('href');
                    $url    =~ s/^#//;
                    my $name= $mech->_xclient_trim_cell( $tab->as_text );
                    $name   =~ s/\s+\(.+//;
                    {
                        name => $name,
                        id => $url
                    };
            } $node->find_xpath(
                        '//div[@id="tabContainer"]/table[@class="tabChannelTable"]//a')
                  ->get_nodelist();

    # go through each tab and get the contents for it
    foreach my $tab ( @tabs ) {
        # get a form per Customer
        my @forms   = $node->find_xpath(
                            '//div[@id="' . $tab->{'id'} . '"]/div[@class="tabInsideWrapper"]/form[@name]'
                          )->get_nodelist();

        foreach my $form ( @forms ) {
            next        if ( $form->attr('name') !~ /^emailCustomer-\d+/ );

            # get the 3 tables in the form
            my @tables  = $form->find_xpath('table')->get_nodelist();

            my $form_tab;

            # parse the first table which contains Customer Number
            $form_tab->{'customer_info'}  = $mech->_xclient_parse_vertical_table( $tables[0] );

            # parse the second table which contains From Email Address
            $form_tab->{'email_info'}  = $mech->_xclient_parse_vertical_table( $tables[1] );

            # parse the third table which contains the list of Products
            $form_tab->{'list'}   = $mech->_xclient_parse_table( $tables[2] );

            push @{ $tables->{ $tab->{name} } }, $form_tab;
        }
    }

    return $tables;
}

=head2 product_reservation_list

Parses the List of Reservations shown after a Product Search. There is a Table for each Variant followed by an optional Table
listing all Customers who have placed a Reservation for that Variant (SKU). It is split between Reservations and Pre-Orders.

    {
        'channel_name' => {
            'reservation' => {
                    variant_id => {
                        customers   => [ { ... } ],
                        variant     => [ { ... } ],
                    },
                    ...
                },
            'preorder' => {
                    variant_id => {
                        customers   => [ { ... } ],
                        variant     => [ { ... } ],
                    },
                    ...
                },
            },
        ...
    }

=cut

sub _xclient_product_reservation_list {
    my ( $mech, $node )     = @_;

    my @tabs    = $mech->_xclient_parse_channel_tabs( $node );

    my $tables;

    foreach my $tab ( @tabs ) {
        # get reservation & preorder Tabs within Tabs
        foreach my $subtab ( qw( reservation preorder ) ) {
            my $sub_node_xpath  = "//div[\@id='${subtab}_tabview-$tab->{conf_section}']";

            # get a list of tables in the Tab that start with 'variant_'
            my @variant_tables  = $tab->{node}->find_xpath("${sub_node_xpath}/table[starts-with(\@id,'variant_')]")->get_nodelist;
            foreach my $table ( @variant_tables ) {
                my $tabid   = $table->attr('id');
                if ( $tabid  =~ m/^variant(?<customers>_customers)?_(?<variant_id>\d+)$/ ) {
                    my $variant_id  = $+{variant_id};
                    my $tab_type    = ( $+{customers} ? 'customers' : 'variant' );

                    my $data    = $mech->_xclient_parse_table( $table, allow_blank_rows => 1 );
                    $tables->{ $tab->{name} }{ $subtab }{ $variant_id }{ $tab_type }   = $data;
                }
            }
        }
    }

    return $tables;
}

=head2 reservation_overview_upload

Parses the Reservation Overview Upload page.

=cut

sub _xclient_reservation_overview_upload {
    my ( $self, $node )     = @_;
    return $self->_xclient_reservation_overview( $node, 'Upload' );
}

=head2 reservation_overview_pending

Parses the Reservation Overview Pending page.

=cut

sub _xclient_reservation_overview_pending {
    my ( $self, $node )     = @_;
    return $self->_xclient_reservation_overview( $node, 'Pending' );
}

=head2 reservation_overview_waiting

Parses the Reservation Overview Waiting List page.

=cut

sub _xclient_reservation_overview_waiting {
    my ( $self, $node )     = @_;
    return $self->_xclient_reservation_overview( $node, 'Waiting' );
}

=head2 _xclient_reservation_overview

    $self->_xclient_reservation_overview_upload( $node, 'Upload' | 'Pending' | 'Waiting' );

General Parser used by the Upload, Pending and Waiting List pages.

=cut

sub _xclient_reservation_overview {
    my ( $mech, $node, $type )  = @_;

    my @tabs    = $mech->_xclient_parse_channel_tabs( $node );

    my %tables;
    foreach my $tab ( @tabs ) {
        my $channel_name    = $tab->{name};
        my $data    = {};

        if ( $type eq 'Upload' ) {
            my $deeply_setting  = $mech->client_parse_cell_deeply;
            $mech->client_parse_cell_deeply( 1 );

            my $table   = $node->find_xpath( '//table[@id="upload_selection-' . $channel_name . '"]' )->get_node(1);
            $data->{upload_selection}   = $mech->_xclient_parse_vertical_table( $table );

            $mech->client_parse_cell_deeply( $deeply_setting );

            # now get any Resevations on the page
            # which are grouped by Season
            my @season_divs = $node->find_xpath( '//div[starts-with(@id,"hideShow_' . $channel_name . '_")]' )->get_nodelist;
            foreach my $div ( @season_divs ) {
                my $season  = $div->attr('id');
                $season     =~ s/^hideShow_${channel_name}_//;

                my $table   = $div->find_xpath('table')->get_node;
                $data->{seasons}{ $season } = $mech->_xclient_parse_table( $table );
            }
        }

        $tables{ $channel_name }    = $data;
    }

    return \%tables;
}

=head2 _xclient_reservation_upload_filtered

=cut

sub _xclient_reservation_upload_filtered {
    my ( $mech, $node )     = @_;

    my %tables;

    # the Designer List should only be 1 column
    my @designer_cells  = $node->find_xpath('//table[@id="designer_list_table"]/tr/td')->get_nodelist;
    foreach my $cell ( @designer_cells ) {
        my $parsed  = $mech->_xclient_parse_cell( $cell );
        $tables{designers}{ $parsed->{input_value} }    = $parsed->{value}      if ( ref( $parsed ) );
    }

    # the Product List will be 2 columns, but not if
    # there aren't any Products then it will be just
    # the one which we don't want to bother parsing
    my $product_tab = $node->find_xpath('//table[@id="product_list_table"]')->get_node(1);
    if ( $product_tab->find_xpath('tr[1]/td[2]')->get_node(1) ) {
        my $contents        = $mech->_xclient_parse_vertical_table( $product_tab );
        # make it 'pid => name'
        $tables{products}   = {
                        map { $_ => $contents->{ $_ }{value} }
                                keys %{ $contents }
                    };
    }

    return \%tables;
}

=head2 _xclient_reservation_view_waiting_lists

Will parse the Reservation Waiting Lists page which is found under the 'View' section of the left hand menu.

=cut

sub _xclient_reservation_view_waiting_lists {
    my ( $mech, $node )     = @_;

    my %tables;

    my @tabs    = $mech->_xclient_parse_channel_tabs( $node );

    foreach my $tab ( @tabs ) {
        my $channel_name    = $tab->{name};

        # get the Customer Reservations per Operator
        my $starts_with = "tbl_next_upload_${channel_name}_";
        my @upload_tables   = $node->find_xpath( '//table[starts-with(@id,"' . $starts_with . '")]' )->get_nodelist;
        $starts_with    = "tbl_other_upload_${channel_name}_";
        push @upload_tables, $node->find_xpath( '//table[starts-with(@id,"' . $starts_with . '")]' )->get_nodelist;

        foreach my $table ( @upload_tables ) {
            my $id      = $table->attr('id');
            $id         =~ m/^tbl_(?<key>.*)_${channel_name}_(?<op_id>\d+)_(?<cust_id>\d+)/;
            my $key     = $+{key};
            my $op_id   = $+{op_id};
            my $cust_id = $+{cust_id};
            $tables{ $channel_name }{ $key }{ $op_id }{ $cust_id }  = $mech->_xclient_parse_table( $table, ( with_raw_rows => 1 ) );
        }

        # get the operator headings, should only be present if using the 'Show All' filter
        $starts_with = "tbl_op_next_upload_${channel_name}_";
        my @op_tables   = $node->find_xpath( '//table[starts-with(@id,"' . $starts_with . '")]' )->get_nodelist;
        $starts_with    = "tbl_op_other_upload_${channel_name}_";
        push @op_tables, $node->find_xpath( '//table[starts-with(@id,"' . $starts_with . '")]' )->get_nodelist;

        foreach my $table ( @op_tables ) {
            my $id      = $table->attr('id');
            $id         =~ m/^tbl_op_(?<key>.*)_${channel_name}_(?<op_id>\d+)/;
            my $key     = $+{key};
            my $op_id   = $+{op_id};
            my $cell    = $table->find_xpath('tr[2]/td[2]')->get_node;
            my $value   = $mech->_xclient_parse_cell( $cell );
            $value      =~ s/Operator: //;
            $tables{ $channel_name }{ $key }{ $op_id }{heading} = { id => $op_id, name => $value };
        }
    }

    return \%tables
}


sub _xclient_preorder_list {
    my ( $mech, $node )     = @_;

    my $starts_with="preorder__data";
    my @preorder_tables = $node->find_xpath( '//table[starts-with(@name,"' . $starts_with . '")]' )->get_nodelist;
    my $tables;
    foreach my $table ( @preorder_tables) {
        my $id = $table->attr('id') //' phew';
        $tables->{$id} = $mech->_xclient_parse_table( $table );
    }
    return $tables;
}

=head2 consistency_report

Parses the Reporting/StockConsistency page which has Mutli Channel Tabs which have different sets of tables in them.

For each Channel there are 4 tables:
* WEB/XT Stock Consistency
* WEB/XT Reservation Consistency
* Negative Stock
* Potential Duplicate Returns

=cut

sub _xclient_consistency_report {
    my ( $mech, $node ) = @_;

    my $tables;

    # Get the Sales Channel Tabs
    my @tabs    = map {
                    my $tab = $_;
                    my $url = $tab->attr('href');
                    $url    =~ s/^#//;
                    my $name= $mech->_xclient_trim_cell( $tab->as_text );
                    $name   =~ s/\s+\(.+//;
                    {
                        name => $name,
                        id => $url
                    };
            } $node->find_xpath(
                        '//div[@id="tabContainer"]/table[@class="tabChannelTable"]//a')
                  ->get_nodelist();

    # go through each tab and get the contents for it
    foreach my $tab ( @tabs ) {
        # get the Id number out of the id field
        my $id  = $tab->{id};
        $id     =~ s/[^\d]//g;

        foreach my $tab_id ( qw( web_xt_reservation negative dupe_returns ) ) {
            my $table   = $node->find_xpath("//table[\@id='${tab_id}_${id}']")->get_node;
            $tables->{ $tab->{name} }{ $tab_id } = $mech->_xclient_parse_table( $table )     if ( $table );
        }
    }

    return $tables;
}

sub _xclient_active_invoices {
    my ( $mech, $node ) = @_;

    my $tables;


    # Get the Sales Channel Tabs
    my @tabs    = map {
                    my $tab = $_;
                    my $url = $tab->attr('href');
                    $url    =~ s/^#//;
                    my $name= $mech->_xclient_trim_cell( $tab->as_text );
                    $name   =~ s/\s+\(.+//;
                    {
                        name => $name,
                        id => $url
                    };
            } $node->find_xpath(
                        '//div[@id="tabContainer"]/table[@class="tabChannelTable"]//a')
                  ->get_nodelist();


    # go through each tab and get the contents for it
    foreach my $tab ( @tabs ) {

        # get the Id number out of the id field
        my $id  = $tab->{id};
        $id     =~ s/[^\d]//g;

        my @headings    = $node->find_xpath('//*[starts-with(@id,"heading_'. ${id}. '_")]')->get_nodelist();
        foreach my $heading ( @headings ) {
            my $heading_name = $heading->getValue;
            my $table_id     = $heading->attr('id');
            $table_id        =~ s/^heading_/table_/;
            my $table        = $node->find_xpath('//table[@id="'. $table_id. '"]')->get_node;
            $tables->{ $tab->{name} }{ $heading_name }  = $mech->_xclient_parse_table( $table )     if ( $table );
        }
    }
    return $tables;
}

=head2 parse_invoice_item_table

=cut

sub _xclient_parse_invoice_item_table {
    my ( $mech, $node, %opts ) = @_;

    # get multiple header rows
    my @header_cells    = $node->find_xpath('//td[contains(@class,"hack_heading")]')
                                    ->get_nodelist();
    my @table;

    # Get the column names
    my @header_cols;
    foreach my $cell ( @header_cells ) {
        my $name    = $mech->_xclient_trim_cell( $cell->as_text ) || '';
        if ( my $num_of_this_heading = $cell->attr('colspan')  ) {
            foreach my $n ( 1..$num_of_this_heading ) {
                push @header_cols, "${name}${n}";
            }
        }
        else {
            push @header_cols, $name;
        }
    }
    push(
        @table,
        [
            @header_cols,
            ( $opts{'with_raw_rows'} ? 'raw' : () )
        ]
    ) if @header_cols;
    my $found_in_th = @table ? 1 : 0;

    # Get the data rows
    # Use the 'tr with a height set method'
    my @rows = $node->find_xpath('tbody/tr[@height]')->get_nodelist();
    # If that doesn't work, get rows that don't have divider children or th elements
    unless ( @rows ) {
        @rows = grep {
            ! (
                $_->find_xpath('td[@class="divider"]')->get_node(0) ||
                $_->find_xpath('td[@class="dividerHeader"]')->get_node(0) ||
                $_->find_xpath('td[@class="blank"]'  )->get_node(0) ||
                $_->find_xpath('th')->get_node(0)
            )
        } $node->find_xpath('tr|tbody/tr')->get_nodelist();
    }

    for my $r ( @rows ) {
        my @tds = map { $mech->_xclient_parse_cell($_) }     $r->find_xpath('td')->get_nodelist();
        if ( $opts{'with_raw_rows'} ) {
            push(@tds, $r) if @tds > 1;
        }
        push( @table, \@tds );
    }

    # Remove any blank rows
    @table = grep { @$_ > 1 } @table;

    # Add an extra column to the columns row for raw if needed
    if ( $opts{'with_raw_rows'} && ! $found_in_th ) {
        $table[0]->[-1] = 'raw'; # It'll be a raw element!
    }

    return $mech->_xclient_map_table( \@table, %opts );
}

=head2 get_fraud_hotlist_tables

Returns the Tables on the Fraud Hotlist page.

=cut

sub _xclient_get_fraud_hotlist_tables {
    my ( $mech, $node ) = @_;

    my %tables;

    # get Add Hotlist Entry table
    my $add_entry   = $node->find_xpath('id("fraud_hotlist_entry")')->get_node(0);
    $tables{hotlist_add_entry} = $mech->_xclient_parse_vertical_table( $add_entry )     if ( $add_entry );

    # get Hotlist Entry tables
    my $qry     = $node->find_xpath('//table[starts-with(@id, "fraud_hotlist_list_")]');
    %tables     = (
        %tables,
        %{ $mech->_xclient_parse_list_of_tables( $qry ) },
    );

    return \%tables;
}

=head2 parse_check_pricing_product_list_table

Returns the Product List table on the 'Check Pricing' page which is off the Order View page.

=cut

sub _xclient_parse_check_pricing_product_list_table {
    my ( $mech, $node )     = @_;

    # get the two rows that make up the Headings
    my @header_rows = grep {
            (
                $_->find_xpath('td[@class="tableHeader"]')->get_node(0)
            )
        } $node->find_xpath('tr|tbody/tr')->get_nodelist();
    my @row1 = $header_rows[0]->find_xpath('td')->get_nodelist();
    my @row2 = $header_rows[1]->find_xpath('td')->get_nodelist();

    # go through each cell of the first row and replace any headings that
    # span multiple columns with columns from the second header row
    foreach my $td ( @row1 ) {
        my $rowspan = $td->attr('rowspan') // 0;
        my $colspan = $td->attr('colspan') // 0;

        if ( $rowspan ) {
            # remove the 'rowspan' attribute
            $td->attr('rowspan', undef);
        }
        if ( $colspan && !$rowspan ) {
            # replace a heading that spans columns
            # with those headings from the second
            # row that it is spanning
            my $prefix  = $mech->_xclient_parse_cell( $td );
            my @nodes;
            foreach ( 1..$colspan ) {
                my $node    = shift @row2;
                if ( $node ) {
                    $node->unshift_content( "${prefix}_" );
                    $node->detach;
                    push @nodes, $node;
                }
            }
            $td->replace_with( @nodes );
        }
    }
    # delete the second row of Headings
    $header_rows[1]->delete;

    # now parse the table normally
    my $rows = $mech->_xclient_parse_table( $node );

    # get the Shipping Charge which should be the last row
    my $shipping_charge = pop @{ $rows };

    # clean up the rows
    my @new_rows;
    ROW:
    foreach my $row ( @{ $rows } ) {
        # if there is NO Designer or Name then this row holds
        # Shipping Restrictions for the previous Item in the PID
        if ( !$row->{Designer} && !$row->{Name} ) {
            if ( @new_rows ) {
                $new_rows[-1]->{restriction} = $row->{PID};
                next ROW;
            }
        }

        # some fields have hidden fields in them
        # so for those we just want their 'values'
        foreach my $key ( keys %{ $row } ) {
            if ( ref( $row->{ $key } ) ) {
                $row->{ $key }  = $row->{ $key }{value};
            }
        }

        push @new_rows, $row;
    }

    return {
        shipping_charge => {
            current_price   => $shipping_charge->{'Current Pricing_Price'},
            new_price       => (
                # if there's a change in Shipping Charges then the
                # new value will be in a HIDDEN field if there's no
                # difference then there will just be a plain value
                ref( $shipping_charge->{'New Pricing_Price'} )
                ? $shipping_charge->{'New Pricing_Price'}{value}
                : $shipping_charge->{'New Pricing_Price'}
            ),
        },
        items => \@new_rows,
    };
}

=head2 welcome_pack_page

Parses the NAPEvents/WelcomePacks page.

=cut

sub _xclient_welcome_pack_page {
    my ( $mech, $node ) = @_;

    $mech->client_parse_cell_deeply(1);

    # get the Welcome Pack Tables
    my $qry     = $node->find_xpath('//table[starts-with(@id, "welcome_pack_")]');
    my $tables  = $mech->_xclient_parse_list_of_tables( $qry );
    my $log_table;

    # determine the Setting of each Pack either On or Off (1 or 0)
    TABLE:
    foreach my $tab_id ( keys %{ $tables } ) {

        # store the Log table for later
        if ( $tab_id eq 'welcome_pack_change_log' ) {
            $log_table  = delete $tables->{ $tab_id };
            next TABLE;
        }

        foreach my $row ( @{ $tables->{ $tab_id } } ) {
            $row->{Setting} = (
                # the first option is 'On' and if checked set to 1
                $row->{Setting}{inputs}[0]{input_checked}
                ? 1
                : 0
            );
        }
    }

    # get the 'Enable All Packs' checkboxes
    my %switches;
    my @elements = $node->find_xpath('//span[starts-with(@id, "conf_group_")]')->get_nodelist;
    foreach my $element ( @elements ) {
        # the 'checkbox' input is the first of the inputs
        # the hidden '*_checkbox' input is the second
        my $value = $mech->_xclient_parse_cell( $element )
                            ->{inputs}[0];
        $switches{ $element->attr('id') } = (
            $value->{input_checked} ? 1 : 0
        );
    }

    $mech->client_parse_cell_deeply(0);

    return {
        log      => $log_table,
        tables   => $tables,
        switches => \%switches,
    };
}

=head2 inthebox_promotion_details

Parses the In The box Marketing Details.

=cut

sub _xclient_inthebox_promotion_details {
    my ( $mech, $node ) = @_;

    my $general = $mech->_xclient_parse_vertical_table(
        $node->find_xpath('id("bd")/table[1]')->get_node
    );

    # get rid of the '*' at then end of some keys
    $mech->__xclient_remove_trailing_char_from_column_name( '*', $general );

    # if the Promotion is Weighted then get the Weighted Details
    my $weighted;
    if ( $general->{Weighted}[0]{select_selected}[0] ) {
        $weighted   = $mech->_xclient_parse_vertical_table(
            $node->find_xpath('id("weighted")/table[1]')->get_node
        );
        $mech->__xclient_remove_trailing_char_from_column_name( '*', $weighted );
    }

    return {
        general => $general,
        ( $weighted ? ( weighted => $weighted ) : () ),
    };
}

=head2 inthebox_promotion_options

Parses the Options such as Designer, Countries etc. that have been
assigned to an In The Box Marketing Promotion.

=cut

sub _xclient_inthebox_promotion_options {
    my ( $mech, $node ) = @_;

    # get all the DIVs with an Id of 'inthebox_.*_list'
    my @divs = grep {
        $_->attr('id') =~ /_list$/
    } $node->find_xpath( 'div[starts-with(@id,"inthebox_")]' )->get_nodelist;

    my %retval;

    my %options;
    foreach my $div ( @divs ) {
        $div->attr('id') =~ m/^inthebox_(?<option_type>.*)_list$/;
        my $option_type  = $+{option_type};

        # get a list of the Ids assigned to the Option
        my $included_ids = $div->find_xpath( "input[id('${option_type}_id_list_include')]" )->get_node //
                            $div->find_xpath( "input[id('${option_type}_list_include')]" )->get_node;
        my @ids          = ( $included_ids ? split( qr/,/, $included_ids->attr('value') ) : () );

        $retval{ $option_type }{assigned_ids} = \@ids;
    }

    return \%retval;
}

=head2 credit_hold_list

Parses the Finance->Credit Hold page.

=cut

sub _xclient_credit_hold_list {
    my ( $self, $node ) = @_;

    my $orig_parse_cell_deeply = $self->client_parse_cell_deeply;
    $self->client_parse_cell_deeply(1);

    my $tables = $self->_xclient_channel_multi_table_by_id( $node );

    # for each Sales Channel get the 'Release Selected Orders' button, if present
    foreach my $channel ( keys %{ $tables } ) {
        my $button_id = 'release_orders_button_' . $channel;
        my $button = $node->find_xpath("id('${button_id}')")->get_node;
        $tables->{ $channel }{release_button} = $self->_xclient_parse_cell( $button )
                                if ( $button );
    }

    $self->client_parse_cell_deeply( $orig_parse_cell_deeply );

    return $tables;
}

=head2 multi_table_by_id

Parses a node and returns all the tables in it, in a HashRef with the key being the id of
the table. If the table has no id, it will be "__TABLE_<index>".

=cut

sub _xclient_multi_table_by_id {
    my ( $mech, $node ) = @_;

    my $result;
    my $unknown = 1;

    # Get the tables in the node.
    my @tables = $node->find_xpath('table')->get_nodelist();
    # they might be in a '<form>' tag
    push @tables, $node->find_xpath('form/table')->get_nodelist();
    # they might be in a '<div>' tag
    push @tables, $node->find_xpath('div/table')->get_nodelist();

    foreach my $table ( @tables ) {

        # Get the id of the table, if there isn't one, generate a generic one.
        my $id = $table->attr('id') || '__TABLE_' . $unknown++;

        # Parse the table and add it to the HashRef.
        $result->{ $id } = $mech->_xclient_parse_table( $table );

    }

    return $result;

}

=head2 channel_multi_table_by_id

Will go through each Channel Tab and return all Tables by Id, see 'multi_table_by_id' method
for more details on how it returns the table data.

=cut

sub _xclient_channel_multi_table_by_id {
    my ( $mech, $node ) = @_;

    my @tabs = $mech->_xclient_parse_channel_tabs( $node );

    my $result;
    foreach my $tab ( @tabs ) {
        my $conf_section    = $tab->{conf_section};
        # use the Config Section as the Tab Id, else use the Name
        my $key_for_tab     = $conf_section || $tab->{name};

        my $tables  = $mech->_xclient_multi_table_by_id( $tab->{node} );
        foreach my $tab_id ( keys %{ $tables } ) {
            my $table   = $tables->{ $tab_id };
            if ( $conf_section ) {
                # get rid of any Channel Config Section in the Tab Id
                $tab_id =~ s/_?${conf_section}_?//g;
            }
            $result->{ $key_for_tab }{ $tab_id } = $table;
        }
    }

    return $result;
}

=head2 multi_table

Parses the common 'multi table' element - pages which have numerous tables on
them arranged by Channel, and then table type. C</Fulfilment/Packing> is an
example.

=cut

# Transforms multi-channel table collections in to data
sub _xclient_multi_table {
    my ( $mech, $node ) = @_;

    # Get the tabs
    my @tabs = map {
        my $tab = $_;
        my $url = $tab->attr('href');
        $url =~ s/^#//;
        my $name = $mech->_xclient_trim_cell( $tab->as_text );
        $name =~ s/\s+\(.+//;
        { name => $name, id => $url };
      } $node->find_xpath(
        '//div[@id="tabContainer"]/table[@class="tabChannelTable"]//a')
      ->get_nodelist();

    # Go through each tab finding tables
    for my $tab (@tabs) {

        # Find the relevant nodeset
        my @children = $node->find_xpath(
            '//div[@id="' . $tab->{'id'} . '"]/div[@class="tabInsideWrapper"]' )
          ->get_node(1)->content_list;

        my @tables;
        my $current_table;

        for my $child (@children) {
            next unless ref $child;
            # Maybe this should match on a more generic m{h\d+}
            if ( grep { $child->tag eq $_ } qw/h3 span/ ) {
                if ( ref($current_table) ) {
                    push( @tables, $current_table );
                }
                $current_table =
                  { title => $mech->_xclient_trim_cell( $child->as_text ) };
            }
            elsif ( $child->tag eq 'form' ) {
                if ( my ($el) = grep { $_ } map { $child->find_xpath($_)->get_node(0) } qw/h3 span/ ) {
            if ( ref($current_table) ) {
                        push( @tables, $current_table );
                     }
                    $current_table =
                    { title => $mech->_xclient_trim_cell( $el->as_text ) };
                }
        $current_table->{'rows'} = $mech->_xclient_parse_table(
                    $child->find_xpath('table[contains(@class,"data")]')->get_node(1)
                );
            }
            elsif ( $child->tag eq 'table' ) {
                $current_table->{'rows'} = $mech->_xclient_parse_table($child);
            }
        }
        push( @tables, $current_table );
        $tab->{'tables'} = { map { $_->{'title'} => $_->{'rows'} } @tables };
    }
    return { map { $_->{'name'} => $_->{'tables'} } @tabs };
}

=head2 _xclient_parse_list_of_tables

Given an xpath query that returns a list of TABLEs will parse each using 'parse_table'
using the Tables Id as the key.

=cut

sub _xclient_parse_list_of_tables {
    my ( $mech, $xpath )    = @_;

    my @list = $xpath->get_nodelist();

    my %tables;
    foreach my $table ( @list ) {
        my $id  = $table->attr('id');
        $tables{ $id }  = $mech->_xclient_parse_table( $table );
    }

    return \%tables;
}

# Parse the funny tables displaying statuses for channels in the product
# description
sub _xclient_parse_channel_table {
    my ( $mech, $node ) = @_;
    my @table;

    # Get the rows
    my @rows = $node->find_xpath('.//tr')->get_nodelist();
    for my $row (@rows) {

        my @cols =
          map { $mech->_xclient_parse_cell($_) }
          $row->find_xpath('td|th')->get_nodelist;
        push( @table, \@cols );
    }
    return $mech->_xclient_map_table( \@table );
}

=head2 parse_table

Takes a reasonable stab at parsing many XTracker tables. Quite a few other
methods hand off to this first, before fixing up the data.

=cut

# Base NAP table parser. Does an intermediate parse on most tables. Push in a
# table node, and get back a list of hashrefs with the column headers. If the
# cell contained a URL, you'll get a hashref like { url => '', value => ''} back
# or otherwise just the value as a string.
sub _xclient_parse_table {
    my ( $mech, $node, %opts ) = @_;
    my @table;

    # NOTE: A todo here is when we have a <th> element that spans > 1 column
    # the <td> elements underneath it don't map to the correct hash key in the
    # output. This needs to be fixed so we don't need to write html to work
    # around this bug.
    my @header_rows=$node->find_xpath('thead/tr[td[@class="tableHeader"]|th]')
                ->get_nodelist();
    # Get the column names
    push(
        @table,
        [(
            map {
              # Sadly &nbsp; has been used for formatting, meaning we have to do
              # this the hard way :-(
                $mech->_xclient_trim_cell( $_->as_text ) || ''
            }
            $header_rows[-1]->find_xpath('td[@class="tableHeader"]|th')
                ->get_nodelist()
        ),
        ( $opts{'with_raw_rows'} || $mech->client_with_raw_rows ? 'raw' : () )
        ]
    ) if @header_rows;
    my $found_in_th = @table ? 1 : 0;

    # Get the data rows
    # Use the 'tr with a height set method'
    my @rows = $node->find_xpath('tbody/tr[@height]')->get_nodelist();
    # If that doesn't work, get rows that don't have divider children or th elements
    unless ( @rows ) {
        @rows = grep {
            ! (
                $_->find_xpath('td[@class="divider"]')->get_node(0) ||
                $_->find_xpath('td[@class="dividerHeader"]')->get_node(0) ||
                $_->find_xpath('td[@class="blank"]'  )->get_node(0) ||
                $_->find_xpath('th')->get_node(0)
            )
        } $node->find_xpath('tr|tbody/tr')->get_nodelist();
    }

    for my $r ( @rows ) {
        my @tds =
          map { $mech->_xclient_parse_cell($_) }
          $r->find_xpath('td')->get_nodelist();
        if ( $opts{'with_raw_rows'} || $mech->client_with_raw_rows ) {
            push(@tds, $r) if @tds > 1;
        }
        push( @table, \@tds );
    }

    # Remove any blank rows
    @table = grep { @$_ > 1 } @table unless ($opts{do_not_ignore_single_column});


    # Add an extra column to the columns row for raw if needed
    if ( ( $opts{'with_raw_rows'} || $mech->client_with_raw_rows ) && ! $found_in_th ) {
        $table[0]->[-1] = 'raw'; # It'll be a raw element!
    }

    return $mech->_xclient_map_table( \@table, %opts );
}

=head2 parse_vertical_table

Parses a Vertical table where 1st column is Field Names and 2nd column has the data. It
returns a HASH Ref with the key being the field name (1st Col) and the value being the data (2nd Col)

This was first written for use with '_xclient_reservation_email' transformer.

=cut

sub _xclient_parse_vertical_table {
    my ( $mech, $node, $td_xpath )     = @_;
    $td_xpath ||= "th|td";

    my %table;
    my @rows = map {
            my $row = $_;
            my $last_key;
            my @cells = $row->find_xpath($td_xpath)->get_nodelist();

            # deal with vertical tables with effectively
            # 2 sets of data in them side by side
            for ( my $i = 0; $i < @cells; $i++ ) { ## no critic(ProhibitCStyleForLoops)
                my $key = $mech->_xclient_parse_cell( $cells[$i] );
                if ( $i < $#cells ) {   # not in the last cell, which means there is a $i+1
                    $key =~ s/:$//;
                    my $val = $mech->_xclient_parse_cell( $cells[($i+1)] );
                    if ( $key ne "" ) {
                        $table{ $key } = $val;
                        $i++;   # the for loop will increase $i a second time
                                # which will jump us to the next 'Key' column
                        $last_key   = $key;
                    }
                    elsif ( $i == 0 || ( $i+1 == $#cells && $val eq "" ) ) {
                        # assume you can't have an empty first column
                        # or an empty 2 last columns
                        # and assign the data to the 'Unknown' key
                        push @{ $table{'Unknown'} }, $val;
                        $i++;
                        $last_key   = 'Unknown';
                    }
                }
                elsif ( defined $last_key ) {
                    # assume as there are no more cells after this one then
                    # the current cell must be another value for the last key
                    $table{ $last_key } = [ $table{ $last_key }, $key ];
                }
            }
        }
        grep {
            !( $_->find_xpath('td[@class="divider"]')->get_node(0) )
        }
        $node->find_xpath('tr')->get_nodelist();

    return \%table;
}

=head2 parse_first_vertical_table

Parses a Vertical table where 1st column is Field Names and 2nd column
has the data, and the rest of the columns are ignored.

This it works the same as the normal parse_vertical_table() method,
but
 * the first vertical table is col 1 & 2 only

=cut

sub _xclient_parse_first_vertical_table {
    my ( $mech, $node, $td_xpath )     = @_;
    $td_xpath ||= "td[ position() <= 2]";
    $mech->_xclient_parse_vertical_table($node, $td_xpath);
}

=head2 parse_second_vertical_table

Parses a Vertical table where 4th column is Field Names and 5th column
has the data.

This it works the same as the normal parse_vertical_table() method,
but
 * the first vertical table is col 1 & 2,
 * the third column is a separator, and
 * the second table is col 4 & 5.

=cut

sub _xclient_parse_second_vertical_table {
    my ( $mech, $node, $td_xpath )     = @_;
    $td_xpath ||= "td[ position() >= 4]";

    $mech->_xclient_parse_vertical_table($node, $td_xpath);
}

=head2 map_table

Convenience method for use in other transforms. Accepts an array-ref of
array-refs, and turns the first row in to column headings. Returns an array-ref
of hash-refs, keyed on columns headings.

=cut

sub _xclient_map_table {
    my ($self, $table, %opts) = @_;
    my @new_table;

    my $header = shift(@$table);
    for my $row (@$table) {
        my @local_column_names = @$header;
        my %row = map { shift(@local_column_names) // '' => $_ } @$row;
        delete $row{''} unless $opts{'allow_blank_rows'};
        push( @new_table, \%row );
    }
    return \@new_table;
}

=head2 parse_cell

Helper method for parsing values in cells. Returns a hash-ref for complicated
cells, and a string for simple ones.

Trims the cell (using C<trim_cell>), and adds a C<url> key if it finds a link.
Adds C<input_name> and C<input_value> keys if there's an input box, and
C<select_name>, C<select_values>, and C<select_selected> keys if there was a
select box. C<value> will be set if other keys are, otherwise, it's returned
as a string.

If 'client_parse_cell_deeply' is set then gives more information for INPUT statements,
see 'client_parse_cell_deeply' for more info on what it does.

=head2 Known bugs

This is currently broken for cells that contain two or more links (e.g. product
overview purchase order table cell for products with two or more purchase
orders).

=cut

sub _xclient_parse_cell {
    my ( $mech, $cell ) = @_;

    # Put the as_text value in 'value'
    my $return = {};
    $return->{'value'} = $mech->_xclient_trim_cell( $cell->as_text );

    # Save an href
    my $href = $cell->find_xpath('a[@href]')->get_node(1);
    if ($href) {
        $return->{'url'} = $href->attr('href');
    }

    # Save an input value or values
    my @input_nodes = $cell->find_xpath('input')->get_nodelist;
    push @input_nodes, $cell->find_xpath('span/input')->get_nodelist        if  ( $mech->client_parse_cell_deeply );
    my @inputs;
    foreach my $input ( @input_nodes ) {
        push @inputs, {
                input_name  => $input->attr('name'),
                input_value => $input->attr('value'),
                input_type  => $input->attr('type'),
                input_readonly => ( $input->attr('readonly') || $input->attr('disabled') ? 1 : 0 ),
            };
        # if checkbox or radio
        if ( $input->attr('type') =~ m/^(checkbox|radio)$/i ) {
            # if 'checked' is there then it's checked and add it to the list
            $inputs[-1]->{input_checked}  = ( defined $input->attr('checked') ? 1 : 0 );
        }
    }

    # if there is only 1 input or if just the basics are required
    # then fold the first input found into the return Hash
    if ( @inputs == 1 || ( @inputs && !$mech->client_parse_cell_deeply ) ) {
        my $ret_input   = $inputs[0];
        if ( !$mech->client_parse_cell_deeply ) {
            # return only the basics for backward compatibility
            delete $ret_input->{ $_ }       foreach ( grep { $_ ne 'input_name' && $_ ne 'input_value' } keys %{ $ret_input } );
        }
        $return = {
                %{ $return },
                %{ $ret_input },
            };
    }
    elsif ( @inputs > 1 ) {
        $return->{inputs}   = \@inputs;
    }

    # Save a select value
    my $select = $cell->find_xpath('select')->get_node(1);
    $select  //= $cell      if ( $cell->tag eq 'select' );
    if ( $select ) {
        $return->{'select_name'} = $select->attr('name');
        $return->{'select_values'} = [ map {
            my $select_values = [ $_->attr('value'), $_->as_text ];
            push ( @{$select_values}, (defined($_->attr('disabled')) ? 1 : 0) ) if ( $mech->client_parse_cell_deeply );
            $select_values;
        } $select->find_xpath('option')->get_nodelist];
        my ($selected) = (
            $select->find_xpath('option[@selected="selected"]')->get_nodelist,
            $select->find_xpath('option')->get_nodelist
        );
        $return->{'select_selected'} = (
            $selected
            ? [ $selected->attr('value'), $selected->as_text ]
            : []
        );
        if ( $mech->client_parse_cell_deeply ) {
            $return->{'select_readonly'} = ( $select->attr('readonly') || $select->attr('disabled') ? 1 : 0 );
        }
    }

    # If value is the only key, then return that as a string
    return $return->{'value'} if keys %$return == 1;

    # Or return the whole thing
    return $return;
}

=head2 trim_cell

Removes leading and trailing whitespace from a value, and changes all other
whitespace to be single spaces.

=cut

sub _xclient_trim_cell {
    my $value = $_[1];
    $value =~ s/\x{a0}/ /g;
    $value =~ s/^\s+//;
    $value =~ s/\s+$//;
    $value =~ s/\s+/ /g;
    return $value;
}

=head2 get_value

This just calls C<getValue> on the node.

=cut

sub _xclient_get_value {
    return $_[1]->getValue();
}

=head2 translate_location

Turns a location you'd get on a packing sheet into a fully-qualified one
depending on which DC you're in.

=cut

sub _xclient_translate_location {

    return Test::XT::Rules::Solve->solve( 'XTracker::Client::TranslateLocation' => { 'packing_location' => $_[1] } );

}

sub _xclient_parse_simple_list {
    my ($mech,$list) = @_;

    return [ map { $mech->_xclient_trim_cell($_->as_text) } $list->find_xpath('li')->get_nodelist() ];
}

=head2 parse_select_element

Parses a SELECT element and returns all the OPTIONs in an ArrayRef of HashRefs,
that contains the keys 'name' and 'value'.

=cut

sub _xclient_parse_select_element {
    my ($mech,$select) = @_;

    return [ map {;
        {
            name  => $mech->_xclient_trim_cell($_->as_text),
            value => $_->attr('value'),
        }
    } $select->find_xpath('option')->get_nodelist ];
}

=head2 parse_select_element_with_all_attributes

Returns the same structure as C<parse_select_element>, but also includes all
the attributes of each OPTION from the SELECT.

=cut

sub _xclient_parse_select_element_with_all_attributes {
    my ( $mech, $select ) = @_;

    my @result;

    foreach my $node ( $select->find_xpath('option')->get_nodelist ) {

        # Get all the attributes (this includes 'private' ones (see
        # L<HTML::Element> for details).
        my %attributes = $node->all_attr;

        # Delete the 'private' attributes prefixed with an underscore.
        delete $attributes{ $_ } foreach grep { /\A_/ } keys %attributes;

        # Add the 'name', because it's not an attribute.
        $attributes{name} = $mech->_xclient_trim_cell( $node->as_text );

        push @result, \%attributes;

    }

    return \@result;

}

=head2 parse_select_element_with_groups

Parses a SELECT element and returns all the OPTIONs in an ArrayRef of HashRefs,
that contains the keys C<name>, C<value> and C<group>.

If an OPTION is in an OPTGROUP, then <group> will be the value of the C<label>
attribute, otherwise it will be undef.

=cut

sub _xclient_parse_select_element_with_groups {
    my ($mech,$select) = @_;

    return [ map {;
        {
            name  => $mech->_xclient_trim_cell($_->as_text),
            value => $_->attr('value'),
            group => lc( $_->parent->tag ) eq 'optgroup' ? $_->parent->attr('label') : undef,
        }
    } $select->find_by_tag_name('option') ];
}

=head2 _xclient_parse_channel_tabs

Given a Channelised page returns the Sales Channel tabs, returning an array of hash's
containing the Name, Id & Node for each channel.

Use this if you have a Channelised Page which can't be parsed using 'multi_table'.

    (
        {
            id => 1,
            name => 'NET-A-PORTER.COM',
            node => $node,
        },
        ...
    ),

=cut

sub _xclient_parse_channel_tabs {
    my ( $mech, $node ) = @_;

    # Get the Sales Channel Tabs
    my @tabs    = map {
                    my $tab = $_;
                    my $url = $tab->attr('href');
                    $url    =~ s/^#//;
                    my $name= $mech->_xclient_trim_cell( $tab->as_text );
                    my $conf_section = $tab->attr('class');
                    $conf_section   =~ s/^contentTab-//     if ( $conf_section );
                    $name   =~ s/\s+\(.+//;
                    {
                        name => $name,
                        conf_section => $conf_section // "",
                        id => $url,
                        node => $node->find_xpath('//div[@id="' . $url . '"]/div[@class="tabInsideWrapper"]')
                                        ->get_node(1),
                    };
            } $node->find_xpath(
                        '//div[@id="tabContainer"]/table[@class="tabChannelTable"]//a')
                  ->get_nodelist();

    return @tabs;
}


=head2 customer_care_confirmation_message

Extracts the confirmation message from the SizeChange page
presented after the e-mail interstitial page has been submitted.

=cut

sub _xclient_customer_care_confirmation_message {
    my ( $mech, $content_right ) = @_;

    # ideally, we ought to extract the random piece of
    # text in close proximity to the title, but
    # the title will do for now

    return $content_right->find_xpath('span[1]')->get_node(1)->getValue();
}

sub _xclient_customercare_returns_create {
    my ( $mech, $node ) = @_;

    # these will be available on the first create return page
    my $paid_for_node    = $node->find_xpath('id("return_create__paid_for")')->get_node;
    my $refund_type_node = $node->find_xpath('id("return_create__refund_type")')->get_node;

    # refunds will only be avaliable on the second create return page
    my $refunds_node    = $node->find_xpath('id("return_create__refund_debit")')->get_node;
    my $refunds         = {};
    if ( $refunds_node ) {
        $refunds->{items}       = $mech->_xclient_parse_table( $refunds_node );
        $refunds->{grand_total} = $mech->_xclient_parse_cell(
            $node->find_xpath('id("return_create__refund_debit__grand_total")')->get_node
        );
        $refunds->{refund_type} = $mech->_xclient_parse_cell(
            $node->find_xpath('id("return_create__refund_debit__type")')->get_node
        );
    }

    return {
        paid_for    => ( $paid_for_node    ? $mech->_xclient_parse_cell( $paid_for_node )    : '' ),
        refund_type => ( $refund_type_node ? $mech->_xclient_parse_cell( $refund_type_node ) : '' ),
        refunds     => $refunds,
    };
}

sub _xclient_parse_vendor_sample_qc_table {
    my ( $mech, $node, %opts ) = @_;

    my $table = $mech->_xclient_parse_table($node,%opts);
    my $ret = [];
    for my $row (@{$table}) {
        if (!ref $row->{SKU}) { # actual data row
            push @$ret,$row;
        }
        else {
            $ret->[-1]->{'Faulty Reason'}=$row->{SKU};
        }
    }

    return $ret;
}

=head2 parse_return_view_items

This will parse the Return Items table on the Return View page, the items are listed in the normal way
except that a more details product description is on the row immediately below the rest of the items
which when using 'parse_table' ends up giving 2 rows per item, this method cleans it up and puts the
description as a seperate column - 'product_description' - with the rest of the items.

=cut

sub _xclient_parse_return_view_items {
    my ( $mech, $node )     = @_;

    my $table   = $mech->_xclient_parse_table( $node );

    my @retval;

    # go through the table, getting the product description which is
    # always on the next row and adding it to the rest of the items
    for ( my $i = 0; $i < @{ $table }; $i++ ) { ## no critic(ProhibitCStyleForLoops)
        my $row = $table->[ $i ];
        $i++;   # jump to the next row which just has the prod desc in it
        $row->{product_description} = $table->[ $i ]{Product};
        push @retval, $row;
    }

    return \@retval;
}

sub _xclient_parse_putaway_prep {
    my ($mech, $node) = @_;

    my %result;

    my $pgid_input = $mech->find_xpath('//input[@name="group_id"]')->get_node(1);
    $result{group_id} = $pgid_input->attr('value') if $pgid_input;

    my $recode_flag_input = $mech->find_xpath('//input[@name="recode"]')->get_node(1);
    $result{recode} = $recode_flag_input->attr('value') if $recode_flag_input;

    my $container_input = $mech->find_xpath('//input[@name="container_id"]')->get_node(1);
    $result{container_id} = $container_input->attr('value') if $container_input;

    my $container_content_table = $mech->find_xpath('//table[@id="container_content"]')->get_node;
    my $container_content
        = $container_content_table
        ? $mech->_xclient_parse_table($container_content_table)
        : undef;

    if ($container_content and 'ARRAY' eq ref $container_content) {

        # treat links in PGID cells as they are text, because they are JavaScript
        # driven ones and have "href" as "#"
        $_->{PGID} = $_->{PGID}{value} foreach grep {ref $_->{PGID}} @$container_content;

        # no need to use special column in tests because action links live there only
        delete $_->{Action} foreach @$container_content;

        $result{container_content} = $container_content;
    }

    return \%result;
}

sub _xclient_parse_putaway_problem_resolution {
    my ($mech, $node) = @_;

    my %result;

    # get currently processing container ID
    my $container_id_inp = $mech->find_xpath('//input[@name="container_id"]')->get_node(1);
    $result{container_id} = $container_id_inp->attr('value') if $container_id_inp;

    # get data about container content
    my $container_content_table = $mech->find_xpath('//table[@id="container_content"]')->get_node;
    my $container_content;
    $container_content = $mech->_xclient_parse_table($container_content_table)
        if $container_content_table;
    $result{container_content} = $container_content
        if 'ARRAY' eq ref($container_content);

    # get info about related groups
    my $related_groups_table = $mech->find_xpath('//table[@id="related_groups"]')->get_node;
    my $related_groups;
    $related_groups = $mech->_xclient_parse_table($related_groups_table)
        if $related_groups_table;
    $result{related_groups} = $related_groups
        if 'ARRAY' eq ref($related_groups);

    # get failure description
    my $failure_description_p = $mech->find_xpath('//p[@id="failure_description"]')->get_node;
    $result{failure_description} = $failure_description_p->as_text if $failure_description_p;

    # get failure resolutions
    $result{failure_resolution} = [
        map {$_->as_text}
        $mech->find_xpath(
            # make sure we match class even if it is not single
            '//div[contains(concat(" ", normalize-space(@class), " "), '
            . '" putaway-problem-resolution-resolution ")]'
        )->get_nodelist
    ];

    # check if we have start put away prep control in the resolution section
    $result{failure_resolution_putaway_prep} = 1
        if $mech->find_xpath('//form[@name="putaway_problem_resolution_reputaway_prep"]')->get_node;

    # check if there is a control for marking faulty container as empty
    $result{empty_faulty_container_button} = 1
        if $mech->find_xpath('//input[@name="empty_faulty_container"]')->get_node;

    # remove leading/tailing spaces from all scalar values
    s/^\s+|\s+$//g foreach grep {$_ and (not ref)} values %result;

    return \%result;
}

# On putaway problem resolution page process part related re-completion of putaway into
# new container
#
sub _xclient_parse_putaway_prep_on_problem_resolution {
    my ($mech, $node) = @_;

    my %result;

    my $container_id_inp = $mech->find_xpath('//input[@name="new_container_id"]')->get_node(1);
    $result{container_id} = $container_id_inp->attr('value') if $container_id_inp;

    # get data about container content
    my $container_content_table =
        $mech->find_xpath('//table[@id="new_container_content"]')->get_node;
    my $container_content;
    $container_content = $mech->_xclient_parse_table($container_content_table)
        if $container_content_table;
    $result{container_content} = $container_content
        if 'ARRAY' eq ref($container_content);

    # get value of button that toggles scan mode (to be scan into new container or
    # scan out of new container)
    my $toggle_scan_mode_inp =
        $mech->find_xpath('//input[@name="toggle_scan_mode"]')->get_node(1);
    $result{toggle_scan_mode_label} = $toggle_scan_mode_inp->attr('value')
        if $toggle_scan_mode_inp;

    # remove leading/tailing spaces from all scalar values
    s/^\s+|\s+$//g foreach grep {$_ and (not ref)} values %result;

    return \%result;
}

sub _xclient_parse_putaway_prep_packing_exception {
    my ($mech, $node) = @_;

    my %result;

    my $container_id_inp =
        $mech->find_xpath('//input[@name="container_id"]')->get_node(1);
    $result{container_id} = $container_id_inp->attr('value')
        if $container_id_inp;

    # get data about container content
    my $container_content_table =
        $mech->find_xpath('//table[@id="container_content"]')->get_node;
    my $container_content;
    $container_content = $mech->_xclient_parse_table($container_content_table)
        if $container_content_table;
    $result{container_content} = $container_content
        if 'ARRAY' eq ref($container_content);

    # get value of button that toggles scan mode (to be scan into new container or
    # scan out of new container)
    my $toggle_scan_mode_inp =
        $mech->find_xpath('//input[@name="toggle_scan_mode"]')->get_node(1);
    $result{toggle_scan_mode_label} = $toggle_scan_mode_inp->attr('value')
        if $toggle_scan_mode_inp;

    # remove leading/tailing spaces from all scalar values
    s/^\s+|\s+$//g foreach grep {$_ and (not ref)} values %result;

    return \%result;
}

sub _xclient_parse_highlighted_rows {
    my ($mech, $node, $class) = @_;

    my @rows = $node->find_xpath('//table/tbody/tr[@height]')->get_nodelist();
    # If that doesn't work, get rows that don't have divider children or th elements

    push @rows, grep {
        ! (
            $_->find_xpath('td[@class="divider"]')->get_node(0) ||
            $_->find_xpath('td[@class="dividerHeader"]')->get_node(0) ||
            $_->find_xpath('td[@class="blank"]'  )->get_node(0) ||
            $_->find_xpath('th')->get_node(0)
        )
    } $node->find_xpath('//table/tr|//table/tbody/tr')->get_nodelist();

    my $return = {};

    foreach my $r ( @rows ) {
        next unless ( defined $r->attr('class') && $r->attr('class') eq 'highlight' );

        my $row = [];

        foreach my $td ( $r->find_xpath('td')->get_nodelist() ) {
            my $td_out;
            if ( defined $td->as_text ) {
                $td_out->{value} = $mech->_xclient_trim_cell($td->as_text);
            }

            if ( my $span = $td->find_xpath('span')->get_node(0) ) {
                foreach my $attr ( qw( id class title ) ) {
                    next unless defined $span->attr($attr);
                    $td_out->{span}->{$attr} = $span->attr($attr);
                }
            }
            push @$row, $td_out;
        }

        if ( defined $r->attr('id') ) {
            $return->{$r->attr('id')} = $row;
        }
        else {
            push @{ $return->{rows} }, $row;
        }
    }

    return $return;
}

=head2 _xclient_reservation_view_live_reservations

Will parse the Reservation Waiting Lists page which is found under the 'View' section of the left hand menu.

=cut

sub _xclient_reservation_view_live_reservations {
    my ( $mech, $node )     = @_;

    my %tables;

    my @tabs    = $mech->_xclient_parse_channel_tabs( $node );

    foreach my $tab ( @tabs ) {
        my $channel_name    = $tab->{name};

        $tables{$channel_name} = [];
        # get the Customer Reservations per Operator
        my @tables   = $tab->{node}->find_xpath('//table[starts_with(@id,"'.$tab->{conf_section}.'_operator_")]' )->get_nodelist;

        foreach my $table ( @tables ) {
            my $table_data = $mech->_xclient_parse_table( $table );
            next unless scalar @$table_data >= 1;
            push @{ $tables{$channel_name} }, $mech->_xclient_parse_table( $table );
        }

    }

    return \%tables
}

sub _xclient_live_reservations_by_operator {
    my ( $mech, $node )     = @_;

    my $result_tables;
    my @tabs = $mech->_xclient_parse_channel_tabs( $node );

    foreach my $tab ( @tabs ) {
        my $channel_name    = $tab->{name};
        my @operator_tables = $node->find_xpath('//table[starts-with(@id, "tbl_live_'.$tab->{conf_section}.'_")]')->get_nodelist;
        $result_tables->{$channel_name}= {};

        foreach my $table ( @operator_tables ) {
            my $cell        = $table->find_xpath('tr[2]/td[2]')->get_node;
            my $value       = $mech->_xclient_parse_cell( $cell );
            my $operator_id = $table->id;
            $operator_id    =~ s/([^0-9])//g;
            my @tables   = $tab->{node}->find_xpath('//table[starts_with(@id,"'.$tab->{conf_section}.'_operator_'.$operator_id.'")]' )->get_nodelist;
            foreach my $table1 ( @tables ) {
                my $table_data = $mech->_xclient_parse_table( $table1 );
                push @{ $result_tables->{$channel_name}{$operator_id}},  $table_data;
            }

        }
    }
    return $result_tables;
}

=head2 _xclient_parse_stockcontrol_measurement

Will parse the StockControl->Measurement Edit page.

=cut

sub _xclient_parse_stockcontrol_measurement {
    my ( $mech, $node )     = @_;

    # What is happening:
    #   There are effectively 2 heading rows, one which has the actual Size
    #   and the second which has the Designer Size. Both of these have a first
    #   column which spans the first 2 columns of the data table which we're
    #   interested in. The code below drops the Designer Size heading row, then
    #   renames the first heading column to be more meaningful and then inserts
    #   a second column heading to match up with the data table's columns, then
    #   the 'parse_table' method is called to parse the data table as normal.

    # get the First Two Rows - which are effectively Headings
    my ( $row1, $row2 ) = grep {
        !scalar( $_->find_xpath('td[@class="divider"]')->get_nodelist() )
    } $node->find_xpath('tr')->get_nodelist();

    my ( $first_heading )   = $row1->find_xpath('td')->get_nodelist();
    my $new_heading = $first_heading->clone;
    # delete existing Heading, then Replace with new Heading
    $new_heading->splice_content(0);
    $new_heading->splice_content(0,1,"Measurement");
    $first_heading->postinsert( $new_heading );

    # change the Heading in the First Column also
    $first_heading->splice_content(0);
    $first_heading->splice_content(0,1,"Is Shown");

    # delete the 2nd set of Headings
    $row2->delete;

    my $deeply_setting  = $mech->client_parse_cell_deeply();

    $mech->client_parse_cell_deeply( 1 );
    my $data =  $mech->_xclient_parse_table( $node );
    $mech->client_parse_cell_deeply( $deeply_setting );

    # clean-up the first column by only using the
    # first input which should be the checkbox
    foreach my $row ( @{ $data } ) {
        $row->{'Is Shown'}  = $row->{'Is Shown'}{inputs}[0];
    }

    return $data;
}

=head2 _xclient_parse_user_profile_authorisation

Will parse the Authorisation section of the User Profile page.

=cut

sub _xclient_parse_user_profile_authorisation {
    my ( $mech, $node ) = @_;

    my $table = $mech->_xclient_parse_table( $node );

    # loop through all the tables making a 'Section => Sub Section' Hash Ref
    my %authorisation;
    my $section;
    my $sequence    = 0;
    OPTION:
    foreach my $option ( @{ $table } ) {
        if ( $option->{'Section'} ) {
            $section = $option->{'Section'};
            next OPTION;
        }

        $sequence++;
        $option->{sequence} = $sequence;
        my $sub_section = $option->{'Sub Section'};

        $authorisation{ $section }{ $sub_section } = $option;
    }

    return \%authorisation;
}

=head2 parse_main_navigation

Will parse the Main Navigation menu on any page.

=cut

sub parse_main_navigation {
    my $mech = shift;

    my $node    = $mech->find_xpath( 'id("nav1")' )->get_node(1);

    my @links   = grep {
        $_->attr('class') !~ m/hassubmenu/
    } $node->find_xpath('//li/a[@class="yuimenubaritemlabel"]')
            ->get_nodelist;

    my %main_nav;
    foreach my $link ( @links ) {
        my $href = $link->attr('href');
        $href    =~ s{^/}{};

        my ( $section, $sub_section ) = split( /\//, $href );
        $sub_section //= '';    # 'Home' doesn't have a Sub-Section

        # nicked from 'XTracker::Authenticate::_current_section_info'
        $section     =~ s/([a-z])([A-Z])/$1 $2/g;
        $section     =~ s/\A([A-Z]+)([A-Z][a-z]+)\z/$1 $2/g;
        $sub_section =~ s/([a-z])([A-Z])/$1 $2/g;

        if ( $sub_section ) {
            $main_nav{ $section }{ $sub_section } = 1;
        }
        else {
            $main_nav{ $section } = 1;
        }
    }

    return \%main_nav;
}

=head2 parse_sidenav

Will parse the Sidenav on any page.

=cut

sub parse_sidenav {
    my $mech = shift;

    my %menu_options;

    my $left_col = $mech->find_xpath('id("contentLeftCol")')->get_node;
    return \%menu_options       unless ( $left_col );

    my @options = $left_col->find_xpath('ul/li')->get_nodelist;
    my $current_section;
    OPTION:
    foreach my $option ( @options ) {
        if ( my $section = $option->find_xpath('span')->get_node ) {
            my $label = $mech->_xclient_parse_cell( $section );
            $current_section = $label;
            next OPTION;
        }

        if ( my $link = $option->find_xpath('a')->get_node ) {
            my $text = $mech->_xclient_parse_cell( $link );
            my $url  = $link->attr('href');
            $menu_options{ $current_section // '_none' }{ $text } = $url;
        }
    }

    # if the only Menu Section is '_none' then just return the options in it
    return (
        scalar( keys %menu_options ) == 1 && exists( $menu_options{'_none'} )
        ? $menu_options{'_none'}
        : \%menu_options
    );
}


# helper to remove trailing chars from a column
# title, initially used for removing '*' which
# is used to indicate that a field is required
sub __xclient_remove_trailing_char_from_column_name {
    my ( $mech, $char_to_remove, $hash )    = @_;

    my $pattern = qr/\Q${char_to_remove}\E$/;

    my @keys    = keys %{ $hash };
    KEY:
    foreach my $key ( @keys ) {
        next KEY        if ( $key !~ m/${pattern}/ );

        my $value       = delete $hash->{ $key };
        $key            =~ s/${pattern}//g;
        $key            = $mech->_xclient_trim_cell( $key );
        $hash->{ $key } = $value;
    }

    return;
}

sub _xclient_acl_tree_node {
    my ( $mech, $node ) = @_;

    my $data;
    if( $data = $node->as_HTML ) {
        $data =~s/<script.*>\s*var data = (.*);\s*var selection_list.*/$1/s;

    }
    return $data;
}

=head2 _xclient_reservation_purchased_report

Will parse the Reservation Purchase Report page data.

=cut

sub _xclient_reservation_purchased_report {
    my ($mech, $node) = @_;

    my $table = $mech->_xclient_parse_table( $node );

    return $table;
}

=head2 _xclient_parse_goh_integration_group_of_skus

Treat given DOM node as group of SKUs on GOH Integration page and
tries to extract data about SKUs.

=cut

sub _xclient_parse_goh_integration_group_of_skus {
    my ($mech, $node) = @_;

    # Get list of SKUs that exist in provided node;
    # we deliberatly do not use find_xpath method on $node
    # as it search entire DOM tree rather than just $node...
    my @skus = $node->look_down(sub{
        my $node = shift;
        return !! (($node->attr('class') || '') =~ /sku\-holder/);
    });

    return [ map { +{ sku => $_->as_text } } @skus ];
}

=head2 pre_order_product_list

Parses the Pre-Order Product List part of the Pre-Order Select Products page.

=cut

sub _xclient_pre_order_product_list {
    my ( $self, $node ) = @_;

    my %retval;

    my @product_divs = $node->find_xpath('//div[starts-with(@id, "select_products__variant_data_")]')->get_nodelist;
    foreach my $div ( @product_divs ) {
        my $pid = $div->attr('id');
        $pid    =~ s/select_products__variant_data_//g;

        # get Prices and then split them up
        foreach my $price_type ( 'price', 'discount_price' ) {
            my $price_node = $div->find_xpath('div/p[@class="select_products__' . $price_type . '"]')->get_node(1);
            my $parts_node = $div->find_xpath('div/p[@class="select_products__broken_' . $price_type . '"]')->get_node(1);

            if ( $price_node ) {
                my $total_price_str = $self->_xclient_parse_cell( $price_node );
                $total_price_str    =~ m/\bPrice: (?:[A-Z])*?.(?<price>[\d\.]+)/i;
                $retval{ $pid }{ $price_type }{total_price} = $+{price};
            }

            if ( $parts_node ) {
                my $parts_str = $self->_xclient_parse_cell( $parts_node );
                $parts_str    =~ m/
                        \bprice:\s(?:[A-Z])*?.(?<unit_price>[\d\.]+).*
                        \btax:\s(?:[A-Z])*?.(?<tax>[\d\.]+).*
                        \bduty:\s(?:[A-Z])*?.(?<duty>[\d\.]+)
                    /xi;
                $retval{ $pid }{ $price_type }{price_parts} = {
                    unit_price => $+{unit_price},
                    tax        => $+{tax},
                    duty       => $+{duty},
                };
            }
        }

        # get the table of SKUs that can be selected
        my $product_table = $node->find_xpath("//table[\@id='select_products__product_table_${pid}']")->get_node(1);
        if ( $product_table ) {
            $retval{ $pid }{sku_table} = $self->_xclient_parse_table( $product_table );
        }
    }

    return \%retval;
}

=head2 _xclient_parse_goh_integration_dcd_containers

Treat given DOM node as group of DCD containers on
GOH Integration page and tries to extract IDs.

=cut

sub _xclient_parse_goh_integration_dcd_containers {
    my ($mech, $node) = @_;

    my @container_id_nodes = $node->look_down(sub{
        !! ((shift->attr('class') || '') =~ /tote\-holder/);
    });

    return [ map { $_->as_text } @container_id_nodes ];
}

=head2 _xclient_split_comma_string

Will split the value of the identified node based on a: /, / pattern,
and return a list of the resulting values

=cut

sub _xclient_split_comma_string {
    my ($mech, $node) = @_;

    my @values = split(/, /, $node->getValue());
    return \@values;
}
1;
