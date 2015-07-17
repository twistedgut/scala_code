package Test::XTracker::Mechanize::StockControl;

use NAP::policy "tt", 'test';
use XTracker::Constants::FromDB qw(
    :channel
);
use Test::XTracker::Data;
use XTracker::Constants::FromDB qw(
    :channel
    :stock_process_type
    :stock_process_status
    :authorisation_level
    :flow_status
);


use Data::Dump qq/pp/;

use Moose;

extends 'Test::XTracker::Mechanize', 'Test::XTracker::Data';

with 'WWW::Mechanize::TreeBuilder' => {
    tree_class => 'HTML::TreeBuilder::XPath'
};

############################
# Page workflow methods
############################

# URI: /StockControl/Location
#   get the Stock Control Location page
#
sub test_location {
    my($self,$opts) = @_;
    my $locs;

    $self->get_ok('/StockControl/Location');

    # we need to create some locations
    if (defined $opts and ref($opts) eq 'HASH') {
        note "creating locations";
        $locs = $self->data__location__create_new_locations($opts);
    }

    return $locs;
}

sub test_location_create {
    my($self,$opts,$locs) = @_;

    my $location_type = defined $opts->{location_type} ? $opts->{location_type} : $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;

    foreach my $loc (@{$locs}) {
        my($dc,$floor,$zone,$location,$level) = $self->split_location($loc);

        $self->follow_link_ok({text_regex => qr/Create/});

        $self->ok_channel_select_box('frm_sales_channel',
            { no_all => 1 });

        $self->submit_form_ok({
            with_fields => {
                start_floor     => $floor,
                start_zone      => $zone,
                start_location  => $location,
                start_level     => $level,

                end_floor       => $floor,
                end_zone        => $zone,
                end_location    => $location,
                end_level       => $level,

                frm_sales_channel   => $opts->{channel_id},
                location_type       => $location_type,
                    # this should say main stock
            },
        }, 'submitting new location allocation');

    # TODO: {
            #    $self->content_contains("creating location $loc",
            #    'location created');
            #}
    }

    return $locs;
}

sub split_location {
    my($self,$loc) = @_;
    my $dc = undef;
    my $floor = undef;
    my $zone = undef;
    my $location = undef;
    my $level = undef;

    if ($loc =~ /^(\d{2})(\d{1})(\w{1})(\d{3})(\w{1})$/) {
        my $dc = $1;
        my $floor = $2;
        my $zone = $3;
        my $location = $4;
        my $level = $5;
    }
    return ($dc,$floor,$zone,$location,$level);
}


__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
no Moose;

1;
