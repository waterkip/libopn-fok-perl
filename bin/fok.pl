#!/usr/bin/perl
use warnings;
use strict;

use OPN::Fok::UA;
use Data::Dumper;

# TODO: Fix a general appconfig::opn subclass
use AppConfig;

use Getopt::Long;
use Pod::Usage;

my $config = AppConfig->new(
    { CASE => 1, CREATE => 1 }, qw(
        url=s
        username=s
        password=s
        type=s
        list-types

        help
        )
);

#my $cf = '/opt/fokrss/fokrss.conf.conf';
my $cf = './etc/fokrss.conf';

$config->file($cf);
$config->getopt(\@ARGV);

pod2usage(0) if $config->get('help');

foreach (qw(type username password)) {
    if (!defined $config->$_) {
        warn "$_ is not defined";
        pod2usage(1);
    }
}

my $fok = OPN::Fok::UA->new(
    username => $config->username,
    password => $config->password,
    url      => $config->url,
);

my $method = $config->type;
# TODO: Check if the method is in types-list.

if (!$fok->can($method)) {
    die "Unable to perform $method";
}

my $x = $fok->login;

die Dumper $x;

$fok->$method;

__END__

=head1 NAME

fok.pl - A command line tool to parse forum.fok.nl

=head1 SYNOPSIS

fok.pl --help [ OPTIONS ]

=head1 OPTIONS

=over

=item * --help (this help)

=item * --username

=item * --password

=item * --type

What you want to convert to RSS, see L</--list-types> for more info.

=item * --list-types

List the calls you can make with this tool

=back

=head1 AUTHOR

Wesley Schwengle

=head1 LICENSE and COPYRIGHT

Wesley Schwengle, 2009-1014.
