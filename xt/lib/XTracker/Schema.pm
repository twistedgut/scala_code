use utf8;
package XTracker::Schema;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces(
    default_resultset_class => "ResultSetBase",
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:OWfDaH+celV9LZOFl8mWTA

__PACKAGE__->load_components('Helper::Schema::DateTime');

# Create an accessor to store our opeator_id. This is useful so our schema can
# know who is performing the action without explicitly needing to always
# explicitly pass operator_id
# NOTE: This is set in the XT::DC::Model::DB and XTracker::Handler constructors
# - *IF* the constructors don't get called at every request we'll have problems
# setting the incorrect operator ids against this object, so be aware in that
# case we either want to remove this bit of code or alternatively make sure
# it's set properly at every request (i.e. in xt.psgi)
__PACKAGE__->mk_group_accessors(simple => 'operator_id');

use Carp;

use feature 'state';

{
my %map=(
    act => 'Public::SeasonAct',
    classification => 'Public::Classification',
    colour => 'Public::Colour',
    colour_filter => 'Public::ColourFilter',
    country => 'Public::Country',
    currency => 'Public::Currency',
    default_currency => ['Public::Currency','currency'],
    designer => 'Public::Designer',
    designer_size => ['Public::Size','size'],
    hs_code => 'Public::HSCode',
    division => 'Public::Division',
    dhl_delivery_file => 'Public::DHLDeliveryFile',
    landed_currency => ['Public::Currency','currency'],
    payment_deposit => ['Public::PaymentDeposit','deposit_percentage'],
    payment_settlement_discount => ['Public::PaymentSettlementDiscount','discount_percentage'],
    payment_term => 'Public::PaymentTerm',
    product_department => ['Public::ProductDepartment','department'],
    product_type => 'Public::ProductType',
    region => 'Public::Region',
    renumeration_type => 'Public::RenumerationType',
    season => 'Public::Season',
    shipment_window_type => ['Public::ShipmentWindowType', 'type'],
    size => 'Public::Size',
    size_scheme => ['Public::SizeScheme','name'],
    sub_type => 'Public::SubType',
    supplier => ['Public::Supplier','code'],
    wholesale_currency => ['Public::Currency','currency'],
    world => 'Public::World',
    stock_status => ['Flow::Status','name'],
);
sub _create_lookup_by_name_sub {
    my ($map)=@_;
    $map||=\%map;

    return sub {
        my ($schema,$name,$value)=@_;

        return unless defined $value;

        die qq{unknown field "$name"} unless exists $map->{$name};
        my $spec=$map->{$name};
        my ($rs,$field) = ( ref($spec) ? @$spec : ($spec,$name) );

        my @rows=$schema->resultset($rs)->search({$field => $value})->all;
        warn 'Found multiple values for search params '
           . "'$field => $value' in $rs. We should only ever get one."
            if scalar @rows > 1;
        my $row = $rows[0];
        if (!$row) {
            my $regex=$value; $regex=~s{[^[:alnum:]]+}{[^[:alnum:]]+}g;
            my $search=$schema->resultset($rs)->search(
                { $field => {'~*' => $regex} }
            );
            $row=$search->first;
            die qq{value "$value" for field "$field" not found, and regex "$regex" is ambiguous} if $search->next;
        }
        if (!$row) {
            die qq{no record found for value "$value" for field "$field"};
        }
        return $row->id;
    }
}
}
{
my $default_lookup=_create_lookup_by_name_sub();
sub lookup_dictionary_by_name {
    return $default_lookup->(@_);
}
}

=head1 METHODS

=head2 find($resultset, $id) : $row_of_resultset_with_id | undef

Find the row with PK $id in $resultset (e.g. "Channel",
"Designer::Attribute").

The default namespace prefix for $resultset is "Public::". Die if the
$resultset doesn't exist.

This method is useful to get out an object from value tables, like
channel, shipping_charge, etc.

=cut

sub find {
    my ($self, $resultset, $id) = @_;
    return undef unless defined($id);
    $resultset =~ /::/ or $resultset = "Public::$resultset";
    return $self->resultset($resultset)->find($id);
}

=head2 find_col($resultset, $id, $column_name) : $column_value_for_row_of_resultset_with_id | undef

Find the row with PK $id in $resultset (e.g. "Channel",
"Designer::Attribute") and return its $column_name value.

Other than that, it's the same as find.

=cut

sub find_col {
    my ($self, $resultset, $id, $column_name) = @_;
    my $row = $self->find($resultset => $id) or return undef;
    return $row->$column_name;
}

=head2 txn_dont($sub_ref) :

Like $schema->txn_do(), but instead of committing the transaction,
roll it back at after running $sub_ref.

=cut

sub txn_dont {
    my ($self, $sub_ref) = @_;

    $self->txn_do(
        sub {
            $sub_ref->();
            $self->txn_rollback();
        }
    );
}

=head2 db_now() : $datetime_object

Return now() from the database, inflated to a DateTime object.

=cut

sub db_now {
    my $self = shift;
    return $self->parse_datetime( $self->db_now_raw );
}

=head2 db_now_raw() : $datetime_string

Return the uninflated value of C<now()> from the db.

=cut

sub db_now_raw {
    return $_[0]->storage->dbh_do( sub {
        my ( $storage, $dbh ) = @_;
        $dbh->selectrow_arrayref( 'SELECT NOW()' )->[0];
    });
}

=head2 db_clock_timestamp

Returns 'clock_timestamp()' from the database and inflated
into a DateTime object.

The function 'clock_timestamp()' is different to 'now()' because
it gives the correct time within a transaction rather than the
same time until the transaction ends which is what 'now()' returns.

=cut

sub db_clock_timestamp {
    my $self = shift;

    # get clock_timestamp() from DB
    my $db_timestamp = $self->storage->dbh_do( sub {
        my ( $storage, $dbh ) = @_;
        return $dbh->selectrow_arrayref( 'SELECT CLOCK_TIMESTAMP()' )->[0];
    });

    # convert to DateTime
    return $self->parse_datetime( $db_timestamp );
}

=head2 set_acl

    $schema->set_acl( $xt_access_controls_object );

Pass an 'XT::AccessControls' object to set the 'acl' which can then be
used anywhere Schema is used by calling '$schema->acl'.

=head2 clear_acl

    $schema->clear_acl;

Will clear 'acl' so that it is 'undef'.

=head2 acl

    $acl_obj = $schema->acl;

Returns the 'XT::AccessControls' object set by 'set_acl'.

=cut

{
    my $_acl_obj;

    sub set_acl {
        my ( $self, $acl )  = @_;

        if ( ref( $acl ) ne 'XT::AccessControls' ) {
            croak "Object used to set 'acl' must be an insance of the 'XT::AccessControls' class, in '" . __PACKAGE__ . "->set_acl'";
        }

        $_acl_obj = $acl;

        return $self->acl;
    }

    sub clear_acl {
        $_acl_obj = undef;
        return;
    }

    sub acl {
        return $_acl_obj;
    }
}

1;
