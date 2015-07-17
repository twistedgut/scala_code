package XTracker::Config::YAML;

use strict;
use warnings;
use version; our $VERSION = qv('1.0.0');
use Data::Dumper;
use Class::Std;
use Net::LDAP;
use base qw/ Helper::Config::YAML /;

{

    my %filter_of :ATTR( get => 'filter', set => 'filter' );
    my %ldap_of :ATTR( get => 'ldap', set => 'ldap' );
    my %db_of :ATTR( get => 'db', set => 'db' );


    sub parse :CUMULATIVE(BASE FIRST) {
        my($self) = @_;
        my $filter = $self->get_filter;

        print __PACKAGE__ ." using filter '$filter'\n" if ($self->debug);

        return
            if (not defined $filter or $filter eq '');

        my $config = $self->get_config;

        die "cannot find '$filter' in the config"
            if (not defined $config->{$filter});

        $self->set_config($config->{$filter});
        $config = $self->get_config;

        # FIXME: pull out the sections we're interested
        die "cannot find ldap section in config"
            if (not defined $config->{ldap});

        $self->set_ldap( $config->{ldap} );

        die "cannot find db section in config"
            if (not defined $config->{db});

        $self->set_db( $config->{db} );


        return;
    }

}

1;
__END__

=head1 NAME

XTracker::Config::YAML - Wrapper to provide simplified usage for YAML

=head1 VERSION


=head1 SYNOPSIS

use Helper::Config::YAML

my $config = Help::Config::YAML->new( {
    base    => ,
});

$config->debug(1);

$config->set_filter('test');

$config->parse;

# returns the ldap section of the configuration
$config->ldap;

=head1 DESCRIPTION

Module to provide NAP specific usage of YAML

=head1 AUTHOR

Jason Tang


=cut
