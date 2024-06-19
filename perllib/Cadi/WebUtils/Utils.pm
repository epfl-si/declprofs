#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Utils.pm
# Description:  
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Wed May 25 15:45:03 CEST 2016
# Revision:     
#
##############################################################################
#
#
package Cadi::WebUtils::Utils;
#
use strict;
use utf8;
use LWP::UserAgent;
use Net::SMTP;

use Cadi::Persons;

my @pubsubs = qw(
  init head banner leftmenu tail error success checkdate redirect
  reloadopener printstack prettydate sendmail
);

sub import {
  my $callpkg = caller (0);
  no strict 'refs';
  foreach my $sub (@pubsubs) {
    *{$callpkg."::$sub"} = \&$sub;
  }
  use strict 'refs';
  return;
}

sub init {
  my $req = shift;
}

sub head {
  my $req = shift;
  return if $req->{headdone};
  binmode STDOUT, ":utf8";
  if ($req->{command} eq 'exportmenu') {
    exportmenu ($req);
    quit ($req);
  }

  my $doctype1 = qq{<!DOCTYPE HTML PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" }.
                 qq{"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">};

  my $doctype2 = qq{<!DOCTYPE HTML PUBLIC "-//W3C//DTD XHTML 1.1//EN" }.
                 qq{"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">};

  my $doctype3 = qq{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" }.
                 qq{"http://www.w3.org/TR/html4/loose.dtd">};
  my $doctype4 = qq{<!DOCTYPE html>};
  
  if ($req->{modifiers}->{embedded}) {
    print qq{Expires: -1\n};
    print qq{Content-type: text/html;charset=utf-8\n};
    return;
  }
  
  my $title = $req->{title} || 'Some title';
  print qq{Content-type: text/html;charset=utf-8\n\n};
  print qq{$doctype4\n};

  my $appname = $req->{appname} || 'someapp';
  print qq{
    <html>
      <head>
        <meta http-equiv="Set-Cookie" content="${appname}_lang=$req->{language}; path=/"/> 
        <meta http-equiv="X-UA-Compatible" content="IE=edge" />
        <link rel="stylesheet" type="text/css" href="https://www.epfl.ch/css/epfl.css"/>
        <link rel="stylesheet" type="text/css" href="/styles/webutils.css">
        <link rel="stylesheet" type="text/css" href="/styles/mytree.css">
  };
  if ($req->{css} && @{$req->{css}}) {
    foreach my $css (@{$req->{css}}) {
      print qq{<link rel="stylesheet" type="text/css" href="$css">\n}
    }
  }
  print qq{
        <script type="text/javascript" src="/js/webutils.js" charset="UTF-8"></script>
        <script type="text/javascript" src="//www.epfl.ch/js/jquery-epfl.min.js"></script>
        <script type="text/javascript">jQuery.noConflict();</script>
        <script src="https://www.epfl.ch/js/globalnav.js" type="text/javascript"></script>
  };
  if ($req->{js} && @{$req->{js}}) {
    foreach my $js (@{$req->{js}}) {
      print qq{<script type="text/javascript" src="$js"></script>\n};
    }
  }
  print qq{
        <title> $title </title> 
  };
  my $bgcolor = 'white'; # $req->{test} ? 'lightblue' : 'white';
  print qq{
      </head>
      <body style="background-color: $bgcolor;">
        <script>
          //inithistory ();
        </script>
  };
  $req->{headdone} = 1;
}

sub tail {
  my $req = shift;
  return if $req->{redirect};
  quit () if $req->{modifiers}->{embedded};
  print qq{
    <script> alert ('$req->{msg}'); </script>
  } if $req->{msg};
  print qq{
        </div>
      </body>
    </html>
  };
  quit ();
}

sub error {
  my ($req, $msg) = @_;
  head ($req) unless $req->{headdone};
  if ($req->{modifiers}->{embedded}) {
    print qq{X-HTTP-Target: error\n\n};
    print msg('Error'), ' : ',$msg, "\n";
  } else {
    print '<h3>', msg('Error'), ' : ', $msg, "</h3>\n";
  }
  quit ();
}

sub msg {
  my $msgcode = shift;
  return $msgcode;
}

sub banner {
  my     $req = shift;
  my      $me = $req->{me};
  my      $su = $req->{su};
  my     $now = $req->{now};
  my    $args = $req->{args};
  my  $userid = $req->{userid};
  my  $cgidir = $req->{cgidir};
  my $dateref = $req->{dateref};
  return if $req->{modifiers}->{embedded};

  my $ladate;
  if ($now) {
    my ($jref, $mref, $aref) = (localtime ())[3..5];
    $mref++; $aref += 1900;
    $ladate = sprintf ("%02d/%02d/%04d", $jref, $mref, $aref);
    $ladate = msg('Today');
  } else {
    my ($aref, $mref, $jref) = ($dateref =~ /^(\d*)-(\d*)-(\d*).*$/);
    $ladate = sprintf ("%02d/%02d/%04d", $jref, $mref, $aref);
  }
  
  my $lang = $req->{language} || 'fr';
  my $header = wget ("https://www.epfl.ch/templates/fragments/header.$lang.html");
  $header =~ s/http:\/\/search.epfl.ch\//https:\/\/search.epfl.ch\//g;

  print qq{$header};
  my $langtitle = ($lang eq 'fr') ? 'Language choice' : 'Choix de la langue';
  my $current = ($lang eq 'fr')
    ? qq{
        <li class="nav-item">
          <span class="visuallyhidden-xxs visuallyhidden-xs"> français </span>
        </li>
      }
    : qq{
        <li class="nav-item">
          <span class="visuallyhidden-xxs visuallyhidden-xs"> English  </span>
        </li>
      }
    ;
  my $other = ($lang eq 'fr')
    ? qq{
        <li class="nav-item nav-item-active pointerlink">
          <a onclick="setlang ('en');">
            <span class="visuallyhidden-xxs visuallyhidden-xs"> English  </span>
          </a>
        </li>
      }
    : qq{
        <li class="nav-item nav-item-active pointerlink">
          <a onclick="setlang ('fr');">
            <span class="visuallyhidden-xxs visuallyhidden-xs"> français </span>
          </a>
        </li>
      }
    ;

  print qq{
    <div style="width: 100%; height: 20px; margin-top: -30px; position: absolute;">
      <div style="width: 1120px; height: 20px; margin: auto;">
        <script>
          function setlang (lang) {
            document.cookie = "$req->{appname}_lang=" + lang + "; path=/";
            window.location.reload ();
          }
        </script>
        <ul class="nav-list" id="languages" title="$langtitle">
          $current
          $other
        </ul>
        <div style="clear:both"></div>
      </div>
    </div>
  };

  my $Persons = new Cadi::Persons ();
  my  $user = $Persons->getPerson ($userid);
  my $uname = "$user->{firstname} $user->{name}";
  my $super = '';
  if ($req->{modifiers}->{resetspoof}) {
    my $cookie = "$req->{appname}::userid=; expires=Thu, 01-Jan-70 00:00:01 GMT; path=/";
    print qq{
      <script language="javascript">
        document.cookie = '$cookie';
        document.location.href = '$cgidir/main.pl';
      </script>
    };
  }
  my $resetspoof;
  if ($req->{realuserid} && ($req->{realuserid} != $userid)) {
    $resetspoof = qq{
      (<a class="pointerlink" onclick="resetspoof ();">}. msg('BecomeMyselfAgain') . qq{</a>)
    };
  }

  if ($req->{su}) {
    $uname .= qq{<a onclick="spoof ();"> [Spoof] </a>};
  }
  print qq{
    <div style="position: absolute; width: 100%; margin: auto; height: 30px;">
      <table style="
                width: 1120px;
               height: 100%;
               margin: auto;
           margin-top: -10px;
               border: 0;">
        <tr style="background-color: #EEEEFF; color: black">
          <th style="text-align: left; width:300px;">
            $uname $super $resetspoof
          </th>
  };
  print qq{
          <th>
            <b>$req->{pagetitle}</b>
          </th>
  } if $req->{pagetitle};
  print qq{
          </tr>
        </table>
      </div>
  };
  my $bgcolor = 'white'; # $req->{test} ? 'lightblue' : 'white';
  print qq{<div id="main-content" style="background-color: $bgcolor;">\n};
}

sub leftmenu {
  my ($req, $tree) = @_;
  return if $req->{modifiers}->{embedded};
  unless ($req->{modifiers}->{noleftmenu}) {
    my $bgcolor = 'white'; # $req->{test} ? 'lightblue' : 'white';
    print qq{
      <div id="leftmenu" class="left">
        <table style="border: 0; height: 100%; margin: 0; background-color: $bgcolor;">
          <tr>
            <td style="vertical-align: top; border: 0;" id="treeroot">
    };
    tree ($req, $tree);
    print qq{
            </td>
          </tr>
        </table>
      </div>
      <script>
        var leftmenu = document.getElementById ('leftmenu');
        window.onscroll = fixleftmenu;
      </script>
    };
  }
  print qq{
    <div id="leftnavigbutton" class="navigbutton"
         onclick="back ();"></div>
    <div id="rightnavigbutton" class="navigbutton"
         onclick="forward ();"></div>
    <div id="reloadbutton" class="navigbutton"
         onclick="reload ();"></div>

    <div id="result-content" class="goright" style="width: 950px;">
      <section class="container">
        <div id="datapage"></div>
      </section>
  };
}

sub tree {
  my ($req, $tree) = @_;
  dobranch ($tree);
  if ($tree->{subtree}) {
    print qq{
      <span class="branch" style="display: block;" id="branch$tree->{id}">
    };
    foreach my $subtree (@{$tree->{subtree}}) {
      tree ($req, $subtree);
    }
    print qq{
      </span>
    };
  }
}

sub dobranch {
  my $branch = shift;
  my     $id = $branch->{id};
  my   $name = $branch->{name};
  my $expand = $branch->{expand};
  my   $icon = $branch->{icon};
  my   $view = $branch->{view};
  my $opened = $branch->{opened};

  my  $style  = qq{style="background-color:#003366;color:#FFFFFF";};
  my $expicon = $expand
    ? ($opened ? '/images/minus.gif' : '/images/plus.gif')
    : '/images/tee.gif';
  my $onclick = $expand
    ? qq{onclick="swapBranch('$id');"}
    : '';

  print qq{
      <div class="trigger" id="div$id">
        <img src="$expicon" $onclick
             border="0"
             vertical-align="middle"
             id="folder$id">
  };
  print qq{
        <img src="$icon"
             border="0"
             vertical-align="middle"
             style="width: 16px; margin: 0;">
  } if $icon;
  print qq{
        <a onclick="$view" title="$name" style="vertical-align: baseline;">
          $name
        </a>
      </div>
  };
}

sub maininit {
  my $req = shift;
  return if $req->{modifiers}->{embedded};
  return if $req->{modifiers}->{noleftmenu};
  print qq{
    <div id="result-content" class="goright">
      <section class="container">
        <div id="datapage"></div>
      </section>
  };
}

sub quit {
  my $req = shift;
  exit (); 
  $! = 0;
  die "OK.";
}

sub seterror {
  my ($req, $msg) = @_;
  $req->{msg} = $msg;
}

sub setmsg {
  my ($req, $msg) = @_;
  $req->{msg} = $msg;
}

sub preamble {
  my $req = shift;
  my $msg = $req->{msg};
  print qq{
    <script> alert ('$msg'); </script>
  } if $req->{msg};
}

sub wget {
  my $url = shift;
  my $lwp = new LWP::UserAgent;
  $lwp->timeout(2);
  my $req = new HTTP::Request ('GET', $url);
  my $res = $lwp->request ($req);
  return $res->decoded_content if ($res->code == 200);
  return "<h1> Unable to fetch Web2010 header. </h1>";
}

sub errorlog {
  my ($req, $i) = 0;
  my $stack = "@_ from $req->{client}, stack = \n";
  while (my ($pack, $file, $line, $subname, $hasargs, $wanrarray) = caller ($i++)) {
    $stack .= "$file:$line\n";
  }
  my $now = scalar localtime;
  warn "[$now] [$req->{appname} warning] : $stack\n";
}

sub checkdate {
  my ($j, $m, $a) = @_;
  my @monthslen = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
  $monthslen [1] += 1 if (($a % 4) == 0);

  error ("Date invalide : $j/$m/$a")
    if (($j !~ /^\d+$/) || ($m !~ /^\d+$/) || ($a !~ /^\d+$/)
    );

  error ("Date invalide : $j/$m/$a")
    if (($a < 2000) || ($m < 1) || ($m > 12) ||
        ($j < 1) || ($j > $monthslen [$m-1])
    );
}

sub fixcase {
  my $string = shift;
  $string =~ tr/A-Z/a-z/;
  if ($string =~ /^(.*)([- ]+)(.*)$/) {
    my ($a, $b, $c) = ($1, $2, $3);
    $string = fixcase ($a) . $b . fixcase ($c);
  } else {
    $string = ucfirst $string
      unless ($string =~ /^(a|au|des|de|du|en|et|zur|le|la|les|sur|von|la)$/);
  }
  return $string;
}

sub setopenerurl {
  my $url = shift;
  print qq{
    <script>
      opener.location.href = '$url';
      window.close ();
    </script>
  };
}

sub reloadopener {
  print qq{X-HTTP-Target: none\n\n};
  print qq{
    <script>
      closepopup ();  
      reload ();
    </script>
  };
  quit ();
}

sub success {
  my ($req, $msg) = @_;
  print qq{X-HTTP-Target: popup\n\n};
  print qq{
    <h3> $msg </h3>
    <p style="text-align: center;">
      <input type="button" value="}.msg('OK').qq{" onclick="reload ();">
    </p>
  };
  quit;
}

sub closepopup {
  print qq{
    <script>
      closepopup ();  
    </script>
  };
}

sub redirect {
  my $url = shift;
  print qq{X-HTTP-Target: none\n\n};
  print qq{
    <script language="javascript">
      closepopup (); 
      loadcontent ('$url', 'load');
    </script>
  };
}

sub printstack {
  my $depth = 0;
  while (my ($package, $filename, $line) = caller ($depth++)) {
    warn "$filename : $package line $line.\n";
  }
}

sub sendmail {
  my ($to, $subject, $body) = @_;
  my $smtp = Net::SMTP->new ('mail.epfl.ch',
    Timeout => 60, 
      Debug => 0,
  );
  my $from = 'someapp@epfl.ch';
  my $data = "To: $to\n".
             "From: $from\n".
             "Reply-to: 1234\@epfl.ch\n".
             "Subject: $subject\n".
             "Content-Type: text/html; charset=utf-8\n".
             "\n".
             "$body\n";
  $smtp->mail ($from) or do {
    warn "InternalWorkflow: Fails to set from value to email.\n"; 
    return;
  };
  $smtp->to   ($to)   or do {
    warn "InternalWorkflow: Fails to set to value to email.\n"; 
    return;
  };
  $smtp->data ($data) or do {
    warn "InternalWorkflow: Fails to set data value to email.\n"; 
    return;
  };
  $smtp->quit;
}

sub sendmail_sendmail {
  my ($to, $subject, $body) = @_;
  $to = 'claude.lecommandeur@epfl.ch';
  local (*STDOUT); close (STDOUT);
  open (MAIL, "|/usr/sbin/sendmail $to 2>&1 > /dev/null") ||
    error (undef, "Unable to send email to $to.");
  binmode (MAIL, ':utf8');
  print MAIL
    "Subject: $subject.\n",
    $body
    ;
  close (MAIL);
}

sub sendmailcore {
  my ($to, $subject, $body) = @_;
  $to = 'claude.lecommandeur@epfl.ch';
  local (*STDOUT); close (STDOUT);
  CORE::open (MAIL, "|/usr/sbin/sendmail $to 2>&1 > /dev/null") ||
    error (undef, "Unable to send email to $to.");
  CORE::binmode (MAIL, ':utf8');
  CORE::print MAIL
    "Subject: $subject.\n",
    $body
    ;
  CORE::close (MAIL);
}


1;
