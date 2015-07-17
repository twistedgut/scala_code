package Test::XT::Data::Fulfilment::Report::Migration;
use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN {
    extends "NAP::Test::Class";
    with (
        "NAP::Test::Class::PRLMQ",
        "NAP::Test::Class::PRLMQ::Messages",
    );
}

use Test::XTracker::RunCondition prl_phase => 'prl';

use XT::Data::Fulfilment::Report::Migration;
use Test::XT::Fixture::Migration::Product;
use XTracker::Constants qw(
    :prl_type
);

sub activemq_message_rs {
    my $self = shift;
    my $schema = $self->schema;
    return scalar $schema->resultset("Public::ActivemqMessage")->search({
        created => { ">" => $schema->db_now_raw },
    });
}

sub basic : Tests() {
    my $self = shift;
    my $report;
    lives_ok(
        sub { $report = XT::Data::Fulfilment::Report::Migration->new() },
        "New with no args works",
    );

    lives_ok(
        sub {
            $report->stock_adjust_messages_rs->all;
            $report->container_info_by_id();
        },
        "Running the query lives ok",
    );
}

# new Report::Migration, with the activemq_message_rs limited to
# results from now onwards, to avoid involving earlier test data
sub new_report {
    my $self = shift;
    return XT::Data::Fulfilment::Report::Migration->new({
        activemq_message_rs => $self->activemq_message_rs,
        @_,
    });
}

# Validation
# set dates

sub all_columns_present : Tests() {
    my $self = shift;

    my $report = $self->new_report();

    note "Create a migration stock adjust to kick off a pprep group";
    my $fixture = Test::XT::Fixture::Migration::Product->new()
        ->with_new_container()
        ->with_sent_stock_adjust_message()
        ;

    my $messages_rs = $report->stock_adjust_messages_rs;
    is($messages_rs->count, 1, "Got one stock adjust row back");

    my $message_row = $messages_rs->first;

    my $expected_container_id = $fixture->container_row->id;
    is(
        $message_row->migration_container_id,
        $expected_container_id,
        "Container ok",
    );

    my $sku = $fixture->variant_rows->[0]->sku;
    is($message_row->sku, $sku, "SKU ok");

    my $expected_delta_quantity = 4;
    is(
        $message_row->delta_quantity,
        $expected_delta_quantity,
        "delta_quantity ok",
    );

    my $container_info = $report->container_info( $message_row );
    my $expected_operator_name = "Application";
    is(
        $container_info->{operator_name},
        $expected_operator_name,
        "operator_name ok (App operator)",
    );
    is($container_info->{status}, "In Progress", "container status ok");
    my $expectd_mgid = $fixture->pprep_container_mgid;
    is($container_info->{mgid}, $expectd_mgid, "mgid ok");
    ok($container_info->{modified}, "modified exists");


    note "Sanity check the CSV output";
    chomp( my $csv = $report->as_csv() );
    is(
        scalar split(/\n/, $csv),
        2,
        "Two lines in csv (header and 1 line of data",
    );
    my $date_rex = qr/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/;

    # needs quotemeta because of whitespace
    my $expected_status_rex = quotemeta( $container_info->{status} );

    my $expected_mgid_rex = qr/\d+/;

    like(
        $csv,
        qr/
              $date_rex ,
              $expected_container_id ,
              $sku ,
              $expected_delta_quantity ,
              $expected_operator_name ,
              " $expected_status_rex " , # quoted because whitespace
              $expected_mgid_rex ,
              $container_info->{modified}
          /xsm,
        "Data line contains all interesting values",
    );
}

