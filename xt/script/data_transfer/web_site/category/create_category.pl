#!/opt/xt/xt-perl/bin/perl

use warnings;
use strict;
use Carp;

use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( fcp_handle fcp_staging_handle fcp_us_handle );

my $dbh = fcp_handle();


my %category = (
                #60 => [ 'Basic Layers', 'Clothing' ],
                #61 => [ 'Jeans',  'Clothing' ],
                #62 => [ 'Kids', 'Clothing' ],
                #63 => [ 'Sleepwear', 'Clothing' ],
                #64 => [ 'Wraps', 'Clothing' ],
                #65 => [ 'Bracelet', 'Accessories' ],
                #66 => [ 'Brooch', 'Accessories' ],
                #67 => [ 'Day Dresses', 'Clothing' ],
                #68 => [ 'Earrings', 'Accessories' ],
                #69 => [ 'Evening Dresses', 'Clothing' ],
                #70 => [ 'Necklace', 'Accessories' ],
                #71 => [ 'Ring', 'Accessories' ],
                #312 => [ 'By Malene Birger', 'Designer' ],
                #306 => [ 'Anglomania', 'Designer' ],
                #318 => [ 'Falke', 'Designer' ],
                #319 => [ 'Bodyamr', 'Designer' ],
                #323 => [ 'Goldsign', 'Designer' ,]
                #330 => [ 'LWren Scott', 'Designer' ,],
                #321 => [ 'MICHAEL Michael Kors', 'Designer' ,]

                #317 => [ 'Primp', 'Designer'],
                #324 => [ 'Be & D', 'Designer'],
                #325 => [ 'D&G', 'Designer'],
                #326 => [ 'Development', 'Designer'],
                #327 => [ 'Graham & Spencer', 'Designer'],
                #328 => [ 'Iisli', 'Designer'],
                #329 => [ 'Leaves of Grass', 'Designer'],
                #331 => [ 'Mayle', 'Designer'],
                #332 => [ 'Norma Kamali for Everlast', 'Designer'],
                #333 => [ '12th Street by Cynthia Vincent', 'Designer'],
                #334 => [ 'Bejeweled', 'Designer'],
                #335 => [ 'Rachel Roy', 'Designer'],
                #336 => [ 'Rebecca Taylor', 'Designer'],
                #337 => [ 'Tom Binns', 'Designer'],
                #338 => [ 'Sinful', 'Designer'],
                #339 => [ 'Jas MB', 'Designer'],

                 #340  => [ 'Alexander Wang', 'Designer' ],
                 #341  => [ 'Bilali', 'Designer' ],
                 #342  => [ 'Erotokritos', 'Designer' ],
                 #343  => [ 'Hoss', 'Designer' ],
                 #344  => [ 'Just Cavalli', 'Designer' ],
                 #345  => [ 'Katherine E Hamnett', 'Designer' ],
                 #346  => [ 'Manoush', 'Designer' ],
                 #347  => [ 'Mira Mikati', 'Designer' ],
                 #348  => [ 'Olivia Morris', 'Designer' ],
                 #349  => [ 'Oscar de la Renta', 'Designer' ],
                 #350  => [ 'Vivienne Westwood Red Label', 'Designer' ],
                 # 351  => [ 'Rupert Sanderson', 'Designer' ],
                 #352  => [ 'Sonia by Sonia Rykiel', 'Designer' ],
                 #353  => [ 'Paula Thomas for TW', 'Designer' ],
                 #354  => [ 'Todd Lynn', 'Designer' ],
                 #355  => [ 'Christensen and Sigersen', 'Designer' ],
                 #356  => [ 'David Szeto', 'Designer' ],
                 #357  => [ 'Jay Ahr', 'Designer' ],
                 #358  => [ 'Hunter', 'Designer' ],
                 #359  => [ 'Binetti', 'Designer' ],
                 #360  => [ 'Notte by Marchesa', 'Designer' ],
                 #361  => [ 'Giles', 'Designer' ],
                 # 365  => [ 'Mulberry for Giles', 'Designer' ],
                 # 379  => [ 'Tooshie', 'Designer' ],
                 # 372  => [ 'Paige', 'Designer' ],

                 #364  => [ 'Mawi', 'Designer' ],
                 #377  => [ 'MINT jodi Arnold', 'Designer' ],
                 #387  => [ 'Zimmermann', 'Designer' ],
                 #394  => [ 'Zoe & Morgan', 'Designer' ],
                 # 375  => [ 'Erva', 'Designer' ],
                 # 371  => [ 'Nanette Lepore', 'Designer' ],
                 # 401  => [ 'RM', 'Designer' ],
                 # 381  => [ 'Jonathan Saunders', 'Designer' ],
                 # 376  => [ 'Helmut Lang', 'Designer' ],

                  #389  => [ 'Pringle', 'Designer' ],
                  #367  => [ 'Brian Atwood', 'Designer' ],
                  #390  => [ 'Camilla and Marc', 'Designer' ],
                  #380  => [ 'Devi Kroell', 'Designer' ],
                  #397  => [ 'Gryphon', 'Designer' ],
                  #369  => [ 'Herve Leger', 'Designer' ],
                  #392  => [ 'James Perse', 'Designer' ],
                  #393  => [ 'Johnstons', 'Designer' ],
                  #395  => [ 'K Karl Lagerfeld', 'Designer' ],
                  #382  => [ 'Karta', 'Designer' ],
                  #384  => [ 'Rodnik', 'Designer' ],
                  #386  => [ 'Tracy Reese', 'Designer' ],
                  # 385  => [ 'Superfine', 'Designer' ],
                  #404  => [ 'Acne Jeans', 'Designer' ],
                  #407  => [ 'Earnest Sewn', 'Designer' ],
                  #99999  => [ 'Fashion Targets Breast Cancer', 'Designer' ],
                  # 413    => [ 'Botkier', 'Designer' ], 
                  #412  => [ 'Hera', 'Designer' ], 
                  #405  => [ 'Chris Benz', 'Designer' ], 
                  #410  => [ 'Isharya', 'Designer' ], 
                  #400  => [ 'Allegra Hicks', 'Designer' ], 
                  #414  => [ 'Roksanda Ilincic', 'Designer' ], 
                  # 406  => [ 'Giuseppe Zanotti', 'Designer' ], 
                  #418  => [ 'Thread Social', 'Designer' ], 
                  #419  => [ 'Bill Blass', 'Designer' ], 
                  #422  => [ 'Thurley', 'Designer' ], 
                  #425  => [ 'Monica Vinader', 'Designer' ], 
                  #421  => [ 'Oliver Peoples', 'Designer' ], 
                  # 437  => [ 'Halston', 'Designer' ], 
#                  438  => [ 'Adidas by Stella McCartney', 'Designer' ],
#441  => [ 'Bally', 'Designer' ],
#442  => [ 'Belle by Sigerson Morrison', 'Designer' ],
#432  => [ 'Couture Couture', 'Designer' ],
#444  => [ 'DKNY', 'Designer' ],
#433  => [ 'Donna Karan', 'Designer' ],
#434  => [ 'Isaac Mizrahi', 'Designer' ],
#427  => [ 'Maison Martin Margiela', 'Designer' ],
#436  => [ 'Philippe Audibert', 'Designer' ],
#416  => [ 'Smythe', 'Designer' ],

 #445  => [ 'ALLDRESSEDUP',  'Designer' ],
 #446  => [ 'Rue du Mail',  'Designer' ],
 #428  => [ 'MM6 by Maison Martin Margiela',  'Designer' ],
 #435  => [ 'Nathan Jendon',  'Designer' ],
 #443  => [ 'Made In Heaven',  'Designer' ],
 #447  => [ 'Castaner',  'Designer' ],
 #448  => [ '3.1 Phillip Lim for Tatami',  'Designer' ],

  #451 => [ 'RayBan Sunglasses',  'Designer' ],
  #450 => [ 'Prada Sunglasses',  'Designer' ],
  #449 => [ 'DOLCE&GABBANA',  'Designer' ],
  #429 => [ 'Mimi Holliday',  'Designer' ],
  #430 => [ 'Myla',  'Designer' ],
  #439 => [ 'Aminika Wilmont',  'Designer' ],
  #364 => [ 'Mawi', 'Designer' ],
  #428 => [ 'MM6 by Maison Martin Margiela', 'Designer' ],
   440 => [ 'Bajra', 'Designer' ],

            );

