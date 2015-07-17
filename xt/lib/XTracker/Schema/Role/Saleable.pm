package XTracker::Schema::Role::Saleable;
use Moose::Role;

sub get_saleable_item_quantity_rs {
    my $self = shift;

    my $pid = $self->id;
    $self->result_source->schema->resultset('Public::VirtualProductSaleableQuantity')->search({}, {bind => [$pid, $pid, $pid, $pid, $pid]});
}

sub get_saleable_item_quantity {
    my $rs = shift->get_saleable_item_quantity_rs;
    my $data;
    while (my $row = $rs->next){
        $data->{ $row->sales_channel }->{ $row->variant_id } = $row->quantity;
    }
    return $data;
}

sub get_saleable_item_quantity_details_rs {
    my $self = shift;

    my $pid = $self->id;
    $self->result_source->schema->resultset('Public::VirtualProductSaleableQuantityDetails')->search({}, {bind => [($pid) x 5]});
}

sub get_saleable_item_quantity_details {
    my $rs = shift->get_saleable_item_quantity_details_rs
        ->search({},{result_class => 'DBIx::Class::ResultClass::HashRefInflator'});
    my $data;
    while (my $row = $rs->next){
        my $chid = delete $row->{channel_id};
        my $vid = delete $row->{variant_id};
        my $vtype = delete $row->{variant_type_id};
        $data->{$chid}{$vid}{$vtype} = $row;
    }
    return $data;
}

1;
