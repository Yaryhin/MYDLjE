package MYDLjE::ControlPanel::C::Accounts;
use Mojo::Base 'MYDLjE::ControlPanel::C';
use Mojo::ByteStream qw(b);
use Time::Piece;
use Time::Seconds;

sub users {
  my $c = shift;
  $c->stash(form  => {@{$c->req->params->params}});
  $c->stash(users => $c->get_users());
  $c->stash(now   => time);
  return;
}

#Generates and executes an SQL query for selecting suers from db.
#The where qlause is generated from the form.
#returns an array of MYDLjE::M::User objects.
sub get_users {
  my $c     = shift;
  my $form  = $c->stash('form');
  my $where = {};
  if ($form->{field}) {
    $where->{$form->{field}} = {-like => $form->{like}};
  }
  my $users = [];
  my ($sql, @bind) =
    $c->dbix->abstract->select(MYDLjE::M::User->TABLE, MYDLjE::M::User->COLUMNS,
    $where);
  $sql .= $c->sql_limit($form->{offset}, $form->{rows});
  foreach my $user (@{$c->dbix->query($sql, @bind)->hashes}) {
    push @$users, $user;
  }
  return $users;
}

sub edit_user {
  my $c = shift;
  my $u_form = MYDLjE::M::User->select(id => $c->stash->{id})->data;
  if (not $u_form) {
    $c->stash(id => 0);
    $u_form = {};
  }
  ($u_form->{created_by_username}, $u_form->{changed_by_username}) =
    $c->dbix->select(MYDLjE::M::User->TABLE, 'login_name',
    {id => {-in => [$u_form->{created_by}, $u_form->{changed_by}]}})->list;

  #primary_group is disabled and only shown
  #It is always the same as the login_name
  $c->stash(
    form => {
      %$u_form,
      primary_group => $u_form->{login_name},
      reg_tstamp_formated =>
        localtime($u_form->{reg_tstamp})
        ->strftime($c->app->config('date_timeseconds_format')),
      tstamp_formated =>
        localtime($u_form->{tstamp})
        ->strftime($c->app->config('date_timeseconds_format')),
      start => $u_form->{start}
      ? localtime($u_form->{start})->strftime($c->app->config('date_format'))
      : '',
      stop => $u_form->{stop}
      ? localtime($u_form->{stop})->strftime($c->app->config('date_format'))
      : '',
    }
  );
  return;
}

sub settings {
  my $c = shift;

#$c->render();
  return;
}


1;

