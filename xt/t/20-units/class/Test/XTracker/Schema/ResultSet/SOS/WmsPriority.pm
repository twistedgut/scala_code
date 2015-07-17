package Test::XTracker::Schema::ResultSet::SOS::WmsPriority;
use NAP::policy 'tt', 'test', 'class';

use Test::XTracker::LoadTestConfig;

BEGIN {
    extends 'NAP::Test::Class';

    use Test::SOS::Data;
    has 'data_helper' => (
        is      => 'ro',
        lazy    => 1,
        default => sub { Test::SOS::Data->new() },
    );
};

sub _test_county_name { return 'The Land of Oz' }
sub _test_region_name { return 'Emerald City' }
sub _test_shipment_class { return 'Yellow Brick Road Post' }
sub _test_shipment_class_attribute { return 'Seeking Wizard' }

sub test__find_wms_priority :Tests {
    my ($self) = @_;

    my (
        $test_country,
        $test_region,
        $test_shipment_class,
        $test_shipment_class_attribute
    ) =  $self->_ensure_test_priority_links();

    for my $test (
        {
            name        => 'Prioritise by lowest wms_priority value first',
            setup       => {
                priorities  => [
                    {
                        shipment_class_id   => $test_shipment_class->id(),
                        wms_priority        => 1,
                        wms_bumped_priority => undef,
                        bumped_interval     => undef,
                    },
                    {
                        country_id          => $test_country->id(),
                        wms_priority        => 2,
                        wms_bumped_priority => undef,
                        bumped_interval     => undef,
                    },
                ],
                parameters  => {
                    shipment_class  => $test_shipment_class,
                    country         => $test_country,
                    region          => $test_region,
                },
            },
            expected => {
                wms_priority        => 1,
                wms_bumped_priority => undef,
                bumped_interval     => undef,
            }
        },

        {
            name        => 'Prioritise by lowest wms_bumped_priority value second',
            setup       => {
                priorities  => [
                    {
                        country_id          => $test_country->id(),
                        wms_priority        => 5,
                        wms_bumped_priority => 1,
                        bumped_interval     => undef,
                    },
                    {
                        region_id           => $test_region->id(),
                        wms_priority        => 5,
                        wms_bumped_priority => 2,
                        bumped_interval     => undef,
                    },
                ],
                parameters  => {
                    shipment_class  => $test_shipment_class,
                    country         => $test_country,
                    region          => $test_region,
                },
            },
            expected => {
                wms_priority        => 5,
                wms_bumped_priority => 1,
                bumped_interval     => undef,
            }
        },

        {
            name        => 'shipment class attributes work',
            setup       => {
                priorities  => [
                    {
                        shipment_class_attribute_id => $test_shipment_class_attribute->id(),
                        wms_priority        => 1,
                        wms_bumped_priority => undef,
                        bumped_interval     => undef,
                    },
                    {
                        region_id           => $test_region->id(),
                        wms_priority        => 2,
                        wms_bumped_priority => undef,
                        bumped_interval     => undef,
                    },
                ],
                parameters  => {
                    shipment_class  => $test_shipment_class,
                    country         => $test_country,
                    region          => $test_region,
                    attribute_list  => [$test_shipment_class_attribute],
                },
            },
            expected => {
                wms_priority        => 1,
                wms_bumped_priority => undef,
                bumped_interval     => undef,
            }
        },

        {
            name        => 'regions work',
            setup       => {
                priorities  => [
                    {
                        shipment_class_attribute_id => $test_shipment_class_attribute->id(),
                        wms_priority        => 2,
                        wms_bumped_priority => undef,
                        bumped_interval     => undef,
                    },
                    {
                        region_id           => $test_region->id(),
                        wms_priority        => 1,
                        wms_bumped_priority => undef,
                        bumped_interval     => undef,
                    },
                ],
                parameters  => {
                    shipment_class  => $test_shipment_class,
                    country         => $test_country,
                    region          => $test_region,
                    attribute_list  => [$test_shipment_class_attribute],
                },
            },
            expected => {
                wms_priority        => 1,
                wms_bumped_priority => undef,
                bumped_interval     => undef,
            }
        },
    ) {
        subtest $test->{name} => sub {
            note(sprintf('Starting subtest: %s', $test->{name}));

            my $schema = $self->schema();

            # Clear any priorities that use our test links
            $schema->resultset('SOS::WmsPriority')->search({
                -or => [
                    shipment_class_id           => $test_shipment_class->id(),
                    country_id                  => $test_country->id(),
                    region_id                   => $test_region->id(),
                    shipment_class_attribute_id => $test_shipment_class_attribute->id(),
                ],
            })->delete();

            my @priority_objects = $self->schema->resultset('SOS::WmsPriority')->populate(
                $test->{setup}->{priorities}
            );
            my @priority_ids = map {$_->id() } @priority_objects;

            my $test_resultset = $self->schema->resultset('SOS::WmsPriority')->search({
                id => \@priority_ids
            });

            my $returned_priority_object;
            lives_ok {
                $returned_priority_object = $test_resultset->find_wms_priority(
                    $test->{setup}->{parameters}
                );
            } 'find_wms_priority() lives';

            isa_ok($returned_priority_object,
                'XTracker::Schema::Result::SOS::WmsPriority',
                'WmsPriority object was returned') or return;

            eq_or_diff({
                wms_priority        => $returned_priority_object->wms_priority(),
                wms_bumped_priority => $returned_priority_object->wms_bumped_priority(),
                bumped_interval     => $returned_priority_object->bumped_interval(),
            }, $test->{expected}, 'Returned object has expected values');
        };
    }
}

sub _ensure_test_priority_links {
    my ($self) = @_;
    my $schema = $self->schema();

    my $test_country = $self->data_helper->find_or_create_country({
        name => $self->_test_county_name(),
    });

    my $test_region = $self->data_helper->find_or_create_region({
        country => $test_country,
        name    => $self->_test_region_name()
    });

    my $test_shipment_class = $self->data_helper->find_or_create_shipment_class({
        name => $self->_test_shipment_class(),
    });

    my $test_shipment_class_attribute
        = $self->data_helper->find_or_create_shipment_class_attribute({
        name => $self->_test_shipment_class_attribute(),
    });

    return (
        $test_country,
        $test_region,
        $test_shipment_class,
        $test_shipment_class_attribute
    );
}
