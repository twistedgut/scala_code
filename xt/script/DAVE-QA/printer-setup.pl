#!/opt/xt/xt-perl/bin/perl

=head1 NAME

printer-setup.pl - Basic script to set up support for printing from XT via CUPS
on a DAVE vm.

=head1 SYNOPSIS

printer-setup.pl [options]

=head1 OPTIONS

=over

=item C<--location|l>

Specify a location - this will automatically set up default IP addresses, as
well as overwrite the existing CUPS configuration and append the printer
addresses to C</etc/hosts>.

This can be one of:

=over

=item C<'uat'>

=item C<'nh5'>

=back

=back

=item C<--skiphosts>

The hosts file will not be updated if this flag is set

=item C<--dummyrun>

If this flag is set, the script will appear to run as normal, but no actual changed will be applied

The hosts file will not be updated if this flag is set

=item C<--force>

Without this flag set, the script will check the XT config to find out if the script should take any action
(typically, we would not want this script to do anything on a production machine for example). Howvever,
if this flag is set, then the script will not check the XT config, and will always go ahead and make
changes.

=head1 DESCRIPTION

If a C<--location> is passed as a command-line argument, the script will not
prompt you for anything, It will use the default IP addresses for that
location, overwrite the CUPS file and append to C</etc/hosts>.

If you run this script without command-line arguments, you will answer a series
of questions as to what you want the script to do.

Under the hood it does 3 things:

=over

=item

optionally copies conf/printers/xtdcN-printers.conf to
C</etc/cups/printers.conf>

=item

creates entries for /etc/hosts in a file under /tmp and lets the user choose
whether they want the script to automatically append them to the real
C</etc/hosts> file

=item

restarts cups to pick up the changes

=back

Yes, it's ugly and needs lots of work, but CLIVE-79 has been stuck going nowhere
for ages, so if this script can encourage even just a few people to keep the
conf/printers/ files up to date with new changes, it'll help. Please feel free to
rewrite/improve (or even just add suggestions in the TODO section below).

=cut

use NAP::policy;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Getopt::Long;
use IO::Prompt;
use Pod::Usage;

use XTracker::Config::Local qw(config_var);

my ($location, $skip_hosts, $force, $dummy_run, $help);
GetOptions(
    'location|l=s' => \$location,
    'skiphosts' => \$skip_hosts,
    'force' => \$force,
    'dummyrun' => \$dummy_run,
    'help|h|?' => \$help
);
pod2usage(1) if $help;

exit(0) unless $force || config_var('PrinterSetupScript', 'enabled');

=head1 PRINTERS

Currently all printers are configured to DC1 models, so we still have some work
to get this script to configure DC2 and DC3 printers properly.

=head2 DC1

=over

=item DHL label - SATO GL408e

=item Document - HP LaserJet P4555n

=item Large label - SATO GL408e

=item Small label - SATO GL408e

=item Sticker - Zebra GX430t (barcode on printer:  06605)

=back

The label printers are given different feeds, but the model is the same.

=head2 DC2

=over

=item Document - HP LaserJet Pro 400 M401dn

=item Large label - Zebra ZM400

=item Small label - Zebra ZM400

=item Sticker - Zebra GX430t

=item UPS label - Zebra GK420d

=back

=head2 DC3

=over

=item DHL label - Zebra GX430t

=item Document - HP LaserJet M402dn

=item Large label - SATO GL408e

=item Small Label - SATO GL408e

=back

=cut

my %printer_type = (
    uat => {
        dc1 => {
            'dhl-label'   => '10.3.33.184',
            'document'    => '10.3.33.226',
            'large-label' => '10.3.33.201',
            'small-label' => '10.3.33.200',
            'sticker'     => '10.3.33.243',
        },
        dc2 => {
            'document'    => '10.7.5.205',
            'large-label' => '10.7.5.202',
            'small-label' => '10.7.5.203',
            'sticker'     => '10.7.5.204',
            'ups-label'   => '10.7.5.206',
        },
        dc3 => {
            'dhl-label'   => '10.3.33.184',
            'document'    => '10.3.33.226',
            'large-label' => '10.3.33.201',
            'small-label' => '10.3.33.200',
        },
    },
    # Couldn't confirm the 'sticker' printer, but all the other ones should be
    # correct at this time
    # TODO: Give DC2 and DC3 their own defaults - currently just copied from DC1
    nh5 => {
        dc1 => {
            'dhl-label'   => '10.5.7.245',
            'document'    => '10.5.7.216',
            'large-label' => '10.5.7.239',
            'small-label' => '10.5.7.239',
            'sticker'     => '10.5.7.239',
        },
        dc2 => {
            'document'    => '10.5.7.216',
            'large-label' => '10.5.7.239',
            'small-label' => '10.5.7.239',
            'sticker'     => '10.5.7.239',
            'ups-label'   => '10.5.4.14',
        },
        dc3 => {
            'dhl-label'   => '10.5.7.245',
            'document'    => '10.5.7.216',
            'large-label' => '10.5.7.239',
            'small-label' => '10.5.7.239',
        },
    },
);

my $dc_name = lc config_var(qw/DistributionCentre name/);
my $printer_ip_map = $location
                   ? ($printer_type{$location}{$dc_name} || die "Unknown location $location\n")
                   : generate_printer_ip_from_prompt($dc_name);

