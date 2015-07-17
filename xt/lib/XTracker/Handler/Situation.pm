package XTracker::Handler::Situation;

use strict;
use warnings;

use Perl6::Export::Attrs;

use URI;
use URI::QueryParam;
use XTracker::Handler;
use XTracker::Error;
use XTracker::Utilities qw( strip );

=head1 Introduction

This is an attempt to abstract arguments capture and validation out of individual handlers
and into a common class, so that they can be handled consistently ana completely, and so
that policy, sanitization, error dispatch and similar operations can be specified in
one place, rather than ad-hocly across many. In particular, it's intended to make
handlers that move through several states more straightforward, by encapsulating
common operations, and providing a way to describe the relationships between states.

=head2 Approach

Each handler that expects to acquire and process arguments, in particular those
that refer to things already in the database, may declare which parameters it wants,
and what kind of object they're expected to refer to.

=head2 Initialization

The call to C<Situation->new()> must be provided with a hashref of args, which can be:

=over 4

=item situations

This is a ref to a set of I<situation> hashes, the keys of which name all the
situations we know about; see later for what each value in this hash may contain.
This is required.

=item parameters

This is a ref to a hash of parameter definitions, the keys of which are the
names of the parameters as passed in through a POST or GET request.
This is required.

=item handler

This is the C<$handler> object, made available to any XTracker Handler.
This is required.

=item validators

This is a ref to a hash of validation definitions, the keys of which must match
the parameter names to be validated.  Not all parameters require validation, but
any validator whose key does not match a parameter will never be used.
This is optional.

=item redirect_on_fail_default

This is a URL to be used for redirection when no other redirection URL is
available, but redirection away from this page is required.
This is optional.

=item situation_param_name

This is the name of the parameter to be captured from the query string,
or from POSTed values, that names the current situation.  This is optional,
and defaults to I<situation>.  It is ignored in the case where only
a single situation is defined, since there is no choice to make.

=back

A I<situation> is a named state that a handler can process; if there is more
than one state for the handler, this must be provided in the parameter C<situation>.

The I<situation> is a key into the hashref, C<situations>.

=head2 Examples

=head3 Single-state handler

A single-state handler, one which always processes its arguments the
same way, can be implemented as follows.

(This code is derived from C<XTracker::Order::Fulfilment::RetryShipment>).

=over 4

=item Set up the situation definitions

    my $situations = {
        'retryShipment' => {
            fancy_name     => 'Retry Shipment',
            check_we_have  => [ qw( shipment_id ) ],
            redirect_on_fail => '/Fulfilment/Packing/CheckShipmentException',
        },
    };

This declares that we must get a I<shipment_id>, and also the
URL we bounce to if things go horribly wrong while trying to
fetch or validate this parameter. The I<fancy_name> is how this
situation will be described to in any messages that refer to it.

I<fancy_name> and I<check_we_have> are required.

=item Define the parameter we want


    my $parameters = {
        shipment_id      => { fancy_name => 'shipment',
                              model_name => 'Public::Shipment',
                            }
    };

Here, C<shipment_id> is the query string/form parameter we're
going to capture, and we want it to match an object from the
database associated with the model C<Public::Shipment>; in
other words, a shipment.  The method C<find_by_model_id> is
passed the I<model_name> and the value of the parameter,
and is expected to return an object, or die trying.

The I<fancy_name> is how this parameter will be described
in any error messages that refer to it, and is required.

=item Define any validation after it's been fetched from the DB


    my $validators = {
        shipment_id => sub {
            my ($shipment,$checked_objects) = @_;

            die "Shipment still contains items to be dealt with at Packing Exception\n"
                unless $shipment->is_packing_exception_completed;
        }
    };

After fetching the shipment from the DB, we also want to check
that the shipment does not have any outstanding packing exception
items before we can declare it acceptable for use. So, we define
this validator, named to match the parameter (C<shipment_id>),
which performs that check.

Validators are expected to die with any problems they find, so
there is no need for them to return a true value on success.

=item Evaluate the situation

