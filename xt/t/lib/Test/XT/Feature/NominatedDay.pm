package Test::XT::Feature::NominatedDay;

use NAP::policy "tt", qw( test role );


sub test_mech__fulfilment__selection_nominatedday {
    my($self,$test,$shipment) = @_;

    $self->announce_method;
    note '  for shipment_id (' . $shipment->id . ')';

    my $query = '//table//tr[@id="'. $shipment->id .'"]';
    note "  query: $query";

    my $col_sla_timer_index = -1;
    my $col_pick_now_index = -1;

    my $node = $self->mech->find_xpath($query)->pop;
    my @fields = $node->look_down('_tag','td');

    my $type = $test->{type} || '';
    if ($type eq 'is_checkbox') {
        my $input_node = $fields[$col_pick_now_index]->look_down('_tag', 'input')
            or die("Could not find an <input> in the $col_pick_now_index <td>");
        is(
            $input_node->attr('type'),
            'checkbox',
            'checkbox exists',
        );

    } elsif ($type eq 'is_held') {
        like(
            $fields[$col_sla_timer_index]->as_text,
            qr/Earliest selection \d+-\d+-\d{4} \d{2}:\d{2} \Q(nom day)/,
            'found hold message',
        );
    } else {
        croak "Don't know what '$type' is in terms of nominated day test";
    }


    return $self;

}



1;
