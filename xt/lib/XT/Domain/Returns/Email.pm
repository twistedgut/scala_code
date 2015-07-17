package XT::Domain::Returns::Email;
use Moose::Role;
use Carp;
use DateTime;
use XTracker::EmailFunctions;
use XTracker::XTemplate;
use Lingua::EN::Inflect qw/ORD/;
use XTracker::Constants::FromDB qw(
    :correspondence_templates
    :renumeration_type
    :return_type
    :department
);
use XTracker::Database::Shipment qw(:DEFAULT get_shipment_item_info);
use XTracker::Database::Logging;
use XTracker::Database::Channel qw(get_channel_details);
use XTracker::Config::Local     qw(
                                    config_var
                                    config_section_slurp
                                    returns_email
                                    localreturns_email
                                    rma_cutoff_days_for_email_copy_only
                                    rma_expiry_days
                                    all_channel_email_addresses
                                );
use namespace::autoclean;

requires 'schema';
requires 'dbh';

=head1 NAME

XT::Domain::Returns::Email

=head1 METHODS

=head2 render_email

 $email_body = $handler->domain('Returns')->render_email($data, $CORRESPONDENCE_TEMPLATES__...);

For most cases C<$data> should contain the DBIC Return row under a key of
'return' (i.e. unless you know better.)

One use-case for return emails has to generate the email before the return has
actually been created. In this case we expect a structure of the same form as
passed to C</create>.

=cut

# Mapping from constants to template filename
my $EMAIL_TEMPLATE = {
    $CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE => 'create_return',
    $CORRESPONDENCE_TEMPLATES__CANCEL_RETURN => 'cancel_return',
    $CORRESPONDENCE_TEMPLATES__ADD_RETURN_ITEM => 'add_item',
    $CORRESPONDENCE_TEMPLATES__REMOVE_RETURN_ITEM => 'remove_item',
    $CORRESPONDENCE_TEMPLATES__CONVERT_TO_EXCHANGE => 'convert_to_exchange',
    $CORRESPONDENCE_TEMPLATES__CANCEL_EXCHANGE => 'convert_from_exchange',
};

# For the case of create_return, there are two modes of operation:
#
#   1. Email generated after RMA row created by the AMQ consumer
#   2. Email generated before RMA created as part of mod_perl app
#
# mode 2 is a *right* pain in the ass.

sub render_email {
    my ($self, $data, $email_type) = @_;

    my $tt_name = $EMAIL_TEMPLATE->{$email_type}
        or
    confess "$email_type not a valid RMA email type";


    my ($shipment_id);
    if ($tt_name eq 'create_return' && !$data->{return}) {
        # We only have a hashref of data, no DBIC objects. PAIN PAIN PAIN

        $shipment_id = $data->{shipment_id} || croak "No shipment_id given!";
    }
    else {
        my $return_id = $data->{return_id};
        $data->{return} ||= $self->schema->resultset('Public::Return')->find($return_id) ||
        croak "No return given!";
        $shipment_id = $data->{return}->shipment_id;
    }

    $self->_setup_shipment_info($shipment_id, $data)
        unless $data->{shipment_items};
    my $shipment = $data->{shipment};

    # build customer email template
    my $ret = {
        email_to      => $shipment->order->email,
    };

    my $channel = $shipment->order->channel;
    my $b_name  = $channel->business->config_section;

    # CANDO- 577 : Migrated emails templates to database from filesystem /root/base/email/rma/
    my $template_name = "RMA - ".join(' ', map { ucfirst(lc($_)) } split /_/, $tt_name ). " - ".$b_name;
    my $correspondence_template = $self->schema->resultset('Public::CorrespondenceTemplate')
                                                ->find ( { name => $template_name, department_id => undef } );
    my $template_content = $correspondence_template->content;

    my $stash =  $self->${\"_setup_${tt_name}_email_stash"}($data);
    $stash->{order_number} = $shipment->order->order_nr;

    my $email_info = get_and_parse_correspondence_template( $self->schema, $correspondence_template->id, {
        channel  => $channel,
        data     => $stash,
        base_rec => $data->{return} || $shipment,
        post_chomp => 1,
     } );

    # get correct from email address
    $ret->{email_from} = $data->{shipment}->is_premier
    ? localreturns_email( $b_name )
    : returns_email( $b_name );
    # now get a localised version if one available
    $ret->{email_from}  = localised_email_address(
        $self->schema,
        $shipment->order->customer->locale,
        $ret->{email_from}
    );

    $ret->{email_subject}       = $email_info->{subject};
    $ret->{email_body}          = $email_info->{content};
    $ret->{email_content_type}  = $email_info->{content_type};

    return $ret;


}

