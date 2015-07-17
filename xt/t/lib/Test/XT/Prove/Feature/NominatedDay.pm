package Test::XT::Prove::Feature::NominatedDay;

=head1 NAME

Test::XT::Prove::Feature::NominatedDay - Test data and methods for Nominated Day functionality

=head1 DESCRIPTION

Test data and methods for Nominated Day functionality.

Verify that the shipment status and the hold status is correct, according to
whether or not the SLA is breached.

=head1 TEST DATA

    * due for selection
    * overdue selection
    * not due for selection

=head1 METHODS

=cut

use NAP::policy "tt", 'class', 'test';
with 'Test::XT::Prove::Role::DateTime::Manipulate';

use Readonly;
use Path::Class;
use DateTime;

use XTracker::Database::Distribution;
use XTracker::Config::Local 'config_var';
use XTracker::Constants::FromDB qw(
    :customer_category
    :shipment_status
    :shipment_hold_reason
    :shipment_type
);
use Test::XTracker::Data;
use Test::XTracker::Utils;
use XTracker::Script::Shipment::NominatedDayActualBreach;

Readonly our $NOMINATEDDAY_TEST_DATA => [
    {
        _name => 'due for selection',
        test => {
            manual_select => {
                type => 'is_checkbox',
                is_returned => 1,
            },
            auto_select => {
                is_selectable => 1,
            },
            possible_breach => {
                is_possible => 1,
                is_staff_possible => 0,
            },
            breach => {
                is_breach => 0,
                is_staff_breach => 0,
            }
        },
        dispatch_time => {
            add => {
                hours => 4,
            },
        },
        sla_cutoff_time => {
           add => {
                minutes => 50,
            },
        },
        earliest_selection_time => {
           subtract => {
                hours => 2,
            },
        },
    },{
        _name => 'overdue selection',
        test => {
            manual_select => {
                type => 'is_checkbox',
                value => '',
                is_returned => 1,
            },
            auto_select => {
                is_selectable => 1,
            },
            possible_breach => {
                is_possible => 0,
                is_staff_possible => 0,
            },
            breach => {
                is_breach => 1,
                is_staff_breach => 0,
            }
        },
        dispatch_time => {
            add => {
                hours => 4,
            },
        },
        sla_cutoff_time => {
           subtract => {
                hours => 2,
            },
        },
        earliest_selection_time => {
           subtract => {
                hours => 3,
            },
        },
    },{
        _name => 'not due for selection',
        test => {
            manual_select => {
                type => 'is_held',
                is_returned => 1,
            },
            auto_select => {
                is_selectable => 0,
            },
            possible_breach => {
                is_possible => 0,
                is_staff_possible => 0,
            },
            breach => {
                is_breach => 0,
                is_staff_breach => 0,
            }
        },
        dispatch_time => {
            add => {
                hours => 4,
            },
        },
        sla_cutoff_time => {
           add => {
                minutes => 75,
            },
        },
        earliest_selection_time => {
            add => {
                hours => 2,
            },
        },
    },
];


=head2 get_nominated_day_test_data

=cut

sub get_nominated_day_test_data {
    return $NOMINATEDDAY_TEST_DATA;
}

=head2 test_possible_and_actual_breach

=cut

sub test_possible_and_actual_breach {
    my($self,$test,$shipment,$test_email_file) = @_;
    my $schema = $shipment->result_source->schema;
    my $customer = $shipment->order->customer;

    $customer->update({
        category_id => $CUSTOMER_CATEGORY__STAFF,
    });
    $shipment->update({ shipment_status_id => $SHIPMENT_STATUS__PROCESSING });

    $self->_test_call_invoke_possible_breach(
        $shipment,$test->{possible_breach}->{is_staff_possible},'Staff',
        $test_email_file,
        $shipment->is_premier,
    );
    $self->_test_call_invoke_actual_breach(
        $shipment,$test->{breach}->{is_staff_breach},'Staff',
        $test_email_file,
        $shipment->is_premier,
    );


    # set it to a non-staff category
    $customer->update({
        category_id => $CUSTOMER_CATEGORY__NONE,
    });
    $shipment->update({ shipment_status_id => $SHIPMENT_STATUS__PROCESSING });

    $self->_test_call_invoke_possible_breach(
        $shipment,$test->{possible_breach}->{is_possible},'Non-Staff',
        $test_email_file,
        $shipment->is_premier,
    );
    $self->_test_call_invoke_actual_breach(
        $shipment,$test->{breach}->{is_breach},'Non-Staff',
        $test_email_file,
        $shipment->is_premier,
    );


    # premier orders are ignored for actual breaches
    $customer->update({
        category_id => $CUSTOMER_CATEGORY__NONE,
    });
    $shipment->update({
        shipment_status_id => $SHIPMENT_STATUS__PROCESSING,
        shipment_type_id => $SHIPMENT_TYPE__PREMIER,
    });

    $self->_test_call_invoke_possible_breach(
        $shipment,$test->{possible_breach}->{is_possible},'Non-Staff',
        $test_email_file,
        $shipment->is_premier,
    );
    $self->_test_call_invoke_actual_breach(
        $shipment,$test->{breach}->{is_breach},'Non-Staff',
        $test_email_file,
        $shipment->is_premier,
    );
}

