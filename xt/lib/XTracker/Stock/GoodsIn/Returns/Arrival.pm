package XTracker::Stock::GoodsIn::Returns::Arrival;

use strict;
use warnings;

use Data::Dump 'pp';
use URI;
use Try::Tiny;

use XTracker::Error;
use XTracker::Handler;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    if ( $handler->method eq 'POST' ) {
        my $redirect_uri;
        try {
            $redirect_uri = process_post($handler)
        }
        catch {
            xt_warn("Failed POST in Returns Arrival: $_");
            $redirect_uri = delivery_uri();
        };
        return $handler->hh_redirect_to($redirect_uri)
    }

    # We have to have a return arrival id if we get here
    my $return_arrival_id = extract_return_arrival_id($handler->uri);
    unless ( $return_arrival_id ) {
        xt_warn(sprintf q{Invalid return arrival id '%s'}, $return_arrival_id//q{});
        return $handler->hh_redirect_to(
            delivery_uri($handler->{param_of}{return_delivery_id})
        );
    }

    # Get the category and pass it to the template
    my $return_arrival
        = $handler->schema->resultset('Public::ReturnArrival')->find($return_arrival_id);
    unless ($return_arrival) {
        xt_warn("Couldn't find return arrival $return_arrival_id");
        return $handler->hh_redirect_to(delivery_uri());
    }

    $handler->add_to_data({
        return_arrival => $return_arrival,
        content        => 'stocktracker/goods_in/returns_in/arrival.tt',
        section        => 'Goods In',
        subsection     => 'Returns Arrival',
    });

    if ( !$handler->is_viewed_on_handheld ) {
        push @{ $handler->{data}{sidenav}[0]{None} },
            {
                title => 'Search Arrivals',
                url   => '/GoodsIn/ReturnsArrival/Search',
            },
            {
                title => 'New Delivery',
                url   => '/GoodsIn/ReturnsArrival/Delivery',
            };
    }

    return $handler->process_template;
}

=head2 extract_return_arrival_id($uri) : $return_arrival_id

Extract the return_arrival id from the given L<URI> object.

=cut

sub extract_return_arrival_id {
    my $uri = shift;
    my ($id) = [$uri->path_segments]->[-1] =~ m{(^\d+$)};
    return $id;
}

=head2 delivery_uri($id?) : $return_delivery_uri

Return a URI object for the return delivery page - C<$id> is optional and just
returns the landing page when not provided.

=cut

sub delivery_uri {
    my ($id) = @_;
    return URI->new(sprintf('/GoodsIn/ReturnsArrival/Delivery%s', $id ? "/$id" : q{}));
}

=head2 arrival_uri($id?) : $return_arrival_uri

Return a URI object for the return arrival page - C<$id> is optional and just
returns the landing page when not provided.

=cut

sub arrival_uri {
    my ($id) = @_;
    return URI->new(sprintf('/GoodsIn/ReturnsArrival/Arrival%s', $id ? "/$id" : q{}));
}

=head2 process_post($handler) : $redirect_uri

Process the post and return a L<URI> object that we can redirect to.

=cut

