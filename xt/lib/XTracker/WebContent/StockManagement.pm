package XTracker::WebContent::StockManagement;

use Moose;
use Module::PluginFinder;

=head1 NAME

XTracker::WebContent::StockManagement

=head1 SYNOPSIS

    use XTracker::WebContent::StockManagement;

    my $stock_manager = XTracker::WebContent::StockManagement->new_stock_manager({
        schema => $schema,
        channel_id => $channel->id,
    });

    $stock_manager->stock_update(
        quantity_change => $quantity,
        variant_id => $variant->id,
        skip_non_live => 1, # optional
    );

    $stock_manager->commit;

    $stock_manager->rollback;


=head1 DESCRIPTION

Factory class for creating StockManagement objects based on the channel. The stock
management objects handle updating stock levels for either our web channels, or
third parties via the integration-service.

The web channels (OurChannels) grab a C<$web_dbh> handle and update the web
database directly and the third parties (ThirdParty) send a stock update message
over AMQ to the integration-service, which does a transformation and relays the
message to the correct location.

=cut

# This factory implementation is inspired by:
# http://acidcycles.wordpress.com/2010/11/24/implementing-factories-in-perl/
my $finder = Module::PluginFinder->new(
    search_path => 'XTracker::WebContent::StockManagement',
    filter      => sub {
        my ($class, $data) = @_;
        $class->is_mychannel($data);
    }
);

=head1 METHODS

=head2 new_stock_manager

    my $stock_manager
        = XTracker::WebContent::StockManagement->new_stock_manager({
        schema     => $schema,
        channel_id => $channel->id,
    });

Returns a new StockManagement object based on the channel passed in.

If a fulfilment_only channel is passed in, will return a
L<XTracker::WebContent::StockManagement::ThirdParty> StockManagement object
otherwise will return a L<XTracker::WebContent::StockManagement:::OurChannels>
StockManagement object.

=cut

sub new_stock_manager {
    my ($class, $data) = @_;

    my $channel = $data->{schema}->resultset('Public::Channel')->find(
        $data->{channel_id}
    );

    # Note - we use the same data for the filter as well as the new
    return $finder->construct($channel, $data);
}

=head1 AUTHOR

Andrew Solomon <andrew.solomon@net-a-porter.com>

=cut

1;
