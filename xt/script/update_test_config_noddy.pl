#!/opt/xt/xt-perl/bin/perl

use NAP::policy;

use Config::Any;
use IO::Prompt;
use File::Slurp;
use File::Temp qw(tempfile);
use File::Spec::Functions;
use Getopt::Long;

GetOptions (
    "config_file=s" => \(my $config_file = catfile($ENV{HOME},'.noddy.conf')),
    "section=s"  => \(my $config_section),
    "dc=s"       => \(my $dc_name),
    "temp=s"     => \(my $incoming),
    "email=s"    => \(my $email),
    "hosttype=s" => \(my $host_type),
    "db=s"       => \(my $xt_db),
    "host=s"     => \(my $host),
    "prl=s"      => \(my $prl_phase),
    # Once the file is created move it to $HOME
    "move!"      => \(my $move_file),
);

# This maps the config keys to the variables - you can use pretty much any
# config that Config::Any accepts, just put it under a dc1/2/3 section and pass
# that on the command line as the 'dc' option, e.g.
# <dc1>
#   db_name     xtdc1_blank
#   email       foo@example.com
#   host        myhost.dave.net-a-porter.com
#   hosttype    XTDC1
#   prl         0
#   properties  ./conf/nap_dev.properties
# </dc1>
# Note that you'll still be prompted for any entries you don't provide that you
# would normally, and that an options given on the command line override your
# config's
my $config_varref_map = {
    db_name    => \$xt_db,
    email      => \$email,
    host       => \$host,
    hosttype   => \$host_type,
    prl        => \$prl_phase,
    properties => \$incoming,
    move       => \$move_file
};

# If we have a config file use it
if ( -f $config_file ) {
    die 'If you have a config file you must pass a section' unless $config_section;

    # Load our config and die if we can't find the appropriate section
    my $config = Config::Any->load_files({
        files => [$config_file],
        use_ext => 1,
    })->[0]{$config_file}{$config_section};
    die "Couldn't find config for '$dc_name'" unless $config;

    # Populate our variables with config options but allow command-line overrides
    ${$config_varref_map->{$_}} //= $config->{$_} for keys %$config_varref_map;
}

# A little help for those who have not used this before
say <<EOF
Answer the following questions to have a new properties file generated
based on your answers and the current properties.

This will generate a new file and not touch your existing properties file.
This should then be copied to where ever you keep your properties file.
EOF
unless grep { !defined $$_ } values %$config_varref_map;

# Get the incoming file
my $default_template = catfile( $ENV{'XTDC_BASE_DIR'} || '.', 'conf/nap_dev.properties' );
$incoming //= prompt( -d => $default_template, "Template file: " );
my $input_data = read_file( $incoming );
die "Can't read anything from [$incoming]" unless $input_data;
die "Contents of [$incoming] doesn't look like a config file"
    unless $input_data =~ m/IWS_ROLLOUT_PHASE_DC1/;

# Is this part of a full-stack environment, or a dev machine?
my $dave_env = $input_data =~ m/xtdc1\-\<\%\= nap_env \%\>/;
print "Config file type: " . ($dave_env ? 'DAVE' : 'Developer') . "\n";

# Build up our configuration changes
my @transforms = (
    # Pass-through comments and space-only lines
    sub {
        my ( $original_line, $key, $value, $comment, $fh ) = @_;
        if ( $original_line =~ m/\s*#/ || $original_line !~ /\w/ ) {
            print $fh $original_line . "\n";
            return 1;
        }
        return;
    }
);

# Strange email addresses?
$email //= prompt("Single Email Recipient (leave blank to not set): ");
if ( ''.$email ) {
    push( @transforms, sub {
        my ( $original_line, $key, $value, $comment, $fh ) = @_;
        return unless $value =~ m/.+\@/;
        print $fh format_line( $key, $email, $comment ) . "\n";
        return 1;
    } );
    push( @transforms, st(SINGLE_MAIL_RECIPIENT => 1) );
}

# Add AMQ stuff?
my $amq_add_flag   = 0;
my $amq_added_flag = 0;
my $amq_transform = sub {
    my ( $original_line, $key, $value, $comment, $fh ) = @_;
    return unless $key eq 'AMQ_LOG_ALL_MESSAGES' && $value eq '0';
    print $fh format_line( AMQ_REALLY_SEND      => 1 ) . "\n";
    print $fh format_line( AMQ_LOG_ALL_MESSAGES => 1 ) . "\n";
    print $fh format_line( AMQ_LOG_DIR => '/var/data/xt_static/queue' ) . "\n";
    $amq_added_flag = 1;
    return 1;
};

