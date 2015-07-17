package XT::DC::Messaging::Producer::Product::SortOrder;
use NAP::policy "tt", 'class';
use XTracker::Config::Local 'config_var';
use XTracker::Comms::DataTransfer 'fetch_product_sort_data';
with 'XT::DC::Messaging::Role::Producer',
    # these are to appease XT's message queue "custom accessors"
    'XTracker::Role::WithIWSRolloutPhase',
    'XTracker::Role::WithPRLs',
    'XTracker::Role::WithSchema';

sub message_spec {
    return {
        type => '//rec',
        required => {
            destination => '//str',
            products => {
                type => '//arr',
                length => { min => 1 },
                contents => {
                    type => '//rec',
                    required => {
                        product_id => '//int',
                        channel_id => '//int',
                        sort_order => '//int',
                    },
                },
            },
        },
    };
}

has '+type' => ( default => 'product_sort_order' );

sub transform {
    my ($self,$header,$data) = @_;

    my $payload={};

    my $channel
        = $self->schema->resultset('Public::Channel')->find( $data->{channel_id} );

    $header->{business_id}   = $channel->business->id;
    $header->{business_name} = $channel->business->name;
    $header->{channel_id}    = $channel->id;
    $header->{channel_name}  = $channel->name;
    $payload->{destination}  = $data->{destination};

    my $sink_env;
    given ($data->{environment}) {
        when ("live_and_staging") {
            $header->{live} = $header->{staging} = 1;
            $sink_env = 'live';
        }
        when ("live") {
            $header->{live}    = 1;
            $header->{staging} = 0;
            $sink_env = 'live';
        }
        when ("staging") {
            $header->{live}    = 0;
            $header->{staging} = 1;
            $sink_env = 'staging';
        }
        default {
            croak __PACKAGE__ . "::transform doesn't know about the environment $data->{environment}";
        }
    }

    my $sort_data
        = fetch_product_sort_data({
            dbh                 => $self->schema->storage->dbh,
            sink_environment    => $sink_env,
            sink_site           => 'intl', # not really used
            product_ids         => $data->{product_ids},
            destination         => $data->{destination},
            channel_id          => $data->{channel_id},
        })->{results_ref};

    my @prods;
    $payload->{products} = \@prods;
    for my $sort_item (@$sort_data) {
        push @prods,{
            product_id => $sort_item->{product_id},
            channel_id => $data->{channel_id},
            sort_order => $sort_item->{sort_order},
        };
    }

    return ($header,$payload);
}
