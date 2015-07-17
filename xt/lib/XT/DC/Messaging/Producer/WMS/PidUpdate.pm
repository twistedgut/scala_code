package XT::DC::Messaging::Producer::WMS::PidUpdate;
use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;

use XTracker::Image;
use XTracker::Config::Local qw( config_var my_own_url );

use Carp;
with 'XT::DC::Messaging::Role::Producer',
     'XTracker::Role::WithIWSRolloutPhase',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithSchema';

has '+type' => ( default => 'pid_update' );
has '+destination' => ( default => config_var('WMS_Queues','wms_inventory') );

sub message_spec {
    return XT::DC::Messaging::Spec::WMS::pid_update();
}

sub transform {
    my ($self, $header, $product) = @_;

    # check $product is a DBIX::Class object
    croak "WMS::PidUpdate needs a Public::Product or Voucher::Product object"
        unless defined $product &&
                       ( $product->isa('XTracker::Schema::Result::Public::Product') ||
                         $product->isa('XTracker::Schema::Result::Voucher::Product') );


    my $is_voucher = $product->can('live');

    my $channel = $is_voucher ?
        $product->channel() :
        $product->get_product_channel()->channel()
    ;

    my $live = $is_voucher ?
                $product->live :
                $product->product_channel->search({
                        'channel_id' => $channel->id,
                    },{
                        rows => 1,
                    })->single->live;
    my $image_url = get_images({
        product_id => $product->id,
        live => $live,
        size => 'm',
        schema => $self->schema,
    })->[0];
    $image_url = sprintf 'http://%s%s',my_own_url(),$image_url
        unless $image_url =~ m{^http://};
    $image_url = ''
        if $image_url =~ m{/blank\.\w+$};

    # If a product doesn't have a storage, we will fail, so die here with
    # a meaningful message.
    if ( !defined $product->storage_type ) {
        die sprintf(
            "Unable to determine storage type for product %s in XT",
            $product->id,
        );
    }

    my $shipping_attribute = $product->shipping_attribute;
    my $payload = {
        version     => '1.0',
        operation   => 'add', # update is just a special case of add. IWS should DTRT
                              # are we really ever going to delete? I think not.
        pid         => $product->id,
        description => $product->wms_presentation_name,
        photo_url   => $image_url,

        length      => $shipping_attribute->length,
        width       => $shipping_attribute->width,
        height      => $shipping_attribute->height,
        weight      => $shipping_attribute->weight,

        storage_type=> lc($product->storage_type->iws_name),
        client      => $channel->client()->get_client_code(),
    };

    return ($header, $payload);
}


1;