if ( $dave_env ) {
    my $add_amq = prompt( -d => 'N', -yes => "Turn on QA/Tester AMQ hack?: ");
    if ( $add_amq ) {
        $amq_add_flag = 1;
        push( @transforms, $amq_transform );
    }
}

# Host type
if (! $dave_env ) {
    $host_type //= prompt( '-m' => ['XTDC1', 'XTDC2', 'XTDC3'], -d => 'XTDC1', 'Host type? ' );

    # Alternative XT DB
    $xt_db //= prompt(
        -d => { XTDC1 => 'xtracker', XTDC2 => 'xtracker_dc2', 'XTDC3' => 'xtdc3' }->{$host_type},
        "DB name for $host_type: "
    );
    my $atom = substr( $host_type, 2, 3 );

    # Hosts for dcx, dcx jq
    $host //= prompt(
        -d => 'localhost',
        "Host for $xt_db and $host_type job_queue: "
    );
    push( @transforms,
        st( NAP_HOST_TYPE => $host_type ),
        st( $atom . '_XTRACKER_DB_NAME' => $xt_db ),
        st( $atom . '_XTRACKER_DB_HOST' => $host ),
        st( $atom . '_DB_JOB_QUEUE_DBDSN' => "dbi:Pg:dbname=job_queue;host=$host" ),
    );

    $prl_phase //= prompt( -m => [0..2],
        -d => { XTDC1 => 0, XTDC2 => 2, XTDC3 => 0 }->{$host_type},
        'Enable PRL rollout phase?: ' );
    push @transforms, st( "PRL_ROLLOUT_PHASE_$atom" => $prl_phase );

} else {
    # Does anyone use this bit?
    push( @transforms, st( 'IWS_ROLLOUT_PHASE_DC1',
        prompt( -m => [0..2], -d => 1, "IWS Phase for DC1: ")
    ) );
    push( @transforms, st( 'IWS_ROLLOUT_PHASE_DC2',
        prompt( -m => [0..2], -d => 0, "IWS Phase for DC2: ")
    ) );
    push( @transforms, st( 'IWS_ROLLOUT_PHASE_DC3',
        prompt( -m => [0..2], -d => 0, "IWS Phase for DC3: ")
    ) );
}

# Add the catch-all that prints the original line
push( @transforms, sub {
    my ( $original_line, $key, $value, $comment, $fh ) = @_;
    print $fh $original_line . "\n";
} );

my ( $temp_fh, $temp_fn ) = tempfile();
for my $line ( split(/\n/, $input_data) ) {
    my ( $key, $value, $comment ) = $line =~ m/^(\w+)\s+([^#]+)(#.+)?$/;
    my @args = (
        $line, ( map { my $item = clean_space( $_ ); $item // '' } $key, $value, $comment ), $temp_fh ); # /
    for my $transform ( @transforms ) {
        last if $transform->( @args );
    }
}
if ( $amq_add_flag && !$amq_added_flag ) {
    $amq_transform->( '', 'AMQ_LOG_ALL_MESSAGES', 0, '', $temp_fh );
}

close $temp_fh;

if ( $move_file ) {
    my $destination_file
        = catfile( $ENV{HOME}, 'nap_dev.properties' );
    rename $temp_fn, $destination_file
        or die "Failed to rename $temp_fn to $destination_file";
    $temp_fn = $destination_file;
}

print `diff $incoming $temp_fn`; ## no critic(ProhibitBacktickOperators)
print "FILE: $temp_fn\n";

sub clean_space {
    my $item = shift;
    return unless length( $item );
    $item =~ s/^\s+//;
    $item =~ s/\s+$//;
    return $item;
}

sub format_line {
    my ( $key, $value, $comment ) = @_;
    $value = '""' unless length( $value );
    my $pad = ' ' x (62 - length( $key ));
    my $output = $key . $pad . $value;
    if ( $comment ) {
        $output .= '# ' . $comment;
    }
    return $output;
}

sub st {
    my ( $match_key, $new_value ) = @_;
    return sub {
        my ( $original_line, $key, $value, $comment, $fh ) = @_;
        return unless $key eq $match_key;
        return if $value eq $new_value;
        print $fh format_line( $key, $new_value, $comment ) . "\n";
        return 1;
    };
}
