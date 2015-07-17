package Test::XT::Rules::Type;

use strict;
use warnings;
use Moose::Util::TypeConstraints;

=pod

my $n = 'Test::XT::Rules::Type::';

# Define DBIC object class types, used for coercions
class_type $n . $_, { class => $_ } for map {
    "XTracker::Schema::Result::Public::$_"
} qw{Shipment Business Location Product};

=cut

enum 'Test::XT::Rules::Type::dc_name',
    [ qw( DC1 DC2 DC3 ) ];

subtype 'Test::XT::Rules::Type::schema',
    as 'XTracker::Schema';

subtype 'Test::XT::Rules::Type::shipment',
    as 'XTracker::Schema::Result::Public::Shipment';

subtype 'Test::XT::Rules::Type::validity',
    as 'Bool';

subtype 'Test::XT::Rules::Type::packing_location',
    as 'Str';

subtype 'Test::XT::Rules::Type::variant_id',
    as 'Int';

subtype 'Test::XT::Rules::Type::stock_status_type',
    as 'Int';

subtype 'Test::XT::Rules::Type::framework',
    as 'Test::XT::Flow';

subtype 'Test::XT::Rules::Type::mechanize',
    as 'Test::XTracker::Mechanize';

subtype 'Test::XT::Rules::Type::location',
    as 'XTracker::Schema::Result::Public::Location';

subtype 'Test::XT::Rules::Type::locations',
    as 'XTracker::Schema::ResultSet::Public::Location';

subtype 'Test::XT::Rules::Type::content',
    as 'Str';

subtype 'Test::XT::Rules::Type::packing_nav',
    as 'HashRef|Undef';

subtype 'Test::XT::Rules::Type::delivery_time',
    as 'Str';

subtype 'Test::XT::Rules::Type::restriction',
    as 'Str';

subtype 'Test::XT::Rules::Type::business_id',
    as 'Int';
1;
