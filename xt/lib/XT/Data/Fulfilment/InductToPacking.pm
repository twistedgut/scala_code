package XT::Data::Fulfilment::InductToPacking;
use NAP::policy "tt", "class";
with "XTracker::Role::WithSchema";

=head1 NAME

XT::Data::Fulfilment::InductToPacking - The Induction of a Container to Packing

=head1 DESCRIPTION

Inducting a Container to Packing means logically sending it to
Packing. Physically this can be done using a Conveyor, or by having a
runner walk the Container over to the Pack Area.

=head2 Container vs Tote

"Container" is used throughout the code, since that's the object
involved.

The user-facing word for Container in this case is "Tote" (partly
because it's shorter and this is displayed on a handheld screen with
limited space).

=cut

use Carp;
use List::Util qw/ sum /;
use Lingua::EN::Inflect qw/ PL /;

use XT::Data::PRL::PackArea;
use XT::Data::Fulfilment::InductToPacking::Question;
use XT::Data::PRL::Conveyor::Route::ToPacking;

use XTracker::Constants::FromDB qw(
    :allocation_status
    :physical_place
);
use XTracker::Pick::Scheduler;
use XTracker::Config::Local qw( config_var );



=head2 ATTRIBUTES

=head2 is_container_in_cage

Whether the User has checked the "I am in the Cage" or "Container is
in the Cage" checkbox.

This influences which questions the user is asked, and how the
Containers can be inducted.

=cut

has is_container_in_cage => (
    is  => "rw",
    isa => "Bool",
);

=head2 is_force : Bool

Whether the induction is forced through, even if there isn't enough
induction_capacity in the Pack Area.

Default: false

=cut

has is_force => (
    is      => "rw",
    isa     => "Bool",
    default => 0,
);

=head2 return_to_url : URL | undef

Optional (relative) URL to redirect back to when the Container is
inducted. Typically, the Commissioner url.

=cut

has return_to_url => (
    is  => "rw",
    isa => "Str | Undef",
);


=head2 container_row : Result::Container

The Container to induct.

=cut

has container_row => (
    is => "rw",
);

=head2 other_container_rows_ready_for_induction : [ Result::Container ]

Array ref with _other_ Container rows in the same Allocations that are
present in ->container_row.

=cut

has other_container_rows_ready_for_induction => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $container_row = $self->container_row or confess("Internal error");
        return [ $container_row->other_container_rows_ready_for_induction->all ];
    },
);

=head2 pack_area

Default PackArea object.

=cut

has pack_area => (
    is   => "ro",
    lazy => 1,
    default => sub {
        my $self = shift;
        XT::Data::PRL::PackArea->new({ schema => $self->schema });
    },
);

=head2 question : XT::Data::Fulfilment::InductToPacking::Question

The question the User is asked, depending on what's already entered,
along with the User's answer.

=cut

has question => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        return XT::Data::Fulfilment::InductToPacking::Question->new({
            is_multi_tote => $self->is_multi_tote_shipment,
            is_container_in_cage  => $self->is_container_in_cage,
        });
    },
);

has message_factory => (
    is       => "ro",
    required => 1,
);

has operator_id => (
    is       => "ro",
    required => 1,
);

sub can_scan {
    my $self = shift;
    return $self->pack_area->accepts_containers_for_induction;
}



=head1 METHODS

=cut

sub set_is_container_in_cage {
    my ($self, $is_container_in_cage) = @_;
    $self->is_container_in_cage( !! $is_container_in_cage );
}

sub set_is_force {
    my ($self, $is_force) = @_;
    $self->is_force( !! $is_force );
}

sub set_return_to_url {
    my ($self, $return_to_url) = @_;
    $self->return_to_url( $return_to_url );
}

