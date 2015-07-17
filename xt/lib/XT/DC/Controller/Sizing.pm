package XT::DC::Controller::Sizing;
use NAP::policy "tt", 'class';
use XTracker::Constants::FromDB ':variant_type';
BEGIN { extends 'Catalyst::Controller::REST' }

sub sizes_for_product :Local :ActionClass('REST') {
}

sub sizes_for_product_POST {
    my ($self,$c) = @_;

    my $schema = $c->model('DB')->schema;

    my $ret;
    try {
        my $product_id = $c->req->data->{product_id};
        my $channel_id = $c->req->data->{channel_id};

        my $product = $schema->resultset('Public::Product')->search(
            { 'me.id' => $product_id },
            {
                prefetch => {
                    'product_attribute' => 'size_scheme',
                    'variants' => [ 'size', 'designer_size', 'std_size' ],
                },
            },
        )->next;

        die "Unknown product $product_id"
            unless $product;

        $ret = $product->sizing_payload($channel_id);
        $self->status_ok(
            $c,
            entity => $ret,
        );
    }
    catch {
        $self->status_bad_request(
            $c,
            message => "Problems: $_",
        );
    };
    return;
}