sub stages : Tests() {
    my $self = shift;

    note "Create a migration stock adjust to kick off a pprep group";
    my $fixture = Test::XT::Fixture::Migration::Product->new();

    my $report = $self->new_report();


    my $first_sku = $fixture->variant_rows->[0]->sku;
    my $second_sku = $fixture->variant_rows->[1]->sku;
    my @expected;

    my $description;

    $description = "C1 first sa for container -> In Progress";
    note $description;
    $fixture
        ->with_new_container()
        ->with_sent_stock_adjust_message()
        ;
    push(
        @expected,
        {
            description  => $description,
            container_id => $fixture->container_row->id,
            sku          => $first_sku,
            mgid         => $fixture->pprep_container_mgid,
            status       => "In Progress",
        },
    );


    $description = "C2 last sa for container -> In Transit";
    note $description;
    $fixture
        ->with_new_container()
        ->with_sent_stock_adjust_message({
            sku => $first_sku,
        })
        ->with_sent_final_stock_adjust_message({
            sku               => $second_sku,
            migrate_container => $PRL_TYPE__BOOLEAN__TRUE,
        })
        ;
    push(
        @expected,
        {
            description  => $description,
            container_id => $fixture->container_row->id,
            sku          => $first_sku,
            mgid         => $fixture->pprep_container_mgid,
            status       => "In Transit",
        },
        {
            description  => $description,
            container_id => $fixture->container_row->id,
            sku          => $second_sku,
            mgid         => $fixture->pprep_container_mgid,
            status       => "In Transit",
        },
    );


    $description = "C3 Advice Response received -> Complete";
    note $description;
    $fixture
        ->with_new_container()
        ->with_sent_final_stock_adjust_message({
            migrate_container => $PRL_TYPE__BOOLEAN__TRUE,
        })
        ->with_received_advice_reponse_message();
        ;
    push(
        @expected,
        {
            description  => $description,
            container_id => $fixture->container_row->id,
            sku          => $first_sku,
            mgid         => $fixture->pprep_container_mgid,
            status       => "Complete",
        },
    );

    $description = "C3 Advice Response received -> Failure";
    note $description;
    $fixture
        ->with_new_container()
        ->with_sent_stock_adjust_message({
            migrate_container => $PRL_TYPE__BOOLEAN__TRUE,
        })
        ->with_received_advice_reponse_message({
            success => $PRL_TYPE__BOOLEAN__FALSE,
        })
        ;
    push(
        @expected,
        {
            description  => $description,
            container_id => $fixture->container_row->id,
            sku          => $first_sku,
            mgid         => $fixture->pprep_container_mgid,
            status       => "Failure",
        },
    );



    my $messages_rs = $report->stock_adjust_messages_rs;
    is($messages_rs->count, 5, "Got expected stock adjust rows back");

    my @all_messages = $messages_rs->all;
    for my $expected_rec (reverse @expected) { # reverse, because the order_by desc created
        note "Comparing $expected_rec->{description}";
        my $message_row = shift(@all_messages);
        my $migration_container_id = $message_row->migration_container_id;

        is(
            $migration_container_id,
            $expected_rec->{container_id},
            "Container ($expected_rec->{container_id}) ok",
        );
        my $sku = $expected_rec->{sku};
        is($message_row->sku, $sku, "SKU ($sku) ok");
        my $container_info = $report->container_info( $message_row );
        is(
            $container_info->{mgid},
            $expected_rec->{mgid},
            "mgid ok",
        );
        is(
            $container_info->{status},
            $expected_rec->{status},
            "container status ok",
        );
    }
}

sub filter_pid_and_container : Tests() {
    my $self = shift;

    note "Create a migration stock adjust to kick off a pprep group";
    my $fixture_product_a = Test::XT::Fixture::Migration::Product->new();
    my $fixture_product_b = Test::XT::Fixture::Migration::Product->new();

    note "Instantiate reports before running tests, to limit the time";
    my $report_with_pid_filter       = $self->new_report();
    my $report_with_container_filter = $self->new_report();

    note "One stock adjust for each product";
    $fixture_product_a
        ->with_new_container()
        ->with_sent_final_stock_adjust_message()
        ;
    $fixture_product_b
        ->with_new_container()
        ->with_sent_final_stock_adjust_message()
        ;

    note "Set filters on reports";
    $report_with_pid_filter->pid(
        $fixture_product_b->product_rows->[0]->id,
    );
    $report_with_container_filter->container_id(
        $fixture_product_b->container_row->id,
    );


    my $cases = [
        {
            description => "PID filter",
            report      => $report_with_pid_filter,
        },
        {
            description => "Container filter",
            report      => $report_with_container_filter,
        },
    ];
    for my $case ( @$cases ) {
        note "Testing report with $case->{description}";

        my $report = $case->{report};
        my $messages_rs = $report->stock_adjust_messages_rs;
        is($messages_rs->count, 1, "Got only one stock adjust back");

        my $message_row = $messages_rs->first;
        my $migration_container_id = $message_row->migration_container_id;
        my $expected_container_id = $fixture_product_b->container_row->id;
        is(
            $migration_container_id,
            $expected_container_id,
            "Container is the one for the filtered product",
        );
    }
}

# date cutoffs


