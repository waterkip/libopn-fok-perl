use Test::More;
use Test::Exception;
use Test::LWP::UserAgent;
use autodie;

use OPN::Fok::UA;
use HTTP::Request;
use HTTP::Response;
use HTML::Entities;

sub open_html_files {
    my $file = shift;
    open my $fh, '<', $file;
    my $contents;
    local $/;
    return <$fh>;
}

my $ua = Test::LWP::UserAgent->new;

my $fok = OPN::Fok::UA->new(ua => $ua,);

subtest request_ok => sub {
    $ua->map_response(
        qr{request_ok},
        HTTP::Response->new(
            '200', 'OK', ['Content-Type' => 'text/html'], "Iets",
        )
    );

    $ua->map_response(
        qr{request_ko},
        HTTP::Response->new(
            '500', 'ERR', ['Content-Type' => 'text/html'], "Iets",
        )
    );

    is($fok->request_ok(
            HTTP::Request->new("GET", 'http://test/request_ok')),
        "Iets", "request_ok");

    throws_ok(
        sub {
            $fok->request_ok(
                HTTP::Request->new("GET", 'http://test/request_ko'));
        },
        qr/Response is not succesful: 500 ERR/,
        "request_ok deals with failure"
    );
};

subtest initial_ssid => sub {
    $ua->map_response(
        qr{user/login},
        HTTP::Response->new(
            '200', 'OK',
            ['Content-Type' => 'text/html'],
            open_html_files('t/inc/html/user_login.html')
        ),
    );
    ok($fok->login(), "Logged in to Fok!");
};

subtest login => sub {
    $ua->map_response(
        qr{user/login},
        HTTP::Response->new(
            '302', 'OK',
            ['Content-Type' => 'text/html'],
            open_html_files('t/inc/html/login_not_logged_in.html')
        ),
    );
    ok($fok->login(), "Logged in to Fok!");
};

subtest parse_index => sub {
    $ua->map_response(
        qr{index/forumindex},
        HTTP::Response->new(
            '200', 'OK',
            ['Content-Type' => 'text/html'],
            open_html_files('t/inc/html/fok.nl.html'),
        ),
    );

    my $data = $fok->parse_forum_index();

    # We are not going to test all the fora, just a few
    is($data->{Community}{url},
        'fok/list_category_topics/2', 'Community URL is correct');

    my $def      = $data->{Community}{fora}{DEF};
    my $contents = {
        last_post => '13-07-2014 13:02',
        long_name => 'Defensie',
        moderator => decode_entities('Pumatje, Cobra4, jitzzzze&nbsp'),
        posts     => '341.295',
        topics    => '2.581',
        url       => 'forum/136',
    };

    is_deeply($def, $contents, "DEF is the same");
};

subtest parse_forum => sub {
    $ua->map_response(
        qr{forum/16},
        HTTP::Response->new(
            '200', 'OK',
            ['Content-Type' => 'text/html'],
            open_html_files('t/inc/html/dig.html'),
        ),
    );

    my $data = $fok->parse_forum("16");

    is_deeply(
        $data->{subfora}{Hardware},
        {
            url        => 'http://forum.fok.nl/rde/list_forumfilter/46',
            topics     => '9.119',
            views      => '185.181',
            last_reply => '13-07-2014 10:21',
        },
        "Hardware subforum show correct information in forum overview"
    );

    # Only testing sticky, the rest is the same
    is_deeply(
        $data->{sticky}{'De DIG huisregels'},
        {
            url      => 'topic/1589228',
            reacties => 3,
            views    => '10.948',
            ts       => {
                username => 'smegmanus',
                profile  => 'user/profile/267547'
            },
            last_reply => {
                date => decode_entities('25-01-2012&nbsp;&nbsp;09:28'),
                url  => 'topic/1589228/1/25#107208740'
            },
            topics => decode_entities('&nbsp'),

        },
        "Sticky huisregels gevonden"
    );
};

#
#subtest parse_filter_index => sub {
#    my $data = $fok->parse_forum();
#
#    is_deeply($data, {}, "Forum index is OK");
#};
#
#subtest parse_active_topics => sub {
#    my $data = $fok->parse_forum();
#
#    is_deeply($data, {}, "Forum index is OK");
#};
#
#subtest parse_my_active_topics => sub {
#    my $data = $fok->parse_forum();
#
#    is_deeply($data, {}, "Forum index is OK");
#};

done_testing;
