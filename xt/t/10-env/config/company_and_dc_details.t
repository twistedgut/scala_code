#!/usr/bin/env perl

use NAP::policy "tt",         'test';

=head2

This tests the Company Addresses for each Sales Channel and also some Distribution Centre config options.

=cut

use Test::XTracker::LoadTestConfig;
use Test::XTracker::RunCondition export => [ qw( $distribution_centre ) ];

use_ok( 'XTracker::Config::Local', qw(
                                        config_var
                                        comp_addr
                                        return_addr
                                        return_postcode
                                        comp_tel
                                        comp_freephone
                                        comp_fax
                                        comp_contact_hours
                                        return_export_reason_prefix
                                        post_code_label
                                    ) );


# expected in the 'DistributionCentre' config section per DC
my %expected_dc_details = (
    DC1 => {
        return_export_reason_prefix => 'British',
        post_code_label             => 'POST CODE',
    },
    DC2 => {
        return_export_reason_prefix => 'USA',
        post_code_label             => 'ZIP CODE',
    },
    DC3 => {
        return_export_reason_prefix => 'Hong Kong',
        post_code_label             => 'POST CODE',
    },
);

# list of functions used to get the values for the 'expected_company_details'
# hash, each one will be passed the Channel Config Section. If a method doesn't
# appear in the list below then it will use 'config_var' by default.
my %method_to_get_option= (
    addr            => \&comp_addr,
    return_addr     => \&return_addr,
    return_postcode => \&return_postcode,
    tel             => \&comp_tel,
    freephone       => \&comp_freephone,
    fax             => \&comp_fax,
    contact_hours   => \&comp_contact_hours,
);
# expected in the 'Company_[CHANNEL]' config section per DC per Sales Channel
my %expected_company_details = (
    DC1 => {
        NAP     => {
            addr            => '1 THE VILLAGE OFFICES, WESTFIELD LONDON SHOPPING CENTRE, ARIEL WAY, LONDON, W12 7GF',
            return_addr     => 'UNIT 3, CHARLTON GATE BUSINESS PARK<br>ANCHOR AND HOPE LANE, CHARLTON<br>LONDON<br>UNITED KINGDOM',
            return_postcode => 'SE7 7RU',
            tel             => '+44 (0) 20 3471 4510',
            freephone       => '0800 044 5700',
            fax             => '+44 (0) 20 3471 4599',
            contact_hours   => '24 hours a day, seven days a week',
            ca_tel          => '+44 (0) 20 3471 4510',
            premier_tel     => '0800 044 5703',
            premier_contact_hours   => '8am-9pm weekdays, 9am-5pm weekends',
        },
        OUTNET  => {
            addr            => '1 THE VILLAGE OFFICES, WESTFIELD LONDON SHOPPING CENTRE, ARIEL WAY, LONDON, W12 7GF',
            return_addr     => 'UNIT 4, OLD PARKBURY LANE<br>COLNEY STREET, ST ALBANS<br>HERTFORDSHIRE<br>UNITED KINGDOM',
            return_postcode => 'AL2 2DZ',
            tel             => '+44 (0) 20 3471 4777',
            freephone       => '0800 011 4250',
            fax             => '+44 (0) 20 3471 4599',
            contact_hours   => '24 hours a day, seven days a week',
            ca_tel          => '+44 (0) 20 3471 4777',
            premier_tel     => '0800 044 5710',
            premier_contact_hours   => '8am-9pm weekdays, 9am-5pm weekends',
        },
        MRP     => {
            addr            => '1 THE VILLAGE OFFICES, WESTFIELD LONDON SHOPPING CENTRE, ARIEL WAY, LONDON, W12 7GF',
            return_addr     => 'UNIT 3, CHARLTON GATE BUSINESS PARK<br>ANCHOR AND HOPE LANE, CHARLTON<br>LONDON<br>UNITED KINGDOM',
            return_postcode => 'SE7 7RU',
            tel             => '+44 (0) 20 3471 4090',
            freephone       => '0800 044 5705',
            fax             => '+44 (0) 20 3471 4599',
            contact_hours   => '24 hours a day, seven days a week',
            ca_tel          => '+44 (0) 20 3471 4090',
            premier_tel     => '0800 044 5708',
            premier_contact_hours   => '8am-9pm weekdays, 9am-5pm weekends',
        },
        JC      => {
            addr            => 'J. Choo (OS) Limited, 10 Howick Place, London, SW1P 1GW United Kingdom',
            return_addr     => 'UNIT 3, CHARLTON GATE BUSINESS PARK<br>ANCHOR AND HOPE LANE, CHARLTON<br>LONDON<br>UNITED KINGDOM',
            return_postcode => 'SE7 7RU',
            tel             => '+44 (0)20 3471 4799',
            freephone       => '0800 044 3221',
            fax             => '+44 (0) 20 3471 4599',
            contact_hours   => '24 hours a day, seven days a week',
            ca_tel          => '+44 (0)20 3471 4799',
            premier_tel     => undef,
            premier_contact_hours   => undef,
        },
    },
    DC2 => {
        NAP     => {
            addr            => '725 Darlington Avenue, Mahwah, NJ 07430',
            return_addr     => '725 Darlington Avenue<br>Mahwah<br>NJ<br>USA',
            return_postcode => '07430',
            tel             => '1 877 6789 NAP (627)',
            freephone       => 'NO_SEPARATE_FREEPHONE',
            fax             => '1-347-448-8069',
            contact_hours   => '24 hours a day, seven days a week',
            ca_tel          => '1-877-678-9627',
            premier_tel     => '1 877 5060 NYP (697)',
            premier_contact_hours   => '8.30am-8pm weekdays, 9am-5.30pm weekends',
        },
        OUTNET  => {
            addr            => '725 Darlington Avenue, Mahwah, NJ 07430',
            return_addr     => '725 Darlington Avenue<br>Mahwah<br>NJ<br>USA',
            return_postcode => '07430',
            tel             => '1 888 9 OUTNET (688638)',
            freephone       => 'NO_SEPARATE_FREEPHONE',
            fax             => '1-347-448-8069',
            contact_hours   => '24 hours a day, seven days a week',
            ca_tel          => '1-888-968-8638',
            premier_tel     => '1 855 688 7736',
            premier_contact_hours   => '8.30am-8pm weekdays, 9am-5.30pm weekends',
        },
        MRP     => {
            addr            => 'Mr Porter, 725 Darlington Avenue, Mahwah, NJ 07430',
            return_addr     => '725 Darlington Avenue<br>Mahwah<br>NJ<br>USA',
            return_postcode => '07430',
            tel             => '1-877-5353-MRP (677)',
            freephone       => 'NO_SEPARATE_FREEPHONE',
            fax             => '1-347-448-8069',
            contact_hours   => '24 hours a day, seven days a week',
            ca_tel          => '1-877-535-3677',
            premier_tel     => '1 877 93 NY MRP (69677)',
            premier_contact_hours   => '8.30am-8pm weekdays, 9am-5.30pm weekends',
        },
        JC      => {
            addr            => 'J. Choo (OS) Limited, 10 Howick Place, London, SW1P 1GW United Kingdom',
            return_addr     => '725 Darlington Avenue<br>Mahwah<br>NJ<br>USA',
            return_postcode => '07430',
            tel             => '1877 95 JCHOO (52466)',
            freephone       => 'NO_SEPARATE_FREEPHONE',
            fax             => '1-347-448-8069',
            contact_hours   => '24 hours a day, seven days a week',
            ca_tel          => '1877 955 2466',
            premier_tel     => undef,
            premier_contact_hours   => undef,
        },
    },
    DC3 => {
        NAP     => {
            addr            => 'Interlink Building, 10th floor, 35-47 Tsing Yi Road, Tsing Yi, New Territories, Hong Kong',
            return_addr     => 'Interlink Building<br>10th floor<br>35-47 Tsing Yi Road<br>Tsing Yi<br>New Territories<br>Hong Kong',
            return_postcode => '',
            tel             => '+44 (0) 330 022 5700',
            freephone       => 'NO_SEPARATE_FREEPHONE',
            contact_hours   => '24 hours a day, seven days a week',
            ca_tel          => '852 3108 6037',
            premier_tel     => '3018 6813',
            premier_contact_hours   => '9am-9pm weekdays, 9am-5.30pm weekends',
        },
        OUTNET  => {
            addr            => 'Interlink Building, 10th floor, 35-47 Tsing Yi Road, Tsing Yi, New Territories, Hong Kong',
            return_addr     => 'Interlink Building<br>10th floor<br>35-47 Tsing Yi Road<br>Tsing Yi<br>New Territories<br>Hong Kong',
            return_postcode => '',
            tel             => '+44 (0) 330 022 5700',
            freephone       => 'NO_SEPARATE_FREEPHONE',
            contact_hours   => '24 hours a day, seven days a week',
            ca_tel          => '852 3108 6037',
            premier_tel     => '+44 (0) 330 022 5700',
            premier_contact_hours   => '8.30am-8pm weekdays, 9am-5.30pm weekends',
        },
        MRP     => {
            addr            => 'Interlink Building, 10th floor, 35-47 Tsing Yi Road, Tsing Yi, New Territories, Hong Kong',
            return_addr     => 'Interlink Building<br>10th floor<br>35-47 Tsing Yi Road<br>Tsing Yi<br>New Territories<br>Hong Kong',
            return_postcode => '',
            tel             => '+44 (0) 330 022 5700',
            freephone       => 'NO_SEPARATE_FREEPHONE',
            contact_hours   => '24 hours a day, seven days a week',
            ca_tel          => '852 3108 6037',
            premier_tel     => '+44 (0) 330 022 5700',
            premier_contact_hours   => '8.30am-8pm weekdays, 9am-5.30pm weekends',
        },
        JC      => {
            addr            => 'J. Choo (OS) Limited, 10 Howick Place, London, SW1P 1GW United Kingdom',
            return_addr     => 'Interlink Building<br>10th floor<br>35-47 Tsing Yi Road<br>Tsing Yi<br>New Territories<br>Hong Kong',
            return_postcode => '',
            tel             => '1877 95 JCHOO (52466)',
            freephone       => 'NO_SEPARATE_FREEPHONE',
            fax             => '1-347-448-8069',
            contact_hours   => '24 hours a day, seven days a week',
            ca_tel          => '1877 955 2466',
            premier_tel     => undef,
            premier_contact_hours   => undef,
        },
    },
);

