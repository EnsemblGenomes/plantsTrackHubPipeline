
use Test::More;
use Test::Exception;
use Capture::Tiny ':all';
use FindBin;
use lib $FindBin::Bin . '/../modules';

# -----
# checks if the module can load
# -----

#test1
use_ok(EGPlantTHs::AEStudy); # it checks if it can use the module correctly

#test2
use_ok(EGPlantTHs::ArrayExpress);  # it checks if it can use the module correctly

#test3
use_ok(Date::Manip);  # it checks if it can use the module correctly


#test4

# -----
# test constructor
# -----

my $plant_names_response_href= EGPlantTHs::ArrayExpress::get_plant_names_AE_API();

my $study_obj= EGPlantTHs::AEStudy->new("SRP068911",$plant_names_response_href);

isa_ok($study_obj,'EGPlantTHs::AEStudy','checks whether the object constructed is of my class type');

# test5
dies_ok(sub{EGPlantTHs::AEStudy->new("blabla")},'checks if wrong object construction of my class dies');

# -----
# test make_runs_tuple_plants_of_study method
# -----

my $run_tuple_href=$study_obj->make_runs_tuple_plants_of_study();

#test6
is($run_tuple_href->{"SRR3124516"}{"organism"}, "vitis_vinifera", "study SRP068911, biorep SRR3124516 has the expected organism name in the run tuple");

#test7
is($run_tuple_href->{"SRR3124516"}{"assembly_name"}, "IGGP_12x", "study SRP068911, biorep SRR3124516 has the expected assembly name currrnetly in the run tuple");

# -----
# test id method
# -----

my $study_id= $study_obj->id;
#test8
is($study_id, "SRP068911", "study id method returns value as expected");

# -----
# test get_biorep_ids_by_organism method
# -----

my $study_obj_3_assemblies= EGPlantTHs::AEStudy->new("DRP000453",$plant_names_response_href); # see http://plantain:3000/json/70/getRunsByStudy/DRP000453
my $biorep_ids_href_oryza_sativa=$study_obj_3_assemblies->get_biorep_ids_by_organism("oryza_sativa");

#test9
ok(exists $biorep_ids_href_oryza_sativa->{DRR001373} , "Biorep of study DRP000453 from oryza_sativa exists at the moment" );

my $oryza_sativa_study_with_many_assemblies_number_of_bioreps = scalar keys %$biorep_ids_href_oryza_sativa;
my $all_biorep_ids_href=$study_obj_3_assemblies->get_biorep_ids;
my $study_with_many_assemblies_number_of_all_bioreps = scalar keys %$all_biorep_ids_href;

#test10
cmp_ok($study_with_many_assemblies_number_of_all_bioreps, 'gt', $oryza_sativa_study_with_many_assemblies_number_of_bioreps , "Number of bioreps of study DRR001373 (has many assemblies) when calling the species specific method is less than the method that returns all bioreps");

# -----
# test get_organism_names_assembly_names method
# -----

#test11
my $sample_ids_href= $study_obj_3_assemblies->get_organism_names_assembly_names;
is($sample_ids_href->{oryza_rufipogon}, "OR_W1943", "organism_name - assembly_name hash returns value as expected currently for study DRP000453");

#test12
is($sample_ids_href->{oryza_indica}, "ASM465v1", "organism_name - assembly_name hash returns value as expected currently for study DRP000453");

#test13
is($sample_ids_href->{oryza_sativa}, "IRGSP-1.0", "organism_name - assembly_name hash returns value as expected currently for study DRP000453");

# -----
# test get_sample_ids method
# -----

#test14
my $study_obj_with_many_samples_per_biorep_id= EGPlantTHs::AEStudy->new("SRP002106",$plant_names_response_href);
my $sample_ids_href = $study_obj_with_many_samples_per_biorep_id->get_sample_ids; # for study SRP002106

ok(exists $sample_ids_href->{SAMN00009808} , "Sample id of Biorep E-GEOD-16631.biorep2 of study SRP002106 from oryza_sativa exists at the moment" );

#test15
ok(exists $sample_ids_href->{SAMN00009837} ,"Sample id of Biorep E-GEOD-16631.biorep2 of study SRP002106 from oryza_sativa exists at the moment" );

# -----
# test get_assembly_name_from_biorep_id method
# -----

#test16
my $assembly_name = $study_obj_with_many_samples_per_biorep_id->get_assembly_name_from_biorep_id("E-GEOD-16631.biorep2");
is($assembly_name, "IRGSP-1.0", "assembly name from biorep id is as expected");


# -----
# test get_sample_ids_from_biorep_id method
# -----

#test17
my @sample_ids_aref=$study_obj_with_many_samples_per_biorep_id->get_sample_ids_from_biorep_id("E-GEOD-16631.biorep2"); # see http://plantain:3000/json/70/getRunsByStudy/SRP002106
my %sample_ids_of_biorep_hash = map{$_ => 1} @sample_ids_aref;

