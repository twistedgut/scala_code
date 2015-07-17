package XT::DC::Controller::Fulfilment::GOH::Integration;

use NAP::policy 'class';

BEGIN { extends 'Catalyst::Controller' };

use List::Util qw/first/;
use XT::Data::Fulfilment::GOH::Integration;
use XTracker::Constants::FromDB qw/ :prl_delivery_destination /;
use vars qw/
    $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION
    $PRL_DELIVERY_DESTINATION__GOH_DIRECT
/;

=head1 NAME

XT::DC::Controller::Fulfilment::GOH::Integration

=head1 DESCRIPTION

This is a controller for GOH Integration page.

Here is a rough steps users do:

    1) Open 'Fulfilent/GOHIntegration' page and select
        which lane to operate on: 'Direct' or 'Integration'.
    2) 'Fulfilent/GOHIntegration/<LANE_NAME>/view' shows the content
        of selected lane and prompt user to scan a container,
        that could be empty tote or (in case of Integration lane)
        a spcific container from upcoming DCD container queue.
    3) In case when user requires to scan particular container
        and it is missing, user could indicate that by running
        'Fulfilent/GOHIntegration/<LANE_NAME>/missing' action,
        that leads back to 2).
    4) After container successfully scanned by
        'Fulfilent/GOHIntegration/<LANE_NAME>/scan' action
         user is on
        'Fulfilent/GOHIntegration/<LANE_NAME>/container/<CONTAINER_ID>/view'
        page.
    5) If SKU is missing user can indicate it by running
        'Fulfilent/GOHIntegration/<LANE_NAME>/container/<CONTAINER_ID>/missing'
        action that submit SKU as a paramter. As a result user lands
        on 4).
    6) User scan a SKU by running action:
        'Fulfilent/GOHIntegration/<LANE_NAME>/container/<CONTAINER_ID>/scan'
        which leads to 4).
    7) When container is full user mark it as full by action
        'Fulfilent/GOHIntegration/<LANE_NAME>/container/<CONTAINER_ID>/full'
        and lands on page 2).

    Here is URLs supported by current controller:

        /Fulfilment/GOHIntegration/
        /Fulfilment/GOHIntegration/<1>/view
        /Fulfilment/GOHIntegration/<1>/missing
        /Fulfilment/GOHIntegration/<1>/scan
        /Fulfilment/GOHIntegration/<1>/container/<2>/view
        /Fulfilment/GOHIntegration/<1>/container/<2>/missing
        /Fulfilment/GOHIntegration/<1>/container/<2>/scan
        /Fulfilment/GOHIntegration/<1>/container/<2>/full

    where <1> - Lane name, <2> - container ID.

=cut

# Because we have Controller class that does not match the urls
# it handles, we have to override namespace for current controller
__PACKAGE__->config(path => 'Fulfilment/GOHIntegration');
__PACKAGE__->config(abort_chain_on_error_fix => 1);

sub begin : Private {
    my ($self, $c) = @_;

    $c->check_access('Fulfilment', 'GOH Integration');
}

my $LANE_COOKIE_NAME = 'integration_lane';

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    # in case user has preferred lane saved in cookies - redirect
    # there without choosing a lane
    if (
        my $lane_from_cookie = $c->req->cookies->{$LANE_COOKIE_NAME}
        && !$c->req->parameters->{ignore_cookies}
    ) {
        $c->res->cookies->{$LANE_COOKIE_NAME} = undef;
        $c->res->redirect(
            $c->uri_for(
                $c->controller->action_for('view'),
                [ $c->req->cookies->{$LANE_COOKIE_NAME}->value ]
            )
        );
        $c->detach;
    }

    my $prl_delivery_destination_rs = $c->model('DB')->schema
        ->resultset('Public::PrlDeliveryDestination');
    $c->stash(
        map {
            'process_' . $_->message_name =>
                 XT::Data::Fulfilment::GOH::Integration->new( prl_delivery_destination_row => $_ ),
        }
        $prl_delivery_destination_rs->search({
            id => [ $PRL_DELIVERY_DESTINATION__GOH_DIRECT, $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION ]
        })
    );
}

