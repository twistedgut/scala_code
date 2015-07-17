package XT::DC::Messaging::Producer::Stock::DetailedLevelChange;
use NAP::policy "tt", 'class';
use XTracker::Config::Local 'config_var';
use MooseX::ClassAttribute;

with 'XT::DC::Messaging::Role::Producer',
    'XTracker::Role::WithSchema';
with 'XTracker::WebContent::Roles::DetailStockFields';

sub runtime_message_spec {
    my ($self) = @_;
    my @required_columns =
        map { $_, '//int' }
        grep { /_quantity$/ }
            $self->required_stock_detail_columns();

    my @optional_columns =
        map { $_, '//int' }
        grep { /_quantity$/ }
            $self->optional_stock_detail_columns();

    return {
        type => '//any',
        of => [
            {
                type => '//rec',

                required => {
                    product_id => '//int',
                    channel_id => '//int',
                    variant_id => '//int',
                    levels => {
                        type => '//rec',
                        required => {
                            @required_columns,
                        },
                        optional => {
                            @optional_columns,
                        },
                    },
                },
            },
            {
                type => '//rec',

                required => {
                    product_id => '//int',
                    channel_id => '//int',
                    variants => {
                        type => '//arr',
                        contents => {
                            type => '//rec',
                            required => {
                                variant_id => '//int',
                                levels => {
                                    type => '//rec',
                                    required => {
                                        @required_columns,
                                    },
                                    optional => {
                                        @optional_columns,
                                    },
                                },
                            },
                        },
                    },
                }
            },
        ],
    };
}

{
my $spec;
sub message_spec { return $spec }

sub BUILD {
    my ($self) = @_;

    $spec = $self->runtime_message_spec unless $spec;
    return;
}
}

has '+type' => ( default => 'DetailedStockLevelChange' );

sub transform {
    my($self, $header, $data) = @_;

    my $channel
        = $self->schema->resultset('Public::Channel')->find( $data->{channel_id} );

    # message groups, to help partition consumers
    $header->{JMSXGroupID} = $data->{product_id};

    $header->{business_id}   = $channel->business->id;
    $header->{business_name} = $channel->business->name;
    $header->{channel_id}    = $channel->id;
    $header->{channel_name}  = $channel->name;

    return ($header, $data);
}
