#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

Admin_UserAdmin_Profile.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for URI:

    /Admin/UserAdmin/Profile

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => '/Admin/UserAdmin/Profile?dbl_submit_token=2468%253AotEX3W7voAIChXxh9cgUqA&operator_id_selected=5001',
    expected   => {
        account_details => {
          "Department" => {
            select_name => "department_id",
            select_selected => ['5', "Customer Care"],
            select_values => [
              ["", "---------"],
              ['20', "Buying"],
              ['5', "Customer Care"],
              ['19', "Customer Care Manager"],
              ['13', "Design"],
              ['2', "Distribution"],
              ['16', "Distribution Management"],
              ['14', "Editorial"],
              ['23', "Fashion Advisor"],
              ['1', "Finance"],
              ['10', "IT"],
              ['9', "Marketing"],
              ['21', "Merchandising"],
              ['8', "Personal Shopping"],
              ['15', "Photography"],
              ['22', "Product Merchandising"],
              ['7', "Retail"],
              ['12', "Sample"],
              ['3', "Shipping"],
              ['17', "Shipping Manager"],
              ['11', "Stock Control"],
            ],
            value => "---------BuyingCustomer CareCustomer Care ManagerDesignDistributionDistribution ManagementEditorialFashion AdvisorFinanceITMarketingMerchandisingPersonal ShoppingPhotographyProduct MerchandisingRetailSampleShippingShipping ManagerStock Control",
          },
          "Disabled" => { input_name => "disabled", input_value => '1', value => "" },
          "e-mail" => {
            input_name => "email_address",
            input_value => "Andrew.Beech\@net-a-porter.com",
            value => "",
          },
          "Name" => { input_name => "name", input_value => "Andrew Beech", value => "" },
          "Phone" => { input_name => "phone_ddi", input_value => "", value => "" },
          "Preferred Sales Channel" => {
            select_name => "pref_channel_id",
            select_selected => ['0', "No Preferred Channel"],
            select_values => [
              ['0', "No Preferred Channel"],
              ['7', "JIMMYCHOO.COM"],
              ['5', "MRPORTER.COM"],
              ['1', "NET-A-PORTER.COM"],
              ['3', "theOutnet.com"],
            ],
            value => "No Preferred ChannelJIMMYCHOO.COMMRPORTER.COMNET-A-PORTER.COMtheOutnet.com",
          },
          "Print Barcode" => { input_name => "print_barcode", input_value => '1', value => "" },
          "Unknown" => [
            { input_name => "submit", input_value => 'Submit »', value => "" },
          ],
          "Use LDAP to build Main Nav" => {
            input_name => "use_acl_for_main_nav",
            input_value => '1',
            value => "(If you are unsure about this option then please leave it as is.)",
          },
          "Username" => "A.Beech",
        },
        authorisation => {
          "Admin"         => {
                               "ACL Admin"         => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_181",
                                                                                   select_selected => ["1", ""],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_181", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "181", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 1,
                                                        "Sub Section"         => "ACL Admin",
                                                      },
                               "Email Templates"   => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_48",
                                                                                   select_selected => ["3", "Manager"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_48", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "48", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 2,
                                                        "Sub Section"         => "Email Templates",
                                                      },
                               "Exchange Rates"    => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_104",
                                                                                   select_selected => ["2", "Operator"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_104", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "104", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 3,
                                                        "Sub Section"         => "Exchange Rates",
                                                      },
                               "Fraud Rules"       => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_142",
                                                                                   select_selected => ["1", ""],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_142", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "142", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 4,
                                                        "Sub Section"         => "Fraud Rules",
                                                      },
                               "Job Queue"         => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_123",
                                                                                   select_selected => ["1", ""],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_123", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "123", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 5,
                                                        "Sub Section"         => "Job Queue",
                                                      },
                               "Printers"          => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_130",
                                                                                   select_selected => ["3", "Manager"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_130", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "130", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 6,
                                                        "Sub Section"         => "Printers",
                                                      },
                               "Sticky Pages"      => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_135",
                                                                                   select_selected => ["1", ""],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_135", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "135", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 7,
                                                        "Sub Section"         => "Sticky Pages",
                                                      },
                               "System Parameters" => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_136",
                                                                                   select_selected => ["1", ""],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_136", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "136", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 8,
                                                        "Sub Section"         => "System Parameters",
                                                      },
                               "User Admin"        => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_19",
                                                                                   select_selected => ["3", "Manager"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_19", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "19", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 9,
                                                        "Sub Section"         => "User Admin",
                                                      },
                             },
          "Customer Care" => {
                               "Customer Search" => {
                                                      "Authorisation Level" => {
                                                                                 select_name => "level_80",
                                                                                 select_selected => ["1", "Read Only"],
                                                                                 select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                 value => "Read OnlyOperatorManager",
                                                                               },
                                                      "Authorised"          => { input_name => "auth_80", input_value => "1", value => "" },
                                                      "Default Home Page"   => { input_name => "default_home_page", input_value => "80", value => "" },
                                                      "Section"             => "",
                                                      "sequence"            => 10,
                                                      "Sub Section"         => "Customer Search",
                                                    },
                               "Order Search"    => {
                                                      "Authorisation Level" => {
                                                                                 select_name => "level_54",
                                                                                 select_selected => ["1", "Read Only"],
                                                                                 select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                 value => "Read OnlyOperatorManager",
                                                                               },
                                                      "Authorised"          => { input_name => "auth_54", input_value => "1", value => "" },
                                                      "Default Home Page"   => { input_name => "default_home_page", input_value => "54", value => "" },
                                                      "Section"             => "",
                                                      "sequence"            => 11,
                                                      "Sub Section"         => "Order Search",
                                                    },
                               "Returns Pending" => {
                                                      "Authorisation Level" => {
                                                                                 select_name => "level_12",
                                                                                 select_selected => ["1", "Read Only"],
                                                                                 select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                 value => "Read OnlyOperatorManager",
                                                                               },
                                                      "Authorised"          => { input_name => "auth_12", input_value => "1", value => "" },
                                                      "Default Home Page"   => { input_name => "default_home_page", input_value => "12", value => "" },
                                                      "Section"             => "",
                                                      "sequence"            => 12,
                                                      "Sub Section"         => "Returns Pending",
                                                    },
                             },
          "Finance"       => {
                               "Active Invoices"       => {
                                                            "Authorisation Level" => {
                                                                                       select_name => "level_20",
                                                                                       select_selected => ["2", "Operator"],
                                                                                       select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                       value => "Read OnlyOperatorManager",
                                                                                     },
                                                            "Authorised"          => { input_name => "auth_20", input_value => "1", value => "" },
                                                            "Default Home Page"   => { input_name => "default_home_page", input_value => "20", value => "" },
                                                            "Section"             => "",
                                                            "sequence"            => 13,
                                                            "Sub Section"         => "Active Invoices",
                                                          },
                               "Credit Check"          => {
                                                            "Authorisation Level" => {
                                                                                       select_name => "level_2",
                                                                                       select_selected => ["2", "Operator"],
                                                                                       select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                       value => "Read OnlyOperatorManager",
                                                                                     },
                                                            "Authorised"          => { input_name => "auth_2", input_value => "1", value => "" },
                                                            "Default Home Page"   => { input_name => "default_home_page", input_value => "2", value => "" },
                                                            "Section"             => "",
                                                            "sequence"            => 14,
                                                            "Sub Section"         => "Credit Check",
                                                          },
                               "Credit Hold"           => {
                                                            "Authorisation Level" => {
                                                                                       select_name => "level_1",
                                                                                       select_selected => ["2", "Operator"],
                                                                                       select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                       value => "Read OnlyOperatorManager",
                                                                                     },
                                                            "Authorised"          => { input_name => "auth_1", input_value => "1", value => "" },
                                                            "Default Home Page"   => { input_name => "default_home_page", input_value => "1", value => "" },
                                                            "Section"             => "",
                                                            "sequence"            => 15,
                                                            "Sub Section"         => "Credit Hold",
                                                          },
                               "Fraud Hotlist"         => {
                                                            "Authorisation Level" => {
                                                                                       select_name => "level_97",
                                                                                       select_selected => ["1", ""],
                                                                                       select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                       value => "Read OnlyOperatorManager",
                                                                                     },
                                                            "Authorised"          => { input_name => "auth_97", input_value => "1", value => "" },
                                                            "Default Home Page"   => { input_name => "default_home_page", input_value => "97", value => "" },
                                                            "Section"             => "",
                                                            "sequence"            => 16,
                                                            "Sub Section"         => "Fraud Hotlist",
                                                          },
                               "Fraud Rules"           => {
                                                            "Authorisation Level" => {
                                                                                       select_name => "level_143",
                                                                                       select_selected => ["1", ""],
                                                                                       select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                       value => "Read OnlyOperatorManager",
                                                                                     },
                                                            "Authorised"          => { input_name => "auth_143", input_value => "1", value => "" },
                                                            "Default Home Page"   => { input_name => "default_home_page", input_value => "143", value => "" },
                                                            "Section"             => "",
                                                            "sequence"            => 17,
                                                            "Sub Section"         => "Fraud Rules",
                                                          },
                               "Invalid Payments"      => {
                                                            "Authorisation Level" => {
                                                                                       select_name => "level_59",
                                                                                       select_selected => ["1", "Read Only"],
                                                                                       select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                       value => "Read OnlyOperatorManager",
                                                                                     },
                                                            "Authorised"          => { input_name => "auth_59", input_value => "1", value => "" },
                                                            "Default Home Page"   => { input_name => "default_home_page", input_value => "59", value => "" },
                                                            "Section"             => "",
                                                            "sequence"            => 18,
                                                            "Sub Section"         => "Invalid Payments",
                                                          },
                               "Pending Invoices"      => {
                                                            "Authorisation Level" => {
                                                                                       select_name => "level_21",
                                                                                       select_selected => ["2", "Operator"],
                                                                                       select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                       value => "Read OnlyOperatorManager",
                                                                                     },
                                                            "Authorised"          => { input_name => "auth_21", input_value => "1", value => "" },
                                                            "Default Home Page"   => { input_name => "default_home_page", input_value => "21", value => "" },
                                                            "Section"             => "",
                                                            "sequence"            => 19,
                                                            "Sub Section"         => "Pending Invoices",
                                                          },
                               "Reimbursements"        => {
                                                            "Authorisation Level" => {
                                                                                       select_name => "level_132",
                                                                                       select_selected => ["1", ""],
                                                                                       select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                       value => "Read OnlyOperatorManager",
                                                                                     },
                                                            "Authorised"          => { input_name => "auth_132", input_value => "1", value => "" },
                                                            "Default Home Page"   => { input_name => "default_home_page", input_value => "132", value => "" },
                                                            "Section"             => "",
                                                            "sequence"            => 20,
                                                            "Sub Section"         => "Reimbursements",
                                                          },
                               "Store Credits"         => {
                                                            "Authorisation Level" => {
                                                                                       select_name => "level_57",
                                                                                       select_selected => ["1", ""],
                                                                                       select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                       value => "Read OnlyOperatorManager",
                                                                                     },
                                                            "Authorised"          => { input_name => "auth_57", input_value => "1", value => "" },
                                                            "Default Home Page"   => { input_name => "default_home_page", input_value => "57", value => "" },
                                                            "Section"             => "",
                                                            "sequence"            => 21,
                                                            "Sub Section"         => "Store Credits",
                                                          },
                               "Transaction Reporting" => {
                                                            "Authorisation Level" => {
                                                                                       select_name => "level_106",
                                                                                       select_selected => ["2", "Operator"],
                                                                                       select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                       value => "Read OnlyOperatorManager",
                                                                                     },
                                                            "Authorised"          => { input_name => "auth_106", input_value => "1", value => "" },
                                                            "Default Home Page"   => { input_name => "default_home_page", input_value => "106", value => "" },
                                                            "Section"             => "",
                                                            "sequence"            => 22,
                                                            "Sub Section"         => "Transaction Reporting",
                                                          },
                             },
          "Fulfilment"    => {
                               "Airwaybill"         => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_10",
                                                                                    select_selected => ["3", "Manager"],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_10", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "10", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 23,
                                                         "Sub Section"         => "Airwaybill",
                                                       },
                               "Commissioner"       => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_129",
                                                                                    select_selected => ["3", "Manager"],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_129", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "129", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 24,
                                                         "Sub Section"         => "Commissioner",
                                                       },
                               "DDU"                => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_9",
                                                                                    select_selected => ["3", "Manager"],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_9", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "9", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 25,
                                                         "Sub Section"         => "DDU",
                                                       },
                               "Dispatch"           => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_7",
                                                                                    select_selected => ["3", "Manager"],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_7", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "7", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 26,
                                                         "Sub Section"         => "Dispatch",
                                                       },
                               "Induction"          => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_147",
                                                                                    select_selected => ["1", ""],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_147", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "147", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 27,
                                                         "Sub Section"         => "Induction",
                                                       },
                               "Invalid Shipments"  => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_84",
                                                                                    select_selected => ["2", "Operator"],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_84", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "84", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 28,
                                                         "Sub Section"         => "Invalid Shipments",
                                                       },
                               "Labelling"          => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_86",
                                                                                    select_selected => ["2", "Operator"],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_86", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "86", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 29,
                                                         "Sub Section"         => "Labelling",
                                                       },
                               "Manifest"           => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_85",
                                                                                    select_selected => ["2", "Operator"],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_85", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "85", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 30,
                                                         "Sub Section"         => "Manifest",
                                                       },
                               "On Hold"            => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_8",
                                                                                    select_selected => ["2", "Operator"],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_8", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "8", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 31,
                                                         "Sub Section"         => "On Hold",
                                                       },
                               "Pack Lane Activity" => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_146",
                                                                                    select_selected => ["1", ""],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_146", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "146", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 32,
                                                         "Sub Section"         => "Pack Lane Activity",
                                                       },
                               "Packing"            => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_6",
                                                                                    select_selected => ["3", "Manager"],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_6", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "6", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 33,
                                                         "Sub Section"         => "Packing",
                                                       },
                               "Packing Exception"  => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_128",
                                                                                    select_selected => ["3", "Manager"],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_128", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "128", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 34,
                                                         "Sub Section"         => "Packing Exception",
                                                       },
                               "Picking"            => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_5",
                                                                                    select_selected => ["3", "Manager"],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_5", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "5", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 35,
                                                         "Sub Section"         => "Picking",
                                                       },
                               "Picking Overview"   => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_145",
                                                                                    select_selected => ["1", ""],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_145", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "145", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 36,
                                                         "Sub Section"         => "Picking Overview",
                                                       },
                               "Pre-Order Hold"     => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_98",
                                                                                    select_selected => ["1", "Read Only"],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_98", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "98", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 37,
                                                         "Sub Section"         => "Pre-Order Hold",
                                                       },
                               "Premier Dispatch"   => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_134",
                                                                                    select_selected => ["1", ""],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_134", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "134", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 38,
                                                         "Sub Section"         => "Premier Dispatch",
                                                       },
                               "Premier Routing"    => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_99",
                                                                                    select_selected => ["2", "Operator"],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_99", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "99", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 39,
                                                         "Sub Section"         => "Premier Routing",
                                                       },
                               "Selection"          => {
                                                         "Authorisation Level" => {
                                                                                    select_name => "level_4",
                                                                                    select_selected => ["2", "Operator"],
                                                                                    select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                    value => "Read OnlyOperatorManager",
                                                                                  },
                                                         "Authorised"          => { input_name => "auth_4", input_value => "1", value => "" },
                                                         "Default Home Page"   => { input_name => "default_home_page", input_value => "4", value => "" },
                                                         "Section"             => "",
                                                         "sequence"            => 40,
                                                         "Sub Section"         => "Selection",
                                                       },
                             },
          "Goods In"      => {
                               "Bag And Tag"                    => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_26",
                                                                                                select_selected => ["1", "Read Only"],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_26", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "26", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 41,
                                                                     "Sub Section"         => "Bag And Tag",
                                                                   },
                               "Barcode"                        => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_49",
                                                                                                select_selected => ["1", "Read Only"],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_49", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "49", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 42,
                                                                     "Sub Section"         => "Barcode",
                                                                   },
                               "Delivery Cancel"                => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_3",
                                                                                                select_selected => ["1", "Read Only"],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_3", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "3", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 43,
                                                                     "Sub Section"         => "Delivery Cancel",
                                                                   },
                               "Delivery Hold"                  => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_37",
                                                                                                select_selected => ["3", "Manager"],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_37", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "37", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 44,
                                                                     "Sub Section"         => "Delivery Hold",
                                                                   },
                               "Delivery Timetable"             => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_117",
                                                                                                select_selected => ["1", "Read Only"],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_117", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "117", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 45,
                                                                     "Sub Section"         => "Delivery Timetable",
                                                                   },
                               "Item Count"                     => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_23",
                                                                                                select_selected => ["1", "Read Only"],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_23", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "23", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 46,
                                                                     "Sub Section"         => "Item Count",
                                                                   },
                               "Putaway"                        => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_27",
                                                                                                select_selected => ["1", "Read Only"],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_27", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "27", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 47,
                                                                     "Sub Section"         => "Putaway",
                                                                   },
                               "Putaway Prep"                   => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_137",
                                                                                                select_selected => ["1", ""],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_137", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "137", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 48,
                                                                     "Sub Section"         => "Putaway Prep",
                                                                   },
                               "Putaway Prep Admin"             => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_140",
                                                                                                select_selected => ["1", ""],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_140", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "140", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 49,
                                                                     "Sub Section"         => "Putaway Prep Admin",
                                                                   },
                               "Putaway Prep Packing Exception" => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_144",
                                                                                                select_selected => ["1", ""],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_144", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "144", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 50,
                                                                     "Sub Section"         => "Putaway Prep Packing Exception",
                                                                   },
                               "Putaway Problem Resolution"     => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_141",
                                                                                                select_selected => ["1", ""],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_141", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "141", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 51,
                                                                     "Sub Section"         => "Putaway Problem Resolution",
                                                                   },
                               "Quality Control"                => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_24",
                                                                                                select_selected => ["1", "Read Only"],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_24", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "24", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 52,
                                                                     "Sub Section"         => "Quality Control",
                                                                   },
                               "Recent Deliveries"              => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_62",
                                                                                                select_selected => ["1", "Read Only"],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_62", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "62", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 53,
                                                                     "Sub Section"         => "Recent Deliveries",
                                                                   },
                               "Returns Arrival"                => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_119",
                                                                                                select_selected => ["3", "Manager"],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_119", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "119", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 54,
                                                                     "Sub Section"         => "Returns Arrival",
                                                                   },
                               "Returns Faulty"                 => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_46",
                                                                                                select_selected => ["3", "Manager"],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_46", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "46", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 55,
                                                                     "Sub Section"         => "Returns Faulty",
                                                                   },
                               "Returns In"                     => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_15",
                                                                                                select_selected => ["3", "Manager"],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_15", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "15", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 56,
                                                                     "Sub Section"         => "Returns In",
                                                                   },
                               "Returns QC"                     => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_35",
                                                                                                select_selected => ["1", "Read Only"],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_35", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "35", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 57,
                                                                     "Sub Section"         => "Returns QC",
                                                                   },
                               "Stock In"                       => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_13",
                                                                                                select_selected => ["1", "Read Only"],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_13", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "13", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 58,
                                                                     "Sub Section"         => "Stock In",
                                                                   },
                               "Surplus"                        => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_29",
                                                                                                select_selected => ["1", "Read Only"],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_29", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "29", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 59,
                                                                     "Sub Section"         => "Surplus",
                                                                   },
                               "Vendor Sample In"               => {
                                                                     "Authorisation Level" => {
                                                                                                select_name => "level_63",
                                                                                                select_selected => ["1", "Read Only"],
                                                                                                select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                                value => "Read OnlyOperatorManager",
                                                                                              },
                                                                     "Authorised"          => { input_name => "auth_63", input_value => "1", value => "" },
                                                                     "Default Home Page"   => { input_name => "default_home_page", input_value => "63", value => "" },
                                                                     "Section"             => "",
                                                                     "sequence"            => 60,
                                                                     "Sub Section"         => "Vendor Sample In",
                                                                   },
                             },
          "NAP Events"    => {
                               "In The Box"    => {
                                                    "Authorisation Level" => {
                                                                               select_name => "level_138",
                                                                               select_selected => ["1", ""],
                                                                               select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                               value => "Read OnlyOperatorManager",
                                                                             },
                                                    "Authorised"          => { input_name => "auth_138", input_value => "1", value => "" },
                                                    "Default Home Page"   => { input_name => "default_home_page", input_value => "138", value => "" },
                                                    "Section"             => "",
                                                    "sequence"            => 61,
                                                    "Sub Section"         => "In The Box",
                                                  },
                               "Manage"        => {
                                                    "Authorisation Level" => {
                                                                               select_name => "level_124",
                                                                               select_selected => ["3", "Manager"],
                                                                               select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                               value => "Read OnlyOperatorManager",
                                                                             },
                                                    "Authorised"          => { input_name => "auth_124", input_value => "1", value => "" },
                                                    "Default Home Page"   => { input_name => "default_home_page", input_value => "124", value => "" },
                                                    "Section"             => "",
                                                    "sequence"            => 62,
                                                    "Sub Section"         => "Manage",
                                                  },
                               "Welcome Packs" => {
                                                    "Authorisation Level" => {
                                                                               select_name => "level_148",
                                                                               select_selected => ["1", ""],
                                                                               select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                               value => "Read OnlyOperatorManager",
                                                                             },
                                                    "Authorised"          => { input_name => "auth_148", input_value => "1", value => "" },
                                                    "Default Home Page"   => { input_name => "default_home_page", input_value => "148", value => "" },
                                                    "Section"             => "",
                                                    "sequence"            => 63,
                                                    "Sub Section"         => "Welcome Packs",
                                                  },
                             },
          "Outnet Events" => {
                               Manage => {
                                 "Authorisation Level" => {
                                                            select_name => "level_126",
                                                            select_selected => ["3", "Manager"],
                                                            select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                            value => "Read OnlyOperatorManager",
                                                          },
                                 "Authorised"          => { input_name => "auth_126", input_value => "1", value => "" },
                                 "Default Home Page"   => { input_name => "default_home_page", input_value => "126", value => "" },
                                 "Section"             => "",
                                 "sequence"            => 64,
                                 "Sub Section"         => "Manage",
                               },
                             },
          "Reporting"     => {
                               "Distribution Reports" => {
                                                           "Authorisation Level" => {
                                                                                      select_name => "level_55",
                                                                                      select_selected => ["1", "Read Only"],
                                                                                      select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                      value => "Read OnlyOperatorManager",
                                                                                    },
                                                           "Authorised"          => { input_name => "auth_55", input_value => "1", value => "" },
                                                           "Default Home Page"   => { input_name => "default_home_page", input_value => "55", value => "" },
                                                           "Section"             => "",
                                                           "sequence"            => 75,
                                                           "Sub Section"         => "Distribution Reports",
                                                         },
                               "Shipping Reports"     => {
                                                           "Authorisation Level" => {
                                                                                      select_name => "level_96",
                                                                                      select_selected => ["1", "Read Only"],
                                                                                      select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                      value => "Read OnlyOperatorManager",
                                                                                    },
                                                           "Authorised"          => { input_name => "auth_96", input_value => "1", value => "" },
                                                           "Default Home Page"   => { input_name => "default_home_page", input_value => "96", value => "" },
                                                           "Section"             => "",
                                                           "sequence"            => 76,
                                                           "Sub Section"         => "Shipping Reports",
                                                         },
                             },
          "Retail"        => {
                               "Attribute Management" => {
                                 "Authorisation Level" => {
                                                            select_name => "level_111",
                                                            select_selected => ["2", "Operator"],
                                                            select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                            value => "Read OnlyOperatorManager",
                                                          },
                                 "Authorised"          => { input_name => "auth_111", input_value => "1", value => "" },
                                 "Default Home Page"   => { input_name => "default_home_page", input_value => "111", value => "" },
                                 "Section"             => "",
                                 "sequence"            => 77,
                                 "Sub Section"         => "Attribute Management",
                               },
                             },
          "RTV"           => {
                               "Awaiting Dispatch" => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_94",
                                                                                   select_selected => ["1", "Read Only"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_94", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "94", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 65,
                                                        "Sub Section"         => "Awaiting Dispatch",
                                                      },
                               "Dispatched RTV"    => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_95",
                                                                                   select_selected => ["1", "Read Only"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_95", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "95", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 66,
                                                        "Sub Section"         => "Dispatched RTV",
                                                      },
                               "Faulty GI"         => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_87",
                                                                                   select_selected => ["1", "Read Only"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_87", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "87", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 67,
                                                        "Sub Section"         => "Faulty GI",
                                                      },
                               "Inspect Pick"      => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_88",
                                                                                   select_selected => ["1", "Read Only"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_88", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "88", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 68,
                                                        "Sub Section"         => "Inspect Pick",
                                                      },
                               "List RMA"          => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_90",
                                                                                   select_selected => ["3", "Manager"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_90", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "90", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 69,
                                                        "Sub Section"         => "List RMA",
                                                      },
                               "List RTV"          => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_91",
                                                                                   select_selected => ["3", "Manager"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_91", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "91", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 70,
                                                        "Sub Section"         => "List RTV",
                                                      },
                               "Non Faulty"        => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_122",
                                                                                   select_selected => ["3", "Manager"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_122", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "122", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 71,
                                                        "Sub Section"         => "Non Faulty",
                                                      },
                               "Pack RTV"          => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_93",
                                                                                   select_selected => ["3", "Manager"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_93", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "93", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 72,
                                                        "Sub Section"         => "Pack RTV",
                                                      },
                               "Pick RTV"          => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_92",
                                                                                   select_selected => ["3", "Manager"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_92", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "92", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 73,
                                                        "Sub Section"         => "Pick RTV",
                                                      },
                               "Request RMA"       => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_89",
                                                                                   select_selected => ["1", "Read Only"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_89", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "89", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 74,
                                                        "Sub Section"         => "Request RMA",
                                                      },
                             },
          "Sample"        => {
                               "Review Requests"   => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_67",
                                                                                   select_selected => ["1", "Read Only"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_67", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "67", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 78,
                                                        "Sub Section"         => "Review Requests",
                                                      },
                               "Sample Cart"       => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_64",
                                                                                   select_selected => ["3", "Manager"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_64", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "64", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 79,
                                                        "Sub Section"         => "Sample Cart",
                                                      },
                               "Sample Cart Users" => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_105",
                                                                                   select_selected => ["3", "Manager"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_105", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "105", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 80,
                                                        "Sub Section"         => "Sample Cart Users",
                                                      },
                               "Sample Transfer"   => {
                                                        "Authorisation Level" => {
                                                                                   select_name => "level_65",
                                                                                   select_selected => ["3", "Manager"],
                                                                                   select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                   value => "Read OnlyOperatorManager",
                                                                                 },
                                                        "Authorised"          => { input_name => "auth_65", input_value => "1", value => "" },
                                                        "Default Home Page"   => { input_name => "default_home_page", input_value => "65", value => "" },
                                                        "Section"             => "",
                                                        "sequence"            => 81,
                                                        "Sub Section"         => "Sample Transfer",
                                                      },
                             },
          "Stock Control" => {
                               "Cancellations"       => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_47",
                                                                                     select_selected => ["3", "Manager"],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_47", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "47", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 82,
                                                          "Sub Section"         => "Cancellations",
                                                        },
                               "Channel Transfer"    => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_125",
                                                                                     select_selected => ["3", "Manager"],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_125", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "125", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 83,
                                                          "Sub Section"         => "Channel Transfer",
                                                        },
                               "Dead Stock"          => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_127",
                                                                                     select_selected => ["1", "Read Only"],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_127", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "127", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 84,
                                                          "Sub Section"         => "Dead Stock",
                                                        },
                               "Duty Rates"          => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_56",
                                                                                     select_selected => ["1", "Read Only"],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_56", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "56", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 85,
                                                          "Sub Section"         => "Duty Rates",
                                                        },
                               "Final Pick"          => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_51",
                                                                                     select_selected => ["1", "Read Only"],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_51", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "51", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 86,
                                                          "Sub Section"         => "Final Pick",
                                                        },
                               "Inventory"           => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_11",
                                                                                     select_selected => ["1", "Read Only"],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_11", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "11", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 87,
                                                          "Sub Section"         => "Inventory",
                                                        },
                               "Location"            => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_78",
                                                                                     select_selected => ["1", ""],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_78", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "78", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 88,
                                                          "Sub Section"         => "Location",
                                                        },
                               "Measurement"         => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_50",
                                                                                     select_selected => ["1", "Read Only"],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_50", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "50", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 89,
                                                          "Sub Section"         => "Measurement",
                                                        },
                               "Perpetual Inventory" => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_79",
                                                                                     select_selected => ["3", "Manager"],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_79", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "79", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 90,
                                                          "Sub Section"         => "Perpetual Inventory",
                                                        },
                               "Product Approval"    => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_73",
                                                                                     select_selected => ["1", "Read Only"],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_73", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "73", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 91,
                                                          "Sub Section"         => "Product Approval",
                                                        },
                               "Purchase Order"      => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_34",
                                                                                     select_selected => ["1", "Read Only"],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_34", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "34", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 92,
                                                          "Sub Section"         => "Purchase Order",
                                                        },
                               "Quarantine"          => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_44",
                                                                                     select_selected => ["1", "Read Only"],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_44", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "44", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 93,
                                                          "Sub Section"         => "Quarantine",
                                                        },
                               "Recode"              => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_131",
                                                                                     select_selected => ["1", ""],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_131", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "131", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 94,
                                                          "Sub Section"         => "Recode",
                                                        },
                               "Reservation"         => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_39",
                                                                                     select_selected => ["1", "Read Only"],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_39", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "39", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 95,
                                                          "Sub Section"         => "Reservation",
                                                        },
                               "Sample"              => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_40",
                                                                                     select_selected => ["3", "Manager"],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_40", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "40", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 96,
                                                          "Sub Section"         => "Sample",
                                                        },
                               "Sample Adjustment"   => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_139",
                                                                                     select_selected => ["1", ""],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_139", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "139", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 97,
                                                          "Sub Section"         => "Sample Adjustment",
                                                        },
                               "Stock Adjustment"    => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_133",
                                                                                     select_selected => ["1", ""],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_133", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "133", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 98,
                                                          "Sub Section"         => "Stock Adjustment",
                                                        },
                               "Stock Check"         => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_41",
                                                                                     select_selected => ["1", "Read Only"],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_41", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "41", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 99,
                                                          "Sub Section"         => "Stock Check",
                                                        },
                               "Stock Relocation"    => {
                                                          "Authorisation Level" => {
                                                                                     select_name => "level_121",
                                                                                     select_selected => ["3", "Manager"],
                                                                                     select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                                                     value => "Read OnlyOperatorManager",
                                                                                   },
                                                          "Authorised"          => { input_name => "auth_121", input_value => "1", value => "" },
                                                          "Default Home Page"   => { input_name => "default_home_page", input_value => "121", value => "" },
                                                          "Section"             => "",
                                                          "sequence"            => 100,
                                                          "Sub Section"         => "Stock Relocation",
                                                        },
                             },
          "Web Content"   => {
                               "Designer Landing" => {
                                 "Authorisation Level" => {
                                                            select_name => "level_114",
                                                            select_selected => ["3", "Manager"],
                                                            select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                            value => "Read OnlyOperatorManager",
                                                          },
                                 "Authorised"          => { input_name => "auth_114", input_value => "1", value => "" },
                                 "Default Home Page"   => { input_name => "default_home_page", input_value => "114", value => "" },
                                 "Section"             => "",
                                 "sequence"            => 101,
                                 "Sub Section"         => "Designer Landing",
                               },
                               "Magazine" => {
                                 "Authorisation Level" => {
                                                            select_name => "level_118",
                                                            select_selected => ["3", "Manager"],
                                                            select_values => [["1", ""], ["1", "Read Only"], ["2", "Operator"], ["3", "Manager"]],
                                                            value => "Read OnlyOperatorManager",
                                                          },
                                 "Authorised"          => { input_name => "auth_118", input_value => "1", value => "" },
                                 "Default Home Page"   => { input_name => "default_home_page", input_value => "118", value => "" },
                                 "Section"             => "",
                                 "sequence"            => 102,
                                 "Sub Section"         => "Magazine",
                               },
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

        <title>User Admin &#8226; Admin &#8226; XT-DC1</title>


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


            <script type="text/javascript" src="/javascript/yui_autocomplete.js"></script>




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











                <form class="quick_search" name="quick_search" method="get" action="/QuickSearch">

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


                <span class="operator_name">Logged in as: Andrew Beech</span>

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
                                                <a href="/Admin/ExchangeRates" class="yuimenuitemlabel">Exchange Rates</a>
                                            </li>

                                            <li class="menuitem">
                                                <a href="/Admin/Printers" class="yuimenuitemlabel">Printers</a>
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
                                                <a href="/Finance/TransactionReporting" class="yuimenuitemlabel">Transaction Reporting</a>
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

        <div id="contentLeftCol" >


        <ul>





                    <li><a href="/Admin/UserAdmin" class="last">Back to User List</a></li>


        </ul>

</div>




        <div id="contentRight" >













                    <div id="pageTitle">
                        <h1>User Admin</h1>
                        <h5>&bull;</h5><h2>User Profile</h2>

                    </div>






                    <p class="bc-container">
  <ul class="breadcrumb">


  </ul>
</p>



<style type="text/css">
    #clone_user_div {
        display: none;
        background-color: #CCFFCC;
        padding: 3px 5px;
        border-top: 1px dotted #006600;
        border-bottom: 1px dotted #006600;
        margin-bottom: 5px;
    }

    #clone_wait {
        display: none;
        text-align: center;
        padding-top: 4px;
        padding-bottom: 4px;
    }

    #clone_revert {
        display: none;
        text-align: center;
        padding-top: 4px;
        padding-bottom: 4px;
    }

    #clone_got {
        display: none;
        text-align: center;
    }

    #ac_search { text-align:left; }
    #ac_input { position:static;width:16em; } /* to center, set static and explicit width: */
    #ac_container { text-align:left;width:20em; } /* to center, set left-align and explicit width: */