ok(exists $sample_ids_href->{SAMN00009822} ,  "Sample id of Biorep E-GEOD-16631.biorep2 of study SRP002106 from oryza_sativa exists at the moment" );

#test18
ok(exists $sample_ids_href->{SAMN00009827} ,  "Sample id of Biorep E-GEOD-16631.biorep2 of study SRP002106 from oryza_sativa exists at the moment" );


# -----
# test get_biorep_ids method
# -----

#test19
my $biorep_ids_href=$study_obj_with_many_samples_per_biorep_id->get_biorep_ids();
ok(exists $biorep_ids_href->{"E-GEOD-16631.biorep1"} ,  "Biorep id of study SRP002106 from oryza_sativa exists at the moment" );

#test20
ok(exists $biorep_ids_href->{SRR037741} ,  "Biorep id of study SRP002106 from oryza_sativa exists at the moment" );

# -----
# test get_biorep_ids_from_sample_id method
# -----

#test21

my $biorep_ids_from_sample_id_href = $study_obj_with_many_samples_per_biorep_id->get_biorep_ids_from_sample_id("SAMN00009808");
ok(exists $biorep_ids_from_sample_id_href->{"E-GEOD-16631.biorep2"} ,  "Biorep id \'E-GEOD-16631.biorep2\' of sample SAMN00009808 from oryza_sativa exists at the moment" );

# -----
# test get_assembly_names method
# -----

#test22
my $assembly_names_of_study_href= $study_obj_3_assemblies->get_assembly_names(); # study DRP000453
ok(exists $assembly_names_of_study_href->{"ASM465v1"} ,  "Assembly id \'ASM465v1\' of study ".$study_obj_3_assemblies->id." exists at the moment" );

#test23
ok(exists $assembly_names_of_study_href->{"IRGSP-1.0"} ,  "Assembly id \'IRGSP-1.0\' of study ".$study_obj_3_assemblies->id." exists at the moment" );

#test24
ok(exists $assembly_names_of_study_href->{"OR_W1943"} ,  "Assembly id \'OR_W1943\' of study ".$study_obj_3_assemblies->id." exists at the moment" );

# -----
# test get_big_data_file_location_from_biorep_id method
# -----

#test25

my $file_location=$study_obj_3_assemblies->get_big_data_file_location_from_biorep_id("DRR001371");
is($file_location, "ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/DRR001/DRR001371/DRR001371.cram", "file location of the cram file is as expected");

#test26
dies_ok(sub{$study_obj_3_assemblies->get_big_data_file_location_from_biorep_id("E-GEOD-16631.biorep2")},'checks if wrong biorep id of study dies');

# -----
# test get_AE_last_processed_date_from_biorep_id method
# -----

#test27
#"LAST_PROCESSED_DATE":"Sat Apr 02 2016 08:13:16",
my $last_processed_date_AE_from_biorep_id=$study_obj_3_assemblies->get_AE_last_processed_date_from_biorep_id("DRR001371");
like($last_processed_date_AE_from_biorep_id , qr/[\w{3}\s\w{2}\s20\w{2}\s.+]/, "Last AE processed date is as expected");

#test28
dies_ok(sub{$study_obj_3_assemblies->get_AE_last_processed_date_from_biorep_id("E-GEOD-16631.biorep2")},'checks if wrong biorep id of study dies');


# -----
# test get_run_ids_of_biorep_id method
# -----

#test29

my $runs_ids_aref =$study_obj_with_many_samples_per_biorep_id->get_run_ids_of_biorep_id("E-GEOD-16631.biorep2");
my %run_ids_hash = map{$_ => 1} @$runs_ids_aref;
ok(exists $run_ids_hash{"SRR037711"},"Run id SRR037711 of biorep \'E-GEOD-16631.biorep2\' exists at the moment");

#test30
ok(exists $run_ids_hash{"SRR037712"},"Run id SRR037712 of biorep \'E-GEOD-16631.biorep2\' exists at the moment");

#test31
dies_ok(sub{$study_obj_with_many_samples_per_biorep_id->get_run_ids_of_biorep_id("DRR001371")},'checks if wrong biorep id of study dies');


# -----
# test give_big_data_file_type_of_biorep_id method
# -----

#test32
my $file_type =$study_obj_with_many_samples_per_biorep_id->give_big_data_file_type_of_biorep_id("E-GEOD-16631.biorep2");
is($file_type, "cram" , "file type is currently cram as expected");

#test33
dies_ok(sub{$study_obj_with_many_samples_per_biorep_id->give_big_data_file_type_of_biorep_id("DRR001371")},'checks if wrong biorep id of study dies');

# -----
# test get_AE_last_processed_unix_date method
# -----

#test34
my $study_obj_SRP067728= EGPlantTHs::AEStudy->new("SRP067728",$plant_names_response_href);

my $unix_date = $study_obj_SRP067728->get_AE_last_processed_unix_date();
# the max date of the bioreps is Tue Jan 12 2016 06:50:49, in unix format that is: 1452581449
is($unix_date , "1452581449" , "Unix date of the max date of the bioreps of study SRP067728 is currently as expected");

done_testing();