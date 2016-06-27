
use Test::More;
use Data::Dumper;
use Test::Exception;
use Test::File;

use FindBin;
use lib $FindBin::Bin . '/../modules';

# -----
# checks if the modules can load
# -----

#test1
use_ok(EGPlantTHs::TrackHubCreation);  # it checks if it can use the module correctly

#test2
use_ok(POSIX);  # it checks if it can use the module correctly

#test3
use_ok(Getopt::Long);  # it checks if it can use the module correctly

#test4
use_ok(EGPlantTHs::ENA);  # it checks if it can use the module correctly

#test5
use_ok(EGPlantTHs::EG);  # it checks if it can use the module correctly

#test6
use_ok(EGPlantTHs::AEStudy);  # it checks if it can use the module correctly

#test7
use_ok(EGPlantTHs::SubTrack);  # it checks if it can use the module correctly

#test8
use_ok(EGPlantTHs::SuperTrack);  # it checks if it can use the module correctly

#test9
use_ok(EGPlantTHs::Helper);  # it checks if it can use the module correctly

#test10
use_ok(EGPlantTHs::ArrayExpress);  # it checks if it can use the module correctly

# -----
# test constructor
# -----

#test11
my $trackHubCreator_obj = EGPlantTHs::TrackHubCreation->new("DRP000391" ,"/homes/tapanari" );

isa_ok($trackHubCreator_obj,'EGPlantTHs::TrackHubCreation','checks whether the object constructed is of my class type');

#test12
dies_ok(sub{EGPlantTHs::TrackHubCreation->new("DRP000391")},'checks if wrong object construction of my class dies');


# -----
# test make_track_hub method
# -----

#test12
my $plant_names_AE_response_href = EGPlantTHs::ArrayExpress::get_plant_names_AE_API();

#my $output=$trackHubCreator_obj->make_track_hub($plant_names_AE_response_href);

#dir_exists_ok( "/homes/tapanari/DRP000391" , "Check that the directory exists" );

#test13
#is($output , "..Done\n" , "track hub is successfully created");

#Helper::run_system_command ("rm -r /homes/tapanari/DRP000391");

# -----
# test make_study_dir method
# -----

#test13
my $plant_names_response_href=EGPlantTHs::ArrayExpress::get_plant_names_AE_API();
my $study_obj=EGPlantTHs::AEStudy->new("DRP000391",$plant_names_response_href);

$trackHubCreator_obj->make_study_dir("/homes/tapanari",$study_obj);
dir_exists_ok( "/homes/tapanari/DRP000391" , "Check that the directory exists" );

# -----
# test make_assemblies_dirs method
# -----

#test14
$trackHubCreator_obj->make_assemblies_dirs("/homes/tapanari",$study_obj);
dir_exists_ok( "/homes/tapanari/DRP000391/IRGSP-1.0" , "Check that the assembly directory exists" );

# -----
# test make_hubtxt_file method
# -----

#test15
my $return1=EGPlantTHs::TrackHubCreation->make_hubtxt_file("/homes/tapanari",$study_obj);
file_exists_ok(("/homes/tapanari/DRP000391/hub.txt"),"Check if the file hub.txt exists");

#test16
file_contains_like( "/homes/tapanari/DRP000391/hub.txt", qr/^hub\sDRP000391\nshortLabel.+\nlongLabel.+\ngenomesFile\sgenomes.txt\nemail\s.+\n/,"content of file hub.txt is as expected" );

# -----
# test make_genomestxt_file method
# -----

#test17
$trackHubCreator_obj->make_genomestxt_file("/homes/tapanari",$study_obj);
file_exists_ok(("/homes/tapanari/DRP000391/genomes.txt"),"Check if the file hub.txt exists");


#test18
file_contains_like( "/homes/tapanari/DRP000391/genomes.txt", qr/^genome\sIRGSP-1\.0\ntrackDb\sIRGSP-1\.0\/trackDb\.txt\n/,"content of file genomes.txt is as expected" );


# -----
# test make_trackDbtxt_file method
# -----

#test19

my $return=$trackHubCreator_obj->make_trackDbtxt_file("/homes/tapanari",$study_obj, "IRGSP-1.0");
file_exists_ok(("/homes/tapanari/DRP000391/IRGSP-1.0/trackDb.txt"),"Check if the file trackDb.txt exists");

#test20
file_contains_like( "/homes/tapanari/DRP000391/IRGSP-1.0/trackDb.txt", qr/^track.+\nsuperTrack on show\n+/,"content of file trackDb.txt is as expected" );


# -----
# test printlabel_key method
# -----

#test21
my $new_label=EGPlantTHs::TrackHubCreation::printlabel_key("electra tapanari");
is($new_label,"electra_tapanari",'method replaces space with "_" in the metadata key behaves as expected');

