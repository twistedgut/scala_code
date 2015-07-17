package Test::Config;
use strict;
use warnings;

use Carp;
use Config::Any;
use Catalyst::Utils;
use Data::Visitor::Callback;
use XTracker::Config::Local qw ( :DEFAULT app_root_dir );

our %config;

sub load_config {

    my $dc   = config_var( 'DistributionCentre', 'name' );
    my $root = app_root_dir() . 't/conf/xtracker';

    # read in the config file
    my $config = Config::Any->load_files({
      use_ext => 1,
      files   => [ "$root/test.conf", "$root/$dc.conf" ],
    });

    if ( $ENV{XT_CONFIG_DEBUG} ) {
        warn "loaded test config files:\n";
        require Data::Dump;
        Data::Dump::pp(@$config);
    }

    my $hash = {};
    $hash = Catalyst::Utils::merge_hashes($hash, $_) foreach ( map { values( %$_ ) } @$config );

    finalize_config( $hash );

    %config = %$hash;
    return %config;

}

# I've stolen these two from Catalyst::Plugin::ConfigLoader and adapted them to this XTDC paradigm.
# Hopefully Catalyst will arrive soon to XTDC and whoever reads this can have a laugh.
sub finalize_config {
    my $config = shift;
    my $v      = Data::Visitor::Callback->new(
        plain_value => sub {
            return unless defined $_;
            config_substitutions( $_ );
        }
    );
    $v->visit( $config );
}

sub config_substitutions {
    my $subs = {};

    $subs->{ env }     ||= sub { $ENV{$_[0]}||$_[1]; };
    $subs->{ literal } ||= sub { return $_[ 1 ]; };
    my $subsre = join( '|', keys %$subs );

    for ( @_ ) {
        s{__($subsre)(?:\((.+?)\))?__}{ $subs->{ $1 }->( $2 ? split( /,/, $2 ) : () ) }eg;
    }
}

load_config();

# If you really must hard-code something for some reason, put it in %defaults, and it will only be used if there is no config value
my %defaults = ();

### Subroutine : value                              ###
# usage        : $value = value($section, $variable); #
# description  : Returns the value of config var    #
#              : named $variable from section       #
#              : $section of the config file, or    #
#              : undef if the variable isn't in     #
#              : the config file.                   #
# parameters   : $section, $variable                #
# returns      : scalar or list ref                 #

sub value {
    my ($class, $section, $variable, @ancestry ) = @_;

    if ( exists $config{ $section } ) {
        if ( exists $config{ $section }{ $variable } ) {
            return $config{ $section }{ $variable };
        }
        elsif ( exists $config{$section}{INHERITFROM} ) {

            #Check that the current section isn't a 'superclass' of itself
            if ( grep( { $_ eq $section } @ancestry ) ) {

                # Circular inheritance detected! Avoid an infinite-loop condition
                carp "Configuration section [$section] inherits from itself!";
                return;
            }
            return $class->value(
                $config{$section}{INHERITFROM},
                $variable,
                ( @ancestry, $section )
            );
        }
    }
    return _default_value( $section, $variable );
}

sub section_keys {
    my ($class, $section) = @_;

    return if (not defined $config{$section});

    my @keys = keys %{$config{$section}};

    return \@keys;
}

sub _default_value {
    my ($section, $variable) = @_;

    #exists() is called twice to prevent auto-vivification of $defaults{section}
    if ( exists( $defaults{$section} ) and exists( $defaults{$section}{$variable} ) ) {
        return $defaults{$section}{$variable};
    }
    return;
}

sub section_slurp {
    my ($class, $section, @ancestry) = @_; # Contains a list of sections inherited from, to prevent circular inheritance

    my $return_hash = {};

    if ( exists( $defaults{ $section } ) and not @ancestry ) {
    foreach my $k (keys %defaults) {
        $return_hash->{$k} = $defaults{$k};
    }
    }

    if (!$class->section_exists($section)) {
    return $return_hash;
    }

    if ( exists( $config{$section}{INHERITFROM} ) ) {
        my $parent_hash = $class->section_slurp(
            $config{$section}{INHERITFROM},
            ( @ancestry, $section )
        );
        foreach my $k (keys %$parent_hash) {
            $return_hash->{$k} = $parent_hash->{$k};
        }
    }

    foreach my $k (keys %{ $config{ $section } } ) {
        $return_hash->{$k} = $config{$section}{$k};
    }

    return $return_hash;
}

sub section_exists {
    my $class = shift;
    my $section = shift;
    return $config{ $section };
}

sub sections {
    my $class   = shift;
    my $regexp  = shift || qr//;
    my @result  = ();

    foreach my $section (keys(%config)) {
        if ($section =~ $regexp) {
            # If the regex has a subexpression, use that instead of the full
            # section
            push(@result, ($1 ? $1 : $section));
        }
    }
    return @result;
}

1;
