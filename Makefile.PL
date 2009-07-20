use inc::Module::Install;

name     q(MooseX-Barewords);
all_from q(lib/MooseX/Barewords.pm);

requires      q(Moose)            => 0.86;
requires      q(Symbol)           => 0;
requires      q(Variable::Magic)  => 0.36;
test_requires q(Test::More)       => 0;

auto_install;
WriteAll;
