#!/usr/bin/perl

use strict;
use warnings;
use lib qw(./lib);
use PJP;
use Module::Find qw/useall/;
useall 'PJP::M';

my $pjp	       = PJP->bootstrap;
my $config     = $pjp->config;
my $mode_name  = $pjp->mode_name || 'development';

my $assets_dir = $config->{'assets_dir'} || die "no assets_dir setting in config/" . $mode_name . '.pl';
my $code_dir   = $config->{'code_dir'}   || die "no code_dir setting in config/"   . $mode_name . '.pl';
my $perl       = $config->{perl} || 'perl -Ilib';
my($sqlite_db) = $config->{DB}->[0] =~m{dbname=(.+)$};

foreach my $db_type (qw/master_db slave_db/) {
    if ( not -e $config->{$db_type} ) {
        die "prepare database at first. not found database: " . $config->{$db_type};
    }
}

if (! -d $assets_dir) {
    mkdir $assets_dir;
}

if (! -d $assets_dir . '/perldoc.jp/') {

    mkdir $assets_dir . '/perldoc.jp/';
    system(<<_SHELL_);
cd $assets_dir/perldoc.jp;
cvs -d:pserver:anonymous\@cvs.sourceforge.jp:/cvsroot/perldocjp login;
cvs -z3 -d:pserver:anonymous\@cvs.sourceforge.jp:/cvsroot/perldocjp co docs;
_SHELL_

} else {
    system(qq{cd $assets_dir/perldoc.jp/docs/; cvs up -dP});
}

if (! -d $assets_dir . '/module-pod-jp/') {
    system(qq{git clone git://github.com/perldoc-jp/module-pod-jp.git $assets_dir/module-pod-jp/});
}

system(qq{cd $assets_dir/module-pod-jp; git pull origin master});

foreach my $jpa_module (qw/MooseX-Getopt-Doc-JA  Moose-Doc-JA/) {
    if (! -d $assets_dir . "/$jpa_module/") {
	system(qq{cd $assets_dir; git clone git://github.com/jpa/$jpa_module.git});
    }

    system(qq{cd $assets_dir/$jpa_module; git pull origin master});
}

unlink "$assets_dir/index-module.pl";
unlink "$assets_dir/index-article.pl";

chdir $code_dir;
if (! -e $sqlite_db) {
    system(qq{sqlite3 $sqlite_db < ./sql/sqlite.sql});
}

my $t = time;
PJP::M::Index::Article->generate_and_save($pjp);
PJP::M::Index::Module->generate_and_save($pjp);
PJP::M::BuiltinFunction->generate($pjp);
PJP::M::BuiltinVariable->generate($pjp);
PJP::M::PodFile->generate($pjp);

if ($config->{master_db} and -e $config->{master_db} and $config->{slave_db}) {
  system('cp ' . $config->{master_db} . ' ' . $config->{slave_db});
}

print $mode_name, "\n";
