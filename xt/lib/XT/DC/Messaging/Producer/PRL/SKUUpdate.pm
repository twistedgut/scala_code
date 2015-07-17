package XT::DC::Messaging::Producer::PRL::SKUUpdate;
# use NAP::policy 'class' # we can't yet - it forces immutability
use strict;
use warnings;
use Carp qw/croak/;

use XT::DC::Messaging::Spec::PRL;

use XTracker::Constants qw/:prl_type :sku_update/; # Imports $PRL_TYPE__*
                                                   # and SKU_UPDATE_DEFAULT_*
use XTracker::Constants::FromDB ':storage_type';
use XTracker::Image qw/get_images/; # Resolve images from PID
use XTracker::Config::Local qw( my_own_url );

use Moose;
with 'XT::DC::Messaging::Role::Producer',
     'XT::DC::Messaging::Producer::PRL::ReadyToSendRole',
     'XTracker::Role::WithIWSRolloutPhase',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithSchema';

=head1 NAME

XT::DC::Messaging::Producer::PRL::SKUUpdate

=head1 DESCRIPTION

Sends the sku_update message from XT to a PRL

=head1 SYNOPSIS

    # standard usage, destination queues will come from config
    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::SKUUpdate' => {
            product_variant => $variant,
        }
    );
    # or if it's a voucher:
    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::SKUUpdate' => {
            voucher_variant => $variant,
        }
    );

    # but you can specify the queue(s)/topic(s) explicitly if you want:

    # in case if message is sent to one destination
    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::SKUUpdate' => {
            product_variant => $variant,
            destinations => '/queue/test.1',
        }
    );

    OR

    # in case when message is sent to specified list of destinations
    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::SKUUpdate' => {
            product_variant => $variant,
            destinations => ['/queue/test.1', '/topic/test.topic'],
        }
    );


=head1 METHODS

=cut

has '+type' => ( default => 'sku_update' );

sub message_spec {
    return XT::DC::Messaging::Spec::PRL->sku_update();
}

=head2 transform

Accepts the AMQ header (which will be provided by the message producer),
and following HASHREF:

    product_variant => <Product::Variant/Voucher::Variant object>,
    destinations => <arrayref of destinations where message is to be sent>

=cut

sub transform {
    my ( $self, $header, $args ) = @_;

    croak 'Arguments are incorrect'
        unless 'HASH' eq uc ref $args;

    my $destinations = $args->{destinations} || $self->destinations;
    croak 'Mandatory parameter "destinations" was omitted and destinations were not found in config'
        unless $destinations;

    my $item = $args->{product_variant} || $args->{voucher_variant};
    croak 'You must supply a product_variant or voucher_variant paramter' unless $item;

    # We require a DBIC product-alike
    croak "PRL::SKUUpdate needs a Public::Variant or Voucher::Variant object"
    unless defined $item && (
        $item->isa('XTracker::Schema::Result::Public::Variant') ||
        $item->isa('XTracker::Schema::Result::Voucher::Variant') );

    # handle case when user's passed one destination as a scalar
    $destinations = [$destinations] unless 'ARRAY' eq uc ref $destinations;

    # Unify the interface to whatever it was we were passed
    my $details = $self->variant_details( $item );

    # Hard-code the operation for now
    $details->{'delete'} = $PRL_TYPE__BOOLEAN__FALSE;
    $details->{'expiration_date_flag'} = $PRL_TYPE__BOOLEAN__FALSE;

    # Pack in AMQ cruft
    return $self->amq_cruft({
        header       => $header,
        payload      => $details,
        destinations => $destinations,
    });
}

=head2 variant_details

Given a variant, looks up the various details around it and returns them as a
hash-ref suitable for returning to a PRL.

=cut

# TODO: This is almost exactly the same as
# XTracker::Schema::ResultSet::Public::PutawayPrepContainer::_get_variant_details
# - maybe it should make a call to it (or a common method). I don't have enough
# knowledge of which cogs they turn (and the data is ever-so-subtly different,
# e.g. see 'color' and family/family_group), but we should be refactoring here.
{
my $default_storage_type_row;
sub _default_storage_type_row {
    my $self = shift;
    return $default_storage_type_row
        ||= $self->schema->resultset('Product::StorageType')->find(
            $PRODUCT_STORAGE_TYPE__FLAT
        );
}
}
sub variant_details {
    my ( $self, $variant ) = @_;

    # Works for both vouchers and products
    my $product = $variant->product;
    my $product_channel = $product->get_product_channel;
    my $channel = $product_channel->channel;

    # These can be the same for everything...
    my $result = {
        'sku'                   => $variant->sku,
        'client'                => $channel->prl_client,
        'channel'               => $channel->business->config_section,
        'name'                  => $product->name || $SKU_UPDATE_DEFAULT_NAME,
        # FIXME: 'color' - is this a typo? If not worth putting a comment
        # saying it isn't, as the rest of xt says 'colour'
        'color'                 => $product->colour->colour,
        # in dc2, weight in db is in lbs already
        'weight_lbs'            => ($product->shipping_attribute->weight || 0),
        'storage_type'          => (
            $product->storage_type
          ? $product->storage_type->name
          : $self->_default_storage_type_row->name
        ),
        'cycle_count_frequency' => 91, # Remove this hard-code when we know how to do this
    };

    if ( $product->is_voucher ) {
        $result->{'family_group'} = $PRL_TYPE__FAMILY__VOUCHER;
        $result->{'designer'}     = $product->designer;
        $result->{'description'}  = "Gift Card";
        $result->{'size'}         = $variant->descriptive_value;
        $result->{'length_cm'}    = 0;
    } else {
        $result->{'family_group'} = $PRL_TYPE__FAMILY__GARMENT;
        $result->{'designer'}     = $product->designer->designer;
        $result->{'description'}  =
            substr( $product->product_attribute->description, 0, 255)
              || $SKU_UPDATE_DEFAULT_DESCRIPTION;
        $result->{'size'}         = $variant->designer_size->size;
        $result->{'length_cm'}    = $variant->get_measurements->{'Length'} || 0;
    }

    $result->{'image_url'} = $self->image_url({
        product_id => $product->id,
        live       => $product_channel->is_live,
        size       => 'm',
        schema     => $product->result_source->schema
    });

    return $result;
}

=head2 image_url

Wrapper around XTracker::Images C<get_images> that will always return
a fully-qualified URL with an image, or an empty string if there's no
image.

=cut

sub image_url {
    my ( $self, $options ) = @_;

    my $image_url = get_images({
         product_id => $options->{'product_id'},
         live       => $options->{'live'},
         size       => $options->{'size'},
         schema     => $options->{'schema'},
    })->[0];

    # Fully-qualify the image URL if needed
    $image_url = sprintf('http://%s%s', my_own_url(), $image_url )
        unless $image_url =~ m{^http://};

    return $image_url;
}

1;
