package Test::XTracker::Schema::ResultSet::Public::PutawayPrepGroup;

use NAP::policy "tt", 'test';

use FindBin::libs;
use parent 'NAP::Test::Class';

use Test::XTracker::RunCondition prl_phase => 'prl';


use Test::Exception; # lives_ok

use Test::XT::Data::PutawayPrep;

# TESTS

sub startup :Test(startup) {
    my ($self) = @_;
    $self->{setup} = Test::XT::Data::PutawayPrep->new;
}

sub filters : Tests {
    my ($self) = @_;

    foreach my $config (
        { method => 'filter_active' },
        { method => 'filter_active', 'voucher' => 1 },
        { method => 'filter_ready_for_putaway' },
        { method => 'filter_normal_stock' },
        { method => 'filter_returns', 'return' => 1 },
        { method => 'filter_recodes', 'recode' => 1 },
    ) {
        # create group of correct type
        my ($stock_process, $product_data)
            = $self->{setup}->create_product_and_stock_process( 1, {
                group_type => (
                    $config->{recode}
                        ? XTracker::Database::PutawayPrep::RecodeBased->name
                        : XTracker::Database::PutawayPrep->name
                ),
                    return => $config->{return},
                voucher => $config->{voucher},
            });
        my $group_id = $product_data->{ ($config->{recode} ? 'recode_id' : 'pgid') };
        my $pp_group = $self->{setup}->create_pp_group({
            group_id => $group_id,
            group_type => (
                $config->{recode}
                    ? XTracker::Database::PutawayPrep::RecodeBased->name
                    : XTracker::Database::PutawayPrep->name
            ),
        });

        # does group match filter?
        my $method = $config->{method};
        my $groups;
        lives_ok( sub {
            $groups = $self->schema->resultset('Public::PutawayPrepGroup')->$method
        }, $method );

        note("groups = ".join(', ',map { $_->canonical_group_id } $groups->all));

        isa_ok( $groups->first, 'XTracker::Schema::Result::Public::PutawayPrepGroup',
            "$method returns PutawayPrepGroups");

        my $group_id_field_name = $config->{recode} ? 'recode_id' : 'group_id';
        ok( $groups->search({ $group_id_field_name => $group_id }), "correct group was returned" );
    }
}

sub find_active_group : Tests {
    my ($self) = @_;

    foreach my $config (
        { prefix => 'p', stock_type => 'normal' },
        { prefix => 'p', stock_type => 'voucher', 'voucher' => 1 },
        { prefix => 'p', stock_type => 'return', 'return' => 1 },
        { prefix => 'r', stock_type => 'recode', 'recode' => 1 },
    ) {
        # create group of correct type
        my ($stock_process, $product_data)
            = $self->{setup}->create_product_and_stock_process( 1, {
                group_type => (
                    $config->{recode}
                        ? XTracker::Database::PutawayPrep::RecodeBased->name
                        : XTracker::Database::PutawayPrep->name
                ),
                return => $config->{return},
                voucher => $config->{voucher},
            });
        my $group_id = $product_data->{ ($config->{recode} ? 'recode_id' : 'pgid') };
        my $pp_group = $self->{setup}->create_pp_group({
            group_id => $group_id,
            group_type => (
                $config->{recode}
                    ? XTracker::Database::PutawayPrep::RecodeBased->name
                    : XTracker::Database::PutawayPrep->name
            ),
        });

        my $id_field_name = $config->{recode} ? 'recode_id' : 'group_id';

        # Pass in group ID with prefix: p123 or r456
        my $prefix_group = $self->schema->resultset('Public::PutawayPrepGroup')
            ->find_active_group({ group_id => $config->{prefix} . $group_id });
        isa_ok($prefix_group, 'XTracker::Schema::Result::Public::PutawayPrepGroup');

        # Pass in raw group ID with field name: 123 + 'group_id' / or 456 + 'recode_id'
        my $raw_group_with_field_name = $self->schema->resultset('Public::PutawayPrepGroup')
            ->find_active_group({
                group_id      => $group_id,
                id_field_name => $id_field_name,
            });
        isa_ok($raw_group_with_field_name, 'XTracker::Schema::Result::Public::PutawayPrepGroup');

        # Pass in group ID with prefix AND field name (redundant): p123 + 'group_id' / or 456 + 'recode_id'
        my $prefix_group_with_field_name = $self->schema->resultset('Public::PutawayPrepGroup')
            ->find_active_group({
                group_id      => $config->{prefix} . $group_id,
                id_field_name => $id_field_name,
            });
        isa_ok($prefix_group_with_field_name, 'XTracker::Schema::Result::Public::PutawayPrepGroup');

        # Pass in raw group ID (123) and no field name - should fail
        # because we can't tell if it's a recode or not
        dies_ok( sub { $self->schema->resultset('Public::PutawayPrepGroup')
            ->find_active_group({ group_id => $group_id }) }, 'dies when called with raw ID and no field name' );

        # Pass in just field name - should fail
        dies_ok( sub { $self->schema->resultset('Public::PutawayPrepGroup')
            ->find_active_group({ id_field_name => $id_field_name }) }, 'dies when called without group_id' );
    }
}

1;
