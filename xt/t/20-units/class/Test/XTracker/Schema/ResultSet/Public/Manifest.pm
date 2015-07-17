package Test::XTracker::Schema::ResultSet::Public::Manifest;
use NAP::policy qw/class test/;

BEGIN { extends 'NAP::Test::Class'; };

use Test::XTracker::Data::Manifest;
use XTracker::Constants::FromDB qw(
    :manifest_status
);

sub test__search_locking_status :Tests {
    my ($self) = @_;

    for my $test (
        {
            name        => 'Check that correct status are reported as locking',
            setup       => {
                manifests => [
                    {
                        filename    => '1.csv',
                        status_id   => $PUBLIC_MANIFEST_STATUS__COMPLETE,
                    },
                    {
                        filename    => '2.csv',
                        status_id   => $PUBLIC_MANIFEST_STATUS__EXPORTING,
                    },
                    {
                        filename    => '3.csv',
                        status_id   => $PUBLIC_MANIFEST_STATUS__EXPORTED,
                    }
                ],
            },
            expected    => {
                locking_filenames => ['2.csv', '3.csv'],
            },
        }
    ) {
        subtest $test->{name} => sub {
            my $resultset = $self->_create_test_data($test);

            my @actual_filenames = sort $resultset->search_locking_status->get_column('filename')->all();
            my @expected_filenames = sort @{$test->{expected}->{locking_filenames}};
            eq_or_diff(\@actual_filenames, \@expected_filenames, 'Manifests returned are as expected');
        };
    }
}

sub test__search_by_channel_ids :Tests {
    my ($self) = @_;

    my $a_valid_channel_id = $self->schema->resultset('Public::Channel')->first->id();
    my $another_valid_channel = $self->schema->resultset('Public::Channel')->search({
        id => { '!=' => $a_valid_channel_id }
    })->first;

    SKIP: {
        skip 'Two channels required to test channel filter', unless $another_valid_channel;

        my $another_valid_channel_id = $another_valid_channel->id();

        for my $test (
            {
                name        => 'Check that the correct manifests are reported as associated with a channel',
                setup       => {
                    manifests => [
                        {
                            filename    => '1.csv',
                            restricted_to_channel_ids => [
                                $a_valid_channel_id,
                            ],
                        },
                        {
                            filename    => '2.csv',
                            restricted_to_channel_ids => [
                                $another_valid_channel_id,
                            ],
                        },
                        {
                            filename    => '3.csv',
                        }
                    ],
                    parameters => {
                        channel_ids => [$a_valid_channel_id],
                    },
                },
                expected    => {
                    matching_filenames => ['1.csv', '3.csv'],
                },
            }
        ) {
            subtest $test->{name} => sub {
                my $resultset = $self->_create_test_data($test);

                my @actual_filenames = sort $resultset->search_by_channel_ids(
                    $test->{setup}->{parameters}->{channel_ids}
                )->get_column('filename')->all();
                my @expected_filenames = sort @{$test->{expected}->{matching_filenames}};
                eq_or_diff(\@actual_filenames, \@expected_filenames, 'Manifests returned are as expected');
            };
        }
    }
}

sub test__create_manifest :Tests {
    my ($self) = @_;

    my $a_valid_channel_id = $self->schema->resultset('Public::Channel')->first->id();
    my $a_valid_carrier_id = $self->schema->resultset('Public::Carrier')->first->id();

    for my $test (
        {
            name        => 'Check that manifest is created properly',
            setup       => {
                parameters => [
                    {
                        cut_off     => DateTime->new( year => '2015', month => '3', day => '31' ),
                        carrier_id  => $a_valid_carrier_id,
                        filename    => 'test.csv',
                    },
                    {
                        channel_ids => [$a_valid_channel_id],
                    }
                ]
            },
            expected    => {
                manifest_attributes => {
                    status_id       => $PUBLIC_MANIFEST_STATUS__EXPORTING,
                    filename        => 'test.csv',
                },
                channel_links       => [$a_valid_channel_id],
            },
        }
    ) {
        subtest $test->{name} => sub {
            my $manifest = $self->schema->resultset('Public::Manifest')->create_manifest(
                @{$test->{setup}->{parameters}}
            );

            for my $manifest_attribute (keys %{$test->{expected}->{manifest_attributes}}) {
                is($manifest->$manifest_attribute(), $test->{expected}->{manifest_attributes}->{$manifest_attribute}
                    , "$manifest_attribute is as expected");
            }

            for my $channel_id ($test->{expected}->{channel_links}) {
                is($manifest->link_manifest__channels->search({ channel_id => $channel_id})->count(), 1,
                    "Channel-ID: $channel_id is linked to manifest");
            }

        };
    }
}

sub _create_test_data {
    my ($self, $test) = @_;

    my $data_helper = Test::XTracker::Data::Manifest->new();

    my @manifest_ids = map {
        $data_helper->create_db_manifest($_)->id();
    } @{$test->{setup}->{manifests}};

    my $resultset = $self->schema->resultset('Public::Manifest')->search({
        'me.id' => \@manifest_ids,
    });

    return $resultset;
}


