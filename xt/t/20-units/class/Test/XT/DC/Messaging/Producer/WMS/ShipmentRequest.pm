package Test::XT::DC::Messaging::Producer::WMS::ShipmentRequest;
use NAP::policy "tt", 'class', 'test';
use JSON::XS;
use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::MockObject::Builder;
use Test::MockModule;
use DateTime;


BEGIN {
    extends 'NAP::Test::Class';

    has 'shipment_id' => ( is => 'ro', default => 1 );
    has 'output_shipment_id' => ( is => 'ro', lazy => 1, default => sub {
        my ($self) = @_;
        's-' . $self->shipment_id();
    });
    has 'shipment_type' => ( is => 'ro', default => 'customer' );
    has 'stock_status' => ( is => 'ro', default => 'main' );
    has 'channel_name' => ( is => 'ro', default => 'NAP' );
    has 'sku' => ( is => 'ro', default => '1234-567' );
    has 'client_code' => ( is => 'ro', default => 'NAP' );
    has 'wms_deadline_datetime' => ( is => 'ro', default => sub {
        DateTime->new(
            year        => 2013,
            month       => 11,
            day         => 26,
            hour        => 15,
            minute      => 56,
            time_zone   => 'UTC',
        );
    });
    has 'wms_deadline_string' => ( is => 'ro', default => '2013-11-26T15:56:00.000+0000' );
    has 'bump_deadline_datetime' => ( is => 'ro', default => sub {
        DateTime->new(
            year        => 2014,
            month       => 12,
            day         => 27,
            hour        => 16,
            minute      => 57,
            time_zone   => 'UTC',
        );
    });
    has 'bump_deadline_string' => ( is => 'ro', default => '2014-12-27T16:57:00.000+0000' );
    has 'initial_pick_priority' => ( is => 'ro', default => 8 );
    has 'bump_pick_priority' => ( is => 'ro', default => 4 );
    has 'shipment_request_type' => ( is => 'ro', default => 'shipment_request' );
    has 'message_version' => ( is => 'ro', default => '1.0' );
    has 'sla_cutoff' => ( is => 'ro', default => sub {
        DateTime->new(
            year        => 2012,
            month       => 10,
            day         => 25,
            hour        => 14,
            minute      => 55,
            time_zone   => 'UTC',
        );
    });
    has 'sla_cutoff_string' => ( is => 'ro', default => '2012-10-25T14:55:00.000+0000' );
    has 'iws_priority_class' => ( is => 'ro', default => 2 );
};