</style>

<script type="text/javascript" language="javascript">

<!--

function checkSelect( dep_id, name, username ) {

    if ( username == '' ) {
        alert('No username has been selected. Please select a username for this user');
        return false;
    }
    if ( name == '' ) {
        alert('No name has been selected. Please select a name for this user');
        return false;
    }
    if ( dep_id == '' ) {
        alert('No department has been selected. Please select a department for this user');
        return false;
    }
    return true;

}

function populateOtherFields() {
    // the name entered
    var full_name = document.getElementById('form_name').value;
    var names = full_name.split(' ');

    // if we only have one name ... leave the user to fill everything in
    // themself
    if (names.length < 2) { return; }

    // prepare useful name-parts
    var first_name = names[0];
    var rest_of_name = names.splice(1, names.length - 1).join('.');
    var initial = first_name.charAt(0);

    // username is (usually) initial.surname
    if ('' == document.getElementById('form_username').value) {
        document.getElementById('form_username').value = initial + '.' + rest_of_name;
    }

    // email is (usually) first.last@
    if ('' == document.getElementById('form_email_address').value) {
        document.getElementById('form_email_address').value = first_name + '.' + rest_of_name + '@net-a-porter.com';
    }
}

function clear_home_page () {
    var def_home_page    = document.forms['useprofile'].default_home_page;

    for (var n=0; n<def_home_page.length; n++) {
        if (def_home_page[n].checked) {
            def_home_page[n].checked    = false;
            document.getElementById('clear_home_page').checked    = true;
            break;
        }
    }
}

