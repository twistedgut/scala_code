package Test::XTracker::Image;

use FindBin::libs;
use NAP::policy "tt", 'test', 'class';

BEGIN {
    extends "NAP::Test::Class";
}

use XTracker::Image qw/get_images/;
use Test::XTracker::Data;
use XTracker::Constants::FromDB qw/
    :storage_type
    :business
/;
use Test::XTracker::Data;

=head1 DESCRIPTION

Unit tests for XTracker::Image

=head3 What's not tested

Everything except get_images().

=cut

sub get_images_nap : Tests {
    my ($self) = @_;

    # Determine NAP channel
    my $channel = $self->schema->resultset('Public::Channel')->find({
        business_id => $BUSINESS__NAP
    });

    # Create a NAP product
    my ($product) = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        channel_id      => $channel->id,
    });

    # Call get_images
    my $image_url = get_images({
        product_id  => $product->id,
        live        => $product->get_product_channel->live,
        size        => 'm',
        schema      => $self->schema,
    })->[0];
    note("image_url = ".($image_url // 'undef'));

    isnt($image_url, undef, 'image url is defined');
}

sub get_images_jc : Tests {
    my ($self) = @_;

    # Determine Jimmy Choo channel
    my $channel = $self->schema->resultset('Public::Channel')->find({
        business_id => $BUSINESS__JC
    });

    # Create a Jimmy Choo product
    my ($product) = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        channel_id      => $channel->id,
    });

    # Call get_images
    my $image_url = get_images({
        product_id  => $product->id,
        live        => $product->get_product_channel->live,
        size        => 'm',
        schema      => $self->schema,
    })->[0];
    note("image_url = ".($image_url // 'undef'));

    isnt($image_url, undef, 'image url is defined for a Jimmy Choo product');
}
