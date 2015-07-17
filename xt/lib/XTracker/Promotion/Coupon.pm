package XTracker::Promotion::Coupon;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Carp;
use String::Random;

use Class::Std;
{
    # what we use to generate coupon suffixes; we'll allow brave souls to
    # modify the regexp, but provide a sane default
    my %suffix_re           :ATTR( get=>'suffix_re',    set=>'suffix_re',   init_arg=>'suffix_re',  default=>'[A-NP-Z2-9]{8}' );

    # the coupong prefix; we don't do any validation on this
    my %prefix_of           :ATTR( get=>'prefix',       set=>'prefix',      init_arg=>'prefix',     default=>'MISSING' );

    # the String::Random object ... just so we have one handy
    my %string_random_of    :ATTR( get=>'string_random' );

    # store the most recent suffix
    my %suffix_of           :ATTR( get=>'suffix',       set=>'suffix' );

    # store the most recently generated suffix list
    my %suffix_list_of      :ATTR( get=>'suffix_list',  set=>'suffix_list' );

    # store the most recently generated coupon list
    my %coupon_list_of      :ATTR( get=>'coupon_list',  set=>'coupon_list' );

    sub START {
        my ($self, $ident, $arg_ref) = @_;

        $string_random_of{$ident} = String::Random->new;
    }

    sub generate_suffix {
        my $self = shift;
        my $suffix = String::Random->new;

        $self->set_suffix(
            $self->get_string_random->randregex(
                $self->get_suffix_re
            )
        );

        return $self->get_suffix;
    }

    sub generate_suffix_list {
        my $self = shift;
        my $required_suffixes = shift;
        my %suffix;
        my @suffixes;

        # make sure $required_suffixes is sane
        if (not defined $required_suffixes or $required_suffixes !~ m{\A\d+\z}) {
            Carp::carp( "\$required_suffixes is invalid - setting to 1" );
            $required_suffixes = 1;
        }

        for (1..$required_suffixes) {
            # make sure each iteration generates a _new_ suffix in our list
            $self->generate_suffix;
            while (exists $suffix{ $self->get_suffix }) {
                Carp::carp( "suffix clash: " . $self->get_suffix );
                $self->generate_suffix;
            }
            $suffix{ $self->get_suffix }++;
        }

        @suffixes = keys %suffix;
        $self->set_suffix_list( \@suffixes );

        return $self->get_suffix_list;
    }

    sub coupon_list {
        my $self = shift;
        my @coupon_list;

        if (not defined $self->get_suffix_list) {
            Carp::carp( "undefined suffix list; did you forget to call ->generate_suffix_list() ?" );
            return;
        }

        # stick the prefix in front of each suffix
        @coupon_list = map {
            $self->get_prefix() . $_
        } @{ $self->get_suffix_list };
        $self->set_coupon_list( \@coupon_list );

        return $self->get_coupon_list;
    }
}

1; # be true

__END__

=pod

=head1 NAME

XTracker::Promotion::Coupon - functionality to make working with coupons easier

=head1 AUTHOR

Chisel Wright C<< <chisel.wright@net-a-porter.com> >>

=cut
