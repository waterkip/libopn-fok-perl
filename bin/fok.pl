#!/usr/bin/env perl
#
use strict;
use warnings;
use Data::Dumper;

use FokUA;
use FokTopic;
use CGI qw(:all);
use CGI::Cache;
use CGI::Carp qw(fatalsToBrowser);



my $cachedir = "/tmp/foktest";
# disable when testing
#$cachedir = "/tmp/CGI_Cache";

my $fok = FokUA->new("$cachedir/opfokrss.jar");
$fok->set_user("credit--");
$fok->set_pass("g49euXvVzSI");


my $cgi = CGI->new();

CGI::Cache::setup(
    {
        cache_options => {
            cache_root         => $cachedir,
            namespace          => 'demo_cgi',
            directory_umask    => 007,
            max_size           => 20 * 1024 * 1024,
            default_expires_in => '5 minutes',
        }
    }
);

my $mode = $cgi->param('mode') || 'xml';

my $type = $cgi->param('type');
my $id   = $cgi->param('id');
CGI::Cache::set_key( $cgi->Vars );
CGI::Cache::invalidate_cache_entry()
  if $cgi->param('force') eq 'true' || $cgi->param('mode');
CGI::Cache::start() or exit;

CGI::Cache::pause();

#print Dumper $fok;
CGI::Cache::continue();

print $cgi->header( -type => "text/$mode", -charset => 'utf-8' );
print get_topics($fok, $type, $id);
print "\n";
CGI::Cache::stop();

