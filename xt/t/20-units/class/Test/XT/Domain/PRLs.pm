package Test::XT::Domain::PRLs;

use NAP::policy "tt", 'test';

use Test::XTracker::RunCondition
    prl_phase  => 'prl',
    export     => qw/$prl_rollout_phase/;

use FindBin::libs;
use Test::XTracker::LoadTestConfig;
use XT::Domain::PRLs;
use XTracker::Constants::FromDB qw(
    :storage_type
);

use parent 'NAP::Test::Class';

sub check_webapp_links :Tests {
    my $self = shift;

    my ($url_goh, $url_fw) = qw/ URL_1 URL_2 /;

    my $prl_configs = {
        Full => {
            prl_webapp_url => $url_fw,
        },
        Dematic => {},
        GOH => {
            prl_webapp_url => $url_goh,
        },
    };

    my $expected_links = [
        {
            caption => 'GOH',
            url => $url_goh,
        },
        {
            caption => 'Full',
            url => $url_fw
        }
    ];

    my $links = XT::Domain::PRLs::get_webapp_links({prl_configs => $prl_configs});

    is_deeply(
        [sort {$a->{caption} cmp $b->{caption}} @$expected_links],
        [sort {$a->{caption} cmp $b->{caption}} @$links],
        'Links info is same as expected'
    );

    is_deeply(
        [],
        XT::Domain::PRLs::get_webapp_links({prl_configs => {Dematic => {}}}),
        'For those config instances where there is no PRL web apps: no link info!'
    );
}

sub check_get_container_max_weight_for_storage_type :Tests {
    my $self = shift;

    my $prl_configs = {
        Full => {
            container_max_weight => 10,
            storage_types => {
                flat => {
                    stock_statuses => [qw/M D/],
                },
            }
        },
        Dematic => {
            container_max_weight => 20,
            storage_types => {
                dematic_flat => {
                    stock_statuses => [qw/M/],
                }
            }
        },
        GOH => {
            storage_types => {
                hanging => {
                    stock_statuses => [qw/M D/],
                }
            }
        },
    };

    my $storage_type_rs = $self->schema->resultset('Product::StorageType');

    is(
        XT::Domain::PRLs::get_container_max_weight_for_storage_type({
            prl_configs  => $prl_configs,
            storage_type => 'flat',
            stock_status => 'M'
        }),
        10,
        'Correct for FW PRL'
    );

    is(
        XT::Domain::PRLs::get_container_max_weight_for_storage_type({
            prl_configs  => $prl_configs,
            storage_type => 'dematic_flat',
            stock_status => 'M'
        }),
        20,
        'Correct for Full PRL'
    );

    is(
        XT::Domain::PRLs::get_container_max_weight_for_storage_type({
            prl_configs  => $prl_configs,
            storage_type => 'hanging',
            stock_status => 'M'
        }),
        0,
        'Correct for GOH PRL'
    );
}

sub get_prls_for_storage_types_and_stock_statuses :Tests {
    my ($test) = @_;

    # setup config to accept "flat" of any stock status to go to FW PRL,
    # "dematic_flat" of Main stock  to go to Dematic PRL,
    # "dematic_flat" of Dead stock - to FW PRL
    my $PRL_CONFIG = {
        FW_PRL => {
            storage_types => {
                flat => {
                    stock_statuses => [qw/M D/],
                },
                dematic_flat => {
                    stock_statuses => [qw/D/],
                }
            }
        },
        DEMATIC_PRL => {
            storage_types => {
                dematic_flat => {
                    stock_statuses => [qw/M/],
                }
            }
        },
    };

    foreach my $case (
        {
            prl_configs => $PRL_CONFIG,
            storage_type_and_stock_status_hash => {
                flat => { M => 1 },
            },
            result => [qw/ FW_PRL /],
            notes => 'Try Flat item of Main'
        },
        {
            prl_configs => $PRL_CONFIG,
            storage_type_and_stock_status_hash => {
                dematic_flat => { D => 1 },
            },
            result => [qw/ FW_PRL /],
            notes => 'Try Dematic Flat item of Dead'
        },
        {
            prl_configs => $PRL_CONFIG,
            storage_type_and_stock_status_hash => {
                dematic_flat => { M => 1 },
            },
            result => [qw/ DEMATIC_PRL /],
            notes => 'Try Dematic Flat item of Main'
        },
        {
            prl_configs => $PRL_CONFIG,
            storage_type_and_stock_status_hash => {
                dematic_flat => { D => 1 },
                flat => { M => 1 },
            },
            result => [qw/ FW_PRL /],
            notes => 'Try combination of Dematic Flat item of Dead and Flat of Main'
        },
        {
            prl_configs => $PRL_CONFIG,
            storage_type_and_stock_status_hash => {
                dematic_flat => { D => 1, M => 1 },
            },
            result => [qw//],
            notes => 'Try to submit incompatible combination'
        },
    ) {

        my $prls_to_advice = XT::Domain::PRLs::get_prls_for_storage_types_and_stock_statuses({
            prl_configs                        => $case->{prl_configs},
            storage_type_and_stock_status_hash => $case->{storage_type_and_stock_status_hash},
        });

        is_deeply(
            [ sort keys %$prls_to_advice ],
            [ sort @{ $case->{result} } ],
            $case->{notes}
        );
    }
}

sub get_prl_location_names : Tests {
    my $self = shift;

    my $location_names = XT::Domain::PRLs::get_prl_location_names();
    my @expected_names = ('Dematic PRL', 'Full PRL');
    push @expected_names, 'GOH PRL' if ($prl_rollout_phase >=2);

    is_deeply(
        [ sort @$location_names ],
        [ sort @expected_names ],
    );
}

sub get_location_from_amq_identifier : Tests {
    my $self = shift;

    my @expected = ({
        amq_identifier => 'Full',
        location_name  => 'Full PRL',
    }, {
        amq_identifier => 'dcd',
        location_name  => 'Dematic PRL',
    });

    foreach my $prl (@expected) {
        my $location_name = XT::Domain::PRLs::get_location_from_amq_identifier({
            amq_identifier => $prl->{amq_identifier},
        });
        is($location_name, $prl->{location_name},
           "Correct location name for amq identifier $prl->{amq_identifier}");
    }
}

1;
