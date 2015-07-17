package XTracker::AJAX::ProductImage;

use NAP::policy;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;

use XTracker::Image; # for get_images

# Send back the url for a product image. Return blank image if
# nothing is found.

sub handler {
    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    my $image_src = '/images/blank.gif';

    my $product_id  = $handler->{param_of}{product_id};
    if ($product_id) {

        # image size string (see XTracker:Image for more details)
        my $size        = $handler->{param_of}{size} // 'xs';

        my $image_urls = get_images( {
            product_id       => $product_id,
            size             => $size,
            schema           => $handler->{schema},
            reverse_non_live => 1,
        } );

        $image_src = $image_urls->[0];
    }

    $handler->{request}->content_type('text/plain');
    $handler->{request}->print($image_src);
    return OK;
}

1;
