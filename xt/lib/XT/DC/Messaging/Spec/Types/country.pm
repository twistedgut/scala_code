package XT::DC::Messaging::Spec::Types::country;
use NAP::policy "tt";
use parent 'Data::Rx::CommonType::EasyNew';

use XTracker::Constants::Regex qw(:country);

sub type_uri {
  sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'country' };

sub assert_valid {
    my ( $self, $value ) = @_;

    if ($value =~ $COUNTRY_REGEX__ISO_3166_1_ALPHA2) {
        return 1;
    }
    else {
        $self->fail({
            error   => [$self->subname],
            message => 'invalid country',
            value   => $value,
        });
    }
}