sub _setup_convert_to_exchange_email_stash {
    my ($self, $data) = @_;

    my $expiry = $data->{return}->expiry_date;
    my $return_expiry_date = join(" ",
        $expiry->month_name,
        ORD($expiry->day_of_month), # 1st, 2nd, 3rd etc.
        $expiry->year
    );

    my $ex = [];
    my $r_items = $data->{return_items};
    for my $id ( keys %$r_items ) {

        # Quite why this is a key of remove i dont know. Oddness
        next unless $r_items->{$id}{remove};

        my $var = $r_items->{$id}{exchange_variant} ||
        $r_items->{$id}{exchange_variant_id} ||
        $r_items->{$id}{exch_variant} ||
        confess "Exchange return item $id has no exchange_variant";

        my $exchange_size = $self->schema
        ->resultset('Public::Variant')
        ->find($var)
        ->designer_size->size;

        $id = $r_items->{$id}{shipment_item_id} || $id,
        push @$ex, { id => $id, exchange_size => $exchange_size };
    }

    my $ret = {
        %{ $self->_setup_common_email_stash($data) },
        return => $data->{return},
        #shipment_items => $data->{shipment_items},
        return_expiry_date => $return_expiry_date,

        exchange_items => $ex,
    };

    return $ret;
}

sub _build_return_email {

    my ( $self, $data, $email_template ) = @_;

    my $email_data = $self->render_email($data, $email_template);

    @$data{keys %$email_data} = values %$email_data;

    $data->{send_email} = 1;

    return;

}

sub _setup_convert_from_exchange_email_stash {
    my ($self, $data) = @_;

    my $expiry = $data->{return}->expiry_date;
    my $return_expiry_date = join(" ",
        $expiry->month_name,
        ORD($expiry->day_of_month), # 1st, 2nd, 3rd etc.
        $expiry->year
    );

    my $ids = [];
    my $r_items = $data->{return_items};
    for my $id ( keys %$r_items ) {

        next unless $r_items->{$id}{change};

        $id = $r_items->{$id}{shipment_item_id} || $id,
        push @$ids, $id;
    }

    my $ret = {
        %{ $self->_setup_common_email_stash($data) },
        return => $data->{return},
        return_expiry_date => $return_expiry_date,
        refund_items => $ids,
    };

    my $refund_type_id = $data->{refund_type_id} || $data->{refund_id} || 0;
    $ret->{refund_type} = $refund_type_id == $RENUMERATION_TYPE__STORE_CREDIT
    ? 'store_credit'
    : $refund_type_id == $RENUMERATION_TYPE__CARD_REFUND
    ? 'card'
    : 'none';

    return $ret;
}

sub _setup_common_email_stash {
    my ($self, $data) = @_;

    my $shipment = $data->{shipment};
    my $shipment_address = {$shipment->shipment_address->get_inflated_columns};

    my $channel = $shipment->order->channel;

    my $expiry = $data->{return_expiry_date} ||
      (blessed $data->{return} && $data->{return}->expiry_date) ||
      $self->_default_return_expiry_date($channel);

    # 'November 4th 2009'
    my $return_expiry_date = join(" ",
        $expiry->month_name,
        ORD($expiry->day_of_month), # 1st, 2nd, 3rd etc.
        $expiry->year
    );

    my $currency = $shipment->order->currency->currency;
    my $renumerations;

    # has a return
    if (blessed $data->{return}) {
        $renumerations = [ $data->{return}->renumerations->all ];
    }
    else {
        $renumerations = $self->get_renumeration_split( $data );

        for my $r (@$renumerations) {
            $r->{is_card_refund} = $r->{renumeration_type_id} == $RENUMERATION_TYPE__CARD_REFUND;
            $r->{is_store_credit} = $r->{renumeration_type_id} == $RENUMERATION_TYPE__STORE_CREDIT;
            $r->{grand_total} = 0;
            $r->{grand_total} += $_->{value} for @{$r->{renumeration_tenders}};
            $r->{currency} = { currency => $currency };
        }
    }

    # set-up a hash in regards to the Payment used for the
    # order, so that the TT has access to it when there is
    # a Card Refund, to see if it is for a Third Party (PayPal)
    # or if it is actually a Credit Card
    my $payment = $shipment->get_payment_info_for_tt;

    return {
        template_type => 'email',
        order => { currency => $currency },
        customer => $shipment->order->customer,
        branded_salutation => $shipment->order->branded_salutation,
        shipment => $shipment,
        shipment_items => get_shipment_item_info($self->dbh, $shipment->id),
        shipment_address => $shipment_address,
        invoice_address => {$shipment->invoice_address->get_inflated_columns},
        distrib_centre => $channel->distrib_centre->name,
        channel => get_channel_details( $self->dbh, $channel->name ),
        return_expiry_date => $return_expiry_date,
        renumerations => $renumerations,
        payment_info => $payment,
        requested_from_arma => $self->requested_from_arma,
        can_set_debit_to_pending => $self->_can_set_debit_to_pending,
        return_cutoff_days => rma_cutoff_days_for_email_copy_only( $channel ),
        channel_branding => $channel->branding,
        channel_email_address => all_channel_email_addresses(
            $channel->business->config_section,
            {
                schema  => $self->schema,
                locale  => $shipment->order->customer->locale,
            }
        ),
        channel_company_detail => config_section_slurp( 'Company_' . $channel->business->config_section ),
    };
}

