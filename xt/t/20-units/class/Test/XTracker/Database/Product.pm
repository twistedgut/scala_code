package Test::XTracker::Database::Product;
use NAP::policy "tt", qw/test class/;

BEGIN {
    extends 'NAP::Test::Class';
};

use XTracker::Database::Product qw(validate_product_weight);

sub test__validate_product_weight :Tests {
    my ($self) = @_;

    ok(validate_product_weight( product_weight => 2.34 ),
        "Valid weight doesn't throw exception");
    ok(validate_product_weight( product_weight => 0.001 ),
        "Weight is allowed to go to 3 decimal places without rounding down");

    throws_ok { validate_product_weight() }
        qr/Product weight should be a positive number/, "No value throws correct exception";

    throws_ok { validate_product_weight( product_weight => -2.34 ) }
        qr/Product weight should be a positive number/, "Negative value throws correct exception";

    throws_ok { validate_product_weight( product_weight => 0 ) }
        qr/Product weight should be a positive number/, "Zero throws correct exception";

    throws_ok { validate_product_weight( product_weight => 'ab' ) }
        qr/Product weight should be a positive number/, "Non-numeric value throws correct exception";

    throws_ok { validate_product_weight( product_weight => 0.0001 ) }
        qr/should not equal or round to zero/, "Value that rounds to zero throws correct exception";
}
