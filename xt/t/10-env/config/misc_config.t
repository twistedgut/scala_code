#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::RunCondition export => [ qw( $distribution_centre ) ];

use Test::XTracker::Data;
use Test::XTracker::ParamCheck;

use XTracker::Constants         qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB qw( :channel );
use XTracker::Database 'xtracker_schema';

use Data::Dump  qw( pp );


use Test::Differences;

BEGIN {
    use_ok('XTracker::Config::Local', qw(
                            config_var
                            isa_finance_manager_user
                            get_file_paths
                            is_staff_order_premier_channel
                            default_carrier
                            order_nr_regex
                            order_nr_regex_including_legacy
                        ));

    can_ok("XTracker::Config::Local", qw(
                            config_var
                            isa_finance_manager_user
                            get_file_paths
                            is_staff_order_premier_channel
                            order_nr_regex
                            order_nr_regex_including_legacy
                        ) );
}

my $schema = xtracker_schema;
isa_ok($schema,"XTracker::Schema","Schema Connection");

#---- Test Functions ------------------------------------------

_test_reqd_params($schema,1);
_test_misc_functions($schema,1);
_test_default_carrier();
_test_order_number_regex( 1 );

#--------------------------------------------------------------


done_testing();

#---- TEST FUNCTIONS ------------------------------------------

# Test that the functions are checking for required parameters
sub _test_reqd_params {
    my $schema  = shift;

    my $param_check = Test::XTracker::ParamCheck->new();

    SKIP: {
        skip "_test_reqd_params",1           if (!shift);

        note "Testing for Required Parameters";

        $param_check->check_for_params(  \&isa_finance_manager_user,
                            'isa_finance_manager_user',
                            [ $schema, 'it.god' ],
                            [ "No Schema Connection Passed", "No User Name Passed" ],
                        );

        $param_check->check_for_params(  \&is_staff_order_premier_channel,
                            'is_staff_order_premier_channel',
                            [ 'NAP' ],
                            [ 'No Sales Channel Conf Section Passed In' ],
                        );
    }
}

# This tests miscellaneous functions used to get the general config settings
sub _test_misc_functions {
    my $schema  = shift;

    my $conf_setting= $schema->resultset('SystemConfig::ConfigGroupSetting');
    my $channels    = $schema->resultset('Public::Channel')->get_channels();
    # this is in 'xtracket_test_base.conf' for the Test Harness
    my $base_dir    = config_var( 'SystemPaths', 'xtdc_base_dir' );
    my $tmp;
    my $expected;

    ok( defined $base_dir && $base_dir ne "", "'xtdc_base_dir' config setting has a value" );

    SKIP: {
        skip "_test_misc_functions",1           if (!shift);

        note "TESTING Miscellaneous Functions";

        note "Testing 'isa_finance_manager_user' function";
        # make sure it-god is definetly not one of the Finance Manager Users
        $tmp    = $conf_setting->search( { 'config_group.name' => 'Finance_Manager_Users', 'me.setting' => 'user', 'me.value' => 'it.god' }, { join => 'config_group' } )->first;
        if ( defined $tmp ) {
            $tmp->delete();
        }
        $tmp    = $conf_setting->config_var( 'Finance_Manager_Users', 'user' );
        ok( defined $tmp, "Found some settings for 'Finance_Manager_Users' config group" );
        # test using 'it.god' user as this shouldn't be one of the ones in the above user list
        cmp_ok( isa_finance_manager_user( $schema, 'it.god' ), '==', 0, "'it.god' user is not a 'Finance_Manager_User'" );
        # test using the first user from the above list and this should be in the Finance Manager Users list
        cmp_ok( isa_finance_manager_user( $schema, ( ref($tmp) eq 'ARRAY' ? $tmp->[0] : $tmp ) ), '==', 1, "Known Finance Manager user does return TRUE" );

        # These test the 'get_file_paths' function which is used in the
        # 'Retail->Attribute Management' page and the 'Web Content' pages.
        # This function is used to get the end destination for SLUG images
        # amongst other things.
        note "Testing 'get_file_paths' function";
        # set-up what is being expected per channel
        # MRP paths haven't been decided yet so are undef
        # because they're not in the config.
        $expected   = {
                NAP => {
                    source_base             => $base_dir.'/root/static/',
                    destination_base        => '/opt/www/NetAPorter/',
                    slug_source             => 'images/slugs/NAP/',
                    slug_destination        => 'images/slugs/product_list/',
                    cms_source              => 'images/cms_content/NAP/',
                    feat_product_destination=> 'images/productCategoryPage/',
                },
                OUTNET  => {
                    source_base             => $base_dir.'/root/static/',
                    destination_base        => '/opt/www/OutNet/',
                    slug_source             => 'images/slugs/OUTNET/',
                    slug_destination        => 'outnet/images/slugs/',
                    cms_source              => 'images/cms_content/OUTNET/',
                    feat_product_destination=> 'images/productCategoryPage/',
                },
                MRP  => {
                    source_base             => $base_dir.'/root/static/',
                    destination_base        => '/opt/www/mrp/',
                    slug_source             => 'images/slugs/MRP/',
                    slug_destination        => 'images/slugs/',
                    cms_source              => 'images/cms_content/MRP/',
                    feat_product_destination=> 'images/productCategoryPage/',
                },
                JC => {
                    source_base             => undef,
                    destination_base        => undef,
                    slug_source             => undef,
                    slug_destination        => undef,
                    cms_source              => undef,
                    feat_product_destination=> undef,
                },
            };
        foreach ( sort { $a <=> $b } keys %{ $channels } ) {
            my $conf_sect   = $channels->{$_}{config_section};
            $tmp    = get_file_paths( $conf_sect );
            eq_or_diff( $tmp, $expected->{$conf_sect}, "$conf_sect file paths as expected" );
        }

        # These test the 'is_staff_order_premier_channel' function to make sure it
        # returns TRUE for 'OUTNET' as this is what is currently required for
        # staff orders.
        note "Testing 'is_staff_order_premier_channel' function";
        $expected   = {
                NAP     => 0,
                OUTNET  => 1,
                MRP     => 0,
            };
        foreach ( sort { $a <=> $b } keys %{ $channels } ) {
            my $conf_sect   = $channels->{$_}{config_section};
            next unless exists $expected->{ $conf_sect };
            $tmp    = is_staff_order_premier_channel( $conf_sect );
            cmp_ok( $tmp, '==', $expected->{$conf_sect}, "$conf_sect result as expected" );
        }
    }
}