function toggle_clone_user () {
    if ( document.getElementById('clone_user_div').style.display == '' ) {
        document.getElementById('clone_user_div').style.display    = 'block';
        document.getElementById('toggle_clone_user_img').alt    = 'Click to Hide';
        document.getElementById('toggle_clone_user_img').title    = 'Click to Hide';
        document.getElementById('toggle_clone_user_img').src    = '/images/minus.gif';
    }
    else {
        document.getElementById('clone_got').style.display        = '';
        document.getElementById('clone_wait').style.display        = '';
        document.getElementById('clone_revert').style.display    = '';
        document.getElementById('ac_search').style.display        = 'block';
        document.getElementById('clone_user_div').style.display    = '';
        document.getElementById('toggle_clone_user_img').alt    = 'Click to Show';
        document.getElementById('toggle_clone_user_img').title    = 'Click to Show';
        document.getElementById('toggle_clone_user_img').src    = '/images/plus.gif';
    }
}

//-->

</script>


<span class="title">Account Details</span><br/>
<form name="useprofile" action="/Admin/UserAdmin/Profile/5001" method="post" onsubmit="javascript:return checkSelect(useprofile.department_id.value, useprofile.name.value);">

    <input type="hidden" id="user_id" name="user_id" value="5001" />
<table width="100%" cellpadding="0" cellspacing="0" border="0" id="user_account_details">
    <tr>
        <td colspan="2" class="divider" class="white"></td>
    </tr>
    <tr height="25">
        <td class="white" width="20%" align="right"><strong>Name:&nbsp;&nbsp;</strong></td>
        <td class="white" width="80%"><input type="text" id="form_name" name="name" value="Andrew Beech" ></td>
    </tr>
    <tr>
        <td colspan="2" class="divider" class="white"></td>
    </tr>
    <tr height="25">
        <td height="36" class="white" align="right"><strong>Department:&nbsp;&nbsp;</strong></td>
        <td class="white">
            <select name="department_id">
                <option value="">---------</option>


                        <option value="20">Buying</option>



                        <option value="5" selected="selected">Customer Care</option>



                        <option value="19">Customer Care Manager</option>



                        <option value="13">Design</option>



                        <option value="2">Distribution</option>



                        <option value="16">Distribution Management</option>



                        <option value="14">Editorial</option>



                        <option value="23">Fashion Advisor</option>



                        <option value="1">Finance</option>



                        <option value="10">IT</option>



                        <option value="9">Marketing</option>



                        <option value="21">Merchandising</option>



                        <option value="8">Personal Shopping</option>



                        <option value="15">Photography</option>



                        <option value="22">Product Merchandising</option>



                        <option value="7">Retail</option>



                        <option value="12">Sample</option>



                        <option value="3">Shipping</option>



                        <option value="17">Shipping Manager</option>



                        <option value="11">Stock Control</option>


            </select>
        </td>
    </tr>
    <tr>
        <td colspan="2" class="divider" class="white"></td>
    </tr>
    <tr>
        <td height="36" class="white" align="right"><strong>Preferred Sales Channel:&nbsp;&nbsp;</strong></td>
        <td class="white">
            <select name="pref_channel_id">
                <option value="0">No Preferred Channel</option>

                    <option value="7">JIMMYCHOO.COM</option>

                    <option value="5">MRPORTER.COM</option>

                    <option value="1">NET-A-PORTER.COM</option>

                    <option value="3">theOutnet.com</option>

            </select>
        </td>
    </tr>
    <tr>
        <td colspan="2" class="divider" class="white"></td>
    </tr>
    <tr height="25">
        <td class="white" align="right"><strong>Disabled:&nbsp;&nbsp;</strong></td>
        <td class="white"><input type="checkbox" name="disabled" value="1"  ></td>
    </tr>
    <tr>
        <td colspan="2" class="divider" class="white"></td>
    </tr>
    <tr height="25">
        <td class="white" align="right"><strong>Username:&nbsp;&nbsp;</strong></td>
        <td class="white">

                A.Beech

        </td>
    </tr>
    <tr>
        <td colspan="2" class="divider"></td>
    </tr>
    <tr height="25">
        <td class="white" align="right"><strong>e-mail:&nbsp;&nbsp;</strong></td>
        <td class="white"><input type="text" id="form_email_address" name="email_address" value="Andrew.Beech@net-a-porter.com" size="30"></td>
    </tr>
    <tr>
        <td colspan="2" class="divider"></td>
    </tr>
    <tr height="25">
        <td class="white" align="right"><strong>Phone:&nbsp;&nbsp;</strong></td>
        <td class="white"><input type="text" id="form_phone_ddi" name="phone_ddi" value="" size="30" maxlength="30"></td>
    </tr>
    <tr>
        <td colspan="2" class="divider"></td>
    </tr>


    <tr height="25">
        <td class="white" align="right"><strong>Print Barcode:&nbsp;&nbsp;</strong></td>
            <td class="white"><input type="checkbox" name="print_barcode" value="1" /></td>
    </tr>
    <tr>
        <td colspan="2" class="divider"></td>
    </tr>


    <tr>
        <td class="white" align="right"><strong>Use LDAP to build Main Nav:&nbsp;&nbsp;</strong></td>
        <td class="white">
            <input type="checkbox" name="use_acl_for_main_nav" value="1" checked="checked" />
            &nbsp;&nbsp;&nbsp;
            (If you are unsure about this option then please leave it as is.)
        </td>
    </tr>
    <tr><td colspan="2" class="divider"></td></tr>


    <tr>
        <td colspan="2"><img src="/images/blank.gif" width="1" height="10"></td>
    </tr>
    <tr>
        <td><!--
            <input type="hidden" name="print_barcode" value="1">
            <input type="submit" name="submit" value="Print Barcode &raquo;" class="button">--></td>
        <td align="right"><input type="submit" name="submit" value="Submit &raquo;" class="button"></td>
    </tr>

