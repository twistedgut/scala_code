package Test::XTracker::CSV::Importer::LatePostcodes;
use NAP::policy qw/test class/;

BEGIN { extends "NAP::Test::Class" };

use Test::XTracker::Data::Shipping;
use XTracker::CSV::Importer::LatePostcodes;

sub test__import_to_database :Tests {
    my ($self) = @_;

    # Tests assume a test shipping sku: '123456-789'
    my $schema = $self->schema();
    my $test_sku = $schema->resultset('Public::ShippingCharge')->find({
        sku => '123456-789',
    }) // Test::XTracker::Data::Shipping->create_shipping_charge({
        sku => '123456-789',
    });

    my $test_shipping_charge_id = $test_sku->id();
    my $united_kingdom_id = $schema->resultset('Public::Country')->find({
        code => 'GB'
    })->id();

    my $united_states_id = $schema->resultset('Public::Country')->find({
        code => 'US'
    })->id();

    for my $test (
        {
            name    => 'Successful import from file without headers',
            setup   => {
                path_to_csv_file    => $ENV{XTDC_BASE_DIR} . '/t/data/csv_importer/late_postcodes/success_without_headers.csv',
                columns             => [qw/
                    country_code
                    shipping_sku
                    postcode
                /],
            },
            result  => {
                populate_data => [
                    {
                        shipping_charge_id  => $test_shipping_charge_id,
                        country_id          => $united_kingdom_id,
                        postcode            => 'sw24jn',
                    },
                    {
                        shipping_charge_id  => $test_shipping_charge_id,
                        country_id          => $united_states_id,
                        postcode            => 'dd34gh',
                    }
                ],
            },
        },
        {
            name    => 'Successful import from file with headers',
            setup   => {
                path_to_csv_file    => $ENV{XTDC_BASE_DIR} . '/t/data/csv_importer/late_postcodes/success_with_headers.csv',
            },
            result  => {
                populate_data => [
                    {
                        shipping_charge_id  => $test_shipping_charge_id,
                        country_id          => $united_kingdom_id,
                        postcode            => 'sw24jn',
                    },
                    {
                        shipping_charge_id  => $test_shipping_charge_id,
                        country_id          => $united_states_id,
                        postcode            => 'dd34gh',
                    }
                ],
            },
        },
        {
            name    => 'Import fails due to unknown country code',
            setup   => {
                path_to_csv_file    => $ENV{XTDC_BASE_DIR} . '/t/data/csv_importer/late_postcodes/bad_country.csv',
                columns             => [qw/
                    country_code
                    shipping_sku
                    postcode
                /],
            },
            result  => {
                error => qr/Could not find a country with code: WIBBLE/
            },
        },
        {
            name    => 'Import fails due to unknown shipping-sku',
            setup   => {
                path_to_csv_file    => $ENV{XTDC_BASE_DIR} . '/t/data/csv_importer/late_postcodes/bad_shipping_sku.csv',
                columns             => [qw/
                    country_code
                    shipping_sku
                    postcode
                /],
            },
            result  => {
                error => qr/Could not find a shipping_charge with sku: WIBBLE/
            },
        },
        {
            name    => 'Import fails due to missing required column',
            setup   => {
                path_to_csv_file    => $ENV{XTDC_BASE_DIR} . '/t/data/csv_importer/late_postcodes/success_without_headers.csv',
                columns             => [qw/
                    country_code
                    shipping_sku
                /],
            },
            result  => {
                error => qr/Required column missing: postcode/
            },
        }
    ) {
        subtest $test->{name} => sub {
            my $importer = XTracker::CSV::Importer::LatePostcodes->new();

            my $late_postcodes_before = $schema->resultset('Public::ShippingChargeLatePostcode')->count();

            open(my $file_handle, "<:encoding(utf8)", $test->{setup}->{path_to_csv_file} )
                || die 'Couldn\'t open file for reading: ' . $test->{setup}->{path_to_csv_file};

            if ($test->{result}->{error}) {
                throws_ok {
                    $importer->import_to_database({
                        file_handle => $file_handle,
                        ( exists($test->{setup}->{columns})
                            ? ( columns => $test->{setup}->{columns} )
                            : ()
                        ),
                    });
                } $test->{result}->{error}, 'import died with expected error';
                return;
            }

            $importer->import_to_database({
                file_handle => $file_handle,
                ( exists($test->{setup}->{columns})
                    ? ( columns => $test->{setup}->{columns} )
                    : ()
                ),
            });
            $file_handle->close();

            eq_or_diff($importer->populate_data(), $test->{result}->{populate_data},
                'Data gathered from CSV file as expected');

            my $late_postcodes_after = $schema->resultset('Public::ShippingChargeLatePostcode')->count();

            is($late_postcodes_after, $late_postcodes_before + @{$test->{result}->{populate_data}},
               'Correct number of new rows in db');
        };
    }
}