sub get_lane :Chained :PathPrefix :CaptureArgs(1) {
    my ($self, $c, $prl_delivery_destination_id) = @_;

    my $process = XT::Data::Fulfilment::GOH::Integration->new(
        prl_delivery_destination_row => $c->model('DB')->schema
            ->resultset('Public::PrlDeliveryDestination')
                ->find($prl_delivery_destination_id),
    );

    $process->is_container_resumed(1) if $c->req->parameters->{is_container_resumed};

    $c->stash(
        template_type => 'blank',
        process       => $process,
        template      => 'fulfilment/goh/integration/view_lane.tt',
    );
}

sub get_container :Chained(get_lane) :PathPart(container) :CaptureArgs(1){
    my ($self, $c, $container_id) = @_;

    $c->stash->{process}->set_container($container_id);
}

sub view_with_container :Chained(get_container) :PathPart(view) :Args(0){
    my ($self, $c) = @_;
}

sub view :Chained(get_lane) :PathPart(view) :Args(0) {
    my ($self, $c) = @_;

    # save user preferred Lane to the cookies
    $c->res->cookies->{$LANE_COOKIE_NAME} = {
        value => $c->stash->{process}->prl_delivery_destination_row->id,
    };
}

sub scan_sku :Chained(get_container) :PathPart(scan) :Args(0) {
    my ($self, $c) = @_;

    $c->stash->{process}->set_sku(
        $c->req->parameters->{sku}
    );

    $c->forward($self, '_scan');
}

sub scan_container :Chained(get_lane) :PathPart(scan) :Args(0){
    my ($self, $c) = @_;

    $c->stash->{process}->set_container(
        $c->req->parameters->{container},
        'scan'
    );
    $c->forward($self, '_scan');
}

sub mark_as_full :Chained(get_container) :PathPart(full) :Args(0) :POST {
    my ($self, $c) = @_;

    my $process = $c->stash->{process};
    $process->mark_container_full({
        operator_id => $c->session->{operator_id},
    });

    $c->res->redirect(
        $c->uri_for($self->action_for('view'), [$process->delivery_destination_id])
    );
    $c->detach;

    return;
}

sub missing_container :Chained(get_lane) :PathPart(missing) :Args(0) :POST {
    my ($self, $c) = @_;

    my $process = $c->stash->{process};

    $process->transform_missing_container_into_empty({
        missing_container_id => NAP::DC::Barcode::Container::Tote->new_from_id(
                                    $c->req->parameters->{container_id}
                                ),
        empty_container_id   => NAP::DC::Barcode::Container::Tote->new_from_id(
                                    $c->req->parameters->{empty_container_id}
                                ),
    });

    $c->res->redirect(
        $c->uri_for(
            $self->action_for('view_with_container'),
            [$process->delivery_destination_id, $c->req->parameters->{empty_container_id}],
            { is_container_resumed => 1 }
        )
    );


    $c->detach;

    return;
}

sub missing_sku :Chained(get_container) :PathPart(missing) :Args(0) {
    my ($self, $c) = @_;

    my $process = $c->stash->{process};

    $process->set_sku(
        $c->req->parameters->{sku}
    );

    $process->mark_missing_sku;

    $c->res->redirect(
        $c->uri_for(
            $self->action_for('view_with_container'),
            [$process->delivery_destination_id, $process->container_id]
        )
    );
    $c->detach;

    return;
}

sub remove_sku_from_container :Chained(get_container) :PathPart(remove_sku) :Args(0) :POST {
    my ($self, $c) = @_;

    my $process = $c->stash->{process};

    $process->remove_sku_from_container(
        $c->req->parameters->{sku}
    );

    $c->res->redirect(
        $c->uri_for(
            $self->action_for('view_with_container'),
            [$process->delivery_destination_id, $process->container_id]
        )
    );
    $c->detach;

    return;
}

