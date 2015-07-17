
package Test::XT::Data::Types;
use FindBin::libs;
use parent "NAP::Test::Class";

use NAP::policy "tt", 'test';

# Needs to be in a CHECK block to put it before Test::Class INIT which
# kicks off the testing
CHECK {
package Test::HasTypes; ## no critic(ProhibitMultiplePackages)
use Moose;
use XT::Data::Types qw/
    TimeStamp
    DateStamp
    Currency
    PosInt
    RemunerationType
    FromJSON
/;

has date => (
    is     => "rw",
    isa    => 'XT::Data::Types::DateStamp | Undef',
    coerce => 1,
);

has currency => (
    is     => 'rw',
    isa    => 'XT::Data::Types::Currency',
);

has pos_int => (
    is     => 'rw',
    isa    => 'XT::Data::Types::PosInt',
);

has remuneration_type => (
    is     => 'rw',
    isa    => 'XT::Data::Types::RemunerationType',
);

has json => (
    is     => 'rw',
    isa    => 'XT::Data::Types::FromJSON',
    coerce => 1,
);

}

package Test::XT::Data::Types; ## no critic(ProhibitMultiplePackages)

use Test::Exception;
use Test::More::Prefix qw/ test_prefix /;
use JSON;

use XT::Data::Types qw/
    TimeStamp
    DateStamp
    Currency
    PosInt
    RemunerationType
    FromJSON
/;

sub DateStamp_coerce_from_Str : Tests() {
    my $self = shift;

    throws_ok(
        sub { Test::HasTypes->new({ date => "Invalidz" }) },
        qr|^\(Invalidz\) can't be parsed|,
        "Invalid date fails ok",
    );
    throws_ok(
        sub { Test::HasTypes->new({ date => "2011-04-21 15:00" }) },
        qr|^\(2011-04-21 15:00\) can't be parsed|,
        "Invalid date/time fails ok",
    );

    $self->test_coerce(
        "Regular date parses ok",
        "2011-04-21",
        "2011-04-21",
    );

    $self->test_coerce(
        "Zulu date/time parses ok",
        "2011-04-21T00:00:00.000Z",
        "2011-04-21",
    );

}

sub DateStamp_coerce_from_DateTime : Tests() {
    my $self = shift;

    $self->test_coerce(
        "DateTime coerces ok",
        DateTime->new(year => 1999, month => 8, day => 7, hour => 6),
        "1999-08-07",
    );
}

sub DateStamp_timezone : Tests() {
    my $has_types = Test::HasTypes->new({ date => "2011-11-13" });
    is($has_types->date->offset, 0, "No TZ offset");
}

sub test_PosInt : Tests() {

    my $has_types = Test::HasTypes->new( { pos_int => 1 } );
    is( $has_types->pos_int, 1, "Positive integer parses correctly" );

    throws_ok(
        sub { Test::HasTypes->new( { pos_int => -1 } ) },
        qr/Int is not larger than 0/,
        'Negative integer fails as expected'
    );

}

sub test_RemunerationType : Tests() {

    my @types = ( 'Store Credit', 'Voucher Credit', 'Card Debit', 'Card Refund' );

    foreach my $type ( @types ) {

        my $has_types = Test::HasTypes->new( { remuneration_type => $type } );
        is( $has_types->remuneration_type, $type, "RemunerationType '$type' parses correctly" );

    }

    my $error = 'Must be one of '
        . join( ', ', @types[ 0 .. ( $#types - 1 ) ] )
        . ' or '
        . $types[ -1 ];

    throws_ok(
        sub { Test::HasTypes->new( { remuneration_type => 'Not Valid' } ) },
        qr/$error/,
        'RemunerationType fails as expected'
    );

}

sub test_Currency : Tests() {

    my @currencies = qw( USD GBP EUR AUD JPY HKD CNY KRW );

    foreach my $currency ( @currencies ) {

        my $has_types = Test::HasTypes->new( { currency => $currency } );
        is( $has_types->currency, $currency, "Currency $currency parses correctly" );

    }

    my $error = 'Must be one of ' . join( ', ', @currencies );

    throws_ok(
        sub { Test::HasTypes->new( { currency => 'XXX' } ) },
        qr/$error/,
        'Currency fails as expected'
    );

}

sub test_FromJSON : Tests() {

    my $valid_json = {
        key1 => 'value1',
        key2 => 1,
        key3 => undef,
        key4 => [ 'value2', 'value3' ],
    };

    my $has_types = Test::HasTypes->new( { json => JSON->new->encode( $valid_json ) } );
    is_deeply( $has_types->json, $valid_json, 'Valid JSON parses as expected' );

    throws_ok(
        sub{ Test::HasTypes->new( { json => '!!INVALID JSON!!' } ) },
        qr/malformed JSON string/,
        'Invalid JSON fails as expected'
    );

}

sub test_coerce {
    my ($self, $description, $date_input, $expected_string, ) = @_;

    my $has_types = Test::HasTypes->new({ date => $date_input });
    is( $has_types->date . "", $expected_string, $description);
}

1;
