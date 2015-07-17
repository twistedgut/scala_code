package XT::Order::Role::Parser::TenderData;

use Moose::Role;
use XT::Data::Types;
use DateTime::Format::Strptime;
use Data::Dump qw/pp/;

requires 'is_parsable';
requires 'parse';

sub _get_tender_data {
    my($self,$rh_args) = @_;

    my $node                    = $rh_args->{tender_lines};
    my $payment_pre_auth_ref    = $rh_args->{preauth};

    my @tenders;
    my $count;
    foreach my $tender (@{$node}) {
        my $tender_data = {};
        # get tender type (card or credit)
        $tender_data->{type}    = $tender->{type};
        $tender_data->{rank}    = ++$count;

        # has to have a type!
        if (!$tender_data->{type}) {
            # FIXME exception
            die "No Tender Line type present";
        }

        # get tender value
        $tender_data->{value}   = $tender->{value}{amount};

        if (defined $tender_data->{type}) {
            if ($tender_data->{type} =~ /^card$/i) {
                $tender_data->{type} = 'Card Debit';
                $tender_data->{payment_pre_auth_ref} = $payment_pre_auth_ref;
                $tender_data->{number} =
                    $tender->{card_details}{number};
                $tender_data->{cv2_response} =
                    $tender->{card_details}{fraud_score};
            }
        }

# FIXME: need to decide what to do with this for integration service
#        if ($tender_data->{type} eq "Gift Voucher") {
#            $tender_data->{type}    = "Voucher Credit";
#            $tender_data->{voucher_code} = $tender->findvalue('@VOUCHER_CODE');
#            # FIXME throw exception
#            die "Voucher code missing"
#                unless defined $tender_data->{voucher_code}
#                    and length $tender_data->{voucher_code};
#        }
#        elsif ($tender_data->{type} eq "Card") {
#            $tender_data->{type} = 'Card Debit';
#            $tender_data->{payment_pre_auth_ref} =
#                $tender->findvalue('PAYMENT_DETAILS/PRE_AUTH_CODE');
#
## FIXME: card_type  number expire_date threed_secure fraud_score
## FIXME: transaction_reference
#            $tender_data = $tender->{auth_code};
#        }

        push @tenders, $tender_data;
    }
    return \@tenders;
}

1;
