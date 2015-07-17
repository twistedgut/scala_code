#!/opt/xt/xt-perl/bin/perl
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Path::Class qw/dir/;
use XTracker::Config::Local qw/config_section_slurp/;

my $user_to_chown_to = shift
    || die "usage: $0 user_to_chown_to\n";

my ($login,$pass,$uid,$gid) = getpwnam($user_to_chown_to)
  or die "$user_to_chown_to not in passwd file\n";

my %system_paths;
$system_paths{$_} = 1 for values %{ config_section_slurp('SystemPaths') };
$system_paths{$_} = 1 for values %{ config_section_slurp('AMQOrders') };
my @system_paths = sort keys %system_paths;

my %failed;
my @created_paths;

for my $path (@system_paths) {
    if (!-d $path) {
        eval { push @created_paths, dir( $path )->mkpath(0, 0775) }; ## no critic(ProhibitLeadingZeros)
        if ($@) {
            $failed{$path} = "mkpath";
            next;
        }
    }
}

# Set ownership of all newly created paths
foreach my $path (@created_paths){
    unless (system("chown $login: $path 2>/dev/null") == 0) {
        $failed{$path} = "chown";
    }
}

if (%failed) {
    print "Failure to assert these system paths:\n";
    for my $path (sort keys %failed) {
        print "$path: $failed{$path}\n";
    }
    print "Please don't ignore these\n";
    # exit 1; # in a sane world
}

SYMLINKS: {
    my $system_symlinks = config_section_slurp('SystemSymlinks');

    # Create evil xt-spool symlink
    # ...but at least not so hardcoded anymore
    foreach my $symlink (keys %{$system_symlinks}) {

        # broken symlinks "don't exist", hence the apparently extra -l test
        if (-e $symlink or -l $symlink) {
            if ( readlink( $symlink ) ne $system_symlinks->{$symlink} ) {
               print "[symlink] unlinking: $symlink\n";
               unlink $symlink;
            } else {
               print "[symlink] skipping: $symlink, already symlinked correctly\n";
               system("chown -R $login: $symlink") == 0
                   or die "[symlink] Was unable to chown symlink $symlink: $!";
               next;
            }
        }
 
       print "[symlink] creating:  $symlink --> $system_symlinks->{$symlink}\n";

       symlink($system_symlinks->{$symlink},$symlink)
           or die "[symlink] Couldn't create symlink $symlink: $!";
       system("chown -R $login: $symlink") == 0
           or die "[symlink] Was unable to chown symlink $symlink: $!";


       
    }
}
