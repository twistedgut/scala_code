
package XTracker::Database::Recode;
use NAP::policy "tt";
use MooseX::Params::Validate qw/validated_hash/;
use Moose::Util::TypeConstraints; # duck_type

use XTracker::Constants qw/ $APPLICATION_OPERATOR_ID /;
use XTracker::Constants::FromDB qw( :stock_action :pws_action :flow_status );
use XTracker::Database::Logging qw( log_stock );
use XTracker::Database::Stock;

=head1 NAME

XTracker::Database::Recode - Functions relating to recodes

=head1 DESCRIPTION

Functions relating to recodes

=head1 FUNCTIONS

=head2 putaway_stock_recode

Given a DBIC stock_recode object, fills out sensible fields from
C<putaway_via_variant_and_quantity> for it. This shouldn't be used for IWS,
because we blindly accept what IWS tells us it's put away, but for the PRL it's
perfect, as we only have the stock_recode record on our side to go by.
Arguments:

* schema => DBIC schema

* stock_recode => DBIC Stock Recode object

* location => DBIC Location object for recode

=cut

sub putaway_stock_recode {

    my ( %params ) = validated_hash(
        \@_,
        schema       => { does => duck_type('has resultset', [qw/resultset/] )},
        stock_recode => { isa => 'XTracker::Schema::Result::Public::StockRecode' },
        location     => { isa => 'XTracker::Schema::Result::Public::Location' },
    );

    my $variant = $params{'stock_recode'}->variant;
    my $channel = $variant->current_channel;

    putaway_recode_via_variant_and_quantity({
        schema   => $params{'schema'},
        channel  => $channel,
        variant  => $variant,
        location => $params{'location'},
        notes    => $params{'stock_recode'}->notes,
        quantity => $params{'stock_recode'}->quantity,
    });
}

=head2 putaway_recode_via_variant_and_quantity

Specialise C<XTracker::Database::Stock::putaway_via_variant_and_quantity>
to be recode based. Refer to its POD for argument description.

=cut

sub putaway_recode_via_variant_and_quantity {
    my $args = shift;

    $args->{stock_action}     = $STOCK_ACTION__RECODE_CREATE;
    $args->{pws_stock_action} = $PWS_ACTION__RECODE_CREATE;

    return XTracker::Database::Stock::putaway_via_variant_and_quantity($args);
}

1;