say "Setting up printers for $dc_name in location: $location";

# Create hosts file entries for printers of each type
my $tmp_hosts_filename = "/tmp/printer-hosts-$$";
generate_tmp_hosts_file( $tmp_hosts_filename, $printer_ip_map );

# Guess which printers.conf we need based on the VM's hostname.
# Obviously this will break if the naming convention ever changes.
my $printers_conf_filename = get_printers_conf_filename();

# We don't prompt the user to update files if they have provided a command-line
# argument so this script can be run without user intervention

# Do we want to update CUPS?
my $copy_cups_conf = !!$location || prompt(
    -d => q{y}, '-yn', "Copy $printers_conf_filename to /etc/cups/printers.conf?"
);
if ( $copy_cups_conf ) {
    print 'Updating /etc/cups/printers.conf...';
    _sys_command("sudo cp $printers_conf_filename /etc/cups/printers.conf") == 0
        && say 'done';
}

# Do we want to append the new hosts?
my $append_hosts = !$skip_hosts && (!!$location || prompt(
    -d => q{y}, '-yn', "Append $tmp_hosts_filename to /etc/hosts?",
));
if ( $append_hosts ) {
    # Remove sections added by previous runs
    my ($start_of_block, $end_of_block) = start_end_block_placeholders();
    print 'Updating /etc/hosts...';
    _sys_command(
        "sudo sed -i.bak_printer_setup -re '/$start_of_block/,/$end_of_block/d' /etc/hosts"
    );
    _sys_command("sudo sh -c 'cat $tmp_hosts_filename >> /etc/hosts'") == 0
        && say 'done';
}

# If we've made any changes let's restart CUPS
if ( $copy_cups_conf || $append_hosts ) {
    _sys_command("sudo /sbin/service cups restart") == 0 && say "Restarted cups";
}

exit(0);

sub generate_printer_ip_from_prompt {
    my ( $dc_name ) = @_;
    $location = prompt(
        -m => {
            'UAT'                   => 'uat',
            'Network House Floor 5' => 'nh5',
        },
        'Where are the printers you are configuring?',
    );

    my %printer_prompt = (
        'dhl-label'   => 'IP address for DHL label printers',
        'document'    => 'IP address for document printers (including Gift and Address cards',
        'large-label' => 'IP address for large label printers',
        'small-label' => 'IP address for small label printers',
        'sticker'     => 'IP address for MR Porter and pigeonhole sticker printers',
        'ups-label'   => 'IP address for UPS label printers',
    );
    return {map {
        $_ => prompt( -d => $printer_type{$location}{$dc_name}{$_}, $printer_prompt{$_} )
    } grep { $printer_type{$location}{$dc_name}{$_} } keys %printer_prompt};
}

sub generate_tmp_hosts_file {
    my ( $filename, $printer_ip_map ) = @_;

    # Create a hash mapping hostnames to printer types
    my $type_hostname_map = generate_type_hostname_map($printer_ip_map);

    my ($start_of_block, $end_of_block) = start_end_block_placeholders();

    open my $hosts_file, q{>}, $filename
        or die "Couldn't open $filename to write hosts";
    say $hosts_file "## $start_of_block - generated by $0 - ".localtime;

    for my $type ( sort keys %$type_hostname_map ) {
        say $hosts_file "\n# $type printers\n";
        say $hosts_file $printer_ip_map->{$type} . qq{\t} . $_
            for sort @{$type_hostname_map->{$type}};
        say sprintf '- Wrote %i %s printers',
            scalar @{$type_hostname_map->{$type}}, $type;
    }
    say $hosts_file "\n## $end_of_block";

    close $hosts_file;

    say "Finished writing to temp file $filename";
}

sub generate_type_hostname_map {
    my ( $printer_ip_map ) = @_;

    my %type_hostname;
    my $path_with_placeholder = config_var('SystemPaths','xtdc_base_dir')
        . "/conf/printers/\%s-printers.txt";
    for my $type (keys %$printer_ip_map) {
        my $path = sprintf $path_with_placeholder, $type;
        open my $hosts_input, q{<}, $path
            or die "Couldn't open $path to read hostnames: $!";
        while (my $hostname = <$hosts_input>) {
            chomp($hostname);
            next unless ($hostname =~ /\w+/);
            push @{$type_hostname{$type}}, $hostname;
        }
        close $hosts_input;
    }
    return \%type_hostname;
}

sub get_printers_conf_filename {

    my $dc_name = config_var('DistributionCentre','name');

    my $filename = config_var('SystemPaths','xtdc_base_dir')
        . "/conf/printers/${dc_name}_printers.conf";
    die "Can't find printers.conf file: $filename" unless (-f $filename);

    return $filename;
}

sub start_end_block_placeholders {
    return ('Printer hosts start', 'Printer hosts end');
}

sub _sys_command {
    my ($command) = @_;
    return ($dummy_run ? 0 : system($command));
}

=head1 TODO

=over

=item Allow user to specify different IPs for each type of printer

Useful on UAT envs, for example.

Maybe support something in env config so that user doesn't have to retype IPs each
time they're deploying to a non-standard env?

=item Check that lists of printer hostnames in printers.conf and hosts file match.

Remember to allow for sticker printers existing only in hosts file.)

=back

=cut