sub test__transform :Tests {
    my ($self) = @_;

    my $message_queue = Test::XTracker::MessageQueue->new();

    for my $test (
        {
            name    => 'Premier with picking docs and configured to use SOS deadline',
            setup   => {
                shipment                    => {
                    set_isa => 'XTracker::Schema::Result::Public::Shipment',
                    mock    => {
                        id                          => $self->shipment_id(),
                        get_iws_shipment_type       => $self->shipment_type(),
                        stock_status_for_iws        => $self->stock_status(),
                        get_channel                 => {
                            mock => { name => $self->channel_name() },
                        },
                        get_iws_is_premier          => 1,
                        list_picking_print_docs     => 1,
                        wms_deadline                => $self->wms_deadline_datetime(),
                        wms_initial_pick_priority   => $self->initial_pick_priority(),
                        wms_bump_deadline           => $self->bump_deadline_datetime(),
                        wms_bump_pick_priority      => $self->bump_pick_priority(),
                        sla_cutoff                  => $self->sla_cutoff(),
                        iws_priority_class          => $self->iws_priority_class(),
                        active_items   => {
                            mock    => { count => 1 },
                            set_list    => {
                                all => [
                                    Test::MockObject::Builder->build({
                                        mock => {
                                            is_virtual_voucher  => 0,
                                            get_true_variant    => {
                                                mock => {
                                                    sku => $self->sku(),
                                                    get_client => {
                                                        mock => {
                                                            get_client_code => $self->client_code(),
                                                        }
                                                    },
                                                },
                                            },
                                        },
                                    })
                                ],
                            },
                        },
                        use_sos_for_sla_data => 1,
                    },
                },
            },
            expected    => {
                shipment_id         => $self->output_shipment_id(),
                shipment_type       => $self->shipment_type(),
                stock_status        => $self->stock_status(),
                channel             => $self->channel_name(),
                premier             => JSON::XS::true,
                has_print_docs      => JSON::XS::true,
                items               => [{
                    sku         => $self->sku(),
                    quantity    => 1,
                    client      => $self->client_code(),
                }],
                deadline            => $self->sla_cutoff_string(),
                initial_priority    => $self->initial_pick_priority(),
                bump_deadline       => $self->bump_deadline_string(),
                bump_priority       => $self->bump_pick_priority(),
                '@type'             => $self->shipment_request_type(),
                version             => $self->message_version(),
            },
        },


        {
            name    =>  'Non-Premier without picking docs, not configured to use ' .
                        'SOS deadline and with virtual voucher',
            setup   => {
                shipment                    => {
                    set_isa => 'XTracker::Schema::Result::Public::Shipment',
                    mock    => {
                        id                          => $self->shipment_id(),
                        get_iws_shipment_type       => $self->shipment_type(),
                        stock_status_for_iws        => $self->stock_status(),
                        get_channel                 => {
                            mock => { name => $self->channel_name() },
                        },
                        get_iws_is_premier          => 0,
                        list_picking_print_docs     => 0,
                        wms_deadline                => $self->wms_deadline_datetime(),
                        wms_initial_pick_priority   => $self->initial_pick_priority(),
                        wms_bump_deadline           => $self->bump_deadline_datetime(),
                        wms_bump_pick_priority      => $self->bump_pick_priority(),
                        sla_cutoff                  => $self->sla_cutoff(),
                        iws_priority_class          => $self->iws_priority_class(),
                        active_items   => {
                            mock    => {
                                count   => 1,
                            },
                            set_list    => {
                                all => [
                                    Test::MockObject::Builder->build({
                                        mock => {
                                            is_virtual_voucher  => 1,
                                            get_true_variant    => {
                                                mock => {
                                                    sku => $self->sku(),
                                                    get_client => {
                                                        mock => {
                                                            get_client_code => $self->client_code(),
                                                        }
                                                    },
                                                },
                                            },
                                        },
                                    }),Test::MockObject::Builder->build({
                                        mock => {
                                            is_virtual_voucher  => 0,
                                            get_true_variant    => {
                                                mock => {
                                                    sku => $self->sku(),
                                                    get_client => {
                                                        mock => {
                                                            get_client_code => $self->client_code(),
                                                        }
                                                    },
                                                },
                                            },
                                        },
                                    })
                                ],
                            },
                        },
                        use_sos_for_sla_data => 0,
                    },
                },
            },
            expected    => {
                shipment_id         => $self->output_shipment_id(),
                shipment_type       => $self->shipment_type(),
                stock_status        => $self->stock_status(),
                channel             => $self->channel_name(),
                premier             => JSON::XS::false,
                has_print_docs      => JSON::XS::false,
                items               => [{
                    sku         => $self->sku(),
                    quantity    => 1,
                    client      => $self->client_code(),
                }],
                deadline            => $self->sla_cutoff_string(),
                initial_priority    => $self->initial_pick_priority(),
                bump_deadline       => $self->bump_deadline_string(),
                bump_priority       => $self->bump_pick_priority(),
                priority_class      => $self->iws_priority_class(),
                '@type'             => $self->shipment_request_type(),
                version             => $self->message_version(),
            },
        },
    ) {
        subtest $test->{name} => sub {
            my $mock_shipment = Test::MockObject::Builder->build($test->{setup}->{shipment});
            my ($headers, $body);

            lives_ok {
                ($headers, $body) = $message_queue->transform(
                    'XT::DC::Messaging::Producer::WMS::ShipmentRequest',
                    $mock_shipment
                );
            } 'transform() lives';

            is_deeply($body, $test->{expected}, 'Message body is as expected');

        };
    }
}
