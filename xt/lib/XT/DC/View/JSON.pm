package XT::DC::View::JSON;

use NAP::policy 'tt';
use base 'Catalyst::View::JSON';

__PACKAGE__->config(
    expose_stash => 'json_data',
);
