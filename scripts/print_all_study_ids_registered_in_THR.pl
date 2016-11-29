
# do first:
# export THR_USER=your_user_name_in_your_track_hub_registry_account
# export THR_PWD=your_password_in_your_track_hub_registry_account


# use strict ;
# use warnings;
# 
# use FindBin;
# use lib $FindBin::Bin . '/../modules';
# use EGPlantTHs::Registry;
# 
# 
# my $registry_user_name =  "testing";
# my $registry_pwd = "testing";
# 
# my $registry_obj = EGPlantTHs::Registry->new($registry_user_name, $registry_pwd,"hidden");
# 
# #my %th_names = %{$registry_obj->give_all_Registered_track_hub_names()};
# 
# 
# print $registry_obj->delete_track_hub("all") ;
# 
# __END__



# do first:
# export THR_USER=your_user_name_in_your_track_hub_registry_account
# export THR_PWD=your_password_in_your_track_hub_registry_account

# use strict ;
# use warnings;
# 
# use FindBin;
# use lib $FindBin::Bin . '/../modules';
# use EGPlantTHs::Registry;
# use EGPlantTHs::EG;
# 
# my $registry_user_name =  "ensemblplants";
# my $registry_pwd = "testing";
# 
# my $registry_obj = EGPlantTHs::Registry->new($registry_user_name, $registry_pwd,"public"); # dosn't matter the visibility setting in this case
# 
# my %track_hub_names = %{$registry_obj->give_all_Registered_track_hub_names()};
# 
# foreach my $study_id (keys %track_hub_names){
# 
#   my %assembly_info = %{$registry_obj->give_species_names_assembly_names_of_track_hub($study_id)};  #    $assembly_info{$species_name}{$assembly_id}=$assembly_name;
#   my @info;
# 
#   foreach my $plant_name (keys %assembly_info){
#     foreach my $assembly_name (keys %{$assembly_info{$plant_name}}){
# 
#       my $string= $assembly_name. "," .$assembly_info{$plant_name}{$assembly_name};  #    $assembly_info{$species_name}{$assembly_name}=$assembly_id;
#       
#       push(@info,$string); 
#     }
#   }
# 
#   print $study_id."\t"."ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs/".$study_id."/hub.txt"."\t".join (",",@info)."\n";
#   
# }
# 
# 
# __END__


use strict ;
use warnings;

use FindBin;
use lib $FindBin::Bin . '/../modules';
use EGPlantTHs::Registry;

my $registry_user_name =  "testing";
my $registry_pwd = "testing";
my $file_name = $ARGV[0];

print "\nUsername and password of the THR account are:\n".$registry_user_name."\n" .$registry_pwd."\n\n";

my $registry_obj = EGPlantTHs::Registry->new($registry_user_name, $registry_pwd, "hidden");

open(IN, $file_name) or die "Can't open $file_name.\n";
my $count=0;

while(<IN>){
  chomp;
  my @words= split(/\t/, $_);

  my $study_id=$words[0];
  my $hub_txt_url=$words[1];
  my $assemblies=$words[2];


#($study_id,$hub_txt_url,$assemblyNames_assemblyAccesions_string)
  my $return_string = $registry_obj->register_track_hub($study_id,$hub_txt_url, $assemblies);
  $count++;
  print $count.". ".$return_string;
}

close(IN);