package Test::XT::Fixture::Role::WithProduct;
use NAP::policy "tt", "role";

=head1 NAME

Test::XT::Fixture::Role::WithProduct - Product fixture setup

=head1 DESCRIPTION

Test fixture role with a Product

=cut

use Test::More;

use Test::XTracker::Data;
use XTracker::Constants::FromDB qw(
    :storage_type
);

requires "discard_changes";



=head1 ATTRIBUTES

=cut

has channel_name => (
    is      => "ro",
    lazy    => 1,
    default => "nap",
);

has channel_row => (
    is   => "ro",
    lazy => 1,
    default => sub {
        my $self = shift;
        Test::XTracker::Data->channel_for_business(
            name => $self->channel_name,
        );
    }
);

has pid_count => (
    is      => "ro",
    lazy    => 1,
    default => 4,
);

has variant_count => (
    is      => "ro",
    lazy    => 1,
    default => 1,
);

has storage_type_id => (
    is      => "ro",
    lazy    => 1,
    default => sub { $PRODUCT_STORAGE_TYPE__FLAT },
);

# This is a number of each particular PID to have in order. So if it
# is for instance "2", order has two items of each PID. Defaults to
# "1".
#
has pids_multiplicator => (
    is  => 'ro',
    lazy    => 1,
    default => 1,
);

# Use prl_pid_counts to get a shipment with allocations in various
# prls. Keys should be the prl name.
#
# Example:
#
#  my $fixture = Test::XT::Fixture::Fulfilment::Shipment->new({
#       prl_pid_counts => {
#           'Dematic' => 1,
#           'Full'    => 2,
#           'GOH'     => 3,
#       },
#  });

has prl_pid_counts => (
    is      => "ro",
);

# TODO: Make this build map from prl config
has prl_storage_type_map => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        return {
            'Full'    => $PRODUCT_STORAGE_TYPE__FLAT,
            'Dematic' => $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT,
            'GOH'     => $PRODUCT_STORAGE_TYPE__HANGING,
        };
    }
);

has storage_type_pid_counts => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        if ($self->prl_pid_counts) {
            my $counts;
            foreach my $prl_name (keys %{$self->prl_pid_counts}) {
                my $storage_type_id = $self->prl_storage_type_map->{$prl_name} || $PRODUCT_STORAGE_TYPE__FLAT;
                $counts->{$storage_type_id} = $self->prl_pid_counts->{$prl_name};
            }
            return $counts;
        }
        return {$self->storage_type_id => $self->pid_count};
    },
);

has pids => (
    is   => "ro",
    isa  => "ArrayRef",
    lazy => 1,
    default => sub {
        my $self = shift;
        my $class = ref($self);
        return $class->grab_products(
            $self->channel_name,
            $self->pid_count,
            $self->pids_multiplicator,
            $self->variant_count,
            $self->storage_type_pid_counts,
        );
    }
);

has product_rows => (
    is         => "ro",
    isa        => "ArrayRef",
    lazy_build => 1,
);
sub _build_product_rows {
    my $self = shift;
    return [ grep { $_ } map { $_->{product} } @{$self->pids} ];
}

has variant_rows => (
    is         => "ro",
    isa        => "ArrayRef",
    lazy_build => 1,
);
sub _build_variant_rows {
    my $self = shift;
    return [ map { $_->variants } @{$self->product_rows} ];
}



=head1 CLASS METHODS

=cut

sub grab_products {
    my ($class, $channel_name, $pid_count, $pids_multiplicator, $variant_count, $storage_type_counts) = @_;

    $variant_count //= 1;
    $storage_type_counts //= {$PRODUCT_STORAGE_TYPE__FLAT => $pid_count};
    my $pids;
    foreach my $storage_type_id (sort keys %{$storage_type_counts}) {
        my ( $channel, $created_pids ) = Test::XTracker::Data->grab_products({
            channel           => $channel_name,
            how_many          => $storage_type_counts->{$storage_type_id},
            how_many_variants => $variant_count,
            force_create      => 1,
            storage_type_id   => $storage_type_id,
        });
        push @$pids, @$created_pids;
    }
    return unless ($pids);
    return [ map {@$pids} 1 .. $pids_multiplicator ];
}



=head1 METHODS

=cut

sub BUILD {
    my $self = shift;
    note "*** BEGIN Product Fixture setup " . ref($self);
    $self->pids;

    note "*** END Product Fixture setup " . ref($self);
}

after discard_changes => sub {
    my $self = shift;

    $_->discard_changes for @{$self->product_rows};

    return $self;
};