</table>
<br><br>

<div>Sub Sections with this <img class="inline" src="/images/icons/lock.png" /> next to them are granted access using <strong>LDAP</strong> and no longer by this page.</div>
<div>
    <span class="title" style="display: block; float: left; width: 50%;">Authorisation</span>
    <div style="float: right; text-align: right; padding-top: 5px;"><a href="javascript:toggle_clone_user();"><img id="toggle_clone_user_img" src="/images/plus.gif" alt="Click to Show" title="Click to Show" align="left" style="margin-top: 4px;" /></a>&nbsp;<a href="javascript:toggle_clone_user();">clone from another user</a></div>
    <br clear="all" />
</div>
<div id="clone_user_div">
    <div id="ac_search">
        <label for="ac_input"><strong>Type the name of the user you'd like to clone Authorisations from, then click 'Clone User':</strong></label>
        <input id="ac_input" type="text" size="30" value="" />
        <input id="ac_input_id" type="hidden" name="clone_operator_id" value="" />
        <input type="button" value="Clone User" onclick="javascript:cloneAuths('clone');" />
        <div id="ac_container"></div>
    </div>
    <div id="clone_wait">
        <span>Getting user authorisations for <span id="clonee_name" style="font-weight: bold;"></span>, please wait</span>
    </div>
    <div id="clone_revert">
        <span>Reverting back to user <span id="clonee_revert" style="font-weight: bold;"></span> authorisations, please wait</span>
    </div>
    <div id="clone_got">
        <span><input type="button" value="Accept" onclick="javascript:acceptAuths();"/>&nbsp;&nbsp;&nbsp;<strong>Click 'Accept' to keep these Authorisations <span style="font-weight: normal !important; font-style: italic;">(you will still need to 'Submit' to save them)</span> or 'Reject' to revert back</strong>&nbsp;&nbsp;&nbsp;<input type="button" value="Reject" onclick="javascript:restore_current();" /></span>
    </div>
