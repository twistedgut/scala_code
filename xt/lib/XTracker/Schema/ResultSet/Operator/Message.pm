package XTracker::Schema::ResultSet::Operator::Message;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub message_list {
    my $resultset = shift;
    my $attr = shift;

    # make sure some values are set to a default if nothing is specified
    if (not defined $attr->{deleted}) {
        $attr->{deleted} = 0;
    }

    my $list = $resultset->search(
        $attr,
        {
            order_by => ['viewed ASC', 'created DESC'],
        },
    );

    return $list;
}

sub message_count {
    my $resultset = shift;
    my $attr = shift;

    # we're looking for all messages (regardless of what may have been
    # passed)
    delete ($attr->{viewed});

    # make sure some values are set to a default if nothing is specified
    if (not defined $attr->{deleted}) {
        $attr->{deleted} = 0;
    }

    my $count = $resultset->count( $attr );

    return $count;
}

sub read_message_count {
    my $resultset = shift;
    my $attr = shift;

    # we're looking for viewed messages (regardless of what may have been
    # passed)
    $attr->{viewed} = 1;

    # make sure some values are set to a default if nothing is specified
    if (not defined $attr->{deleted}) {
        $attr->{deleted} = 0;
    }

    my $count = $resultset->count( $attr );

    return $count;
}

sub unread_message_count {
    my $resultset = shift;
    my $attr = shift;

    # we're looking for non-viewed messages (regardless of what may have been
    # passed)
    $attr->{viewed} = 0;

    # make sure some values are set to a default if nothing is specified
    if (not defined $attr->{deleted}) {
        $attr->{deleted} = 0;
    }

    my $count = $resultset->count( $attr );

    return $count;
}

1;
