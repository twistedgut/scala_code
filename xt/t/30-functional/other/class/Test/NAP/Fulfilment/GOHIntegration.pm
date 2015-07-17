package Test::NAP::Fulfilment::GOHIntegration;

use NAP::policy qw/tt test class/;

BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with 'Test::Role::WithDeliverResponse',
         'Test::Role::WithGOHIntegration';
};

use FindBin::libs;
use Test::XTracker::RunCondition prl_phase => 'prl';

use Test::XT::Flow;
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :flow_status
    :prl_delivery_destination
    :allocation_status
    :storage_type
    :prl
);
use XTracker::Constants qw(
    :application
);
use vars qw/
    $PRL__DEMATIC
    $PRL__GOH
    $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION
    $PRL_DELIVERY_DESTINATION__GOH_DIRECT
/;

sub startup : Tests(startup => no_plan) {
    my ($self) = @_;
    $self->SUPER::startup;

    use_ok 'XT::DC::Controller::Fulfilment::GOH::Integration';

    $self->{flow} = $self->get_flow;
}

sub test_select_lane_page :Tests {
    my $self = shift;

    my $flow = $self->{flow};

    my $integration_sku = $self
        ->create_allocation_item_at_delivery_destination(
            $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION
        )
        ->shipment_item
        ->get_sku;
    my $direct_sku = $self
        ->create_allocation_item_at_delivery_destination(
            $PRL_DELIVERY_DESTINATION__GOH_DIRECT
        )
        ->shipment_item
        ->get_sku;



    note 'Open GOH integration page';
    $flow->flow_mech__fulfilment__goh_integration({ ignore_cookies => 1 });

    my $page_data = $flow->mech->as_data;

    ok(
        exists($page_data->{direct_lane_button}),
        'There is a button to select Direct lane'
    );

    ok(
        exists($page_data->{integration_lane_button}),
        'There is a button to select Integration lane'
    );

    ok
        grep({$_->{sku} eq $integration_sku} @{$page_data->{integration_lane_content} }),
        'Check SKUs on incoming lane';
    ok
        grep({$_->{sku} eq $direct_sku} @{$page_data->{direct_lane_content} }),
        'Check SKUs on incoming lane';
}

sub test_choosing_integration_lane :Tests {
    my $self = shift;

    my $flow = $self->{flow};

    note 'Create new allocation item on Integration lane';
    my $sku = $self
        ->create_allocation_item_at_delivery_destination(
            $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION
        )
        ->shipment_item
        ->get_sku;

    my ($container) =Test::XT::Data::Container->create_new_container_rows;
    my $integration_container =
        $self->schema->resultset('Public::IntegrationContainer')->create({
            container_id => $container->id,
            prl_id       => $PRL__GOH,
            from_prl_id  => $PRL__DEMATIC,
        });

    note 'Open GOH integration page';
    $flow
        ->flow_mech__fulfilment__goh_integration({ignore_cookies => 1})
        ->flow_mech__fulfilment__select_goh_integration_lane;

    my $page_data = $flow->mech->as_data;

    is(
        $page_data->{working_station_name},
        'GOH Integration',
        'Integration lane page'
    );

    ok
        grep({$_->{sku} eq $sku} @{$page_data->{integration_lane_content} }),
        'Check SKUs on incoming lane';

    ok
        !exists($page_data->{container_content}),
        'No conatiner content on the page as we just selected a lane';

    ok
        grep(
            {$_ eq $integration_container->container_id}
            @{ $page_data->{upcoming_dcd_containers} }
        ),
        'Check if newly added upcoming DCD container is shown';
}

sub test_choosing_direct_lane :Tests {
    my $self = shift;

    my $flow = $self->{flow};

    note 'Create new allocation item and make sure it is on Direct lane';
    my $sku = $self
        ->create_allocation_item_at_delivery_destination(
            $PRL_DELIVERY_DESTINATION__GOH_DIRECT
        )
        ->shipment_item
        ->get_sku;

    note 'Open GOH integration page';
    $flow
        ->flow_mech__fulfilment__goh_integration({ignore_cookies => 1})
        ->flow_mech__fulfilment__select_goh_direct_lane;

    my $page_data = $flow->mech->as_data;

    is(
        'GOH Direct',
        $page_data->{working_station_name},
        'Direct lane page'
    );

    ok
        grep({$_->{sku} eq $sku} @{$page_data->{direct_lane_content} }),
        'Check SKUs on incoming lane';
}

