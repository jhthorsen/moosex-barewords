use inc::Module::Install;

name     q(MooseX-MagicVar);
all_from q(lib/MooseX/MagicVar.pm);

requires      q(Moose)            => 0;
test_requires q(Test::More)       => 0;

auto_install;
WriteAll;
