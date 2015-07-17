#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use FindBin::libs;

use Test::XTracker::Data;
use Test::Exception;
use XTracker::Config::Local qw/config_var/;

use Data::Printer;

use XT::Importer::FCPImport qw( :xml_filename );

# test xml_filename utilities inside FCPImport

my $filename_parts = {
    first => {
                filename => qw( OUTNET_INTL_orders_20110830_142539.xml ),
                 channel => qw( OUTNET_INTL ),
                    type => qw( orders ),
                    date => qw( 20110830 ),
                    time => qw( 142539 ),
                datetime => qw( 20110830142539 )
             },
     last => {
                filename => qw( NAP_AM_orders_20191231_235959.xml ),
                 channel => qw( NAP_AM ),
                    type => qw( orders ),
                    date => qw( 20191231 ),
                    time => qw( 235959 ),
                datetime => qw( 20191231235959 )
             },
};

# longer data sets are:
#
# + deliberately not already sorted
#
# + first and last items deliberately not the first
#   or last by a simple alphanumeric sort of the whole value
#

# first and last items in the sorted list are:
#
# + what's meant to be the first or last item in the list
#
# + deliberately not at either end of the unsorted list
#
#

my $sortable_filename_sets = {
  empty => {     first => undef,
                  last => undef,
                  name => "Empty list",
                 parts => { first => { filename => undef,
                                        channel => undef,
                                           type => undef,
                                           date => undef,
                                           time => undef,
                                       datetime => undef
                                     },
                             last => { filename => undef,
                                        channel => undef,
                                           type => undef,
                                           date => undef,
                                           time => undef,
                                       datetime => undef
                                    }
                          },
             filenames => []
           },

  single => {     first => $filename_parts->{first}{filename},
                   last => $filename_parts->{first}{filename},
                   name => "Single item",
                  parts => { first => $filename_parts->{first},
                              last => $filename_parts->{first} },
              filenames => [ $filename_parts->{first}{filename} ]
             },

  double_sorted => {
                  first => $filename_parts->{first}{filename},
                   last => $filename_parts->{last}{filename},
                   name => "Two pre-sorted different filenames",
                  parts => $filename_parts,
              filenames => [ $filename_parts->{first}{filename},
                             $filename_parts->{last}{filename}
                           ]
            },

  double_reversed => {
                  first => $filename_parts->{first}{filename},
                   last => $filename_parts->{last}{filename},
                   name => "Two reverse-sorted different filenames",
                  parts => $filename_parts,
              filenames => [ $filename_parts->{last}{filename},
                             $filename_parts->{first}{filename}
                           ]
            },

  several_sorted => {
                  first => $filename_parts->{first}{filename},
                   last => $filename_parts->{last}{filename},
                   name => "Several pre-sorted different filenames",
                  parts => $filename_parts,
              filenames => [
                    $filename_parts->{first}{filename},
                    qw(
                        NAP_INTL_orders_20110805_170132.xml
                        NAP_INTL_orders_20110809_115024.xml
                        NAP_INTL_orders_20110809_121224.xml
                        OUTNET_INTL_orders_20110822_174452.xml
                        OUTNET_INTL_orders_20110830_141539.xml
                        OUTNET_INTL_orders_20110830_141939.xml
                        OUTNET_INTL_orders_20110830_142539.xml
                        OUTNET_AM_orders_20110901_154113.xml
                        OUTNET_INTL_orders_20110926_085843.xml
                        MRP_INTL_orders_20111205_164324.xml
                        MRP_INTL_orders_20111205_165324.xml
                        MRP_INTL_orders_20111206_102556.xml
                    ),
                    $filename_parts->{last}{filename},
                ]
            },

  several_reversed => {
                  first => $filename_parts->{first}{filename},
                   last => $filename_parts->{last}{filename},
                   name => "Several reverse-sorted different filenames",
                  parts => $filename_parts,
              filenames => [
                    $filename_parts->{last}{filename},
                    qw(
                       MRP_INTL_orders_20111206_102556.xml
                       MRP_INTL_orders_20111205_165324.xml
                       MRP_INTL_orders_20111205_164324.xml
                       OUTNET_INTL_orders_20110926_085843.xml
                       OUTNET_AM_orders_20110901_154113.xml
                       OUTNET_INTL_orders_20110830_142539.xml
                       OUTNET_INTL_orders_20110830_141939.xml
                       OUTNET_INTL_orders_20110830_141539.xml
                       OUTNET_INTL_orders_20110822_174452.xml
                       NAP_INTL_orders_20110809_121224.xml
                       NAP_INTL_orders_20110809_115024.xml
                       NAP_INTL_orders_20110805_170132.xml
                    ),
                    $filename_parts->{first}{filename},
                ]
              },

  several_mixed => {
                  first => $filename_parts->{first}{filename},
                   last => $filename_parts->{last}{filename},
                   name => "Several unsorted different filenames",
                  parts => $filename_parts,
              filenames => [
                   qw(
                       OUTNET_AM_orders_20110901_154113.xml
                          MRP_INTL_orders_20111206_102556.xml
                       OUTNET_INTL_orders_20110830_141939.xml
                          NAP_INTL_orders_20110805_170132.xml
                       OUTNET_INTL_orders_20110830_142539.xml
                          NAP_INTL_orders_20110809_115024.xml
                    ),
                    $filename_parts->{first}{filename},
                  qw(
                          MRP_INTL_orders_20111205_164324.xml
                       OUTNET_INTL_orders_20110822_174452.xml
                          MRP_INTL_orders_20111205_165324.xml
                       OUTNET_INTL_orders_20110830_141539.xml
                    ),
                    $filename_parts->{last}{filename},
                  qw(
                       OUTNET_INTL_orders_20110926_085843.xml
                          NAP_INTL_orders_20110809_121224.xml
                    )
                ]
              },
};

