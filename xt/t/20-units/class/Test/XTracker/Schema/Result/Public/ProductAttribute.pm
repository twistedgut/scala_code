package Test::XTracker::Schema::Result::Public::ProductAttribute;

use FindBin::libs;

use parent 'NAP::Test::Class';
use NAP::policy "tt", 'test';

use XTracker::Schema::Result::Public::ProductAttribute;
use XTracker::DBEncode qw/ encode_it /;
use XTracker::Database::Address;

use Test::XTracker::Data;

use DBI qw/ :utils /;

sub setup : Test(setup) {
    my $self = shift;

    # set this true if you want to keep the data around to play with...
    $self->{KEEP_DATA} = 0;

    # wrap tests in a transaction so we don't create loads of horrible addresses
    $self->schema->txn_begin unless $self->{KEEP_DATA};
}

sub teardown : Test(teardown) {
    my $self = shift;

    # wrap tests in a transaction so we don't create loads of horrible addresses
    $self->schema->txn_rollback unless $self->{KEEP_DATA};
}

sub test_unicode_fields : Tests {
    my $self = shift;

    my $address_rs = $self->schema->resultset('Public::ProductAttribute');

    my ( $product ) = Test::XTracker::Data->create_test_products();
    my $product_attributes = $product->product_attribute;

    # columns expected to support utf8
    my @utf8_columns = qw/
        name
        description
        long_description
        short_description
        editors_comments
    /;

    # strings to try in utf8 columns
    my $test_strings = {
        ascii => 'Test',
        utf8_latin1 => "T\N{U+00E9}st",
        utf8_cyrillic => "T\N{U+0511}st",
        utf8_arabic => "تجربة",
        utf8_chinese => "試驗",
        utf8_symbol => "T\N{U+20AC}st",
    };

    foreach my $test ( keys %$test_strings ) {

        my $update = {};
        map { $update->{$_} = $test_strings->{$test} } @utf8_columns;

        $product_attributes->update( $update );

        foreach my $column ( @utf8_columns ) {
            if ( $test eq 'ascii' ) {
                ok ( ! utf8::is_utf8( $product_attributes->$column ),
                    "ASCII $column does NOT have UTF-8 flag" );
            }
            else {
                ok ( utf8::is_utf8( $product_attributes->$column ),
                    "$column has UTF-8 flag turned on" );
            }
            is ( $product_attributes->$column, $test_strings->{$test},
                "and the value is the same as the test value ".encode_it($test_strings->{$test}) );
        }
    }
}

