#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;
use Test::XTracker::Data;
use Test::XTracker::ParamCheck;

use XTracker::Constants         qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB qw( :channel );
use XTracker::Database 'xtracker_schema';
use Test::XTracker::RunCondition dc => 'DC2';

BEGIN {
    use_ok('XTracker::Config::Local', qw( :carrier_automation config_var sys_config_var ));

    can_ok("XTracker::Config::Local", qw(
                            get_ups_qrt
                            get_ups_api_credentials
                            get_ups_api_url
                            get_ups_api_service_suffix
                            get_ups_max_wait_time
                            get_ups_services
                            get_ups_api_warning_failures
                            get_packing_stations
                            get_packing_station_printers
                        ) );
}

my $schema = xtracker_schema;
isa_ok($schema,"XTracker::Schema","Schema Connection");

my $dbh = $schema->storage->dbh;
isa_ok($dbh,"DBI::db","DBH Connection");

#---- Test Functions ------------------------------------------

_test_reqd_params($dbh,$schema,1);
_test_ups_config_funcs($dbh,$schema,1);

#--------------------------------------------------------------


done_testing();

#---- TEST FUNCTIONS ------------------------------------------

# Test that the functions are checking for required parameters
sub _test_reqd_params {
    my $dbh     = shift;
    my $schema  = shift;
    my $cursors = _define_dbh_cursors($dbh);

    my $channels    = $cursors->{channel_conf_sections}();
    my $param_check = Test::XTracker::ParamCheck->new();

    SKIP: {
        skip "_test_reqd_params",1           if (!shift);

        note "Testing for Required Parameters";

        $param_check->check_for_params(  \&get_ups_qrt,
                            'get_ups_qrt',
                            [ $channels->[0] ],
                            [ "No Sales Channel Config Section Passed" ],
                        );
        $param_check->check_for_params(  \&get_ups_api_credentials,
                            'get_ups_api_credentials',
                            [ $channels->[0] ],
                            [ "No Sales Channel Config Section Passed" ],
                        );
        $param_check->check_for_params(  \&get_ups_api_url,
                            'get_ups_api_url',
                            [ $channels->[0] ],
                            [ "No Sales Channel Config Section Passed" ],
                        );
        $param_check->check_for_params(  \&get_ups_api_service_suffix,
                            'get_ups_api_service_suffix',
                            [ "av", $channels->[0] ],
                            [ "No Service Passed", "No Sales Channel Config Section Passed" ],
                        );
        $param_check->check_for_params(  \&get_ups_max_wait_time,
                            'get_ups_max_wait_time',
                            [ $channels->[0] ],
                            [ "No Sales Channel Config Section Passed" ],
                        );
        $param_check->check_for_params(  \&get_ups_services,
                            'get_ups_services',
                            [ 'air', $channels->[0] ],
                            [ "No UPS Shipment Service Passed", "No Sales Channel Config Section Passed" ],
                        );
        $param_check->check_for_params(  \&get_ups_api_warning_failures,
                            'get_ups_api_warning_failures',
                            [ $channels->[0] ],
                            [ "No Sales Channel Config Section Passed" ],
                        );
        $param_check->check_for_params(  \&get_packing_stations,
                            'get_packing_stations',
                            [ $schema, 1 ],
                            [ "No Schema Connection Passed", "No Sales Channel Id Passed" ],
                            [ undef, 0 ],
                            [ undef, "No Sales Channel Id Passed" ]
                        );
        $param_check->check_for_params(  \&get_packing_station_printers,
                            'get_packing_station_printers',
                            [ $schema, "Packing Station" ],
                            [ "No Schema Connection Passed", "No Packing Station Passed" ]
                        );
    }
}

