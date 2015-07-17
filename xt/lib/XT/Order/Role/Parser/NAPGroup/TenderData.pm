package XT::Order::Role::Parser::NAPGroup::TenderData;
use Moose::Role;
use feature ':5.14';

use XT::Data::Types;
use DateTime::Format::Strptime;
use Data::Dump qw/pp/;

requires 'is_parsable';
requires 'parse';

sub _get_tender_data {
    my ($self,$rh_args) = @_;
    my $count = 0;
    my @tenders;

    foreach my $tender (@{$rh_args->{tender_lines}}) {
        # has to have a type!
        if (! defined $tender->{type}) {
            # FIXME exception
            die "No Tender Line type present";
        }

        my $tender_data = {
            type    => $tender->{type},
            rank    => ++$count,
            value   => $tender->{value}{amount},
        };

        SMARTMATCH: {
            use experimental 'smartmatch';
            given ($tender_data->{type}) {
                when (m{^card$}i) {
                    $tender_data = {
                        %{$tender_data}, # preserve what we already have in the hashref
                        type                    => 'Card Debit',
                        payment_pre_auth_ref    => $tender->{payment_details}{pre_auth_code},
                    };
                }

                when (m{^store\s+credit$}i) {
                    $tender_data = {
                        %{$tender_data}, # preserve what we already have in the hashref
                    };
                }

                when (m{^gift\s+voucher}i) {
                    $tender_data = {
                        %{$tender_data}, # preserve what we already have in the hashref
                        type            => "Voucher Credit",
                        voucher_code    => $tender->{voucher_code},
                    };
                    # FIXME throw exception
                    die "Voucher code missing"
                        unless defined $tender_data->{voucher_code}
                            and length $tender_data->{voucher_code};
                }

                default {
                    die 'Unexpected tender type: ' . $tender_data->{type};
                }
            }
        }
        push @tenders, $tender_data;
    }

    return \@tenders;
}

1;
