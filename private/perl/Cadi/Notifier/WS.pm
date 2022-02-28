#!/usr/bin/perl
#
use strict;
use utf8;
use LWP::UserAgent;
use URI;

package Cadi::Notifier::WS;


sub new {
  my ($class, $config) = @_;
  my $self = {
      errmsg => undef,
    wsserver => $config->{wsserver},
      wsport => $config->{wsport},
      wsfile => $config->{wsfile},
     verbose => $config->{verbose},
  };
  bless $self;
}

sub supports {
  my ($self, $event) = @_;
  return 1;
}

sub call {
  my ($self, $event, $args) = @_;

  my $data = $args;

  my $wsserver = $self->{wsserver};
  my $wsport = $self->{wsport};
  my $wsfile = $self->{wsfile};
  return unless $wsserver && $wsport && $wsfile;

  # NB: access is limited by IP on the WS side
  my $ua = LWP::UserAgent->new ();
  $ua->timeout(1);

  my $scheme = $wsport == 80 ? 'http' : 'https';
  my $url = URI->new_abs ($wsfile, "$scheme://$wsserver:$wsport");
  # FIXME: use standard application/x-www-form-urlencoded querystring ?
  # /!\ adapt decoding part in cgi-bin/notify
  # $url->query ($data);
  $url->query (join ('&', map { "$_=" . fixarg ($data->{$_}) } keys %$data));

  my $req = HTTP::Request->new ('GET', $url->as_string);
  warn (scalar localtime, " ".ref($self)."::call info : ".$req->as_string) if $self->{verbose};

  my $response = $ua->request($req);
  if ($response->is_error) {
    $self->{errmsg} = $response->status_line;
    warn (scalar localtime, " ".ref($self)."::call error : ($url, $self->{errmsg})");
  }
}


sub fixarg {
  my $url = shift;
  $url =~ s/ /+/g;
  $url =~ s/([^\w\+\.\-])/sprintf("%%%X",ord($1))/ge;
  return $url;
}


1;
