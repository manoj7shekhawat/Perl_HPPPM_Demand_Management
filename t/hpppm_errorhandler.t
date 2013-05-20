#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 11;

BEGIN { use_ok('HPPPM::Demand::Management') }
BEGIN { use_ok('HPPPM::ErrorHandler') }

my ( $hpppm, $url, $inputs, $response );

$hpppm  = HPPPM::Demand::Management->new();
$url    = 'http://www.cpan.org';
$inputs = {
    serviceUrl  => ['http://search.cpan.org'],
    requestType => ['MIS'],
    fields      => [ 'REQ.VP.AAMIS_APPLICATION', 'ARTT' ],
};
$response = '<?xml version=\'1.0\' encoding=\'UTF-8\'?><soapenv:Envelope ';
$response .= 'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">';
$response .= '<soapenv:Header /><soapenv:Fault><faultcode>UNKNOWN</faultcode>';
$response .=
  '<faultstring>GUID</faultstring></soapenv:Fault></soapenv:Envelope>';

$hpppm->current_operation("createRequest");

can_ok( $hpppm, 'validate_read_cmdargs' );
can_ok( $hpppm, 'validate_tokens' );
can_ok( $hpppm, 'validate_inputs' );
can_ok( $hpppm, 'check_url_availability' );
can_ok( $hpppm, 'extract' );

is( $hpppm->validate_tokens($inputs), 1, 'Testing validate_tokens' );
is( $hpppm->validate_inputs($inputs), 1, 'Testing validate_inputs' );
is_deeply(
    $hpppm->extract( $response, [ 'faultcode', 'faultstring' ] ),
    { faultcode => 'UNKNOWN', faultstring => 'GUID' },
    'Testing fault extraction'
);
is( $hpppm->check_url_availability($url), 1, 'Testing check_url_availablilty' );

