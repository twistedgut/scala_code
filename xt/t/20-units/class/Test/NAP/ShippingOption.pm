
package Test::NAP::ShippingOption;
use FindBin::libs;
use parent "NAP::Test::Class";

use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::More::Prefix qw/ test_prefix /;

use NAP::ShippingOption;
use XTracker::Config::Local qw( config_var );

sub new_fail : Tests() {
    dies_ok(
        sub { NAP::ShippingOption->new() },
        "Missing required params dies ok",
    );
}

sub new_from_query_hash : Tests() {
    my $self = shift;

    my $test_cases = [
        {
            setup => {
                shipping_account_name => "International",
                shipment_type         => "International",
                sub_region            => "Middle East",
            },
            expected => {
                code                         => intl_code(),
                label_count                  => 2,
            },
        },

        {
            setup => {
                shipping_account_name => "International",
                shipment_type         => "International",
                sub_region            => "Middle East",
                is_voucher_only       => 1,
            },
            expected => {
                code                         => vouchers_intl_code(),
                label_count                  => 2,
            },
        },
    ];

    if ( config_var( "DistributionCentre", "name" ) ne 'DC2' ) {
        push @$test_cases, (
        {
            setup => {
                shipping_account_name => "Domestic",
                shipment_type         => "Domestic",
                sub_region            => "EU Member States",
            },
            expected => {
                code                         => "DOM",
                label_count                  => 2,
            },
        },

        {
            setup => {
                shipping_account_name => "International Road",
                shipment_type         => "International",
                sub_region            => "Middle East",
            },
            expected => {
                code                         => iroad_intl_code(),
                label_count                  => 2,
            },
        },
        {
            setup => {
                shipping_account_name => "International Road",
                shipment_type         => "International",
                sub_region            => "Middle East",
                is_voucher_only       => 1,
            },
            expected => {
                code                         => iroad_intl_voucher_code(),
                label_count                  => 2,
            },
        },
    )};

    # Add in EU test cases if this is DC1
    if ( config_var( "DistributionCentre", "name" ) eq 'DC1' ) {
        push @$test_cases, (
            {
                setup => {
                    shipping_account_name => "International",
                    shipment_type         => "International",
                    sub_region            => "EU Member States",
                },
                expected => {
                    code                         => eu_code(),
                    label_count                  => 2,
                },
            },
            {
                setup => {
                    shipping_account_name => "International Road",
                    shipment_type         => "International",
                    sub_region            => "EU Member States",
                },
                expected => {
                    code                         => iroad_eu_code(),
                    label_count                  => 2,
                },
            }
        );
    }

    for my $case (@$test_cases) {
        $case->{setup}->{is_voucher_only} //= 0;
        my $shipping_option = NAP::ShippingOption->new_from_query_hash($case->{setup});
        isa_ok($shipping_option, "NAP::ShippingOption");
        for my $attribute (keys %{$case->{expected}}) {
            my $expected = $case->{expected}->{$attribute};
            is(
                $shipping_option->$attribute,
                $expected,
                "ShippingOption->$attribute is ($expected)"
            )
        }
    }
}

sub dhl_service_type : Tests() {
    my $self = shift;

    my $test_cases = [
        # International
        {
            setup    => { code => intl_code(), shipment_type => "International DDU" },
            expected => {
                dhl_service_type     => "",
            },
        },
        {
            setup    => { code => intl_code(), shipment_type => "International" },
            expected => {
                dhl_service_type     => service_type_duty_paid(),
            },
        },
        {
            setup    => { code => intl_code(), shipment_type => "International" },
            expected => {
                dhl_service_type     => service_type_duty_paid(),
            },
        },
    ];

    if ( config_var( "DistributionCentre", "name" ) ne 'DC2' ) {
        push @$test_cases, (
        # Domestic
        {
            setup    => { code => "DOM", shipment_type => "Domestic" },
            expected => {
                dhl_service_type     => "",
            },
        },

        # International
        {
            setup    => { code => intl_code(), shipment_type => "International DDU" },
            expected => {
                dhl_service_type     => "",
            },
        },
        {
            setup    => { code => intl_code(), shipment_type => "International" },
            expected => {
                dhl_service_type     => service_type_duty_paid(),
            },
        },
        {
            setup    => { code => intl_code(), shipment_type => "International" },
            expected => {
                dhl_service_type     => service_type_duty_paid(),
            },
        },

        # International Road
        {
            setup    => { code => iroad_intl_code(), shipment_type => "International DDU" },
            expected => {
                dhl_service_type     => "",
            },
        },
        {
            setup    => { code => iroad_intl_code(), shipment_type => "International" },
            expected => {
                dhl_service_type     => service_type_duty_paid(),
            },
        },
        {
            setup    => { code => iroad_intl_code(), shipment_type => "International" },
            expected => {
                dhl_service_type     => service_type_duty_paid(),
            },
        },
        );
    }

    # Add in EU test cases if this is DC1
    if ( config_var( "DistributionCentre", "name" ) eq 'DC1' ) {
        push @$test_cases, (
            # EU
            {
                setup    => { code => eu_code(), shipment_type => "International" },
                expected => {
                    dhl_service_type     => "",
                },
            },
            {
                setup    => { code => iroad_eu_code(), shipment_type => "International" },
                expected => {
                    dhl_service_type     => "",
                },
            },
        );
    }

    for my $is_voucher_only ( 0, 1 ) {
        test_prefix("is_voucher_only($is_voucher_only)");
        for my $case (@$test_cases) {
            my $shipping_option = NAP::ShippingOption->new_from_code({
                code => $case->{setup}->{code},
            });

            note("Service type");
            my $dhl_service_type = $shipping_option->dhl_service_type({
                shipment_type   => $case->{setup}->{shipment_type},
                is_voucher_only => $is_voucher_only,
            });
            my $expected_dhl_service_type = $case->{expected}->{dhl_service_type};
            if($expected_dhl_service_type) {
                $expected_dhl_service_type = vouchers_type() if($is_voucher_only);
            }
            is(
                $dhl_service_type,
                $expected_dhl_service_type,
                "Correct dhl_service_type is_voucher_only($is_voucher_only), ($case->{setup}->{code}), ($case->{setup}->{shipment_type}) = ($expected_dhl_service_type)",
            );

        }
    }
    test_prefix("");
}


# These subs return the correct DHL product type codes for the given generation of codes
sub vouchers_intl_code
    { config_var('DHL', 'use_2nd_gen_products') eq 'yes' ? 'BTC' : 'DOX' }

sub eu_code
    { config_var('DHL', 'use_2nd_gen_products') eq 'yes' ? 'WPX' : 'ECX' }

sub intl_code
    { 'WPX' }

sub iroad_eu_code
    { config_var('DHL', 'use_2nd_gen_products') eq 'yes' ? 'WPX' : 'ESU' }

sub iroad_intl_code
    { config_var('DHL', 'use_2nd_gen_products') eq 'yes' ? 'WPX' : 'ESI' }

sub iroad_intl_voucher_code
    { config_var('DHL', 'use_2nd_gen_products') eq 'yes' ? 'BTC' : 'ESI' }

# These subs return the correct DHL service type for the given generation of codes
sub service_type_duty_paid
    { 'DDP' }

sub vouchers_type
    { config_var('DHL', 'use_2nd_gen_products') eq 'yes' ? '' : 'DOX' }

1;
