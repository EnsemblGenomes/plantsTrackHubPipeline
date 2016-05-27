
use Test::More;
use Data::Dumper;
use Test::Exception;
use Test::File;

# -----
# checks if the modules can load
# -----

#test1
use_ok(TrackHubCreation);  # it checks if it can use the module correctly

#test2
use_ok(POSIX);  # it checks if it can use the module correctly

#test3
use_ok(Getopt::Long);  # it checks if it can use the module correctly

#test4
use_ok(ENA);  # it checks if it can use the module correctly

#test5
use_ok(EG);  # it checks if it can use the module correctly

#test6
use_ok(AEStudy);  # it checks if it can use the module correctly

#test7
use_ok(SubTrack);  # it checks if it can use the module correctly

#test8
use_ok(SuperTrack);  # it checks if it can use the module correctly

#test9
use_ok(Helper);  # it checks if it can use the module correctly

#test10
use_ok(ArrayExpress);  # it checks if it can use the module correctly

# -----
# test constructor
# -----

#test11
my $trackHubCreator = TrackHubCreation->new("DRP000391" ,"/homes/tapanari" );

isa_ok($trackHubCreator,'TrackHubCreation','checks whether the object constructed is of my class type');

#test12
dies_ok(sub{TrackHubCreation->new("DRP000391")},'checks if wrong object construction of my class dies');


# -----
# test make_track_hub method
# -----

#test12
my $plant_names_AE_response_href = ArrayExpress::get_plant_names_AE_API();

#my $output=$trackHubCreator->make_track_hub($plant_names_AE_response_href);

#dir_exists_ok( "/homes/tapanari/DRP000391" , "Check that the directory exists" );

#test13
#is($output , "..Done\n" , "track hub is successfully created");

#Helper::run_system_command ("rm -r /homes/tapanari/DRP000391");

# -----
# test make_study_dir method
# -----

#test13
my $plant_names_response_href= ArrayExpress::get_plant_names_AE_API();
my $study_obj=AEStudy->new("DRP000391",$plant_names_response_href);

$trackHubCreator->make_study_dir("/homes/tapanari",$study_obj);
dir_exists_ok( "/homes/tapanari/DRP000391" , "Check that the directory exists" );

# -----
# test make_assemblies_dirs method
# -----

#test14
$trackHubCreator->make_assemblies_dirs("/homes/tapanari",$study_obj);
dir_exists_ok( "/homes/tapanari/DRP000391/IRGSP-1.0" , "Check that the assembly directory exists" );

# -----
# test make_hubtxt_file method
# -----

#test15
my $return1=TrackHubCreation->make_hubtxt_file("/homes/tapanari",$study_obj);
file_exists_ok(("/homes/tapanari/DRP000391/hub.txt"),"Check if the file hub.txt exists");

#test16
file_contains_like( "/homes/tapanari/DRP000391/hub.txt", qr/^hub\sDRP000391\nshortLabel.+\nlongLabel.+\ngenomesFile\sgenomes.txt\nemail\s.+\n/,"content of file hub.txt is as expected" );

# -----
# test make_genomestxt_file method
# -----

#test17
$trackHubCreator->make_genomestxt_file("/homes/tapanari",$study_obj);
file_exists_ok(("/homes/tapanari/DRP000391/genomes.txt"),"Check if the file hub.txt exists");


#test18
file_contains_like( "/homes/tapanari/DRP000391/genomes.txt", qr/^genome\sIRGSP-1\.0\ntrackDb\sIRGSP-1\.0\/trackDb\.txt\n/,"content of file genomes.txt is as expected" );


# -----
# test make_trackDbtxt_file method
# -----

#test19

my $return=$trackHubCreator->make_trackDbtxt_file("/homes/tapanari",$study_obj, "IRGSP-1.0");
file_exists_ok(("/homes/tapanari/DRP000391/IRGSP-1.0/trackDb.txt"),"Check if the file trackDb.txt exists");

#test20
file_contains_like( "/homes/tapanari/DRP000391/IRGSP-1.0/trackDb.txt", qr/^track.+\nsuperTrack on show\n+/,"content of file trackDb.txt is as expected" );


# -----
# test printlabel_key method
# -----

#test21
my $new_label=TrackHubCreation::printlabel_key("electra tapanari");
is($new_label,"electra_tapanari",'method replaces space with _ in the metadata key behaves as expected');

#test22
$new_label=TrackHubCreation::printlabel_key("electra_tapanari");
is($new_label,"electra_tapanari",'method replaces space with \"_\" in the metadata key behaves as expected');

#test23
$new_label=TrackHubCreation::printlabel_key("electra");
is($new_label,"electra",'method replaces space wit \"_\" in the metadata key behaves as expected');

#test24
$new_label=TrackHubCreation::printlabel_key("electra tapanari of angelos");
is($new_label,"electra_tapanari_of_angelos",'method replaces space with \"_\" in the metadata key behaves as expected');

# -----
# test printlabel_value method
# -----

#test25
my $new_label=TrackHubCreation::printlabel_value("electra tapanari");
is($new_label,"\"electra tapanari\"",'method that puts quotes to the metadata value behaves as expected');

#test26
$new_label=TrackHubCreation::printlabel_value("electra");
is($new_label,"electra",'method that puts quotes to the metadata value behaves as expected');

#test27
$new_label=TrackHubCreation::printlabel_value("electra tapanari of angelos");
is($new_label,"\"electra tapanari of angelos\"",'method that puts quotes to the metadata value behaves as expected');

# -----
# test get_ENA_biorep_title method
# -----

#test28
my $ena_biorep_title=TrackHubCreation::get_ENA_biorep_title($study_obj,"E-MTAB-2037.biorep4"); # study DRP000391
is($ena_biorep_title,"Illumina Genome Analyzer IIx sequencing; Illumina sequencing of cDNAs generated from mRNAs_retro_PAAF", "ENA biorep title as expected currently") ;

# -----
# test make_biosample_super_track_obj method
# -----

#test29

# -----
# test make_biosample_sub_track_obj method
# -----

#test30

###################

Helper::run_system_command ("rm -r /homes/tapanari/DRP000391");

done_testing(); 