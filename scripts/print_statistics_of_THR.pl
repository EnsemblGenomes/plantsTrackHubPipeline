# do first:
# export THR_USER=your_user_name_in_your_track_hub_registry_account
# export THR_PWD=your_password_in_your_track_hub_registry_account

use strict ;
use warnings;

use FindBin;
use lib $FindBin::Bin . '/../modules';
use EGPlantTHs::Registry;
use EGPlantTHs::EG;

my $registry_user_name = $ENV{'THR_USER'}; 
my $registry_pwd = $ENV{'THR_PWD'};

defined $registry_user_name and $registry_pwd
  or die "Track Hub Registry username and password are required to be set as shell variables\n";

  print "* Using these shell variables of the THR account:\n\n";
  print " THR_USER=$registry_user_name\n THR_PWD=$registry_pwd\n\n";

my $registry_obj = EGPlantTHs::Registry->new($registry_user_name, $registry_pwd,"public"); # dosn't matter the visibility setting in this case

my %track_hub_names = %{$registry_obj->give_all_Registered_track_hub_names()};

my %number_of_ths_per_species;

foreach my $study_id (keys %track_hub_names){

  my %assembly_info = %{$registry_obj->give_species_names_assembly_names_of_track_hub($study_id)};  #    $assembly_info{$species_name}{$assembly_name}=$assembly_id;
  foreach my $species_name (keys %assembly_info){
    $number_of_ths_per_species{$species_name}++;
  }
}

print "Number of track hubs per species:\n\n";

foreach my $species_name (keys %number_of_ths_per_species){

  print $species_name."\t".$number_of_ths_per_species{$species_name}."\n";
}

print "\n\n";
print "Number of track hubs with more than 1 assembly:\n\n";

foreach my $study_id (keys %track_hub_names){

  my $flag=0;
  my %assembly_info = %{$registry_obj->give_species_names_assembly_names_of_track_hub($study_id)};  #    $assembly_info{$species_name}{$assembly_name}=$assembly_id;

  foreach my $species_name (keys %assembly_info){
    if (keys %assembly_info >1 or keys %{$assembly_info{$species_name}} >1){
      $flag=1;
    }   
  } 

  next unless $flag==1;
  print $study_id."\t";

  foreach my $species_name (keys %assembly_info){
    foreach my $assembly_name (keys %{$assembly_info{$species_name}}){
      print $species_name."(".$assembly_name.")"."\t";
    }    
  }

  print "\n";
  
}
