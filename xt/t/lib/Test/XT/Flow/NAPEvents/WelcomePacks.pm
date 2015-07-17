package Test::XT::Flow::NAPEvents::WelcomePacks;

use NAP::policy "tt",     qw( test role );
with 'Test::XT::Flow::AutoMethods';

=head1 NAME

Test::XT::Flow::NapEvents::WelcomePacks

=head1 DESCRIPTION

Flow methods to test Marketing Welcome Packs admin page

=head1 METHODS

=head2 flow_mech__napevents_welcomepacks

    $framework->flow_mech__napevents_welcomepacks;

Goes to the 'NAP Events -> Welcome Packs' page.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__napevents_welcomepacks',
    page_description => 'Welcome Packs page',
    page_url         => '/NAPEvents/WelcomePacks',
);

=head2 flow_mech__napevents_welcomepacks__submit

    $framework->flow_mech__napevents_welcomepacks__submit( {
        # use any/all of the following:

        # array of System Config Group Ids you wish to
        # uncheck/check their 'Enable All Packs' checkboxes
        switch_off_groups   => [
            1, 45, 56
        ],
        switch_on_groups    => [
            1, 45, 56
        ],

        # array of System Config Setting Ids you wish
        # to turn On/Off their corresponding Language
        # Welcome Pack
        switch_off_settings => [
            45, 678, 234
        ],
        switch_on_settings  => [
            45, 678, 234
        ],
    } );

Submits changes to the 'NAP Events -> Welcome Packs' such as turning off
whole Sales Channels Packs or just individual Packs.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__napevents_welcomepacks__submit',
    form_name         => 'welcome_pack_admin_form',
    form_description  => 'Change Welcome Pack Settings',
    assert_location   => qr!^/NAPEvents/WelcomePacks!,
    transform_fields  => sub {
        my ( $self, $args ) = @_;

        my $mech    = $self->mech;
        my %fields;

        # need to use the FORM in the page for checkboxes
        $mech->form_name('welcome_pack_admin_form');

        foreach my $id ( @{ $args->{switch_off_groups} } ) {
            $mech->untick( "conf_group_${id}", 1 );
        }

        foreach my $id ( @{ $args->{switch_on_groups} } ) {
            $mech->tick( "conf_group_${id}", 1 );
        }

        foreach my $id ( @{ $args->{switch_off_settings} } ) {
            $fields{ "conf_setting_${id}" } = 0;
        }

        foreach my $id ( @{ $args->{switch_on_settings} } ) {
            $fields{ "conf_setting_${id}" } = 1;
        }

        return \%fields;
    },
);
