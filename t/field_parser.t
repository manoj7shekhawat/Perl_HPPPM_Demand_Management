#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2;

BEGIN { use_ok( 'FieldParser', qw(parser) ) }

my ( $fields, $tags, $got, $exp );

$fields =
'"<serviceUrl>" "http://d.com" "</serviceUrl>" "<requestType>" "AIS" "</requestType>"';
$tags = [ 'serviceUrl', 'requestType' ];

$got = FieldParser::parser( $fields, $tags );
$exp = {
    serviceUrl  => ['http://d.com'],
    requestType => ['AIS'],
};

is_deeply( $got, $exp, 'Testing FieldParser' );
