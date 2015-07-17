#!/usr/bin/env perl


use NAP::policy "tt",     'test';

=head1 XTracker::EmailFunctions Test

Tests various functions in the 'XTracker::EmailFunctions' package.

currently tests:
    * send_customer_email
    * send_ddu_email
    * localised_email_address

Also tests Helper functions in 'XTracker::Config::Local' that
return email addresses:
    * customercare_email
    * fashionadvisor_email
    * returns_email
    * shipping_email
    * dispatch_email
    * localreturns_email
    * all_channel_email_addresses
    * personalshopping_email

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Email;
use Test::XT::Data;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw( :correspondence_templates );

use_ok( 'XTracker::EmailFunctions', qw(
                                send_customer_email
                                send_ddu_email
                                localised_email_address
                            ) );
use_ok( 'XTracker::Config::Local', qw(
                                config_var
                                config_section_slurp
                                customercare_email
                                fashionadvisor_email
                                returns_email
                                dispatch_email
                                shipping_email
                                localreturns_email
                                all_channel_email_addresses
                                personalshopping_email
                            ) );


# most of these tests will want to redefine 'send_email'
no warnings "redefine";
# some globals to define how the redefined 'send_email' function should work
my $send_email_action   = '1';      # 1 or 0 or 'DIE'
my %send_email_args;
*XTracker::EmailFunctions::send_email   = \&_redefined_send_email;
use warnings "redefine";


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, 'XTracker::Schema', "sanity check got a Schema" );

#------------- TESTS -------------
_test_send_customer_email( $schema, 1 );
_test_send_ddu_email( $schema, 1 );
_test_localised_email_address( $schema, 1 );
_test_email_address_helper_functions( $schema, 1 );
_test_all_channel_email_addresses( $schema, 1 );
#---------------------------------

done_testing;

# tests the 'send_customer_email' function
sub _test_send_customer_email {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip '_test_send_customer_email', 1         if ( !$oktodo );

        note "TESTING: _test_send_customer_email";

        _check_required_parameters( 'send_customer_email', {
                                        to      => 'to@example.com',
                                        from    => 'from@example.com',
                                        subject => 'subject',
                                        content => 'content',
                                } );

        note "TESTING: 'send_customer_email' function";

        my %tests   = (
                "Test all Params are passed Through"    => {
                        send_email_action   => 1,       # send_email returns TRUE
                        return_result       => 1,       # expect send_customer_email to return TRUE
                        in  => {
                                to          => 'to@example.com',
                                from        => 'from@example.com',
                                reply_to    => 'replyto@example.com',
                                subject     => 'subject',
                                content     => 'content',
                                content_type=> 'html',
                                attachments => 'attachments',
                                another     => 'arg',
                                and         => 'another',
                            },
                        expected    => {
                                to          => 'to@example.com',
                                from        => 'from@example.com',
                                reply_to    => 'replyto@example.com',
                                subject     => 'subject',
                                content     => 'content',
                                type        => 'html',
                                attachments => 'attachments',
                                other_args  => {
                                    another     => 'arg',
                                    and         => 'another',
                                },
                            },
                    },
                "Test when Reply-To not passed From is used" => {
                        send_email_action   => 1,
                        return_result       => 1,
                        in  => {
                                to          => 'to@example.com',
                                from        => 'from@example.com',
                                subject     => 'subject',
                                content     => 'content',
                                content_type=> 'html',
                                attachments => 'attachments',
                            },
                        expected    => {
                                to          => 'to@example.com',
                                from        => 'from@example.com',
                                reply_to    => 'from@example.com',
                                subject     => 'subject',
                                content     => 'content',
                                type        => 'html',
                                attachments => 'attachments',
                                other_args  => {},
                            },
                    },
                "Test when no Content Type is passed 'text' is used" => {
                        send_email_action   => 1,
                        return_result       => 1,
                        in  => {
                                to          => 'to@example.com',
                                from        => 'from@example.com',
                                reply_to    => 'replyto@example.com',
                                subject     => 'subject',
                                content     => 'content',
                                attachments => 'attachments',
                            },
                        expected    => {
                                to          => 'to@example.com',
                                from        => 'from@example.com',
                                reply_to    => 'replyto@example.com',
                                subject     => 'subject',
                                content     => 'content',
                                type        => 'text',
                                attachments => 'attachments',
                                other_args  => {},
                            },
                    },
                "Test when no Attachments are passed there is no problem" => {
                        send_email_action   => 1,
                        return_result       => 1,
                        in  => {
                                to          => 'to@example.com',
                                from        => 'from@example.com',
                                reply_to    => 'replyto@example.com',
                                subject     => 'subject',
                                content     => 'content',
                                content_type=> 'text',
                            },
                        expected    => {
                                to          => 'to@example.com',
                                from        => 'from@example.com',
                                reply_to    => 'replyto@example.com',
                                subject     => 'subject',
                                content     => 'content',
                                type        => 'text',
                                attachments => undef,
                                other_args  => {},
                            },
                    },
                "Test when 'send_email' returns FALSE so does 'send_customer_email'" => {
                        send_email_action   => 0,
                        return_result       => 0,
                        in  => {
                                to          => 'to@example.com',
                                from        => 'from@example.com',
                                subject     => 'subject',
                                content     => 'content',
                            },
                        expected    => {
                                to          => 'to@example.com',
                                from        => 'from@example.com',
                                reply_to    => 'from@example.com',
                                subject     => 'subject',
                                content     => 'content',
                                type        => 'text',
                                attachments => undef,
                                other_args  => {},
                            },
                    },
            );

        foreach my $label ( keys %tests ) {
            note "Testing: ${label}";
            my $test    = $tests{ $label };

            $send_email_action  = $test->{send_email_action};
            %send_email_args    = ();

            my $retval  = send_customer_email( $test->{in} );
            cmp_ok( $retval, '==', $test->{return_result}, "'send_customer_email' returned expected result" );
            is_deeply( \%send_email_args, $test->{expected}, "and expected arguments were passed to 'send_email'" );
        }
    };

    return;
}


