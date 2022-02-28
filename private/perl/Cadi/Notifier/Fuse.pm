#!/usr/bin/perl
#
use strict;
use utf8;
use LWP::UserAgent;
use JSON qw//; # avoid Prototype mismatch: sub [...]::from_json: none vs ($@)
use URI;
use Cwd;
use File::Basename;

use Cadi::Groups;
use Cadi::Services;
use Cadi::Accounts;

package Cadi::Notifier::Fuse;


# sample config, overwritten with the content of config.json
my $configs = {
  prod => {
    fuse => {
      url => 'https://api.epfl.ch/events/v1/',
      user => 'accred',
      pwd => '...',
    }
  },
  test => {
    fuse => {
      url => 'https://api-test.epfl.ch/events/v1/',
      user => 'accred',
      pwd => '...',
    }
  },
  dev => {
    fuse => {
      url => 'https://fuse-dev/events/v1/',
      user => 'accred',
      pwd => '...',
    }
  },
};

my $notifier_dir = File::Basename::dirname(Cwd::abs_path(__FILE__));
$configs = _slurp_utf8_json($notifier_dir."/config.json");

sub new {
  my ($class, $config) = @_;
  my $self = {
     errmsg => undef,
    verbose => $config->{verbose},
  };

  $self->{Groups} = Cadi::Groups->new (
      caller => '000000',
    readonly => 1,
        utf8 => 1,
  );

  $self->{Services} = Cadi::Services->new (
      caller => '000000',
    readonly => 1,
        utf8 => 1,
  );

  $self->{Accounts} = Cadi::Accounts->new (
      caller => '000000',
    readonly => 1,
        utf8 => 1,
  );

  my $env = $config->{execmode} or die ("execmode is not defined");
  $self->{fuseurl} = $configs->{$env}->{fuse}->{url} or die ("Fuse url is not defined for env $env");
  $self->{fuseuser} = $configs->{$env}->{fuse}->{user} or die ("Fuse user is not defined for env $env");
  $self->{fusepassword} = $configs->{$env}->{fuse}->{pwd} or die ("Fuse password is not defined for env $env");

  bless $self;
}

sub supports {
  my ($class, $event) = @_;
  return $class->can ($event);
}

sub call {
  my ($self, $event, $args) = @_;
  my $fuseurl = $self->{fuseurl};
  my $fuseuser = $self->{fuseuser};
  my $fusepassword = $self->{fusepassword};

  my ($method, $url, $data) = $self->$event ($args);

  $url = URI->new_abs ($url, $fuseurl);

  my $ua = LWP::UserAgent->new ();
  $ua->credentials ($url->host.":".$url->port, '', $fuseuser, $fusepassword);
  $ua->timeout(1);

  my $req = HTTP::Request->new ($method, $url->as_string);
  if (Encode::is_utf8($data, 1)) {
    $req->content_type ('application/json; charset=utf-8');
    $data = Encode::encode('utf8', $data);
  } else {
    $req->content_type ('application/json');
  }
  $req->content ($data) if $data;
  warn (scalar localtime, " ".ref($self)."::call info : ".$req->as_string) if $self->{verbose};

  my $response = $ua->request($req);
  if ($response->is_error) {
    $self->{errmsg} = $response->status_line;
    warn (scalar localtime, " ".ref($self)."::call error : ($url, $self->{errmsg})");
  }
}

sub _json_bool {
  my ($condition) = @_;
  #if ($condition eq 'y') {
  #  return JSON::true;
  #} elsif ($condition eq 'n') {
  #  return JSON::false;
  #}
  return $condition ? JSON::true : JSON::false;
}

### Groups

sub _serialize_group {
  my ($group) = @_;
  my $json = JSON->new;
  my $data = $json->encode(
    {
                id => "$group->{id}",
              name => "$group->{name}",
             owner => "$group->{owner}",
       description => "$group->{description}",
               url => "$group->{url}",
            access => "$group->{access}",
      registration => "$group->{registration}",
           visible => _json_bool($group->{visible}),
          maillist => $group->{maillist} ? $group->{name}.'@groupes.epfl.ch' : '',
          visilist => _json_bool($group->{visilist}),
            public => _json_bool($group->{public}),
              ldap => _json_bool($group->{ldap}),
               gid => "$group->{gid}",
          creation => $group->{creation}
    }
  );
  return $data;
}

