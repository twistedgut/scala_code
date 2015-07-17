package Test::XT::Feature::Ch11n::GoodsIn;

use NAP::policy "tt", qw( test role);

#
# Channelisation support tests
#
use XTracker::Config::Local;



sub test_mech__goodsin__stockin_ch11n {
    my($self) = @_;

    $self->announce_method;

    $self->mech_select_box_ch11n;

}

sub test_mech__goodsin__stockin_packingslip_ch11n {
    my($self,$po) = @_;

    $self->announce_method;

    # It it channelised correctly
    return $self
        ->mech_logo_ch11n
        ->mech_title_ch11n(['Enter Packing Slip Values',
            $self->mech->channel->name])
        ;
}

sub test_mech__goodsin__stockin_search_ch11n {
    my ($self) = @_;

    $self->announce_method;

    # The page should have been submitted, and show the PO in the list
    my $title_class = $self->_title_class;
    my $open_plus = $self->mech->look_down('id', "open_". $self->purchase_order->id);

    isnt($open_plus, undef, 'PO found in list');

    # Ensure that the channel name appears on the list with the correct colour
    my $results = $self->mech->look_down('class', $title_class);
    isnt($results, undef, 'channel appears in the list');

    return $self;
}

sub test_mech__goodsin__itemcount_ch11n {
    my ($self) = @_;

    $self->announce_method;

    return $self->mech_tab_ch11n;
}

sub test_mech__goodsin__itemcount_counts_ch11n {
    my ($self) = @_;

    $self->announce_method;

    my $channel = $self->mech->channel;

    $self->mech_logo_ch11n; # ($channel);

    $self->mech_title_ch11n(
#        $channel,
        ['Product Information', 'Unit Count', $channel->name]
    );

    return $self;
}

sub test_mech__goodsin__qualitycontrol_ch11n {
    my($self) = @_;

    $self->announce_method;

    # Ensure the tab is set up with the correct CSS
    note $self->mech->uri;
    $self->mech_tab_ch11n;

    return $self;
}

sub test_mech__goodsin__qualitycontrol_processitem_ch11n {
    my($self) = @_;

    $self->announce_method;

    my $po = $self->purchase_order;

    $self->mech_logo_ch11n($po->channel) or note $self->mech->uri;
    $self->mech_title_ch11n([
        'Product Information',
        'QC Results',
        'Measurements',
        $po->channel->name
    ]) or note $self->mech->uri;

    return $self;
}

sub test_mech__goodsin__surplus_ch11n {
    my($self) = @_;

    $self->announce_method;

    my $po = $self->purchase_order;

    $self->mech_tab_ch11n;

    return $self;
}

sub test_mech__goodsin__surplus_process_ch11n {
    my($self) = @_;

    $self->announce_method;

    my $po = $self->purchase_order;

    $self->mech_logo_ch11n;
    $self->mech_title_ch11n(['Process Surplus Units']);

    return $self;
}

sub test_mech__goodsin__bagandtag_ch11n {
    my($self) = @_;

    $self->announce_method;

    my $po = $self->purchase_order;

    $self->mech_tab_ch11n;

    $self->mech_element_classes_ch11n({
        expect => 1,
        channel => $po->channel,
        names => ['Items Awaiting Bag & Tag'],
    });

    return $self;
}

sub test_mech__goodsin__putaway_ch11n {
    my($self) = @_;

    $self->announce_method;

    my $po = $self->purchase_order;

    $self->mech_tab_ch11n;
    $self->mech_element_classes_ch11n({
        expect => 1,
        channel => $po->channel,
        # there should be at least this section - others are possible
        names => [ 'Process Groups Awaiting Putaway', ],
    });

    return $self;
}


1;
