#!/usr/bin/env perl

use NAP::policy "tt",     'test';

use Test::XTracker::Data;
use Test::XTracker::RunCondition export => [ qw( $distribution_centre ) ];

use XTracker::Config::Local;
use XTracker::Database::Currency;

my $schema  = Test::XTracker::Data->get_schema;


# expected currencies for each DC
my %expected_currencies = (
    DC1 => {
        default     => { code => 'GBP', glyph => '&pound;' },
        additional  => [
            { code => 'EUR', glyph => '&euro;' },
        ],
    },
    DC2 => {
        default     => { code => 'USD', glyph => '&#36;' },
        additional  => [],
    },
    DC3 => {
        default     => { code => 'HKD', glyph => 'HK&#36;' },
        additional  => [
            { code => 'USD', glyph => '&#36;' },
            { code => 'AUD', glyph => 'AU&#36;' },
        ],
    },
);
my $dc_currency = $expected_currencies{ $distribution_centre };

if ( !$dc_currency ) {
    fail( "No Expected Currencies have been configured in this test for DC: ${distribution_centre}" );
    done_testing;
    exit;
}

SKIP: {
    my $var = config_var('Currency', 'local_currency_code');
    ok(defined($var), "[Currency]/local_currency_code is defined") || skip('Failure of previous test means next tests are void', 1);
    is( $var, $dc_currency->{default}{code}, "and as expected for the DC" );

    ok(_is_valid_currency($schema, $var), "$var is a valid currency code in the database");
}

SKIP: {
    my $var = config_var('Currency', 'additional_currency');

    if ( $var && ref($var) ne 'ARRAY' ) {
        $var = [$var];
    }
    is_deeply(
        [ sort grep { $_ } @{ $var // [] } ],
        [ sort map { $_->{code} } @{ $dc_currency->{additional} } ],
        "Additional Currencies as expected"
    );

    skip('No need to test additional currencies, not present', 1) if (!defined($var));

    foreach my $ccy (@$var) {
        ok(_is_valid_currency($schema, $ccy), "$ccy is a valid currency code in the database");
    }
}

# test 'get_currencies_from_config' function to check
# it brings back all expected currencies for the DC
note "testing 'get_currencies_from_config' function";
my $currencies  = get_currencies_from_config( $schema );
my $local_curr  = shift @{ $currencies };       # first Currency should always be 'local_currency_code'
isa_ok( $local_curr, 'HASH', "Local currency found" );
is( $local_curr->{name}, $dc_currency->{default}{code}, "and is as expected: '" . $dc_currency->{default}{code} . "'" );
is( $local_curr->{html_entity}, $dc_currency->{default}{glyph}, "and has the expected Glyph: '" . $dc_currency->{default}{glyph} . "'" );
cmp_ok( $local_curr->{default}, '==', 1, "and IS flagged as the 'default'" );
is_deeply(
    [ sort map { $_->{name} } @{ $currencies } ],
    [ sort map { $_->{code} } @{ $dc_currency->{additional} } ],
    "Additional Currencies as expected"
);
is_deeply(
    { map { $_->{name} => $_->{html_entity} } @{ $currencies } },
    { map { $_->{code} => $_->{glyph} } @{ $dc_currency->{additional} } },
    "and Additional Currency Glyphs as expected"
);
is_deeply(
    { map { $_->{name} => $_->{default} } @{ $currencies } },
    { map { $_->{code} => 0 } @{ $dc_currency->{additional} } },
    "and Additional Currencies are NOT flagged as 'default'"
);


done_testing;


sub _is_valid_currency {
    my ($schema, $ccy) = @_;

    my $dbh = $schema->storage->dbh;

    my $rec;
    eval {
        my $id  = get_currency_id($dbh, $ccy);
        $rec    = $schema->resultset('Public::Currency')->find( $id );
    };
    if ( my $err = $@ ) {
        return 0;
    }

    my $valid       = 1;
    my $source_seas_conv= $schema->resultset('Public::SeasonConversionRate')
                                    ->search( { source_currency_id => $rec->id } );
    my $dest_seas_conv  = $schema->resultset('Public::SeasonConversionRate')
                                    ->search( { destination_currency_id => $rec->id } );

    # check various other things that should
    # be in place for a currency to be valid

    note "check for Currency Glyph";
    my $html_entity = $rec->get_glyph_html_entity;
    ok( $html_entity, "Found an HTML entity for the Currency Glyph: '${html_entity}'" );

    note "check for entries in 'sales_conversion_rate' table";

    my $count   = $rec->sales_conversion_rate_source_currencies
                        ->search( {
                            destination_currency => $rec->id,
                            conversion_rate => 1,
                            date_finish => undef,       # 'date_finish' being NULL means the rate is 'Active'
                        } )->count;
    cmp_ok( $count, '==', 1, "Record found in 'sales_conversion_rate' table to Convert to itself at a rate of 'x 1'" ) or $valid = 0;

    $count  = $rec->sales_conversion_rate_source_currencies
                        ->search( {
                            destination_currency => { '!=' => $rec->id },
                            date_finish => undef,       # 'date_finish' being NULL means the rate is 'Active'
                        } )->count;
    cmp_ok( $count, '>', 0, "Record(s) found in 'sales_conversion_rate' table to Convert to Other Currencies: ${count}" ) or $valid = 0;

    $count  = $rec->sales_conversion_rate_destination_currencies
                        ->search( {
                            source_currency => { '!=' => $rec->id },
                            date_finish => undef,       # 'date_finish' being NULL means the rate is 'Active'
                        } )->count;
    cmp_ok( $count, '>', 0, "Record(s) found in 'sales_conversion_rate' table to Convert from Other Currencies: ${count}" ) or $valid = 0;


    note "check for entries in 'season_conversion_rate' table should be for more than 1 season";

    $count  = $source_seas_conv->search( { destination_currency_id => $rec->id, conversion_rate => 1 } )->count;
    cmp_ok( $count, '>', 1, "Records found in 'season_conversion_rate' table to Convert to itself at a rate of 'x 1': ${count}" ) or $valid = 0;

    $count  = $source_seas_conv->search( { destination_currency_id => { '!=' => $rec->id } } )->count;
    cmp_ok( $count, '>', 1, "Records found in 'season_conversion_rate' table to Convert to Other Currencies: ${count}" ) or $valid = 0;

    $count  = $dest_seas_conv->search( { source_currency_id => { '!=' => $rec->id } } )->count;
    cmp_ok( $count, '>', 1, "Records found in 'season_conversion_rate' table to Convert from Other Currencies: ${count}" ) or $valid = 0;


    return $valid;
}