# because list handling lists sometimes have unexpected problems
# with certain sizes of list, let's also knock up some test lists that
# are a bunch of common sizes and see if they pass through properly

foreach my $data_set ( qw( single double_sorted double_reversed ) ) {
    foreach my $count (2, 3, 5, 7, 11, 13, 17, 47, 74, 101, 4, 8, 15, 16, 23, 42 ) {
        $sortable_filename_sets->{"${data_set}_$count"} = {
                first => $sortable_filename_sets->{$data_set}{first},
                 last => $sortable_filename_sets->{$data_set}{last},
                 name => "$count times $data_set",
                parts => $sortable_filename_sets->{$data_set}{parts},
            filenames => [ ( @{$sortable_filename_sets->{$data_set}{filenames}} ) x $count ]
        };
    }
}

my @broken_filenames = (
    qw(
          MOG_INTL_orders_20120101_000000.xml
          MRP_NILT_orders_20120101_000000.xml
          MRP_INTL_orders_120101_000000.xml
          MRP_INTL_orders_20120101000000.xml
          MRP_INTL_orders20120101000000.xml
          MRP_INTLorders20120101000000.xml
          MRPINTLorders20120101000000.xml

          MRP_INTL_20120101_000000.xml
          MRP_INTL_20120101_0x0000.xml
          MRP_INTL_20120101_00000.xml
          MRP_INTL_20120101_0000000.xml

          MRP_INTL_orders_20120101_000000.xmlx
          MRP_INTL_orders_20120101_000000.
          MRP_INTL_orders_20120101_000000

          .
          ..
      )
);

push @broken_filenames, '', ' ', undef;

