package XTracker::Stock::GoodsIn::Returns::Delivery;

use strict;
use warnings;

use Try::Tiny;
use URI;

use XTracker::Config::Local qw(config_var);
use XTracker::Error;
use XTracker::Handler;
use XTracker::PrintFunctions;
use XTracker::EmailFunctions;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    # This page always requires an id - the rest of it is in the Catalyst part
    my $return_delivery_id = extract_return_delivery_id($handler->uri);
    unless ( $return_delivery_id ) {
        xt_warn(sprintf q{Invalid return delivery id '%s'}, $return_delivery_id//q{});
        return $handler->hh_redirect_to(delivery_uri());
    }

    my $schema = $handler->schema;
    my $return_delivery = $schema->resultset('Public::ReturnDelivery')->find($return_delivery_id);
    unless ( $return_delivery ) {
        xt_warn("Could not find return delivery id $return_delivery_id");
        return $handler->hh_redirect_to(delivery_uri());
    }

    # Handle any post requests
    if ( $handler->method eq 'POST' ) {
        return $handler->hh_redirect_to(process_post($handler, $return_delivery));
    }

    $handler->add_to_data({
        content         => 'stocktracker/goods_in/returns_in/delivery.tt',
        section         => 'Goods In',
        subsection      => 'Returns Delivery',
        return_delivery => $return_delivery,
        return_arrivals => [
            $return_delivery->return_arrivals->order_by({-desc => 'id'})->all
        ],
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

    if ( $return_delivery->confirmed ) {
        push @{ $handler->{data}{sidenav}[0]{None} }, {
            title => 'New Arrival',
            url   => delivery_uri(),
        };
        # It appears that at this point a new file was created every time...
        # that's kind of weird. Let's only create it if the file doesn't
        # already exist.
        _create_manifest_file( $return_delivery, $handler )
            unless -f XTracker::PrintFunctions::path_for_document_name(
                'return_delivery-' . $return_delivery->id
            );
    }

    return $handler->process_template;
}

=head2 extract_return_delivery_id($uri) : $return_delivery_id

Extract the return delivery id from the path.

=cut

sub extract_return_delivery_id {
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

=head2 process_post($handler, $return_delivery) : $redirect_uri

Process the post and return a L<URI> object that we can redirect to.

=cut

sub process_post {
    my ( $handler, $return_delivery ) = @_;

    my $param = $handler->{param_of};

    unless ( $param->{action} ) {
        xt_warn('No action provided');
        return delivery_uri();
    }

    my $schema = $handler->schema;
    # The user confirmed the delivery
    if ( $param->{action} eq 'confirm_delivery' ) {
        unless ( $return_delivery->total_packages ) {
            xt_warn("There are no packages to confirm!");
            return delivery_uri($return_delivery->id);
        }
        if ( $return_delivery->confirmed ) {
            xt_warn('Return delivery is already confirmed');
            return delivery_uri($return_delivery->id);
        }
        try {
            $schema->txn_do( sub {
                $return_delivery->confirm($handler->operator_id);
                $handler->{data}{manifest}{return_delivery} = $return_delivery;

                my $manifest_file = _create_manifest_file(
                    $return_delivery,
                    $handler
                );

                my $manifest_details = XTracker::PrintFunctions::document_details_from_name( $manifest_file );
                my $manifest_path = XTracker::PrintFunctions::path_for_print_document({
                    %$manifest_details,
                    extension => 'html',
                });
                _send_manifest_email( $manifest_path );

                xt_success( 'Delivery confirmed' );
            } );
        }
        catch {
            xt_warn("Failed to confirm delivery: $_");
        };
        return delivery_uri();
    }

    xt_warn("Unknown action $param->{action}");
    return delivery_uri();
}

sub _send_manifest_email {
    my ($manifest_path)= @_;

    send_email(
        config_var('Email', 'dc-returns_email'),   # to
        'xtracker@net-a-porter.com',               # from
        'xtracker@net-a-porter.com',               # reply_to
        'NET-A-PORTER: Return Delivery Confirmed', # subject
        'HTML manifest file attached',             # message
        'text',                                    # type
        # add an attachment
        {
            type    => 'text/html',
            filename=> $manifest_path,
        }
    );
    return;
}

sub _create_manifest_file {
    my ( $return_delivery, $handler ) = @_;

    my $manifest_data = {
        manifest        => 1,
        return_delivery => $return_delivery,
        return_arrivals => [
            $return_delivery->return_arrivals->order_by({-desc => 'id'})->all
        ],
    };

    my $filename = 'return_delivery-' . $return_delivery->id;
    my $html = create_document(
        $filename,
        'stocktracker/goods_in/returns_in/arrivals_confirm_delivery.tt',
        $manifest_data,
    );
    return $filename;
}

1;
