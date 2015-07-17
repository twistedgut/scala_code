package XT::Data::Types;
use strict;
use warnings;

=head1 NAME

XT::Data::Types

=head1 DESCRIPTION

A set of common data types.

=cut

use MooseX::Types
    -declare => [ qw(
        Currency
        DatabaseInt
        DateStamp
        ExpiryDate
        FromJSON
        PosInt
        PositiveDatabaseInt
        PosNum
        RemunerationType
        ResourceBool
        RTVDocumentType
        RecodeRow
        RemunerationType
        ResourceBool
        ShipmentRow
        ShipmentItemRow
        ShipmentStatusId
        SKU
        TimeStamp
        URN
    ) ];

use MooseX::Types::Moose qw(
    Bool
    HashRef
    Int
    Num
    Str
);

use Moose::Util::TypeConstraints;

use Time::ParseDate;
use DateTime;
use JSON;

use XT::Data::DateStamp;
use XT::Data::URI;

use XTracker::Constants ':database';
use XTracker::Constants::Regex ':sku';
use XTracker::Database 'xtracker_schema';

use XTracker::Constants::FromDB qw/ :shipment_status /;

=head1 DATA TYPES

=head2 Class Types

=over

=item XT::Data::Address

=item XT::Data::CustomerName

=item XT::Data::Money

=item XT::Data::Telephone

=item XT::Data::Order::LineItem

=item XT::Data::Order::CostReduction

=item XT::Data::Order::Tender

=item XTracker::Schema

=item DBIx::Class::Schema

=item JSON::XS::Boolean

=item XT::DC::Messaging::Model::Schema

=back

=cut

class_type 'XT::Data::Address';
class_type 'XT::Data::CustomerName';
class_type 'XT::Data::Money';
class_type 'XT::Data::Telephone';
class_type 'XT::Data::Order::LineItem';
class_type 'XT::Data::Order::CostReduction';
class_type 'XT::Data::Order::Tender';
class_type 'XTracker::Schema';
class_type 'DBIx::Class::Schema';
class_type 'JSON::XS::Boolean';
class_type 'XT::DC::Messaging::Model::Schema';

=head2 ShipmentRow

=cut

class_type ShipmentRow, { class => 'XTracker::Schema::Result::Public::Shipment' };
coerce ShipmentRow,
    from Int,
    via { xtracker_schema->resultset('Public::Shipment')->find($_) };

=head2 ShipmentItemRow

=cut

class_type ShipmentItemRow, { class => 'XTracker::Schema::Result::Public::ShipmentItem' };
coerce ShipmentItemRow,
    from Int,
    via { xtracker_schema->resultset('Public::ShipmentItem')->find($_) };

=head2 RecodeRow

=cut

class_type RecodeRow, { class => 'XTracker::Schema::Result::Public::StockRecode' };
coerce RecodeRow,
    from Int,
    via { xtracker_schema->resultset('Public::StockRecode')->find($_) };


=head2 PosInt

Integers greater than ZERO.

=cut

subtype PosInt,
    as Int,
    where { $_ > 0 },
    message { 'Int is not larger than 0' };

=head2 PosNum

Numbers greater than 0.

=cut

subtype PosNum,
    as Num,
    where { $_ > 0 },
    message { 'Num is not larger than 0' };;

=head2 RemunerationType

String enumeration that must be one of:

    Store Credit
    Voucher Credit
    Card Debit
    Card Refund

=cut

# These are the types in XT
subtype RemunerationType,
    as Str,
    where { /^(Store Credit|Voucher Credit|Card Debit|Card Refund)$/ },
    message { 'Must be one of Store Credit, Voucher Credit, Card Debit or Card Refund' };

=head2 Currency

Curreny name enumeration that must be one of the following:

    USD
    GBP
    EUR
    AUD
    JPY
    HKD
    CNY
    KRW

=cut

subtype Currency,
    as Str,
    where { /^(USD|GBP|EUR|AUD|JPY|HKD|CNY|KRW)$/i },
    message { 'Must be one of USD, GBP, EUR, AUD, JPY, HKD, CNY, KRW' };

