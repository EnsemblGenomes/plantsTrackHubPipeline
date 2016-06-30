package EGPlantTHs::TrackHubCreation;

use strict ;
use warnings;

use Getopt::Long; # to use the options when calling the script
use POSIX qw(strftime); # to get GMT time stamp

use EGPlantTHs::ENA;
#use EGPlantTHs::EG; # remove?
use EGPlantTHs::AEStudy;
use EGPlantTHs::SubTrack;
use EGPlantTHs::SuperTrack;
use EGPlantTHs::Helper;

my $meta_keys_aref = EGPlantTHs::ENA::get_all_sample_keys(); # array ref that has all the keys for the ENA warehouse metadata

sub new {

  my $class = shift;

  my $study_id  = shift; 
  my $server_dir_full_path = shift;
  
  defined $study_id and defined $server_dir_full_path
    or die "Object must be constructed using 2 parameters: study id and folder path\n";

  my $self = {
    study_id  => $study_id ,
    server_dir_full_path => $server_dir_full_path
  };

  return bless $self, $class; # this is what makes a reference into an object
}


sub make_track_hub{ # main method, creates the track hub of a study in the folder/server specified

  my $self= shift;
  my $study_id= $self->{study_id};
  my $server_dir_full_path = $self->{server_dir_full_path};

  my $plant_names_response_href = shift;

  my $study_obj = EGPlantTHs::AEStudy->new($study_id,$plant_names_response_href);

  $self->make_study_dir($server_dir_full_path, $study_obj);

  $self->make_assemblies_dirs($server_dir_full_path, $study_obj) ;  
  
  my $return = $self->make_hubtxt_file($server_dir_full_path , $study_obj);

  if($return eq "not yet in ENA"){
    return "..Study $study_id is not yet in ENA\n";
  }
  $self->make_genomestxt_file($server_dir_full_path , $study_obj);  

  my %assembly_names = %{$study_obj->get_assembly_names}; 

  foreach my $assembly_name (keys %assembly_names){

    my $return_of_make_trackDbtxt_file = $self->make_trackDbtxt_file($server_dir_full_path, $study_obj, $assembly_name);

    if (!$return_of_make_trackDbtxt_file) { # method returns 0 when there is no ENA warehouse metadata
      return ".. No ENA Warehouse metadata found for at least 1 of the sample ids\n";
    }
    if ($return_of_make_trackDbtxt_file eq "at least 1 cram file of the TH that was not found in ENA"){
      return "..Skipping this TH because at least 1 of the cram files of the TH is not yet in ENA\n";
    }
  }

  return "..Done\n";
}


sub make_study_dir{

  my $self= shift;
  my ($server_dir_full_path,$study_obj) = @_;

  my $study_id = $study_obj->id;  

  EGPlantTHs::Helper::run_system_command("mkdir $server_dir_full_path" . '/' . $study_id)
    or die "I cannot make dir $server_dir_full_path/$study_id in script: ".__FILE__." line: ".__LINE__."\n";
}

sub make_assemblies_dirs{

  my $self= shift;
  my ($server_dir_full_path,$study_obj) = @_;
  my $study_id = $study_obj->id;
  
  # For every assembly I make a directory for the study -track hub
  foreach my $assembly_name (keys %{$study_obj->get_assembly_names}){

    EGPlantTHs::Helper::run_system_command("mkdir $server_dir_full_path/$study_id/$assembly_name")
      or die "I cannot make directories of assemblies in $server_dir_full_path/$study_id in script: ".__FILE__." line: ".__LINE__."\n";
  }
}

sub make_hubtxt_file{

  my $self= shift;
  my ($server_dir_full_path,$study_obj) = @_;

  my $study_id = $study_obj->id;
  my $hub_txt_file= "$server_dir_full_path/$study_id/hub.txt";

  EGPlantTHs::Helper::run_system_command("touch $hub_txt_file")
    or die "Could not create hub.txt file in the $server_dir_full_path location\n";
  
  open(my $fh, '>', $hub_txt_file) or die "Could not open file '$hub_txt_file' $! in ".__FILE__." line: ".__LINE__."\n";

  print $fh "hub $study_id\n";

  print $fh "shortLabel "."RNA-Seq alignment hub ".$study_id."\n"; 
  
  my $ena_study_title = EGPlantTHs::ENA::get_ENA_study_title($study_id);

  if ($ena_study_title eq "not yet in ENA"){
    return "not yet in ENA";
  }
  my $long_label;

  if ($ena_study_title eq "Study title was not found in ENA") { 

    print STDERR "I cannot get study title for $study_id from ENA\n";
    $long_label = "longLabel <a href=\"http://www.ebi.ac.uk/ena/data/view/".$study_id."\">".$study_id."</a>"."\n";

  }else{

    $long_label = "longLabel $ena_study_title ; <a href=\"http://www.ebi.ac.uk/ena/data/view/".$study_id."\">".$study_id."</a>"."\n";
    print $fh $long_label;
    print $fh "genomesFile genomes.txt\n";
    print $fh "email helpdesk\@ensemblgenomes.org\n";

  }

  return "ok";
}