#test22
$new_label=EGPlantTHs::TrackHubCreation::printlabel_key("electra_tapanari");
is($new_label,"electra_tapanari",'method replaces space with "_" in the metadata key behaves as expected');

#test23
$new_label=EGPlantTHs::TrackHubCreation::printlabel_key("electra");
is($new_label,"electra",'method replaces space with "_" in the metadata key behaves as expected');

#test24
$new_label=EGPlantTHs::TrackHubCreation::printlabel_key("electra tapanari of angelos");
is($new_label,"electra_tapanari_of_angelos",'method replaces space with "_" in the metadata key behaves as expected');

# -----
# test printlabel_value method
# -----

#test25
my $new_label=EGPlantTHs::TrackHubCreation::printlabel_value("electra tapanari");
is($new_label,"\"electra tapanari\"",'method that puts quotes to the metadata value behaves as expected');

#test26
$new_label=EGPlantTHs::TrackHubCreation::printlabel_value("electra");
is($new_label,"electra",'method that puts quotes to the metadata value behaves as expected');

#test27
$new_label=EGPlantTHs::TrackHubCreation::printlabel_value("electra tapanari of angelos");
is($new_label,"\"electra tapanari of angelos\"",'method that puts quotes to the metadata value behaves as expected');

# -----
# test get_ENA_biorep_title method
# -----

#test28
my $ena_biorep_title=EGPlantTHs::TrackHubCreation::get_ENA_biorep_title($study_obj,"E-MTAB-2037.biorep4"); # study DRP000391
is($ena_biorep_title,"Illumina Genome Analyzer IIx sequencing; Illumina sequencing of cDNAs generated from mRNAs_retro_PAAF", "ENA biorep title as expected currently") ;

# -----
# test make_biosample_super_track_obj method
# -----

#test29

my $super_track_obj = $trackHubCreator_obj->make_biosample_super_track_obj("SAMD00008650"); # study id DRP000391

is($super_track_obj->{track_name},"SAMD00008650","super track name is as expected");

#test30
is($super_track_obj->{long_label},"Total mRNAs from callus, leaf, panicle before flowering, panicle after flowering, root, seed, and shoot of rice (Oryza sativa ssp. Japonica cv. Nipponbare) ; <a href=\"http://www.ebi.ac.uk/ena/data/view/SAMD00008650\">SAMD00008650</a>","super track long label is as expected");

#test31
like($super_track_obj->{metadata}, qr/hub_created_date=".+BST" biosample_id=SAMD00008650 germline=N description=\"Total mRNAs from callus, leaf, panicle before flowering, panicle after flowering, root, seed, and shoot of rice \(Oryza sativa ssp. Japonica cv. Nipponbare\)\" accession=SAMD00008650 environmental_sample=N scientific_name=\"Oryza sativa Japonica Group\" sample_alias=SAMD00008650 tax_id=39947 center_name=BIOSAMPLE secondary_sample_accession=DRS000668 first_public=2011-12-21/,"super track metadata string is as expected");

# -----
# test make_biosample_sub_track_obj method
# -----

#test32
my $sub_track_obj=$trackHubCreator_obj->make_biosample_sub_track_obj($study_obj,"E-MTAB-2037.biorep4","SAMD00008650","on");  # study id DRP000391

is($sub_track_obj->{track_name},"E-MTAB-2037.biorep4","sub track name is as expected");
###################

#test33
is($sub_track_obj->{parent_name},"SAMD00008650","sub track parent name is as expected");

#test34
#is($sub_track_obj->{big_data_url},"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/aggregated_techreps/E-MTAB-2037/E-MTAB-2037.biorep4.cram","sub track cram url location is as expected");
is($sub_track_obj->{big_data_url},"ftp.sra.ebi.ac.uk/vol1/ERZ310/ERZ310303/E-MTAB-2037.biorep4.cram","sub track cram url location is as expected");

#test35
is($sub_track_obj->{short_label},"ArrayExpress:E-MTAB-2037.biorep4","sub track short label is as expected");

#test36
is($sub_track_obj->{long_label},"Illumina Genome Analyzer IIx sequencing; Illumina sequencing of cDNAs generated from mRNAs_retro_PAAF;<a href=\"http://www.ebi.ac.uk/arrayexpress/experiments/E-GEOD-55482/samples/?full=truehttp://www.ebi.ac.uk/~rpetry/bbrswcapital/E-MTAB-2037.bioreps.txt\">E-MTAB-2037.biorep4</a>","sub track long label is as expected");

#test37
is($sub_track_obj->{file_type},"cram","sub track file type is as expected");

#test38
is($sub_track_obj->{visibility},"on","sub track visibility is as expected");

EGPlantTHs::Helper::run_system_command ("rm -r /homes/tapanari/DRP000391");

done_testing(); 