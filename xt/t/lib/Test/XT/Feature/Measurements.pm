package Test::XT::Feature::Measurements;
use NAP::policy "tt", qw( test role );

=head1 NAME

Test::XT::Feature::Measurements

=head2 DESCRIPTION

Role to use with C<Test::XT::Flow> that provides Measurements related tests.

    my $flow1 = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Feature::Measurements'
        ],
    );

=cut

use XTracker::Config::Local;


=head1 METHODS

=head2 test_mech__goodsin__qualitycontrol_measurements

=cut

sub test_mech__goodsin__qualitycontrol_measurements {
    my($self) = @_;

    $self->announce_method;

    my $wanted_count = 0;

    # Check the correct measurement types are displayed
    foreach my $variant ($self->product->variants) {
        foreach my $measurement (@{$self->attr__measurements__measurement_types}) {
            my $field_name = "measure-".$variant->id."-".$measurement->measurement;
            my $field = $self->mech->look_down('name', $field_name);
            isnt($field, undef, "Variant ".$variant->id.": field for ".$measurement->measurement." exists");
            $wanted_count++;
        }
    }

    return $self;
}

=head2 test_mech__stockcontrol__measurement

=cut

sub test_mech__stockcontrol__measurement {
    my($self) = @_;

    $self->announce_method;

    my $wanted_count = 0;

    foreach my $variant ($self->product->variants) {
        foreach my $measurement (@{$self->attr__measurements__measurement_types}) {
            my $field_name = "measure-".$variant->id."-".$measurement->measurement;
            my $field = $self->mech->look_down('name', $field_name);
            isnt($field, undef, "Variant ".$variant->id.": field for ".$measurement->measurement." exists");
            my $value = $self->attr__measurements__variant_measurement_values->{$variant->id}->{$measurement->id};
            is($field->attr('value'), $value, "Measurement value is correct");

            $wanted_count+=3; # each one has 3 inputs - value, checkbox, hidden
        }
    }
    $wanted_count++; # the submit button

    # Check we're not displaying any bonus measurements
    my $measurements_table = $self->mech->find_xpath(
        "//table[\@id='editMeasurements']"
    )->pop;
    my @measurement_inputs = $measurements_table->look_down('_tag','input');
    is (scalar @measurement_inputs, $wanted_count, "Measurements table contains the right number of fields");

    return $self;
}

=head2 test_mech__stockcontrol__product_overview__measurement_link

Test that the Product Overview page has a menu item called 'Measurements', that
links to the Measurements page.

=cut

sub test_mech__stockcontrol__product_overview__measurement_link {
    my ( $self, $product_id ) = @_;

    $self->announce_method;

    # Default in case not provided.
    $product_id //= $self->product->id;

    # Make sure we're on the Product Overview page.
    like(
        $self->mech->uri,
        qr{/StockControl/Inventory/Measurement},
        'We are on the right version of the page [Stock Control - Inventory - Measurement]'
    );

    # check on the page that every input is Read-Only
    my $pg_data = $self->mech->as_data()->{measurements};
    my $editable_counter    = 0;
    foreach my $row ( @{ $pg_data } ) {
        $editable_counter++     if ( grep { ref( $_ ) && !$_->{input_readonly} } values %{ $row } );
    }
    cmp_ok( $editable_counter, '==', 0, "All fields on the Page are Read-Only" );

    note "check that the 'Product Overview' link is in the Left Hand Menu and can be clicked on";
    $self->flow_mech__stockcontrol__inventory_product_overview_link;

    return $self;
}

1;