sub make_genomestxt_file{

  my $self= shift;
  my ($server_dir_full_path,$study_obj) = @_;  

  my $assembly_names_href = $study_obj->get_assembly_names;
  my $study_id = $study_obj->id;

  my $genomes_txt_file = "$server_dir_full_path/$study_id/genomes.txt";

  EGPlantTHs::Helper::run_system_command("touch $genomes_txt_file")
    or die "Could not create genomes.txt file in the $server_dir_full_path location\n";

  open(my $fh2, '>', $genomes_txt_file) or die "Could not open file '$genomes_txt_file' $!\n";

  foreach my $assembly_name (keys %{$assembly_names_href}) {

    print $fh2 "genome ".$assembly_name."\n"; 
    print $fh2 "trackDb ".$assembly_name."/trackDb.txt"."\n\n"; 
  }

}

sub make_trackDbtxt_file{

  my $self =shift;

  my ($ftp_dir_full_path, $study_obj , $assembly_name) = @_;
    
  my $study_id =$study_obj->id;
  my $trackDb_txt_file="$ftp_dir_full_path/$study_id/$assembly_name/trackDb.txt";

  EGPlantTHs::Helper::run_system_command("touch $trackDb_txt_file")
    or die "Could not create trackDb.txt file in the $ftp_dir_full_path/$study_id/$assembly_name location\n";       

  open(my $fh, '>', $trackDb_txt_file)
    or die "Error in ".__FILE__." line ".__LINE__." Could not open file '$trackDb_txt_file' $!";

  my @sample_ids = keys %{$study_obj->get_sample_ids($assembly_name)} ;
  if(scalar @sample_ids ==0){
    print STDERR "No samples found for study $study_id\n"; 
  }

  my $counter_of_tracks=0; # i need to count the number of tracks in order to have only the first 10 "on" by default

  foreach my $sample_id ( @sample_ids ) { 

    my $super_track_obj = $self->make_biosample_super_track_obj($sample_id);

    if(!$super_track_obj) {  # method returns 0 when there is no ENA warehouse sample metadata
      return 0;
    }

    $super_track_obj->print_track_stanza($fh);

    my $visibility="off";

    foreach my $biorep_id (keys %{$study_obj->get_biorep_ids_from_sample_id($sample_id)}){

      $counter_of_tracks++;
      if ($counter_of_tracks <=10){
        $visibility = "on";
      }else{
        $visibility = "off";
      }

      my $track_obj = $self->make_biosample_sub_track_obj($study_obj,$biorep_id,$sample_id,$visibility);

      if(!$track_obj){ # this is in case there is a run id from AE that is not yet in ENA, then I want to skip doing this track, this method returns 0 if this is the case
        next;
      }
      if($track_obj eq "no cram in ENA"){

        return "at least 1 cram file of the TH that was not found in ENA";
      }

      $track_obj->print_track_stanza($fh);

    } 
  }

  return 1;
} 


# i want they key of the key-value pair of the metadata to have "_" instead of space if they are more than 1 word
sub printlabel_key {

  my $string = shift ;
  my @array = split (/ /,$string) ;

  if (scalar @array > 1) {
    $string =~ s/ /_/g;

  }
  return $string;
}

# I want the value of the key-value pair of the metadata to have quotes in the whole string if the value is more than 1 word.
sub printlabel_value {

  my $string = shift ;
  my @array = split (/ /,$string) ;

  if (scalar @array > 1) {
       
    $string = "\"".$string."\"";  

  }
  return $string;
}

sub get_ENA_biorep_title{

  my $study_obj = shift;
  my $biorep_id = shift ;

  my $biorep_title ;
  my %run_titles;

  my @run_ids = @{$study_obj->get_run_ids_of_biorep_id($biorep_id)};

  if(scalar @run_ids > 1){ # then it is a clustered biorep
    foreach my $run_id (@run_ids){

      $run_titles{EGPlantTHs::ENA::get_ENA_title($run_id)} =1;  # I get all distinct run titles
    }
    my @distinct_run_titles = keys (%run_titles);
    $biorep_title= join(" ; ",@distinct_run_titles); # the run titles are seperated by comma

    return $biorep_title;
  }else{  # the biorep_id is the same as a run_id
    return EGPlantTHs::ENA::get_ENA_title($biorep_id);
  }
}

