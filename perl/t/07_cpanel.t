#!/usr/bin/env perl;
use strict;
use warnings;
use File::Basename 'dirname';
use Cwd;
use Data::Dumper;

BEGIN {

  $ENV{MOJO_MODE} ||= 'development';

  #$ENV{MOJO_MODE}='production';
  $ENV{MOJO_HOME}    = Cwd::abs_path(dirname(__FILE__) . '/../..');
  $ENV{MOJO_APP}     = 'MYDLjE::ControlPanel';
  $ENV{MYDLjE_ADMIN} = 'admin';
}

use lib ("$ENV{MOJO_HOME}/perl/lib", "$ENV{MOJO_HOME}/perl/site/lib");
use Test::More;
use Test::Mojo;
use MYDLjE::Config;
use MYDLjE::Plugin::DBIx;
use MYDLjE::M::User;

my $config = MYDLjE::Config->new(
  files => [
    $ENV{MOJO_HOME} . '/conf/mydlje.development.yaml',
    $ENV{MOJO_HOME} . '/conf/local.mydlje.development.yaml',
    $ENV{MOJO_HOME} . '/conf/mydlje-controlpanel.development.yaml',
    $ENV{MOJO_HOME} . '/conf/local.mydlje-controlpanel.development.yaml'
  ]
);

#print Dumper();
my $dbix =
  MYDLjE::Plugin::DBIx::dbix($config->stash('plugins')->{'MYDLjE::Plugin::DBIx'});

if (not $config->stash('installed')) {
  plan skip_all => 'System is not installed. Will not test cpanel.';
}
if (not $ENV{MYDLjE_ROOT_URL}) {
  plan(skip_all =>
      'Please set $ENV{MYDLjE_ROOT_URL} to the root url of your installation.');
}
$ENV{MYDLjE_ROOT_URL} =~ m|/$| or do { $ENV{MYDLjE_ROOT_URL} .= '/' };

my $t = Test::Mojo->new();

#Login functionality
#How it looks?
$t->get_ok($ENV{MYDLjE_ROOT_URL} . 'cpanel/loginscreen')->status_is(200)
  ->content_like(qr/guest\@MYDLjE\:\:ControlPanel\@MYDLjE/x)
  ->element_exists('form#login_form')->element_exists('label#login_name_label')
  ->element_exists('input#login_name[type="text"]')
  ->element_exists('label#login_password_label')
  ->element_exists('input#login_password[type="password"]')
  ->element_exists('input#login_password_md5[type="hidden"]')
  ->element_exists('input#session_id[type="hidden"]')
  ->element_exists('button[type="submit"]')

  #Check other hidden form for testing JS
  ->element_exists('form#other_form');
my $dom   = $t->tx->res->dom;
my $style = $dom->at('form#other_form')->attrs->{style};
ok($style =~ m/display\:none;/x, 'form#other_form is hidden');

#Does it seem usable?
like($dom->at('label#login_name_label')->text, qr/User/x, 'Label reads: "User:"');
like($dom->at('label#login_password_label')->text,
  qr/Password/x, 'Label reads: "Password:"');
is($dom->at('button[type="submit"]')->text, 'Login', 'Button reads: "Login"');


#And mainly does it work?
$t->post_form_ok(
  $ENV{MYDLjE_ROOT_URL} . 'cpanel/loginscreen',
  'UTF-8',
  { login_name     => 'admin',
    login_password => 'admin',
  },
)->element_exists('div[class="ui-state-error ui-corner-all"]');
$dom = $t->tx->res->dom;
ok($dom->at('div[class="ui-state-error ui-corner-all"]')->text =~ m/Invalid\ssession/x,
  'Invalid session');
my $user = MYDLjE::M::User->new();

#get the first added user (during setup)
$user->WHERE(
  { disabled => 0,
    -and     => [\['exists(select gid from users_groups where uid=id and gid=1)']]
  }
);
$user->select();
my $login_name = $user->login_name;
$t = Test::Mojo->new();
$t->get_ok($ENV{MYDLjE_ROOT_URL} . 'cpanel/loginscreen');
$dom = $t->tx->res->dom;
my $session_id = $dom->at('#session_id')->attrs->{value};

$t->post_form_ok(
  $ENV{MYDLjE_ROOT_URL} . 'cpanel/loginscreen',
  'UTF-8',
  { login_name => $login_name,

    #login_password => $user->login_password,
    login_password_md5 => Mojo::Util::md5_sum($session_id . $user->login_password),
    session_id         => $session_id
  },
)->status_is(302)->header_like(Location => qr|home|x);

$t->get_ok($ENV{MYDLjE_ROOT_URL} . 'cpanel/home')->status_is(200)
  ->text_like('#title-main-header', qr/$login_name/x, 'admin user logged in')
  ->text_is('#main-left-navigation #site li:nth-of-type(1) a', 'Domains')
  ->text_is('#main-left-navigation #site li:nth-of-type(2) a', 'Pages')
  ->text_is('#main-left-navigation #site li:nth-of-type(3) a', 'Templates')
  ->text_is('#main-left-navigation #site li:nth-of-type(4) a', 'I18N&L10N');

#TODO: continue with post and get for each route

done_testing();