# tests the 'send_ddu_email' function
sub _test_send_ddu_email {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip '_test_send_ddu_email', 1          if ( !$oktodo );

        note "TESTING: _test_send_ddu_email";

        $schema->txn_do( sub {
            my $data    = Test::XT::Data->new_with_traits(
                                    traits  => [
                                        'Test::XT::Data::Order',
                                    ],
                                );
            my $channel     = Test::XTracker::Data->channel_for_nap;
            $data->new_order( channel => $channel );
            my $order_nr    = $data->order->order_nr;
            my $shipment    = $data->order->get_standard_class_shipment;
            my $email_log_rs= $shipment->shipment_email_logs;
            my $template_rs = $schema->resultset('Public::CorrespondenceTemplate');

            # make the Template Id easier to type
            my $ddu_request_id  = $CORRESPONDENCE_TEMPLATES__DDU_ORDER__DASH__REQUEST_ACCEPT_SHIPPING_TERMS;
            my $ddu_followup_id = $CORRESPONDENCE_TEMPLATES__DDU_ORDER__DASH__FOLLOW_UP;

            # get the Templates required into a HASH
            my %templates   = map { $_->id => $_ }
                                    $template_rs->search( {
                                            id => [
                                                    $ddu_request_id,
                                                    $ddu_followup_id,
                                                ],
                                        } )->all;

            # update the Templates to be predicatable
            $templates{ $ddu_request_id }->update( {
                                            id_for_cms => undef,
                                            content => $ddu_request_id . ' - content [% order_number %]',
                                            subject => $ddu_request_id . ' - subject [% order_number %]',
                                            content_type => 'text',
                                        } );
            $templates{ $ddu_followup_id }->update( {
                                            id_for_cms => undef,
                                            content => $ddu_followup_id . ' - content [% order_number %]',
                                            subject => $ddu_followup_id . ' - subject [% order_number %]',
                                            content_type => 'html',
                                        } );

            # create a Localised version of the Shipping Email address
            # so that the correct Email Address can be tested for
            my $shipping_email  = Test::XTracker::Data::Email->create_localised_email_for_config_setting(
                $channel,
                'shipping_email',
                'fr_FR',
            );
            # set the Customer's language to be French
            $data->order->customer->set_language_preference('fr');

            my $template_data   = {
                        shipping_email  => $shipping_email->email_address,      # pass in the UN-Localised version
                        email_to        => 'to@example.com',
                        order_number    => $shipment->order->order_nr,
                        operator_id     => $APPLICATION_OPERATOR_ID,
                    };

            _check_required_parameters( 'send_ddu_email', {
                                        schema          => $schema,
                                        shipment        => $shipment,
                                        template_data   => $template_data,
                                    } );

            note "TESTING: 'send_ddu_email' function";

            my %test_data   = (
                    "No Email Type Passed"  => {
                            params              => [ $schema, $shipment, $template_data ],
                            send_email_action   => 1,
                            expect  => {
                                    return_value    => 0,
                                    email_logged    => 0,
                                },
                        },
                    "Email Type Passed but not anything meaningful" => {
                            params              => [ $schema, $shipment, $template_data, 'meaningless' ],
                            send_email_action   => 1,
                            expect  => {
                                    return_value    => 0,
                                    email_logged    => 0,
                                },
                        },
                    "Email Type is 'notify' expect Notify email to be sent" => {
                            params              => [ $schema, $shipment, $template_data, 'notify' ],
                            send_email_action   => 1,
                            expect  => {
                                    return_value    => 1,
                                    email_logged    => 1,
                                    template_id     => $ddu_request_id,
                                    email_params    => {
                                            to          => $template_data->{email_to},
                                            # tests that the Localised Email Address was used
                                            from        => $shipping_email->localised_email_address,
                                            reply_to    => $shipping_email->localised_email_address,
                                            subject     => "${ddu_request_id} - subject ${order_nr}",
                                            content     => "${ddu_request_id} - content ${order_nr}",
                                            type        => $templates{ $ddu_request_id }->content_type,
                                            attachments => undef,
                                            other_args  => {},
                                        },
                                },
                        },
                    "Email Type is 'followup' expect Follow Up email to be sent" => {
                            params              => [ $schema, $shipment, { %{ $template_data }, shipping_email => 'from@example.com' }, 'followup' ],
                            send_email_action   => 1,
                            expect  => {
                                    return_value    => 1,
                                    email_logged    => 1,
                                    template_id     => $ddu_followup_id,
                                    email_params    => {
                                            to          => $template_data->{email_to},
                                            # test when no Localised version of an Email Address
                                            from        => 'from@example.com',
                                            reply_to    => 'from@example.com',
                                            subject     => "${ddu_followup_id} - subject ${order_nr}",
                                            content     => "${ddu_followup_id} - content ${order_nr}",
                                            type        => $templates{ $ddu_followup_id }->content_type,
                                            attachments => undef,
                                            other_args  => {},
                                        },
                                },
                        },
                    "Email Type is 'notify' but have 'send_email' fail, expect Notify email NOT to be sent" => {
                            params              => [ $schema, $shipment, $template_data, 'notify' ],
                            send_email_action   => 0,
                            expect  => {
                                    return_value    => 0,
                                    email_logged    => 0,
                                    template_id     => $ddu_request_id,
                                    email_params    => {
                                            to          => $template_data->{email_to},
                                            # tests that the Localised Email Address was used
                                            from        => $shipping_email->localised_email_address,
                                            reply_to    => $shipping_email->localised_email_address,
                                            subject     => "${ddu_request_id} - subject ${order_nr}",
                                            content     => "${ddu_request_id} - content ${order_nr}",
                                            type        => $templates{ $ddu_request_id }->content_type,
                                            attachments => undef,
                                            other_args  => {},
                                        },
                                },
                        },
                    "Email Type is 'followup' but have 'send_email' fail, expect Follow Up email NOT to be sent" => {
                            params              => [ $schema, $shipment, { %{ $template_data }, shipping_email => 'from@example.com' }, 'followup' ],
                            send_email_action   => 0,
                            expect  => {
                                    return_value    => 0,
                                    email_logged    => 0,
                                    template_id     => $ddu_followup_id,
                                    email_params    => {
                                            to          => $template_data->{email_to},
                                            # test when no Localised version of an Email Address
                                            from        => 'from@example.com',
                                            reply_to    => 'from@example.com',
                                            subject     => "${ddu_followup_id} - subject ${order_nr}",
                                            content     => "${ddu_followup_id} - content ${order_nr}",
                                            type        => $templates{ $ddu_followup_id }->content_type,
                                            attachments => undef,
                                            other_args  => {},
                                        },
                                },
                        },
                );

            foreach my $label ( keys %test_data ) {
                note "Testing: ${label}";
                my $test    = $test_data{ $label };

                # clear all Email Logs
                $email_log_rs->reset->delete;

                # clear 'send_email' params
                %send_email_args    = ();
                # set the action for the 'send_email' function
                $send_email_action  = $test->{send_email_action} // 1;

                my @func_params = @{ $test->{params} };
                my $expect      = $test->{expect};
                my $log_prefix  = ( $expect->{email_logged} ? 'AN' : 'NO' );

                # call the function
                my $retval  = send_ddu_email( @func_params );

                cmp_ok( $retval, '==', $expect->{return_value}, "Function Return Value as Expected" );
                cmp_ok( $email_log_rs->reset->count, '==', $expect->{email_logged}, "${log_prefix} Email was Logged" );
                if ( $expect->{email_logged} ) {
                    my $template= $template_rs->find( $expect->{template_id} );
                    my $log     = $email_log_rs->first;
                    cmp_ok( $log->correspondence_templates_id, '==', $expect->{template_id},
                                                    "and for the Correct Template: '" . $template->name . "'" );
                }

                if ( $expect->{email_params} ) {
                    cmp_ok( ( keys %send_email_args ), '>', 1, "'send_email' was called" );
                    is_deeply( \%send_email_args, $expect->{email_params}, "and with the Expected Parameters" ) or diag "====> " . p( %send_email_args );
                }
                else {
                    cmp_ok( ( keys %send_email_args ), '==', 0, "'send_email' wasn't called" );
                }
            }


            # rollback changes
            $schema->txn_rollback();
        } );
    };

    return;
}

