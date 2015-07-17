package XTracker::Schema::ResultSetBase;
use parent 'DBIx::Class::ResultSet';
use Moose;
use MooseX::NonMoose;
with "XTracker::Schema::Role::ResultSet::GroupBy";

__PACKAGE__->load_components('Helper::ResultSet::Shortcut');

=head1 NAME

XTracker::Schema::ResultSetBase - schema resulset base class

=cut


use Carp;
use Scalar::Util qw(blessed);


=head1 METHODS

=head2 first

Override DBICs first method to use slice and single - first is broken in DBIC
on Postgres

=cut

sub first {
    my $self = shift;

    return $self->slice(0, 0)->single;
}

=head2 by_channel ($channel | $channel_id)

Constrain the resultset to specified channel. May be an
L<XTracker::Schema::Result::Public::Channel> object or a channel_id

=cut

sub by_channel {
    my $self = shift;
    my $channel = shift;

    croak 'No such column "channel_id"'
        unless $self->result_source->has_column('channel_id');

    my $channel_id;

    if (blessed $channel and
        $channel->isa('XTracker::Schema::Result::Public::Channel')) {
        $channel_id = $channel->id;
    }
    else {
        $channel_id = $channel;
    }

    return $self->search({channel_id => $channel_id});
}

1;
