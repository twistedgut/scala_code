package XT::Data::PRL::Conveyor::Route::Role::WithContainers;
use NAP::policy "tt", "role";
with
    "XTracker::Role::WithSchema";

=head1 NAME

XT::Data::PRL::Conveyor::Route::Role::WithContainers - Route Container(s)

=head1 DESCRIPTION

This is a Route for one or many Containers on the Conveyor belt.

Calling ->send() will send an AMQ message to the Conveyor belt with
the appropriate destination for each Container.

=cut

use Carp;

requires "get_route_destination";
requires "send_message";

use Moose::Util::TypeConstraints;

use NAP::DC::Barcode::Container;
use XTracker::Schema::Result::Public::Container;

has container_id => (
    is      => "ro",
    isa     => "Str | NAP::DC::Barcode::Container | Undef",
    default => undef,
);

has container_ids => (
    is      => "ro",
    isa     => "ArrayRef[ Str | NAP::DC::Barcode::Container ]",
    default => sub { [] },
);

has container_row => (
    is      => "ro",
    isa     => "XTracker::Schema::Result::Public::Container | Undef",
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $container_row = $self->_find_container( $self->container_id );
        return $container_row;
    },
);

has container_rows => (
    is      => "ro",
    isa     => "ArrayRef[XTracker::Schema::Result::Public::Container]",
    lazy    => 1,
    default => sub {
        my $self =  shift;
        return [
            grep { defined }
            (
                $self->container_row,
                map { $self->_find_container($_) } @{$self->container_ids},
            ),
        ],
    },
);


=head1 METHODS

=cut

sub _find_container {
    my ($self, $container_id) = @_;
    return unless $container_id;

    my $container_row = $self->schema->resultset("Public::Container")->find( $container_id )
        or die("Could not find Container ($container_id)\n");

    return $container_row;
}

=head2 new(%args) : $new_object | die

Create new Route object.

This is a base class. Create a Route of the correct sub class
depending on which logical destination the Container should go to.

You must specify at least one of the attributes ->container_id,
->container_ids, ->container_row, ->container_rows to indicate which
DBIC Containers to send messages for. The ->container_rows attribute
is what is ultimately being used, it will look up Containers using the
other attributes as needed.

If you pass in many Containers, they should contain related Shipments,
because their state as a whole may determine whether any Routing
messages are sent. See sub classes (e.g. ToPacking won't be sent if
any Shipment is on Hold) for examples.

=cut

# This way BUILD is always called, even if this BUILD isn't composed
# into the main class
sub BUILD { }
after BUILD => sub {
    my $self = shift;
    if ( ! @{$self->container_rows} ) {
        confess("Please specify either of container_id, container_row, container_ids, container_rows");
    }
};

=head2 send(%args) : $route_destination_name | undef | die

Send a routing message (if appropriate) for each container with a
destination that may or may not depend on %args.

Return the name of the destination the the route messages was sent
for, or undef if no message was sent. Die on errors.

=cut

sub send {
    my ($self, $args) = @_;

    my $route_destination = $self->get_route_destination($args)
        or return undef;

    for my $container_row( @{$self->container_rows} ) {
        $self->send_message( $container_row->id, $route_destination );
    }

    return $route_destination;
}


