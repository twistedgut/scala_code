package Helper::Config::YAML;
use strict;
use warnings;

use version; our $VERSION = qv('1.0.0');

use Data::Dumper;
use Class::Std;
use Net::LDAP;
use Readonly;

{

    my %file_of :ATTR( get => 'file', set => 'file', init_arg => 'file' );
    my %debug_of :ATTR( get => 'debug', set => 'debug' );
    my %config_of :ATTR( get => 'config', set => 'config' );


    sub debug {
        my($self) = @_;

        return $self->get_debug;
    }

    sub parse :CUMULATIVE(BASE FIRST) {
        my($self) = @_;
        my $config = undef;
        my $file = $self->get_file;

        # check the file is readable and exists
        die "config file does not exist - $file" if (not -f $file);

        # parse it in
        eval {
            $config = YAML::LoadFile($file);
        };

        if ($@) {
            die "problem reading in file - $@";
        }

        $self->set_config($config);

        return;
    }

}

1;
__END__

=head1 NAME

Helper::Config::YAML - Wrapper to provide simplified usage for YAML

=head1 VERSION


=head1 SYNOPSIS

use Helper::Config::YAML

my $config = Help::Config::YAML->new( {
    file    => 'application.conf',
});

$config->debug(1);

$config->parse;

=head1 DESCRIPTION

A helper module using YAML to pull out none-NAP specific code

=head1 AUTHOR

Jason Tang

=cut