sub check_that_preferable_lane_is_saved :Tests {
    my $self = shift;

    note 'The idea of this test to check if preferable '
        .' lane is saved and reopening of Itgration page '
        .' leads to that lane rather than selection page.';

    note 'Make sure we get fresh Flow object for '
        .'this test as we need to have its cookies clear.';

    my $flow = $self->get_flow;
    $flow->flow_mech__fulfilment__goh_integration;
    my $page_data = $flow->mech->as_data;

    ok(
        exists($page_data->{direct_lane_button}),
        'There is button to select Direct lane, '
       .'so we are on the select lane page.'
    );

    $flow->flow_mech__fulfilment__select_goh_direct_lane;
    $page_data = $flow->mech->as_data;

    is(
        'GOH Direct',
        $page_data->{working_station_name},
        'Direct lane page is opened'
    );

    $flow->flow_mech__fulfilment__goh_integration;
    $page_data = $flow->mech->as_data;

    ok(
        !exists($page_data->{direct_lane_button}),
        'There is NO button to select Direct lane, '
       .'we were redircted streight to Direct lane page.'
    );
    is(
        'GOH Direct',
        $page_data->{working_station_name},
        'Direct lane page is opened'
    );
}

sub test_scan_sku_into_empty_container :Tests {
    my $self = shift;

    my $flow = $self->{flow};
    my ($container) =Test::XT::Data::Container->create_new_container_rows;

    note 'Make sure that rail has at least one garment on it';
    my $sku = $self
        ->create_allocation_item_at_delivery_destination(
            $PRL_DELIVERY_DESTINATION__GOH_DIRECT
        )
        ->shipment_item
        ->get_sku;

    $flow
        ->flow_mech__fulfilment__goh_integration({ignore_cookies => 1})
        ->flow_mech__fulfilment__select_goh_direct_lane
        ->flow_mech__fulfilment__scan_container_at_goh_integration(
            $container->id
        );

    my $page_data = $flow->mech->as_data;

    cmp_deeply(
        [],
        $page_data->{container_content},
        'Check that we have information about scanned container '
            . 'but it does not have any content'
    );

    $flow->flow_mech__fulfilment__scan_sku_at_goh_integration($sku);

    $page_data = $flow->mech->as_data;

    cmp_deeply(
        $page_data->{container_content},
        [ { sku => $sku } ],
        'Sku was added into container'
    );
}

sub check_that_no_dcd_container_queu_is_shown_on_direct_lane :Tests {
    my $self = shift;

    my ($container) =Test::XT::Data::Container->create_new_container_rows;
    my $integration_container =
        $self->schema->resultset('Public::IntegrationContainer')->create({
            container_id => $container->id,
            prl_id       => $PRL__GOH,
            from_prl_id  => $PRL__DEMATIC,
        });
    my $flow = $self->{flow};

    note 'Open GOH integration page';
    $flow
        ->flow_mech__fulfilment__goh_integration({ ignore_cookies => 1})
        ->flow_mech__fulfilment__select_goh_direct_lane;

    my $page_data = $flow->mech->as_data;

    ok
        !exists($page_data->{upcoming_dcd_containers}),
        'No DCD containers are shown on Direct lane';
}

sub test_missing_sku :Tests {
    my $self = shift;

    my $flow = $self->{flow};
    my ($container) =Test::XT::Data::Container->create_new_container_rows;

    note 'Make sure that rail has at least one garment on it';
    $self->create_allocation_item_at_delivery_destination(
        $PRL_DELIVERY_DESTINATION__GOH_DIRECT
    );

    note 'Select Direct lane and get its first SKU';
    $flow
        ->flow_mech__fulfilment__goh_integration({ignore_cookies => 1})
        ->flow_mech__fulfilment__select_goh_direct_lane;

    my $page_data = $flow->mech->as_data;
    my $sku = $page_data->{direct_lane_content}->[0]->{sku};

    note 'Scan empty container and mark SKU as missing';
    $flow
        ->flow_mech__fulfilment__scan_container_at_goh_integration(
            $container->id
        )
        ->flow_mech__fulfilment__missing_sku_at_goh_integration;

    $page_data = $flow->mech->as_data;

    is(
        0,
        scalar( grep { $_->{sku} eq $sku }
            @{ $page_data->{direct_lane_content} }
        ),
        'Check that SKU is not on the Direct rail anymore'
    );

    cmp_deeply(
        [],
        $page_data->{container_content},
        'Page does not show missing SKU as part of current container'
    );
}

sub anonymous_user_access_goh_integration_view_page : Tests {
    my $self = shift;
    my $flow = $self->get_flow;

    $flow->mech->get_ok('/Logout');
    $flow->flow_mech__fulfilment__goh_integration_logged_out_user_access;
}

# UTILITIES (move to the Role if those methods are used more then
# in one file)

sub get_flow {

    my $perms = {
        $AUTHORISATION_LEVEL__OPERATOR => [
            'Fulfilment/GOH Integration',
        ],
        $AUTHORISATION_LEVEL__MANAGER => [
            'Fulfilment/GOH Integration',
        ],
    };

    my $flow = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Fulfilment',
        ],
    );

    $flow->login_with_permissions({
        dept  => 'Distribution Management',
        perms => $perms,
    });

    return $flow;
}
