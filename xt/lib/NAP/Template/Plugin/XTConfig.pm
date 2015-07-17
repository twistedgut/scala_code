package NAP::Template::Plugin::XTConfig;
use strict;
use warnings;
use XTracker::Config::Local(); # don't export anything you polluting c**kend!

use base qw{ Template::Plugin };

our $VERSION = '0.01_01';

sub new {
    my ($class, $context, @args) = @_;
    my $new_obj = bless {}, $class;

    return $new_obj;
}

sub config_var {
    my ($self, $section, $var) = @_;
    return XTracker::Config::Local::config_var($section, $var);
}

1;
__END__

=pod

=head1 NAME

NAP::Template::Plugin::Config - v. simple plugin to wrap XTracker::Config::Local

=head1 SYNOPSIS

Make sure that the plugin namespace is specified in XTemplate.pm:

  Template->new(
    # ...
    PLUGIN_BASE => 'NAP::Template::Plugin',
  );

Then use the plugin in your TT templates:

  [% USE XTConfig %]

=head1 AUTHOR

Misha Gale C<< <misha.gale@net-a-porter.com> >>

=cut