sub process_post {
    my $handler = shift;

    my $param = $handler->{param_of};

    my $action = $param->{action};
    unless ( $param->{action} ) {
        xt_warn('Nothing to do!');
        return delivery_uri();
    }

    my $schema = $handler->schema;

    # The user inputted an airway bill
    if ( $action eq 'create' ) {
        return add_arrival({
            uri                => $handler->uri,
            schema             => $schema,
            awb                => $param->{awb},
            return_delivery_id => $param->{return_delivery_id},
            operator_id        => $handler->operator_id,
        });
    }

    # All actions after creation require the return arrival to exist, so we
    # error if we can't find one
    my $return_arrival_id = extract_return_arrival_id($handler->uri);
    my $return_arrival = $schema->resultset('Public::ReturnArrival')
        ->find($return_arrival_id);

    unless ( $return_arrival ) {
        xt_warn("Couldn't find arrival $return_arrival_id");
        return delivery_uri();
    }

    my %action_map = (
        delete => sub {
            $_[0]->delete;
            xt_success('Arrival deleted');
        },
        remove_package => sub {
            $_[0]->remove_package;
            xt_success('Package removed');
        },
        enter_details => sub {
            my ($return_arrival, $param) = @_;
            $return_arrival->complete(@{$param}{qw/dhl_tape damaged damage_description/});
            xt_success(
                sprintf 'AWB %s details confirmed', $return_arrival->return_airway_bill
            );
        },
        edit_note => sub {
            my ($return_arrival, $param) = @_;
            $return_arrival->update({ damage_description => $param->{edit_notes} });
            xt_success("Updated notes for AWB: ".$return_arrival->return_airway_bill);
        },
    );
    my $sub = $action_map{$action};
    if ( $sub ) {
        $sub->($return_arrival, $param)
    }
    else {
        xt_warn('Unrecognised action - params were ' . pp $param);
    }
    return delivery_uri($return_arrival->return_delivery_id);
}

=head2 add_arrival($uri, $schema, $awb, $return_delivery, $operator_id) : $redirect_uri

Attempts to add the arrival given by the awb in the parameters to the delivery.

=cut

sub add_arrival {
    my ( $uri, $schema, $awb, $return_delivery_id, $operator_id )
        = @{$_[0]}{qw/uri schema awb return_delivery_id operator_id/};

    # Validate our return_delivery_id
    unless ( $return_delivery_id ) {
        xt_warn('No return delivery id provided');
        return delivery_uri();
    }
    unless ( $return_delivery_id =~ m{^\d+$} ) {
        xt_warn("Invalid return delivery id provided '$return_delivery_id'");
        return delivery_uri();
    }

    my $return_delivery = $schema->resultset('Public::ReturnDelivery')->find($return_delivery_id);
    unless ( $return_delivery_id ) {
        xt_warn("Couldn't find return delivery for id $return_delivery_id");
        return delivery_uri();
    }

    if ( $return_delivery->confirmed ) {
        xt_warn("Couldn't add return arrival to confirmed delivery");
        return delivery_uri($return_delivery_id);
    }

    # Strip whitespace
    $awb = $awb//q{} =~ s{^\s*(\w{10,18})\s*$}{$1}r;
    unless ( $awb ) {
        xt_warn('Please enter a valid AWB');
        return delivery_uri($return_delivery_id);
    }

    # If we already have a return arrival our behaviour changes
    if ( my $return_arrival = $schema->resultset('Public::ReturnArrival')->find_by_awb($awb) ) {
        if ( arrival_belongs_to_another_delivery($return_arrival, $return_delivery) ) {
            xt_warn( sprintf(
                'The AWB is part of another delivery (%d - %s)',
                $return_arrival->return_delivery_id,
                $return_arrival->return_delivery->date_confirmed->strftime('%F %R')
            ));
            return delivery_uri($return_delivery_id);
        }
        else {
            $return_arrival->add_package;
            xt_info( "This AWB ($awb) was already present in this delivery - its package count has been incremented" );
            return arrival_uri($return_arrival->id);
        }
    }

    # If we get here we add the arrival to the delivery
    my $return_arrival = $return_delivery->add_arrival( $awb, $operator_id );
    xt_success('Arrival added to delivery');

    return arrival_uri($return_arrival->id);
}

=head2 arrival_belongs_to_another_delivery($return_arrival, $return_delivery) : Bool

Returns a true value if C<$return_arrival> is part of another
C<$return_delivery>.

=cut

sub arrival_belongs_to_another_delivery {
    my ( $return_arrival, $return_delivery ) = @_;
    return $return_arrival->return_delivery_id != $return_delivery->id;
}

1;
