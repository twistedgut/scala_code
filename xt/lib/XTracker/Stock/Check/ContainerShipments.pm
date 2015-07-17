package XTracker::Stock::Check::ContainerShipments;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Navigation;
use XTracker::Error qw( xt_warn );
use XTracker::Utilities qw( :string );

use XTracker::Database::Container qw( :utils );

use XTracker::Handler::Situation;

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

my $redirect_default = '/StockControl/StockCheck/ContainerShipments';

my $situations = {
    'containerShipments' => {
        fancy_name     => 'Container Shipments',
        check_we_have  => [ qw( container_id ) ],
        redirect_on_fail => '',
    },
};

my $parameters = {
    container_id     => { fancy_name => 'container/tote',
                          # make sure that incoming Container ID goes further as Barcode object
                          get_object => sub {
                                my ($schema, $container_id) = @_;
                                $container_id = NAP::DC::Barcode::Container->new_from_barcode(
                                    $container_id
                                );
                                return get_container_by_id ( $schema, $container_id );
                          },
                          redirect_on_fail => '',
                        }
};

my $validators = {
    container_id => sub {
        my ($container,$checked_objects) = @_;

        die "Container ".($container->id)." is empty\n"
            if $container->is_empty;
    }
};


sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{data}{content}   = 'stocktracker/check/handheld/container_shipments.tt';
    $handler->{data}{sidenav}   = {};
    $handler->{data}{view}      = 'HandHeld';

    if (exists $handler->{param_of}{container_id}) {
        my ($situation,$bounce);

        eval {
            $situation = XTracker::Handler::Situation->new( { situations => $situations,
                                                              parameters => $parameters,
                                                              validators => $validators,
                                                              redirect_on_fail_default => $redirect_default,
                                                              handler    => $handler } );
            $bounce=$situation->evaluate;
        };

        if ($@) {
            xt_warn($@);

            return $handler->redirect_to($redirect_default);
        }

        my $container = $situation->get_checked_objects('container_id');

        if ($container) {
            eval {
                $handler->{data}{scanned_container} = $container->id; # canonical form
                $handler->{data}{channel_name}      = $container->get_channel->name;

                my @shipment_ids = $container->shipment_ids;

                $handler->{data}{shipment_heading}  = @shipment_ids > 1? 'Shipments' : 'Shipment';

                # done as a hash, because we'll probably add per-shipment info soon, and
                # so we might as well start as we mean to go on

                foreach my $shipment_id (@shipment_ids) {
                    $handler->{data}{shipments}{$shipment_id}{shipment_id}  = $shipment_id;   # just to have something there
                }

                if ($container->is_part_of_multi_container_shipment) {
                    my $other_containers = $container->other_containers_in_shipment;

                    while ( my $other_container = $other_containers->next ) {
                        push @{$handler->{data}{other_containers}}, $other_container->id;
                    }

                    $handler->{data}{container_heading}
                        = @{$handler->{data}{other_containers}} > 1
                            ? 'Associated containers'
                            : 'Associated container';
                }
            };
            if ($@) {
                xt_warn($@);
            }
        }
    }

    $handler->process_template( undef );

    return OK;
}

1;