sub creategroup {
  my ($self, $args) = @_;
  my $url  = "groups";
  my $group = $self->{Groups}->getGroup($args->{id});
  my $data = _serialize_group($group);
  return ('POST', $url, $data);
}

sub removegroup {
  my ($self, $args) = @_;
  my $url = "groups/$args->{id}";
  return ('DELETE', $url, undef);
}

sub modifygroup {
  my ($self, $args) = @_;
  my $url = "groups/$args->{id}";

  my $group = $self->{Groups}->getGroup($args->{id});
  my $data = _serialize_group($group);

  return ('PUT', $url, $data);
}

sub setgroupmembers {
  my ($self, $args)  = @_;
  my $url     = "groups/$args->{id}/members";

  my $group = $self->{Groups}->getGroup($args->{id});
  my $members = [map { $_->{id} } @{$group->{persons}}];

  my $json = JSON->new;
  my $data = $json->encode($members);
  return ('PUT', $url, $data);
}

sub renamegroup {
  my ($self, $args) = @_;
  return $self->modifygroup ($args);
}

### Services

sub _serialize_service {
  my ($service) = @_;
  my $external_id = sprintf("M%05d", $service->{id});
  my $json = JSON->new;
  my $data = $json->encode(
    {
               id => $external_id,
             name => "$service->{name}",
            label => "$service->{label}",
            owner => "$service->{owner}",
           unitid => "$service->{unit}",
      description => "$service->{description}",
          tequila => _json_bool($service->{tequila}),
             ldap => _json_bool($service->{ldap}),
               ad => _json_bool($service->{ad}),
           radius => _json_bool($service->{radius}),
              sco => _json_bool($service->{sco}),
              uid => "$service->{uid}",
              gid => "$service->{gid}",
            email => ($service->{email} eq 'Exchange') ? "$service->{name}\@epfl.ch" : "$service->{email}",
      camiprorfid => "$service->{camiprorfid}",
         creation => $service->{creation}
    }
  );
  return $data;
}

sub addservice {
  my ($self, $args) = @_;
  my $url  = "serviceaccounts";
  my $service = $self->{Services}->getService($args->{id});
  my $data = _serialize_service($service);
  return ('POST', $url, $data);
}

sub updateservice {
  my ($self, $args) = @_;
  my $external_id = sprintf("M%05d", $args->{id});
  my $url = "serviceaccounts/$external_id";
  my $service = $self->{Services}->getService($args->{id});
  my $data = _serialize_service($service);
  return ('PUT', $url, $data);
}

sub removeservice {
  my ($self, $args) = @_;
  my $external_id = sprintf("M%05d", $args->{id});
  my $url = "serviceaccounts/$external_id";
  return ('DELETE', $url, undef);
}

### Accounts

sub _serialize_account {
  my ($account) = @_;
  my $json = JSON->new;
  my $data = $json->encode(
    # because we're doing PATCHes on persons/
    { "account" => $account ?
      {
        user   => "$account->{user}",
        uid    => "$account->{uid}",
        gid    => "$account->{gid}",
        gecos  => "$account->{gecos}",
        home   => "$account->{home}",
        shell  => "$account->{shell}",
        # TODO: automaps ? or in separate event ?
      }
      :
      undef
    }
  );
  return $data;
}

sub addaccount {
  my ($self, $args) = @_;
  my $url = "persons/$args->{sciper}";
  my $account = $self->{Accounts}->getAccount($args->{sciper});
  my $data = _serialize_account($account);
  return ('PATCH', $url, $data);
}

sub changeaccount {
  my ($self, $args) = @_;
  my $url = "persons/$args->{sciper}";
  my $account = $self->{Accounts}->getAccount($args->{sciper});
  my $data = _serialize_account($account);
  return ('PATCH', $url, $data);
}

sub removeaccount {
  my ($self, $args) = @_;
  my $url = "persons/$args->{sciper}";
  my $data = _serialize_account(undef);
  return ('PATCH', $url, $data);
}

### utils

sub _slurp_utf8_text {
  my $filename = shift;
  my $text = do {
   open(my $fh, "<:encoding(UTF-8)", $filename)
      or die("Can't open \"$filename\": $!\n");
   local $/; # slurp
   <$fh>
  };
  return $text;
}

sub _slurp_utf8_json {
  my $filename = shift;
  my $json_text = _slurp_utf8_text($filename);
  my $json = JSON->new();
  return $json->decode ($json_text);
}


1;
