package XT::DC::Controller::GoodsIn::ReturnsArrival;

use NAP::policy 'class';

BEGIN { extends 'Catalyst::Controller' }

=head1 NAME

XT::DC::Controller::GoodsIn::ReturnsArrival

=head1 DESCRIPTION

Main page for GoodsIn > ReturnsArrival
It gives options to create a new delivery and
view existing open deliveries

=cut

__PACKAGE__->config(
    path => '/GoodsIn/ReturnsArrival',
);

sub index : Path :Args(0) {
    my ($self, $c, $param) = @_;

    $c->res->redirect(
        $c->uri_for_action($self->action_for('delivery'))
    );
}

sub delivery : Path('Delivery') ActionClass('REST') Args(0) {
    my ($self, $c, $param) = @_;

    $c->stash( param => $param );
}

=head2 index_POST

POST REST action for GoodsIn/ReturnsArrival

Creates a new delivery and redirects to delivery page

=cut

sub delivery_POST {
    my ( $self, $c ) = @_;

    my $schema = $c->model('DB')->schema;

    my $return_delivery_page = '/GoodsIn/ReturnsArrival/Delivery/';

    unless ( $c->req->parameters->{'create_delivery'} ) {
        $c->feedback_warn(q{Attempt to create new return delivery with incomplete params});
        $c->response->redirect( $c->uri_for( $return_delivery_page ) );
    }

    my $return_delivery;

    # If creating a new delivery, create it and then redirect to another page with new id
    try {
        $return_delivery = $schema->resultset('Public::ReturnDelivery')->create(
            {  created_by => $schema->operator_id });
    } catch {
        $c->feedback_warn(qq{Unable to create new return delivery: $_});
        $c->detach;
    };

    $return_delivery_page .= $return_delivery->id;
    my $delivery_params = {};
    $delivery_params->{ view } = 'HandHeld' if ($c->req->parameters->{'is_handheld'});

    $c->feedback_success(q{New return delivery created});
    $c->response->redirect( $c->uri_for( $return_delivery_page, $delivery_params ) );
}

=head2 index_GET

GET REST action for GoodsIn/ReturnsArrival

Populates the main/handheld page for GoodsIn > ReturnsArrival
with all open deliveries.

/GoodsIn/ReturnsArrival/
/GoodsIn/ReturnsArrival/HandHeld

=cut

sub delivery_GET {
    my ( $self, $c ) = @_;

    my $view   = $c->req->parameters->{'view'};
    my $schema = $c->model('DB')->schema;

    # for HandHeld use different template
    if ($view && $view eq 'HandHeld') {
        $c->stash( template_type => 'handheld' );
    } else {
        $c->stash(
            sidenav => [
                { None => [{ 'title' => 'Search Arrivals',
                             'url'   => "/GoodsIn/ReturnsArrival/Search"}] }
            ],
        );
    }

    $c->stash(
        return_deliveries => [ $schema->resultset('Public::ReturnDelivery')
            ->filter_unconfirmed ]
    );
}
