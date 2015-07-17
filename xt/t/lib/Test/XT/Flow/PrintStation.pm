package Test::XT::Flow::PrintStation;
use NAP::policy qw( test role );

use URI;
requires 'mech';

with 'Test::XT::Flow::AutoMethods';

=head1 NAME

Test::XT::Flow::PrintStation

=cut

__PACKAGE__->create_custom_method(
    method_name      => 'flow_mech__select_printer_station',
    handler          => sub {
        my ($self,$args) = @_;

        my $uri = URI->new($self->mech->base);
        $uri->path('/My/SelectPrinterStation');
        $uri->query_form(
            section         => $args->{section},
            subsection      => $args->{subsection},
            channel_id      => $args->{channel_id},
            # We default to 1 in our tests so unless required we don't need to
            # change our flow in the callers where we have just one printer for
            # the section
            force_selection => $args->{force_selection}//1,
        );

        $self->mech->get_ok($uri);

        return $self;
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__select_printer_station_submit',
    assert_location  => qr!^/My/SelectPrinterStation\?!,
    form_name        => 'SelectPrinterStation',
    form_description => 'printer station',
    transform_fields => sub {
        my ( $self, $ps_value ) = @_;
        # Default station
        $ps_value ||= (grep {
            $_ ne q{}
        } map { $_->{value} } @{$self->mech->as_data->{stations}})[0];
        return { ps_name => $ps_value };
    },
);

=head1 task__set_printer_station(section, subsection, channel_id?) :

Pick the first available printer for the given args.

=cut

sub task__set_printer_station {
    my ( $self, $section, $subsection, $channel_id ) = @_;
    $self->flow_mech__select_printer_station({
        section => $section,
        subsection => $subsection,
        channel_id => $channel_id,
    });
    return $self->flow_mech__select_printer_station_submit;
}

1;