# tests Localised Email function
sub _test_localised_email_address {
    my ( $schema, $oktodo ) = @_;

    SKIP: {
        skip '_test_localised_email_address', 1         if ( !$oktodo );

        note "TESTING: _test_localised_email_address";

        # populate the 'localised_email_address' with
        # the following data to be used in tests
        my @test_email_addresses    = (
            # email_address, locale, localised_email_address
            [ 'test_address1@net-a-porter.com', 'de_DE', 'test_address1.de_DE@net-a-porter.com' ],
            [ 'test_address1@net-a-porter.com', 'fr_FR', 'test_address1.fr_FR@net-a-porter.com' ],
            [ 'TeSt_AddRess3@net-a-PoRter.com', 'de_DE', 'test_address3.de_DE@net-a-porter.com' ],
            [ 'test_address3@theoutnet.com', 'de_DE', 'test_address3.de_DE@theoutnet.com' ],
            [ 'test_address4@net-a-porter.com', 'de_DE', 'test_address4.de_DE@theoutnet.com' ],
            [ 'test_address4@net-a-porter.com', 'zh_ZH', 'test_address4.zh_ZH@theoutnet.com' ],
        );

        my %tests   = (
            "Ask for Email Address not in the table, expect to be given back what was given" => {
                email       => 'test_address1@mrporter.com',
                locale      => 'en_GB',
                expected    => 'test_address1@mrporter.com',
            },
            "Email Address not in the table, passing in a mixed case email address and expect the same mixed case address back" => {
                email       => 'tEst_AdDress1@MrPORter.com',
                locale      => 'en_GB',
                expected    => 'tEst_AdDress1@MrPORter.com',
            },
            "Ask for Email Address using 'locale', expect localised version" => {
                email       => 'test_address1@net-a-porter.com',
                locale      => 'de_DE',
                expected    => 'test_address1.de_DE@net-a-porter.com',
            },
            "Pass in a Mixed Cased Email Address, should make no difference and get back localised version" => {
                email       => 'tEsT_ADDREss1@nEt-a-pORter.com',
                locale      => 'de_DE',
                expected    => 'test_address1.de_DE@net-a-porter.com',
            },
            "Ask for Email Address that's mixed case in the table but passing in a lowercase email address, expect localised version" => {
                email       => 'test_address3@net-a-porter.com',
                locale      => 'de_DE',
                expected    => 'test_address3.de_DE@net-a-porter.com',
            },
            "Ask for Email Address using 'language', expect localised version" => {
                email       => 'test_address1@net-a-porter.com',
                language    => 'fr',
                expected    => 'test_address1.fr_FR@net-a-porter.com',
            },
            "Ask for Email Address but with a 'locale' that's not in the table, expect back what was given" => {
                email       => 'test_address1@net-a-porter.com',
                locale      => 'zh_CN',
                expected    => 'test_address1@net-a-porter.com',
            },
            "Ask for Email Address but with a 'language' that's not in the table, expect back what was given" => {
                email       => 'test_address4@net-a-porter.com',
                language    => 'fr',
                expected    => 'test_address4@net-a-porter.com',
            },
            "Passing in 'undef' email address should get empty string back" => {
                email       => undef,
                locale      => 'fr_FR',
                expected    => '',
            },
            "Passing in 'empty' email address should get empty string back" => {
                email       => '',
                locale      => 'fr_FR',
                expected    => '',
            },
            "Passing in Email Address but an Empty Locale should get back what was given" => {
                email       => 'test_address1@net-a-porter.com',
                locale      => '',
                expected    => 'test_address1@net-a-porter.com',
            },
            "Passing in Email Address but an 'undef' Locale should get back what was given" => {
                email       => 'test_address1@net-a-porter.com',
                locale      => undef,
                expected    => 'test_address1@net-a-porter.com',
            },
            "Passing in an Email Address without an '\@' symbol in it, expect to get back what was given" => {
                email       => 'test_address1',
                locale      => 'fr_FR',
                expected    => 'test_address1',
            },
        );

        $schema->txn_do( sub {
            # populate the table with test data
            my $localised_email_rs  = $schema->resultset('Public::LocalisedEmailAddress');
            $localised_email_rs->search->delete;
            foreach my $row ( @test_email_addresses ) {
                $localised_email_rs->create( {
                    email_address           => $row->[0],
                    locale                  => $row->[1],
                    localised_email_address => $row->[2],
                } );
            }

            foreach my $label ( keys %tests ) {
                note "Test: ${label}";
                my $test    = $tests{ $label };

                my $locale  = $test->{locale} || $test->{language};
                my $got = localised_email_address( $schema, $locale, $test->{email} );
                is(
                    $got,
                    $test->{expected},
                    "Passing in: '" . ( defined $test->{email} ? $test->{email} : 'undef' ) . "', " .
                    "with " . ( exists( $test->{locale} ) ? 'Locale' : 'Language' ) . ": '" . ( defined $locale ? $locale : 'undef' ) . "', " .
                    "got back as expected: '${got}'"
                );
            }


            # rollback changes
            $schema->txn_rollback();
        } );
    };

    return;
}

