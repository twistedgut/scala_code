package XTracker::DFV;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Data::Dump qw(pp);
use Perl6::Export::Attrs;

use XTracker::Constants::FromDB qw( :promotion_coupon_target );
use XTracker::Logfile qw(xt_logger);

sub dfv_is_ymd :Export( :promotions ) {
    return sub {
        my $dfv = shift;
        $dfv->name_this('invalid_ymd');
        my $val = $dfv->get_current_constraint_value();
        return ($val =~ m{\A\d{4}-\d{2}-\d{2}\z})
    }
}

sub dfv_divisible_by_5 :Export( :promotions ) {
    return sub {
        my $dfv = shift;
        $dfv->name_this('not_divisible_by_5');
        my $val = $dfv->get_current_constraint_value();
        # if we get 0 then it _is_ divisible by 5
        return not($val % 5);
    }
}

sub dfv_5_to_90 :Export( :promotions ) {
    return sub {
        my $dfv = shift;
        $dfv->name_this('not_5_to_90');
        my $val = $dfv->get_current_constraint_value();
        # if we get 0 then it _is_ divisible by 5
        return ($val>=5 && $val<=90);
    }
}

sub dfv_not_more_than :Export( :promotions ) {
    my ($max_value) = @_;
    return sub {
        my $dfv = shift;
        $dfv->name_this('value_too_large');
        return ($dfv->get_current_constraint_value() <= $max_value);
    }
}

sub dfv_offer_data_valid :Export( :promotions ) {
    return sub {
        my $dfv = shift;
        # the value for offer type
        my $val = $dfv->get_current_constraint_value();
        my $data = $dfv->get_filtered_data();
        #xt_logger->debug( pp($data) );

        # we deal with 'percentage_discount' in the profile

        # we need at least one of the lump sum values
        if ('lump_sum_discount' eq $val) {
            $dfv->name_this('invalid_lump_sum_discount');

            my $count = grep {
                m{
                    \A
                    discount_
                    (?:
                        pounds
                        |
                        euros
                        |
                        dollars
                    )
                    \z
                }xms
            } keys %{$data};

            return $count;
        }
        elsif ('free_shipping' eq $val) {
            return 1;
        }
        else {
            $dfv->name_this('invalid_discount_type');
        }
    }
}

sub dfv_valid_coupon_prefix :Export( :promotions ) {
    return sub {
        my $dfv = shift;
        my $val = $dfv->get_current_constraint_value();

        # get other data to refer to
        my $data = $dfv->get_filtered_data;

        #warn pp($data);

        # GENERIC (prefix / suffix are merged)
        if ($PROMOTION_COUPON_TARGET__GENERIC == $data->{coupon_target_type}) {
            # check the length
            if (length($val) > 16) {
                $dfv->name_this('coupon_code_too_long');
                return 0;
            }

            # because we need at least one character for each of the prefix
            # and suffix, we need at least two characters in the generic case
            if (length($val) < 2) {
                $dfv->name_this('coupon_code_too_short');
                return 0;
            }
        }
        elsif ($val =~ /^GC/i){
                $dfv->name_this('coupons cannot be prefixed with "GC", reserved for vouchers');
        }
        # the 'normal' case, where the suffix gets randomly generated
        else {
            # check the length
            if (length($val) > 8) {
                $dfv->name_this('coupon_prefix_too_long');
                return 0;
            }
        }

        # make sure we're not using any naughty characters
        $dfv->name_this('invalid_coupon_prefix');
        return ($val =~ m{\A[A-Za-z0-9]+\z})
    }
}

1;

__END__

=pod

=head1 NAME

XTracker::DFV - Data::FormValidator constraint methods

=head1 SYNOPSIS

  use XTracker::DFV qw( :promotions );

  # ...

  our %DFV_PROFILE_FOR = (
    a_profile => {
      constraint_methods => {
        some_date_field => dfv_is_ymd(),
      },
    },
  );

=head1 DESCRIPTION

[TODO]

=head1 SEE ALSO

L<Data::FormValidator>

=head1 AUTHOR

Chisel Wright C<< <chisel.wright@net-a-porter.com> >>

=cut