=head2 TimeStamp

A L<DateTime> object that will coerce from a C<Str> (string) using the
L<Time::ParseDate> C<parsedate> method.

=cut

subtype TimeStamp, as class_type('DateTime');

coerce TimeStamp,
    from Str,
    via {
        my $epoch = parsedate($_);
        die "Unable to parse supposedly datetime - ($_)" unless $epoch;
        my $dt = DateTime->from_epoch( epoch => scalar $epoch);
        # this was in when we were passing strings rather than a DateTime with
        # timezone set
        #$dt->set_time_zone('Europe/London');
        return $dt;
    };

=head2 DateStamp

A L<DateTime> object that will coerce from one of the following:

C<Str> (string)
    Using L<XT::Data::DateStamp> C<from_string>.

L<DateTime>
    Using L<XT::Data::DateStamp> C<from_datetime>.

=cut

# This can't use the same coercion as a Timestamp, because the
# TimeStamp parses into the localtime TZ, and the time part of the
# datetime needs to stay at 00:00:00, so it needs GMT/UTC to be
# stable.

subtype DateStamp, as class_type("XT::Data::DateStamp");
coerce DateStamp,
    from Str,
    via { return XT::Data::DateStamp->from_string($_) };

coerce DateStamp,
    from "DateTime",
    via { return XT::Data::DateStamp->from_datetime($_) };


=head2 FromJSON

A HashRef that will be coerced from a <CStr> (string) using the
L<JSON> method C<decode>.

=cut

subtype FromJSON,
    as HashRef;

coerce FromJSON,
    from Str,
    via { return JSON->new->decode($_) };

=head2 URN

An L<XT::Data::URI> object that will be coerced from a C<Str>
(string) by instantiating a new L<XT::Data::URI> object.

=cut

subtype URN, as class_type("XT::Data::URI");
coerce URN,
  from Str,
  via { XT::Data::URI->new( $_, 'urn' ) };

=head2 ResourceBool

A C<Bool> (boolean) that can be coerced from a L<JSON::XS::Boolean>
object.

=cut

subtype ResourceBool, as Bool;
coerce ResourceBool,
  from 'JSON::XS::Boolean',
  via { $_ ? 1 : 0 };

subtype DatabaseInt,
    as Int,
    where { $_ >= $PG_MIN_INT && $_ <= $PG_MAX_INT },
    message { "DatabaseInt must range between $PG_MIN_INT and $PG_MAX_INT" };

subtype PositiveDatabaseInt,
    as Int,
    where { $_ > 0 && $_ <= $PG_MAX_INT },
    message { "PositiveDatabaseInt must range between 1 and $PG_MAX_INT" };

=head2 ExpiryDate

String in the format MM/YY, where MM must be a an integer in the range
1 to 12 and YY must be a two digit integer greater than 1.

Both MM and YY can be either one or two digits.

=cut

subtype ExpiryDate,
    as Str,
    where   {
        if ( /^(?<month>\d\d?)\/(?<year>\d\d?)$/ ) {
        # If the string looks like a date in the format MM/YY.
            if ( $+{month} >= 1 && $+{month} <= 12 && $+{year} >= 1 ) {
            # If the Month is in the range 1 to 12 and the year
            # is greater than 1.
                return 1;
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    },
    message { 'Must be in the format MM/YY' };

subtype SKU,
    as Str,
    where { $_ =~ $SKU_REGEX },
    message { "Not a valid SKU" };

subtype ShipmentStatusId,
    as Int,
    where {
        my $value = $_;
        grep {
            $_ == $value
        } @SHIPMENT_STATUS_VALUES;
    },
    message { "Not a valid shipment-status-id" };

=head2 RTVDocumentType

For validating against the set of document types accepted by RTV stock sheets

=cut

subtype RTVDocumentType,
    as enum([ qw\ main dead rtv \ ]),
    message { "Invalid RTV document type" };

1;
