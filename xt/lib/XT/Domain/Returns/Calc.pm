package XT::Domain::Returns::Calc;
use Moose::Role;
use Carp;
use XTracker::Constants::FromDB qw(
    :refund_charge_type
    :renumeration_type
    :customer_issue_type
    :renumeration_class
    :renumeration_status
);
use XTracker::Database::Return qw(
    calculate_returns_charge
);

use List::Util qw/sum min/;
use Perl6::Junction 'any';
use Data::Dump 'pp';
use namespace::autoclean;
use Data::Dumper;

requires 'schema';
requires 'dbh';

our $RENUMERATION_TYPE__FULL_CASH_REFUND = 99;

=head2 get_renumeration_split

 $hash = $handler->domain('Returns')->create($data);

Return a data structure detailing how we should split the renumerations for a
return of the given shape. C<$data> is a hash that should match the following
type:

  Dict[
    shipment_id => Int,

    # One of these two fields must be present.
    full_refund => Optional[Bool],
    refund_type_id => Optional[Int], # $RENUMERATION_TYPE__xxx

    shipping_charge => Num,  # if a refund_type_id
    shipping_refund => Bool, # if a refund_type_id

    return_items => Dict[
      # Keys are the shipment_item ids
      slurpy Dict[
        type => Enum['Exchange', 'Return'],
        reason_id => Int,

        # required if type eq 'Exchange'. Is a variant.id
        exchange_variant => Int,
      ]
    ],
  ]

  [
    { renumeration_type => XTracker::Scheam::Result::Public::RenumerationType->new(
          id => $RENUMERATION_TYPE__CARD_REFUND, ... ),
      tenders => [
        {
          tender_id => 123,
          value => 1
        }
      ],
      items => {
        shipment_item_id => 123456,
        unit_price => 1,
        tax => 0,
        duty => 0,
      }
    },
    { renumeration_type => XTracker::Scheam::Result::Public::RenumerationType->new(
          id => $RENUMERATION_TYPE__STORE_CREDIT, ... ),
      tenders => [
        tenders => [
          {
            tender_id => 124,
            value => 3,
          },
          {
            tender_id => 125, # This gives us the link to the voucher code to send to PWS
            value => 40,
          }
        ],
      items => [
        {
          shipment_item_id => 123456,
          unit_price => 33,
          tax => 5,
          duty => 5,
        }
      ]
    }
  ]

=cut

sub get_renumeration_split {
    my ($self, $req) = @_;

    my $refund_type = $req->{refund_type_id};

    if ( $req->{is_lost_shipment} ) {
        $self->{is_lost_shipment}   = 1;
    }

    if ( $req->{dispatch_return} ) {
        $self->{dispatch_return}    = 1;
    }

    if (defined $refund_type) {
        return [] if $refund_type == 0; # 0 == No refund
    }
    else {
        # The 'default' renumeration type is to ask for card refund if we can
        $refund_type = $RENUMERATION_TYPE__CARD_REFUND;
    }

    $self->order( $self->schema->resultset('Public::Shipment')
        ->find($req->{shipment_id})->order
    );

    my $renum_split = $self->_build_renum_list($req, $refund_type);
    my @items = (
        map { $self->_lookup_item($_, $req->{return_items}{$_}) } keys %{ $req->{return_items} }
    );

    my $data = {
        n => 0,
        renums => $renum_split,
        debit => undef,
    };

    # Sort the items so that returns are processed before exchanges.
    my $sorter = sub { $a->{shipment_item_id} <=> $b->{shipment_item_id} };
    my @returns = sort $sorter  grep { ( $_->{_type} // '' ) eq 'Return' }  @items;
    my @exchanges = sort $sorter grep { ( $_->{_type} // '' ) ne 'Return' }  @items;

    # Generally: BLAAAAAAAAAARHG

    # Shipping refund and charge is funny. Since the logic for _return_item
    # expects to only go 'forward'. Therefore we add in a fake 'return' item of
    # the right type so that the shipping refund can be processed inline, and
    # then corrected to the renumeration at the end.
    my ($shp_refund, $shp_charge)  = $self->_shipping_refund_charge($req);
    $shp_charge ||= 0;

    my $shp_bal = $shp_refund + $shp_charge;

    my $i = {
            shipment_item_id => 'shipping',
            duty => 0,
            unit_price => 0,
            _shipping_charge => $shp_charge,
            _shipping_refund => $shp_refund
    };

    if ($shp_bal < 0) {
        # negative refund = charge
        $i->{tax} = $shp_bal;
        $i->{_type} = 'Exchange';
        push @exchanges, $i;
    }
    elsif ($shp_refund > 0) {
        $i->{tax} = $shp_bal;
        $i->{_type} = 'Return';
        push @returns, $i;
    }


    # loop through list of items to refunded
    for my $item ( @returns, @exchanges ) {

        if ( ( $item->{_type} // '' ) eq 'Return') {
            $self->_return_item($item, $data);
        }
        elsif ( ( $item->{_type} // '' ) eq 'Exchange') {
            $self->_exchange_item($item, $data);
        }
        else {
            die "Bad return type ". $item->{_type} // '' ." expecting 'Return' or 'Exchange' request: "
            . pp $req;
        }
    }

    unshift @$renum_split, $data->{debit} if $data->{debit};

    # Strip out any 0 renumerations and items
    $renum_split = [ grep {
        my $r = $_;
        $r->{renumeration_tenders} = [ grep {
            delete @{$_}{qw/_remaining _original_value/};
            $_->{value};
        } @{ $r->{renumeration_tenders} } ];

        my $val = 0;

        $r->{renumeration_items} = [ grep {
            if ($_->{shipment_item_id} eq 'shipping') {
                $_->{tax} = 0;
                $r->{shipping} = delete $_->{_shipping_refund};
                $r->{misc_refund} = delete $_->{_shipping_charge};
                # Delete if misc_refund is undef or 0
                delete $r->{misc_refund} unless $r->{misc_refund};
            }
            my $x = ($_->{tax} ||= 0) + ($_->{duty} ||= 0) + ($_->{unit_price} ||= 0);

            $val += $x;
            $x;
        } @{ $r->{renumeration_items} } ];

        delete $r->{_n_tender};

        scalar @{ $r->{renumeration_tenders} } || $val;
    } @$renum_split ];

    return $renum_split;
}


# returns count of exchange, returned and faulty items
sub _get_request_stat {
    my ($self, $req) = @_;

    my ($r, $e, $f) = (0,0,0);

    for my $si (keys %{$req->{return_items}}) {
        ( $req->{return_items}{$si}{type} // '' ) eq 'Return' ? $r++ : $e++;
        $f++ if ( $req->{return_items}{$si}{reason_id} // '') == $CUSTOMER_ISSUE_TYPE__7__DEFECTIVE_FSLASH_FAULTY;
    }

    return ($r, $e, $f);
}

=head2

Calculate shipping refund / charges from request.

Returns $shipping_refund. If this is positive it is a refund, if its negative its a charge.

=cut

sub _shipping_refund_charge {
    my ($self, $req) = @_;

    my ($return, $exchange, $faulty) = $self->_get_request_stat($req);

    my ($sid) = keys %{$req->{return_items}};
    my $shipment = $self->schema
                        ->resultset('Public::ShipmentItem')
                        ->search({ id=>$sid })->first->shipment;

    confess "Couldn't find shipment for request, order nr: "
        . $self->order->order_nr unless $shipment;

    my $full_refund
        = scalar ( grep { $_->{full_refund} } values %{$req->{return_items}} );

    # refund shipping if one of the items have set full_refund
    if ($req->{shipping_refund} || $full_refund) {
        return ( $shipment->shipping_charge - $shipment->renumerations->previous_shipping_refund );
    }

    if ( delete $req->{dispatch_return} ) {
        # no shipping charge unless 'Full Refund' asked for when doing Dispatch Returns
        return 0;
    }

    if ( $req->{is_lost_shipment} ) {
        # no shipping refund or shipping charge if a lost shipment
        return 0;
    }

    return calculate_returns_charge({
        shipment_row       => $shipment,
        num_return_items   => $return + $exchange, # number of returns includes Exchanges as they are being returned
        num_exchange_items => $exchange,
        got_faulty_items   => $faulty,
    });
}

# lookup shipment item fetch unit price etc
sub _lookup_item {
    my ($self, $shipment_item_id, $ritem) = @_;

    my $item = {%$ritem}; # clone so we don't alter the request

    my $si = $self->schema->resultset('Public::ShipmentItem')
                  ->find($shipment_item_id)
                    or die "Couldn't find shipment item id";

    $item->{shipment_item_id} = $shipment_item_id;

    # not refunding anything
    $item->{unit_price} = $si->unit_price+0 if $item->{type} ne 'Exchange';
    $item->{unit_price} = 0 unless exists $item->{unit_price};
    $item->{_reason_id} = delete  $item->{reason_id};
    $item->{_type} = delete $item->{type};
    if ( $self->{dispatch_return} ) {
        $item->{_tax} = $ritem->{tax};
        $item->{_duty} = $ritem->{duty};
    }
    else {
        $item->{_tax} = $si->tax+0;
        $item->{_duty} = $si->duty+0;

        if ( ( $item->{_type} // '' ) ne 'Exchange' ) {
            # REL-853:
            # work out what existing refunds have happened
            # and then take off the values so that
            # people aren't refunded too much
            my ( $price, $tax, $duty )  = $si->refund_invoice_total;
            $item->{unit_price} -= $price;
            $item->{_tax}       -= $tax;
            $item->{_duty}      -= $duty;
        }
    }
    $item->{tax} = 0;
    $item->{duty} = 0;

    return $item;
}

sub _make_charge {
    my ($self, $renums, $to_refund, $item) = @_;
    my $t = 0;

    my $n = $renums->{n};
    my $renum = $renums->{renums}[$n];
    my $t_n = $renum->{_n_tender} ||= 0;
    my $tender = $renum->{renumeration_tenders}[$t_n];

    # Refund duty, then tax, then unit price. Since we are in 'refund' mode a
    # charge = a negative refund
    my ($duty, $tax, $unit_price) = (-$item->{duty}, -$item->{tax}, -$item->{unit_price});

    my $clamp = sub {
        # Helper fn for slpit
        my ($v, $amount) = @_; my $ret;
        if ($$v <= $$amount) {
            $ret = -$$v;
            $$amount -= $$v;
            $$v = 0;
        }
        else {
            $ret = -$$amount;
            $$v -= $$amount;
            $$amount = 0;
        }
        $to_refund -= $ret;
        return $ret;
    };

    my $split = sub {
        my ($tender) = @_;
        my ($d, $t, $u) = (0,0,0);

        my $amount = $tender->{value};

        $d = $clamp->( \$duty, \$amount ) if ($duty && $amount);
        $t = $clamp->( \$tax, \$amount ) if ($tax && $amount);
        $u = $clamp->( \$unit_price, \$amount )  if ($unit_price && $amount);

        $tender->{value} = $amount;
        $tender->{_remaining} -= $d+$t+$u;
        return ( duty => $d, tax => $t, unit_price => $u );
    };

    while ( $to_refund < 0 ) {
        if ( $to_refund > -0.0001 ) {
            # bloody floating point maths!
            # throw it away!
            last;
        }
        if (!$tender->{value}) {
            # Create a debit (if there isn't one, else add to it)
            $renum = $renums->{debit} ||= {
                renumeration_type_id => $RENUMERATION_TYPE__CARD_DEBIT,
                renumeration_class_id => $RENUMERATION_CLASS__RETURN,
                renumeration_status_id => (
                                            $self->_can_set_debit_to_pending
                                            ? $RENUMERATION_STATUS__PENDING                     # CANDO-141: if called from the web-site then set
                                            : $RENUMERATION_STATUS__AWAITING_AUTHORISATION      #            automatically to 'PENDING'
                                        ),
                renumeration_items => [],
                renumeration_tenders => [],
                shipment_id => $renum->{shipment_id},
            };

            push @{$renum->{renumeration_items}}, {
                unit_price => $unit_price,
                tax => $tax,
                duty => $duty,
                shipment_item_id => $item->{shipment_item_id},
            };
            $to_refund = 0;
            last;
        }
        my %split = $split->( $tender );

        if ($item->{shipment_item_id} eq 'shipping'){
            $split{_shipping_charge} = $item->{_shipping_charge};
            $split{_shipping_refund} = $item->{_shipping_refund};
        }

        # Sometimes there are two tenders in the same renumeration (i.e.
        # tenders for store credit and vouchers) So we need just the one
        # renumeration item created
        my $last = $renum->{renumeration_items}[-1];
        if ($last && $last->{shipment_item_id} eq $item->{shipment_item_id}) {
            $last->{$_} += $split{$_} for keys %split;
        }
        else {
            push @{$renum->{renumeration_items}}, {
                shipment_item_id => $item->{shipment_item_id},
                %split
            };
        }

        if( $tender->{value} == 0 ) {
            # Nothing left on this tender to subtract charge from - Move to the next one.
            $t_n = --$renum->{_n_tender};
            if ($t_n < 0) {
                # No more tenders left, move to prev renum type
                $n = --$renums->{n};
                last if $n < 0;

                $renum = $renums->{renums}[$n];
                $t_n = $#{$renum->{renumeration_tenders}};
                $renum->{_n_tender} = $t_n;
                $tender = $renum->{renumeration_tenders}[$t_n];
            }
            else {
                $tender = $renum->{renumeration_tenders}[$t_n];
            }
        }
    }
}

sub _make_refund {
    my ($self, $renums, $to_refund, $item) = @_;
    my $t = 0;

    my $n = $renums->{n};
    my $renum = $renums->{renums}[$n];
    my $t_n = $renum->{_n_tender} ||= 0;
    my $tender = $renum->{renumeration_tenders}[$t_n];

    # Refund duty, then tax, then unit price.
    my ($duty, $tax, $unit_price) = ($item->{duty}, $item->{tax}, $item->{unit_price});

    my $clamp = sub {
        # Helper fn for slpit
        my ($v, $amount) = @_; my $ret;
        if ($$v <= $$amount) {
            $ret = $$v;
            $$amount -= $$v;
            $$v = 0;
        }
        else {
            $ret = $$amount;
            $$v -= $$amount;
            $$amount = 0;
        }
        $to_refund -= $ret;
        return $ret;
    };

    my $split = sub {
        my ($tender) = @_;
        my ($d, $t, $u) = (0,0,0);

        my $amount = $tender->{_remaining};

        $d = $clamp->( \$duty, \$amount ) if ($duty && $amount);
        $t = $clamp->( \$tax, \$amount ) if ($tax && $amount);
        $u = $clamp->( \$unit_price, \$amount )  if ($unit_price && $amount);

        $tender->{value} += $d+$u+$t;
        $tender->{_remaining} = $amount;


        return ( duty => $d, tax => $t, unit_price => $u );
    };


    while ( $to_refund > 0.0001 ) {
        my %split = $split->( $tender );

        if ($item->{shipment_item_id} eq 'shipping'){
            # NOTE: for Shipping Refunds a FAKE Return Item is created
            #       with the amount to refund in '_shipping_refund' and
            #       the amount of return charges (OUTNET) in '_shipping_charge'.
            #       The difference between the shipping refund amount and the
            #       charges is stored in 'tax' and this is the actual amount
            #       that will get refunded and is what the '$split->()'
            #       function has dealt with for this FAKE item.

            # set what will appear in the 'misc_refund' column for this renumeration rec.
            $split{_shipping_charge}    = $item->{_shipping_charge};

            # set what appears in the 'shipping' column for this renumeration rec. by
            # adding the amount of Shipping refunded for this renumeration rec. to any
            # Return Charges for the Return (it'll be negative so use its absolute value)
            $split{_shipping_refund}    = abs( $item->{_shipping_charge} ) + $split{tax};

            # reduce the amount of Shipping to be refunded for the next
            # tender that will be used if this one didn't cover everything
            $item->{_shipping_refund}  -= $split{tax};

            # absorb all Shipping Charges in the first renumeration created
            # therefore set them to zero for the next tender should one be used
            $item->{_shipping_charge}   = 0;
        }

        # Sometimes there are two tenders in the same renumeration (i.e.
        # tenders for store credit and vouchers) So we need just the one
        # renumeration item created
        my $last = $renum->{renumeration_items}[-1];
        if ($last && $last->{shipment_item_id} eq $item->{shipment_item_id}) {
            $last->{$_} += $split{$_} for keys %split;
        }
        else {
            push @{$renum->{renumeration_items}}, {
                shipment_item_id => $item->{shipment_item_id},
                %split
            };
        }

        if( $tender->{_remaining} == 0 ) {

            # Nothing left on this tender to refund to - Move to the next one.
            $t_n = ++$renum->{_n_tender};
            if ( !($tender = $renum->{renumeration_tenders}[$t_n]) ) {
                # No more tenders left, move to next renum type
                $n = ++$renums->{n};
                last if $to_refund <= 0.0001;

                if ( !($renum = $renums->{renums}[$n]) ) {
                    confess "Ran out of tenders and renumerations!"
                    . "\nitem\n" . Dumper ($item)
                    . "\nto refund: $to_refund"
                    . "\nrenumerations\n" . Dumper ($renums);
                }
                $t_n = 0;
                $tender = $renum->{renumeration_tenders}[$t_n];
            }
        }
    }

}


# calculate the renumeration for an item
# accross multiple tenders
sub _return_item {
    my ($self, $item, $renums) = @_;

    my $to_refund = $self->_localized_refund($item);

    $self->_make_refund($renums, $to_refund, $item);
}

# calculate refund
sub _localized_refund {
    my ($self, $item) = @_;

    if ($item->{shipment_item_id} eq 'shipping') {
        return $item->{tax};
    }

    if ( ($item->{_reason_id}
            == any( $CUSTOMER_ISSUE_TYPE__7__INCORRECT_ITEM,
                $CUSTOMER_ISSUE_TYPE__7__DEFECTIVE_FSLASH_FAULTY))
                or
            ($item->{full_refund})
                or
            ($self->{is_lost_shipment})
                or
            ($self->{dispatch_return})
    ) {
        # Refund tax and duty
        $item->{tax} = $item->{_tax};
        $item->{duty} = $item->{_duty};
    }
    else {
        # work out which of Tax & Duty can be refunded based on the Shipping Country
        my $shipment    = $self->schema->resultset('Public::ShipmentItem')->find( $item->{shipment_item_id} )->shipment;
        my $ship_country= $shipment->shipment_address->country_table;

        if ( $ship_country->can_refund_for_return( $REFUND_CHARGE_TYPE__TAX ) ) {
            $item->{tax}    = $item->{_tax};
        }
        if ( $ship_country->can_refund_for_return( $REFUND_CHARGE_TYPE__DUTY ) ) {
            $item->{duty}   = $item->{_duty};
        }
    }

    return $item->{unit_price} + $item->{tax} + $item->{duty};
}

sub _exchange_item {
    my ($self, $item, $renums) = @_;

    my $to_refund = $self->_localized_exchange($item);

    # if no charges for item just push on
    # to first tender type
    return if ($item->{tax} + $item->{duty} == 0);

    $self->_make_charge($renums, $to_refund, $item);
}


sub _localized_exchange {
    my ($self, $item) = @_;

    if ($item->{shipment_item_id} eq 'shipping') {
        # Its not a realy item, but a shipping charge
        return $item->{tax};
    }

    if ($item->{_reason_id}  == $CUSTOMER_ISSUE_TYPE__7__INCORRECT_ITEM ||
            $item->{_reason_id} == $CUSTOMER_ISSUE_TYPE__7__DEFECTIVE_FSLASH_FAULTY
    ) {
        return 0;
    }

    my $shipment    = $self->schema->resultset('Public::ShipmentItem')->find( $item->{shipment_item_id} )->shipment;
    my $ship_country= $shipment->shipment_address->country_table;

    # Charge tax and duty again
    $item->{tax} = -$item->{_tax};
    $item->{duty} = -$item->{_duty};

    # check to see if Tax &/or Duty shouldn't be charged based on the Shipping Country
    if ( $ship_country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__TAX ) ) {
        $item->{tax}    = 0;
    }
    if ( $ship_country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__DUTY ) ) {
        $item->{duty}   = 0;
    }

    return $item->{tax} + $item->{duty};
}

# build list of renumerations
# ordered by rank and grouped by type
sub _build_renum_list {
    my ($self, $req, $type_override) = @_;

    # What type should we set card *debit* renums too. Default is card refund,
    # but operator can overload to say store credit refund only.
    $type_override ||= $RENUMERATION_TYPE__CARD_REFUND;

    my @type_objs = $self->order->tenders->search({},{
            select => [{distinct => 'type_id'}, 'rank'],
                as => [qw/type_id rank/],
                order_by => { -asc => 'rank' },
            });
    my @ranked_types = uniq(map {$_->type_id} @type_objs);

    # reverse order so the lowest valued rank for each type gets set
    my %types_to_rank = map { $_->type_id, $_->rank } reverse @type_objs;

    my $renum_list;
    for my $id (@ranked_types) {
        push @$renum_list, {
            renumeration_type_id => $id,
            renumeration_status_id => $RENUMERATION_STATUS__PENDING,
            renumeration_class_id => $RENUMERATION_CLASS__RETURN,
            renumeration_tenders => [],
        };
    }

    my $store_credit_renum;

    for my $renum (@$renum_list) {
        # add tenders of that type
        my $tenders = $self->order->tenders->search({
                type_id => $renum->{renumeration_type_id}
            },
            {order_by =>{ -asc => 'rank'} }
        );

        while (my $tender = $tenders->next) {
            push @{$renum->{renumeration_tenders}}, {
                tender_id => $tender->id,
                value => 0,
                _original_value => $tender->value,
                _remaining => $tender->remaining_value || 0,
            } if $tender->remaining_value;
        }

        # If the operator asked for full cash refund then make everything go to a card refund.
        if ($type_override == $RENUMERATION_TYPE__FULL_CASH_REFUND) {
                _set_to_min ($types_to_rank{$RENUMERATION_TYPE__CARD_REFUND},
                        $types_to_rank{$renum->{renumeration_type_id}});

            $renum->{renumeration_type_id} = $RENUMERATION_TYPE__CARD_REFUND;
        }
        # tender card_debit gets switched to a card_refund
        elsif ($renum->{renumeration_type_id} == $RENUMERATION_TYPE__CARD_DEBIT) {
                _set_to_min ($types_to_rank{$type_override},
                    $types_to_rank{$renum->{renumeration_type_id}});

            $renum->{renumeration_type_id} = $type_override;
        }
        # Vouchers get refunded as store credit, so we need to merge the voucher tenders in the renum for store credit
        elsif ($renum->{renumeration_type_id} == $RENUMERATION_TYPE__VOUCHER_CREDIT) {
            if ($store_credit_renum) {
                push @{$store_credit_renum->{renumeration_tenders}},
                     @{$renum->{renumeration_tenders}};

                $renum->{renumeration_tenders} = [];
            }
            else {
                _set_to_min($types_to_rank{$RENUMERATION_TYPE__STORE_CREDIT},
                    $types_to_rank{$RENUMERATION_TYPE__VOUCHER_CREDIT});

                $renum->{renumeration_type_id} = $RENUMERATION_TYPE__STORE_CREDIT;
                $store_credit_renum = $renum;
            }
        }
        elsif ($renum->{renumeration_type_id} == $RENUMERATION_TYPE__STORE_CREDIT) {
            $store_credit_renum = $renum;
        }

        $renum->{shipment_id} = $req->{shipment_id};

        # order tenders by remaining value
        @{$renum->{renumeration_tenders}}
            = sort { $a->{_remaining}  <=> $b->{_remaining} }
                @{$renum->{renumeration_tenders}};
    }

    return [] unless $renum_list;

    $renum_list = [ grep { @{$_->{renumeration_tenders}} } @$renum_list ];


    # group by type;
    my %renum_by_type;
    foreach my $renum (@$renum_list) {
        if ($renum_by_type{$renum->{renumeration_type_id}}) {
            push @{$renum_by_type{$renum->{renumeration_type_id}}->{renumeration_tenders}},
                @{$renum->{renumeration_tenders}};
        }
        else {
            $renum_by_type{$renum->{renumeration_type_id}} = $renum;
        }
    }

    return [
        @renum_by_type{
            sort { $types_to_rank{$b} <=> $types_to_rank{$a} }
            keys %renum_by_type
        }
    ];
}

sub _set_to_min {
    $_[0]=min grep {defined} @_;
}

sub _setup_shipment_info {
    my ($self, $shipment_id, $data) = @_;

    my ($shipment) = $self->schema->resultset('Public::Shipment')
                          ->find($shipment_id);

    croak "cannot find shipment - $shipment_id" unless $shipment;

    $data->{shipment} = $shipment;
    $data->{shipment_id} = $shipment->id;
    $data->{shipment_info} = {$shipment->get_columns};
    $data->{shipment_items} = { map { $_->id => $_ } $shipment->shipment_items->all };

    my $shipment_address = {$shipment->shipment_address->get_inflated_columns};
}


# Eliminates redundant values from sorted list of values input.
sub uniq {
    my $prev = undef;
    my @out;
    foreach my $val (@_){
        next if $prev && ($prev eq $val);
        $prev = $val;
        push(@out, $val);
    }
    return @out;
}

1;
