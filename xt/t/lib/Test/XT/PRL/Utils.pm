package Test::XT::PRL::Utils;

use NAP::policy "tt", qw( role test );

use XT::Domain::PRLs;

=head1 NAME

Test::XTracker::Artifacts

=head2 DESCRIPTION

Base class for modules that monitor directories; the base class for
Test::XTracker::PrintDocs and Test::XTracker::Artifacts::Manifest.

=head1 METHODS

=head2 check_sku_updates_for_product

Checks that we have sent the appropriate sku_update messages to PRLs for a product.

=cut

sub check_sku_updates_for_product {
    my ($self, $product, $xt_to_prls) = @_;

    # We should have sent one message for each related SKU to each PRL
    my $channel = $product->get_product_channel->channel->business->config_section;
    my @prls = XT::Domain::PRLs::get_all_prls();
    my @messages;
    foreach my $prl (@prls) {
        foreach my $variant ($product->variants) {
            push @messages,
            {
                '@type' => 'sku_update',
                'path' => $prl->amq_queue,
                details => {
                    'sku' => $variant->sku,
                    'channel' => $channel,
                },
            };
        }
    }

    return $xt_to_prls->expect_messages({ messages => \@messages });
}
