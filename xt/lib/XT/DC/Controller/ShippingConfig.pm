package XT::DC::Controller::ShippingConfig;
use NAP::policy qw(tt class);
use DateTime::Duration;
use DateTime::Format::Duration;
use DateTime::Format::Strptime;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' }

# Default to JSON
__PACKAGE__->config(default => 'application/json');

sub index :Path('') :Args(0) {
    my ($self, $c) = @_;

    $c->response->body( "ShippingConfig service is serving" );
}

sub begin : Private {
    my ($self, $c) = @_;

    # Check access
    $c->check_access('Admin', 'ShippingConfig');
    $c->forward('deserialize');
}

sub deserialize : ActionClass('Deserialize') {}

sub processing_times :Local :ActionClass('REST') {}

sub wms_priorities :Local :ActionClass('REST') {}

sub earliest_selection :Local :ActionClass('REST') {}

=head2 processing_times_GET

Handler for RESTful GET calls to ShippingConfig/processing_times.
Retrieves processing time config data.

=cut

sub processing_times_GET {
    my ($self, $c) = @_;

    my $json = {
        payload =>  {},
    };

    # Processing time config
    for my $processing_time ($c->model('DB::SOS::ProcessingTime')->all) {
        my $type = $processing_time->type;
        my $name = $processing_time->name;
        my $time = $processing_time->processing_time->in_units('minutes');
        my $id = $processing_time->id;

        $json->{payload}->{$id}->{name} = $name;
        $json->{payload}->{$id}->{type} = $type;
        $json->{payload}->{$id}->{processing_time} = $time;

        # Overrides

        # So there are two kinds of overrides: those defined against
        # shipment classes and those defined in
        # sos.processing_time_overrides

        # See if this "type" has an override property,
        # else it doesn't

        $json->{payload}->{$id}->{overrides_all} = $processing_time->overrides_all;


        # See if this processing time has any "classic" overrides
        my @overrides = $processing_time->search_related(
            'processing_time_override_major_ids'
        )->all;

        my @these_overrides = map { $_->minor->name } @overrides;
        $json->{payload}->{$id}->{overrides} = [ @these_overrides ];
    }

    $c->stash(json => $json);
    $c->forward('/serialize');
}

=head2 processing_times_POST

Handler for RESTful POST calls to ShippingConfig/processing_times.
Updates processing time config data.

=cut