</div>
<table width="100%" cellpadding="0" cellspacing="0" border="0" class="data" id="user_profile_authorisation">
    <thead>
    <tr>
        <td colspan="5" class="dividerHeader"></td>
    </tr>
    <tr height="24">
        <td class="tableHeader" width="150">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Section</td>
        <td class="tableHeader">Sub Section</td>
        <td class="tableHeader" align="center">Authorised</td>
        <td class="tableHeader" align="center">Authorisation Level</td>
        <td class="tableHeader" align="center">Default Home Page</td>
    </tr>
    <tr>
        <td colspan="5" class="dividerHeader"></td>
    </tr>
    </thead>
    <tbody>



            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<strong>Admin</strong></td>

                    <td colspan="3">&nbsp;</td>
                    <td align="center">[ <a href="javascript:clear_home_page();">clear home page</a> ]</td>

            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
                            <tr height="20">
                    <td></td>
                    <td>ACL Admin</td>
                    <td align="center"><input type="checkbox" id="auth_181" name="auth_181" value="1" ></td>
                    <td align="center">
                        <select id="level_181" name="level_181" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_181" name="default_home_page" value="181" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Email Templates</td>
                    <td align="center"><input type="checkbox" id="auth_48" name="auth_48" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_48" name="level_48" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_48" name="default_home_page" value="48" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Exchange Rates</td>
                    <td align="center"><input type="checkbox" id="auth_104" name="auth_104" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_104" name="level_104" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2" selected="selected">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_104" name="default_home_page" value="104" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Fraud Rules</td>
                    <td align="center"><input type="checkbox" id="auth_142" name="auth_142" value="1" ></td>
                    <td align="center">
                        <select id="level_142" name="level_142" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_142" name="default_home_page" value="142" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Job Queue</td>
                    <td align="center"><input type="checkbox" id="auth_123" name="auth_123" value="1" ></td>
                    <td align="center">
                        <select id="level_123" name="level_123" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_123" name="default_home_page" value="123" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Printers</td>
                    <td align="center"><input type="checkbox" id="auth_130" name="auth_130" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_130" name="level_130" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_130" name="default_home_page" value="130" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Sticky Pages</td>
                    <td align="center"><input type="checkbox" id="auth_135" name="auth_135" value="1" ></td>
                    <td align="center">
                        <select id="level_135" name="level_135" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_135" name="default_home_page" value="135" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>System Parameters</td>
                    <td align="center"><input type="checkbox" id="auth_136" name="auth_136" value="1" ></td>
                    <td align="center">
                        <select id="level_136" name="level_136" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_136" name="default_home_page" value="136" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>User Admin</td>
                    <td align="center"><input type="checkbox" id="auth_19" name="auth_19" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_19" name="level_19" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_19" name="default_home_page" value="19" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<strong>Customer Care</strong></td>

                    <td colspan="4">&nbsp;</td>

            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
                            <tr height="20">
                    <td></td>
                    <td>Customer Search</td>
                    <td align="center"><input type="checkbox" id="auth_80" name="auth_80" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_80" name="level_80" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_80" name="default_home_page" value="80" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Order Search</td>
                    <td align="center"><input type="checkbox" id="auth_54" name="auth_54" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_54" name="level_54" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_54" name="default_home_page" value="54" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Returns Pending</td>
                    <td align="center"><input type="checkbox" id="auth_12" name="auth_12" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_12" name="level_12" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_12" name="default_home_page" value="12" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<strong>Finance</strong></td>

                    <td colspan="4">&nbsp;</td>

            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
                            <tr height="20">
                    <td></td>
                    <td>Active Invoices</td>
                    <td align="center"><input type="checkbox" id="auth_20" name="auth_20" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_20" name="level_20" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2" selected="selected">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_20" name="default_home_page" value="20" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Credit Check</td>
                    <td align="center"><input type="checkbox" id="auth_2" name="auth_2" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_2" name="level_2" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2" selected="selected">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_2" name="default_home_page" value="2" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Credit Hold</td>
                    <td align="center"><input type="checkbox" id="auth_1" name="auth_1" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_1" name="level_1" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2" selected="selected">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_1" name="default_home_page" value="1" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Fraud Hotlist<img class="inline" src="/images/icons/lock.png" alt="Access granted by LDAP" title="Access granted by LDAP" /></td>
                    <td align="center"><input type="checkbox" id="auth_97" name="auth_97" value="1" disabled="disabled"></td>
                    <td align="center">
                        <select id="level_97" name="level_97" disabled="disabled">
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_97" name="default_home_page" value="97" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Fraud Rules</td>
                    <td align="center"><input type="checkbox" id="auth_143" name="auth_143" value="1" ></td>
                    <td align="center">
                        <select id="level_143" name="level_143" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_143" name="default_home_page" value="143" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Invalid Payments</td>
                    <td align="center"><input type="checkbox" id="auth_59" name="auth_59" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_59" name="level_59" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_59" name="default_home_page" value="59" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Pending Invoices</td>
                    <td align="center"><input type="checkbox" id="auth_21" name="auth_21" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_21" name="level_21" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2" selected="selected">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_21" name="default_home_page" value="21" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Reimbursements</td>
                    <td align="center"><input type="checkbox" id="auth_132" name="auth_132" value="1" ></td>
                    <td align="center">
                        <select id="level_132" name="level_132" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_132" name="default_home_page" value="132" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Store Credits</td>
                    <td align="center"><input type="checkbox" id="auth_57" name="auth_57" value="1" ></td>
                    <td align="center">
                        <select id="level_57" name="level_57" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_57" name="default_home_page" value="57" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Transaction Reporting</td>
                    <td align="center"><input type="checkbox" id="auth_106" name="auth_106" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_106" name="level_106" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2" selected="selected">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_106" name="default_home_page" value="106" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<strong>Fulfilment</strong></td>

                    <td colspan="4">&nbsp;</td>

            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
                            <tr height="20">
                    <td></td>
                    <td>Airwaybill</td>
                    <td align="center"><input type="checkbox" id="auth_10" name="auth_10" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_10" name="level_10" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_10" name="default_home_page" value="10" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Commissioner</td>
                    <td align="center"><input type="checkbox" id="auth_129" name="auth_129" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_129" name="level_129" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_129" name="default_home_page" value="129" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>DDU</td>
                    <td align="center"><input type="checkbox" id="auth_9" name="auth_9" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_9" name="level_9" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_9" name="default_home_page" value="9" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Dispatch</td>
                    <td align="center"><input type="checkbox" id="auth_7" name="auth_7" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_7" name="level_7" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_7" name="default_home_page" value="7" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Induction</td>
                    <td align="center"><input type="checkbox" id="auth_147" name="auth_147" value="1" ></td>
                    <td align="center">
                        <select id="level_147" name="level_147" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_147" name="default_home_page" value="147" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Invalid Shipments</td>
                    <td align="center"><input type="checkbox" id="auth_84" name="auth_84" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_84" name="level_84" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2" selected="selected">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_84" name="default_home_page" value="84" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Labelling</td>
                    <td align="center"><input type="checkbox" id="auth_86" name="auth_86" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_86" name="level_86" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2" selected="selected">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_86" name="default_home_page" value="86" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Manifest</td>
                    <td align="center"><input type="checkbox" id="auth_85" name="auth_85" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_85" name="level_85" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2" selected="selected">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_85" name="default_home_page" value="85" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>On Hold</td>
                    <td align="center"><input type="checkbox" id="auth_8" name="auth_8" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_8" name="level_8" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2" selected="selected">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_8" name="default_home_page" value="8" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Pack Lane Activity</td>
                    <td align="center"><input type="checkbox" id="auth_146" name="auth_146" value="1" ></td>
                    <td align="center">
                        <select id="level_146" name="level_146" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_146" name="default_home_page" value="146" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Packing</td>
                    <td align="center"><input type="checkbox" id="auth_6" name="auth_6" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_6" name="level_6" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_6" name="default_home_page" value="6" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Packing Exception</td>
                    <td align="center"><input type="checkbox" id="auth_128" name="auth_128" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_128" name="level_128" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_128" name="default_home_page" value="128" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Picking</td>
                    <td align="center"><input type="checkbox" id="auth_5" name="auth_5" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_5" name="level_5" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_5" name="default_home_page" value="5" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Picking Overview</td>
                    <td align="center"><input type="checkbox" id="auth_145" name="auth_145" value="1" ></td>
                    <td align="center">
                        <select id="level_145" name="level_145" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_145" name="default_home_page" value="145" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Pre-Order Hold</td>
                    <td align="center"><input type="checkbox" id="auth_98" name="auth_98" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_98" name="level_98" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_98" name="default_home_page" value="98" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Premier Dispatch</td>
                    <td align="center"><input type="checkbox" id="auth_134" name="auth_134" value="1" ></td>
                    <td align="center">
                        <select id="level_134" name="level_134" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_134" name="default_home_page" value="134" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Premier Routing</td>
                    <td align="center"><input type="checkbox" id="auth_99" name="auth_99" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_99" name="level_99" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2" selected="selected">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_99" name="default_home_page" value="99" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Selection</td>
                    <td align="center"><input type="checkbox" id="auth_4" name="auth_4" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_4" name="level_4" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2" selected="selected">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_4" name="default_home_page" value="4" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<strong>Goods In</strong></td>

                    <td colspan="4">&nbsp;</td>

            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
                            <tr height="20">
                    <td></td>
                    <td>Bag And Tag</td>
                    <td align="center"><input type="checkbox" id="auth_26" name="auth_26" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_26" name="level_26" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_26" name="default_home_page" value="26" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Barcode</td>
                    <td align="center"><input type="checkbox" id="auth_49" name="auth_49" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_49" name="level_49" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_49" name="default_home_page" value="49" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Delivery Cancel</td>
                    <td align="center"><input type="checkbox" id="auth_3" name="auth_3" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_3" name="level_3" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_3" name="default_home_page" value="3" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Delivery Hold</td>
                    <td align="center"><input type="checkbox" id="auth_37" name="auth_37" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_37" name="level_37" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_37" name="default_home_page" value="37" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Delivery Timetable</td>
                    <td align="center"><input type="checkbox" id="auth_117" name="auth_117" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_117" name="level_117" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_117" name="default_home_page" value="117" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Item Count</td>
                    <td align="center"><input type="checkbox" id="auth_23" name="auth_23" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_23" name="level_23" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_23" name="default_home_page" value="23" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Putaway</td>
                    <td align="center"><input type="checkbox" id="auth_27" name="auth_27" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_27" name="level_27" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_27" name="default_home_page" value="27" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Putaway Prep</td>
                    <td align="center"><input type="checkbox" id="auth_137" name="auth_137" value="1" ></td>
                    <td align="center">
                        <select id="level_137" name="level_137" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_137" name="default_home_page" value="137" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Putaway Prep Admin</td>
                    <td align="center"><input type="checkbox" id="auth_140" name="auth_140" value="1" ></td>
                    <td align="center">
                        <select id="level_140" name="level_140" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_140" name="default_home_page" value="140" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Putaway Prep Packing Exception</td>
                    <td align="center"><input type="checkbox" id="auth_144" name="auth_144" value="1" ></td>
                    <td align="center">
                        <select id="level_144" name="level_144" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_144" name="default_home_page" value="144" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Putaway Problem Resolution</td>
                    <td align="center"><input type="checkbox" id="auth_141" name="auth_141" value="1" ></td>
                    <td align="center">
                        <select id="level_141" name="level_141" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_141" name="default_home_page" value="141" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Quality Control</td>
                    <td align="center"><input type="checkbox" id="auth_24" name="auth_24" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_24" name="level_24" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_24" name="default_home_page" value="24" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Recent Deliveries</td>
                    <td align="center"><input type="checkbox" id="auth_62" name="auth_62" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_62" name="level_62" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_62" name="default_home_page" value="62" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Returns Arrival</td>
                    <td align="center"><input type="checkbox" id="auth_119" name="auth_119" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_119" name="level_119" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_119" name="default_home_page" value="119" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Returns Faulty</td>
                    <td align="center"><input type="checkbox" id="auth_46" name="auth_46" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_46" name="level_46" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_46" name="default_home_page" value="46" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Returns In</td>
                    <td align="center"><input type="checkbox" id="auth_15" name="auth_15" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_15" name="level_15" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_15" name="default_home_page" value="15" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Returns QC</td>
                    <td align="center"><input type="checkbox" id="auth_35" name="auth_35" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_35" name="level_35" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_35" name="default_home_page" value="35" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Stock In</td>
                    <td align="center"><input type="checkbox" id="auth_13" name="auth_13" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_13" name="level_13" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_13" name="default_home_page" value="13" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Surplus</td>
                    <td align="center"><input type="checkbox" id="auth_29" name="auth_29" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_29" name="level_29" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_29" name="default_home_page" value="29" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Vendor Sample In</td>
                    <td align="center"><input type="checkbox" id="auth_63" name="auth_63" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_63" name="level_63" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_63" name="default_home_page" value="63" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<strong>NAP Events</strong></td>

                    <td colspan="4">&nbsp;</td>

            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
                            <tr height="20">
                    <td></td>
                    <td>In The Box</td>
                    <td align="center"><input type="checkbox" id="auth_138" name="auth_138" value="1" ></td>
                    <td align="center">
                        <select id="level_138" name="level_138" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_138" name="default_home_page" value="138" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Manage</td>
                    <td align="center"><input type="checkbox" id="auth_124" name="auth_124" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_124" name="level_124" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_124" name="default_home_page" value="124" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Welcome Packs</td>
                    <td align="center"><input type="checkbox" id="auth_148" name="auth_148" value="1" ></td>
                    <td align="center">
                        <select id="level_148" name="level_148" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_148" name="default_home_page" value="148" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<strong>Outnet Events</strong></td>

                    <td colspan="4">&nbsp;</td>

            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
                            <tr height="20">
                    <td></td>
                    <td>Manage</td>
                    <td align="center"><input type="checkbox" id="auth_126" name="auth_126" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_126" name="level_126" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_126" name="default_home_page" value="126" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<strong>RTV</strong></td>

                    <td colspan="4">&nbsp;</td>

            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
                            <tr height="20">
                    <td></td>
                    <td>Awaiting Dispatch</td>
                    <td align="center"><input type="checkbox" id="auth_94" name="auth_94" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_94" name="level_94" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_94" name="default_home_page" value="94" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Dispatched RTV</td>
                    <td align="center"><input type="checkbox" id="auth_95" name="auth_95" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_95" name="level_95" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_95" name="default_home_page" value="95" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Faulty GI</td>
                    <td align="center"><input type="checkbox" id="auth_87" name="auth_87" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_87" name="level_87" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_87" name="default_home_page" value="87" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Inspect Pick</td>
                    <td align="center"><input type="checkbox" id="auth_88" name="auth_88" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_88" name="level_88" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_88" name="default_home_page" value="88" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>List RMA</td>
                    <td align="center"><input type="checkbox" id="auth_90" name="auth_90" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_90" name="level_90" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_90" name="default_home_page" value="90" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>List RTV</td>
                    <td align="center"><input type="checkbox" id="auth_91" name="auth_91" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_91" name="level_91" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_91" name="default_home_page" value="91" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Non Faulty</td>
                    <td align="center"><input type="checkbox" id="auth_122" name="auth_122" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_122" name="level_122" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_122" name="default_home_page" value="122" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Pack RTV</td>
                    <td align="center"><input type="checkbox" id="auth_93" name="auth_93" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_93" name="level_93" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_93" name="default_home_page" value="93" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Pick RTV</td>
                    <td align="center"><input type="checkbox" id="auth_92" name="auth_92" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_92" name="level_92" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_92" name="default_home_page" value="92" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Request RMA</td>
                    <td align="center"><input type="checkbox" id="auth_89" name="auth_89" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_89" name="level_89" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_89" name="default_home_page" value="89" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<strong>Reporting</strong></td>

                    <td colspan="4">&nbsp;</td>

            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
                            <tr height="20">
                    <td></td>
                    <td>Distribution Reports</td>
                    <td align="center"><input type="checkbox" id="auth_55" name="auth_55" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_55" name="level_55" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_55" name="default_home_page" value="55" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Shipping Reports</td>
                    <td align="center"><input type="checkbox" id="auth_96" name="auth_96" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_96" name="level_96" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_96" name="default_home_page" value="96" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<strong>Retail</strong></td>

                    <td colspan="4">&nbsp;</td>

            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
                            <tr height="20">
                    <td></td>
                    <td>Attribute Management</td>
                    <td align="center"><input type="checkbox" id="auth_111" name="auth_111" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_111" name="level_111" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2" selected="selected">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_111" name="default_home_page" value="111" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<strong>Sample</strong></td>

                    <td colspan="4">&nbsp;</td>

            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
                            <tr height="20">
                    <td></td>
                    <td>Review Requests</td>
                    <td align="center"><input type="checkbox" id="auth_67" name="auth_67" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_67" name="level_67" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_67" name="default_home_page" value="67" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Sample Cart</td>
                    <td align="center"><input type="checkbox" id="auth_64" name="auth_64" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_64" name="level_64" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_64" name="default_home_page" value="64" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Sample Cart Users</td>
                    <td align="center"><input type="checkbox" id="auth_105" name="auth_105" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_105" name="level_105" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_105" name="default_home_page" value="105" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Sample Transfer</td>
                    <td align="center"><input type="checkbox" id="auth_65" name="auth_65" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_65" name="level_65" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_65" name="default_home_page" value="65" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<strong>Stock Control</strong></td>

                    <td colspan="4">&nbsp;</td>

            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
                            <tr height="20">
                    <td></td>
                    <td>Cancellations</td>
                    <td align="center"><input type="checkbox" id="auth_47" name="auth_47" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_47" name="level_47" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_47" name="default_home_page" value="47" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Channel Transfer</td>
                    <td align="center"><input type="checkbox" id="auth_125" name="auth_125" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_125" name="level_125" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_125" name="default_home_page" value="125" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Dead Stock</td>
                    <td align="center"><input type="checkbox" id="auth_127" name="auth_127" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_127" name="level_127" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_127" name="default_home_page" value="127" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Duty Rates</td>
                    <td align="center"><input type="checkbox" id="auth_56" name="auth_56" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_56" name="level_56" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_56" name="default_home_page" value="56" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Final Pick</td>
                    <td align="center"><input type="checkbox" id="auth_51" name="auth_51" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_51" name="level_51" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_51" name="default_home_page" value="51" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Inventory</td>
                    <td align="center"><input type="checkbox" id="auth_11" name="auth_11" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_11" name="level_11" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_11" name="default_home_page" value="11" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Location</td>
                    <td align="center"><input type="checkbox" id="auth_78" name="auth_78" value="1" ></td>
                    <td align="center">
                        <select id="level_78" name="level_78" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_78" name="default_home_page" value="78" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Measurement</td>
                    <td align="center"><input type="checkbox" id="auth_50" name="auth_50" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_50" name="level_50" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_50" name="default_home_page" value="50" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Perpetual Inventory</td>
                    <td align="center"><input type="checkbox" id="auth_79" name="auth_79" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_79" name="level_79" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_79" name="default_home_page" value="79" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Product Approval</td>
                    <td align="center"><input type="checkbox" id="auth_73" name="auth_73" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_73" name="level_73" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_73" name="default_home_page" value="73" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Purchase Order</td>
                    <td align="center"><input type="checkbox" id="auth_34" name="auth_34" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_34" name="level_34" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_34" name="default_home_page" value="34" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Quarantine</td>
                    <td align="center"><input type="checkbox" id="auth_44" name="auth_44" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_44" name="level_44" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_44" name="default_home_page" value="44" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Recode</td>
                    <td align="center"><input type="checkbox" id="auth_131" name="auth_131" value="1" ></td>
                    <td align="center">
                        <select id="level_131" name="level_131" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_131" name="default_home_page" value="131" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Reservation</td>
                    <td align="center"><input type="checkbox" id="auth_39" name="auth_39" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_39" name="level_39" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_39" name="default_home_page" value="39" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Sample</td>
                    <td align="center"><input type="checkbox" id="auth_40" name="auth_40" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_40" name="level_40" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_40" name="default_home_page" value="40" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Sample Adjustment</td>
                    <td align="center"><input type="checkbox" id="auth_139" name="auth_139" value="1" ></td>
                    <td align="center">
                        <select id="level_139" name="level_139" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_139" name="default_home_page" value="139" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Stock Adjustment</td>
                    <td align="center"><input type="checkbox" id="auth_133" name="auth_133" value="1" ></td>
                    <td align="center">
                        <select id="level_133" name="level_133" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_133" name="default_home_page" value="133" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Stock Check</td>
                    <td align="center"><input type="checkbox" id="auth_41" name="auth_41" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_41" name="level_41" >
                            <option value="1"></option>
                            <option value="1" selected="selected">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_41" name="default_home_page" value="41" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Stock Relocation</td>
                    <td align="center"><input type="checkbox" id="auth_121" name="auth_121" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_121" name="level_121" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_121" name="default_home_page" value="121" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>


            <tr height="20">
                <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<strong>Web Content</strong></td>

                    <td colspan="4">&nbsp;</td>

            </tr>
            <tr>
                <td colspan="5" class="divider"></td>
            </tr>
                            <tr height="20">
                    <td></td>
                    <td>Designer Landing</td>
                    <td align="center"><input type="checkbox" id="auth_114" name="auth_114" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_114" name="level_114" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_114" name="default_home_page" value="114" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>
                            <tr height="20">
                    <td></td>
                    <td>Magazine</td>
                    <td align="center"><input type="checkbox" id="auth_118" name="auth_118" value="1" checked="checked" ></td>
                    <td align="center">
                        <select id="level_118" name="level_118" >
                            <option value="1"></option>
                            <option value="1">Read Only</option>
                            <option value="2">Operator</option>
                            <option value="3" selected="selected">Manager</option>
                        </select>
                    </td>
                    <td align="center">
                        <input type="radio" id="def_home_pge_118" name="default_home_page" value="118" />
                    </td>
                </tr>
                <tr>
                    <td colspan="5" class="divider"></td>
                </tr>





    <tr>
        <td colspan="5" class="white"><img src="/images/blank.gif" width="1" height="1" /></td>
    </tr>
    <tr>
        <td colspan="5" class="white" align="right"><input type="submit" name="submit" value="Submit &raquo;" class="button" /></td>
    </tr>