# This tests the functions used to get the UPS Config Settings
sub _test_ups_config_funcs {

    my $dbh     = shift;
    my $schema  = shift;

    my $cursors     = _define_dbh_cursors($dbh);

    my $channels    = $cursors->{channel_conf_sections}();
    my $chan_ids    = $cursors->{channel_ids}();
    my $tmp;

    SKIP: {
        skip "_test_ups_config_funcs",1           if (!shift);

        note "Testing UPS Config Functions";

        foreach my $channel ( @{ $channels } ) {
            $tmp    = get_ups_qrt( $channel );
            isnt($tmp,"","UPS QRT for $channel: Is NOT Empty - $tmp");
            like($tmp,qr/^\d+(\.\d+)?$/,"UPS QRT for $channel: Is a Number");

            $tmp    = get_ups_api_credentials( $channel );
            isnt($tmp->{$_},"","UPS API Credentials for $channel: $_ Is NOT Empty - ".$tmp->{$_})
                for qw( user_name password xml_access_key );

            $tmp    = get_ups_api_url( $channel );
            isnt($tmp,"","UPS API Base URL for $channel: Is NOT Empty - $tmp");

            $tmp    = get_ups_api_service_suffix( 'av', $channel );
            like($tmp,qr{^/\w},"UPS API Service Suffix for $channel: 'av' Is NOT Empty & Has Preceding '/' - $tmp");
            $tmp    = get_ups_api_service_suffix( 'shipconfirm', $channel );
            like($tmp,qr{^/\w},"UPS API Service Suffix for $channel: 'shipconfirm' Is NOT Empty & Has Preceding '/' - $tmp");
            $tmp    = get_ups_api_service_suffix( 'shipaccept', $channel );
            like($tmp,qr{^/\w},"UPS API Service Suffix for $channel: 'shipaccept' Is NOT Empty & Has Preceding '/' - $tmp");

            $tmp    = get_ups_max_wait_time( $channel );
            like($tmp->{$_},qr/^\d+(\.\d+)?$/,"UPS Max Wait Time for $channel: $_ Is NOT Empty & a Number - ".$tmp->{$_})
                for qw( max_wait max_retries );

            SKIP: {
                # tests no longer required as they are done as part of the NAP::Carrier tests
                skip "tests no longer required to be done here",0;
                foreach my $shipment_service ( qw( air ground ) ) {
                    $tmp    = get_ups_services( $shipment_service, $channel );
                    isa_ok($tmp,"ARRAY","UPS Shipment Services for $channel: $shipment_service");
                    cmp_ok( @{ $tmp }, ">", 0,"UPS Shipment Services for $channel: $shipment_service Is Not Empty");
                    foreach ( @{ $tmp } ) {
                        like($_->{code},qr/^\d\d$/,"UPS Shipment Services for $channel: $shipment_service Code is NOT Empty & 2 Digit Number - ".$_->{code});
                        isnt($_->{description},"","UPS Shipment Services for $channel: $shipment_service Description is NOT Empty - ".$_->{description});
                    }
                }
            }

            my $tmp = get_ups_api_warning_failures( $channel );
            isa_ok($tmp,"ARRAY","UPS API Warning Failures for $channel: ".@{ $tmp }." warnings");

            foreach my $ch_id ( @{ $chan_ids } ) {
                $tmp    = get_packing_stations( $schema, $ch_id );
                isa_ok($tmp,"ARRAY","Packing Station List Exist for Channel: ".$ch_id);

                foreach ( @{ $tmp } ) {
                    my $printer;

                    my $printers    = get_packing_station_printers( $schema, $_ );
                    isa_ok($printers,"HASH","Got Packing Station Printers for $_ on Channel $ch_id");

                    # check printers are the right ones in the conf settings table
                    $printer = sys_config_var( $schema, $_, 'doc_printer' );
                    is($printer,$printers->{document},"Packing Station $_ for Channel $ch_id has correct document printer: ".$printers->{document});
                    $printer = sys_config_var( $schema, $_, 'lab_printer' );
                    is($printer,$printers->{label},"Packing Station $_ for Channel $ch_id has correct label printer: ".$printers->{label});
                }
            }
        }
    }
}

#--------------------------------------------------------------

# defines a set of commands to be used by a DBI connection
sub _define_dbh_cursors {

    my $dbh     = shift;

    my $cursors = {};
    my $sql     = "";

    $cursors->{channel_conf_sections}  = sub {
            my $sections;
            my $sql =<<SQL
SELECT  b.config_section
FROM    channel ch
        JOIN business b ON b.id = ch.business_id
                           AND b.config_section != 'MRP'
ORDER BY b.config_section
SQL
;
            my $sth = $dbh->prepare($sql);
            $sth->execute();
            while ( my $row = $sth->fetchrow_hashref() ) {
                push @{ $sections },$row->{config_section}
            }
            return $sections;
        };

    $cursors->{channel_ids}  = sub {
            my $channels;
            my $sql =<<SQL
SELECT  ch.id
FROM    channel ch
        JOIN business b ON b.id = ch.business_id
                           AND b.config_section != 'MRP'
ORDER BY ch.id
SQL
;
            my $sth = $dbh->prepare($sql);
            $sth->execute();
            while ( my $row = $sth->fetchrow_hashref() ) {
                push @{ $channels },$row->{id}
            }
            return $channels;
        };

    return $cursors;
}
