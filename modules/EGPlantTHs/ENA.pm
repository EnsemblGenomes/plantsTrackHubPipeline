package EGPlantTHs::ENA;

use strict ;
use warnings;

use LWP::UserAgent;
use XML::LibXML;
use utf8;
use DateTime::Format::Strptime;

my $ua = LWP::UserAgent->new;
my $parser = XML::LibXML->new;

my $all_cram_locations_href = get_hash_of_locations_of_cram_submissions();  # hash is like: hash{DRR008478"}{"TAIR10"}{"2016-03-04"}="ftp.sra.ebi.ac.uk/vol1/ERZ270/ERZ270564/DRR008478.cram"
my %unique_cram_locations= %{get_last_updated_cram_file_location_hash($all_cram_locations_href)};  # hash is like: hash{DRR008478"}{"TAIR10"}="ftp.sra.ebi.ac.uk/vol1/ERZ270/ERZ270564/DRR008478.cram"

sub get_ENA_study_title{  

  my $study_id = shift; 

  my $study_title;

  my $url ="http://www.ebi.ac.uk/ena/data/view/$study_id&display=xml";

  my $response = $ua->get($url); 

  my $response_string;

  if ($response->is_success) {
    $response_string = $response->decoded_content;  
  }
  else {
    return 0;
  }

  my $doc_obj = $parser->parse_string($response_string);

  if ($doc_obj =~/display type is either not supported or entry is not found/ or $doc_obj !~/\/STUDY_LINK/){
    return "not yet in ENA";
  }

  my @nodes = $doc_obj->findnodes("//STUDY_TITLE");

  if(!$nodes[0]){
    print STDERR "I could not get a node from the xml doc of STUDY_TITLE for study id $study_id\n";
    return "Study title was not found in ENA";
  }
  $study_title = $nodes[0]->firstChild->data; #it's always 1 node
  utf8::encode($study_title);
  return $study_title;

}

sub get_ENA_title { # it works for sample, run and experiment ids

  my $id = shift ;
  my $title ;

  my $url ="http://www.ebi.ac.uk/ena/data/view/$id&display=xml";

  my $response = $ua->get($url); 
  my $response_string;

  if ($response->is_success) {
    $response_string = $response->decoded_content;  
  }
  else {

    return 0;
  }
  my $doc = $parser->parse_string($response_string);
  my @nodes = $doc->findnodes("//TITLE");

  if ($doc =~/display type is either not supported or entry is not found/){
    return "not yet in ENA";
  }

  elsif(!@nodes){

    print STDERR "I could not get a node from the xml doc of TITLE for sample/run/experiment id $id\n";
    return 0;   

  }else{
 
    $title = $nodes[0]->firstChild->data; #it's always 1 node
    utf8::encode($title);

    return $title;
  }
}

# I call the endpoint (of the ENA sample metadata stored in $url) and get this type of response:
#accession	altitude	bio_material	broker_name	cell_line	cell_type	center_name	checklist	col_scientific_name	col_tax_id	collected_by	collection_date	country	cultivar	culture_collection	depth	description	dev_stage	ecotype	elevation	environment_biome	environment_feature	environment_material	environmental_package	environmental_sample	experimental_factor	first_public	germline	host	host_body_site	host_genotype	host_gravidity	host_growth_conditions	host_phenotype	host_sex	host_status	host_tax_id	identified_by	investigation_type	isolate	isolation_source	location	mating_type	ph	project_name	protocol_label	salinity	sample_alias	sample_collection	sampling_campaign	sampling_platform	sampling_site	scientific_name	secondary_sample_accession	sequencing_method	serotype	serovar	sex	specimen_voucher	strain	sub_species	sub_strain	submitted_host_sex	submitted_sex	target_gene	tax_id	temperature	tissue_lib	tissue_type	variety
#SAMEA1711073						The Genome Analysis Centre										INF1-C								N		2012-07-13	N																				RW_S9_barley					Hordeum vulgare subsp. vulgare	ERS155504												112509				

#url call -> http://www.ebi.ac.uk/ena/data/warehouse/search?query=%22accession=SAMEA1711073%22&result=sample&display=report&fields=accession,altitude,bio_material,broker_name,cell_line,cell_type,center_name,checklist,col_scientific_name,col_tax_id,collected_by,collection_date,country,cultivar,culture_collection,depth,description,dev_stage,ecotype,elevation,environment_biome,environment_feature,environment_material,environmental_package,environmental_sample,experimental_factor,first_public,germline,host,host_body_site,host_genotype,host_gravidity,host_growth_conditions,host_phenotype,host_sex,host_status,host_tax_id,identified_by,investigation_type,isolate,isolation_source,location,mating_type,ph,project_name,protocol_label,salinity,sample_alias,sample_collection,sampling_campaign,sampling_platform,sampling_site,scientific_name,secondary_sample_accession,sequencing_method,serotype,serovar,sex,specimen_voucher,strain,sub_species,sub_strain,submitted_host_sex,submitted_sex,target_gene,tax_id,temperature,tissue_lib,tissue_type,variety