# tests email address helper functions
# found in XTracker::Config::Local
sub _test_email_address_helper_functions {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip '_test_email_address_helper_functions', 1         if ( !$oktodo );

        note "TESTING: _test_email_address_helper_functions";

        my $channel         = Test::XTracker::Data->any_channel;
        my $config_section  = $channel->business->config_section;

        my %functions_to_test   = (
            customercare_email      => \&customercare_email,
            fashionadvisor_email    => \&fashionadvisor_email,
            returns_email           => \&returns_email,
            dispatch_email          => \&dispatch_email,
            shipping_email          => \&shipping_email,
            localreturns_email      => \&localreturns_email,
            personalshopping_email  => \&personalshopping_email,
        );

        my %locale_to_test  = (
            fr_FR   => 'fr',
        );
        # just a Locale & Language that won't exist in the DB
        my $other_locale    = 'en_GB';
        my $other_language  = 'en';

        # will store what's expected back from
        # the functions by language & locale
        my %expected_results;

        # generate some test data
        my @test_data;
        foreach my $email_type ( keys %functions_to_test ) {
            my $email   = config_var( "Email_${config_section}", $email_type );
            foreach my $locale ( keys %locale_to_test ) {
                my $localised_email = "${locale}.${email}";
                push @test_data, {
                    email_address           => $email,
                    locale                  => $locale,
                    localised_email_address => $localised_email,
                };
                my $language    = $locale_to_test{ $locale };
                $expected_results{ $email_type }{locale}{ $locale }     = $localised_email;
                $expected_results{ $email_type }{language}{ $language } = $localised_email;
            }
            # for the Other Locale/Language then the original email should be returned
            $expected_results{ $email_type }{locale}{ $other_locale }       = $email;
            $expected_results{ $email_type }{language}{ $other_language }   = $email;
            $expected_results{ $email_type }{standard}                      = $email;
        }

        # put the other locales in the hash with the others
        $locale_to_test{ $other_locale }    = $other_language;

        $schema->txn_do( sub {
            # populate the table with test data
            my $localised_email_rs  = $schema->resultset('Public::LocalisedEmailAddress');
            $localised_email_rs->search->delete;
            foreach my $row ( @test_data ) {
                $localised_email_rs->create( $row );
            }

            foreach my $function_name ( keys %functions_to_test ) {
                note "Testing: '$function_name' function";
                my $function    = $functions_to_test{ $function_name };
                my $expected    = $expected_results{ $function_name };

                # Test just getting the standard email address
                my $got = $function->( $config_section );
                is( $got, $expected->{standard},
                            "Using the Standard way of calling the function and got expected email address: '${got}'" );

                # Test calling it with Locales/Languages and should get the translations
                while ( my ( $locale, $language ) = each %locale_to_test ) {
                    # test callling with Locale/Language and should get localised email back
                    $got    = $function->( $config_section, { schema => $schema, locale => $locale } );
                    is( $got, $expected->{locale}{ $locale },
                                "Calling with Locale: '${locale}' and got expected email address: '${got}'" );

                    $got    = $function->( $config_section, { schema => $schema, language => $language } );
                    is( $got, $expected->{language}{ $language },
                                "Calling with Language: '${language}' and got expected email address: '${got}'" );

                    # test callling with 'undef' Locale/Language to simulate no
                    # Locale/Language known and should get standard email back
                    $got    = $function->( $config_section, { schema => $schema, locale => undef } );
                    is( $got, $expected->{standard},
                                "Calling with an 'undef' Locale and got expected Standard email address: '${got}'" );

                    $got    = $function->( $config_section, { schema => $schema, language => undef } );
                    is( $got, $expected->{standard},
                                "Calling with an 'undef' Language and got expected Standard email address: '${got}'" );

                    # test callling with empty Locale/Language to simulate no
                    # Locale/Language known and should get standard email back
                    $got    = $function->( $config_section, { schema => $schema, locale => '' } );
                    is( $got, $expected->{standard},
                                "Calling with an empty Locale and got expected Standard email address: '${got}'" );

                    $got    = $function->( $config_section, { schema => $schema, language => '' } );
                    is( $got, $expected->{standard},
                                "Calling with an empty Language and got expected Standard email address: '${got}'" );
                }

                _check_function_fails_ok( $channel, $function_name, $function );
            }


            # rollback changes
            $schema->txn_rollback;
        } );
    };

    return;
}