sub make_biosample_super_track_obj{
# i need 3 pieces of data to make the track obj :  track_name, long_label , metadata
  my $self= shift;
  my $sample_id = shift; # track name

  my $ena_sample_title = EGPlantTHs::ENA::get_ENA_title($sample_id);
  my $long_label;

  # there are cases where the sample doesnt have title ie : SRS429062 doesn't have sample title
  if($ena_sample_title and $ena_sample_title !~/^ *$/ ){ 
    $long_label= "$ena_sample_title ; <a href=\"http://www.ebi.ac.uk/ena/data/view/".$sample_id."\">".$sample_id."</a>";

  }else{
    $long_label = "<a href=\"http://www.ebi.ac.uk/ena/data/view/".$sample_id."\">".$sample_id."</a>";
    print STDERR "Could not get sample title from ENA API for sample $sample_id\n\n";

  }

  my $date_string = strftime "%a %b %e %H:%M:%S %Y %Z", gmtime;  # date is of this type: "Tue Feb  2 17:57:14 2016 GMT"
  my $metadata_string="hub_created_date=".printlabel_value($date_string)." biosample_id=".$sample_id;
    
  # returns a has ref or 0 if unsuccessful
  my $metadata_respose = EGPlantTHs::ENA::get_sample_metadata_response_from_ENA_warehouse_rest_call( $sample_id,$meta_keys_aref);  
  if ($metadata_respose==0){
  
    print STDERR "No metadata values found in ENA warehouse for sample $sample_id\n";
    return 0;

  }else{  # if there is metadata
    my %metadata_pairs = %{$metadata_respose};
    my @meta_pairs;

    foreach my $meta_key (keys %metadata_pairs) {  # printing the sample metadata
 
      my $meta_value = $metadata_pairs{$meta_key} ;
      my $pair= printlabel_key($meta_key)."=".printlabel_value($meta_value);
      push (@meta_pairs, $pair);
    }
    $metadata_string = $metadata_string." " . join(" ",@meta_pairs);
  }

  my $super_track_obj = EGPlantTHs::SuperTrack->new($sample_id,$long_label,$metadata_string);
  return $super_track_obj;
}

sub make_biosample_sub_track_obj{ 
# i need 5 pieces of data to make the track obj, to return:  track_name, parent_name, big_data_url , long_label ,file_type
  my $self= shift;

  my $study_obj = shift;
  my $biorep_id = shift; #track name
  my $parent_id = shift;
  my $visibility= shift;

  #my $big_data_url = $study_obj->get_big_data_file_location_from_biorep_id($biorep_id);

  my $study_id=$study_obj->id;
  my $big_data_url = EGPlantTHs::ENA::get_ENA_cram_location($biorep_id) ; 

  if (!$big_data_url){ # if the cram file is not yet in ENA the method EGPlantTHs::ENA::get_ENA_cram_location($biorep_id) returns 0

    print STDERR "This biorep id $biorep_id (study id $study_id) has not yet its CRAM file in ENA\n";
    return "no cram in ENA";
  }
  my $short_label_ENA;
  my $long_label_ENA;
  my $ena_title = get_ENA_biorep_title($study_obj,$biorep_id);

  if($biorep_id!~/biorep/){
    $short_label_ENA = "ENA Run:$biorep_id";

    if(!$ena_title){ # if return is 0
       print STDERR "Biorep id $biorep_id of study id $study_id was not found to have a title in ENA\n\n";
       $long_label_ENA = "<a href=\"http://www.ebi.ac.uk/ena/data/view/".$biorep_id."\">".$biorep_id."</a>" ;

    }elsif($ena_title eq "not yet in ENA"){
       print STDERR "Biorep id $biorep_id of study id $study_id is not yet in ENA, this track will not be written in the trackDb.txt file of the TH\n\n";
       return 0;
    }else{
       $long_label_ENA = $ena_title." ; <a href=\"http://www.ebi.ac.uk/ena/data/view/".$biorep_id."\">".$biorep_id."</a>" ;
    }

  }else{ # run id would be "E-MTAB-2037.biorep4"     
  
    $short_label_ENA = "ArrayExpress:$biorep_id";
    my $biorep_accession; 
    if($biorep_id=~/(.+)\.biorep.*/){
      $biorep_accession = $1;
    } 
 
    if(!$ena_title){
      print STDERR "first run of biorep id $biorep_id of study id $study_id was not found to have a title in ENA\n\n";
      # i want the link to be like: http://www.ebi.ac.uk/arrayexpress/experiments/E-GEOD-55482/samples/?full=truehttp://www.ebi.ac.uk/~rpetry/bbrswcapital/E-GEOD-55482.bioreps.txt      
      $long_label_ENA = "<a href=\"http://www.ebi.ac.uk/arrayexpress/experiments/E-GEOD-55482/samples/?full=truehttp://www.ebi.ac.uk/~rpetry/bbrswcapital/".$1.".bioreps.txt"."\">".$biorep_id."</a>";

     }else{ 
        $long_label_ENA = $ena_title.";<a href=\"http://www.ebi.ac.uk/arrayexpress/experiments/E-GEOD-55482/samples/?full=truehttp://www.ebi.ac.uk/~rpetry/bbrswcapital/".$biorep_accession.".bioreps.txt"."\">".$biorep_id."</a>";
      }
  }

  my $file_type = EGPlantTHs::ENA::give_big_data_file_type($big_data_url);
  my $track_obj = EGPlantTHs::SubTrack->new($biorep_id,$parent_id,$big_data_url,$short_label_ENA,$long_label_ENA,$file_type,$visibility);
  return $track_obj;

}


1;