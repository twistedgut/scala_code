package XT::DC::Controller::Admin::ShippingConfig;
use NAP::policy qw(tt class);

BEGIN { extends 'Catalyst::Controller' }

sub index :Path('/Admin/ShippingConfig') :Args(0) {
    my ($self, $c) = @_;

    $c->check_access('Admin', 'Shipping Config');
    $c->stash(template => 'admin/shippingconfig.tt');
}
