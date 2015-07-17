package XTracker::Logout;
use NAP::policy "tt";

sub handler {
    my $r = shift;

    if ($r->isa('XT::Plack::FakeModPerl')) {
        return handler__plack($r);
    }
    elsif ($r->isa('Apache')) {
        return handler__modperl($r);
    }
    else {
        say 'Unknown Logout' . ref($r);
    }
}

sub handler__plack {
    die 'We should have been handled by Plack::Middleware::';
}

sub handler__modperl {
    die 'We no longer use apache/mod_perl - how did you get here?';
}

1;
