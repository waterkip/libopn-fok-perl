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
        id=s
        list-types

        help
        )
);

#my $cf = '/opt/fokrss/fokrss.conf.conf';
my $cf = './etc/fokrss.conf';

$config->file($cf);
$config->getopt(\@ARGV);

pod2usage(0) if $config->get('help');

foreach (qw(username password)) {
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

if ($config->get('list-types')) {
    print "You can use the following types: $/";

    my @types = @{$fok->types};
    foreach (@types) {
        print "*\t$_", $/;
    }
}
elsif (my $method = $config->type) {
    $method = "parse_$method";

    if (!$fok->can($method)) {
        die "Unable to perform $method";
    }

    # Fucking cookie wall
    # <input type="hidden" name="token" value="02ee2897184d45edbf09fc4c5cd7b143">
    # <input type="hidden" name="allowcookies" value="ACCEPTEER ALLE COOKIES">
    $fok->cookie_wall_ok();

    my $x = $fok->login;
    #die Dumper $x;

    my $res = $fok->$method($config->id);
    print STDERR Dumper $res;
}



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
