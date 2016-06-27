
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
use_ok(EGPlantTHs::SubTrack);  # it checks if it can use the module correctly


# -----
# test constructor
# -----

my $st_obj=EGPlantTHs::SubTrack->new("SRR351196","SAMN00728445","bigdata url","short label" ,"long label", "cram", "on");

# test2
isa_ok($st_obj,'SubTrack','checks whether the object constructed is of my class type');


# test3
dies_ok(sub{EGPlantTHs::SubTrack->new("blabla")},'checks if wrong object construction of my class dies');


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

is($string_content, "\ttrack SRR351196\n\tparent SAMN00728445\n\tbigDataUrl http://bigdata url\n\tshortLabel short label\n\tlongLabel long label\n\ttype cram\n\tvisibility pack\n\n", "test_file has the expected content");

close(IN);

$st_obj=EGPlantTHs::SubTrack->new("SRR351196","SAMN00728445","bigdata url","short label" ,"long label", "cram", "off");

open(my $fh, '>', $test_file)
 or die "Error in ".__FILE__." line ".__LINE__." Could not open file \.\/test_file!\n";

$st_obj->print_track_stanza($fh);
 
close($fh);

open(IN, $test_file) or die "Can't open $test_file.\n";

@file_lines=<IN>;

$string_content=join("",@file_lines);

#test8
is($string_content, "\ttrack SRR351196\n\tparent SAMN00728445\n\tbigDataUrl http://bigdata url\n\tshortLabel short label\n\tlongLabel long label\n\ttype cram\n\tvisibility hide\n\n", "test_file has the expected content");

close(IN);

`rm $test_file`;

done_testing();