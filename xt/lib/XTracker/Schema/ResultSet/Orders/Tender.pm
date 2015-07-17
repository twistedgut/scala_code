package XTracker::Schema::ResultSet::Orders::Tender;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head1 NAME

XTracker::Schema::ResultSet::Orders::Tender

=head1 METHODS

=cut

=head2 voucher_usage

Returns a resultset of tenders where the vouchers were used. C<source> is null
as these are promotional and given, and won't have orders where they were sold
anyway.

=cut

sub voucher_usage {
    my ( $self, $voucher_code_id ) = @_;

    my $me = $self->current_source_alias;
    # can't call search_related 'order' as it confuses pg
    return $self->search({ "$me.voucher_code_id" => $voucher_code_id })
                ->sourceless_vouchers;
}

=head2 sourceless_vouchers

Returns an Orders::Tender resultset of voucher rows that don't have a source.

=cut

sub sourceless_vouchers {
    return $_[0]->search(
        { 'voucher_instance.source' => undef },
        { join => 'voucher_instance' }
    );
}

1;
