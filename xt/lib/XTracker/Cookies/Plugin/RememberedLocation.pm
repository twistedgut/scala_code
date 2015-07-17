package XTracker::Cookies::Plugin::RememberedLocation;
use NAP::policy "tt", 'class';

with 'XTracker::Cookies::Role::ManipulatesCookies';

=head1 NAME

XTracker::Cookies::Plugin::RememberedLocation

=head1 DESCRIPTION

Allows access to remembered location cookie data,
replaces methods formally in XTracker::Utilities:

    - munch_rmbrlctn_cookie
    - delete_rmbrlctn_cookie
=cut

sub name_template {
    return 'xt_rmbrlctn_<NAME>';
};

=head1 PUBLIC METHODS

=head2 get_rmbrlctn_cookie

This reads a remember location cookie called $name with the name first
being prefixed with 'xt_rmbrlctn'. All the contents of the cookie is returned
in a SCALAR.

param - $name : Cookie Name.

return - $contents : A SCALAR containing the cookie contents.
=cut
sub get_rmbrlctn_cookie {
    my ($self, $name) = @_;
    return $self->get_cookie();
}
