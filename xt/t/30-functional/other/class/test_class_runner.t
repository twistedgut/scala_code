#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use FindBin::libs;
use mro;

=head1 NAME

test_class_runner.t - run all the Test::Class tests

=head1 DESCRIPTION

Runner for Test::Class files in t/30-functional

They used to live in t/20-units/ but strictly speaking, if you have to fire up
mechanize they aren't unit tests.

These are the Test::Class tests that use ::Flow or Mechanize.

Beneath this directory, Test::Class .pm files live. They are named
primarily after the main class they test, with a Test:: prefix. e.g.

    Test::NAP::ShippingOption

All Test::Class classes should inherit from NAP::Test::Class, so that
they're run automatically.

You can run these all together by running:

    prove -vl test_class_runner.t

or individualy, by running:

    prove -vl path/To/Individual/Test/Class/File.pm

=cut

use Test::Class::Load "./t/30-functional/other/class";

my @test_classes = @{mro::get_isarev('Test::Class')};

Test::Class->runtests(sort @test_classes);