note "TESTING: 'DistributionCentre' Config Options";
my $to_expect   = $expected_company_details{ $distribution_centre }
                       || fail( "No tests for 'DistributionCentre' for DC: $distribution_centre" );

foreach my $config_to_test ( keys %{ $expected_dc_details{ $distribution_centre } } ) {
    my $expected= $expected_dc_details{ $distribution_centre }{ $config_to_test };
    my $got     = config_var( 'DistributionCentre', $config_to_test );
    is( $got, $expected, "for option '${config_to_test}' got expected value: '${expected}'" );
}


note "TESTING: 'Company_*' Config Options";

# get what to expect based on which DC we are in
$to_expect  = $expected_company_details{ $distribution_centre }
                   || fail( "No tests for 'Company_*' for DC: $distribution_centre" );

foreach my $conf_section ( sort keys %{ $to_expect } ) {
    note "Sales Channel Conf Section: $conf_section";
    my $expect  = $to_expect->{ $conf_section };

    my %got;
    foreach my $option ( keys %{ $expect } ) {
        my $method  = $method_to_get_option{ $option };
        $got{ $option } = (
                            $method
                            ? $method->( $conf_section )
                            : config_var( 'Company_' . $conf_section, $option )
                        );
    }

    is_deeply( \%got, $expect, "Got Expected Company Details" );
}

done_testing;

#--------------------------------------------------------------