sub get_sample_metadata_response_from_ENA_warehouse_rest_call {  # returns a hash ref if successful, or 0 if not successful -- this is slow

  my $sample_id =  shift;
  my $meta_keys = shift; 

  my %metadata_key_value_pairs;

  my $url = create_url_for_call_sample_metadata($sample_id,$meta_keys);

  my $response_string;
  my @lines;
  my $metadata_keys_line;
  my $metadata_values_line;

  my $response = $ua->get($url); 

  if($response->code != 200 ){

    print "Couldn't get metadata for $url \nwith the first attempt, retrying..\n" ;

    my $flag_success=0;

    for(my $i=1; $i<=10; $i++) {

      print $i .".Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      $response = $ua->get($url);

      if($response->is_success){

        $response_string = $response->decoded_content;
        @lines = split(/\n/, $response_string);
        if($lines[0]) {
          $metadata_keys_line =  $lines[0];
        }
        if($lines[1]){
          $metadata_values_line =  $lines[1];
        }

        $flag_success =1 ;
        last;
      }

    }

    if($flag_success ==0 or $response_string =~ /^ *$/ or (!$metadata_values_line) or (!$metadata_keys_line) ){  # if after the 10 attempts I still don't get the metadata..
      return 0;
    }
    print "Got metadata after all!\n";
  }

  $response_string = $response->decoded_content;
  @lines = split(/\n/, $response_string);
  if($lines[0]) {
    $metadata_keys_line =  $lines[0];
  }else{

    return 0;
  }
  if($lines[1]){
    $metadata_values_line =  $lines[1];
  }else{

    return 0;
  }
  
  my @metadata_keys = split(/\t/, $metadata_keys_line);
  my @metadata_values = split(/\t/, $metadata_values_line); 

  my $index = 0;

  foreach my $metadata_key (@metadata_keys){
    if(!$metadata_values [$index] or $metadata_values [$index] =~/^ *$/) {
      $index++;
      next;

    }else{
      if($metadata_key=~/date/ and $metadata_values [$index]=~/(\d+)-\d+-\d+\/\d+-\d+-\d+/){ # i do this as an exception because I had dates like this:  collection_date=2014-01-01/2014-12-31, I want to do it collection_date=2014
         $metadata_values [$index] = $1;
      }
      utf8::encode($metadata_key);
      utf8::encode($metadata_values [$index]);
      $metadata_key_value_pairs{$metadata_key} = $metadata_values [$index];
    }
    $index++;

  }
  return \%metadata_key_value_pairs ; # hash with key -> metadata_key , value-> metadata_value
}


#content of the returned array:

#accession,altitude,bio_material,broker_name,cell_line,cell_type,center_name,checklist,col_scientific_name,col_tax_id,collected_by,collection_date,country,cultivar,culture_collection,depth,
#description,dev_stage,ecotype,elevation,environment_biome,environment_feature,environment_material,environmental_package,environmental_sample,experimental_factor,first_public,germline,host,host_body_site,host_genotype,
#host_gravidity,host_growth_conditions,host_phenotype,host_sex,host_status,host_tax_id,identified_by,investigation_type,isolate,isolation_source,location,mating_type,ph,project_name,protocol_label,
#salinity,sample_alias,sample_collection,sampling_campaign,sampling_platform,sampling_site,scientific_name,secondary_sample_accession,sequencing_method,serotype,serovar,sex,specimen_voucher,strain,sub_species,sub_strain,
#submitted_host_sex,submitted_sex,target_gene,tax_id,temperature,tissue_lib,tissue_type,variety[

sub get_all_sample_keys{

  my @array_keys;

  my $url ="http://www.ebi.ac.uk/ena/data/warehouse/usage?request=fields&result=sample";

  my $response = $ua->get($url); 

  my $response_string = $response->decoded_content;

  my @keys;

  if($response->code != 200 or $response_string =~ /^ *$/ ){

    print "\nCouldn't get sample metadata keys using $url with the first attempt, retrying..\n" ;

    my $flag_success = 0 ;
    for(my $i=1; $i<=10; $i++) {

      print $i .".Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      $response = $ua->get($url);

      my $response_string = $response->decoded_content;

      $response->code= $response->code;

      if($response->code == 200){

        $response_string = $response->decoded_content;
        @keys = split(/\n/, $response_string);

        $flag_success =1 ;
        print "Got sample metadata keys after all!\n";
        last;
      }

    }
    if($flag_success ==0 or $response_string =~ /^ *$/){  # if after the 10 attempts I still don't get the metadata..
     
      print STDERR "Didn't get response for sample metadata keys using url $url"."\t".$response->code."\n\n";
      return 0;
    }

  }else{

    @keys = split(/\n/, $response_string);
  }

  foreach my $key (@keys){
    push (@array_keys ,$key);
  }

  return \@array_keys;
}

