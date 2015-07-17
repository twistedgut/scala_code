package XTracker::Cookies::Plugin::Search;
use NAP::policy "tt", 'class';

with 'XTracker::Cookies::Role::ManipulatesCookies';

=head1 NAME

XTracker::Cookies::Plugin::Search

=head1 DESCRIPTION

Allows access to search cookie data, replaces methods formally in XTracker::Utilities:

    - create_search_cookie
    - munch_search_cookie
    - delete_search_cookie
=cut

sub name_template {
    return 'xt_<NAME>_search';
};

=head1 PUBLIC METHODS

=head2 create_search_cookie

This creates a cookie to store search parameters in so they can
be used later when going back to a list of results. The name is
taken and then prefixed with a 'xt_' and suffixed with a '_search',
also the value is assumed to be a query string and will then lose
the leading '?'.

param - $cookie_name : Name for the cookie
param - $value_to_store : value to store

=cut
sub create_search_cookie {
    my ($self, $name, $value) = @_;

    # Chop the leading '?' off the query string
    $value  =~ s/^\?//;

    return $self->set_cookie($name, {
        value   => $value,
        expires => "+1d",
        path    => '/',
    });
}

=head2 get_search_cookie

This reads a search cookie called $name with the name first being
prefixed with 'xt_' and then suffixed with '_search'. The value
will be split by '&' and then each segment split by '=' and put
into a hash, which is then returned.

param - $name : Cookie Name

return - $search_results : A pointer to a HASH containing the cookie contents

=cut
sub get_search_cookie {
    my ($self, $name) = @_;

    my %search_results;

    # was one of them the one we want
    if ( my $cookie_data = $self->get_cookie($name) ) {
        %search_results     = map { split(/=/,$_) } split(/\&/,$cookie_data);
    }

    return \%search_results;
}
