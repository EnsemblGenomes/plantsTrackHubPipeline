
use Test::More;
use Test::File;
use Test::Exception;
#use Devel::Cover;

use FindBin;
use lib $FindBin::Bin . '/../modules';

# -----
# checks if the module can load
# -----

#test1
use_ok(EGPlantTHs::SuperTrack);  # it checks if it can use the module correctly


# -----
# test constructor
# -----

my $st_obj=EGPlantTHs::SuperTrack->new("SRP045759","long label here","metadata here");

# test2
isa_ok($st_obj,'SuperTrack','checks whether the object constructed is of my class type');


# test3
dies_ok(sub{EGPlantTHs::SuperTrack->new("blabla")},'checks if wrong object construction of my class dies');


# -----
# test print_track_stanza method
# -----
my $test_file = "./test_file";

open(my $fh, '>', $test_file)
 or die "Error in ".__FILE__." line ".__LINE__." Could not open file \.\/test_file!\n";

$st_obj->print_track_stanza($fh); 

close($fh);

#test4
file_exists_ok(($test_file),"Check if the file I wrote exists");

#test5     
file_readable_ok($test_file,"Checks if the file is readable");

#test6
file_not_empty_ok($test_file,"Checks if the file is not empty");

#test7
open(IN, $test_file) or die "Can't open $test_file.\n";

my @file_lines=<IN>;

my $string_content=join("",@file_lines);

is($string_content, "track SRP045759\nsuperTrack on show\nshortLabel BioSample:SRP045759\nlongLabel long label here\nmetadata metadata here\ntype cram\n\n", "test_file has the expected content");

close(IN);

`rm $test_file`;

done_testing();