The start of the handler now looks like this:

    sub handler {
        my $r           = shift;
        my $handler     = XTracker::Handler->new($r);


        my ($situation,$bounce);

        eval {
            $situation = XTracker::Handler::Situation->new(
                             { situations => $situations,
                               parameters => $parameters,
                               validators => $validators,
                               redirect_on_fail_default => '/Fulfilment/PackingException',
                               handler    => $handler
                             }
                         );

            $bounce=$situation->evaluate;
        };

At the top of the handler itself, this code is enough to capture
the C<shipment_id>, strip it, canonicalize it, fetch the
shipment object through the C<Public::Shipment> model,
validate it, and stash it in the C<$situation> object for later use.

=item Decide if we should continue or redirect

        if ($@) {
            xt_warn($@);

            return $handler->redirect_to($redirect_default);
        }

        return $handler->redirect_to($bounce) if $bounce;

I<evaluate> dies if it encounters a problem, returns a URL
to redirect to if that's the correct post-validation action,
otherwise it returns false.

=item Now do the handler-specific work

At this point, the shipment object, for the C<shipment_id> we
were passed, is available by name (C<shipment_id>) via the
C<get_checked_objects> method...

        my $shipment = $situation->get_checked_objects('shipment_id');

    [...rest of handler here...]

And the rest of the handler is whatever it's supposed to be.

=back

=head3 Multi-state handler

A multi-state handler, which captures a series of parameters over a number
of passes through the same handler, can be implemented as follows.

(This code is derived from C<XTracker::Order::Fulfilment::ScanOutPEItem>).

=over 4

=item Set up the situation definitions


    my $situations = {
        'removeFaulty' => {
            fancy_name     => 'Scan SKU of Faulty Item',
            check_we_have  => [ qw( shipment_id shipment_item_id ) ],
            next_situation => 'removeFaulty.handleSKU',
        },
        'removeFaulty.handleSKU' => {
            fancy_name     => 'Scan Container for Faulty Item',
            check_we_have  => [ qw( shipment_id shipment_item_id sku ) ],
            next_situation => 'removeFaulty.handleContainer',
        },
        'removeFaulty.handleContainer' => {
            fancy_name      => 'Remove Faulty Item',
            check_we_have   => [ qw( shipment_id shipment_item_id sku container_id ) ],
            continue_url    => '/Fulfilment/Packing/ScanFaultyItem',
            continue_params => [ qw( shipment_id shipment_item_id     container_id ) ],
        }
    }

This is similar to the single-state version, except we now have three states
the handler can exist in.  Consequently, we also have to specify what the
current situation is via the I<situation> parametere in the page request.

The above specifies three situations: on the first, we expect to receive
a C<shipment_id> and a C<shipment_item_id>, on the second, we expect
those plus a C<sku>, and on the third, those plus a C<container_id>.
The first two situations each point to the next one via the C<next_situation>
value, while the last situation specifies a redirect to be taken, and
the parameters that should be passed to it.

As with the single-state situation, I<fancy_name> and I<check_we_have> are required
for each situation definition. Additionally, either I<next_situation> or
I<continue_url> should be provided, otherwise there will be no way to
know what comes after the current situation is successfully processed.


=item Define the parameters we want

    my $parameters = {
        shipment_id      => { fancy_name => 'shipment',
                              model_name => 'Public::Shipment',
                            },
        shipment_item_id => { fancy_name => 'shipment item',
                              model_name => 'Public::ShipmentItem',
                              redirect_on_fail =>'/Fulfilment/Packing/CheckShipmentException',
                            },
        sku              => { fancy_name => 'SKU',
                              redirect_on_fail => '',
                            },
        container_id     => { fancy_name => 'container/tote',
                              get_object => sub { get_container_by_id ( @_ ); },
                              redirect_on_fail => '',
                            }
    }

The I<shipment_id> and I<shipment_item_id> parameters use a DB fetch
through their respective models to get corresponding objects, as
in the simple case earlier. I<SKU>, on the other hand, is just a
text string, so neither of I<model_name> or I<get_object> attributes
is specified, in which case the cleaned-up value of the parameter
is returned.

I<container_id> is a special case, in that just asking about a
container for the first time brings the corresponding database record
into existence.

Consequently, a more generic C<get_object> method is defined,
which is passed two parameters:

=over 4

=item schema

the I<schema> object from the I<handler> that was used to instantiate the I<situation>
object

=item value

the value of the parameter that has defined this C<get_object> method

=back

The I<get_object> method is expected to return the appropriate object,
or C<die> trying.

As with the single-state situation, I<fancy_name>s,
defining how each parameter will be described in any
error messages that refer to it, are required.


=item Define any validation after it's been fetched from the DB

    my $validators = {
        shipment_item_id => sub {
            my ($item,$checked_objects) = @_;

            die "That shipment item is not in this shipment\n"
                unless $checked_objects->{shipment_id}->id == $item->shipment_id;
        },

        sku => sub {
            my ($sku,$checked_objects) = @_;

            die "SKU $sku does not match the target item's SKU\n"
                unless $checked_objects->{shipment_item_id}->get_sku eq $sku;
        },

        container_id => sub {
            my ($container,$checked_objects) = @_;

            die "May not put faulty item into that container; please scan another\n"
                unless $container->accepts_faulty_items;
        }
    }

If the shipment object specified by I<shipment_id> exists, no further checking is
needed for this handler. Hence, no validator is specified for C<shipment_id>.

However, we do want to check that the shipment contains the shipment item, so
there is a validator for the C<shipment_item_id> that performs that check. It's
able to do that, because the parameters are processed in the order specified in
the situation's C<check_we_have> list, so by the time the validator is invoked
for the C<shipment_item_id>, we know the I<shipment> object has already been
successfully fetched and stashed in the situation's I<checked_objects> hash.

Similarly, the I<SKU> validator can rely on there being a validated I<shipment_item>
object in I<checked_objects>.

=item Evaluate the situation

As with the single-state case, the start of the handler looks like this:

    sub handler {
        my $r           = shift;
        my $handler     = XTracker::Handler->new($r);

        my ($situation,$bounce);

        eval {
            $situation = XTracker::Handler::Situation->new(
                             { situations => $situations,
                               parameters => $parameters,
                               validators => $validators,
                               redirect_on_fail_default => '/Fulfilment/PackingException',
                               handler    => $handler
                             }
                         );

            $bounce=$situation->evaluate;
        };

At the top of the handler itself, this code is enough to capture
the C<shipment_id>, strip it, canonicalize it, fetch the
shipment object through the C<Public::Shipment> model,
validate it, and stash it in the C<$situation> object for later use.

=item Decide if we should continue or redirect

        if ($@) {
            xt_warn($@);

            return $handler->redirect_to('/Fulfilment/PackingException');
        }

        return $handler->redirect_to($bounce) if $bounce;

I<evaluate> dies if it encounters a problem, returns a URL
to redirect to if that's the correct post-validation action,
otherwise it returns false.

Note that the initialization and evalulation of the situation,
and dealing with the results of it, are identical to the
single-state case earlier.

=item Now do the handler-specific work

At this point, the shipment and shipment_item objects
for the C<shipment_id> and C<shipment_item_id> we were passed,
as well as the cleaned-up SKU provided via C<sku>, are available
by name via the C<get_checked_objects> method...

        my ($shipment,$shipment_item,$sku) = $situation
                                               ->get_checked_objects(
                                                  qw( shipment_id shipment_item_id sku )
                                                 );

    [...rest of handler here...]

And the rest of the handler is whatever it's supposed to be.

=cut


# hey, maybe I could do this in Moose at some point

sub new {
    my ($class, $args)=@_;
    my $self = bless {}, $class;

    foreach my $required (qw( situations parameters handler )) {
        die "BUG: Must provide '$required' parameter"
            unless exists $args->{$required} && $args->{$required};

        $self->{$required} = delete $args->{$required};
    }

    foreach my $optional (qw( validators redirect_on_fail_default situation_param_name )) {
        if (exists $args->{$optional}) {
            $self->{$optional} = delete $args->{$optional};
        }
    }

    if (keys %{$args}) {
        # egad, I'm pedantic
        if (keys %{$args} == 1) {
            warn "Unrecognized parameter '".((keys %{$args})[0])."' provided -- IGNORED\n";
        }
        else {
            warn "Unrecognized parameters '".join("','",sort keys %{$args})."' provided -- IGNORED\n";
        }
    }

    $self->{situation_param_name} ||= 'situation'; # friendly default

    my @situation_keys = keys %{$self->{situations}};

    if (@situation_keys == 1) {
        # only one thing we can be doing, let's do that
        $self->{situation_name} = $situation_keys[0];

        if (my $provided_situation_name = strip($self->{handler}->{param_of}{$self->{situation_param_name}})) {
            warn "BUG: provided value for 'situation_param_name', ($provided_situation_name), does not match the only situation"
              unless $self->{situation_name} eq $provided_situation_name;
        }
    }
    else {
        $self->{situation_name} = strip($self->{handler}->{param_of}{$self->{situation_param_name}});
    }

    die "You must specify an action via '$self->{situation_param_name}'"
        unless $self->{situation_name};

    $self->{situation} = $self->{situations}->{ $self->{situation_name} };

    die "Action ".$self->{situation_name}." not recognized"
        unless $self->{situation};

    $self->{checked_objects}={};
    $self->{ok_to_proceed}='';
    $self->{redirect_to}=$self->{redirect_on_fail_default} || '';

    # at this point, the following hash keys are set up:
    #
    # + provided parameters:
    #
    #   situations
    #   parameters
    #   handler
    #   validators
    #   redirect_on_fail_default
    #   situation_param_name
    #
    # + derived parameter:
    #
    #   situation_name
    #
    # + persistent state objects:
    #
    #   checked_objects
    #   ok_to_proceed
    #   redirect_to
    #

    return $self;
}

sub _get_checkee {
    my ($self,$checkee_name) = @_;

    die "Unable to determine what to check\n"
        unless $checkee_name && exists $self->{parameters}->{$checkee_name};

    return $self->{parameters}->{$checkee_name};
}

sub _find_by_model_id {
    my ($self,$model,$id) = @_;

    # presume that any ID ought to be only an integer
    # -- impose that rule here, until we know better

    die "ID '$id' is not an integer\n"
        unless $id =~ m{\A\d+\z}xms;

    return $self->{handler}->{schema}->resultset( $model )->find( { id => $id } );
}

sub _make_redirect {
    my ($self,$url,@param_names) = @_;

    my $redirect = URI->new( $url, 'http' );

    foreach my $param_name ( @param_names ) {
        if ( exists $self->{checked_objects}->{$param_name} ) {
            $redirect->query_param( $param_name => ref $self->{checked_objects}->{$param_name}
                                                     ? $self->{checked_objects}->{$param_name}->id
                                                     : $self->{checked_objects}->{$param_name}
                                  );
        }
    }

    return $redirect;
}

sub _find_best_redirect {
    my ($self,$checkee_name) = @_;

    my $checkee=$self->_get_checkee($checkee_name);

    if (exists $checkee->{redirect_on_fail}) {
        return unless $checkee->{redirect_on_fail};

        return $self->_make_redirect( $checkee->{redirect_on_fail},
                                      sort keys %{$self->{checked_objects}} );
    }

    return $self->{redirect_on_fail_default};
}

sub _get_parameter {
    my ($self,$checkee_name) = @_;

    # we alias the param_of key to the checkee_name
    my $checkee=$self->_get_checkee($checkee_name);

    my $checkee_value = strip( $self->{handler}->{param_of}{$checkee_name} );

    die "You must provide a valid $checkee_name\n"  unless $checkee_value;

    my $checkee_obj;

    if (exists $checkee->{get_object}) {
        $checkee_obj = $checkee->{get_object}($self->{handler}->{schema},$checkee_value);
    }
    elsif (exists $checkee->{model_name}) {
        $checkee_obj = $self->_find_by_model_id($checkee->{model_name}, $checkee_value );
    }
    else {
        # just the value will do

        return $checkee_value;
    }

    # Check it maps to a real DB object

    die "Couldn't find ".$checkee->{fancy_name}." with ID $checkee_value\n"
        unless $checkee_obj;

    return $checkee_obj;
}

sub _validate_parameter {
    my ($self,$checkee_name,$checkee_obj) = @_;

    if (exists $self->{validators}->{$checkee_name}) {
        $self->{validators}->{$checkee_name}(
            $checkee_obj,$self->{checked_objects},$self->{handler});
    }

    return 1;
}

sub _save_checked_object {
    my ($self,$name,$value) = @_;

    if ($self->_validate_parameter($name,$value)) {
        $self->{checked_objects}->{$name} = $value;
    }
}

sub evaluate :Export(:DEFAULT) {
    my $self = shift;

    $self->{ok_to_proceed}=1;
    $self->{redirect_to} = '';

    my $situation=$self->{situation};

  SITCHECK:
    foreach my $checkee_name ( @{$situation->{check_we_have}} ) {
        my $checkee_object;

        eval {
            $checkee_object = $self->_get_parameter( $checkee_name );
        };

        if ($@) {
            xt_warn($@);

            $self->{redirect_to} = $self->_find_best_redirect($checkee_name);

            $self->{ok_to_proceed}='';

            last SITCHECK;
        }

        eval {
            $self->_save_checked_object( $checkee_name, $checkee_object );
        };

        if ($@) {
            xt_warn($@);

            $self->{ok_to_proceed}='';

            last SITCHECK;
        }
    }

    if ( $self->{ok_to_proceed} && exists $situation->{continue_url} ) {
         $self->{redirect_to}= $self->_make_redirect(   $situation->{continue_url},
                                                      @{$situation->{continue_params}});
    }

    return $self->{redirect_to};
}

sub fancy_name     :Export(:DEFAULT) { return shift->{situation}->{fancy_name}; }
sub this_situation :Export(:DEFAULT) { return shift->{situation_name}; }

sub next_situation :Export(:DEFAULT) {
    my $self = shift;

    return $self->{ok_to_proceed} ? $self->{situation}->{next_situation}
                                  : $self->this_situation
                                  ;
}

sub get_checked_objects :Export(:DEFAULT) {
    my ($self,@names) = @_;

    if (wantarray) {
        return @{$self->{checked_objects}}{ @names };
    }
    else {
        return   $self->{checked_objects}->{$names[0]};
    }
}

1;
