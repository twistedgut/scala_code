package XT::DC::Messaging::Producer::Shipping::DeliveryDateRestriction;
use NAP::policy "tt", "class";
use XTracker::Database::Shipment;
use XTracker::Config::Local qw( config_var );
use NAP::Messaging::Validator;

NAP::Messaging::Validator->add_type_plugins(
    map {"XT::DC::Messaging::Spec::Types::$_"}
        qw(date channel_website_name nominated_day_restriction_type)
    );

with 'XT::DC::Messaging::Role::Producer',
     'XTracker::Role::WithSchema';

sub date_restriction_rs {
    my $self = shift;
    return $self->schema->resultset("Shipping::DeliveryDateRestriction");
}

sub message_spec {
    return {
        type => '//rec',
        required => {
            channel => '/nap/channel_website_name',
            window => {
                type => '//rec',
                required => {
                    begin_date => '/nap/date',
                    end_date   => '/nap/date',
                },
            },
            restricted_dates => {
                type     => '//arr',
                length   => { min => 0 },
                contents => {
                    type     => '//rec',
                    required => {
                        date                => '/nap/date',
                        restriction_type    => '/nap/nominated_day_restriction_type',
                        shipping_charge_sku => '//str',
                    },
                },
            },
        },
    };
}

has '+type' => ( default => 'ShippingRestrictedDays' );
has '+set_at_type' => ( default => 0 );

sub transform {
    my ($self, $header, $data) = @_;
    my $channel_row = $data->{channel_row};
    my $begin_date  = $data->{begin_date};
    my $end_date    = $data->{end_date};

    my $payload = {
        channel => $channel_row->website_name,
        window => {
            begin_date => $begin_date->ymd,
            end_date   => $end_date->ymd,
        },
        restricted_dates => $self->restricted_dates({
            channel_row => $channel_row,
            begin_date  => $begin_date,
            end_date    => $end_date
        }),
    };

    $header->{channel_id}   = $channel_row->id;
    $header->{channel_name} = $channel_row->website_name;

    return ($header, $payload);
}

sub restricted_dates {
    my ($self, $args) = @_;
    return [
        map {
            my $date = $_->date->ymd;
            + {
                date                => $date,
                restriction_type    => $_->restriction_type->token,
                shipping_charge_sku => $_->shipping_charge->sku,
            },
        }
        $self->date_restriction_rs->between_dates_per_channel_rs({
            channel    => $args->{channel_row},
            begin_date => $args->{begin_date},
            end_date   => $args->{end_date},
        })->all,
    ];
}

1;