=head2 _scan($c) : undef

Common logic for scanning action. This should be called after
process has submitted data.

=cut

sub _scan {
    my ($self, $c) = @_;

    my $process = $c->stash->{process};

    $process->commit_scan;

    $c->res->redirect(
        $c->uri_for(
            $self->action_for('view_with_container'),
            $process->next_action_args,
        )
    );

    $c->detach;

    return;
}

=pod

While processing actions in current controller there could be
exceptions both known and unknown. Catalyst places them into
$c->error.

Following structure maps error handlers to exception classes
we are aware of.

Unknown errors are displayed on the current page.

=cut

my $report_error_as_fatal = sub {
    my ($c, $e) = @_;

    $c->feedback_fatal($e);
};

my %known_errors = (
    # Thrown when user scanned invalid container barcode
    'NAP::DC::Exception::Barcode' => $report_error_as_fatal,
    # Thrown after user scanned SKU that is not expected to be on
    # current lane
    'XT::Exception::Data::Fulfilment::GOH::Integration::UnknownSku'                 => $report_error_as_fatal,
    'XT::Exception::Data::Fulfilment::GOH::Integration::NoIntegrationContainer'     => $report_error_as_fatal,
    'XT::Exception::Data::Fulfilment::GOH::Integration::ContainerIsEmpty'           => $report_error_as_fatal,
    'XT::Exception::Data::Fulfilment::GOH::Integration::ContainerIsAlreadyComplete' => $report_error_as_fatal,
    'XT::Exception::Data::Fulfilment::GOH::Integration::MixGroupMismatch'           => $report_error_as_fatal,
    'XT::Exception::Data::Fulfilment::GOH::Integration::UnexpectedContainer'        => $report_error_as_fatal,
    'XT::Exception::Data::Fulfilment::GOH::Integration::InvalidSkuBarcode'          => $report_error_as_fatal,
    'XT::Exception::Data::Fulfilment::GOH::Integration::ScanRoutedContainer'        => $report_error_as_fatal,
    'XT::Exception::Data::Fulfilment::GOH::Integration::AttemptToUseDCDContainerAtDirectLane' => $report_error_as_fatal,
    # Failure of Moose type constraint. It has special case for
    # process's type attribute
    'Moose::Exception::ValidationFailedForInlineTypeConstraint'=> sub{
        my ($c, $e) = @_;

        if (
            $e->attribute_name eq 'prl_delivery_destination_row' &&
            $e->class_name eq 'XT::Data::Fulfilment::GOH::Integration'
        ) {
            $c->feedback_warn('Unknown GOH lane');
        } else {
            $c->feedback_warn("$e");
        }
        $c->res->redirect(
            $c->uri_for(
                $c->controller->action_for('index'), [], {ignore_cookies => 1}
            )
        );
        $c->detach;
    },
    UNKNOWN => sub {
        my $c = shift;
        $c->feedback_warn('Got unkown error: ');
        $c->feedback_warn("$_") foreach @{$c->error};
        $c->clear_errors;
        $c->res->redirect(
            $c->uri_for( $c->controller->action_for('index'), [] )
        );
        $c->detach;
    },
);


=head2 end

Handle fatal errors occurred during request.

If more then one known fatal error occurred (though it should not
happened as we have 'abort_chain_on_error_fix' set) only one
handler is run.

Before running error handler for particular error - rest of
errors (if exist) are removed.

If fatal error is not known - generic handler is called.

=cut

sub end :Private {
    my ($self, $c) = @_;

    # ignore this method if there is no fatal errors
    return $c->forward('XT::DC::View::TT') unless @{ $c->error };

    # check if occurred error is known
    my $error = first { exists $known_errors{ref $_} } @{$c->error};

    if ($error) {
        $c->clear_errors;
        $known_errors{ref $error}->($c, $error);
    } else {
        $known_errors{UNKNOWN}->($c);
    }

    $c->forward('XT::DC::View::TT');
}
