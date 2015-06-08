#!perl -T

use Test::More tests => 2;

BEGIN {
    use_ok( 'HPPPM::Demand::Management' ) || print "Bail out!\n";
    use_ok( 'HPPPM::ErrorHandler' ) || print "Bail out!\n";
}

diag( "Testing HPPPM::Demand::Management $HPPPM::Demand::Management::VERSION, Perl $], $^X" );
