package Test::XTracker::ParamCheck;

use strict;
use warnings;

use Test::More;
use Moose;

no Moose;



# This checks that an error message appears when absent parameters
# are passed to a function also checks against invalid parameters
sub check_for_params {

    my $self        = shift;
    my $func        = shift;
    my $label       = shift;
    my $rqd_params  = shift;
    my $rqd_msgs    = shift;
    my $inv_params  = shift;
    my $inv_msgs    = shift;


    # check for required parameters
    if ( defined $rqd_params ) {
        foreach my $idx ( 0..$#{ $rqd_params } ) {
            next        if ( !defined $rqd_params->[$idx] );
            eval {
                my @pass_in = @{ $rqd_params };
                $pass_in[$idx]  = undef;
                $func->( @pass_in );
            };
            like($@,qr/$rqd_msgs->[$idx]/,"${label}: Failed on ".$rqd_msgs->[$idx]);
        }
    }
    # check for invalid parameters
    if ( defined $inv_params ) {
        foreach my $idx ( 0..$#{ $inv_params } ) {
            next        if ( !defined $inv_params->[$idx] );
            eval {
                my @pass_in = @{ $rqd_params };
                $pass_in[$idx]  = $inv_params->[$idx];
                $func->( @pass_in );
            };
            like($@,qr/$inv_msgs->[$idx]/,"${label}: Failed on ".$inv_msgs->[$idx]);
        }
    }

    return;
}

# This checks that an error message appears when absent parameters
# are passed to a function in anonymous hashes also checks against invalid parameters
sub check_for_hash_params {

    my $self        = shift;
    my $func        = shift;
    my $label       = shift;
    my $rqd_params  = shift;
    my $rqd_msgs    = shift;
    my $inv_params  = shift;
    my $inv_msgs    = shift;


    # check for required parameters
    if ( defined $rqd_params ) {
        foreach my $idx ( 0..$#{ $rqd_params } ) {
            next        if ( ref( $rqd_params->[$idx] ) ne "HASH" );
            foreach my $key ( keys %{ $rqd_params->[$idx] } ) {
                next    if ( !defined $rqd_msgs->[$idx]{$key} );
                my $tmp;
                eval {
                    my @pass_in = @{ $rqd_params };
                    $tmp = delete $pass_in[$idx]{$key};
                    $func->( @pass_in );
                };
                like($@,qr/$rqd_msgs->[$idx]{$key}/,"${label}: Failed on ".$rqd_msgs->[$idx]{$key});
                $rqd_params->[$idx]{$key} = $tmp;
            }
        }
    }
    # check for invalid parameters
    if ( defined $inv_params ) {
        foreach my $idx ( 0..$#{ $inv_params } ) {
            next        if ( ref( $rqd_params->[$idx] ) ne "HASH" );
            foreach my $key ( keys %{ $rqd_params->[$idx] } ) {
                next    if ( !exists $inv_params->[$idx]{$key} );
                my $tmp;
                eval {
                    my @pass_in = @{ $rqd_params };
                    $tmp    = $pass_in[$idx]{$key};
                    $pass_in[$idx]{$key}    = $inv_params->[$idx]{$key};
                    $func->( @pass_in );
                };
                like($@,qr/$inv_msgs->[$idx]{$key}/,"${label}: Failed on ".$inv_msgs->[$idx]{$key});
                $rqd_params->[$idx]{$key}   = $tmp;
            }
        }
    }

    return;
}


1;
__END__

=pod

=head1=SYNOPSIS

    use Test::Xtracker::ParamCheck;

    my $param_check = Test::Xtracker::ParamCheck->new();

    $param_check->check_for_params( ... );
    $param_check->check_for_hash_params( ... );

=head1=DESCRIPTION

This module provides 2 functions to check required parameters and invalid parameters passed to functions. It checks for specific error messages for each parameter check. The 2 functions are:

check_for_params();

This checks for basic paramters passed as an array such as: function_name( $param1, $param2, $param3 );

check_for_hash_params();

This checks for parameters passed into an Anoymous Hash such as: function_name( $param1, { key1 => value1, key2 => value2 }

=cut