sub _test_call_invoke_actual_breach {
    my($self,$shipment,$expect,$prefix,$test_email_file,$is_premier) = @_;
    my $schema = $shipment->result_source->schema;
    my @ids = $self->_invoke_script(
        XTracker::Script::Shipment::NominatedDayActualBreach->new(),
        $prefix,
        $shipment,
        $test_email_file,
        $expect,
        $is_premier,
    );


    # if we're expecting something then check up on the status and that a
    # hold reason matches what we want for the possible breach
    if ($expect) {
        $shipment->discard_changes;
        isnt($shipment->shipment_status_id, $SHIPMENT_STATUS__HOLD,
            'shipment is not on hold');
    }

    # if they've passed a file for the contents of the email, test it
    $self->test_email_content(
        $expect,$shipment->id, $test_email_file, $is_premier
    );

}

sub _invoke_script {
    my($self,$script,$prefix,$shipment,$test_email_file,$expect,
        $is_premier) = @_;
    my $schema = $shipment->result_source->schema;

    $self->_unlink_email_files($test_email_file);

    my @shipment_ids = $script->invoke(
        verbose => 1,
    );

    # we are only interested in the shipment we created
    my @ids = grep { $_ == $shipment->id } @shipment_ids;

    if ($is_premier) {
        is(scalar @ids, 0,
            'premier shipment is not returned ids');
    } else {
        is(scalar @ids, $expect,
            $prefix
            . 'returned as expected ('
            . (defined $expect ? $expect : 'UNDEF')
            . ')'
        );
        is(scalar @ids, $expect, "Got the correct number of ids");
    }

    return @ids;
}

sub _test_call_invoke_possible_breach {
    my ($self,$shipment,$expect,$prefix,$test_email_file,$is_premier ) = @_;
    my @ids = $self->_invoke_script(
        XTracker::Script::Shipment::NominatedDayPossibleBreach->new(),
        $prefix,
        $shipment,
        $test_email_file,
        $expect,
        $is_premier,
    );


    # if we're expecting something then check up on the status and that a
    # hold reason matches what we want for the possible breach
    if ($expect) {
        $shipment->discard_changes;
        is($shipment->shipment_status_id, $SHIPMENT_STATUS__HOLD,
            'shipment is on hold');

        # check holding reason is there
        my @hold_reason = $shipment
            ->shipment_holds
            ->search({shipment_hold_reason_id => $SHIPMENT_HOLD_REASON__NOMINATED_DAY_POSSIBLE_SLA_BREACH})
            ->all;

        is(scalar @hold_reason, 1, 'possible - found hold reason');
    }

    # if they've passed a file for the contents of the email, test it
    $self->test_email_content(
        $expect,$shipment->id, $test_email_file,$is_premier
    );

}

sub _unlink_email_files {
    my($self,$file) = @_;

    unlink(glob("$file.*"));
}

=head2 test_email_content

=cut

sub test_email_content {
    my($self,$expect,$id,$test_email_file,$is_premier) = @_;
    my @files = glob("$test_email_file.*");
    my $found = 0;

    foreach my $file (@files) {
        my $content = Test::XTracker::Utils->slurp_file(
            Path::Class::File->new($file)
        ) // '';
        $found++ if ($content =~ /Shipment Number: $id/);

        unlike($content, qr/DOCTYPE/, "not html - $file");
    }

    if ($is_premier) {
        is($found, 0,
            'premier: not found shipment_id in email - '. $id);
    } else {
        is($found, $expect,
            'found shipment_id in email - '. $id);
    }
}

