package XT::Order::Role::Parser::Common::AsList;
use NAP::policy "tt", 'role';

=head1 METHODS

=head2 as_list($self, $thingy)

If C<$thingy> is not a list (ARRAYREF) return a list consisting of one item,
C<$thingy>

If C<$thingy> is a list, return C<$thingy>

I've seen this used in a few places, and it's looking like something that
would better be provided as a role than through copy'n'paste.

=cut
sub as_list {
    my $self   = shift;
    my $thingy = shift;
    my $list;

    return
        unless defined $thingy;

    # we're already what we want to be
    return $thingy
        if (defined $thingy && ref($thingy) eq 'ARRAY');

    # make our thingy into a solo list element
    return [ $thingy ];
}
