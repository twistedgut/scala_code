package Test::NAP::Carp;

=head1 NAME

Test::NAP::Carp

=head1 DESCRIPTION

Check that NAP::Carp filters stacktraces, that it includes what it's supposed to
and filters out what it's supposed to.

=cut

use NAP::policy 'test', 'tt';

use parent 'NAP::Test::Class';

use NAP::Carp 'cluck';

sub test_cluck :Tests {
    my ($self) = @_;

    my $error_message;

    # Catch the next warn (cluck)
    local $SIG{__WARN__} = sub {
        $error_message = shift;
    };

    cluck 'Hadouken';

    like($error_message, qr/Hadouken/, 'Stacktrace detected');
    like($error_message, qr/ at \(abridged\) /, 'NAP::Carp filtering detected');
}

sub test_confess :Tests {
    try {
        NAP::Something::foo();
    }
    catch {
        my $error_message = $_;
        like($error_message, qr/Shoryuken/, 'Stacktrace detected');
        like($error_message, qr/NAP::Something/, 'Stacktrace contains expected module');
        unlike($error_message, qr/Plack::Wibble/, 'Stacktrace does not contain unwanted module');
    };
}

# The packages below are designed to test NAP::Carp::confess

package NAP::Something { ## no critic(ProhibitMultiplePackages)
    sub foo {
        Plack::Wibble::boing();
    }
}

package Plack::Wibble {
    use NAP::policy;
    use NAP::Carp qw/confess/;
    sub boing {
        confess('Shoryuken');
    }
}
