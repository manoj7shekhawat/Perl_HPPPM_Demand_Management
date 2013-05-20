#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 11;

BEGIN { use_ok('HPPPM::Demand::Management') }

my ( $hpppm, @inps, $fields, $tags, $inputs, $req );

$hpppm  = HPPPM::Demand::Management->new();
$inputs = {
    serviceUrl  => ['http://search.cpan.org'],
    requestType => ['MIS'],
    fields      => [ 'REQ.VP.MIS_APPLICATION', 'ARTT' ],
};

$hpppm->current_operation('createRequest');
$hpppm->user('user');
$hpppm->password('password');

can_ok( $hpppm, 'create_request' );
can_ok( $hpppm, 'post_request' );
can_ok( $hpppm, 'get_inputs' );
can_ok( $hpppm, 'get_reqd_inputs' );
can_ok( $hpppm, 'get_current_oper' );
can_ok( $hpppm, 'get_supported_ops' );

#$fields = $hpppm->validate_read_cmdargs(@inps);
$req = $hpppm->create_request($inputs);

like( $req, qr/MIS/,      'Testing create_request PASS 1...' );
like( $req, qr/ARTT/,     'Testing create_request PASS 2..' );
like( $req, qr/user/,     'Testing create_request PASS 3.' );
like( $req, qr/password/, 'Testing create_request PASS 4' );