sub _test_default_carrier {

    # ($distribution_centre eq "DC1")
    my $dc_expected = {
        DC1 => "DHL Express",
        DC2 => "DHL Express",
        DC3 => "DHL Express",
    };
    my $expected = $dc_expected->{$distribution_centre} or die("No config found, new DC?");

    is(default_carrier(0), $expected, "Not ground, correct carrier");
    is(default_carrier(1), $expected, "Ground, correct carrier");
}

# tests that the '<OrderNumber_RegEx>' section is correct
sub _test_order_number_regex {
    my $oktodo = shift;

    SKIP: {
        skip "_test_order_number_regex", 1           if ( !$oktodo );

        note "TESTING '<OrderNumber_RegEx>' config group";

        my %expect = (
            DC1 => {
                settings => {
                    regex => [
                        'JC[A-Z]+\d+',
                        '\d+',
                    ],
                    legacy_regex => [ '\d+-\d+' ],
                },
                order_nr_regex_function                  => '(?:JC[A-Z]+\d+|\d+)',
                order_nr_regex_including_legacy_function => '(?:(?:JC[A-Z]+\d+|\d+)|\d+-\d+)',
            },
            DC2 => {
                settings => {
                    regex => [
                        'JC[A-Z]+\d+',
                        '\d+',
                    ],
                    legacy_regex => [ '\d+-\d+' ],
                },
                order_nr_regex_function                  => '(?:JC[A-Z]+\d+|\d+)',
                order_nr_regex_including_legacy_function => '(?:(?:JC[A-Z]+\d+|\d+)|\d+-\d+)',
            },
            DC3 => {
                settings => {
                    regex => [
                        '\d+',
                    ],
                    legacy_regex => [ undef ],
                },
                order_nr_regex_function => '\d+',
                # for DC3 there is no Legacy RegExs so
                # it will just be the same as above
                order_nr_regex_including_legacy_function => '\d+',
            },
        );

        my $dc_expect = $expect{ $distribution_centre };
        if ( !$dc_expect ) {
            fail( "Couldn't find what to Expect for DC: '${distribution_centre}'" );
            return;
        }

        my $got = config_var( 'OrderNumber_RegEx', 'regex' );
        $got    = ( ref( $got ) ne 'ARRAY' ? [ $got ] : $got );
        cmp_deeply( $got, $dc_expect->{settings}{regex}, "Settings are as Expected" )
                                or diag "ERROR - Settings: Got: " . p( $got ) .
                                                   ", Expected: " . p( $dc_expect->{settings}{regex} );

        $got = config_var( 'OrderNumber_RegEx', 'legacy_regex' );
        $got = ( ref( $got ) ne 'ARRAY' ? [ $got ] : $got );
        cmp_deeply( $got, $dc_expect->{settings}{legacy_regex}, "Legacy Settings are as Expected" )
                                or diag "ERROR - Legacy Settings: Got: " . p( $got ) .
                                                          ", Expected: " . p( $dc_expect->{settings}{legacy_regex} );

        $got = order_nr_regex();
        is( $got, $dc_expect->{ order_nr_regex_function }, "'order_nr_regex' function returned as Expected" );
        lives_ok {
            my $tmp = "";
            $tmp =~ m/${got}/;
        } "Pattern can be turned into a RegEx correctly";

        $got = order_nr_regex_including_legacy();
        is( $got, $dc_expect->{ order_nr_regex_including_legacy_function },
                        "'order_nr_regex_including_legacy_function' function returned as Expected" );
        lives_ok {
            my $tmp = "";
            $tmp =~ m/${got}/;
        } "Including Legacy Pattern can be turned into a RegEx correctly";
    }
}

#--------------------------------------------------------------
