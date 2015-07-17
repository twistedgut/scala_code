package XT::Data::Fulfilment::Putaway;
use NAP::policy "tt", "class";

=head1 NAME

XT::Data::Fulfilment::Putaway - Putaway Cancelled using either a Container or a Location

=head1 DESCRIPTION

Note: the distinctinon between Container vs Location is what mechanism
is used for _intransit_ to Putaway.

* Manual DC2 -- Container, but left in Cancel Pending until manually
carried to Putaway.

* IWS -- Container, but then immediately cancelled and Putaway back
into the IWS location.

* PRL -- Cancelled-to-Putaway Location, and then left in Cancel
Pending until actually Putaway.

=cut

use Carp;

use XTracker::Config::Local qw(
    putaway_intransit_type
);
use Module::Runtime 'require_module';

=head1 ATTRIBUTES

=cut

has intransit_type => (
    is => "ro",
    default => sub { putaway_intransit_type() },
);


=head1 CLASS METHODS

=head2 new_by_type() : $new_subclass_object

Factory constructor: Return a new object of the appropriate subclass
according to the config.

=cut

sub new_by_type {
    my ($class,@args) = @_;
    my $concrete_class = __PACKAGE__ . "::" . putaway_intransit_type();
    require_module $concrete_class;
    return $concrete_class->new(@args);
}


=head1 METHODS

=head2 marked_for_putaway_user_message($container_id) : $user_message_string

Return the message for informing the user what to do after the entire
$container_id has been marked for Putaway.

=cut

sub marked_for_putaway_user_message {
    my ($self, $container_row) = @_;
    croak("Abstract");
}

=head2 send_cancelled_shipment_item_to_putaway($shipment_item_row, $operator_row) :

Do the right thing wrt cancelling the $shipment_item_row, moving it to
a Container/Location, notifying the Public Web Site, etc.

=cut

sub send_cancelled_shipment_item_to_putaway {
    my ($self, $shipment_item_row, $operator_row) = @_;
    croak("Abstract");
}