# it makes this url, given the table ref with the keys:

#http://www.ebi.ac.uk/ena/data/warehouse/search?query=%22accession=SAMPLE_id%22&result=sample&display=report&fields=accession,altitude,bio_material,broker_name,cell_line,cell_type,center_name,checklist,col_scientific_name,
#col_tax_id,collected_by,collection_date,country,cultivar,culture_collection,depth,description,dev_stage,ecotype,elevation,environment_biome,environment_feature,environment_material,environmental_package,environmental_sample,
#experimental_factor,first_public,germline,host,host_body_site,host_genotype,host_gravidity,host_growth_conditions,host_phenotype,host_sex,host_status,host_tax_id,identified_by,investigation_type,isolate,isolation_source,location,
#mating_type,ph,project_name,protocol_label,salinity,sample_alias,sample_collection,sampling_campaign,sampling_platform,sampling_site,scientific_name,secondary_sample_accession,sequencing_method,serotype,serovar,sex,
#specimen_voucher,strain,sub_species,sub_strain,submitted_host_sex,submitted_sex,target_gene,tax_id,temperature,tissue_lib,tissue_type,variety

sub create_url_for_call_sample_metadata { # i am calling this method for a sample id

  my $sample_id = shift;
  my $table_ref= shift;

  my @key_values = @{$table_ref};

  my $url = "http://www.ebi.ac.uk/ena/data/warehouse/search?query=\%22accession=\%22$sample_id\%22\%22&result=sample&display=report&fields=";

  my $counter = 0;

  foreach my $key_value (@key_values){

    $counter++;
    $url = $url .$key_value;
    if ($counter < scalar @key_values){
      $url = $url .",";
    }
 
  }

  return $url;
}


sub get_hash_of_locations_of_cram_submissions{

  my $fake_study_id= "ERP014374"; # this is the study id that Christoph uses to submit the CRAM files to ENA. this study id includes all CRAM files that Chr. managed to submit to ENA from ArrayExpress.

  my $url = "http://www.ebi.ac.uk/ena/data/warehouse/filereport?accession=ERP014374&result=analysis&fields=last_updated,submitted_ftp,analysis_accession&download=txt";

#last_updated	submitted_ftp
#2016-03-04	ftp.sra.ebi.ac.uk/vol1/ERZ270/ERZ270564/DRR008478.cram ERZ273205
#2016-03-11	ftp.sra.ebi.ac.uk/vol1/ERZ270/ERZ270806/DRR016127.cram ERZ277617

  my $response = $ua->get($url); 

  my $response_string = $response->decoded_content;

  if($response->code != 200 or $response_string =~ /^ *$/ ){

    print STDERR "\nCouldn't get submitted CRAM locations using $url with the first attempt, retrying..\n" ;

    my $flag_success = 0 ;
    for(my $i=1; $i<=10; $i++) {

      print STDERR $i .".Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      $response = $ua->get($url);

      my $response_string = $response->decoded_content;

      $response->code= $response->code;

      if($response->code == 200){

        $response_string = $response->decoded_content;

        $flag_success =1 ;
        print "Got CRAM locations after all!\n";
        last;
      }

    }
    if($flag_success ==0 or $response_string =~ /^ *$/){  # if after the 10 attempts I still don't get the metadata..
     
      print STDERR "Didn't get response for CRAM locations using url $url"."\t".$response->code."\n\n";
      return 0;
    }

  }else{ # if there is proper response

    my %cram_name_ena_location; # same cram file submitted more than once. It will have a different ftp location since the analysis id will be different and it is included in the ftp location url, i can only keep the most recent date

    my @lines= split(/\n/, $response_string);
    
    foreach my $line (@lines){ # I am reading line-by-line the response, and make my hash table

      next if ($line=~/^last/); # i skip the title
      next if (!$line);

#2016-03-04	ftp.sra.ebi.ac.uk/vol1/ERZ270/ERZ270564/DRR008478.cram  ERZ273205
      my @words= split(/\t/, $line);
      my $date = $words[0];
      my $cram_location = $words[1];
      my $analysis_id = $words[2];

      next if(!$date) or (!$cram_location);  # goes to next line

      if($cram_location =~/.+\/(.+)\.cram/){   # the cram name could be of type : SRR2912853.cram or E-MTAB-4045.biorep85.cram

        my $assembly_name = get_assembly_name_from_analysis_XML_using_analysis_id($analysis_id);

        if(!$assembly_name){
          print STDERR "In method get_assembly_name_from_analysis_XML_using_analysis_id, module ENA.pm , line ".__LINE__." could not get the assembly name from the ENA XML file using analysis id $analysis_id"."\n";
          return 0;      
        }
        $cram_name_ena_location{$1}{$assembly_name}{$date}=$cram_location; # it would be $cram_name_ena_location{DRR008478"}{"TAIR10"}{"2016-03-04"}="ftp.sra.ebi.ac.uk/vol1/ERZ270/ERZ270564/DRR008478.cram"

      }else{
        print STDERR "In method get_hash_of_locations_of_cram_submissions, module ENA.pm , line ".__LINE__." could not get the cram name here $line in the regex\n";
        return 0;
      }
    }
    return \%cram_name_ena_location;

  }
}