# Called automatically by render_email
sub _setup_cancel_return_email_stash {
    my ($self, $data) = @_;

    my $shipment = $data->{shipment};
    my $return   = $data->{return};
    my $ret = {
        %{ $self->_setup_common_email_stash($data) },
        return_items => [$return->return_items->not_cancelled->get_column('shipment_item_id')->all],
    };

    return $ret;
}

# Called automatically by render_email
sub _setup_create_return_email_stash {
    my ($self, $data) = @_;

    my $ret = $self->_setup_common_email_stash($data);

    my ($refunds, $ex) = ([], []);
    my ($refund_type_id);

    if (my $return = $data->{return}) {
        # Populate the refund_items and exchange_items from $return->items

        # This should only really be passed in from tests
        $refund_type_id = $data->{__refund_type_id};
        unless (exists $data->{__refund_type_id}) {
            my $renum = $return->renumerations->first;
            $refund_type_id = !$renum
            ? 0
            : $renum->renumeration_type_id;
        }

        my $refund_info = $self->_setup_calculate_returns_charge_stash( $data );
        $ret->{charge_tax} = $refund_info->{charge_tax} || 0;
        $ret->{charge_duty} = $refund_info->{charge_duty} || 0;
        $ret->{rma_number} = $return->rma_number;
        $ret->{total_charges} = $return->get_total_charges_for_exchange_items;
        $ret->{debit_charges} = $return->get_debit_charges_for_exchange_items;
        $ret->{has_debit_card_renumeration} = $return->has_at_least_one_debit_card_renumeration;
    }
    else {
        $refund_type_id = $data->{refund_type_id} ||
        $data->{refund_id} || 0;
    }

    for (qw/rma_number charge_tax charge_duty shipment/) {
        next if exists $ret->{$_};
        die "data->{$_} missing" unless exists $data->{$_};
        $ret->{$_} = $data->{$_};
    }

    # Populate the refund_items and exchange_items from $data->{return_items}
    my $r_items = $data->{return_items};
    foreach my $id (keys %$r_items) {
        # type is either id from web request or text string via XT
        if ($r_items->{$id}{type} eq 'Exchange'
            || ($r_items->{$id}{type} =~ /^\d+$/ and $r_items->{$id}{type} == $RETURN_TYPE__EXCHANGE)) {

            my $var = $r_items->{$id}{exchange_variant} ||
            $r_items->{$id}{exchange_variant_id} ||
            confess "Exchange return item $id has no exchange_variant";

            my $exchange_size = $self->schema
            ->resultset('Public::Variant')
            ->find($var)
            ->designer_size->size;
            push @$ex, { id => $id, exchange_size => $exchange_size };
        } else {
            push @$refunds, $id;
        }
    }

    $ret->{refund_items} = $refunds;
    $ret->{exchange_items} = $ex;
    $ret->{email_type} = $data->{email_type} || '';
    return $ret;
}

# add_item uses many/all the variables that create uses
sub _setup_add_item_email_stash {
    my ($self, $data) = @_;

    my $ret = $self->_setup_create_return_email_stash($data);

    return $ret;
}

sub _setup_remove_item_email_stash {
    my ($self, $data) = @_;

    my $expiry = $data->{return}->expiry_date;
    my $return_expiry_date = join(" ",
        $expiry->month_name,
        ORD($expiry->day_of_month), # 1st, 2nd, 3rd etc.
        $expiry->year
    );

    my $ret = {
        %{ $self->_setup_common_email_stash($data) },
        return => $data->{return},
        return_expiry_date => $return_expiry_date,

        # One code path uses (mod_perl Return/RemoveItem) uses $ri_id => { si_id => ... }
        # The other (domain, MQ etc) has $si_id => { ... }
        # This map/grep works for both
        return_items => [
        map { $data->{return_items}{$_}{shipment_item_id} || $_ }
        grep { $data->{return_items}{$_}{remove} } keys %{$data->{return_items}}
        ]
    };

    return $ret;
}

sub _send_email {
    my ($self, $data, $email_type) = @_;

    if(send_customer_email({
            from => $data->{'email_from'},
            reply_to =>$data->{'email_replyto'},
            to => $data->{'email_to'},
            subject => $data->{'email_subject'},
            content => $data->{'email_body'},
            content_type => $data->{'email_content_type'},
        }
        )){
        log_shipment_email(
            $self->dbh,
            $data->{shipment}->id,
            $email_type,
            $data->{operator_id}
        );
    }
}

# Get the correct expiry date for a return based on channel/creation date
sub _default_return_expiry_date {
    my ($self, $channel, $return_date) = @_;

    $return_date ||= DateTime->now;

    my $expiry_days_delta = rma_expiry_days( $channel )
            || die $channel->business->config_section."/expiry_days not found in config";

    return $return_date->clone->add( days => $expiry_days_delta );
}

1;
