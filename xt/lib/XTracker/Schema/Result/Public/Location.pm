use utf8;
package XTracker::Schema::Result::Public::Location;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.location");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "location_id_seq",
  },
  "location",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("new_location_location_key", ["location"]);
__PACKAGE__->has_many(
  "channel_transfer_picks",
  "XTracker::Schema::Result::Public::ChannelTransferPick",
  { "foreign.location_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "channel_transfer_putaways",
  "XTracker::Schema::Result::Public::ChannelTransferPutaway",
  { "foreign.location_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "location_allowed_statuses",
  "XTracker::Schema::Result::Public::LocationAllowedStatus",
  { "foreign.location_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_locations",
  "XTracker::Schema::Result::Public::LogLocation",
  { "foreign.location_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "prls",
  "XTracker::Schema::Result::Public::Prl",
  { "foreign.location_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "putaway_prep_containers",
  "XTracker::Schema::Result::Public::PutawayPrepContainer",
  { "foreign.destination" => "self.location" },
  undef,
);
__PACKAGE__->has_many(
  "putaways",
  "XTracker::Schema::Result::Public::Putaway",
  { "foreign.location_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "quantities",
  "XTracker::Schema::Result::Public::Quantity",
  { "foreign.location_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "rtv_quantities",
  "XTracker::Schema::Result::Public::RTVQuantity",
  { "foreign.location_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "sample_request_type_bookout_location_ids",
  "XTracker::Schema::Result::Public::SampleRequestType",
  { "foreign.bookout_location_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "sample_request_type_source_location_ids",
  "XTracker::Schema::Result::Public::SampleRequestType",
  { "foreign.source_location_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_items",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { "foreign.lost_at_location_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "stock_count_variants",
  "XTracker::Schema::Result::Public::StockCountVariant",
  { "foreign.location_id" => "self.id" },
  undef,
);
__PACKAGE__->many_to_many("allowed_statuses", "location_allowed_statuses", "status");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9dm9ePF+UEUGWaughc46Ow


use XTracker::Constants::Regex qw( :location );
use XTracker::Config::Local qw( config_var );

__PACKAGE__->many_to_many( 'product_variants', 'quantities' => 'product_variant' );
__PACKAGE__->many_to_many( 'voucher_variants', 'quantities' => 'voucher_variant' );
__PACKAGE__->many_to_many( 'stock_processes', 'putaways' => 'stock_process' );

use Scalar::Util 'blessed';

sub allows_status {
    my ($self,$status)=@_;

    my $id;
    $id=$status->id if blessed($status) && $status->can('id');
    $id=$status unless defined $id;

    return $self->count_related('location_allowed_statuses',{
        status_id => $id,
    }) > 0;
}

sub parse_location_name {
    my ($self, $location) = @_;

    # support either Location object or a location name string
    my $loc_name;
    $loc_name = $location->location if blessed($location) && $location->can('location');
    $loc_name //= $location;
    return unless defined $location;

    # collect location details to return
    my $loc_components = {
        name => $loc_name,
    };

    # get static location-parsing stuff
    my $dc_name = config_var('DistributionCentre', 'name');
    my $re = $LOCATION_REGEX;
    my @re_parts = @{$LOCATION_PARTS};

    # check the location name is parseable
    if ((my @matched_parts) = ($loc_name =~ /$re/)) {
        # parse and fill in other location details
        map { $loc_components->{$re_parts[$_]} = $matched_parts[$_] } 0..$#re_parts;
    }

    # always return a hashref, with at least name filled in
    return $loc_components;
}

sub location_parsed {
    # cached parsed location name
    my ($self) = @_;
    # TODO implement caching
    return $self->parse_location_name($self->location);
}

sub floor {
    return shift->location_parsed->{floor};
}

sub level {
    return shift->location_parsed->{level};
}

=head2 is_on_floor($floor)

Returns a true value if the location is on the given floor.

=cut

sub is_on_floor {
    my ( $self, $floor ) = @_;
    return $self->floor && $self->floor == $floor;
}

=head2 is_same($location_name) : Bool

Wether $location_name (the ->location) is the same Location as this
one.

=cut

sub is_same {
    my ($self, $other_location_name) = @_;

    return uc($self->location) eq uc($other_location_name);
}

=head2 verify_is_same($location_name) : die |

Ensure $location_name is this Location or die if not.

=cut

sub verify_is_same {
    my ($self, $other_location_name) = @_;
    $self->is_same($other_location_name)
        or die("($other_location_name) is not the Location (" . $self->location . ")\n");
    return;
}

=head2 does_include_variants($variant_rows_array_ref): Bool

Check if current location contains passed Variant rows. Pass certain Variant N times if there is a need
to check the quantity N.

=cut

sub does_include_variants {
    my ($self, $variants) = @_;

    my %actual_stock =
        map { $_->variant->sku => $_->quantity } $self->quantities->all;

    my %passed_stock;
    $passed_stock{$_->sku}++ foreach @$variants;

    return 0 if grep { !$actual_stock{$_} || $actual_stock{$_} < $passed_stock{$_} } keys %passed_stock;
    return 1;
}

=head2 get_quantity_sum($variant_ids) : $quantity_sum

Return the total quantity of the $variant_ids in the Location.

=cut

sub get_quantity_sum {
    my ($self, $variant_ids) = @_;
    return $self->quantities->search({
        variant_id => { -in => $variant_ids },
    })->get_column("quantity")->sum() // 0;
}

=head2 does_include_content_of_pp_container($pp_container_row): bool

Check if content of provided "putaway prep container" could be sourced from current location.

=cut

sub does_include_content_of_pp_container {
    my ($self, $pp_container_row) = @_;

    return $self->does_include_variants( $pp_container_row->variants );
}

1;

