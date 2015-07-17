package XTracker::Schema::ResultSet::Public::LogStock;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head2 log

Logs an entry to the log_stock table.

=cut

sub log {
    my ( $self, $arg_ref ) = @_;
    my @field_names = (qw{
        variant_id
        stock_action_id
        operator_id
        notes
        quantity
        balance
        channel_id
    });
    my %params;
    @params{@field_names} = @{ $arg_ref }{ @field_names };

    my $schema = $self->result_source->schema;
    my $variant
        = $arg_ref->{variant}
            || $schema->resultset('Public::Variant')->find( $arg_ref->{variant_id} )
            || $schema->resultset('Voucher::Variant')->find( $arg_ref->{variant_id} );
    $params{variant_id} ||= $variant->id;

    die "$variant variant_id not found in public.variant or voucher.variant"
        unless $variant;

    $params{balance}
        = $variant->current_stock_on_channel( $arg_ref->{channel_id} );

    return $self->create( \%params );
}

1;
