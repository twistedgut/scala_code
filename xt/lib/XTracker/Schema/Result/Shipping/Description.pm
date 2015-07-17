use utf8;
package XTracker::Schema::Result::Shipping::Description;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("shipping.description");
__PACKAGE__->add_columns(
  "name",
  { data_type => "text", is_nullable => 0 },
  "public_name",
  { data_type => "text", is_nullable => 0 },
  "title",
  { data_type => "text", is_nullable => 0 },
  "public_title",
  { data_type => "text", is_nullable => 0 },
  "short_delivery_description",
  { data_type => "text", is_nullable => 1 },
  "long_delivery_description",
  { data_type => "text", is_nullable => 1 },
  "estimated_delivery",
  { data_type => "text", is_nullable => 1 },
  "delivery_confirmation",
  { data_type => "text", is_nullable => 1 },
  "shipping_charge_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("shipping_charge_id");
__PACKAGE__->belongs_to(
  "shipping_charge",
  "XTracker::Schema::Result::Public::ShippingCharge",
  { id => "shipping_charge_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4MfL3X7ayr+QGewBxhMGBQ

use Moose;
with 'XTracker::Role::WithAMQMessageFactory';

use DateTime;

=head1 NAME

XTracker::Schema::Result::Shipping::Description

=head1 DESCRIPTION

L<DBIx::Class::Result> class for the shipping_description table.

=head1 METHODS

=head2 C<broadcast>

Sends a Shipping::Description broadcast message.

=cut

sub broadcast {
    my $self = shift;
    my $args = shift;

    my $transformer_args = {
        shipping_description => $self,
    };

    if ( keys %{ $args->{envs} } ) {
        $transformer_args->{envs} = $args->{envs};
    }

    $self->msg_factory->transform_and_send('XT::DC::Messaging::Producer::Shipping::Description', $transformer_args );
}

=head2 upload

Send an AMQ message "uploading" this shipping "product".

=cut

sub upload {
    my ( $self ) = @_;

    $self->msg_factory->transform_and_send('XT::DC::Messaging::Producer::ProductService::Upload', {
        channel_id => $self->channel->id,
        pids => [ $self->shipping_charge->product_id ],
        upload_date => DateTime->now->set_time_zone('UTC')->iso8601,
        upload_timestamp => DateTime->now->set_time_zone('UTC')->iso8601,
    });
}


=head2 C<channel>

Returns the L<XTracker::Schema::Result::Public::Channel> associated with
this L<XTracker::Schema::Result::Shipping::Description>.

=cut

sub channel {
    my $self = shift;

    return $self->shipping_charge->channel;
}

=head2 C<business>

Returns the L<XTracker::Schema::Result::Public::Business> associated with
this L<XTracker::Schema::Result::Shipping::Channel>.

=cut

sub business {
    my $self = shift;

    return $self->shipping_charge->channel->business;
}

=head2 C<has_country_charges>

Returns a boolean indicatiing whether the C<shipping_charge> has
country charges.

=cut

sub has_country_charges {
    my $self = shift;

    return $self->shipping_charge->has_country_charges();
}

=head2 C<has_region_charges>

Returns a boolean indicatiing whether the C<shipping_charge> has
region charges.

=cut

sub has_region_charges {
    my $self = shift;

    return $self->shipping_charge->has_region_charges();
}

=head2 C<country_charges_payload>

Returns the C<shipping_charge>'s country charges.

=cut

sub country_charges_payload {
    my $self = shift;

    return $self->shipping_charge->country_charges_payload();
}

=head2 C<region_charges_payload>

Returns the C<shipping_charge>'s region charges.

=cut

sub region_charges_payload {
    my $self = shift;

    return $self->shipping_charge->region_charges_payload();
}

1; # be true