</table>
    <input id="clear_home_page" type="radio" name="default_home_page" value="0" style="display: none;" />
</form>


<script type="text/javascript" language="javascript">

var store_auths    = new Array();
var store_defpge= 0;

function store_current () {

    store_auths    = new Array();
    store_defpge= 0;

    xform    = document.forms['useprofile'].elements;

    for ( var x=0; x<xform.length; x++ ) {
        if ( xform[x].name.match(/^auth_/) ) {
            var parts    = xform[x].name.split('_');
            if ( xform[x].checked ) {
                store_auths[store_auths.length]    = { 'id':parts[1], 'level':document.getElementById('level_'+parts[1]).value };
            }
            else {
                store_auths[store_auths.length]    = { 'id':parts[1], 'level':0 };
            }
            if ( document.getElementById('def_home_pge_'+parts[1]).checked )
                store_defpge    = parts[1];
        }
    }

}

function restore_current () {

    for ( var x=0; x<store_auths.length; x++ ) {

        var auth    = store_auths[x];

        if ( auth.level ) {
            document.getElementById('auth_'+auth.id).checked        = true;
            document.getElementById('level_'+auth.id).selectedIndex    = auth.level;
        }
        else {
            document.getElementById('auth_'+auth.id).checked        = false;
            document.getElementById('level_'+auth.id).selectedIndex    = 0;
        }

    }

    clear_home_page();
    if ( store_defpge )
        document.getElementById('def_home_pge_'+store_defpge).checked= true;

    toggle_clone_user();

}

