package XT::DC::Messaging;
use NAP::policy "tt", 'class';
use version; our $VERSION = '1.00';

BEGIN { extends 'NAP::Messaging::Catalyst' }

__PACKAGE__->setup();

1;
