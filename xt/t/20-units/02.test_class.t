#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use FindBin::libs;
use mro;

=head1 DESCRIPTION

Test::Class runner for t/20-units/class

Beneath this directory, Test::Class .pm files live. They are named
primarily after the main class they test, with a Test:: prefix. e.g.

  Test::NAP::ShippingOption

All Test::Class classes should inherit from NAP::Test::Class, so that
they're run automatically.

You can run these all together by running

  prove -vl t/20-units/02.test_class.t

or individualy, by running

  prove -vl t/20-units/class/Test/NAP/ShippingOption.pm

=cut

use Test::Class::Load "./t/20-units/class";

my @test_classes = @{mro::get_isarev('Test::Class')};

Test::Class->runtests(sort @test_classes);
