package XT::DC::Messaging::Spec::Types::language;
use strict;
use warnings;
use Carp;
use parent 'Data::Rx::CommonType::EasyNew';

use XTracker::Constants::Regex qw( :language );

sub type_uri {
  sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'language' };

sub assert_valid {
    my ( $self, $value ) = @_;

    if (($value =~ $LANGUAGE_REGEX__ISO_639_1) || ($value =~ $LANGUAGE_REGEX__IETF_LANG_TAG)) {
        return 1;
    }
    else {
        $self->fail({
            error   => [$self->subname],
            message => 'invalid language',
            value   => $value,
        });
    }
}

1;