sub get_last_updated_cram_file_location_hash{
  
   my $location_href = shift; # the hash would be like this: $location_hash{DRR008478"}{"TAIR10"}{"2016-03-04"}="ftp.sra.ebi.ac.uk/vol1/ERZ270/ERZ270564/DRR008478.cram"
   my %unique_cram_names;
  
  foreach my $cram_name (keys %$location_href){
    foreach my $assembly_name (keys %{$location_href->{$cram_name}}){

      my $max_timestamp=0;
      my $timestamp;
      my $location_of_max_timestamp;

      foreach my $date (keys %{$location_href->{$cram_name}{$assembly_name}}){

        my $strp = DateTime::Format::Strptime->new(
        pattern => '%Y-%m-%d', #2016-03-04
        time_zone => 'local',
        );
        my $dt = $strp->parse_datetime($date);
        $timestamp=$dt->epoch;

        if($timestamp > $max_timestamp){

          $max_timestamp = $timestamp;
          $location_of_max_timestamp = $location_href->{$cram_name}{$assembly_name}{$date}; 
        }
      }

      $unique_cram_names{$cram_name}{$assembly_name}=$location_of_max_timestamp; #the hash would be like this: $unique_cram_names_href{DRR008478"}{"TAIR10"}="ftp.sra.ebi.ac.uk/vol1/ERZ270/ERZ270564/DRR008478.cram"
    }
  }

  return \%unique_cram_names;
}

sub get_ENA_cram_location_of_biorep_id_and_assembly_name{

  my $biorep_id = shift;
  my $biorep_assembly_name = shift;

  my %cram_locations = %unique_cram_locations; # $unique_cram_locations_href is global variable

  if($cram_locations{$biorep_id}{$biorep_assembly_name}){
    return $cram_locations{$biorep_id}{$biorep_assembly_name};
  }else{
    return 0;
  }

}


sub give_big_data_file_type{
  
  my $big_data_url = shift;

  $big_data_url=~ /.+\/.+\.(.+)$/; #  http://ftp.sra.ebi.ac.uk/vol1/ERZ285/ERZ285703/SRR3019819.cram

  return $1; # ie cram

}


sub get_assembly_name_from_analysis_XML_using_analysis_id {

  my $analysis_id = shift ;

  my $assembly_name ;

  my $title;
  my $filename;

  my $url ="http://www.ebi.ac.uk/ena/data/view/$analysis_id&display=xml"; 

  my $response = $ua->get($url); 
  my $response_string;

  if ($response->is_success) {
    $response_string = $response->decoded_content;  
  }
  else {
    print STDERR "Could not get response for call: $url in ENA module method get_assembly_name_from_analysis_XML_using_analysis_id, line ".__LINE__."\n";
    return 0;
  }
  my $doc = $parser->parse_string($response_string);

  if ($doc =~/display type is either not supported or entry is not found/){
    return "not yet in ENA";
  }

  my @nodes = $doc->findnodes("//TITLE");

  if(!@nodes){
    print STDERR "I could not get a TITLE node from the xml doc $url\n";
    return 0;   

  }else{
 
    $title = $nodes[0]->firstChild->data; #it's always 1 node
    utf8::encode($title);
    if($title =~/Alignment\sof\s.+\sto\s(.+)/){   #     <TITLE>Alignment of ERR072804 to AGPv3</TITLE>
      $assembly_name = $1;
    }else{
      print STDERR "Could not find the assembly name in the TITLE node of the analysis id $analysis_id in ENA $url in module ENA.pm\n";
      return 0;
    }
  }

  return $assembly_name;
}


1;