# this tests the 'all_channel_email_addresses'
# function that returns all email addresses from
# the Config for a Sales Channel
sub _test_all_channel_email_addresses {
    my ( $schema, $oktodo ) = @_;

    SKIP: {
        skip '_test_all_channel_email_addresses', 1         if ( !$oktodo );

        note "TESTING: _test_all_channel_email_addresses";

        my $channel         = Test::XTracker::Data->any_channel;
        my $config_section  = $channel->business->config_section;

        # get all the emails out of the
        # config for the Sales Channel
        my $all_emails  = config_section_slurp( "Email_${config_section}" );

        # use the French Locale for
        # localised versions of the emails
        my $locale      = 'fr_FR';
        my $language    = 'fr';

        $schema->txn_do( sub {
            # clear out current localisations
            $schema->resultset('Public::LocalisedEmailAddress')->search->delete;

            # to check that localised versions are
            # returned, create localised versions of
            # every other one of the emails
            my %localised_emails;
            my $localise    = 1;
            # an email address can be used by more than one
            # setting so store the translation of an address here
            my %emails_processed;
            while ( my ( $setting, $address ) = each %{ $all_emails } ) {
                if ( $localise > 0 && !exists( $emails_processed{ $address } ) ) {
                    # if we should localise and the email
                    # address hasn't already been translated
                    my $localised_email = Test::XTracker::Data::Email->create_localised_email_address(
                        $address,
                        $locale,
                    );
                    $emails_processed{ $address }   = $localised_email->localised_email_address;
                }
                else {
                    # store the un-translated email here
                    # if it hasn't been stored already
                    $emails_processed{ $address }   //= $address;
                }

                $localised_emails{ $setting }   = $emails_processed{ $address };

                $localise   *= -1;
            }

            note "Calling 'all_channel_email_addresses' WITHOUT wanting any Localised versions";
            my $got = all_channel_email_addresses( $config_section );
            is_deeply( $got, $all_emails, "and got Email Addresses expected all Standard NO Localised versions" );

            note "Calling 'all_channel_email_addresses' WANTING localised versions, using a Locale";
            $got    = all_channel_email_addresses( $config_section, { schema => $schema, locale => $locale } );
            is_deeply( $got, \%localised_emails, "and got ALL Email Addresses expected a mixture of Localised and Standard" );

            note "Calling 'all_channel_email_addresses' WANTING localised versions, using a Language";
            $got    = all_channel_email_addresses( $config_section, { schema => $schema, language => $language } );
            is_deeply( $got, \%localised_emails, "and got ALL Email Addresses expected a mixture of Localised and Standard" );


            # test callling with 'undef' Locale/Language to simulate no Locale/Language known
            note "Calling 'all_channel_email_addresses' WANTING localised versions, using an 'undef' Locale";
            $got    = all_channel_email_addresses( $config_section, { schema => $schema, locale => undef } );
            is_deeply( $got, $all_emails, "and got Email Addresses expected all Standard NO Localised versions" );

            note "Calling 'all_channel_email_addresses' WANTING localised versions, using an 'undef' Language";
            $got    = all_channel_email_addresses( $config_section, { schema => $schema, language => undef } );
            is_deeply( $got, $all_emails, "and got Email Addresses expected all Standard NO Localised versions" );


            # test callling with empty Locale/Language to simulate no Locale/Language known
            note "Calling 'all_channel_email_addresses' WANTING localised versions, using an Empty Locale";
            $got    = all_channel_email_addresses( $config_section, { schema => $schema, locale => '' } );
            is_deeply( $got, $all_emails, "and got Email Addresses expected all Standard NO Localised versions" );

            note "Calling 'all_channel_email_addresses' WANTING localised versions, using an Empty Language";
            $got    = all_channel_email_addresses( $config_section, { schema => $schema, language => '' } );
            is_deeply( $got, $all_emails, "and got Email Addresses expected all Standard NO Localised versions" );


            _check_function_fails_ok( $channel, 'all_channel_email_addresses', \&all_channel_email_addresses );


            # rollback changes
            $schema->txn_rollback;
        } );
    };

    return;
}

