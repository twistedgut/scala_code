package XTracker::Schema::ResultSet::Public::Season;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head2 drop_down_options

Returns a resultset of all designers ordered for display in a select drop-down-box.
For now it returns in 'season_year - season_code' order

=cut

sub drop_down_options {
    my ( $class ) = @_;

    return $class->search({}, {'order_by'=> {-desc => [qw/season_year season_code/]}, cache => 1} );
}

sub season_list {
    my $self = shift;
    my $me = $self->current_source_alias;

    return $self->search_rs( {},
        {
            order_by => {-desc => [ "$me.season_year", "$me.season_code"] },
            cache => 1,
        },
    );
}

1;