sub set_container_row {
    my ($self, $container_id, $container_barcode) = @_;
    $container_id = NAP::DC::Barcode::Container->new_from_id_or_barcode(
        $container_id,
        $container_barcode,
    ) or return undef;

    my $container_rs = $self->schema->resultset("Public::Container");
    my $container_row = $container_rs->search(
        { "me.id" => $container_id },
        { prefetch => shipment_items => allocation_items => "allocation" },
    )->first or die("Unknown Container ($container_id)\n");

    unless ($container_row->is_ready_for_induction) {
        die("Container $container_id cannot be inducted (it may have outstanding picks, or it may have already been inducted)\n");
    }

    return $self->container_row( $container_row );
}

=head2 check_induction_capacity() : 1 | die

Die if there is no capacity to induct more totes (unless ->is_force).

=cut

sub check_induction_capacity {
    my $self = shift;
    return 1 if ($self->is_force);
    $self->can_scan()
        or die("There is no capacity to induct any totes at the moment, please try later\n");
    return 1;
}

=head2 set_answer_to_question($answer?) : Bool $is_question_answered | die

Set the ->question->answer property from $answer if provided, or from
the default answer if there is one (i.e. if there is only one possible
answer available, go with that).

Return true if the question was answered (either by a passed in value,
or by a single available answer), or false if not. Die on invalid
$answers.

=cut

sub set_answer_to_question {
    my ($self, $answer) = @_;
    my $question = $self->question;
    $answer and $question->answer($answer);
    return !! $self->question->answer();
}

=head2 user_message_ensure_multi_tote_all_present() : $message | undef

If this is a multi-tote shipment, return a user instruction message
(that they should ensure all totes are present), else return undef.

=cut

sub _other_container_ids_string {
    my $self = shift;

    my @other_container_rows = @{$self->other_container_rows_ready_for_induction()}
        or return "";

    return join(", ", sort map { $_->id } @other_container_rows );
}

sub user_message_ensure_multi_tote_all_present {
    my $self = shift;
    my $other_container_ids = $self->_other_container_ids_string or return undef;

    my $container_id = $self->container_row->id;
    return "$other_container_ids must be inducted together with $container_id, please ensure they're all present.";
}

=head2 user_message_fragment_totes() : $message

Return user message fragment representing the tote / totes to induct.

=cut

sub user_message_fragment_totes {
    my $self = shift;
    my $container_id = $self->container_row->id;

    my $other_container_ids = $self->_other_container_ids_string()
        or return "tote $container_id";

    return "tote $container_id AND $other_container_ids";
}

=head2 user_message_instruction($display_pack_area_destination, $contains_triggering_allocation) : $user_message

Return a user message instruction for what to do with the
->container_row or (if there are multiple totes) all other containers
once they're inducted.

E.g. walk the containers to the $route_destination.

This depends on whether any pick messages to triggered PRLs
(e.g. Dematic) will be sent ($contains_triggering_allocation) by the
Pick::Scheduler next time it's run.

=cut

sub user_message_instruction {
    my ($self, $display_pack_area_destination, $contains_triggering_allocation) = @_;

    my $user_message_fragment_totes = $self->user_message_fragment_totes();

    my $user_message;
    if ($self->question->can_be_conveyed) {
        # Yes - can be conveyed
        $user_message = "Please place $user_message_fragment_totes onto the conveyor";
    }
    else {
        # No - can't be conveyed
        $user_message = "Please take $user_message_fragment_totes to $display_pack_area_destination";

        # If we're in the Cage and we just sent pick messages to any
        # fast PRls, the present totes need to remain in the cage
        # until fast picks arrive at the packing station by conveyor
        if ($self->is_container_in_cage && $contains_triggering_allocation) {
            $user_message = "Shipment incomplete, please retain $user_message_fragment_totes in the Cage ready to be fetched to $display_pack_area_destination";
        }
    }

    return $user_message;
}

=head2 is_multi_tote_shipment() : Bool

Whether this is a multi-tote shipment, i.e. there are other Containers
that need inducting as well.

=cut

sub is_multi_tote_shipment {
    my $self = shift;
    return @{$self->other_container_rows_ready_for_induction()} > 0;
}