my %class_id = ( 'Clothing'    => '05',
                 'Accessories' => '01',
         );


# insert into product type
my $qry_pt = "insert into product_type values ( ?, ? )";
my $sth_pt = $dbh->prepare( $qry_pt );


foreach my $id ( keys %category ){

    my $t_id         = sprintf("%03d", $id);
    my ( $name, $class )  = @{ $category{$id} };

    # create url key - repace bad chars
    ( my $url_key = $name ) =~ s/ /-/g;
    $url_key =~ s/&/and/xms;

    # for product cats ( create entry in pt table )
    # $sth_pt->execute( $t_id, $name );
    
    # for product cats ( create category )
    # my $qry_cat = "insert into category values ('TYPE_$t_id', '$name', '', NULL, NULL, NULL, NULL, NULL, NULL , 'T', 0, now(), 'SYSTEM', now(), 'SYSTEM', '$url_key' )";

    # for designer cats
    my $qry_cat = "insert into category values ('DES_$t_id', '$name', '', NULL, NULL, NULL, NULL, NULL, NULL , 'F', 0, now(), 'SYSTEM', now(), 'SYSTEM', '$url_key' )";
    my $sth_cat = $dbh->prepare( $qry_cat );

    # for product cats
    # my $qry_cath = "insert into category_hierarchy values ( 'TYPE_$t_id', 'PRODUCT_CATEGORY', 'CLAS_$class_id{$class} ', NULL, 'F', now(), 'SYSTEM', now(), 'SYSTEM' )";

    # for designer cats
    my $qry_cath1 = "insert into category_hierarchy values ( 'DES_$t_id', 'PRODUCT_CATEGORY', 'WORLD_01', NULL, 'F', now(), 'SYSTEM', now(), 'SYSTEM' )";
    my $qry_cath2 = "insert into category_hierarchy values ( 'CLAS_01', 'PRODUCT_CATEGORY', 'DES_$t_id', 5, 'F', now(), 'SYSTEM', now(), 'SYSTEM' )";
    my $qry_cath3 = "insert into category_hierarchy values ( 'CLAS_02', 'PRODUCT_CATEGORY', 'DES_$t_id', 2, 'F', now(), 'SYSTEM', now(), 'SYSTEM' )";
    my $qry_cath4 = "insert into category_hierarchy values ( 'CLAS_03', 'PRODUCT_CATEGORY', 'DES_$t_id', 3, 'F', now(), 'SYSTEM', now(), 'SYSTEM' )";
    my $qry_cath5 = "insert into category_hierarchy values ( 'CLAS_04', 'PRODUCT_CATEGORY', 'DES_$t_id', 4, 'F', now(), 'SYSTEM', now(), 'SYSTEM' )";
    my $qry_cath6 = "insert into category_hierarchy values ( 'CLAS_05', 'PRODUCT_CATEGORY', 'DES_$t_id', 1, 'F', now(), 'SYSTEM', now(), 'SYSTEM' )";
    my $qry_cath7 = "insert into category_hierarchy values ( 'CLAS_06', 'PRODUCT_CATEGORY', 'DES_$t_id', 3, 'F', now(), 'SYSTEM', now(), 'SYSTEM' )";

    my $sth_cath1 = $dbh->prepare( $qry_cath1 );
    my $sth_cath2 = $dbh->prepare( $qry_cath2 );
    my $sth_cath3 = $dbh->prepare( $qry_cath3 );
    my $sth_cath4 = $dbh->prepare( $qry_cath4 );
    my $sth_cath5 = $dbh->prepare( $qry_cath5 );
    my $sth_cath6 = $dbh->prepare( $qry_cath6 );
    my $sth_cath7 = $dbh->prepare( $qry_cath7 );

    $sth_cat->execute( );
    $sth_cath1->execute();
    $sth_cath2->execute();
    $sth_cath3->execute();
    $sth_cath4->execute();
    $sth_cath5->execute();
    $sth_cath6->execute();
    $sth_cath7->execute();
}
    
$dbh->commit();
$dbh->disconnect();

__END__