sub processing_times_POST {
    my($self, $c) = @_;

    my $json = {
        payload =>  {},
    };

    my $params = $c->req->body_data;

    for my $key ( keys %{$params//{}} ) {
        # Undefine if the value contains only whitespace characters
        # (or the empty string)
        if ($params->{$key} =~ m/^\s*$/) {
            $params->{$key} = undef;
        }
    }

    my $row_id = $params->{id};
    my $new_time = $params->{processing_time};

    # Validate parameters
    unless(defined($row_id) && $row_id =~ m/^\d+$/) {
        $self->_bad_request_error($c, "Invalid parameter: id");
    }

    unless(defined($new_time)) {
        $self->_bad_request_error($c, "Undefined parameter: time");
    };

    if ($new_time =~ m/\D/) {
        $self->_bad_request_error($c, "Non-integer parameter: time");
    }

    # Guard against silly duration values
    # (reject processing times of more than a thousand days)
    if (int($new_time > 1440000)) {
        $self->_bad_request_error($c, "time parameter outside of \
            accepted range");
    }

    my $schema = $c->model('DB')->schema;
    my $processing_time = $schema->resultset('SOS::ProcessingTime')->find($row_id);

    unless(defined($processing_time)) {
        $self->_bad_request_error($c, "Nonexistent row-id: $row_id");
    }

    $processing_time->update({
     "processing_time" => DateTime::Duration->new( minutes => $new_time ),
    });
    $json->{params} = $params;
    $c->stash(json => $json);
    $c->forward('/serialize');
}

=head2 wms_priorities_GET

Handler for RESTful GET calls to ShippingConfig/wms_priorities.
Retrieves WMS priority config data.

=cut

sub wms_priorities_GET {
    my ($self, $c) = @_;

    my $json = {
        payload =>  {},
    };


    # WMS priority config
    for my $wms_priority ($c->model('DB::SOS::WmsPriority')->all) {
        my $type = $wms_priority->type;
        my $name = $wms_priority->name;
        my $priority = $wms_priority->wms_priority;
        my $bumped_priority = $wms_priority->wms_bumped_priority;
        my $bumped_interval = $wms_priority->bumped_interval;
        if ($bumped_interval) {
            $bumped_interval = $bumped_interval->in_units('minutes');
        }
        my $id = $wms_priority->id;

        $json->{payload}->{$id}->{name} = $name;
        $json->{payload}->{$id}->{type} = $type;
        $json->{payload}->{$id}->{initial_priority} = $priority;
        $json->{payload}->{$id}->{bumped_priority} = $bumped_priority // undef;
        $json->{payload}->{$id}->{bumped_interval} = $bumped_interval;
    }

    $c->stash(json => $json);
    $c->forward('/serialize');
}

=head2 wms_priorities_POST

Handler for RESTful POST calls to ShippingConfig/wms_priorities.
Updates WMS priority config data.

=cut

sub wms_priorities_POST {
    my ($self, $c) = @_;

    my $json = {
        payload =>  {},
    };


    my $params = $c->req->body_data;

    for my $key ( keys %{$params//{}} ) {
        # Undefine if the value contains no non-whitespace characters
        if ($params->{$key} =~ m/^\s*$/) {
            $params->{$key} = undef;
        # If the value isn't an integer, error
        } elsif ($params->{$key} =~ m/\D/) {
            $self->_bad_request_error($c, "Non-integer parameter $key");
        }
    }

    # the row ID and initial priority are required,
    # or the update will fail
    unless(defined($params->{id})) {
        $self->_bad_request_error($c, "Undefined parameter: id");
    }

    unless(defined($params->{initial_priority})) {
        $self->_bad_request_error($c, "Undefined parameter: initial_priority");
    }

    my $schema = $c->model('DB')->schema;
    my $wms_priority = $schema->resultset('SOS::WmsPriority')->find($params->{id});
    unless(defined($wms_priority)) {
        $self->_bad_request_error($c, "Nonexistent row-id: $params->{id}");
    }

    $wms_priority->update({
     "wms_priority" => $params->{initial_priority},
     "wms_bumped_priority" => $params->{bumped_priority},
     "bumped_interval" => defined($params->{bumped_interval})
        ? DateTime::Duration->new( minutes => $params->{bumped_interval} )
        : undef ,
    });

    $json->{params} = $params;
    $c->stash(json => $json);
    $c->forward('/serialize');
}

=head2 earliest_selection_GET

Handler for RESTful GET calls to ShippingConfig/earliest_selection.
Retrieves earliest selection time config data.

=cut

sub earliest_selection_GET {
    my ($self, $c) = @_;

    my $json = {
        payload =>  {},
    };

    # earliest selection times config
    for my $pickup_time ($c->model('DB::Public::Carrier')->all) {
        my $name = $pickup_time->name;
        my $time = $pickup_time->last_pickup_daytime;
        my $id   = $pickup_time->id;

        my $formatter = DateTime::Format::Duration->new(
            pattern => '%H:%M',
            normalize => 1,
        );

        $json->{payload}->{$id}->{name} = $name;
        $json->{payload}->{$id}->{time} = $formatter->format_duration($time);
    }

    $c->stash(json => $json);
    $c->forward('/serialize');
}

=head2 earliest_selection_POST

Handler for RESTful POST calls to ShippingConfig/earliest_selection.
Updates earliest selection time config data.

=cut

sub earliest_selection_POST {
    my ($self, $c) = @_;

    my $json = {
        payload =>  {},
    };

    my $params = $c->req->body_data;

    my $row_id = $params->{id};
    my $new_time = $params->{time};
    # Validate parameters
    unless (defined($row_id)) {
        $self->_bad_request_error($c, "Undefined Parameter id");
    }

    unless (defined($new_time)) {
        $self->_bad_request_error($c, "Undefined Parameter time");
    }

    # Validate
    my $validator = DateTime::Format::Strptime->new(
        pattern     =>  '%R',
        on_error    =>  'croak'
    );

    try {
        $validator->parse_datetime($new_time);
    } catch {
        $self->_bad_request_error($c, "Invalid time format");
    };

    # Format
    my $formatter = DateTime::Format::Duration->new(
        pattern => '%H:%M',
        normalize => 1,
    );

    $new_time = $formatter->parse_duration($new_time);

    my $schema = $c->model('DB')->schema;
    my $earliest_selection = $schema->resultset('Public::Carrier')->find($row_id);

    unless(defined($earliest_selection)) {
        $self->_bad_request_error($c, "Nonexistent row id");
    }

    $earliest_selection->update({
     "last_pickup_daytime" => $new_time,
    });
    $json->{params} = $params;
    $c->stash(json => $json);
    $c->forward('/serialize');

}

=head2 _bad_request_error

Sets the request's status call and error message, sets a corresponding message
for the REST return value, and detaches

=cut

sub _bad_request_error {
    my ($self, $c, $message) = @_;

    $self->status_bad_request($c, message => $message);
    $c->stash->{rest} = { error => $message };
    $c->detach;
    return undef;
}

1;
