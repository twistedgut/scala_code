package Test::XT::Fixture::Fulfilment::Shipment;
use NAP::policy "tt", "class";
extends "Test::XT::Fixture::Common::Shipment";

=head1 NAME

Test::XT::Fixture::Fulfilment::Shipment.pm - Test fixture

=head1 DESCRIPTION

Test fixture with a Shipment that can be picked.

Feel free to add more transformations here.

=cut

use Test::More;

use XT::Domain::PRLs;
use XTracker::Constants::FromDB qw(
    :allocation_status
);



=head1 ATTRIBUTES

=cut

has "+flow" => (
    default => sub {
        my $self = shift;
        return Test::XT::Data->new_with_traits(
            traits => [
                "Test::XT::Data::Order",
                "Test::XT::Flow::PRL",
            ],
            dbh    => $self->schema->storage->dbh,
        );
    }
);

has "+shipment_row" => (
    default => sub {
        my $self = shift;
        $self->order_row->shipments(
            {},
            { prefetch => shipment_items => allocation_items => "allocation" },
        )->first;
    },
);

# Key is PRL name, value is an allocation row
has allocation_rows => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my %rows;

        foreach my $prl_name (map { $_->name } XT::Domain::PRLs::get_all_prls) {
            $rows{$prl_name} =
                $self->shipment_row->shipment_items
                    ->related_resultset('allocation_items')
                    ->related_resultset('allocation')->filter_in_prl($prl_name)
                    ->first;
        }

        return \%rows;
    },
);

# Set up a "xxx_allocation_row" attribute for each active PRL
# e.g. dematic_allocation_row
# Each is just a proxy for a value in the allocation_rows attribute (see above)
foreach my $prl_name (map { $_->name } XT::Domain::PRLs::get_all_prls) {
    has lc $prl_name . '_allocation_row' => (
        is => "ro",
        lazy => 1,
        default => sub {
            my $self = shift;
            return $self->allocation_rows->{$prl_name};
        },
    );
}

=head1 METHODS

=cut

after discard_changes => sub {
    my $self = shift;
    ( $_ and $_->discard_changes ) for (
        $self->dematic_allocation_row,
    );
};