foreach my $broken_filename ( @broken_filenames ) {
    my $split = split_xml_filename( $broken_filename );

    ok( !( $split && exists $split->{datetime} ),
        q{Broken filename '}
          .( $broken_filename // '[undefined]')
          .q{' correctly rejected} );
}

run_tests( $sortable_filename_sets, 0 );

foreach my $set ( keys %$sortable_filename_sets ) {
    push @{$sortable_filename_sets->{$set}{filenames}},@broken_filenames;
    $sortable_filename_sets->{$set}{name} .= " with broken names";
}

run_tests( $sortable_filename_sets, 1 );

done_testing;

sub check_sorted_filenames {
    my ( $sortable_set, $includes_broken, @sorted_filenames ) = @_;

    my @sortable_filenames = @{$sortable_set->{filenames}};

    if ( $includes_broken ) {
        is( scalar( @sorted_filenames ),
            scalar( @sortable_filenames ) - scalar( @broken_filenames ),
            q{Sorted filenames contains same number of elements as original list less broken names} );
    }
    else {
        is( scalar( @sorted_filenames ),
            scalar( @sortable_filenames ),
            q{Sorted filenames contains same number of elements as original list} );
    }

    my $diffs = {};

    foreach my $before ( @sortable_filenames ) {
        $diffs->{$before}++ if $before;
    }

    foreach my $after ( @sorted_filenames ) {
        $diffs->{$after}-- if $after;
    }

  DIFF:
    foreach my $diff ( keys %$diffs ) {
        if ( $diff eq '.' || $diff eq '..' ) {
            delete $diffs->{$diff};
            next DIFF;
        }

        my $split_name = split_xml_filename( $diffs->{$diff} );

        unless ( $split_name && exists $split_name->{datetime} ) {
            delete $diffs->{$diff};
            next DIFF;
        }

        delete $diffs->{$diff} unless $diffs->{diff};
    }

    ok( !scalar( keys %$diffs ),
        q{All items in the non-sorted list have exactly one sorted counterpart} );

    my $parts;

    $parts->{first} = split_xml_filename( $sortable_set->{first} );
    $parts->{last}  = split_xml_filename( $sortable_set->{last} );

    foreach my $part ( qw( first last ) ) {
        foreach my $element ( qw( filename channel date time datetime type ) ) {
            is( $parts->{$part}{$element},
                $sortable_set->{parts}{$part}{$element},
                qq{Correct $element for $part item} );
        }
    }
}

sub run_tests {
    my ( $sets, $includes_broken ) = @_;

    foreach my $sortable_set_name ( keys %$sets ) {
        my $sortable_set = $sortable_filename_sets->{$sortable_set_name};

        my @sortable_filenames = @{$sortable_set->{filenames}};

        note "Checking $sortable_set->{name}";

      FILENAME:
        foreach my $sortable_filename ( @sortable_filenames ) {
            my $parts = split_xml_filename( $sortable_filename );

            if ( $includes_broken ) {
                next FILENAME unless $parts && exists $parts->{datetime};
            }

            foreach my $element ( sort keys %{$filename_parts->{first}} ) {
                ok( $parts->{$element},
                    qq{Got $element '$parts->{$element}' from '$sortable_filename'} );
            }

            is( $sortable_filename, $parts->{filename},
                qq{Got original filename '$parts->{filename}' from '$sortable_filename'} );

            my $new_filename = join( q{_},@{$parts}{qw( channel type date time )} ).'.xml';

            is( $sortable_filename, $new_filename,
                qq{Able to reassemble '$new_filename' from component parts} );

            $parts->{datetime} =~ m{
                 \A
                 (?<year>  \d{4})
                 (?<month> \d{2})
                 (?<day>   \d{2})
                 (?<hour>  \d{2})
                 (?<minute>\d{2})
                 (?<second>\d{2})
                 \z
            }x;

            my $dt_obj = DateTime->new(
                year      => $+{year},
                month     => $+{month},
                day       => $+{day},
                hour      => $+{hour},
                minute    => $+{minute},
                second    => $+{second},
                time_zone => 'UTC'
            );

            my $made_filename = make_xml_filename( $parts->{channel}, $dt_obj );

            is( $made_filename, $sortable_filename,
                qq{Able to make matching filename '$made_filename' from channel '$parts->{channel}' and datetime '$parts->{datetime}'} );
        }

        if ( $includes_broken ) {
            note "Skipping comparison function in simple sort";
        }
        else {
            note "Checking comparison function in simple sort";
            check_sorted_filenames( $sortable_set,
                                    0,
                                    sort { xml_filename_cmp( $a, $b ) } @sortable_filenames );
        }

        note "Checking more efficient, less readable, sort function";
        check_sorted_filenames( $sortable_set,
                                $includes_broken,
                                sort_xml_filenames ( @sortable_filenames ) );
    }
}

