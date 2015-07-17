package XTracker::Schema::ResultSet::Public::LogSampleAdjustment;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head2 data_for_log_screen

Returns data for supplied product_id or variant_id, suitable for display in
the Sample Adjustment Log screen.

=cut

sub data_for_log_screen {
    my ( $self, $args ) = @_;

    my $match_sku;
    my $schema = $self->result_source->schema;
    my $variant_rs = $schema->resultset('Public::Variant');

    if ( $args->{variant_id} ) {
        # get sku for this variant
        $match_sku = $variant_rs->find( $args->{variant_id} )->sku;
    } elsif ( $args->{product_id} ) {
        # get skus for all sizes for this product
        my @size_ids = map { $_->sku } $variant_rs->search(
            { product_id => $args->{product_id} },
            { order_by => 'size_id' },
        )->all;
        $match_sku = { '-in' => [ \@size_ids ] };
    }

    my @sample_adjustment_log = $self->search(
        { sku => $match_sku },
        {
            order_by => 'me.timestamp',
            join => 'channel',
            '+select' => [ 'channel.name', \"TO_CHAR(me.timestamp, 'DD-MM-YYYY')", \"TO_CHAR(me.timestamp, 'HH24:MI')" ],
            '+as' => [ 'sales_channel', 'date', 'time' ],
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        }
    )->all;

    # Log screen wants log entries in a hashref split by channel name
    my %sample_adjustment_log_by_channel;
    push @{ $sample_adjustment_log_by_channel{ $_->{sales_channel} } }, $_ for @sample_adjustment_log;

    return \%sample_adjustment_log_by_channel;
}

1;
