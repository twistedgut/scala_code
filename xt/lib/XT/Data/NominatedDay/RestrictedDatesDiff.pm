package XT::Data::NominatedDay::RestrictedDatesDiff;
use NAP::policy "tt", 'class';
with qw(
    XTracker::Role::WithSchema
    XTracker::Role::WithAMQMessageFactory
);

use List::MoreUtils qw/ uniq /;

use XT::Data::Types qw/ DateStamp /;
use XT::Data::Types;
use Moose::Util::TypeConstraints;

use XTracker::Logfile qw( xt_logger );

=head1 NAME

XT::Data::NominatedDay::RestrictedDatesDiff - The diff between two sets of RestrictedDate objects

=head1 DESCRIPTION

The diff between two sets of RestrictedDate objects, and the
operations needed to update the database and publish the changes to
the Web sites.

The "current" set of restricted dates, which was sent to the browser
for editing, and the "new" set of dates, which was sent back by the
user are used to determine the diff of these two sets.

Only the dates actually touched by the user are changed, which means
we avoid the race condition where two users are editing the same
report time period.

In the case where two users edit the same exact date, the last person
to submit the changes wins (lesson learned: work slower).

=cut

has begin_date    => ( is => "ro", isa => "XT::Data::Types::DateStamp", coerce => 1 );
has end_date      => ( is => "ro", isa => "XT::Data::Types::DateStamp", coerce => 1 );
has change_reason => ( is => "ro", isa => "Str", required => 1 );

has operator      => (
    is       => "ro",
    isa      => "XTracker::Schema::Result::Public::Operator",
    required => 1,
);

has current_restricted_dates => (
    is      => "ro",
    isa     => "ArrayRef[XT::Data::NominatedDay::RestrictedDate]",
    default => sub { [] },
);

has current_key_restricted_date => (
    is      => "ro",
    isa     => "HashRef[XT::Data::NominatedDay::RestrictedDate]",
    lazy    => 1,
    default => sub {
        my $self = shift;
        return { map { $_->key => $_ } @{$self->current_restricted_dates} };
    },
);

has new_restricted_dates => (
    is      => "ro",
    isa     => "ArrayRef[XT::Data::NominatedDay::RestrictedDate]",
    default => sub { [] },
);

has new_key_restricted_date => (
    is      => "ro",
    isa     => "HashRef[XT::Data::NominatedDay::RestrictedDate]",
    lazy    => 1,
    default => sub {
        my $self = shift;
        return { map { $_->key => $_ } @{$self->new_restricted_dates} };
    },
);

sub save_to_database {
    my $self = shift;

    try {
        $self->schema->txn_do( sub {
            for my $date (@{$self->dates_to_restrict()}) {
                $date->restrict(
                    $self->operator,
                    $self->change_reason,
                );
            }
            for my $date (@{$self->dates_to_unrestrict()}) {
                $date->unrestrict(
                    $self->operator,
                    $self->change_reason,
                );
            }
        } );
    }
    catch {
        xt_logger->error($_);
        die("A Database error occurred, please contact Service Desk\n");
    };
}

# This will give a modicum of order to the Change Log
sub sorted {
    my ($self, $dates) = @_;

    my @sorted_dates = sort {
        # reverse date order, so the log (which is in reverse
        # order) shows it correctly
        ($a->date cmp $b->date) * -1
            ||
        $a->restriction_type cmp $b->restriction_type
            ||
        $a->shipping_charge_id cmp $b->shipping_charge_id
    } @$dates;

    return \@sorted_dates;
}

sub channel_rows_with_changes {
    my $self = shift;
    return [
        sort { $a->name cmp $b->name }
        uniq(
            map { $_->channel_row }
            @{$self->dates_to_change}
        ),
    ];
}

sub publish_to_web_sites {
    my $self = shift;

    for my $channel_row (@{$self->channel_rows_with_changes}) {
        $self->msg_factory->transform_and_send(
            "XT::DC::Messaging::Producer::Shipping::DeliveryDateRestriction",
            {
                channel_row => $channel_row,
                begin_date  => $self->begin_date,
                end_date    => $self->end_date,
            },
        );
    }

}

sub dates_to_restrict {
    my $self = shift;
    my $key_date = $self->hashref_difference(
        $self->new_key_restricted_date,
        $self->current_key_restricted_date,
    );
    return $self->sorted([ values %$key_date ]);
}

sub dates_to_unrestrict {
    my $self = shift;
    my $key_date = $self->hashref_difference(
        $self->current_key_restricted_date,
        $self->new_key_restricted_date,
    );

    return $self->sorted([ values %$key_date ]);
}

sub dates_to_change {
    my $self = shift;
    return [
        @{$self->dates_to_restrict},
        @{$self->dates_to_unrestrict},
    ];
}

# because Set::Object doesn't seem to do the right thing :/
sub hashref_difference {
    my ($self, $set_a, $set_b) = @_;

    my %seen;
    @seen{ keys %$set_a } = 1;
    delete @seen{ keys %$set_b };
    my @keys_difference = keys %seen;

    my %set_difference;
    @set_difference{ @keys_difference } = @{$set_a}{ @keys_difference };

    return \%set_difference;
}

