package XT::DC::Messaging::Producer::Shipping::DutyRate;
use NAP::policy "tt", 'class';
with 'XT::DC::Messaging::Role::Producer';

use XT::DC::Messaging::Spec::DutyRate;

sub message_spec {
    return XT::DC::Messaging::Spec::DutyRate::duty_rate();
}

has '+type' => ( default => 'ShippingDutyRate' );

sub transform {
    my ($self, $header, $data) = @_;

    confess 'Expected hashref of arguments' unless ref $data eq 'HASH';

    my $schema = $data->{schema} or confess 'Expected a schema object';
    my $payload = {
        channel_ids => [ $schema->resultset('Public::Channel')->enabled->get_column('id')->all ],
        duty_rate => $data->{duty_rate},
    };

    if (defined(my $cdr_id = $data->{cdr_id})) {
        my $cdr = $schema->resultset('Public::CountryDutyRate')->find(
            { id => $cdr_id },
            { prefetch => [qw(country hs_code)] },
        ) or confess 'Expected valid cdr_id';

        $payload->{hs_code} = $cdr->hs_code->hs_code;
        $payload->{country_code} = $cdr->country->code;
        $payload->{duty_rate} = $cdr->rate;
    }
    elsif (
        defined(my $hs_code_id = $data->{hs_code_id}) &&
        defined(my $country_id = $data->{country_id})
    ) {
        my $hs_code = $schema->resultset('Public::HSCode')->find({ id => $hs_code_id })
            or confess "Expected valid hs_code_id";
        my $country = $schema->resultset('Public::Country')->find({ id => $country_id })
            or confess "Expected valid country_id";

        $payload->{hs_code} = $hs_code->hs_code;
        $payload->{country_code} = $country->code;
    }
    else {
        confess "Expected at least cdr_id or hs_code_id and country_id";
    }

    return ($header, $payload);
}
