package NAP::Template::Plugin::cTracker;
use strict;
use warnings;
use XTracker::Config::Local;

use base qw{ Template::Plugin };

our $VERSION = '0.01_01';

sub new {
    my ($class, $context, @args) = @_;
    my $new_obj = bless {}, $class;

    # get a list of system emails from xtracker.conf
    my @values = values %{ config_section_slurp('Email') };
    my @email_list = grep { m{\@net-a-porter\.com} } @values;
    # store the list of email addresses for easy access later
    $new_obj->{system_addresses} = \@email_list;

    return $new_obj;
}

sub email_type {
    my ($self, $from_list, $to_list) = @_;

    # a count of how many from/to addresses are NOT @net-a-porter.com addresses
    my ($not_from_nap, $not_to_nap) = (0, 0);

    # find out if it's a system email
    if ($self->_is_system_email($from_list)) {
        # we don't care about any other details if it's from The System
        return q[system];
    }

    # otherwise we need to do some domain-counting ...

    # get a count of NAP address in From: list
    $not_from_nap   = _nap_count( $from_list );

    # get a count of NAP address in To: list
    $not_to_nap     = _nap_count( $to_list );

    if ($not_from_nap or $not_to_nap) {
        return q[external];
    }
    else {
        return q[internal];
    }
}

sub _is_system_email {
    my ($self,$list) = @_;
    my $is_system_email = 0;

    my @system_emails = @{ $self->{system_addresses} };

    foreach my $address (@$list) {
        # ignore anything that's not a cTracker::Schema::Addressing object
        if (ref($address) ne q[cTracker::Schema::Addressing]) {
            next;
        }

        my $email_address = $address->address->address;
        if (grep{ m!\A${email_address}\z!xms } @system_emails) {
            # we only need one match to be a system email
            return 1;
        }
    }

    return 0;
}

sub _nap_count {
    my $list  = shift;
    my $tally = 0;

    foreach my $address (@$list) {
        # ignore anything that's not a cTracker::Schema::Addressing object
        if (ref($address) ne q[cTracker::Schema::Addressing]) {
            next;
        }

        my $email_address = $address->address->address;
        if ($email_address !~ m{\@net-a-porter\.com\z}xms) {
            $tally++;
        }
    }

    return $tally;
}

1;
__END__

=pod

=head1 NAME

NAP::Template::Plugin::cTracker - extended TT functionality for cTracker section.

=head1 SYNOPSIS

Make sure that the plugin namespace is specified in XTemplate.pm:

  Template->new(
    # ...
    PLUGIN_BASE => 'NAP::Template::Plugin',
  );

Then use the plugin in your TT templates:

  [% USE cTracker %]

=head1 AUTHOR

Chisel Wright C<< <chisel.wright@net-a-porter.com> >>

=cut

vim: ts=8 sts=4 et sw=4 sr sta
