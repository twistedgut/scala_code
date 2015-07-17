package XTracker::Cookies::Plugin::ColumnSort;
use NAP::policy "tt", 'class';

with 'XTracker::Cookies::Role::ManipulatesCookies';

=head1 NAME

XTracker::Cookies::Plugin::ColumnSort

=head1 DESCRIPTION

Allows access to columnsort cookie data, replaces methods formally in XTracker::Utilities:
    - munch_columnsort_cookie

=cut

sub name_template {
    return 'xt_<NAME>_columnsort';
};

=head1 PUBLIC METHODS

=head2 get_sort_data

Get stored data to remember how user wants their columns sorted

=cut
sub get_sort_data {
    my ($self, $name) = @_;

    my $order_by    = undef;
    my $asc_desc    = undef;

    if ( my $cookie_data = $self->get_cookie($name) ) {
        ($order_by, $asc_desc)  = split /:/, $cookie_data;
    }

    my $columnsort_ref = { order_by => $order_by, asc_desc => $asc_desc };
    return $columnsort_ref;
}
