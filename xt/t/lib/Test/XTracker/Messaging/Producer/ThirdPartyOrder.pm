package Test::XTracker::Messaging::Producer::ThirdPartyOrder;
use NAP::policy "tt", 'class';
use Test::XTracker::Data; # to load test config
with 'NAP::Messaging::Role::Producer';

sub message_spec {
    return {
        type => '//any',
    };
}

has '+type' => ( default => 'order' );
has '+destination' => (
    default => Test::XTracker::Config->messaging_config
        ->{'Consumer::JimmyChooOrder'}{routes_map}{destination}
);

sub transform {
    my ($self, $header, $data) = @_;

    $header->{reply_to} = 'jchoo-order-exporter-test';

    my $rh_amq_data = {
        %{$data},
    };

    return ($header, $rh_amq_data );

}