var handleCloneAuthsSuccess    = function(oResponse) {

    var oResults    = eval("(" + oResponse.responseText + ")");

    if ( oResults.status == 'OK' ) {
        for (var x=0; x<oResults.auths.length; x++ ) {

            var auth = oResults.auths[x];

            if ( auth.auth_level ) {
                document.getElementById('auth_'+auth.auth_id).checked            = true;
                document.getElementById('level_'+auth.auth_id).selectedIndex    = auth.auth_level;
            }
            else {
                document.getElementById('auth_'+auth.auth_id).checked            = false;
                document.getElementById('level_'+auth.auth_id).selectedIndex    = 0;
            }
        }

        clear_home_page();
        if ( oResults.def_home_page )
            document.getElementById('def_home_pge_'+oResults.def_home_page).checked    = true;

        if ( !oResults.revert ) {
            document.getElementById('clone_wait').style.display    = 'none';
            document.getElementById('clone_got').style.display    = 'block';
        }
        else {
            document.getElementById('clone_revert').style.display    = 'none';
            document.getElementById('ac_search').style.display        = 'block';
            toggle_clone_user();
        }
    }
    else {
        document.getElementById('clone_wait').style.display        = 'none';
        document.getElementById('clone_revert').style.display    = 'none';
        document.getElementById('ac_search').style.display        = 'block';
        alert(oResults.msg);
    }

    document.getElementById('ac_input').value    = '';
    document.getElementById('ac_input_id').value= '';
};

