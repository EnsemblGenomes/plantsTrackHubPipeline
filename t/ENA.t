use Test::More;
use Capture::Tiny ':all';

use FindBin;
use lib $FindBin::Bin . '/../modules';

# -----
# checks if the module can load
# -----

#test1
use_ok(EGPlantTHs::ENA);  # it checks if it can use the module correctly

#test2
use_ok(LWP::UserAgent);  # it checks if it can use the module correctly

#test3
use_ok(XML::LibXML);  # it checks if it can use the module correctly

# -----
# test get_ENA_study_title method
# -----

#test4
my $study_title=EGPlantTHs::ENA::get_ENA_study_title("DRP000315");
is($study_title,"Oryza sativa Japonica Group transcriptome sequencing", "ENA title of study DRP000315 is as expected");

#test5
my $study_title_wrong_study_title=EGPlantTHs::ENA::get_ENA_study_title("DRP0003");
is($study_title_wrong_study_title,"not yet in ENA", "not yet in ENA response when giving wrong study id..");

# -----
# test get_ENA_title method
# -----

#test6
my $sample_title = EGPlantTHs::ENA::get_ENA_title("SAMN02666886");
is($sample_title,"Arabidopsis thaliana Bur-0 X Col-0 seedling, biological replicate 1", "ENA title of sample SAMN02666886 is as expected");

#test7
my $sample_title_wrong_sample_title = EGPlantTHs::ENA::get_ENA_title("SAMN0266688");
is($sample_title_wrong_sample_title,"not yet in ENA", "not yet in ENA response when giving wrong sample id..");

#test8
my ($stdout, $stderr,$sample_title_wrong_sample_title) = capture { 
  EGPlantTHs::ENA::get_ENA_title("SAMN03782116");
};

is($sample_title_wrong_sample_title,0, "no title found for sample SAMN03782116");

#test9
is($stderr,"I could not get a node from the xml doc of TITLE for sample/run/experiment id SAMN03782116\n", "gives the expected STDERR when there is no title found in ENA");

# -----
# test get_all_sample_keys method
# -----

#test10
my $meta_keys_aref = EGPlantTHs::ENA::get_all_sample_keys(); # array ref that has all the keys for the ENA warehouse metadata
my %meta_keys_hash = map{$_ => 1} @$meta_keys_aref;

my @meta_keys_to_test=("accession", "cell_line","cell_type","tax_id","tissue_type","sex");

foreach my $meta_key (@meta_keys_to_test) {

  ok(exists $meta_keys_hash{$meta_key}, "\'$meta_key\' exists as a key");
}

# -----
# test get_sample_metadata_response_from_ENA_warehouse_rest_call method
# -----

my $sample_id="SAMN02666886";

my $sample_metadata_href=EGPlantTHs::ENA::get_sample_metadata_response_from_ENA_warehouse_rest_call($sample_id,$meta_keys_aref);

#test16
ok(exists $sample_metadata_href->{scientific_name}, "\'scientific_name\' exists as a key");

#test17
is($sample_metadata_href->{scientific_name}, "Arabidopsis thaliana", "scientic name metakeys is as expected");


# -----
# test create_url_for_call_sample_metadata method
# -----

#test18
my $url=EGPlantTHs::ENA::create_url_for_call_sample_metadata("SAMN02666886",$meta_keys_aref);
like($url , qr/^http:\/\/www.ebi.ac.uk\/ena\/data\/.+accession=SAMN02666886.+sex.+tax_id.*/, "REST url to get ENA metadata is as expected");



# -----
# test give_big_data_file_type method
# -----

#test19
my $url_ena="http://ftp.sra.ebi.ac.uk/vol1/ERZ285/ERZ285703/SRR3019819.cram";
my $file_type = EGPlantTHs::ENA::give_big_data_file_type($url_ena);
is($file_type, "cram", "big data file type is as expected");


# -----
# test get_assembly_name_from_analysis_XML_using_analysis_id method
# -----

#test20
my $assembly_name=EGPlantTHs::ENA::get_assembly_name_from_analysis_XML_using_analysis_id("ERZ359348");
is($assembly_name, "SolTub_3.0", "assembly name of analysis id ERZ359348 is as expected");

#test22
$assembly_name=EGPlantTHs::ENA::get_assembly_name_from_analysis_XML_using_analysis_id("359348");
is($assembly_name, "not yet in ENA", "assembly name of a wrong analysis id is 0");

done_testing();