#!/usr/bin/env perl

use strict;
use warnings;
use Template;
use File::Path 'make_path';
my $template_body = join '', (<DATA>);

# Usage: t/script/create_test_class.pl XTracker::Your::Class
#
# Creates a basic Test::Class class, and prints its name for you

# Get the class the user passed in
my $target = ClassName->new(( $ARGV[0] ||
    die "Please specify a class to create a test class for"),
    'lib'
);

# Was that what the user wanted?
print "You'd like to create a test class for:\n";
print $target->explain_yourself;
die "Please try again!" unless prompt("Is this correct");

# What would a test class look like?
my $test_class = ClassName->new( 'Test::' . $target->as_class,
    't/20-units/class/' );
print "We'll be creating:\n";
print $test_class->explain_yourself;
die "Please try again!" unless prompt("Is this correct");

# Check it doesn't already exist...
die sprintf("Refusing to overwrite existing [%s]", $test_class->as_file)
    if -e $test_class->as_file;

# Do we have the requisite directory?
my $directory = $test_class->as_file->dir;
unless ( -d $directory ) {
    print "The directory [$directory] doesn't exist.\n";
    die "Bailing out!" unless prompt("Create it");
    make_path $directory;
}

# Create the class body
my $template_obj = Template->new();
my $output = '';

$template_obj->process( \$template_body, {
    target_class => $target,
    test_class   => $test_class
}, \$output ) || die $template_obj->error();

open( my $fh, '>', $test_class->as_file ) ||
    die sprintf("Can't open %s for writing", $test_class->as_file);
print $fh $output;
close $fh;

print "Created:\n";
print $test_class->explain_yourself;
my $perldoc = sprintf('perldoc -t -T %s', $test_class->as_file );
print `$perldoc`; ## no critic(ProhibitBacktickOperators)

sub prompt {
    my ( $message ) = @_;
    print $message . " [(Y)es/(N)o/(A)bort]: ";
    my $input = <STDIN>; ## no critic(ProhibitExplicitStdin)
    $input = lc( substr( $input, 0, 1 ) );
    return 1 if $input eq 'y';
    return 0 if $input eq 'n';
    die "User aborted process" if $input eq 'a';
    print "Unrecognized input\n";
    return prompt( $message );
}

package ClassName;
use Path::Class;

sub new {
    my ( $class, $string, $prefix ) = @_;
    my $suffix = 'pm';

    # Create the object
    my $self = bless {
        suffix => $suffix,
        prefix => $prefix,
        atoms  => [],
    }, $class;

    # Populate atoms appropriately
    if ( $string =~ m/:/ ) {
        $self->{'atoms'} = [split(/::/, $string)];
    } else {
        $string =~ s!^$prefix/?!!;
        $string =~ s/\.$suffix$//;
        $self->{'atoms'} = [split(qr!/!, $string)];
    }

    return $self;
}

sub explain_yourself {
    my $self = shift;
    return sprintf("Class: [%s]\nFile : [%s]\n",
        $self->as_class, $self->as_file );
}

sub as_class {
    my $self = shift;
    return join '::', @{$self->{'atoms'}};
}

sub as_file {
    my $self = shift;

    # Take a copy of atoms, and mangle it so the last one ends
    # with the filetype suffix
    my @atoms = @{$self->{'atoms'}};
    $atoms[-1] .= '.' . $self->{'suffix'};

    return file( $self->{'prefix'}, @atoms );
}

package main; ## no critic(ProhibitMultiplePackages)

1;

__DATA__
package [% test_class.as_class %];

use FindBin::libs;
use NAP::policy "tt", 'test';

use parent "NAP::Test::Class";
use [% target_class.as_class %];

=head1 NAME

[% test_class.as_class %] - Unit tests for [% target_class.as_class %]

=head1 DESCRIPTION

Unit tests for [% target_class.as_class %]

=head1 SYNOPSIS

 # Run all tests
 prove [% test_class.as_file %]

 # Run all tests matching the foo_bar regex
 TEST_METHOD=foobar prove [% test_class.as_file %]

 # For more details, perldoc NAP::Test::Class

=cut

# See NAP::Test::Class for details.

sub foobar : Tests() {
    ok("I live!");
}

=head1 SEE ALSO

L<NAP::Test::Class>

L<[% target_class.as_class %]>

=cut

1;
