#!/usr/bin/env perl

use OPN::Fok::UA;
use OPN::Fok::RSS;
use OPN::Fok::Topic;

my $ua = OPN::Fok::UA->new();
my $rss = OPN::Fok::RSS->new();

my @topics = $ua->get_topics();
$rss->generate_feed(@topics);