=head2 induct_containers() : $user_message_instruction

If the answer is suitable, induct the scanned container and possibly
other related containers (if it's a multi-tote allocation). All
containers used to pick the Allocations are inducted.

Inducting the containers include:

  * marking the allocations in the container as picked
  * finding a pack lane for the containers to induct
  * marking it as being on the way to the pack lane
      * if walked over: marking it as already being there
      * if conveyed: sending a route message
  * if there are outstanding picks: sending related pick messages

Return a user message with instructions, e.g. to put the Container(s)
on the Conveyor, or to leave it where it is (if the container(s)
shouldn't be inducted).

=cut

sub induct_containers {
    my $self = shift;

    # If all totes aren't present, we should not induct the tote
    $self->question->should_be_inducted_at_all
        or return "Don't induct this container now. Wait until all containers are present.";

    my @container_rows_to_induct = (
        $self->container_row,
        @{$self->other_container_rows_ready_for_induction},
    );


    # This sets the container.pack_lane_id on all of the Containers if
    # it's going to a PackLane (as opposed to Packing Exception)
    my $route = XT::Data::PRL::Conveyor::Route::ToPacking->new({
        container_rows => \@container_rows_to_induct,
    });
    my $route_destination = $route->get_route_destination()
        or die("The tote could not be assigned a pack lane. Please try again, or talk to a manager.\n");

    my $contains_triggering_allocation =
        !! grep { $self->induct_container($_, $route, $route_destination) }
        @container_rows_to_induct;

    my $display_pack_area_destination = $route->display_route_destination(
        $route_destination,
    );
    return $self->user_message_instruction(
        $display_pack_area_destination,
        $contains_triggering_allocation,
    );
}

sub induct_container {
    my ($self, $container_row, $route, $route_destination) = @_;

    my $container_id = $container_row->id;

    if ($self->question->can_be_conveyed) {
        # The Container will be "in transit" until it arrives at the
        # PackLane. At this point a scanner on the Conveyor will send
        # "route_response", which will mark the Container as "has
        # arrived".
        $route->send_message($container_id, $route_destination);
    }
    else {
        # Pretend we immediately transported the Container to the
        # PackLane.
        #
        # This is a simplification, but the closest approximation to
        # what happens IRL (the runner takes the Container to the
        # PackLane and leaves it in a pile next to it).
        $container_row->maybe_mark_has_arrived();
    }


    # Count this Container towards the Induction Capacity in the Pack
    # Area
    $self->pack_area->decrement_induction_capacity();


    my $contains_triggering_allocation = 0;

    my $pick_scheduler_version = config_var("PickScheduler", "version");
    if( $pick_scheduler_version == 2 ) {
        # Must happen before the container allocations get picked
        my $pick_scheduler = XTracker::Pick::Scheduler->new(
            msg_factory => $self->message_factory,
            operator_id => $self->operator_id,
        );
        # If any allocation of the shipment in the container has a triggering container,
        $contains_triggering_allocation
            = $pick_scheduler->container_has_triggered_allocations(
                $container_row,
            );
    }

    $container_row->pick_staged_allocations($self->operator_id);

    # The induction capacity for these are re-calculated by the
    # PickScheduler and not accounted for here
    if( $pick_scheduler_version == 1 ) {
        # Should happen after the container allocations are picked
        my $fast_pick_count
            = $container_row->trigger_picks_for_related_allocations(
                $self->message_factory,
                $self->operator_id,
            );
        $contains_triggering_allocation = $fast_pick_count;
    }

    $container_row->set_place();
    if($self->is_container_in_cage) {
        $container_row->move_to_physical_place( $PHYSICAL_PLACE__CAGE );
    }

    return $contains_triggering_allocation;
}

sub container_records {
    my $self = shift;
    return $self->schema
        ->resultset("Public::Container")->prepare_induction_page_data;
}

sub shipment_records {
    my $self = shift;
    return [$self->schema->resultset("Public::Shipment")->staged_shipments->all];
}