=head2 test_auto_select

=cut

sub test_auto_select {
    my($self,$case,$shipment) = @_;

    $self->_test_get_selection_list_method(
        # 1 is passed to the get_selection_list method to indicate it is an
        # auto_select call and only return shipments ready to be selected
        $shipment,$case->{test}->{auto_select}->{is_selectable},1
    );
}

=head2 test_manual_select_get_selection_list

=cut

sub test_manual_select_get_selection_list {
    my($self,$test,$shipment) = @_;

    $self->_test_get_selection_list_method(
        # 0 is passed to the get_selection_list method to indicate it is an
        # NOT auto_select and it can return items not ready to be selected
        # as these will be display differently in the page
        $shipment,$test->{manual_select}->{is_returned},0
    );

}

sub _test_get_selection_list_method {
    my ($self, $shipment, $is_selectable, $auto_select) = @_;

    is(ref($shipment),'XTracker::Schema::Result::Public::Shipment', 'have shipment');

    my $eligable_shipments = Test::XTracker::Model->get_schema()->resultset('Public::Shipment')->get_order_selection_list({
        exclude_held_for_nominated_selection => $auto_select,
    });

    my $eligible_count = $eligable_shipments->count();
    note "Eligible shipments count: $eligible_count\n";

    my @found_records = $eligable_shipments->search({ id => $shipment->id });

    is(
        scalar @found_records,
        $is_selectable,
        "get_selection_list returned what we expect ($is_selectable)",
    );
}

=head2 set_nominated_fields

=cut

sub set_nominated_fields {
    my($self,$shipment,$data,$timezone,$date) = @_;

    my $delivery_date = $self->manipulate_now_time(undef,$date)
        ->set_time_zone($timezone)->truncate(to => "day");
    my $earliest_selection_time = $self->manipulate_now_time(
        $data->{earliest_selection_time},$date)->set_time_zone($timezone);

    my $sla_cutoff_time = $self->manipulate_now_time(
        $data->{sla_cutoff_time},$date)->set_time_zone($timezone);

    my $dispatch_time = $self->manipulate_now_time(
        $data->{dispatch_time},$date)->set_time_zone($timezone);

    my $format = '%Y-%m-%d %H:%M:%S %z';
    my $now = $self->manipulate_now_time(undef,$date)->set_time_zone($timezone);
    note "                               now: " . $now->strftime($format);
    note "           nominated_delivery_date: " . $delivery_date->strftime($format);
    note "                   sla_cutoff_time: " . $sla_cutoff_time->strftime($format);
    note " nominated_earliest_selection_time: " . $earliest_selection_time->strftime($format);
    note "           nominated_dispatch_time: " . $dispatch_time->strftime($format);

    my $schema      = Test::XTracker::Model->get_schema;
    my $date_parser = $schema->storage->datetime_parser;

    $shipment->update({
        nominated_delivery_date           => $delivery_date,
        nominated_dispatch_time           => $dispatch_time,
        sla_cutoff                        => $sla_cutoff_time,
        nominated_earliest_selection_time => $earliest_selection_time,
    });

    return $shipment;
}

=head2 create_shipment

=cut

sub create_shipment {
    my($self,$args) = @_;
    $args->{date} //= DateTime->now();


    # create shipment and set it to today's date
    my $shipment = Test::XTracker::Data->create_domestic_order(
        channel => $args->{channel},
        pids => $args->{pids},
    )->shipments->first;

    if ($args->{premier}) {
        $shipment->update({
            shipment_type_id => $SHIPMENT_TYPE__PREMIER
        });
    }

    $self->set_nominated_fields($shipment, {
            # just set it to now - no manipulation needed
            dispatch_time           => { add => { minutes => 1} },
            sla_cutoff_time         => { add => { minutes => 1} },
            earliest_selection_time => { add => {minutes => 1} },
        }, $args->{timezone}, $args->{date});


    my $public_shipment_rs = Test::XTracker::Model->get_schema
        ->resultset('Public::Shipment');

    note "shipment_id: ". $shipment->id;
    note "nominated shipment count: ".
        $public_shipment_rs->nominated_to_dispatch_on_day($args->{date})->count;

    return $shipment;

}




1;