# check required parameters for functions
sub _check_required_parameters {
    my ( $function, $args )     = @_;

    my %funcs_to_test   = (
            'send_customer_email'   => {
                    "Pass NO 'To' Address"  => {
                            params  => [ { from => $args->{from}, subject => $args->{subject}, content => $args->{content} } ],
                            expect  => qr/Argument 'to' missing/i,
                        },
                    "Pass Empty 'To' Address"  => {
                            params  => [ { to => '', from => $args->{from}, subject => $args->{subject}, content => $args->{content} } ],
                            expect  => qr/Argument 'to' missing/i,
                        },
                    "Pass 'undef' as 'To' Address"  => {
                            params  => [ { to => undef, from => $args->{from}, subject => $args->{subject}, content => $args->{content} } ],
                            expect  => qr/Argument 'to' missing/i,
                        },
                    "Pass NO 'From' Address"  => {
                            params  => [ { to => $args->{to}, subject => $args->{subject}, content => $args->{content} } ],
                            expect  => qr/Argument 'from' missing/i,
                        },
                    "Pass Empty 'From' Address"  => {
                            params  => [ { to => $args->{to}, from => '', subject => $args->{subject}, content => $args->{content} } ],
                            expect  => qr/Argument 'from' missing/i,
                        },
                    "Pass 'undef' as 'From' Address"  => {
                            params  => [ { to => $args->{to}, from => undef, subject => $args->{subject}, content => $args->{content} } ],
                            expect  => qr/Argument 'from' missing/i,
                        },
                    "Pass NO 'Subject'"  => {
                            params  => [ { to => $args->{to}, from => $args->{from}, content => $args->{content} } ],
                            expect  => qr/Argument 'subject' missing/i,
                        },
                    "Pass Empty 'Subject'"  => {
                            params  => [ { to => $args->{to}, from => $args->{from}, subject => '', content => $args->{content} } ],
                            expect  => qr/Argument 'subject' missing/i,
                        },
                    "Pass 'undef' as 'Subject'"  => {
                            params  => [ { to => $args->{to}, from => $args->{from}, subject => undef, content => $args->{content} } ],
                            expect  => qr/Argument 'subject' missing/i,
                        },
                    "Pass NO 'Content'"  => {
                            params  => [ { to => $args->{to}, from => $args->{from}, subject => $args->{subject} } ],
                            expect  => qr/Argument 'content' missing/i,
                        },
                    "Pass Empty 'Content'"  => {
                            params  => [ { to => $args->{to}, from => $args->{from}, subject => $args->{subject}, content => '' } ],
                            expect  => qr/Argument 'content' missing/i,
                        },
                    "Pass 'undef' as 'Content'"  => {
                            params  => [ { to => $args->{to}, from => $args->{from}, subject => $args->{subject}, content => undef } ],
                            expect  => qr/Argument 'content' missing/i,
                        },
                },
            'send_ddu_email'    => {
                    'Pass NO Schema Handler'    => {
                            params  => [ undef, $args->{shipment}, $args->{template_data}, 'notify' ],
                            expect  => qr/No Schema Handler/i,
                        },
                    'Pass NO Shipment Object'   => {
                            params  => [ $args->{schema}, undef, $args->{template_data}, 'notify' ],
                            expect  => qr/No Shipment Object/i,
                        },
                    'Pass NO Template Data'   => {
                            params  => [ $args->{schema}, $args->{shipment}, undef, 'notify' ],
                            expect  => qr/No Template Data/i,
                        },
                    'Pass in a Schema Handler but NOT the correct type' => {
                            params  => [ [ 2 ], $args->{shipment}, $args->{template_data}, 'notify' ],
                            expect  => qr/No Schema Handler/i,
                        },
                    'Pass in a Shipment Object but NOT the correct type'    => {
                            params  => [ $args->{schema}, { 1 => 2 }, $args->{template_data}, 'notify' ],
                            expect  => qr/No Shipment Object/i,
                        },
                    'Pass in a Template Data but NOT the correct type'  => {
                            params  => [ $args->{schema}, $args->{shipment}, [ 'fred' ], 'notify' ],
                            expect  => qr/No Template Data/i,
                        },
                },
        );

    return      if ( !exists( $funcs_to_test{ $function } ) );

    note "TESTING Required Params for '${function}'";
    my $tests   = $funcs_to_test{ $function };
    my $func_ref= \&${function};

    foreach my $label ( keys %{ $tests } ) {
        note "Testing: ${label}";
        my $test    = $tests->{ $label };

        my @params  = @{ $test->{params} };
        my $expect  = $test->{expect};

        throws_ok {
                    $func_ref->( @params );
                  }
                  qr/$expect/,
                  "got expected error thrown";
    }

    return;
}