var handleFailure    = function(oResponse) {

    document.getElementById('clone_got').style.display    = 'none';
    document.getElementById('ac_search').style.display    = 'block';

    if(oResponse.responseText !== undefined){
        alert(oResponse.statusText);
    }

};

var cloneAuthsCallback = {
  success:handleCloneAuthsSuccess,
  failure:handleFailure
};

function acceptAuths () {

    document.getElementById('clone_wait').style.display    = 'none';
    document.getElementById('ac_search').style.display    = 'block';
    toggle_clone_user();

}

function cloneAuths (action) {

    // show loading div
//    showLoadingLayer();

    var op_id    = 0;

    if ( action == 'clone') {
        op_id    = document.getElementById('ac_input_id').value;

        document.getElementById('clonee_name').innerHTML    = document.getElementById('ac_input').value;
        document.getElementById('ac_search').style.display    = 'none';
        document.getElementById('clone_wait').style.display    = 'block';

        store_current();
    }

    if ( action == 'revert') {
        op_id    = document.getElementById('user_id').value + '&revert=1';

        document.getElementById('clonee_revert').innerHTML        = document.getElementById('form_name').value;
        document.getElementById('clone_got').style.display        = 'none';
        document.getElementById('clone_revert').style.display    = 'block';
    }

    if ( !op_id ) {
        alert("Please enter a valid User to clone");
        return;
    }

    var request = YAHOO.util.Connect.asyncRequest('GET', '/Admin/UserAdmin/AJAX/CloneUserAuths?ms=' + new Date().getTime() + '&page_operator_id=5001&clone_operator_id=' + op_id, cloneAuthsCallback);

}

</script>





        </div>
    </div>

    <p id="footer">    xTracker-DC  (2013.12.02.00.14.ga9cf023 / IWS phase 2 / PRL phase 0 / ). &copy; 2006 - 2013 NET-A-PORTER

</p>


</div>

    </body>
</html>