#-----------------------------------------------------------------------

# used to test that config helper functions
# that can be passed additional args to get
# localised versions of email addresses fail
# correctly when the wrong params are passed
sub _check_function_fails_ok {
    my ( $channel, $function_name, $function )  = @_;

    my $locale          = 'en_GB';
    my $schema          = $channel->result_source->schema;
    my $config_section  = $channel->business->config_section;

    my $function_in_error   = qr/.*${function_name}/i;

    # all the ways of calling the functions
    # that should result in a fatal error
    my %failure_tests   = (
        "Calling function with ARRAY Ref as 2nd parameter dies and throws 'should be a HASH Ref' error" => {
            params          => [ $config_section, [ 1 ] ],
            expected_error  => qr/Second Parameter should be a HASH Ref/i,
        },
        "Calling function with an Object as 2nd parameter dies and throws 'should be a HASH Ref' error" => {
            params          => [ $config_section, $schema ],
            expected_error  => qr/Second Parameter should be a HASH Ref/i,
        },
        "Calling function with a Scalar as 2nd parameter dies and throws 'should be a HASH Ref' error" => {
            params          => [ $config_section, $locale ],
            expected_error  => qr/Second Parameter should be a HASH Ref/i,
        },
        "Calling function with HASH Ref, but with no Schema, dies and throws 'no Schema in Args' error" => {
            params          => [ $config_section, { locale => $locale } ],
            expected_error  => qr/No Schema passed in Arguments/i,
        },
        "Calling function with HASH Ref, but with an 'undef' Schema, dies and throws 'no Schema in Args' error" => {
            params          => [ $config_section, { schema => undef, locale => $locale } ],
            expected_error  => qr/No Schema passed in Arguments/i,
        },
        "Calling function with HASH Ref, but with something that isn't a Schema, dies and throws 'no Schema in Args' error" => {
            params          => [ $config_section, { schema => [ 1 ], locale => $locale } ],
            expected_error  => qr/No Schema passed in Arguments/i,
        },
        "Calling function with HASH Ref, but with no Locale or Langauge, dies and throws 'no Locale/Language in Args' error" => {
            params          => [ $config_section, { schema => $schema, xlocale => $locale } ],
            expected_error  => qr/No Locale or Language passed in Arguments/i,
        },
    );

    # check for expected failures when calling
    # the function in certain circumstances
    foreach my $label ( keys %failure_tests ) {
        my $params  = $failure_tests{ $label }{params};
        my $error   = $failure_tests{ $label }{expected_error};

        throws_ok {
            my $got = $function->( @{ $params } );
        }
        qr/${error}${function_in_error}/,
        $label . ": '" . $@ . "'";
    }

    return;
}

# used to redefine the 'send_email' function
sub _redefined_send_email {
    my @params  = @_;

    note "========> IN REDEFINED 'send_email' FUNCTION";

    %send_email_args    = (
                from        => $params[0],
                reply_to    => $params[1],
                to          => $params[2],
                subject     => $params[3],
                content     => $params[4],
                type        => $params[5],
                attachments => $params[6],
                other_args  => $params[7],
            );

    if ( $send_email_action eq 'DIE' ) {
        die "Redefined 'send_email' function told to DIE for Test";
    }

    return $send_email_action;
}
